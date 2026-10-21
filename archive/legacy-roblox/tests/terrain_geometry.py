"""Run the actual Luau lakebed module against a supplied canonical lake JSON.
Usage: python tests/terrain_geometry.py /path/to/luau /path/to/lake_geometry.json
No Roblox installation needed; engine properties are stubbed for geometry checks.
"""
import json, subprocess, sys, tempfile
from pathlib import Path
root = Path(__file__).resolve().parents[1]
scene = json.loads(Path(sys.argv[2]).read_text())
def lua(v):
    if isinstance(v, dict): return '{'+','.join(k+'='+lua(x) for k,x in v.items())+'}'
    if isinstance(v, list): return '{'+','.join(map(lua,v))+'}'
    if isinstance(v, bool): return str(v).lower()
    return json.dumps(v)
style = (root/'src/shared/TerrainVisualConfig.lua').read_text()
source = (root/'src/shared/LakebedPresentation.lua').read_text()
source = '\n'.join(l for l in source.splitlines() if not l.startswith('local Geometry =') and not l.startswith('local Space =') and not l.startswith('local Style ='))
harness = '''
local V={}
V.__index=function(t,k)
 if k=="Magnitude" then return math.sqrt(t.X*t.X+t.Y*t.Y+t.Z*t.Z) end
 if k=="Unit" then return t/t.Magnitude end
 return V[k]
end
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z},V) end
V.__add=function(a,b)return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
V.__sub=function(a,b)return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
V.__unm=function(a)return vec(-a.X,-a.Y,-a.Z)end
V.__mul=function(a,b)return vec(a.X*b,a.Y*b,a.Z*b)end
V.__div=function(a,b)return vec(a.X/b,a.Y/b,a.Z/b)end
function V:Dot(b)return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
function V:Cross(b)return vec(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X)end
local Vector3={new=vec}
local Color3={fromRGB=function(r,g,b)return vec(r,g,b)end}
function V:Lerp(b,t)return self+(b-self)*t end
local Enum={Material={Sand="Sand",Rock="Rock",Ground="Ground"}}
local CFrame={fromMatrix=function(p,x,y,z)return {Position=p,X=x,Y=y,Z=z}end}
local parts={}
local Instance={new=function(kind)
 local t={Kind=kind,SetAttribute=function()end,GetChildren=function()return {}end}
 if kind=="WedgePart" then table.insert(parts,t) end
 return t
end}
local Space={toRobloxXYZ=function(x,y,z)return vec(x-50,z-60,y-50)end}
'''
harness += '\nlocal Style=(function()\n'+style+'\nend)()\nlocal M=(function()\n'+source+'\nend)()\nlocal scene='+lua(scene)+'\n'
harness += '''
local area=0
for _,face in M.facets(scene) do
 local signed=0
 for i,a in face do
  local b=face[i%#face+1]
  signed+=a[1]*b[2]-b[1]*a[2]
  local expected=0
  for _,p in scene.terrain.planes do expected=math.max(expected,p[1]*a[1]+p[2]*a[2]+p[3]) end
  assert(math.abs(expected-a[3])<1e-7,"Facet disagrees with collision terrain")
 end
 area+=math.abs(signed)/2
end
assert(math.abs(area-10000)<1e-6,"Facet coverage has holes or overlap")
M.create(scene,{},true)
local count=#parts
assert(count>0 and count<=512,"Client terrain exceeds static part budget")
local areas,materials=0,{}
for _,p in parts do
 assert(p.Anchored and not p.CanTouch)
 assert(p.Size.Y>0 and p.Size.Z>0)
 areas+=p.Size.Y*p.Size.Z/2*math.abs(p.CFrame.X.Y)
 materials[p.Material]=true
end
assert(math.abs(areas-10000)<1e-5,"Tessellation loses projected area")
assert(materials.Sand and materials.Rock,"Missing sediment/rock distinction")
table.clear(parts)
M.create(scene,{},false)
assert(#parts<count and #parts<=64,"Server must use coarse collision facets")
print("PASS: exact terrain coverage; client wedges="..count.."; server wedges="..#parts)
'''
with tempfile.TemporaryDirectory() as d:
    p=Path(d)/'terrain.luau';p.write_text(harness)
    subprocess.run([sys.argv[1],str(p)],check=True)
