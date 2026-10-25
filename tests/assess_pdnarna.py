"""Independent checkpoint accounting and predeclared finite-horizon ecology gates."""
import argparse,csv,hashlib,json,math
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--results',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
NC=16/106;PC=1/106;cases=[]
for seed in (1,42,9876):
 for mutation in (0,.02):
  name=f'{seed}-'+('mutating' if mutation else 'fixed')
  path=a.results/(name+'.json');raw=path.read_bytes();j=json.loads(json.loads(raw)['payload'])
  rows=list(csv.DictReader((a.results/(name+'.csv')).open()))
  assert [int(r['tick']) for r in rows]==list(range(5000,100001,5000)),name+' incomplete segments'
  assert j['tick']==100000 and j['model']=='pdnarna-4' and j['seed']==seed and j['config']['mutationProbability']==mutation
  # Independently sum each element from raw checkpoint arrays, not C++ summary fields.
  carbon=[j['air'][0]];nitrogen=[];phosphorus=[];oxygen=[j['air'][1]]
  for m,light in j['cells']:
   organic=math.fsum(m[k] for k in (5,6,7,8,9,10))
   carbon.extend((m[0],organic));nitrogen.extend((m[1],m[2],organic*NC));phosphorus.extend((m[3],m[11],organic*PC));oxygen.append(m[4])
  counts=[0,0,0]
  for c in j['colonies']:
   counts[c[6]]+=1;s=c[8];nucleic=c[9]+math.fsum(c[11]);protein=math.fsum(c[12]);reserve=c[10]
   carbon.extend((s,nucleic,protein,reserve[0]));nitrogen.extend((s*NC,nucleic*.4,protein*.25,reserve[1]));phosphorus.extend((s*PC,nucleic*.1,reserve[2]))
  for c,n,p in j['detritus']:carbon.append(c);nitrogen.append(n);phosphorus.append(p)
  totals=[math.fsum(v) for v in (carbon,nitrogen,phosphorus,oxygen)]
  expected=j['initial'][:3]+[j['initial'][3]+j['flux'][8]]
  residual=[x-y for x,y in zip(totals,expected)]
  ledger=all(abs(r)<=1e-8*max(1,abs(v)) for r,v in zip(residual,expected))
  photon=j['flux'][10]<=j['flux'][9]*(1+1e-10)
  roots={}
  for gid,parent,ploidy,copies in j['genomes']:roots[gid]=roots[parent] if parent else gid
  births=[0,0,0];deaths=[0,0,0]
  for rid,parent,gid,born,died,generation in j['ancestry']:
   guild=roots[gid]-1
   if parent and born>80000:births[guild]+=1
   if died>80000:deaths[guild]+=1
  late=next(r for r in rows if int(r['tick'])==80000);last=rows[-1]
  biomassRatio=[float(last[k])/float(late[k]) for k in ('suspendedC','attachedC','decomposerC')]
  lateRows=[r for r in rows if int(r['tick'])>=80000]
  biomassRangeRatio=[max(float(r[k]) for r in lateRows)/min(float(r[k]) for r in lateRows) for k in ('suspendedC','attachedC','decomposerC')]
  turnoverRatio=[b/d if d else None for b,d in zip(births,deaths)]
  gates={
   'independentElementLedger':ledger,'photonLedger':photon,
   'allGuildsAtLeast50Colonies':min(counts)>=50,
   'noPopulationCap':all(int(r['population'])<j['config']['maximumColonies'] for r in rows),
   'lateBiomassWithinFactor1_5':all(r<=1.5 for r in biomassRangeRatio),
   'lateTurnoverWithinFactor2':all(r is not None and .5<=r<=2 for r in turnoverRatio),
   'birthsAndDeaths':j['events'][0]>0 and j['events'][1]>0,
   'mutationMode':j['events'][2]>0 if mutation else j['events'][2]==0,
  }
  cases.append({'name':name,'seed':seed,'mutationProbability':mutation,'tick':j['tick'],'population':len(j['colonies']),'guildCounts':counts,'events':j['events'],'lateBirths':births,'lateDeaths':deaths,'lateBirthDeathRatio':turnoverRatio,'lateBiomassRatio':biomassRatio,'lateBiomassRangeRatio':biomassRangeRatio,'independentResidual':residual,'checkpointSha256':hashlib.sha256(raw).hexdigest(),'gates':gates,'passed':all(gates.values())})
summary={'model':'pdnarna-4','ticksPerCase':100000,'cases':cases,'passed':all(c['passed'] for c in cases),'meaning':'Finite-horizon engineering acceptance, not proof of indefinite ecological equilibrium or species calibration. Late window is ticks 80000–100000. Kernel timings in cohort CSVs were collected under concurrent workload and are not isolated benchmarks.'}
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(summary,indent=2)+'\n')
for c in cases:print(c['name'],c['guildCounts'],'late biomass',c['lateBiomassRatio'],'birth/death',c['lateBirthDeathRatio'],'PASS' if c['passed'] else 'FAIL')
raise SystemExit(0 if summary['passed'] else 1)
