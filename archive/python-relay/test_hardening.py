"""Standard-library relay fault/load tests; no Studio or internet required."""
import tempfile,time,json,sys,copy,statistics
from pathlib import Path
from durable_store import Ledger
from relay import World,atomic,unique_object

def reject(f):
 try:f()
 except (ValueError,RuntimeError):return
 raise AssertionError('invalid operation accepted')

def main():
 with tempfile.TemporaryDirectory() as d:
  p=Path(d);ledger=Ledger(p/'ledger.sqlite3')
  assert ledger.bind('run','owner')==1
  reject(lambda:ledger.bind('run','intruder'))
  event=[1,1,9,1,35];q={'events':[event]}
  ledger.record('run','owner',1,q,[event]);ledger.record('run','owner',1,q,[event])
  reject(lambda:ledger.record('run','owner',1,{'changed':True},[]))
  reject(lambda:ledger.record('run','owner',2,{},[[1,1,9,1,40]]))
  ledger.db.close();ledger=Ledger(p/'ledger.sqlite3');assert ledger.pending('run','owner',0)=={1:event}
  assert ledger.pending('run','owner',1)=={}
  assert ledger.takeover('run')==2 and ledger.bind('run','new-owner')==2
  reject(lambda:ledger.bind('run','owner'))
  reject(lambda:json.loads('{"a":1,"a":2}',object_pairs_hook=unique_object))
  ledger.db.close()
 with tempfile.TemporaryDirectory() as d:
  p=Path(d);world=World(p)
  agents=[[i,0,50,50,40,0,0,0,100,1,0,0,0,1,.1,.1,0,100,1,.5,.5,.5,0,0,0] for i in range(1,10001)]
  snapshot={'protocol':1,'state':'running','manifest':{'runId':'load-run','schemaVersion':3,'geometry':{'version':2}},'sequence':1,'tick':1,'ack':0,'durableAck':0,'session':'owner','boot':'boot-1','light':[0,.08,.08],'agents':agents,'bridgeBuild':'hardened-v3'}
  atomic(p/'snapshot.json',json.dumps(snapshot));q={'protocol':1,'run':'load-run','session':'owner','boot':'boot-1','batch':1,'poses':[[r[0],*r[2:8]] for r in agents],'actors':[],'events':[]}
  times=[]
  for i in range(30):
   q['batch']=i+1;start=time.perf_counter();result=world.exchange(q);times.append(1000*(time.perf_counter()-start))
   assert result['total']==10000
   if i<2:assert len(result['added'])==10000 # first reply lost: birth rows must be resent
   if i==1:q['ackBatch']=2
   if i==2:assert not result['added']
  bad=copy.deepcopy(q);bad['poses'][0][1]=51
  reject(lambda:world.exchange(bad))
  q['batch']+=1;q['events']=[[2,1,1,1,10]];result=world.exchange(q);assert result['eventError'] and result['ack']==0
  assert (p/'input.txt').stat().st_size<3*1024*1024
  world.calls=[time.monotonic()]*420;reject(lambda:world.exchange(q))
  print('10k agents, 30 exchanges: median %.1f ms, p95 %.1f ms; input %d bytes'%(statistics.median(times),sorted(times)[28],(p/'input.txt').stat().st_size))
  world.ledger.db.close()
 print('PASS durable dedup/restart, changed retry rejection, fencing, JSON ambiguity rejection, event-gap lane isolation, load and quota checks')
if __name__=='__main__':main()
