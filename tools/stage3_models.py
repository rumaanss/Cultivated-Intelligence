"""Deterministic, authored mesh kit; glTF/OBJ and Roblox native triangle data agree."""
from pathlib import Path
import math,json,struct,base64
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/stage3';OUT.mkdir(parents=True,exist_ok=True)
def mesh():return {'vertices':[],'faces':[],'colors':[]}
def vertex(m,p):m['vertices'].append(list(map(float,p)));return len(m['vertices'])-1
def face(m,a,b,c,color):
 if np.linalg.norm(np.cross(np.array(m['vertices'][b])-m['vertices'][a],np.array(m['vertices'][c])-m['vertices'][a]))>1e-9:
  m['faces'].append([a,b,c]);m['colors'].append(color)
def tube(m,points,radius,color,sides=5):
 rings=[]
 for i,p in enumerate(points):
  p=np.array(p);t=np.array(points[min(i+1,len(points)-1)])-np.array(points[max(i-1,0)]);t=t/np.linalg.norm(t)
  ref=np.array([0.,1.,0.]) if abs(t[1])<.9 else np.array([1.,0.,0.]);u=np.cross(t,ref);u/=np.linalg.norm(u);v=np.cross(t,u)
  rings.append([vertex(m,p+(u*math.cos(a*2*math.pi/sides)+v*math.sin(a*2*math.pi/sides))*radius*(1-.75*i/max(1,len(points)-1))) for a in range(sides)])
 for i in range(len(rings)-1):
  for j in range(sides):
   a,b,c,d=rings[i][j],rings[i][(j+1)%sides],rings[i+1][j],rings[i+1][(j+1)%sides];face(m,a,b,c,color);face(m,b,d,c,color)
def grazer(kind,detail):
 m=mesh();n=24 if detail else 8;r=10 if detail else 4;rings=[]
 phases=[math.pi*i/r for i in range(r+1)]
 if kind==1:phases=([0,.3,.6,.9,1.2,1.4,1.57,1.75,2.05,2.4,2.75,math.pi] if detail else [0,.8,1.4,1.57,1.8,2.5,math.pi]);r=len(phases)-1
 copper=[164,126,62];moss=[96,116,64];teal=[65,137,139];plum=[103,69,85]
 for i in range(r+1):
  phi=phases[i];ring=[]
  for j in range(n):
   theta=2*math.pi*j/n
   shape=1+.09*math.cos(3*theta)+.07*math.sin(theta) if kind==0 else 1+.05*math.sin(theta)
   notch=1-(.38 if kind==0 else .23)*math.exp(-((theta-1.5*math.pi)/.65)**2)*math.sin(phi)**4
   x=math.sin(phi)*math.cos(theta)*shape*notch*(1 if kind==0 else .92)
   z=math.sin(phi)*math.sin(theta)*shape*notch*(.9 if kind==0 else 1.5)
   y=math.cos(phi)*(.5 if kind==0 else .55)
   if kind==1:
    # A real recessed equatorial feeding belt between two curved lips.
    waist=1-.28*math.exp(-((phi-math.pi/2)/.09)**2)
    x*=waist;z*=waist
    y+=.045*math.sin(theta*2)*math.sin(phi)
   ring.append(vertex(m,[x,y,z]))
  rings.append(ring)
 for i in range(r):
  for j in range(n):
   color=(moss if i<r*.35 else copper) if kind==0 else (teal if i<r*.6 else plum)
   # Warm rim, organic mottling and a dark recessed feeding groove.
   blend=(math.sin(j*2.4+i*.7)*.5+.5)*.24
   accent=[184,151,77] if kind==0 else [110,167,151]
   color=[int(a*(1-blend)+b*blend) for a,b in zip(color,accent)]
   if i>=r*.75:color=[61,75,48] if kind==0 else plum
   if kind==1:
    color=([56,143,151] if phases[i]<1.4 else [111,179,161] if phases[i]<1.5 else [36,69,72] if phases[i]<1.75 else [109,70,88])
    color=[min(255,int(c*(.85+.3*(math.sin(j*12.989+i*7.13)*.5+.5)))) for c in color]
   elif abs(j/n*2*math.pi-1.5*math.pi)<.65 and r*.35<=i<r*.8:color=[63,71,42]
   a,b,c,d=rings[i][j],rings[i][(j+1)%n],rings[i+1][j],rings[i+1][(j+1)%n];face(m,a,b,c,color);face(m,b,d,c,color)
 if detail:
  for j in range(14 if kind==0 else 32):
   theta=2*math.pi*j/(14 if kind==0 else 32);x=math.cos(theta)*(1 if kind==0 else .92);z=math.sin(theta)*(.9 if kind==0 else 1.5)
   if kind==1:tube(m,[[x*.77,.01,z*.77],[x*.97,-.06,z*.97],[x*1.10,-.16,z*1.10]],.018,[204,207,156],4)
   else:tube(m,[[x,-.12,z],[x*1.08,-.20,z*1.08],[x*1.17,-.31,z*1.17]],.022,[187,176,110],4)
 return m
def blade(form,detail):
 m=mesh();steps=10 if detail else 3;cross=4 if detail else 2;grid=[]
 for i in range(steps+1):
  t=i/steps;row=[]
  for j in range(cross+1):
   u=2*j/cross-1
   width=(.18+.82*math.sin(math.pi*(.05+.9*t)))
   if form=='Fan':width*=.25+1.65*t
   x=u*width*.5;y=t;z=.17*math.sin(t*math.pi*1.6)+.13*u*u*math.sin(t*math.pi*2)
   if form=='Ribbon':x+=.11*math.sin(t*math.pi*2);z+=.18*u*math.sin(t*math.pi*1.7)
   if form=='Fan':y=t*(.72+.28*math.sqrt(max(0,1-u*u)));z+=.09*math.cos(u*math.pi*4)*t
   if form=='Sheet':x=u*.5;y=.12*math.sin(t*math.pi*2+u*1.6)+.10*u*u;z=t
   row.append(vertex(m,[x,y,z]))
  grid.append(row)
 for i in range(steps):
  for j in range(cross):
   color=[55+int(i/steps*24),113+int(i/steps*25),91]
   a,b,c,d=grid[i][j],grid[i][j+1],grid[i+1][j],grid[i+1][j+1];face(m,a,b,c,color);face(m,b,d,c,color)
 return m
def filament(detail):
 m=mesh();steps=6 if detail else 2
 tube(m,[[.12*math.sin(i/steps*3),i/steps,0] for i in range(steps+1)],.065,[105,145,82],6 if detail else 4)
 return m
def holdfast(detail):
 m=mesh();n=8 if detail else 4
 for i in range(n):
  t=i/n*math.pi*2;tube(m,[[0,.12,0],[.18*math.cos(t),.05,.18*math.sin(t)],[.4*math.cos(t),0,.4*math.sin(t)]],.06,[88,101,58],4)
 return m
def append_mesh(dst,src,scale=(1,1,1),angle=0,offset=(0,0,0),tilt=0):
 start=len(dst['vertices']);co,si=math.cos(angle),math.sin(angle)
 for p in src['vertices']:
  x,y,z=[p[i]*scale[i] for i in range(3)]
  x,y=x*math.cos(tilt)-y*math.sin(tilt),x*math.sin(tilt)+y*math.cos(tilt)
  vertex(dst,[x*co+z*si+offset[0],y+offset[1],-x*si+z*co+offset[2]])
 for f,c in zip(src['faces'],src['colors']):dst['faces'].append([i+start for i in f]);dst['colors'].append(c)
def assembled(form,variant=0):
 m=mesh();append_mesh(m,holdfast(True),scale=(1.1,.7,1.1))
 count=5 if form!='Filament' else 11
 for i in range(count):
  theta=i*2.399963;length=(1.5+.25*(i%3))*(.7 if variant else 1);width=(.32 if form=='Ribbon' else .65 if form=='Fan' else .25 if form=='Filament' else 1.1)*(1.4 if variant else 1)
  if form=='Sheet':length=1.2+.16*i
  unit=filament(True) if form=='Filament' else blade(form,True)
  offset=(.22*math.cos(theta),.02,.22*math.sin(theta))
  append_mesh(m,unit,(width,length,width if form!='Sheet' else length),theta,offset,tilt=(i%3-1)*.24)
  if form in ('Filament','Fan'):
   append_mesh(m,unit,(width*.6,length*.55,width*.6),theta+.7,(offset[0]+.12,.5*length,offset[2]),tilt=.55 if i%2 else -.55)
 return m
def export(name,m):
 # Duplicate face vertices for precise per-face colors and reliable flat normals.
 pos=[];norm=[];colors=[]
 for f,c in zip(m['faces'],m['colors']):
  pts=[np.array(m['vertices'][i]) for i in f];normal=np.cross(pts[1]-pts[0],pts[2]-pts[0]);normal/=np.linalg.norm(normal)
  for p in pts:pos.extend(p);norm.extend(normal);colors.extend([x/255 for x in c]+[1.])
 streams=[np.array(pos,dtype='<f4').tobytes(),np.array(norm,dtype='<f4').tobytes(),np.array(colors,dtype='<f4').tobytes()];data=b''.join(streams);views=[];offset=0
 for stream in streams:views.append({'buffer':0,'byteOffset':offset,'byteLength':len(stream),'target':34962});offset+=len(stream)
 count=len(pos)//3;positions=np.array(pos).reshape(-1,3)
 access=[{'bufferView':0,'componentType':5126,'count':count,'type':'VEC3','min':positions.min(axis=0).tolist(),'max':positions.max(axis=0).tolist()},
         {'bufferView':1,'componentType':5126,'count':count,'type':'VEC3'},{'bufferView':2,'componentType':5126,'count':count,'type':'VEC4'}]
 doc={'asset':{'version':'2.0','generator':'Cultivated Intelligence Stage3 deterministic mesh kit'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0,'name':name}],
      'meshes':[{'primitives':[{'attributes':{'POSITION':0,'NORMAL':1,'COLOR_0':2},'material':0}]}],
      'materials':[{'name':'Biological pigments','doubleSided':True,'pbrMetallicRoughness':{'metallicFactor':0,'roughnessFactor':.9}}],
      'buffers':[{'byteLength':len(data),'uri':'data:application/octet-stream;base64,'+base64.b64encode(data).decode()}],'bufferViews':views,'accessors':access}
 (OUT/(name+'.gltf')).write_text(json.dumps(doc,separators=(',',':')))
 (OUT/(name+'.obj')).write_text('# Stage 3 authored mesh; use glTF for pigments\n'+''.join('v '+' '.join(f'{v:.7g}' for v in p)+'\n' for p in m['vertices'])+''.join('f '+' '.join(str(v+1) for v in f)+'\n' for f in m['faces']))
 return {'vertices':len(m['vertices']),'triangles':len(m['faces'])}
def lua(v):
 if isinstance(v,dict):return '{'+','.join('['+json.dumps(k)+']='+lua(x) for k,x in v.items())+'}'
 if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
 return str(round(v,7)) if isinstance(v,float) else str(v)
def main():
 low={};stats={}
 for name,fn in [('BacterialGrazer',lambda d:grazer(0,d)),('MicroalgalGrazer',lambda d:grazer(1,d)),('Ribbon',lambda d:blade('Ribbon',d)),('Fan',lambda d:blade('Fan',d)),('Sheet',lambda d:blade('Sheet',d)),('Filament',filament),('Holdfast',holdfast)]:
  high=fn(True);stats[name]=export(name,high);low[name]=fn(False);stats[name]['nativeTriangles']=len(low[name]['faces'])
  assert all(np.isfinite(p).all() for p in np.array(high['vertices']))
 for form in ('Ribbon','Fan','Filament','Sheet'):
  for v in range(2):stats[form+'Habitat'+str(v+1)]=export(form+'Habitat'+str(v+1),assembled(form,v))
 (OUT/'mesh-manifest.json').write_text(json.dumps(stats,indent=2)+'\n')
 (ROOT/'planet/src/biology/shared/Stage3MeshData.lua').write_text('--!nonstrict\n-- Generated by tools/stage3_models.py; zero external asset dependencies.\nreturn '+lua(low)+'\n')
 # Actual exported geometry preview, not an image-generated mock-up.
 import matplotlib;matplotlib.use('Agg')
 import matplotlib.pyplot as plt
 from mpl_toolkits.mplot3d.art3d import Poly3DCollection
 fig=plt.figure(figsize=(14,8),facecolor='#edf0ee')
 for i,(name,fn) in enumerate([('Bacterial grazer',lambda:grazer(0,True)),('Microalgal grazer',lambda:grazer(1,True)),('Ribbon habitat',lambda:assembled('Ribbon')),('Fan habitat',lambda:assembled('Fan')),('Filament habitat',lambda:assembled('Filament')),('Sheet habitat',lambda:assembled('Sheet'))]):
  ax=fig.add_subplot(2,3,i+1,projection='3d');m=fn();v=np.array(m['vertices']);v=v[:,[0,2,1]];polys=[[v[k] for k in f] for f in m['faces']]
  ax.add_collection3d(Poly3DCollection(polys,facecolors=np.array(m['colors'])/255,edgecolors='none'));lo=v.min(axis=0);hi=v.max(axis=0);extent=max(hi-lo)*.6;center=(lo+hi)/2
  ax.set_xlim(center[0]-extent,center[0]+extent);ax.set_ylim(center[1]-extent,center[1]+extent);ax.set_zlim(center[2]-extent,center[2]+extent);ax.set_box_aspect([1,1,1]);ax.view_init(22,-55);ax.set_axis_off();ax.set_title(name,color='#263b3e',fontsize=13);ax.set_facecolor('#edf0ee')
 fig.suptitle('Stage 3 — actual generated mesh kit',fontsize=20,color='#263b3e');fig.text(.5,.025,'Actual mesh geometry. Algal assemblies illustrate the kit; live shapes come from saved C++ tissue graphs.',ha='center',color='#263b3e');fig.savefig(OUT/'actual-mesh-preview.png',dpi=150,bbox_inches='tight');plt.close(fig)
 print(json.dumps(stats))
if __name__=='__main__':main()
