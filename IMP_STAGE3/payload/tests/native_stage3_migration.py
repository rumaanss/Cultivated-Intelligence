"""Run both installed executables; no compiler-specific RNG fixture."""
import argparse,hashlib,json,socket,subprocess,tempfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--original',type=Path,required=True);p.add_argument('--executable',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1]
def hashes(path):return {str(p.relative_to(path)):hashlib.sha256(p.read_bytes()).hexdigest() for p in path.rglob('*') if p.is_file()}
with tempfile.TemporaryDirectory() as tmp:
 tmp=Path(tmp);old=tmp/'pdnarna';new=tmp/'stage3';rb=tmp/'roblox';(rb/'src/server').mkdir(parents=True);(rb/'default.project.json').write_text('{}')
 for d in (old,new):d.mkdir();(d/'planet_habitat.json').write_bytes((root/'contracts/planet_habitat.json').read_bytes())
 def run(exe,d,*args,ok=True):
  with socket.socket() as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
  r=subprocess.run([str(exe.resolve()),'--project-root',str(root),'--roblox-root',str(rb),'--live-dir',str(d),'--port',str(port),'--unpaced',*args],capture_output=True,text=True,timeout=35)
  assert (r.returncode==0)==ok,r.stdout+r.stderr
  return r
 run(a.original,old,'--physiology','--new-world','--seed','43','--ticks','80');before=hashes(old)
 run(a.executable,new,'--migrate-pdnarna',str(old/'physiology.checkpoint.json'),'--ticks','600')
 assert hashes(old)==before,'Migration touched source runtime'
 cp=new/'stage3.checkpoint.json';payload=json.loads(json.loads(cp.read_text())['payload']);assert payload['seed']==43 and payload['model']=='stage3-1' and payload['tick']==600
 day=json.loads((new/'food-days/600.json').read_text());assert day['endTick']==600 and day['startTick']==80 and len(day['habitat'])>0
 run(a.executable,new,'--ticks','610');assert json.loads(json.loads(cp.read_text())['payload'])['tick']==610
 durable=cp.read_bytes();run(a.executable,new,'--new-world','--ticks','620',ok=False);assert cp.read_bytes()==durable
 run(a.executable,new,'--migrate-pdnarna',str(old/'physiology.checkpoint.json'),'--ticks','620',ok=False);assert cp.read_bytes()==durable
 run(a.executable,old,'--new-world','--ticks','0',ok=False);assert hashes(old)==before
 run(a.original,new,'--physiology','--new-world','--ticks','0',ok=False);assert cp.read_bytes()==durable
 run(a.executable,new,'--seed','999','--ticks','620',ok=False);assert cp.read_bytes()==durable
 print('PASS Stage3 native migration, inherited seed, resume, daily boundary report, source/runtime isolation and creation guards')
