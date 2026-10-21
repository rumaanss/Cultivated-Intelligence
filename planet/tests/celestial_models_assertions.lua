-- Resource and scheduling checks against test doubles, not a GPU test.
Vector3.one=Vector3.new(1,1,1)
local cf={};cf.__index=cf;cf.__mul=function(a,b)return a end
CFrame.new=function(p)return setmetatable({Position=p},cf)end
CFrame.Angles=function()return setmetatable({},cf)end
function cf:VectorToObjectSpace(v)return v end
local liveMeshes=0;local colorWrites=0;local allocations=0;local failAt=nil
local function meshNew()
 allocations+=1
 if allocations==failAt then return nil end
 liveMeshes+=1
 local m={positions={},colors={},faces={},links={},dead=false}
 function m:AddVertex(v)table.insert(self.positions,v);return #self.positions end
 function m:AddColor(c,a)assert(a==1);table.insert(self.colors,c);return #self.colors end
 function m:AddNormal(n)return 1 end
 function m:AddTriangle(a,b,c)table.insert(self.faces,{a,b,c});return #self.faces end
 function m:SetFaceColors(f,ids)for i,c in ids do self.links[c]=self.links[c] or {};table.insert(self.links[c],self.faces[f][i])end end
 function m:SetFaceNormals()end
 function m:GetColors()local ids={};for i in self.colors do table.insert(ids,i)end;return ids end
 function m:GetVerticesWithColor(c)return self.links[c] or {}end
 function m:GetPosition(v)return self.positions[v]end
 function m:GetColor(c)return self.colors[c]end
 function m:SetColor(c,v)assert(not self.dead);colorWrites+=1;self.colors[c]=v end
 function m:Destroy()assert(not self.dead,'double mesh disposal');self.dead=true;liveMeshes-=1 end
 return m
end
local Asset={}
function Asset:CreateEditableMesh()return meshNew()end
local Content={fromObject=function(o)return o end}
function Asset:CreateDataModelContentAsync(m)return Enum.CreateContentResult.Success,m end
function Asset:CreateEditableMeshAsync(m,options)
 assert(options.FixedSize)
 local n=meshNew();if not n then return nil end
 n.positions=m.positions;n.colors=table.clone(m.colors);n.faces=m.faces;n.links=m.links;return n
end
function Asset:CreateMeshPartAsync(m,options)assert(options.CollisionFidelity==Enum.CollisionFidelity.Box);return Instance.new('MeshPart')end
services.AssetService=Asset;task.wait=function()end
local Models=MODEL_SOURCE_PLACEHOLDER
local root=Instance.new('Folder')
local model,err=Models.new(root,Vector3.zero,4096,Vector3.xAxis,Vector3.yAxis)
assert(model,err);assert(liveMeshes==6)
local folder=root:FindFirstChild('CelestialModels');assert(#folder:GetChildren()==6)
for _,p in folder:GetChildren()do assert(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch and not p.CastShadow)end
local count=allocations
for frame=1,120 do
 local before=colorWrites
 model.Update(Vector3.yAxis*4100,frame/600,Vector3.xAxis,0,frame/60)
 assert(colorWrites-before<=64,'unbounded shading work')
end
assert(allocations==count,'per-frame mesh allocation');assert(folder:GetAttribute('ShadingGeneration')>0)
model.Update(Vector3.yAxis*4100,1,Vector3.xAxis,1,3)
for _,p in folder:GetChildren()do assert(p.Transparency==1,'underwater handoff');assert(p.Size.X<=2048)end
model.Destroy();model.Destroy();assert(liveMeshes==0 and #root:GetChildren()==0)
failAt=allocations+4
local failed,message=Models.new(root,Vector3.zero,4096,Vector3.xAxis,Vector3.yAxis)
assert(not failed and message);assert(liveMeshes==0 and #root:GetChildren()==0,'partial initialization leak')
print('PASS celestial models: bounded shading, six nonphysical models, underwater handoff, no per-frame allocation, shutdown and partial-allocation cleanup')
