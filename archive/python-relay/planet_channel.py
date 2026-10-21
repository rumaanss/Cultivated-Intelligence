"""Read-only publisher telemetry and validated, immutable planet habitat export.

No exchange, session claim, event application or biology startup occurs here.
"""
import hashlib,json,math,threading,time
from pathlib import Path
from platform_io import replace

def finite(v):return type(v) in (int,float) and math.isfinite(v)
def need(ok,message):
 if not ok:raise ValueError(message)
def vector(v):
 need(type(v) is list and len(v)==3 and all(finite(x) for x in v),'invalid frame vector');return v
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def validate_habitat(q):
 need(type(q) is dict and q.get('schema')==1 and q.get('biologyEnabled') is False,'invalid habitat schema/state')
 for key in ('id','dataset'):
  v=q.get(key);need(type(v) is str and 0<len(v)<=128 and all(c.isalnum() or c in '-_.' for c in v),'invalid habitat identity')
 need(q.get('unit')=='stud' and q.get('coordinates')=='east-north-radial-altitude','invalid habitat units')
 f=q.get('frame');need(type(f) is dict,'missing frame');center=vector(f.get('center'))
 need(all(abs(x)<=1e7 for x in center) and finite(f.get('radius')) and 100<=f['radius']<=1e7,'invalid planet radius/center')
 axes=[vector(f.get(k)) for k in ('up','east','north')]
 need(all(abs(dot(a,a)-1)<1e-5 for a in axes),'non-unit frame')
 need(all(abs(dot(axes[i],axes[j]))<1e-5 for i,j in ((0,1),(0,2),(1,2))),'nonorthogonal frame')
 up,east,north=axes
 cross=[north[1]*up[2]-north[2]*up[1],north[2]*up[0]-north[0]*up[2],north[0]*up[1]-north[1]*up[0]]
 need(dot(cross,east)>.99999,'incorrect habitat handedness')
 w=q.get('water');need(type(w) is dict and w.get('grid')==4,'unsupported water survey spacing')
 cells=w.get('cells');need(type(cells) is list and 9<=len(cells)<=20000,'water survey budget')
 floors={}
 for c in cells:
  need(type(c) is list and len(c)==3 and type(c[0]) is int and type(c[1]) is int and finite(c[2]),'invalid floor cell')
  need(abs(c[0]*4)<=f['radius']*.25 and abs(c[1]*4)<=f['radius']*.25 and -200<=c[2]<=50,'floor outside region')
  key=tuple(c[:2]);need(key not in floors,'duplicate floor cell');floors[key]=c[2]
 need((0,0) in floors and floors[(0,0)]<0,'habitat origin must be submerged')
 for (x,y),altitude in floors.items():
  if any(k not in floors for k in ((x+1,y),(x-1,y),(x,y+1),(x,y-1))):need(altitude>=2,'open shoreline')
 seen={(0,0)};todo=[(0,0)]
 while todo:
  x,y=todo.pop()
  for k in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
   if k in floors and k not in seen:seen.add(k);todo.append(k)
 need(len(seen)==len(floors),'disconnected survey')
 land=q.get('land');need(type(land) is dict,'missing land survey')
 nx,ny=land.get('nx'),land.get('ny');need(type(nx) is int and type(ny) is int and 1<=nx<=128 and 1<=ny<=128,'land grid budget')
 need(land.get('spacing')==16 and type(land.get('origin')) is list and len(land['origin'])==2 and all(finite(x) for x in land['origin']),'invalid land frame')
 lc=land.get('cells');need(type(lc) is list and len(lc)==nx*ny,'land cell count')
 wet=[(x*4,y*4) for (x,y),h in floors.items() if h<0];eligible=0
 for i,c in enumerate(lc):
  need(type(c) is list and len(c)==3 and finite(c[0]) and -200<=c[0]<=200 and finite(c[1]) and -1.00001<=c[1]<=1.00001 and type(c[2]) is bool,'invalid land sample')
  x,y=land['origin'][0]+(i%nx+.5)*16,land['origin'][1]+(i//nx+.5)*16
  need(abs(x)<=f['radius']*.25 and abs(y)<=f['radius']*.25,'land outside chart')
  if c[2]:
   nearest=min((x-a)**2+(y-b)**2 for a,b in wet)
   need(c[0]>=3 and c[1]>=.85 and 144<=nearest<=4096,'plant site is not suitable near-lake land');eligible+=1
 need(eligible>0,'no suitable plant sites')
 return q

class PlanetChannel:
 def __init__(self,directory):
  self.directory=Path(directory);self.lock=threading.Lock();self.sample=None;self.rate=None
 def habitat(self,q):
  validate_habitat(q)
  raw=json.dumps(q,sort_keys=True,separators=(',',':'),allow_nan=False).encode();digest=hashlib.sha256(raw).hexdigest()
  target=self.directory/'planet_habitat.json'
  with self.lock:
   if target.exists():need(target.read_bytes()==raw,'habitat changed; use a new runtime directory')
   else:
    need(not (self.directory/'snapshot.json').exists(),'existing simulation directory; use a fresh planet runtime directory')
    temp=target.with_suffix('.tmp');temp.write_bytes(raw);replace(temp,target)
  return {'schema':1,'id':q['id'],'sha256':digest,'biologyEnabled':False}
 def telemetry(self,q):
  need(type(q) is dict and q.get('schema')==1,'invalid telemetry request')
  start=time.monotonic();result={'schema':1,'state':'No publisher'}
  with self.lock:
   path=self.directory/'snapshot.json'
   if path.exists():
    stat=path.stat();need(stat.st_size<=3*1024*1024,'snapshot too large')
    raw=path.read_bytes();need(len(raw)<=3*1024*1024,'snapshot too large');s=json.loads(raw)
    tick=s.get('tick');need(type(tick) is int and 0<=tick<=4294967295,'invalid tick')
    identity=(s.get('manifest',{}).get('runId'),s.get('boot'));now=time.monotonic()
    age=max(0,time.time()-stat.st_mtime)
    if self.sample is None or self.sample[0]!=identity or tick<self.sample[1]:self.sample=(identity,tick,now);self.rate=None
    elif now-self.sample[2]>=1:
     self.rate=(tick-self.sample[1])/(now-self.sample[2]);self.sample=(identity,tick,now)
    result.update(SimulationTick=tick,SnapshotAgeSeconds=age,state='Stale' if age>3 else s.get('state','Unknown'))
    if self.rate is not None and age<=3:result['SimulationTicksPerSecond']=self.rate
   else:self.sample=None;self.rate=None
  result['RelayWorkMs']=(time.monotonic()-start)*1000
  return result
