"""Report observed finite-trial gates without calling persistence perpetual stability."""
import argparse,json,statistics
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--results',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--end-tick',type=int,default=60000);p.add_argument('--window-start',type=int,default=30000);a=p.parse_args();mid=(a.window_start+a.end_tick)//2;a.output.mkdir(parents=True,exist_ok=True)
summaries=[];series=[]
for path in sorted(a.results.glob('*.jsonl')):
 rows={};timing=[]
 for line in path.read_text().splitlines():
  try:r=json.loads(line)
  except ValueError:continue
  if 'counts' in r and r['tick']<=a.end_tick:rows[r['tick']]=r
  if 'p95StepMs' in r:timing.append(r)
 data=[rows[k] for k in sorted(rows)];last=data[-1];early=min(data,key=lambda r:abs(r['tick']-a.window_start));late=[r for r in data if r['tick']>=a.window_start]
 guild_delta=[x-y for x,y in zip(last['guildBirths'],early['guildBirths'])];form_delta=[x-y for x,y in zip(last.get('formBirths',[0]*4),early.get('formBirths',[0]*4))]
 first=[r for r in late if r['tick']<mid];second=[r for r in late if r['tick']>=mid]
 ratios=[statistics.mean(r['biomass'][g] for r in second)/statistics.mean(r['biomass'][g] for r in first) for g in range(6)] if first and second else []
 gates={'completedRequestedDuration':last['tick']>=a.end_tick,'allGuildsPersist':all(min(r['counts'])>0 for r in data),'allAlgalFormsPersist':all(min(r['forms'])>0 for r in data),'belowRecordCap':max(sum(r['counts']) for r in data)<50000,'foodLedgersClose':max(max(r['ledger']) for r in data)<1e-6,'allGuildsReproduceLate':min(guild_delta)>0,'allAlgalFormsReproduceLate':min(form_delta)>0,'lateMeanBiomassWithinFactorTwo':bool(ratios) and all(.5<=v<=2 for v in ratios)}
 summaries.append({'case':path.stem,'seed':last['seed'],'mutation':last['mutation'],'endTick':last['tick'],'gates':gates,'allGatesPass':all(gates.values()),'maximumRecords':max(sum(r['counts']) for r in data),'maximumLocalLedgerResidual':max(max(r['ledger']) for r in data),'finalCounts':last['counts'],'finalForms':last['forms'],'lateGuildBirths':guild_delta,'lateFormBirths':form_delta,'lateMeanBiomassRatios':ratios,'finalBiomass':last['biomass'],'timing':timing})
 series.append((path.stem,data))
(a.output/'ecology-summary.json').write_text(json.dumps({'status':'finite observation; not proof of permanent stability','endTick':a.end_tick,'windowStart':a.window_start,'trials':summaries},indent=2)+'\n')
import matplotlib;matplotlib.use('Agg')
import matplotlib.pyplot as plt
names=['Suspended producers','Attached films','Bacteria','Bacterial grazers','Microalgal grazers','Algal habitat'];colors=['#4b9c71','#2f7148','#9e8456','#bd7c3f','#428d9e','#517779']
fig,axs=plt.subplots(2,len(series),figsize=(14,7),squeeze=False,sharex=True)
for col,(name,data) in enumerate(series):
 x=[r['tick']/600 for r in data]
 for g in range(6):axs[0,col].plot(x,[r['biomass'][g] for r in data],label=names[g],color=colors[g]);axs[1,col].plot(x,[r['counts'][g] for r in data],color=colors[g])
 axs[0,col].set_title(name);axs[0,col].set_yscale('log');axs[1,col].set_xlabel('Biological days')
 for ax in axs[:,col]:ax.grid(alpha=.2)
axs[0,0].set_ylabel('Living carbon (mmol C, log scale)');axs[1,0].set_ylabel('Cohort records (not individual cells)')
fig.legend(*axs[0,0].get_legend_handles_labels(),loc='lower center',ncol=3,frameon=False);fig.suptitle('Stage 3 native ecology — measured trajectories');fig.tight_layout(rect=(0,.1,1,.95));fig.savefig(a.output/'ecology-trajectories.png',dpi=160);plt.close(fig)
print(json.dumps(summaries,indent=2))
