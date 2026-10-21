"""Starts and tests the actual native server in one local process environment."""
import argparse,json,os,signal,socket,subprocess,sys,tempfile,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--executable',type=Path,required=True);p.add_argument('--runtime',type=Path);a=p.parse_args()
root=Path(__file__).resolve().parents[1]
runtime=a.runtime.resolve() if a.runtime else Path(tempfile.mkdtemp(prefix='ci-native-test-'))
runtime.mkdir(parents=True,exist_ok=True)
(runtime/'planet_habitat.json').write_bytes((root/'contracts/planet_habitat.json').read_bytes())
with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
command=[str(a.executable.resolve()),'--headless','--benchmark-ticks','4294967295','--live-dir',str(runtime),'--island-surface',str(root/'contracts/planet_surface.txt'),'--geometry','lake','--optics','v2','--archive-dir',str(runtime/'metrics'),'--port',str(port)]
def run(stop_tick):
 command[command.index("--benchmark-ticks")+1]=str(stop_tick)
 log=open(runtime/'process.log','a');process=subprocess.Popen(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)
 try:
  for _ in range(240):
   if process.poll() is not None:raise RuntimeError((runtime/'process.log').read_text())
   try:
    with socket.create_connection(('127.0.0.1',port),timeout=.1):break
   except OSError:time.sleep(.25)
  subprocess.run([sys.executable,str(root/'tests/native_transport_smoke.py'),'--runtime',str(runtime),'--port',str(port)],check=True,cwd=root,timeout=60,env=dict(os.environ,CI_TEST_KEEPALIVE='1'))
  process.wait(timeout=20)
  assert process.returncode==0, "Native process did not exit cleanly"
 finally:
  if process.poll() is None:
   if os.name=='nt':process.terminate()
   else:process.send_signal(signal.SIGINT)
   try:process.wait(timeout=30)
   except subprocess.TimeoutExpired:process.kill();process.wait()
  log.close()
run(240)
first=json.loads((runtime/'smoke-result.json').read_text())
assert (runtime/'checkpoint.bin').exists(),'No durable checkpoint'
run(480)
second=json.loads((runtime/'smoke-result.json').read_text())
assert second['startTick']>=first['endTick'],'Checkpoint lost progression'
print('PASS: authenticated exchange, bounded views, retry identity, fencing, plants, persistence and restart',runtime)
