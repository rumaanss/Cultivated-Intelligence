"""Process restart every 5,000 ticks. Exit nonzero on any invariant/ecology failure."""
import argparse,csv,subprocess,json,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--executable',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--ticks',type=int,default=100000);p.add_argument('--seeds',type=int,nargs='+',default=[1,42,9876]);p.add_argument('--mutation-probabilities',type=float,nargs='+',default=[0,.02]);a=p.parse_args()
a.output.mkdir(parents=True,exist_ok=True)
header='seed,mutation,tick,population,suspended,attached,decomposer,suspendedC,attachedC,decomposerC,births,deaths,mutations,kernel_p95_ms'
for seed in a.seeds:
 for mutation in a.mutation_probabilities:
  name=f'{seed}-'+('mutating' if mutation else 'fixed');checkpoint=a.output/(name+'.json');report=a.output/(name+'.csv')
  start=json.loads(json.loads(checkpoint.read_text())['payload'])['tick'] if checkpoint.exists() else 0
  if not report.exists():report.write_text(header+'\n')
  for tick in range(start+5000,a.ticks+1,5000):
   result=subprocess.run([str(a.executable.resolve()),str(seed),str(tick),str(checkpoint.resolve()),str(mutation),'-1'],capture_output=True,text=True)
   if result.returncode:
    print(result.stdout,result.stderr,flush=True)
    raise RuntimeError(f"Validation process failed: {name} at {tick}")
   line=result.stdout.strip();assert len(next(csv.reader([line])))==14
   with report.open('a') as f:f.write(line+'\n')
   print(line,flush=True)
  rows=list(csv.DictReader(report.open()));assert rows and int(rows[-1]['tick'])==a.ticks
  assert int(rows[-1]['births'])>0 and int(rows[-1]['deaths'])>0
  if mutation:assert int(rows[-1]['mutations'])>0
print('PASS all requested cohorts; checkpoints retained for continuation',flush=True)
