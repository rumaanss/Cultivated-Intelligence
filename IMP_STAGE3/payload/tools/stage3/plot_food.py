"""Plot measured same-cell edible standing carbon, not synthetic food predictions."""
import argparse,json
from pathlib import Path
import matplotlib;matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm
p=argparse.ArgumentParser();p.add_argument('report',type=Path);p.add_argument('output',type=Path);a=p.parse_args();b=json.loads(a.report.read_text());fig,axs=plt.subplots(2,2,figsize=(12,7),sharex=True,sharey=True)
for diet,title in enumerate(['Accessible bacterial carbon','Accessible microbial-algal carbon']):
 values=[h[8][diet] for h in b['habitat']];positive=[x for x in values if x>0];norm=LogNorm(vmin=max(.01,min(positive)),vmax=max(positive))
 for layer in range(2):
  rows=[h for h in b['habitat']if h[1]==layer];ax=axs[layer,diet];im=ax.scatter([h[2]for h in rows],[h[3]for h in rows],c=[max(.01,h[8][diet])for h in rows],s=42,marker='s',cmap='viridis',norm=norm);ax.set_aspect('equal');ax.set_title(title+' — '+('upper water' if layer==0 else 'bottom layer'));ax.set_xlabel('Simulation X (studs)');ax.set_ylabel('Simulation Y (studs)');ax.set_xlim(0,436);ax.set_ylim(0,212);ax.grid(alpha=.15)
  fig.colorbar(im,ax=ax,label='mmol C per chemistry cell',shrink=.8)
fig.suptitle(f"Stage 3 food distribution at biological day {b['endTick']/600:g}",fontsize=16)
fig.text(.5,.02,'Measured standing food; same-cell diet estimate with algal shelter. Encounter rates, oxygen and handling further limit actual consumption.',ha='center',fontsize=9)
fig.tight_layout(rect=(0,.05,1,.94));a.output.parent.mkdir(parents=True,exist_ok=True);fig.savefig(a.output,dpi=160);plt.close(fig)
