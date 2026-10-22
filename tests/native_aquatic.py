"""Developer-only acceptance: actual native HTTP + durable aquatic scenario. No Python runtime."""
import argparse,json,socket,subprocess,tempfile,time,urllib.request,urllib.error
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--executable',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='ci-aquatic-') as tmp:
 runtime=Path(tmp)/'runtime';runtime.mkdir()
 (runtime/'planet_habitat.json').write_bytes((root/'contracts/planet_habitat.json').read_bytes())
 roblox=Path(tmp)/'planet';(roblox/'src/server').mkdir(parents=True);(roblox/'default.project.json').write_text('{}')
 with socket.socket() as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
 base=[str(a.executable.resolve()),'--project-root',str(root),'--live-dir',str(runtime),'--roblox-root',str(roblox),'--port',str(port),'--seed','42']
 logpath=Path(tmp)/'log.txt'
 with logpath.open('w') as log:
  proc=subprocess.Popen(base+['--new-world','--ticks','120'],stdout=log,stderr=subprocess.STDOUT)
  try:
   for _ in range(150):
    if proc.poll() is not None:raise AssertionError(logpath.read_text())
    try:
     key=(runtime/'native.token').read_text().strip()
     with socket.create_connection(('127.0.0.1',port),timeout=.1):break
    except (OSError,FileNotFoundError):time.sleep(.05)
   def post(q,token=key):
    req=urllib.request.Request(f'http://127.0.0.1:{port}/exchange',json.dumps(q).encode(),headers={'X-CI-Token':token,'Content-Type':'application/json'})
    with urllib.request.urlopen(req,timeout=2) as response:return json.load(response)
   q={'protocol':1,'session':'aquatic-test','run':'','observer':{'version':1,'regions':[{'center':[200,100,90],'limit':24,'selected':0}]}}
   # The native publisher encodes initial state asynchronously.
   for _ in range(50):
    try:r=post(q);break
    except urllib.error.HTTPError as e:
     assert e.code==503
     time.sleep(.05)
   assert r['reset']
   q.update(run=r['manifest']['runId'],boot=r['snapshot']['boot'],batch=1,ackBatch=0,poses=[],actors=[],events=[],plants={'schema':1},aquaticToken='')
   r=post(q);assert not r.get('resync')
   packet=r['aquatic'];assert 0<len(packet['patches'])<=24
   assert packet['run']==q['run'] and all(len(row)==16 for row in packet['patches'])
   assert r['total']==0 and r['plants']['upsert']==[] and r['plants']['surface'].startswith('planet-')
   assert all(abs(v)<.1 for v in packet['residual'])
   assert len(json.dumps(r))<48*1024
   print('Aquatic selected patches:',len(packet['patches']),'exchange bytes:',len(json.dumps(r)),'native work ms:',r['relayTimingMs'][2])
   assert post(q)==r,'retry must be idempotent'
   q.update(batch=2,ackBatch=1,aquaticToken=packet['token'])
   r=post(q)
   # Same snapshot token suppresses repeated bulk data; new snapshots may race this check.
   if 'aquatic' in r:assert r['aquatic']['token']!=packet['token']
   q.update(batch=3,ackBatch=2);q['observer']['regions'][0]['center']=[900,900,900]
   r=post(q);assert r['aquatic']['patches']==[],'interest exit must clear'
   q.update(batch=4,ackBatch=3);q['observer']['regions']=[{'center':[x,100,80],'limit':24} for x in [50,150,250,350]]
   r=post(q);assert len(r['aquatic']['patches'])<=96
   try:post(q,token='bad');raise AssertionError('accepted unauthenticated')
   except urllib.error.HTTPError as e:assert e.code==401
   proc.wait(timeout=15);assert proc.returncode==0,logpath.read_text()
  finally:
   if proc.poll() is None:proc.terminate();proc.wait(timeout=10)
 def checkpoint():return json.loads(json.loads((runtime/'aquatic.checkpoint.json').read_text())['payload'])
 assert checkpoint()['tick']==120
 result=subprocess.run(base+['--ticks','240','--unpaced'],capture_output=True,text=True,timeout=15)
 assert result.returncode==0,result.stdout+result.stderr
 assert checkpoint()['tick']==240
 result=subprocess.run(base+['--new-world','--ticks','260'],capture_output=True,text=True,timeout=15)
 assert result.returncode!=0 and checkpoint()['tick']==240,'new-world must not overwrite'
 # Legacy state must never be read or destroyed by this scenario.
 (runtime/'checkpoint.bin').write_bytes(b'preserve legacy')
 result=subprocess.run(base+['--ticks','260'],capture_output=True,text=True,timeout=15)
 assert result.returncode!=0 and (runtime/'checkpoint.bin').read_bytes()==b'preserve legacy'
 print('PASS aquatic native exchange, bounded views, retry, authentication, exact resume and runtime isolation')
