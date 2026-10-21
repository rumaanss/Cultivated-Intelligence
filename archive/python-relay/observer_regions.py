"""Bounded read-only observer views; region exit never changes simulation life.
Index is built once per native snapshot. Exact nearest selection has deterministic
ID tie breaking; cell lower bounds let distant cells be skipped safely.
"""
import math,heapq
class ObserverIndex:
 CELL=24
 def __init__(self,rows):
  self.rows={int(r[0]):r for r in rows};self.cells={}
  for r in rows:self.cells.setdefault(tuple(math.floor(v/self.CELL) for v in r[2:5]),[]).append(r)
 def nearest(self,center,limit):
  cells=[]
  cx,cy,cz=center
  for key,rows in self.cells.items():
   lower=sum(max(k*self.CELL-c,0,c-(k+1)*self.CELL)**2 for k,c in zip(key,center))
   cells.append((lower,key,rows))
  cells.sort(key=lambda x:(x[0],x[1]));best=[]
  for lower,_,rows in cells:
   if len(best)==limit and lower>-best[0][0]:break
   for r in rows:
    dx,dy,dz=r[2]-cx,r[3]-cy,r[4]-cz
    distance=dx*dx+dy*dy+dz*dz;entry=(-distance,-r[0],r[0])
    if len(best)<limit:heapq.heappush(best,entry)
    elif entry>best[0]:heapq.heapreplace(best,entry)
  return [identity for _,_,identity in sorted(best,reverse=True)]
 def select(self,request,bounds):
  if not isinstance(request,dict) or request.get('version')!=1:raise ValueError('observer view version')
  regions=request.get('regions');
  if not isinstance(regions,list) or not 1<=len(regions)<=4:raise ValueError('observer region budget')
  result={}
  for region in regions:
   if not isinstance(region,dict):raise ValueError('observer region')
   center=region.get('center');limit=region.get('limit',384);selected=region.get('selected',0)
   if not isinstance(center,list) or len(center)!=3 or not all(type(v) in (float,int) and math.isfinite(v) and abs(v)<=10000 for v in center):raise ValueError('observer center')
   if type(limit)!=int or not 1<=limit<=384 or type(selected)!=int or not 0<=selected<=2147483647:raise ValueError('observer selection budget')
   ids=self.nearest(center,limit)
   if selected in self.rows and selected not in ids:ids=ids[:limit-1]+[selected]
   for identity in ids:result[identity]=self.rows[identity]
  return dict(sorted(result.items()))
