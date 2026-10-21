"""A post-input failure must never return another batch's cached response."""
import tempfile,json
from pathlib import Path
from unittest.mock import patch
from relay import World,atomic
with tempfile.TemporaryDirectory()as d:
 p=Path(d);w=World(p)
 s={'protocol':1,'state':'running','manifest':{'runId':'retry-test','schemaVersion':3,'geometry':{'version':2},'motionAuthority':'cpp-v1'},'sequence':1,'tick':1,'ack':0,'durableAck':0,'session':'owner','boot':'boot-1','light':[0,.08,.08],'agents':[],'bridgeBuild':'hardened-v3'}
 atomic(p/'snapshot.json',json.dumps(s))
 q={'protocol':1,'run':'retry-test','session':'owner','boot':'boot-1','batch':1,'ackBatch':0,'poses':[],'actors':[],'events':[]}
 assert w.exchange(q)['batch']==1
 q.update(batch=2,ackBatch=1)
 original=Path.stat;count=[0]
 def fail_stat(path,*args,**kwargs):
  if path==p/'snapshot.json':
   count[0]+=1
   if count[0]==2:raise FileNotFoundError(2,'Injected replacement race',str(path))
  return original(path,*args,**kwargs)
 with patch.object(Path,'stat',fail_stat):
  try:w.exchange(q)
  except FileNotFoundError:pass
 reply=w.exchange(q)
 assert reply['batch']==q['batch'],f"Wrong exchange identity reproduced: expected {q['batch']}, received {reply['batch']}"
 # Explicit partial-commit state must also reject a mismatched response cache.
 w.batch=3;q.update(batch=3,ackBatch=2)
 assert w.exchange(q)['batch']==3
 w.ledger.db.close()
print('PASS injected snapshot replacement failure and partial-commit retry identity')
