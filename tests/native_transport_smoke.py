"""Offline developer test client; never part of the application's runtime."""
import argparse,json,time,urllib.request,urllib.error,statistics
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--runtime',type=Path,required=True);p.add_argument('--port',type=int,default=18765);a=p.parse_args()
base='http://127.0.0.1:'+str(a.port)
for _ in range(120):
 if (a.runtime/'native.token').exists():break
 time.sleep(.25)
key=(a.runtime/'native.token').read_text().strip()
def call(path,q,key_override=None,raw=None):
 req=urllib.request.Request(base+path,data=(raw or json.dumps(q)).encode(),headers={'Content-Type':'application/json','X-CI-Token':key if key_override is None else key_override})
 try:
  with urllib.request.urlopen(req,timeout=5) as r:return r.status,json.loads(r.read())
 except urllib.error.HTTPError as e:return e.code,json.loads(e.read())
q=dict(protocol=1,session='native-smoke',run='',batch=1,ackBatch=0,boot='',correctionAck=0,poses=[],actors=[],events=[],observer=dict(version=1,regions=[dict(center=[200,100,50],limit=384,selected=0)]))
assert call('/exchange',q,'wrong')[0]==401
assert call('/exchange',q,raw='{"protocol":1,"protocol":1}')[0]==409
for _ in range(120):
 code,r=call('/exchange',q)
 if code==200:break
 assert code==503,r
 time.sleep(.25)
assert r['reset'],r
q['run']=r['manifest']['runId'];q['boot']=r['snapshot']['boot']
code,resync=call('/exchange',dict(q,boot='old-process-boot'));assert code==200 and resync['resync'] and resync['session']==q['session']
assert len(r['snapshot']['agents'])<=384
initial=r['snapshot']['tick'];times=[];seen={};last_sequence=-1
for i in range(36):
 q['batch']=i+1;q['ackBatch']=i
 q['observer']['regions'][0]['limit']=16 if i==10 else 384
 if i==10 and seen:q['observer']['regions'][0]['selected']=max(seen)
 q['plants']=dict(schema=1,run='',revision=0)
 start=time.perf_counter();code,r=call('/exchange',q);times.append((time.perf_counter()-start)*1000)
 assert code==200,r
 assert set(r['exchangeStagesMs'])=={'snapshot','selection','agents','plants'}
 assert all(isinstance(v,(int,float)) and v>=0 for v in r['exchangeStagesMs'].values())
 assert sum(r['exchangeStagesMs'].values()) <= r['relayTimingMs'][2]+0.01
 assert r['exchangeCounts']['visible']==r['visible']
 assert r['run']==q['run'] and r['batch']==q['batch'] and r['session']==q['session'],r
 assert r['sequence']>=last_sequence;last_sequence=r['sequence']
 assert r['visible']<=q['observer']['regions'][0]['limit'] and r['transportBuild']=='native-memory-v1'
 if i==10:assert any(row[0]==q['observer']['regions'][0]['selected'] for row in r['motions'])
 for row in r['added']:seen[row[0]]=row
 for row in r['updates']:assert row[0] in seen
 for id in r['removed']:seen.pop(id,None)
 assert len(seen)==r['visible']
 if i==2:
  code,retry=call('/exchange',q);assert code==200 and retry==r
  changed=dict(q,correctionAck=1);assert call('/exchange',changed)[0]==409
 if i==3:
  other=dict(q,session='conflicting-owner');assert call('/exchange',other)[0]==409
 if i==4:
  invalid=dict(q,batch=i+2,events=[[1,1,1,1,1]]);assert call('/exchange',invalid)[0]==409
 if i==5:
  packet=r['plants']
  if packet.get('chunked'):
   pages=[packet['data']]
   for n in range(2,packet['count']+1):
    code,nextpage=call('/plants',dict(schema=1,transfer=packet['transfer'],chunk=n));assert code==200,nextpage;pages.append(nextpage['data'])
   packet=json.loads(''.join(pages))
  assert packet['reset'] and packet['upsert'] and packet['run']==q['run']
 time.sleep(.17)
assert r['tick']>initial,(initial,r['tick'])
code,health=call('/health',dict(schema=1));assert code==200,health
assert health['liveFileReads']==health['liveFileWrites']==0
assert not (a.runtime/'snapshot.json').exists() and not (a.runtime/'input.txt').exists()
result=dict(startTick=initial,endTick=r['tick'],requests=len(times),httpMedianMs=statistics.median(times),httpP95Ms=sorted(times)[int(.95*(len(times)-1))],health=health)
(a.runtime/'smoke-result.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))

# Continue observer heartbeats until the native run finishes.
import os
if os.environ.get('CI_TEST_KEEPALIVE') == '1':
 deadline=time.monotonic()+40
 q.pop('plants',None)
 while time.monotonic()<deadline:
  q['ackBatch']=q['batch'];q['batch']+=1
  try:
   code,reply=call('/exchange',q)
  except (urllib.error.URLError, OSError):
   break
  assert code==200,reply
  assert reply['batch']==q['batch'] and reply['session']==q['session'],reply
  time.sleep(.17)
 else:
  raise TimeoutError('Native run did not finish while observer heartbeats continued')