"""Exact spatial views, bounded transport, camera migration, loss and read-only state."""
import json,tempfile,random,copy,time,statistics,sys,shutil
from pathlib import Path
from observer_regions import ObserverIndex
from relay import World,atomic
rng=random.Random(42)
rows=[[i,0,*[rng.uniform(-100,400) for _ in range(3)],0,0,0,100,1,0,0,0,1,.1,.1,0,100,1,.5,.5,.5,0,0,0] for i in range(1,10001)]
index=ObserverIndex(rows)
for _ in range(30):
 center=[rng.uniform(-150,450)for _ in range(3)];k=rng.randrange(1,385)
 actual=index.nearest(center,k)
 expected=[r[0]for r in sorted(rows,key=lambda r:(sum((a-b)**2 for a,b in zip(r[2:5],center)),r[0]))[:k]]
 assert actual==expected
for invalid in [{'version':2,'regions':[]},{'version':1,'regions':[{'center':[float('nan'),0,0]}]},{'version':1,'regions':[{'center':[0,0,0],'limit':385}]}]:
 try:index.select(invalid,None)
 except ValueError:pass
 else:raise AssertionError('Invalid view accepted')
with tempfile.TemporaryDirectory()as d:
 p=Path(d);w=World(p)
 s={'protocol':1,'state':'running','manifest':{'runId':'region-test','schemaVersion':3,'geometry':{'version':2},'motionAuthority':'cpp-v1','bounds':[436,212,108]},'sequence':1,'tick':1,'ack':0,'durableAck':0,'session':'owner','boot':'boot-1','light':[0,.08,.08],'agents':rows,'bridgeBuild':'hardened-v3'}
 atomic(p/'snapshot.json',json.dumps(s));original=(p/'snapshot.json').read_bytes()
 q={'protocol':1,'run':'','session':'owner','boot':'boot-1','batch':1,'ackBatch':0,'poses':[],'actors':[],'events':[],'observer':{'version':1,'regions':[{'center':[0,0,0],'limit':384,'selected':10000}]}}
 reset=w.exchange(q);assert len(reset['snapshot']['agents'])==384 and reset['snapshot']['total']==10000
 q['run']='region-test';r=w.exchange(q);membership={x[0]for x in r['added']};assert 10000 in membership
 # Observer-only traffic does not create durable event/request records.
 assert w.ledger.db.execute('SELECT COUNT(*) FROM requests').fetchone()[0]==0
 assert w.ledger.db.execute('SELECT COUNT(*) FROM leases').fetchone()[0]==1
 q.update(batch=2,ackBatch=1);q['observer']['regions'][0]['center']=[400,400,400]
 lost=w.exchange(q);assert lost['removed'] and lost['added']
 q['batch']=3;r=w.exchange(q)
 assert r['removed']==lost['removed'] and r['added']==lost['added']
 membership.difference_update(r['removed']);membership.update(x[0]for x in r['added'])
 assert membership==set(w.observer_index.select(q['observer'],None)) and len(membership)==384
 changed=copy.deepcopy(q);changed['observer']['regions'][0]['center']=[1,1,1]
 try:w.exchange(changed)
 except ValueError:pass
 else:raise AssertionError('Changed same-batch observer request accepted')
 q.update(batch=4,ackBatch=3);r=w.exchange(q);assert not r['motions'] and not r['added'] and not r['removed']
 assert (p/'snapshot.json').read_bytes()==original
 # Four regions remain bounded without losing global population accounting.
 q.update(batch=5,ackBatch=4);q['observer']['regions']=[{'center':[i*100]*3,'limit':384,'selected':0}for i in range(4)]
 r=w.exchange(q);assert r['visible']<=1536 and r['total']==10000
 w.ledger.db.close()
print('PASS 30 exact nearest comparisons at 10k, view budgets, 4 regions, loss/retry, migration, durable ownership and unchanged biology')
if len(sys.argv)>2:
 source=Path(sys.argv[1]);habitat=Path(sys.argv[2]);actual=json.loads(source.read_text())
 with tempfile.TemporaryDirectory()as d:
  p=Path(d);shutil.copyfile(habitat,p/'planet_habitat.json');atomic(p/'snapshot.json',json.dumps(actual));w=World(p)
  q={'protocol':1,'run':actual['manifest']['runId'],'session':'measure','boot':actual['boot'],'batch':1,'ackBatch':0,'poses':[],'actors':[],'events':[],'observer':{'version':1,'regions':[{'center':[218,106,90],'limit':384,'selected':0}]}}
  times=[];sizes=[]
  for i in range(1,31):
   actual['tick']+=1;actual['sequence']+=1
   for row in actual['agents']:row[9]+=1
   atomic(p/'snapshot.json',json.dumps(actual));q.update(batch=i,ackBatch=i-1)
   t=time.perf_counter();r=w.exchange(q);times.append((time.perf_counter()-t)*1000);sizes.append(len(json.dumps(r,separators=(',',':'))))
   assert len(r['motions'])==384 and r['total']==len(actual['agents'])
  print('Actual advancing snapshots: median_ms',round(statistics.median(times[1:]),2),'p95_ms',round(sorted(times[1:])[27],2),'median_bytes',statistics.median(sizes[1:]),'visible',r['visible'],'global',r['total'])
  w.ledger.db.close()
