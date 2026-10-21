"""Reproducible workload measurements; not an evolution-success benchmark."""
import json,subprocess,tempfile,time,sys
from pathlib import Path
binary=Path(sys.argv[1]).resolve();result=[]
for policy,founders,ticks,rain,light in [('wait',24,300,0,1),('neural',24,600,.025,1),('baseline',24,600,.025,1),('baseline',128,300,.025,.4)]:
 with tempfile.TemporaryDirectory() as directory:
  start=time.perf_counter();run=subprocess.run([str(binary),'--directory',directory,'--policy',policy,'--founders',str(founders),'--ticks',str(ticks),'--rain',str(rain),'--light',str(light),'--seed','731'],capture_output=True,text=True,check=True)
  elapsed=time.perf_counter()-start;s=json.loads((Path(directory)/'plants.json').read_text())
  result.append(dict(policy=policy,founders=founders,ticks=ticks,light=light,rain=rain,wallSeconds=elapsed,msPerStep=elapsed*1000/ticks,finalPlants=len(s['plants']),organs=sum(len(p['organs']) for p in s['plants']),snapshotBytes=(Path(directory)/'plants.json').stat().st_size,checkpointBytes=(Path(directory)/'plants.checkpoint').stat().st_size))
print(json.dumps(result,indent=2))
if len(sys.argv)>2:Path(sys.argv[2]).write_text(json.dumps(result,indent=2)+'\n')
