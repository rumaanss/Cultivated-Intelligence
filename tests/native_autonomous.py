"""Developer-only test of unattended native execution and worker determinism."""
import argparse,csv,socket,subprocess,tempfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--executable',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1]
hashes=[]
with tempfile.TemporaryDirectory(prefix='ci-autonomous-') as temporary:
 for workers in (1,4):
  runtime=Path(temporary)/str(workers);runtime.mkdir()
  (runtime/'planet_habitat.json').write_bytes((root/'contracts/planet_habitat.json').read_bytes())
  with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
  command=[str(a.executable.resolve()),'--headless','--benchmark-ticks','12','--autonomous','--unpaced','--workers',str(workers),'--port',str(port),'--live-dir',str(runtime),'--island-surface',str(root/'contracts/planet_surface.txt'),'--geometry','lake','--optics','v2','--archive-dir',str(runtime/'metrics')]
  result=subprocess.run(command,cwd=root,capture_output=True,text=True,timeout=40)
  assert result.returncode==0,result.stdout+result.stderr
  metrics=next(csv.DictReader(max((runtime/'metrics').rglob('performance_metrics.csv'),key=lambda p:p.stat().st_mtime_ns).read_text().splitlines()))
  assert metrics['executed_ticks']=='12',metrics
  hashes.append(metrics['population_state_hash'])
  assert (runtime/'checkpoint.bin').exists()
  command[command.index('--benchmark-ticks')+1]='24'
  result=subprocess.run(command,cwd=root,capture_output=True,text=True,timeout=40)
  assert result.returncode==0,result.stdout+result.stderr
  metrics=next(csv.DictReader(max((runtime/'metrics').rglob('performance_metrics.csv'),key=lambda p:p.stat().st_mtime_ns).read_text().splitlines()))
  assert metrics['executed_ticks']=='12',metrics
assert hashes[0]==hashes[1],hashes
print('PASS unattended headless execution, exact resume, and 1/4-worker state equivalence')
