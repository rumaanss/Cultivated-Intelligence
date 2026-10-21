"""Authenticated read-only plant state channel plus explicit terrain export ingestion.
Uses the relay's existing token; never accepts client-authored plant biology.
"""
import json, math, threading, time, os, hashlib
from pathlib import Path
from platform_io import replace
def atomic(path,text):
 temp=path.with_name(path.name+'.upload.tmp')
 with open(temp,'w',encoding='utf-8',newline='\n') as f:
  f.write(text);f.flush();os.fsync(f.fileno())
 replace(temp,path)
LIMIT=8*1024*1024
class PlantChannel:
 def __init__(self,directory):self.directory=Path(directory);self.lock=threading.Lock();self.current=None;self.previous=None;self.signature=None;self.history=[];self.transfers={}
 def exchange(self,q):
  if not isinstance(q,dict) or q.get('schema')!=1:raise ValueError('plant protocol')
  with self.lock:
   p=self.directory/'plants.json';st=p.stat()
   if st.st_size>LIMIT:raise ValueError('plant snapshot budget')
   signature=(st.st_mtime_ns,st.st_size)
   if signature!=self.signature:
    raw=p.read_bytes()
    if len(raw)>LIMIT:raise ValueError('plant snapshot budget')
    s=json.loads(raw)
    if s.get('schema')!=1 or not isinstance(s.get('plants'),list) or len(s['plants'])>512:raise ValueError('plant snapshot schema')
    if self.current and s['run']==self.current['run'] and s['revision']<self.current['revision']:raise ValueError('plant revision rollback')
    if self.current:
     prior_by_id={p['id']:p for p in self.current['plants']}
     for plant in s['plants']:
      prior=prior_by_id.get(plant['id'])
      if prior and prior.get('organs')==plant.get('organs') and 'organs' in prior:plant['organs']=prior['organs']
     self.history.append(self.current)
     self.history=self.history[-8:]
    self.previous=self.current;self.current=s;self.signature=signature
   s=self.current
   info={k:s[k] for k in ('schema','run','revision','tick','surface','units','ledger')};info['age']=max(0,time.time()-st.st_mtime)
   for key in ('worldTick','worldBounds','plantStride','habitatDigest','environment'):
    if key in s:info[key]=s[key]
   if q.get('run')==s['run'] and q.get('revision')==s['revision']:
    return dict(info,reset=False,base=s['revision'],upsert=[],removed=[])
   old=next((v for v in reversed(self.history) if q.get('run')==v['run'] and q.get('revision')==v['revision']),None)
   if old and q.get('run')==old['run']==s['run'] and q.get('revision')==old['revision']:
    a={p['id']:p for p in old['plants']};b={p['id']:p for p in s['plants']}
    updates=[]
    for identity,p in b.items():
     prior=a.get(identity)
     if prior==p:continue
     row=dict(p)
     if prior and prior.get('organs')==p.get('organs'):row.pop('organs')
     updates.append(row)
    return dict(info,reset=False,base=old['revision'],upsert=updates,removed=[i for i in a if i not in b])
   return dict(info,reset=True,base=0,upsert=s['plants'],removed=[])
 def exchange_paged(self,q):
  # A reset is frozen until complete, so a faster publisher cannot invalidate
  # the client's in-flight base. Only three bounded transfers are retained.
  if not isinstance(q,dict):raise ValueError('plant protocol')
  transfer=q.get('transfer');index=q.get('chunk',1)
  if transfer:
   if not isinstance(transfer,str) or len(transfer)!=64 or type(index)!=int:raise ValueError('plant transfer query')
   with self.lock:
    cached=self.transfers.get(transfer)
    if cached:
     pages,created=cached
     if not 1<=index<=len(pages):raise ValueError('plant chunk index')
     return {'chunked':True,'transfer':transfer,'index':index,'count':len(pages),'data':pages[index-1],'age':max(0,time.time()-created)}
  packet=self.exchange(q)
  encoded=json.dumps(packet,separators=(',',':'),allow_nan=False)
  if len(encoded)<=256*1024:return packet
  if len(encoded)>LIMIT:raise ValueError('plant transfer budget')
  transfer=hashlib.sha256(encoded.encode()).hexdigest()
  pages=[encoded[i:i+256*1024] for i in range(0,len(encoded),256*1024)]
  with self.lock:
   self.transfers[transfer]=(pages,time.time())
   while len(self.transfers)>3:self.transfers.pop(next(iter(self.transfers)))
  return {'chunked':True,'transfer':transfer,'index':1,'count':len(pages),'data':pages[0],'age':0}
 def surface(self,q):
  text=q.get('text') if isinstance(q,dict) else None
  if not isinstance(text,str) or len(text)>2*1024*1024:raise ValueError('surface size')
  fields=text.split();h=fields[:7]
  if len(h)!=7 or h[0]!='CIPLANTSURFACE1' or not h[1].replace('-','').replace('_','').isalnum() or len(h[1])>80:raise ValueError('surface schema')
  width,height=int(h[2]),int(h[3]);numbers=list(map(float,h[4:]))
  if not 1<=width<=128 or not 1<=height<=128 or not all(math.isfinite(n) for n in numbers) or numbers[2]<=0:raise ValueError('surface bounds')
  if len(fields)!=7+width*height*5:raise ValueError('surface count')
  for i in range(7,len(fields),5):
   y,depth,water,nutrient,valid=map(float,fields[i:i+5])
   if not all(math.isfinite(n) for n in (y,depth,water,nutrient,valid)) or not -10000<=y<=10000 or not 0<depth<=1000 or not 0<=water<=1000 or not 0<=nutrient<=1000 or valid not in (0,1):raise ValueError('surface cell')
  with self.lock:atomic(self.directory/'plant_surface.txt',text)
  return {'schema':1,'saved':True,'revision':h[1],'cells':width*height,'note':'Used on a new plant run; never rewrites a running ecosystem'}
