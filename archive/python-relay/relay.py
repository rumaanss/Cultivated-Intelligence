#!/usr/bin/env python3
"""Single-world, bounded, authenticated local relay. Python 3.10+, standard library only."""
import argparse,json,math,os,secrets,ssl,threading,time,sqlite3
from durable_store import Ledger
from planet_channel import PlanetChannel
from observer_regions import ObserverIndex
from platform_io import replace,ProcessLock
from pathlib import Path
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
MAX_BYTES=3*1024*1024
def unique_object(pairs):
 result={}
 for k,v in pairs:
  if k in result:raise ValueError('duplicate JSON key')
  result[k]=v
 return result

def need(ok,msg):
 if not ok:raise ValueError(msg)
def number(x):return type(x) in (int,float) and math.isfinite(x)
def integer(x,low=0,high=2147483647):return type(x)==int and low<=x<=high
def token(s):return type(s)==str and 1<=len(s)<=100 and all(c.isascii() and (c.isalnum() or c in '-_') for c in s)
def atomic(path,data):
 temp=path.with_suffix(path.suffix+'.tmp')
 with temp.open('w',encoding='utf-8',newline='\n') as f:f.write(data);f.flush();os.fsync(f.fileno())
 replace(temp,path)

def publish_input(path,data):
 # Inputs are replaceable poses plus events already committed to the SQLite
 # FULL-synchronous ledger. Flush Python buffers; no second durability barrier.
 # C++ event acknowledgment remains distinct from durable checkpoint acknowledgment.
 temp=path.with_suffix(path.suffix+'.tmp')
 with temp.open('w',encoding='utf-8',newline='\n') as f:f.write(data)
 replace(temp,path)

def exchange_bundle(world,plants,q):
 started=time.monotonic()
 result=dict(world.exchange(q))
 if isinstance(q,dict) and 'plants' in q:
  try:result['plants']=plants.exchange_paged(q['plants'])
  except (FileNotFoundError,ValueError,OSError) as error:
   result['plantError']=str(error)[:160]
 timing=result.get('relayTimingMs',[0,0,0])
 result['relayTimingMs']=[timing[0],timing[1],(time.monotonic()-started)*1000]
 return result

def journal(path,value):
 # Bounded logs: eight rotated 32 MiB segments plus the active segment.
 if path.exists() and path.stat().st_size>=32*1024*1024:
  oldest=path.with_name(path.name+'.8');oldest.unlink(missing_ok=True)
  for i in range(7,0,-1):
   old=path.with_name(path.name+'.'+str(i))
   if old.exists():os.replace(old,path.with_name(path.name+'.'+str(i+1)))
  os.replace(path,path.with_name(path.name+'.1'))
 with path.open('a',encoding='utf-8') as f:
  f.write(json.dumps(value,separators=(',',':'),allow_nan=False)+'\n');f.flush();os.fsync(f.fileno())

class World:
 def __init__(self,directory,audit=False):
  self.audit=audit
  self.habitat_stamp=None;self.habitat_identity=None
  self.epoch=0;self.boot=None;self.confirmed_previous={};self.sent_previous={};self.sent_batch=0;self.sent_sequence=None;self.sent_view=None;self.observer_requests={}
  self.directory=Path(directory);self.directory.mkdir(parents=True,exist_ok=True)
  self.ledger=Ledger(self.directory/'relay.sqlite3')
  self.lock=threading.Lock();self.run=None;self.session=None;self.last_request=0.;self.batch=0;self.pending={};self.poses={};self.actors=[];self.high_event=0;self.previous={};self.response_cache=None;self.last_seq=-1;self.stamp=None;self.snapshot=None;self.last_tick=None;self.tick_at=0.;self.calls=[];self.token=secrets.token_urlsafe(32)
 def recover(self,s):
  path=self.directory/'input.txt'
  if not path.exists():return
  try:
   need(path.stat().st_size<=MAX_BYTES,'input budget');lines=path.read_text().splitlines();h=lines[0].split()
   if len(h)!=7 or h[0]!='CIINPUT1' or h[1]!=self.run:return
   session=h[2];batch,n,a,e=map(int,h[3:]);need(token(session) and 0<=n<=10000 and 0<=a<=64 and 0<=e<=512 and len(lines) in (1+n+a+e,2+n+a+e),'input recovery')
   rows=[[float(x) for x in line.split()] for line in lines[1:1+n+a+e]]
   for row in rows:row[0]=int(row[0])
   self.session=session;self.batch=batch;self.poses={r[0]:r for r in rows[:n]};self.actors=rows[n:n+a]
   done=s.get('durableAck',0) if s['session']==session else 0
   self.pending=self.ledger.pending(self.run,session,done) or {r[0]:r for r in rows[n+a:] if r[0]>done};self.high_event=max([done,*self.pending])
   for row in self.pending.values():
    for i in range(4):row[i]=int(row[i])
   self.last_request=time.monotonic()
  except (ValueError,IndexError,KeyError,OSError):raise ValueError('Cannot recover relay input; stop both processes and use a new live directory')
 def load(self):
  p=self.directory/'snapshot.json';stat=p.stat();need(stat.st_size<=MAX_BYTES,'snapshot too large')
  stamp=(stat.st_mtime_ns,stat.st_size)
  if stamp!=self.stamp:
   raw=p.read_bytes();need(len(raw)<=MAX_BYTES,'snapshot too large');v=json.loads(raw)
   need(v.get('protocol')==1 and v.get('state') in ('running','stopped'),'unsupported snapshot')
   m=v['manifest'];need(token(m.get('runId')) and m.get('schemaVersion')==3 and m.get('geometry',{}).get('version') in (2,3,4),'lake manifest required')
   geometry=m['geometry'];habitat_path=self.directory/'planet_habitat.json'
   if geometry['version']==4 or habitat_path.exists():
    from planet_channel import validate_habitat
    import hashlib
    need(geometry['version']==4 and habitat_path.exists(),'Planet runtime requires its surveyed habitat and version 4 geometry')
    hs=habitat_path.stat();habitat_stamp=(hs.st_mtime_ns,hs.st_ctime_ns,hs.st_size)
    if self.habitat_stamp!=habitat_stamp:
     need(hs.st_size<=3*1024*1024,'habitat file budget')
     habitat=json.loads(habitat_path.read_text(encoding='utf-8'));validate_habitat(habitat)
     digest=hashlib.sha256(json.dumps(habitat,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()
     self.habitat_identity=(digest,habitat['id'],habitat['dataset']);self.habitat_stamp=habitat_stamp
    digest,habitat_id,habitat_dataset=self.habitat_identity
    binding=geometry.get('habitat',{})
    need(geometry.get('sha256')==digest and binding.get('sha256')==digest and binding.get('id')==habitat_id and binding.get('dataset')==habitat_dataset,'Planet publisher habitat mismatch')
   need(integer(v.get('sequence')) and integer(v.get('tick')) and integer(v.get('ack')),'invalid snapshot counters')
   rows=v.get('agents');need(type(rows)==list and len(rows)<=10000,'population budget')
   previous=0
   for r in rows:
    need(type(r)==list and len(r)==25 and all(type(x) in (int,float) for x in r) and all(map(math.isfinite,r)),'invalid agent')
    need(r[0]>previous and r[0]%1==0,'unsorted IDs');previous=r[0]
   if self.run!=m['runId']:
    self.run=m['runId'];self.session=None;self.batch=0;self.pending={};self.poses={};self.actors=[];self.high_event=0;self.previous={};self.last_seq=-1;self.response_cache=None;self.last_tick=None
    self.recover(v)
   if self.boot!=v.get('boot'):
    self.boot=v.get('boot');self.previous={};self.confirmed_previous={};self.sent_previous={};self.sent_batch=0;self.sent_sequence=None;self.sent_view=None;self.observer_requests={};self.response_cache=None
   if self.last_tick!=v['tick']:self.last_tick=v['tick'];self.tick_at=time.monotonic()
   if v['session']==self.session:
    self.pending={k:e for k,e in self.pending.items() if k>v.get('durableAck',0)}
   self.snapshot=v;self.stamp=stamp;self.snapshot_mtime=stat.st_mtime
   self.agent_rows={int(r[0]):r for r in rows}
   self.live_ids=set(self.agent_rows)
   self.observer_index=ObserverIndex(rows)
  return self.snapshot
 def exchange(self,q):
  with self.lock:
   now=time.monotonic();self.calls=[t for t in self.calls if now-t<60]
   need(len(self.calls)<420,'relay request budget exceeded');self.calls.append(now)
   started=time.monotonic();s=self.load();loaded=time.monotonic();m=s['manifest'];need(type(q)==dict and q.get('protocol')==1 and token(q.get('session')),'invalid request')
   view=q.get('observer')
   selected=self.observer_index.select(view,m.get('bounds')) if view is not None else self.agent_rows
   view_key=tuple(selected)
   observed=dict(s,agents=list(selected.values()),total=len(self.agent_rows)) if view is not None else s
   if q.get('run')!=self.run:return {'protocol':1,'reset':True,'manifest':m,'snapshot':observed,'age':max(0,time.time()-self.snapshot_mtime)}
   session=q['session'];batch=q.get('batch');need(integer(batch,1),'invalid batch')
   acknowledged=q.get('ackBatch',0);need(integer(acknowledged) and acknowledged<batch,'invalid response acknowledgment')
   if self.session!=session:
    if self.session is not None:
     need(now-self.last_request>8 and not self.pending,'world already leased or has uncommitted events')
     self.ledger.takeover(self.run)
    self.session=session;self.batch=0;self.high_event=0;self.pending={};self.previous={};self.poses={};self.actors=[];self.response_cache=None;self.confirmed_previous={};self.sent_previous={};self.sent_batch=0;self.sent_sequence=None;self.sent_view=None;self.observer_requests={}
   self.epoch=self.ledger.bind(self.run,session)
   self.last_request=now
   cpp_motion=m.get('motionAuthority')=='cpp-v1'
   fingerprint=self.ledger.check_request(self.run,session,batch,q)
   if cpp_motion and batch in self.observer_requests:need(self.observer_requests[batch]==fingerprint,'batch identity reused with different payload')
   if batch==self.batch and self.response_cache is not None and self.response_cache.get('batch')==batch and self.response_cache.get('session')==session and self.response_cache.get('run')==self.run:return self.response_cache
   need(batch>=self.batch,'old batch')
   correction_ack=q.get('correctionAck',0);need(integer(correction_ack),'invalid correction acknowledgment')
   poses=q.get('poses',[]);actors=q.get('actors',[]);events=q.get('events',[])
   cpp_motion=m.get('motionAuthority')=='cpp-v1'
   if cpp_motion:need(not poses and not actors and not events,'C++ motion world accepts observer heartbeats only')
   need(type(poses)==list and len(poses)<=10000 and type(actors)==list and len(actors)<=64 and type(events)==list and len(events)<=512,'request budgets')
   live_ids=self.live_ids;next_poses={i:p for i,p in self.poses.items() if i in live_ids}
   seen=set()
   for p in poses:
    need(type(p)==list and len(p)==7 and integer(p[0],1) and p[0] not in seen and all(number(x) for x in p),'invalid pose');seen.add(p[0])
    need(sum(x*x for x in p[1:4])<=1e12 and sum(x*x for x in p[4:])<=1e12,'pose numeric budget')
    if p[0] in live_ids:next_poses[p[0]]=p
   seen=set()
   for a in actors:
    need(type(a)==list and len(a)==7 and integer(a[0],1,999999) and a[0] not in seen and a[1] in (1,2) and all(number(x) for x in a),'invalid actor');seen.add(a[0])
    need(.1<=a[5]<=8 and 0<=a[6]<=10000 and sum(x*x for x in a[2:5])<=1e12,'actor bounds')
   durable=s.get('durableAck',0) if s['session']==session else 0
   pending=self.ledger.pending(self.run,session,durable);high=max([durable,*pending])
   if s.get('boot') and q.get('boot')!=s['boot']:
    return {'protocol':1,'resync':True,'snapshot':observed,'batch':batch,'epoch':self.epoch,'session':session}
   pending.update(self.pending);high=max([high,*pending])
   accepted_events=[];event_error=None
   for e in events:
    need(type(e)==list and len(e)==5 and all(integer(x,0) for x in e[:4]) and e[0]>0 and e[1] in (1,2) and e[2]>0 and number(e[4]) and 0<e[4]<=100,'invalid event')
    if e[0]<=high:
     need(e[0] not in pending or pending[e[0]]==e,'event identity changed');accepted_events.append(e);continue
    if e[0]!=high+1:event_error='event gap: expected '+str(high+1);break
    pending[e[0]]=e;high=e[0];accepted_events.append(e)
   need(len(pending)<=512,'unacknowledged event budget')
   lines=[f'CIINPUT1 {self.run} {self.session} {batch} {len(next_poses)} {len(actors)} {len(pending)}']
   for rows in [list(next_poses.values()),actors,[pending[k] for k in sorted(pending)]]:
    lines.extend(' '.join(str(x) for x in r) for r in rows)
   lines.append(f'ACKCORRECTIONS {correction_ack} EPOCH {self.epoch} BOOT {s.get("boot","legacy")}')
   # Journal combat events before acknowledging relay receipt; C++ acknowledgment is separate.
   if cpp_motion:
    # Observer requests contain no biological events. Owner fencing remains durable;
    # committing their retry fingerprints with fsync at 6 Hz only delays heartbeats.
    self.observer_requests[batch]=fingerprint
    while len(self.observer_requests)>1024:del self.observer_requests[next(iter(self.observer_requests))]
   else:self.ledger.record(self.run,session,batch,q,accepted_events,fingerprint)
   if self.audit:journal(self.directory/'input_audit.jsonl',{'receivedUtc':time.time(),'cppTick':s['tick'],'request':q})
   disk_start=time.monotonic();publish_input(self.directory/'input.txt','\n'.join(lines)+'\n');disk_ms=(time.monotonic()-disk_start)*1000
   self.poses=next_poses;self.actors=actors;self.pending=pending;self.high_event=high;self.batch=batch;self.response_cache=None
   if acknowledged==self.sent_batch:self.confirmed_previous=self.sent_previous
   self.previous=dict(self.confirmed_previous)
   # Membership always travels; full physical/lineage state only on birth/reset.
   current=selected;added=[];updates=[]
   # Most batches already refresh every body; skip all proximity work then.
   full_refresh=cpp_motion or batch%3==0
   positions=[a[2:5] for a in actors if a[1]==1 and a[6]>0]
   actor_cells={}
   if not full_refresh:
    for a in positions:actor_cells.setdefault(tuple(math.floor(v/30) for v in a),[]).append(a)
   for identity,row in current.items():
    old=self.previous.get(identity)
    if old is None:added.append(row);self.previous[identity]=row;continue
    near=False
    if not full_refresh and positions:
     pose=next_poses.get(identity)
     px,py,pz=pose[1:4] if pose is not None else row[2:5]
     if len(positions)<=4:
      near=any((px-a[0])**2+(py-a[1])**2+(pz-a[2])**2<900 for a in positions)
     else:
      cx,cy,cz=math.floor(px/30),math.floor(py/30),math.floor(pz/30)
      for dx in (-1,0,1):
       for dy in (-1,0,1):
        for dz in (-1,0,1):
         if any((px-a[0])**2+(py-a[1])**2+(pz-a[2])**2<900 for a in actor_cells.get((cx+dx,cy+dy,cz+dz),())):near=True;break
        if near:break
       if near:break
    if (near or full_refresh) and row!=old:
     updates.append([row[0],*row[8:10],*row[13:25]]);self.previous[identity]=row
   removed=[i for i in self.previous if i not in current]
   for i in removed:self.previous.pop(i)
   response={'protocol':1,'reset':False,'run':self.run,'session':session,'batch':batch,'sequence':s['sequence'],'tick':s['tick'],'ack':s['ack'] if s['session']==session else 0,'light':s['light'],'state':s['state'],'age':max(0,time.time()-self.snapshot_mtime),'stalled':now-self.tick_at>3 and s['tick']>0,'total':len(self.agent_rows),'visible':len(current),'viewVersion':1 if view is not None else 0,'added':added,'updates':updates,'removed':removed,'epoch':self.epoch,'boot':s.get('boot'),'durableAck':s.get('durableAck',0) if s['session']==session else 0,'bridgeBuild':s.get('bridgeBuild','legacy'),'corrections':s.get('corrections',[]) if s['session']==session else []}
   if cpp_motion:
    # Only suppress motion after this exact snapshot was acknowledged. A lost
    # response must resend it, even if C++ has not published another tick.
    unchanged=acknowledged==self.sent_batch and self.sent_sequence==s['sequence'] and self.sent_view==view_key
    response['motions']=[] if unchanged else [[row[0],*row[2:8]] for row in current.values()]
   status_path=self.directory/'bridge_status.json'
   try:
    if status_path.stat().st_size<=4096:
     diagnostic=json.loads(status_path.read_bytes())
     if diagnostic.get('run')==self.run and diagnostic.get('boot',s.get('boot'))==s.get('boot'):
      response['bridgeStatusAgeMs']=max(0,time.time()-status_path.stat().st_mtime)*1000;response['bridgeStatus']=diagnostic.get('status','unknown');response['cppInputAgeMs']=diagnostic.get('inputAgeMs',-1);response['cppReceivedBatch']=diagnostic.get('receivedBatch',0)
   except (OSError,ValueError):pass
   response['eventError']=event_error
   response['relayTimingMs']=[(loaded-started)*1000,disk_ms,(time.monotonic()-started)*1000]
   self.sent_previous=self.previous;self.sent_batch=batch;self.sent_sequence=s['sequence'];self.sent_view=view_key
   self.response_cache=response;return response

class Handler(BaseHTTPRequestHandler):
 server_version='CILive/1'
 protocol_version='HTTP/1.1'
 def log_message(self,*args):pass
 def send(self,status,value):
  raw=json.dumps(value,separators=(',',':'),allow_nan=False).encode()
  if status>=400:self.close_connection=True
  self.send_response(status)
  if self.close_connection:self.send_header('Connection','close')
  self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(raw)));self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(raw)
 def do_POST(self):
  self.connection.settimeout(5)
  if self.headers.get('Transfer-Encoding') or len(self.headers.get_all('Content-Length',[]))!=1:self.send(400,{'error':'invalid framing'});return
  if self.path not in ('/exchange','/plants','/plant-surface','/habitat','/telemetry'):self.send(404,{'error':'not found'});return
  if not secrets.compare_digest(self.headers.get('X-CI-Token',''),self.server.world.token):self.send(401,{'error':'unauthorized'});return
  try:
   n=int(self.headers.get('Content-Length','0'));need(0<n<=MAX_BYTES,'request size');raw=self.rfile.read(n);need(len(raw)==n,'incomplete body');q=json.loads(raw,object_pairs_hook=unique_object,parse_constant=lambda _:(_ for _ in ()).throw(ValueError('non-finite JSON')))
   self.send(200,exchange_bundle(self.server.world,self.server.plants,q) if self.path=='/exchange' else self.server.plants.exchange(q) if self.path=='/plants' else self.server.planet.habitat(q) if self.path=='/habitat' else self.server.planet.telemetry(q) if self.path=='/telemetry' else self.server.plants.surface(q))
  except FileNotFoundError as e:
   missing=Path(e.filename).name if e.filename else 'unknown'
   self.send(503,{'error':'waiting for C++ publisher' if missing=='snapshot.json' else 'required relay file missing: '+missing})
  except (ValueError,KeyError,TypeError,OverflowError,RecursionError) as e:self.send(409,{'error':str(e)[:180]})
  except (OSError,sqlite3.Error) as e:
   detail=f'{type(e).__name__}: {e}'
   print('[CI relay I/O] '+detail,flush=True)
   self.send(503,{'error':'relay I/O: '+detail[:800]})
class Server(ThreadingHTTPServer):
 daemon_threads=True
 def __init__(self,address,world):super().__init__(address,Handler);self.world=world;self.planet=PlanetChannel(world.directory);self.plants=__import__('plant_channel').PlantChannel(world.directory);self.slots=threading.BoundedSemaphore(8)
 def process_request(self,request,address):
  if not self.slots.acquire(blocking=False):self.shutdown_request(request);return
  try:super().process_request(request,address)
  except BaseException:self.slots.release();raise
 def process_request_thread(self,request,address):
  try:super().process_request_thread(request,address)
  finally:self.slots.release()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--directory',default='live/state');p.add_argument('--port',type=int,default=8765);p.add_argument('--host',default='127.0.0.1');p.add_argument('--roblox-root',type=Path);p.add_argument('--cert');p.add_argument('--key');p.add_argument('--public-url');p.add_argument('--takeover',action='store_true',help='Fence prior Roblox owner; stop old server first');p.add_argument('--rotate-token',action='store_true');p.add_argument('--audit-inputs',action='store_true',help='Record accepted two-way inputs in bounded rotating logs');a=p.parse_args()
 need(a.host in ('127.0.0.1','localhost'),'Built-in development server binds only to loopback; use production_wsgi.py behind TLS')
 Path(a.directory).mkdir(parents=True,exist_ok=True)
 relay_lock=ProcessLock(Path(a.directory)/"relay.lock")
 world=World(a.directory,a.audit_inputs)
 token_file=world.directory/'bridge.token'
 if a.takeover:
  snapshot=world.load();need(not world.pending,'Cannot take over with uncommitted events; reconnect old owner first');world.ledger.takeover(world.run);world.session=None;world.pending={};world.batch=0
 if a.rotate_token:token_file.unlink(missing_ok=True)
 if token_file.exists():world.token=token_file.read_text().strip()
 else:
  token_file.write_text(world.token);token_file.chmod(0o600)
 secret=os.environ.get('CI_BRIDGE_TOKEN')
 if secret:need(len(secret)>=32,'CI_BRIDGE_TOKEN must be at least 32 characters');world.token=secret
 need(len(world.token)>=32,'Stored token is invalid; remove bridge.token with the relay stopped')
 url=a.public_url or f'http://localhost:{a.port}/exchange'
 need(not a.public_url or (a.public_url.startswith('https://') and a.public_url.endswith('/exchange')),'Public URL must be HTTPS and end in /exchange')
 if a.roblox_root:
  need((a.roblox_root/'default.project.json').is_file(),'Wrong Roblox project root')
  path=a.roblox_root/'src/server/LiveTransportConfig.lua'
  atomic(path,'--!strict\n-- Generated local credentials. Do not commit this file.\nreturn table.freeze({Url='+json.dumps(url)+',Token='+json.dumps(world.token)+'})\n')
  ignore=a.roblox_root/'.gitignore';text=ignore.read_text() if ignore.exists() else ''
  if 'src/server/LiveTransportConfig.lua' not in text:ignore.write_text(text+'\nsrc/server/LiveTransportConfig.lua\n')
  print('Server-only connection configuration written. Sync Rojo before Play.')
 server=Server((a.host,a.port),world)
 if a.cert:
  context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.load_cert_chain(a.cert,a.key);server.socket=context.wrap_socket(server.socket,server_side=True)
 print(f'CI live relay listening on {a.host}:{a.port}. Ctrl+C stops it. No credentials are printed.')
 try:server.serve_forever(poll_interval=.25)
 except KeyboardInterrupt:pass
 finally:server.server_close();world.ledger.db.close();relay_lock.close()
if __name__=='__main__':main()
