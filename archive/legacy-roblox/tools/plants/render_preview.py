from pathlib import Path
import json,math
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
ROOT=Path(__file__).resolve().parents[2]
geometry=json.loads((ROOT/'assets/plants/showcase_geometry.json').read_text())
box=np.array([[-.5,-.5,-.5],[.5,-.5,-.5],[.5,.5,-.5],[-.5,.5,-.5],[-.5,-.5,.5],[.5,-.5,.5],[.5,.5,.5],[-.5,.5,.5]])
faces=[[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[0,1,5,4],[3,7,6,2]]
fig=plt.figure(figsize=(14,7),facecolor='#152622')
names=['PIONEER SHRUB','CANOPY TREE','DRYLAND PLANT']
for species in range(3):
 ax=fig.add_subplot(1,3,species+1,projection='3d');polygons=[];colors=[];parts=0
 for piece in geometry:
  a=piece['values']
  if int(a[0])!=species:continue
  parts+=1;size=np.array(a[2:5]);p=np.array(a[5:8]);r=np.array(a[8:17]).reshape(3,3);color=np.array(a[17:20])
  if piece['shape']=='Wedge':v=box[[0,1,4,5,7,6]];fs=[[0,2,4],[1,5,3],[0,1,3,2],[2,3,5,4],[0,4,5,1]]
  elif piece['shape']=='Ball':
   v=[];fs=[]
   for y in range(7):
    theta=math.pi*y/6
    for x in range(10):v.append([math.sin(theta)*math.cos(2*math.pi*x/10)*.5,math.cos(theta)*.5,math.sin(theta)*math.sin(2*math.pi*x/10)*.5])
   for y in range(6):
    for x in range(10):fs.append([y*10+x,y*10+(x+1)%10,(y+1)*10+(x+1)%10,(y+1)*10+x])
   v=np.array(v)
  else:v=box;fs=faces
  v=(v*size)@r.T+p
  for f in fs:
   poly=v[f];n=np.cross(poly[1]-poly[0],poly[2]-poly[0]);n/=max(np.linalg.norm(n),1e-10);shade=.67+.33*max(0,np.dot(n,[-.3,.8,-.5]));polygons.append(poly[:,[0,2,1]]);colors.append(color*shade)
 pts=np.concatenate(polygons);lo=pts.min(0);hi=pts.max(0);center=(lo+hi)/2;extent=max(hi-lo)*.62
 ax.add_collection3d(Poly3DCollection(polygons,facecolors=colors,edgecolors='none'))
 ax.set_xlim(center[0]-extent,center[0]+extent);ax.set_ylim(center[1]-extent,center[1]+extent);ax.set_zlim(center[2]-extent,center[2]+extent)
 ax.set_box_aspect([1,1,1]);ax.set_axis_off();ax.set_facecolor('#152622');ax.view_init(elev=18,azim=-60);ax.set_proj_type('ortho')
 fig.text((species+.5)/3,.17,names[species],ha='center',color='#dfebd2',fontsize=16,weight='bold')
 fig.text((species+.5)/3,.12,f'{parts} native pieces · authored growth specimen',ha='center',color='#9db1a1',fontsize=10)
fig.text(.04,.92,'CULTIVATED INTELLIGENCE / LIVING PLANTS',color='#e7eedb',fontsize=24,weight='bold')
fig.text(.04,.86,'Reusable geometry • inherited palettes • stable organ attachments',color='#9db1a1',fontsize=12)
fig.text(.04,.035,'Rendered from the real Lua asset descriptors / explicit authored growth policy / not a Studio capture or neural evolution result',color='#9db1a1',fontsize=10)
plt.subplots_adjust(left=0,right=1,top=.81,bottom=.2,wspace=-.05)
fig.savefig(ROOT/'docs/plants/PlantGrowthPreview.png',dpi=150,facecolor=fig.get_facecolor())
print('Saved geometry-derived plant preview')
