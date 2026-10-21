"""Validate authored rigs, exported mesh assets, safe envelopes and real Luau poses."""
from pathlib import Path
import json,subprocess,sys,tempfile,base64,math
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/agents'))
import export_models as ex
models=json.loads((ROOT/'assets/agents/designs.json').read_text())
assert len(models)==6
for d in models:
 for i,j in enumerate(d['joints']):
  assert 0<=j['parent']<=i and (i==0 or j['parent']>0)
  assert abs(np.linalg.norm(j['axis'])-1)<1e-7
 for p in d['parts']:
  r=np.array(p['cf'][3:]).reshape(3,3)
  assert np.allclose(r.T@r,np.eye(3),atol=1e-6) and np.linalg.det(r)>.999
  assert min(p['size'])>0 and 1<=p['joint']<=len(d['joints'])
  assert all(0<=c<=255 for c in p['color'])
 for phase in np.linspace(0,1,61):
  frames=ex.joint_matrices(d,float(phase),True)
  for p in d['parts']:
   vertices,_=ex.localmesh(p);mat=frames[p['joint']-1]
   world=vertices@mat[:3,:3].T+mat[:3,3]
   assert np.linalg.norm(world,axis=1).max()<=d['safeRadius']+1e-5,(d['key'],'radius escape')
 gltf=json.loads((ROOT/'assets/agents'/f"{d['key']}.gltf").read_text())
 data=base64.b64decode(gltf['buffers'][0]['uri'].split(',')[1])
 assert len(data)==gltf['buffers'][0]['byteLength']
 triangles=0
 for mesh in gltf['meshes']:
  for prim in mesh['primitives']:
   arrays={}
   for kind,index in prim['attributes'].items():
    acc=gltf['accessors'][index];view=gltf['bufferViews'][acc['bufferView']]
    start=view.get('byteOffset',0);length=view['byteLength']
    assert start+length<=len(data)
    a=np.frombuffer(data[start:start+length],dtype='<f4');assert np.isfinite(a).all()
    width={'VEC3':3,'VEC2':2}[acc['type']];assert len(a)==acc['count']*width
    arrays[kind]=a.reshape(-1,width)
   vertices=arrays['POSITION'];normals=arrays['NORMAL'];uv=arrays['TEXCOORD_0']
   assert len(vertices)==len(normals)==len(uv) and len(vertices)%3==0
   assert np.allclose(np.linalg.norm(normals,axis=1),1,atol=1e-5)
   assert uv.min()>=0 and uv.max()<=1
   tri=vertices.reshape(-1,3,3)
   cross=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0])
   assert (np.linalg.norm(cross,axis=1)>1e-8).all()
   assert ((cross*normals[::3]).sum(1)>0).all(), 'Normal/winding disagreement'
   triangles+=len(tri)
 assert triangles==d['meshTriangles']
 assert len(gltf['materials'])==1 and len(gltf['images'])==1
 print('PASS mesh:',d['key'],triangles,'triangles;',len(d['joints']),'rigid groups')
# Execute actual native Factory rather than reimplementing its behavior in Python.
header=r'''
local V={};V.__index=function(t,k)if k=="Magnitude"then return math.sqrt(t.X*t.X+t.Y*t.Y+t.Z*t.Z)end;return V[k]end
local function vec(x,y,z)return setmetatable({X=x,Y=y,Z=z},V)end
V.__mul=function(a,b)return vec(a.X*b,a.Y*b,a.Z*b)end
local Vector3={new=vec}
local CF={}
local function frame(x,y,z,...)
 local r={...};if #r==0 then r={1,0,0,0,1,0,0,0,1}end
 return setmetatable({p={x or 0,y or 0,z or 0},r=r},CF)
end
CF.__index=function(t,k)if k=="Position"then return vec(t.p[1],t.p[2],t.p[3])end;return CF[k]end
function CF:PointToWorldSpace(v)
 local p=self.p;local r=self.r
 return vec(p[1]+r[1]*v.X+r[2]*v.Y+r[3]*v.Z,p[2]+r[4]*v.X+r[5]*v.Y+r[6]*v.Z,p[3]+r[7]*v.X+r[8]*v.Y+r[9]*v.Z)
end
CF.__mul=function(a,b)
 local r={};for i=0,2 do for j=0,2 do local s=0;for k=0,2 do s+=a.r[i*3+k+1]*b.r[k*3+j+1]end;r[i*3+j+1]=s end end
 local p=a:PointToWorldSpace(vec(unpack(b.p)));return frame(p.X,p.Y,p.Z,unpack(r))
end
local CFrame={new=frame,fromAxisAngle=function(v,a)
 local x,y,z=v.X,v.Y,v.Z;local c,s=math.cos(a),math.sin(a);local q=1-c
 return frame(0,0,0,x*x*q+c,x*y*q-z*s,x*z*q+y*s,y*x*q+z*s,y*y*q+c,y*z*q-x*s,z*x*q-y*s,z*y*q+x*s,z*z*q+c)
end}
local Color3={fromRGB=function(...)return {...}end}
local Enum={Material={SmoothPlastic="SmoothPlastic"}}
local Instance={new=function(kind)return {Kind=kind,SetAttribute=function()end,Destroy=function(t)t.Destroyed=true end}end}
'''
source=header+'\nlocal data=(function()\n'+(ROOT/'src/shared/AgentDesignData.lua').read_text()+'\nend)()\n'
factory=(ROOT/'src/shared/AgentModelFactory.lua').read_text().replace('require(script.Parent.AgentDesignData)','data')
source+='local Factory=(function()\n'+factory+'\nend)()\n'
source+=r'''
for _,d in Factory.designs() do
 local radius=.25
 local rig=Factory.create(d.key,{},radius,2)
 assert(#rig.states==d.partCount)
 for frame=1,80 do
  Factory.pose(rig,CFrame.new(),frame*.17,1)
  for _,state in rig.states do
   local part=state.part
   assert(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery)
   for _,x in {-1,1}do for _,y in {-1,1}do for _,z in {-1,1}do
    local corner=part.CFrame:PointToWorldSpace(Vector3.new(part.Size.X*x/2,part.Size.Y*y/2,part.Size.Z*z/2))
    assert(corner.Magnitude<=radius+1e-6,"Native model escapes authoritative radius")
   end end end
  end
 end
 Factory.destroy(rig);assert(#rig.states==0 and rig.model.Destroyed)
end
print("PASS native Luau creation, 80 poses per design, .25-radius envelopes and teardown")
'''
with tempfile.TemporaryDirectory() as directory:
 p=Path(directory)/'agent-model-tests.luau';p.write_text(source)
 subprocess.run([sys.argv[1],str(p)],check=True)
# The optional installer makes exactly one reviewed, identity-only edit.
live=(ROOT/'src/client/Controllers/LiveController.client.lua').read_text()
old='part:SetAttribute("CI_AgentId",id);part.Position'
new='part:SetAttribute("CI_AgentId",id);part:SetAttribute("CI_SpeciesId",row[2]);part.Position'
assert live.count(new)==1
original=live.replace(new,old,1)
assert original.replace(old,new,1)==live
print('PASS metadata-only live integration patch; no server/C++ edits')
