"""Export the same native Part/Wedge geometry as glTF and render verifiable design sheets."""
from pathlib import Path
import json,math,base64,struct,io
from PIL import Image
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
ROOT=Path(__file__).resolve().parents[2];ASSET=ROOT/'assets/agents';DOC=ROOT/'docs/agents';DOC.mkdir(parents=True,exist_ok=True)
MODELS=json.loads((ASSET/'designs.json').read_text())
BOX=np.array([[-.5,-.5,-.5],[.5,-.5,-.5],[.5,.5,-.5],[-.5,.5,-.5],[-.5,-.5,.5],[.5,-.5,.5],[.5,.5,.5],[-.5,.5,.5]])
BF=[[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[0,1,5,4],[3,7,6,2]]
WEDGE=BOX[[0,1,4,5,7,6]]
WF=[[0,2,4],[1,5,3],[0,1,3,2],[2,3,5,4],[0,4,5,1]]
def axisangle(axis,a):
 axis=np.array(axis,dtype=float);axis/=np.linalg.norm(axis);x,y,z=axis;c=math.cos(a);s=math.sin(a);v=1-c
 return np.array([[x*x*v+c,x*y*v-z*s,x*z*v+y*s],[y*x*v+z*s,y*y*v+c,y*z*v-x*s],[z*x*v-y*s,z*y*v+x*s,z*z*v+c]])
def joint_matrices(d,t=0,animate=False):
 frames=[]
 for j in d['joints']:
  matrix=np.eye(4);matrix[:3,3]=j['pivot']
  if animate:matrix[:3,:3]=axisangle(j['axis'],j['amplitude']*math.sin(t*2*math.pi+j['phase']))
  if j['parent']:matrix=frames[j['parent']-1]@matrix
  frames.append(matrix)
 return frames
def localmesh(p):
 profile=p.get('meshProfile')
 if profile:
  bevel=profile['bevel'];u=1-bevel
  outline=np.array([[-u,-1],[u,-1],[1,-u],[1,u],[u,1],[-u,1],[-1,u],[-1,-u]])*.5
  axis=profile['axis'];sx,sy,sz=p['size']
  size=np.array([sx,sy,sz] if axis==2 else [sx,sz,sy])
  v=[]
  for t,scale in profile['rings']:
   for xy in outline:v.append([xy[0]*scale*size[0],xy[1]*scale*size[1],t*size[2]])
  v=np.array(v);f=[list(reversed(range(8))),list(range(len(v)-8,len(v)))]
  for ring in range(len(profile['rings'])-1):
   for k in range(8):f.append([ring*8+k,ring*8+(k+1)%8,(ring+1)*8+(k+1)%8,(ring+1)*8+k])
  if axis==1:v=v[:,[0,2,1]]*np.array([1,1,-1])
 else:v,f=(WEDGE,WF) if p['shape']=='Wedge' else (BOX,BF);v=v*np.array(p['size'])
 r=np.array(p['cf'][3:]).reshape(3,3)
 return v@r.T+np.array(p['cf'][:3]),f

def mesh_faces(d,p):
 if p['name']=='Pigment' and d['kind']=='Study':return []
 v,fs=localmesh(p);result=[]
 for f in fs:
  q=v[f];normal=np.cross(q[1]-q[0],q[2]-q[0]);normal/=max(np.linalg.norm(normal),1e-9)
  if p.get('meshPigment') and len(f)==4:
   nu=max(1,min(8,math.ceil(np.linalg.norm(q[1]-q[0])*5)))
   nv=max(1,min(8,math.ceil(np.linalg.norm(q[3]-q[0])*5)))
   for a in range(nu):
    for b in range(nv):
     def interp(u,w):return (1-u)*(1-w)*q[0]+u*(1-w)*q[1]+u*w*q[2]+(1-u)*w*q[3]
     patch=np.array([interp(a/nu,b/nv),interp((a+1)/nu,b/nv),interp((a+1)/nu,(b+1)/nv),interp(a/nu,(b+1)/nv)])
     pt=patch.mean(0);color=p['color']
     pattern=math.sin(math.floor(pt[2]*6)*7.7+math.floor(pt[1]*6)*13.7+d['partCount'])*.5+.5
     band=math.sin(pt[2]*9+pt[1]*2)
     if normal[1]<-.45:color=d['palette']['light']
     elif abs(normal[0])>.4 and band>.1 and pattern>.36:color=d['palette']['stripe']
     elif pattern>.85:color=d['palette']['dark']
     result.append((patch,color))
  else:result.append((q,p['color']))
 return result

def faces(d,t=0,animate=False,lod=2):
 frames=joint_matrices(d,t,animate);out=[]
 for p in d['parts']:
  if p['lod']>lod:continue
  mat=frames[p['joint']-1]
  for localverts,pigment in mesh_faces(d,p):
   verts=localverts@mat[:3,:3].T+mat[:3,3]
   normal=np.cross(verts[1]-verts[0],verts[2]-verts[0]);normal/=max(np.linalg.norm(normal),1e-9)
   light=np.array([-.4,.8,-.6]);light/=np.linalg.norm(light)
   intensity=.62+.38*max(0,float(np.dot(normal,light)))
   color=np.clip(np.array(pigment)/255*intensity,0,1)
   out.append((verts,color))
 return out

def draw(ax,d,t=0,animate=False,azim=-62):
 fs=faces(d,t,animate)
 ax.set_facecolor('#17232c')
 polys=[v[:,[2,0,1]] for v,c in fs]
 colors=[c for v,c in fs]
 ax.add_collection3d(Poly3DCollection(polys,facecolors=colors,edgecolors='none',linewidths=0,zsort='average'))
 pts=np.concatenate(polys);lo=pts.min(0);hi=pts.max(0);center=(hi+lo)/2;span=max(hi-lo)*.56
 ax.set_xlim(center[0]-span,center[0]+span);ax.set_ylim(center[1]-span,center[1]+span);ax.set_zlim(center[2]-span*.7,center[2]+span*.7)
 ax.set_box_aspect((1,1,.7));ax.view_init(elev=18,azim=azim);ax.set_axis_off()
 # Compact floor shadow beneath the actual mesh, not an inferred generated model.
 ax.set_proj_type('ortho')
 return ax

def sheet(subset,filename,title,subtitle):
 fig=plt.figure(figsize=(15,7.8),facecolor='#17232c')
 for i,d in enumerate(subset):
  ax=fig.add_subplot(1,3,i+1,projection='3d');draw(ax,d)
  fig.text((i+.5)/3,.18,d['title'].upper(),color='#e6e7d8',ha='center',fontsize=16,weight='bold')
  fig.text((i+.5)/3,.14,f"{d['meshTriangles']:,} mesh triangles  /  {len(d['joints'])} rigid groups",color='#9fb1b3',ha='center',fontsize=11)
 fig.text(.045,.92,title,color='#f3eedb',fontsize=25,weight='bold');fig.text(.045,.865,subtitle,color='#a9b8ba',fontsize=12)
 fig.text(.045,.045,'Production mesh renders • native Part fallback supplied separately • original geometry, no extracted assets',color='#849b9e',fontsize=10)
 plt.subplots_adjust(left=.01,right=.99,bottom=.21,top=.84,wspace=-.05)
 fig.savefig(DOC/filename,dpi=150,facecolor=fig.get_facecolor());plt.close(fig)

def export(d):
 gltf={'asset':{'version':'2.0','generator':'CI original faceted models'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[],'meshes':[],'materials':[{'name':'VertexPigment','pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':1},'doubleSided':False}],'buffers':[],'bufferViews':[],'accessors':[]}
 palette=list(dict.fromkeys(tuple(c) for p in d['parts'] for _,c in mesh_faces(d,p)))
 assert len(palette)<=256
 atlas=Image.new('RGB',(128,128),(255,255,255))
 for i,color in enumerate(palette):
  for xx in range((i%16)*8,(i%16)*8+8):
   for yy in range((i//16)*8,(i//16)*8+8):atlas.putpixel((xx,yy),color)
 atlas.save(ASSET/(d['key']+'_palette.png'))
 img=io.BytesIO();atlas.save(img,format='PNG')
 gltf['images']=[{'uri':'data:image/png;base64,'+base64.b64encode(img.getvalue()).decode()}]
 gltf['samplers']=[{'magFilter':9728,'minFilter':9728,'wrapS':33071,'wrapT':33071}]
 gltf['textures']=[{'source':0,'sampler':0}]
 gltf['materials'][0]['pbrMetallicRoughness']['baseColorTexture']={'index':0}
 binary=bytearray()
 def access(array,kind,component=5126):
  dtype=np.float32 if component==5126 else np.uint32;array=np.asarray(array,dtype=dtype)
  while len(binary)%4:binary.append(0)
  offset=len(binary);binary.extend(array.tobytes());view=len(gltf['bufferViews'])
  gltf['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':array.nbytes})
  obj={'bufferView':view,'componentType':component,'count':len(array),'type':kind}
  if kind=='VEC3':obj.update(min=array.min(0).tolist(),max=array.max(0).tolist())
  gltf['accessors'].append(obj);return len(gltf['accessors'])-1
 for i,j in enumerate(d['joints']):
  node={'name':j['name'],'translation':j['pivot']}
  children=[n for n,q in enumerate(d['joints']) if q['parent']==i+1]
  if children:node['children']=children
  vertices=[];normals=[];colors=[];uvs=[]
  for p in d['parts']:
   if p['joint']!=i+1:continue
   for polygon,color in mesh_faces(d,p):
    colorIndex=palette.index(tuple(color))
    uv=[((colorIndex%16)*8+4)/128,((colorIndex//16)*8+4)/128]
    for t in range(1,len(polygon)-1):
     tri=polygon[[0,t,t+1]];n=np.cross(tri[1]-tri[0],tri[2]-tri[0]);n/=np.linalg.norm(n)
     vertices.extend(tri);normals.extend([n]*3);colors.extend([np.array(color)/255]*3);uvs.extend([uv]*3)
  if vertices:
   primitive={'attributes':{'POSITION':access(vertices,'VEC3'),'NORMAL':access(normals,'VEC3'),'TEXCOORD_0':access(uvs,'VEC2')},'material':0,'mode':4}
   node['mesh']=len(gltf['meshes']);gltf['meshes'].append({'name':j['name'],'primitives':[primitive]})
  gltf['nodes'].append(node)
 gltf['buffers']=[{'byteLength':len(binary),'uri':'data:application/octet-stream;base64,'+base64.b64encode(binary).decode()}]
 (ASSET/(d['key']+'.gltf')).write_text(json.dumps(gltf,separators=(',',':')))
 # OBJ provides an additional simple, flat-shaded interchange path.
 lines=['# Original CI model, units match native authoring data'];materials=[];offset=1
 for i,(v,c) in enumerate(faces(d)):
  lines.append(f'usemtl pigment_{i}');materials+= [f'newmtl pigment_{i}',f'Kd {c[0]:.5f} {c[1]:.5f} {c[2]:.5f}']
  lines += [f'v {p[0]:.7f} {p[1]:.7f} {p[2]:.7f}' for p in v]
  lines.append('f '+' '.join(str(offset+k) for k in range(len(v))));offset+=len(v)
 (ASSET/(d['key']+'.obj')).write_text('mtllib '+d['key']+'.mtl\n'+'\n'.join(lines)+'\n')
 (ASSET/(d['key']+'.mtl')).write_text('\n'.join(materials)+'\n')

if __name__=='__main__':
 for d in MODELS:
  d['meshTriangles']=sum(len(v)-2 for p in d['parts'] for v,c in mesh_faces(d,p))
  export(d)
 (ASSET/'designs.json').write_text(json.dumps(MODELS,indent=2)+'\n')
 sheet(MODELS[:3],'LiveAgents.png','CULTIVATED INTELLIGENCE / LIVE AGENTS','Faceted biological markers • restrained pigment blocks • enlarged here for inspection')
 sheet(MODELS[3:],'CreatureStudies.png','CULTIVATED INTELLIGENCE / BODY STUDIES','Mesozoico-inspired proportions and angular anatomy • future morphology studies, separate from current microbes')
 for d in MODELS[3:]:
  fig=plt.figure(figsize=(9,6),facecolor='#17232c');draw(fig.add_subplot(111,projection='3d'),d)
  plt.subplots_adjust(0,0,1,1);fig.savefig(DOC/(d['key']+'.png'),dpi=140);plt.close(fig)
 print('Exported 6 glTFs, OBJ/MTLs and geometry-derived sheets')
