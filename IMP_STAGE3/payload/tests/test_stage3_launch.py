"""PowerShell wrapper integration; uses native executable under a temporary project root."""
import argparse,json,socket,subprocess,tempfile,shutil,csv
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--executable',type=Path,required=True);p.add_argument('--pwsh',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory()as tmp:
 d=Path(tmp);shutil.copytree(root/'contracts',d/'contracts');(d/'scripts').mkdir();(d/'planet/src/server').mkdir(parents=True);(d/'planet/default.project.json').write_text('{}');(d/'build/native').mkdir(parents=True)
 shutil.copy2(a.executable,d/'build/native/ci_stage3.exe')
 for name in ('Start-Stage3.ps1','Report-Stage3.ps1'):shutil.copy2(root/'scripts'/name,d/'scripts'/name)
 def ps(script,*args,ok=True):
  r=subprocess.run([str(a.pwsh.resolve()),'-NoProfile','-File',str(d/'scripts'/script),*args],cwd=d,capture_output=True,text=True,timeout=50)
  assert (r.returncode==0)==ok,r.stdout+r.stderr
  return r.stdout
 with socket.socket()as s:s.bind(('127.0.0.1',0));port=str(s.getsockname()[1])
 ps('Start-Stage3.ps1','-Runtime','runtime/test-43','-Seed','43','-NewWorld','-StopTick','600','-Port',port)
 cp=d/'runtime/test-43/stage3.checkpoint.json';payload=json.loads(json.loads(cp.read_text())['payload']);assert payload['seed']==43 and payload['tick']==600
 ps('Start-Stage3.ps1','-Runtime','runtime/test-43','-StopTick','601','-Port',port)
 assert json.loads(json.loads(cp.read_text())['payload'])['tick']==601
 before=cp.read_bytes();ps('Start-Stage3.ps1','-Runtime','runtime/test-43','-NewWorld','-StopTick','602','-Port',port,ok=False);assert cp.read_bytes()==before
 ps('Report-Stage3.ps1','-Runtime','runtime/test-43','-DayEndTick','600')
 rows=list(csv.DictReader((d/'runtime/test-43/food-summary.csv').open(encoding='utf-8-sig')));assert len(rows)==6
 report=json.loads((d/'runtime/test-43/food-days/600.json').read_text())
 for guild,row in enumerate(rows):
  stock=sum(r[4][0] for r in report['rows'] if r[2]==guild)
  assert abs(float(row['RemainingC'])-stock)<1e-6
 access=list(csv.DictReader((d/'runtime/test-43/food-summary.access.csv').open(encoding='utf-8-sig')));assert len(access)==len(report['habitat'])
 assert abs(sum(float(x['BacterialNetProductionCPerDay'])for x in access)-float(rows[2]['NetBiologicalProductionCPerDay']))<1e-6
 assert abs(sum(float(x['MicroalgalNetProductionCPerDay'])for x in access)-sum(float(rows[g]['NetBiologicalProductionCPerDay'])for g in (0,1)))<1e-6
 print('PASS PowerShell single-root new seed, automatic resume seed, overwrite refusal, daily report and exact CSV totals; executed under PowerShell on Linux, not Windows/MSVC')
