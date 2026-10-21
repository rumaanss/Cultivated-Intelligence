"""Export reduced geometry LODs and an animation preview of the actual meshes."""
import copy,json,sys
from pathlib import Path
from PIL import Image
import matplotlib.pyplot as plt
from export_models import MODELS,ASSET,DOC,export,mesh_faces,draw
rows=[]
for d in MODELS:
 low=copy.deepcopy(d);low['key']+='__LOD1'
 low['parts']=[p for p in low['parts'] if p['lod']==1 and p['name']!='Pigment']
 for p in low['parts']:p['meshPigment']=False
 export(low)
 rows.append({'key':d['key'],'heroTriangles':d['meshTriangles'],'lod1Triangles':sum(len(v)-2 for p in low['parts'] for v,c in mesh_faces(low,p)),'nativeParts':d['partCount'],'components':len(d['joints']),'poseBytes':20+2*len(d['joints'])})
(ASSET/'budgets.json').write_text(json.dumps(rows,indent=2)+'\n')
if '--no-preview' not in sys.argv:
 frames=[]
 for n in range(18):
  fig=plt.figure(figsize=(12,4.5),facecolor='#17232c')
  for i,d in enumerate(MODELS[3:]):
   draw(fig.add_subplot(1,3,i+1,projection='3d'),d,n/18,True)
   fig.text((i+.5)/3,.12,d['title'],ha='center',color='#e6e7d8',fontsize=12)
  fig.text(.04,.93,'BODY STUDIES / JOINT MOTION',color='#e6e7d8',fontsize=17,weight='bold')
  fig.text(.04,.035,'Actual exported geometry • procedural motion study • not a Roblox capture',color='#9fb1b3',fontsize=10)
  plt.subplots_adjust(left=0,right=1,bottom=.15,top=.9,wspace=-.1)
  fig.canvas.draw();frames.append(Image.frombuffer('RGBA',fig.canvas.get_width_height(),fig.canvas.buffer_rgba(),'raw','RGBA',0,1).convert('RGB'));plt.close(fig)
 frames[0].save(DOC/'MotionStudy.gif',save_all=True,append_images=frames[1:],duration=85,loop=0,optimize=True)
print(json.dumps(rows,indent=2))
