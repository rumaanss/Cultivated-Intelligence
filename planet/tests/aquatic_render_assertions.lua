-- Rendering/lifecycle doubles: does not claim Roblox GPU or visual validation.
Vector3.zAxis=Vector3.new(0,0,1)
local cm={};cm.__index=cm
function cm:Lerp(b,t)return setmetatable({R=self.R+(b.R-self.R)*t,G=self.G+(b.G-self.G)*t,B=self.B+(b.B-self.B)*t},cm)end
Color3.fromRGB=function(r,g,b)return setmetatable({R=r/255,G=g/255,B=b/255},cm)end
local oldIsA=methods.IsA
methods.IsA=function(self,c)return (c=="BasePart" and self.ClassName=="WedgePart") or oldIsA(self,c)end
local cf={};cf.__index=cf;cf.__mul=function(a,b)return a end
CFrame.new=function(x,y,z)return setmetatable({Position=Vector3.new(x or 0,y or 0,z or 0)},cf)end
CFrame.Angles=function()return CFrame.new()end
CFrame.fromAxisAngle=function()return CFrame.new()end
CFrame.fromMatrix=function(p)return setmetatable({Position=p},cf)end
workspace.CurrentCamera={CFrame={Position=Vector3.new(100,100,100)}}
workspace.Raycast=function(_,p,d)return {Position=Vector3.new(p.X,p.Y,50),Normal=Vector3.zAxis}end
local Contract={habitat={frame={center={0,0,0},east={1,0,0}}}}
local Space={}
Space.toRobloxXYZ=Vector3.new
function Space.toSimulation(p)return {x=p.X,y=p.Y,z=p.Z}end
function services.CollectionService:AddTag(obj,tag)
 if not table.find(tags,obj)then table.insert(tags,obj);tagAdded:Fire(obj)end
end
function services.CollectionService:RemoveTag(obj,tag)
 local i=table.find(tags,obj);if i then table.remove(tags,i);tagRemoved:Fire(obj)end
end
local event=Instance.new("RemoteEvent");event.Name="CI_AquaticState";event.OnClientEvent=signal();event.Parent=replicated
local os={clock=function()return now end}
local tasks={}
task.wait=function()coroutine.yield()end
task.spawn=function(fn)local co=coroutine.create(fn);table.insert(tasks,co);assert(coroutine.resume(co))end
local script=Instance.new("LocalScript")
CLIENT_SOURCE_PLACEHOLDER
local p={schema=1,model="aquatic-foundation-1",run="test",revision=1,token="test:1",totals={1,2,3,4},residual={0,0,0,0},flux={0,0,0,0,0},patches={}}
for i=1,24 do table.insert(p.patches,{i,i*6,100,50,2,40,.8,500,250,200,1500,20,40,2,100,10})end
event.OnClientEvent:Fire(p)
local root=workspace:FindFirstChild("CI_AquaticCohorts")
assert(root and #root:GetChildren()==6,"bounded 6 visible patches")
local parts=0;for _,o in root:GetDescendants()do if o:IsA("BasePart")then parts+=1;assert(o.Anchored and not o.CanCollide and not o.CanTouch and not o.CastShadow)end end
assert(parts==192,"bounded 192 parts")
local cyano,decomposer=0,0
for _,o in root:GetDescendants()do
 if o:IsA("Model") and o:GetAttribute("DesignKey")=="Cyanobacteria" then cyano+=1 end
 if o:IsA("Model") and o:GetAttribute("DesignKey")=="Bacterivore" then decomposer+=1 end
 assert(o:GetAttribute("DesignKey")~="BodoSaltans","do not relabel a consumer as decomposer")
end
assert(cyano==18 and decomposer==6,"reuse original body library")
assert(#tags==18,"three inspectable populations per patch")
for _,g in tags do assert(g:GetAttribute("CI_BiologyKind")=="Population" and g:GetAttribute("CI_Biomass")~=nil and g:GetAttribute("CI_BiologyTimestamp")==now)end
assert(not pg:FindFirstChild("CI_AquaticResearch"),"no duplicate research overlay")
assert(coroutine.resume(tasks[2]),"bounded animation tick")
local first=root:GetChildren()[1];event.OnClientEvent:Fire(p);assert(first.Parent==root,"no reallocation on same interest")
for _,r in p.patches do r[5],r[6],r[7]=0,0,0 end
event.OnClientEvent:Fire(p)
for _,o in root:GetDescendants()do assert(not o:IsA("BasePart"),"dead biomass rigs destroyed")end
for _,r in p.patches do r[5],r[6],r[7]=2,40,.8 end
workspace.CurrentCamera.CFrame.Position=Vector3.new(900,900,900);event.OnClientEvent:Fire(p);assert(#root:GetChildren()==0,"interest exit cleanup")
workspace.CurrentCamera.CFrame.Position=Vector3.new(100,100,100);event.OnClientEvent:Fire(p);assert(#root:GetChildren()==6)
now+=6;assert(coroutine.resume(tasks[1]));assert(#root:GetChildren()==0,"stale observation cleanup")
event.OnClientEvent:Fire(p);script.Destroying:Fire()
assert(root.Parent==nil and #tags==0,"shutdown/tag cleanup")
for _,c in event.OnClientEvent.listeners do assert(not c.Connected,"event leak")end
print("PASS aquatic rendering: bounded allocation, grounded mat queries, same-interest reuse, dead-rig destruction, range/stale/shutdown cleanup")
