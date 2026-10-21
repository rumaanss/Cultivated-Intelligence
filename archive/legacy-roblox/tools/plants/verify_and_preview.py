"""Run real PlantAssetLibrary/PlantRenderer against a small math/Instance test double.
Exports descriptors from the same Lua geometry code used in Studio, for preview rendering.
"""
from pathlib import Path
import json,subprocess,sys,tempfile
ROOT=Path(__file__).resolve().parents[2]
snapshot=json.loads(Path(sys.argv[2]).read_text())
selected=[]
for species in range(3):
 choices=[p for p in snapshot['plants'] if p['species']==species and p['stage']==1]
 p=max(choices,key=lambda p:len(p['organs']));p=json.loads(json.dumps(p));p['position']=[(species-1)*14,0,0];selected.append(p)
def lua(v):
 if isinstance(v,dict):return '{'+','.join('['+json.dumps(k)+']='+lua(x) for k,x in v.items())+'}'
 if isinstance(v,list):return '{'+','.join(map(lua,v))+'}'
 if isinstance(v,bool):return 'true' if v else 'false'
 if v is None:return 'nil'
 return json.dumps(v)
base=(ROOT/'tests/agent_models.py').read_text().split("header=r'''",1)[1].split("'''",1)[0]
extra=r'''
V.__add=function(a,b)return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
V.__sub=function(a,b)return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
local oldIndex=V.__index
V.__index=function(t,k)if k=="Unit" then return t*(1/t.Magnitude) end;return oldIndex(t,k)end
function V:Cross(b)return vec(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X)end
function V:Lerp(b,t)return self*(1-t)+b*t end
Vector3.xAxis=vec(1,0,0);Vector3.yAxis=vec(0,1,0)
CFrame.new=function(x,y,z,...)if type(x)=="table" then return frame(x.X,x.Y,x.Z,...)end;return frame(x,y,z,...)end
CFrame.lookAt=function(a,b,up)local z=(a-b).Unit;local x=up:Cross(z).Unit;local y=z:Cross(x);return frame(a.X,a.Y,a.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
CFrame.Angles=function(x,y,z)return CFrame.fromAxisAngle(vec(1,0,0),x)*CFrame.fromAxisAngle(vec(0,1,0),y)*CFrame.fromAxisAngle(vec(0,0,1),z)end
function CF:Lerp(b,t)local r={};for i=1,9 do r[i]=self.r[i]*(1-t)+b.r[i]*t end;return frame(self.p[1]*(1-t)+b.p[1]*t,self.p[2]*(1-t)+b.p[2]*t,self.p[3]*(1-t)+b.p[3]*t,unpack(r))end
local COL={};COL.__index=COL
function COL:Lerp(b,t)return setmetatable({R=self.R*(1-t)+b.R*t,G=self.G*(1-t)+b.G*t,B=self.B*(1-t)+b.B*t},COL)end
Color3.new=function(r,g,b)return setmetatable({R=r,G=g,B=b},COL)end
Color3.fromRGB=function(r,g,b)return Color3.new(r/255,g/255,b/255)end
Enum.PartType={Ball="Ball"}
Instance.new=function(kind)return {Kind=kind,SetAttribute=function(t,k,v)t[k]=v end,IsA=function(t,k)return t.Kind==k end,Destroy=function(t)t.Destroyed=true end}end
'''
art=(ROOT/'src/shared/PlantAssetLibrary.lua').read_text()
renderer=(ROOT/'src/shared/PlantRenderer.lua').read_text();start=renderer.index('local parent=');end=renderer.index('function M.new')
renderer=renderer[:start]+'local Art=Art\n'+renderer[end:]
protocol=(ROOT/'src/shared/PlantProtocol.lua').read_text()
source=base+extra+'\nlocal records='+lua(selected)+'\nlocal Art=(function()\n'+art+'\nend)()\nlocal Renderer=(function()\n'+renderer+'\nend)()\nlocal Protocol=(function()\n'+protocol+'\nend)()\n'
source+=r'''
local keyed={};for _,p in records do keyed[p.id]=p end
local config={FarDistance=1000,NearDistance=100,MidDistance=200,MaximumRenderedPlants=3,MaximumParts=2400}
local renderer=Renderer.new(Instance.new("Folder"))
Renderer.select(renderer,keyed,vec(0,4,-10),config,false)
local first=renderer.plants[records[1].id].items[1].part
Renderer.pose(renderer,.1,1)
Renderer.select(renderer,keyed,vec(0,4,-10),config,false)
assert(first==renderer.plants[records[1].id].items[1].part,"Ordinary updates recreated geometry")
assert(renderer.parts<=2400 and renderer.parts>0)
config.MaximumParts=8;Renderer.select(renderer,keyed,vec(0,4,-10),config,false);assert(renderer.parts<=8,"Part cap escaped")
Renderer.clear(renderer);assert(renderer.parts==0)
local packet={schema=1,run="test-1",units="studs-Y-up",revision=1,tick=1,surface="flat-v1",reset=true,base=0,upsert=records,removed={}}
local state=Protocol.apply(nil,packet);assert(state and state.records[records[1].id])
local row=table.clone(records[1]);row.organs=nil;row.age+=1
local delta={schema=1,run="test-1",units="studs-Y-up",revision=2,tick=2,surface="flat-v1",reset=false,base=1,upsert={row},removed={}}
local updated=Protocol.apply(state,delta);assert(updated.records[row.id].organs==state.records[row.id].organs,"Unchanged topology lost")
packet.reset=false;packet.base=0;assert(Protocol.apply(state,packet)==nil,"Wrong base accepted")
packet.reset=true;packet.upsert={records[1],records[1]};assert(not pcall(function()Protocol.validate(packet)end),"Duplicate IDs accepted")
for _,p in records do
 for _,d in Art.geometry(p,2,false) do
  local values={p.species,d.id,d.size.X,d.size.Y,d.size.Z,unpack(d.cf.p)}
  for _,v in d.cf.r do table.insert(values,v)end
  table.insert(values,d.color.R);table.insert(values,d.color.G);table.insert(values,d.color.B)
  print(d.shape.." "..table.concat(values," "))
 end
end
'''
with tempfile.TemporaryDirectory() as folder:
 p=Path(folder)/'test.luau';p.write_text(source)
 output=subprocess.check_output([sys.argv[1],str(p)],text=True)
geometry=[]
for line in output.splitlines():
 values=line.split();geometry.append({'shape':values[0],'values':list(map(float,values[1:]))})
(ROOT/'assets/plants/showcase_geometry.json').write_text(json.dumps(geometry,indent=2))
(ROOT/'assets/plants/showcase_records.json').write_text(json.dumps(selected,indent=2))
(ROOT/'src/shared/PlantShowcaseData.lua').write_text('--!strict\n-- Captured from explicit authored growth requests at tick '+str(snapshot['tick'])+'; resources ledger-accounted; not neural evolution evidence.\nreturn '+lua(selected)+'\n')
print('PASS actual Luau: geometry, stable part identity, budgets, teardown, delta bases and duplicate rejection;',len(geometry),'preview pieces')
