"""Offline developer test; no Python in the live transport or simulation."""
import argparse,json,socket,subprocess,tempfile,time,urllib.request,urllib.error,statistics
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--executable',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='ci-inspection-http-') as tmp:
 d=Path(tmp);runtime=d/'runtime';runtime.mkdir();(runtime/'planet_habitat.json').write_bytes((root/'contracts/planet_habitat.json').read_bytes())
 roblox=d/'planet';(roblox/'src/server').mkdir(parents=True);(roblox/'default.project.json').write_text('{}')
 with socket.socket() as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
 args=[str(a.executable.resolve()),'--project-root',str(root),'--live-dir',str(runtime),'--roblox-root',str(roblox),'--port',str(port),'--new-world','--ticks','60','--sensor-mode','scene']
 with (d/'log').open('w') as log:
  proc=subprocess.Popen(args,stdout=log,stderr=subprocess.STDOUT)
  try:
   for _ in range(150):
    assert proc.poll() is None,(d/'log').read_text()
    try:
     key=(runtime/'native.token').read_text().strip()
     with socket.create_connection(('127.0.0.1',port),timeout=.1):break
    except OSError:time.sleep(.05)
   def post(route,q,token=None):
    req=urllib.request.Request(f'http://127.0.0.1:{port}{route}',json.dumps(q).encode(),headers={'X-CI-Token':key if token is None else token,'Content-Type':'application/json'})
    with urllib.request.urlopen(req,timeout=5) as r:return json.load(r)
   s=post('/sensing',{'schema':1});assert s['reset']
   envelope={'schema':1,'run':s['run'],'boot':s['boot'],'host':'test-server'}
   one=post('/inspection',dict(envelope,id=1));assert one['individual']['biological']=='alive'
   time.sleep(.15);assert post('/sensing',envelope)['tick']==0,'Missing sensor must pause biology'
   try:post('/sensing',envelope,token='bad');raise AssertionError('Unauthorized sensor')
   except urllib.error.HTTPError as e:assert e.code==401
   exchange={'protocol':1,'session':'inspection-test','run':'','observer':{'version':1,'regions':[{'center':[x,100,90],'limit':24} for x in [50,150,250,350]]}}
   for _ in range(50):
    try:r=post('/exchange',exchange);break
    except urllib.error.HTTPError:time.sleep(.05)
   exchange.update(run=r['manifest']['runId'],boot=r['snapshot']['boot'],batch=1,ackBatch=0,poses=[],actors=[],events=[],aquaticToken='')
   timings=[];applied=set()
   deadline=time.monotonic()+20
   while proc.poll() is None and time.monotonic()<deadline:
    s=post('/sensing',envelope)
    pending=s.get('pending')
    if pending and pending['request'] not in applied:
     obs={k:pending[k] for k in ['run','boot','request','tick','habitat','optics']};obs.update(schema=1,scene='controlled-test',visibility=[.5]*len(pending['points']),geometry={'passed':True,'scope':'test fixture, not Studio'})
     wrong=dict(obs,visibility=[])
     try:post('/sensing',dict(envelope,observation=wrong));raise AssertionError('Incomplete sample accepted')
     except urllib.error.HTTPError as e:assert e.code==409
     ack=post('/sensing',dict(envelope,observation=obs));assert ack['accepted']==pending['request'];applied.add(pending['request'])
    r=post('/exchange',exchange);timings.append(r['relayTimingMs'][2]);exchange['ackBatch']=exchange['batch'];exchange['batch']+=1
    if 'aquatic' in r:exchange['aquaticToken']=r['aquatic']['token']
    time.sleep(.1)
   proc.wait(timeout=5);assert proc.returncode==0,(d/'log').read_text()
  except urllib.error.URLError as error:
   # The finite native process may close its listener between poll and POST.
   assert not isinstance(error,urllib.error.HTTPError),str(error)
   proc.wait(timeout=2);assert proc.returncode==0,(d/'log').read_text()
  finally:
   if proc.poll() is None:proc.terminate();proc.wait(timeout=10)
 saved=json.loads(json.loads((runtime/'stage3.checkpoint.json').read_text())['payload'])
 assert saved['tick']==60 and len(applied)==6
 records=[json.loads(x) for x in next(runtime.glob('scene-observations-*.jsonl')).read_text().splitlines()]
 assert [x['applyTick'] for x in records]==list(range(0,60,10))
 assert saved['sceneTransmission']==[.575]*len(saved['sceneTransmission'])
 print('PASS executable scene pause/resume, bounded input, auth, records and four-observer exchange')
 print(json.dumps({'exchanges':len(timings),'medianMs':statistics.median(timings),'p95Ms':sorted(timings)[int(.95*(len(timings)-1))],'maxMs':max(timings)}))
