"""Execute the real island modules with a lightweight Roblox API test double.
Checks field layout, voxel safety, partial builds, removal, and decoration budgets.
Run: python tests/island_generator.py /absolute/path/to/luau
"""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
def module(name,remove=()):
    text=(root/'src/shared'/f'{name}.lua').read_text()
    return '\n'.join(l for l in text.splitlines() if not any(l.startswith(p) for p in remove))
header=r'''
local V={}
V.__index=function(t,k)
 if k=="Magnitude" then return math.sqrt(t.X*t.X+t.Y*t.Y+t.Z*t.Z) end
 return V[k]
end
local function vec(x,y,z)return setmetatable({X=x,Y=y,Z=z},V)end
V.__sub=function(a,b)return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
local Vector3={new=vec}
local cf={};cf.__mul=function(a,b)return setmetatable({},cf)end
local CFrame={new=function(...)return setmetatable({},cf)end,Angles=function(...)return setmetatable({},cf)end,lookAt=function(...)return setmetatable({},cf)end}
local Color3={fromRGB=function(...)return {}end}
local Enum={Material={},PartType={Ball="Ball",Cylinder="Cylinder"},SurfaceType={Smooth="Smooth"}}
for _,s in {"Air","Water","Grass","LeafyGrass","Ground","Rock","Sand","Wood","Glass"} do Enum.Material[s]=s end
local Region3={new=function(a,b)return {Min=a,Max=b}end}
local Instances={}
local I={}
I.__index=function(t,k)return I[k]end
function I:IsA(k)return self.ClassName==k end
function I:SetAttribute(k,v)self.Attributes[k]=v end
function I:GetAttribute(k)return self.Attributes[k]end
function I:GetChildren()
 local out={};for _,v in Instances do if v.Parent==self then table.insert(out,v)end end;return out
end
function I:FindFirstChild(name)
 for _,v in self:GetChildren() do if v.Name==name then return v end end
 return nil
end
function I:Destroy()
 for _,v in self:GetChildren() do v:Destroy()end
 self.Parent=nil;self.Dead=true
end
local Instance={new=function(kind)
 local t=setmetatable({ClassName=kind,Attributes={}},I);table.insert(Instances,t);return t
end}
local task={wait=function()end}
local typeof=type
local function warn(...)end
local Random={new=function(seed)
 math.randomseed(seed)
 return {NextNumber=function(_,a,b)a=a or 0;b=b or 1;return a+(b-a)*math.random()end,
 NextInteger=function(_,a,b)return math.random(a,b)end}
end}
local running=false
local RunService={IsRunning=function()return running end}
local payloads={}
local Http={JSONEncode=function(_,v)table.insert(payloads,v);return tostring(#payloads)end,JSONDecode=function(_,v)return payloads[tonumber(v)]end}
local Workspace=Instance.new("Workspace");Workspace.CurrentCamera={}
local state={};local writes=0;local failAt=nil
local function key(x,y,z)return x..":"..y..":"..z end
local terrain={}
function terrain:ReadVoxels(region,res)
 assert(res==4)
 local m,o={},{}
 for ix=1,(region.Max.X-region.Min.X)/4 do
  m[ix]={};o[ix]={}
  for iy=1,(region.Max.Y-region.Min.Y)/4 do
   m[ix][iy]={};o[ix][iy]={}
   for iz=1,(region.Max.Z-region.Min.Z)/4 do
    local cell=state[key(region.Min.X+(ix-.5)*4,region.Min.Y+(iy-.5)*4,region.Min.Z+(iz-.5)*4)]
    m[ix][iy][iz]=if cell then cell[1] else "Air"
    o[ix][iy][iz]=if cell then cell[2] else 0
   end
  end
 end
 return m,o
end
function terrain:WriteVoxels(region,res,m,o)
 writes+=1
 if writes==failAt then error("Injected write failure")end
 for ix=1,#m do for iy=1,#m[ix] do for iz=1,#m[ix][iy] do
  local amount=o[ix][iy][iz]
  assert(amount>=0 and amount<=1 and amount==amount)
  local k=key(region.Min.X+(ix-.5)*4,region.Min.Y+(iy-.5)*4,region.Min.Z+(iz-.5)*4)
  state[k]=if amount>0 then {m[ix][iy][iz],math.floor(amount*255+.5)/255} else nil
 end end end
end
terrain.ClassName="Terrain"
function terrain:IsA(kind)return kind=="Terrain" end
Workspace.Terrain=terrain
function Workspace:FindFirstChildOfClass(kind)return if kind=="Terrain" then terrain else nil end
local game={GetService=function(_,name)return ({Workspace=Workspace,RunService=RunService,HttpService=Http})[name]end}
'''
source=header+'\nlocal C=table.clone((function()\n'+module('IslandConfig')+'\nend)())\n'
source+='local F=(function()\n'+module('IslandField',('local C = require',))+'\nend)()\n'
source+='local Vegetation=(function()\n'+module('IslandVegetation',('local C=require','local F=require'))+'\nend)()\n'
source+='local Generator=(function()\n'+module('ReferenceIslandGenerator',('local C=require','local F=require','local Vegetation=require'))+'\nend)()\n'
source+=r'''
local land,water,rock=0,0,0
for z=C.MinZ+2,C.MaxZ-2,8 do for x=C.MinX+2,C.MaxX-2,8 do
 local h,m,s=F.sample(x,z)
 assert(h==h and h>=C.Bottom and h<C.Top)
 if h>0 then land+=1 else water+=1 end
 if m=="Rock" then rock+=1 end
 if F.protected(x,z) then assert(h==-64)end
end end
assert(land>2000 and water>2000 and rock>100)
for x=-50,50,2 do for z=-50,50,2 do assert(F.protected(x,z))end end
assert(F.coast(-370,-370)>0,"Western peninsula missing")
assert(F.coast(520,-80)<0,"Eastern inlet missing")
local full=Instance.new("Folder")
Vegetation.build(full)
assert(full:GetAttribute("Trees")>60 and full:GetAttribute("Trees")<=C.TreeBudget)
assert(full:GetAttribute("RockClusters")>60 and full:GetAttribute("RockClusters")<=C.RockBudget)
local parts=0
for _,p in Instances do if p.ClassName=="Part" then
 parts+=1;assert(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery)
 assert(p.Size.X>0 and p.Size.Y>0 and p.Size.Z>0)
end end
assert(parts<=C.TreeBudget*4+C.RockBudget*2+C.PlantBudget*3)
print("PASS full island field; vegetation: "..full:GetAttribute("Trees").." trees, "..full:GetAttribute("RockClusters").." rock clusters, "..parts.." parts")
full:Destroy()
-- Exercise actual voxel builder on nine representative chunks, including the pond.
C.MinX=-64;C.MaxX=128;C.MinZ=-64;C.MaxZ=128
local pond=key(2,-2,2);local outside=key(82,2,82)
state[pond]={"Rock",1};state[outside]={"Wood",1}
assert(not pcall(Generator.Generate),"Must refuse existing exterior terrain")
assert(writes==0 and Workspace:FindFirstChild("CI_ReferenceIsland")==nil)
state[outside]=nil
running=true;assert(not pcall(Generator.Generate));running=false
Generator.Generate()
assert(writes==9 and state[pond][1]=="Rock")
assert(Workspace:FindFirstChild("CI_ReferenceIsland"):GetAttribute("Ready"))
local previous=writes;assert(not pcall(Generator.Generate));assert(writes==previous)
state[outside]={"Wood",1} -- A user edit after generation must survive removal.
C.Seed+=10;C.Bottom=-100;C.MaxX=256 -- Removal must use recorded columns, not new settings.
Generator.Remove()
assert(state[pond][1]=="Rock" and state[outside][1]=="Wood")
local remaining=0;for _ in state do remaining+=1 end
assert(remaining==2,"Generated voxels remain after removal")
state[outside]=nil;C.Seed-=10;C.Bottom=-72;C.MaxX=128
failAt=writes+3
assert(not pcall(Generator.Generate),"Expected simulated failure")
assert(not Workspace:FindFirstChild("CI_ReferenceIsland"):GetAttribute("Ready"))
failAt=nil;Generator.Remove()
remaining=0;for _ in state do remaining+=1 end
assert(remaining==1 and state[pond][1]=="Rock","Partial build rollback failed")
print("PASS preflight, pond protection, quantized voxel removal, post-build edits, changed configuration, partial build recovery")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'island-tests.luau';p.write_text(source)
 subprocess.run([sys.argv[1],str(p)],check=True)
