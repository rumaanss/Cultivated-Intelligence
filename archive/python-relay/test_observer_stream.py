"""Native observer acknowledgments, lost packets, boot fencing and status identity."""
import json,tempfile
from pathlib import Path
from relay import World,atomic

def main():
 with tempfile.TemporaryDirectory() as d:
  p=Path(d);w=World(p)
  row=[1,0,50,50,40,0,0,0,100,1,0,0,0,1,.1,.1,0,100,1,.5,.5,.5,0,0,0]
  s={'protocol':1,'state':'running','manifest':{'runId':'observer-test','schemaVersion':3,'geometry':{'version':2},'motionAuthority':'cpp-v1'},'sequence':1,'tick':1,'ack':0,'durableAck':0,'session':'owner','boot':'boot-1','light':[0,.08,.08],'agents':[row],'bridgeBuild':'hardened-v3'}
  atomic(p/'snapshot.json',json.dumps(s))
  q={'protocol':1,'run':'observer-test','session':'owner','boot':'boot-1','batch':1,'ackBatch':0,'poses':[],'actors':[],'events':[]}
  first=w.exchange(q);assert len(first['motions'])==1 and len(first['added'])==1
  assert w.exchange(q)==first # Exact retry is stable.
  q['batch']=2
  assert len(w.exchange(q)['motions'])==1 # Unacknowledged response resends.
  q.update(batch=3,ackBatch=2)
  r=w.exchange(q);assert r['motions']==[] and r['added']==[]
  assert (p/'input.txt').read_text().split()[3]=='3' # Heartbeat still reaches C++.
  s['sequence']=2;s['tick']=2;s['agents'][0][2]=51
  atomic(p/'snapshot.json',json.dumps(s));q.update(batch=4,ackBatch=3)
  assert w.exchange(q)['motions'][0][1]==51
  atomic(p/'bridge_status.json',json.dumps({'run':'observer-test','boot':'old-boot','status':'stale-input'}))
  q.update(batch=5,ackBatch=4);assert 'bridgeStatus' not in w.exchange(q)
  atomic(p/'bridge_status.json',json.dumps({'run':'observer-test','boot':'boot-1','status':'running','inputAgeMs':20}))
  q.update(batch=6,ackBatch=5);r=w.exchange(q);assert r['bridgeStatus']=='running' and r['bridgeStatusAgeMs']>=0
  s['boot']='boot-2';s['sequence']=1;s['tick']=1
  atomic(p/'snapshot.json',json.dumps(s));q.update(batch=7,ackBatch=6)
  assert w.exchange(q)['resync']
  q.update(batch=8,boot='boot-2');r=w.exchange(q)
  assert len(r['motions'])==1 and len(r['added'])==1
  w.ledger.db.close()
 print('PASS observer duplicate/lost/acknowledged/new snapshot, heartbeat, boot reset and status fencing')
if __name__=='__main__':main()
