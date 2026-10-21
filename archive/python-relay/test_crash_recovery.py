"""Force-terminate C++ and verify durable event does not apply twice after resync."""
from pathlib import Path
import sys,tempfile,subprocess,time,json
from relay import World
exe=sys.argv[1]
def wait_for(fn,seconds=5):
 end=time.monotonic()+seconds
 while time.monotonic()<end:
  try:
   value=fn()
   if value:return value
  except (FileNotFoundError,json.JSONDecodeError):pass
  time.sleep(.03)
 raise AssertionError('timed out')
for committed in (False,True):
 with tempfile.TemporaryDirectory() as d:
  p=Path(d);process=subprocess.Popen([exe,d],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
  world=World(d)
  try:
   first=wait_for(lambda:json.loads((p/'snapshot.json').read_text()))
   q={'protocol':1,'run':first['manifest']['runId'],'boot':first['boot'],'session':'crash-owner','batch':1,'poses':[[1,50,50,40,0,0,0]],'actors':[],'events':[[1,1,1,1,35]]}
   def exchange():
    q['batch']+=1;return world.exchange(q)
   response=wait_for(lambda:(r if (r:=exchange()).get('ack')==1 and r.get('durableAck')==(1 if committed else 0) else None))
   assert response['ack']==1
   process.kill();process.wait(timeout=5)
   process=subprocess.Popen([exe,d],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
   resync=wait_for(lambda:(r if (r:=exchange()).get('resync') else None))
   assert resync['snapshot']['agents'][0][17]==(65 if committed else 100)
   q['boot']=resync['snapshot']['boot'];assert q['boot']!=first['boot']
   final=wait_for(lambda:(r if not (r:=exchange()).get('resync') and r.get('durableAck')==1 else None))
   time.sleep(.2)
   snap=json.loads((p/'snapshot.json').read_text());assert snap['agents'][0][17]==65
   print('PASS forced process death '+('after' if committed else 'before')+' durable commit, boot fencing, full resync, exactly one resulting hit')
  finally:
   process.kill();process.wait(timeout=5);world.ledger.db.close()
