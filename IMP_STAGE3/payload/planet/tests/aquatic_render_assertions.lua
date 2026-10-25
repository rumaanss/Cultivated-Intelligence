-- Rendering/lifecycle doubles: does not claim Roblox GPU or visual validation.
Vector3.zAxis=Vector3.new(0,0,1)
local cm={};cm.__index=cm
function cm:Lerp(b,t)return setmetatable({R=self.R+(b.R-self.R)*t,G=self.G+(b.G-self.G)*t,B=self.B+(b.B-self.B)*t},cm)end
Color3.fromRGB=function(r,g,b)return setmetatable({R=r/255,G=g/255,B=b/255},cm)end
local oldIsA=methods.IsA
methods.IsA=function(self,c)return (c=="BasePart" and self.ClassName=="WedgePart") or oldIsA(self,c)end
Color3.fromHSV=function(h,s,v)return Color3.fromRGB(h*255,s*255,v*255)end
local cf={}
cf.__index=function(a,k)if k=="Rotation" then return CFrame.new()else return cf[k]end end
cf.__mul=function(a,b)return CFrame.new(a.Position+b.Position)end
CFrame.new=function(x,y,z)return setmetatable({Position=if type(x)=="table" then x else Vector3.new(x or 0,y or 0,z or 0)},cf)end
CFrame.Angles=function()return CFrame.new()end
CFrame.fromAxisAngle=function()return CFrame.new()end
CFrame.fromMatrix=function(p)return setmetatable({Position=p},cf)end
cf.PointToWorldSpace=function(self,p)return self.Position+p end
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

p.schema=2;p.model="pdnarna-3";p.colonies={};p.revision+=1;p.population=995;p.events={100,20,3}
for _,r in p.patches do
 for guild=0,2 do table.insert(p.colonies,{r[1],guild,r[1]*3+guild,0,guild+1,0,200,1,.5,.1,.01,.002,.008,.065,.5,3,2,1.575,.2,.02,1,80})end
end
event.OnClientEvent:Fire(p)
assert(#tags==18,"bounded colony samples")
local oldSample
for _,g in tags do assert(g:GetAttribute("CI_BiologyKind")=="Colony" and g:GetAttribute("CI_GenomeId") and g:GetAttribute("CI_DNA"));oldSample=g end
local id=oldSample:GetAttribute("CI_ColonyId")
for _,r in p.colonies do if r[3]==id then r[3]+=1000 end end
p.revision+=1;event.OnClientEvent:Fire(p)
assert(oldSample.Parent==nil,"a replacement sample must not inherit the selected object's identity")
local filtered=Protocol.near(p,{100,100,100},1);assert(#filtered.patches==1 and #filtered.colonies==3)
local invalid=table.clone(p);invalid.colonies=table.clone(p.colonies);table.insert(invalid.colonies,p.colonies[1]);assert(not pcall(Protocol.validate,invalid,p.run),"reject duplicate identities")
invalid=table.clone(p);invalid.colonies={table.clone(p.colonies[1])};invalid.colonies[1][15]=2;assert(not pcall(Protocol.validate,invalid,p.run),"reject replication outside bounds")

event.OnClientEvent:Fire({clear=true})
p.model="pdnarna-4";p.run="motion-test";p.revision=100;p.lifecycle={};p.colonies={}
local function colony(id,patch,x,parent,genome)
 return {patch,0,id,parent or 0,genome or 1,if parent then 1 else 0,200,1,.5,.1,.01,.002,.008,.065,.5,3,2,1.575,.2,.02,1,80,x,100,80,1,2,4,.01,1,1,1,1,1,1,1,1,1,1}
end
p.colonies={colony(100,16,96)};p.colonies[1][8]=2
event.OnClientEvent:Fire(p)
assert(#tags==1,"individual sample")
local tracked=tags[1];local initialSize=tracked:GetDescendants()[2].Size
p.colonies={colony(100,17,102)};p.colonies[1][8]=2;p.revision=120
now+=1;event.OnClientEvent:Fire(p)
assert(tags[1]==tracked and tracked:GetAttribute("CI_PatchId")==17,"identity must survive a patch crossing")
now+=.5;assert(coroutine.resume(tasks[2]))
assert(math.abs(tracked:GetAttribute("CI_DisplayX")-99)<1e-6,"interpolate real positions")
event.OnClientEvent:Fire(p)
now+=.5;assert(coroutine.resume(tasks[2]))
assert(math.abs(tracked:GetAttribute("CI_DisplayX")-102)<1e-6,"repeated packets must not restart interpolation")
assert(math.abs(tracked:GetDescendants()[2].Size.X/initialSize.X-2^(1/3))<1e-6,"growth radius follows structural volume")
p.colonies[1][8]=1
local child=colony(101,17,102,100,4);child[39]=1.05;child[7]=0
p.colonies={p.colonies[1],child};p.lifecycle={{120,1,101,100,17,102,100,80}};p.revision=140
now+=1;event.OnClientEvent:Fire(p)
assert(#tags==2 and tracked.Parent==root,"birth retains parent and admits a real daughter")
local daughter=if tags[1]==tracked then tags[2]else tags[1]
assert(daughter:GetAttribute("CI_ParentId")==100 and daughter:GetAttribute("CI_GenomeId")==4,"inherited identity")
assert(daughter:GetAttribute("CI_Lifecycle")=="New offspring","birth observation")
local parentPart=tracked:GetDescendants()[2];local childPart=daughter:GetDescendants()[2]
assert(parentPart.Color.R~=childPart.Color.R,"inherited allele diversity changes marker color")
p.colonies={child};p.lifecycle={{150,2,100,0,17,102,100,80}};p.revision=160
now+=1;event.OnClientEvent:Fire(p)
assert(coroutine.resume(tasks[2]))
assert(math.abs(tracked:GetDescendants()[2].Size.X/initialSize.X-1)<1e-6,"division halves volume and reduces parent radius")
assert(tracked:GetAttribute("CI_Lifecycle")=="Died; material returned to detritus","only explicit death gets death animation")
now+=1;assert(coroutine.resume(tasks[2]));assert(tracked.Parent==nil and #tags==1,"death animation cleanup")
local invalidMotion=table.clone(p);invalidMotion.colonies={table.clone(child)};invalidMotion.colonies[1][39]=9
assert(not pcall(Protocol.validate,invalidMotion,p.run),"reject invalid allele")
event.OnClientEvent:Fire({clear=true});assert(#tags==0)
NATIVE_REPLAY_PLACEHOLDER
script.Destroying:Fire()
assert(root.Parent==nil and #tags==0,"shutdown/tag cleanup")
for _,c in event.OnClientEvent.listeners do assert(not c.Connected,"event leak")end
print("PASS aquatic rendering: bounded allocation, grounded mat queries, same-interest reuse, dead-rig destruction, range/stale/shutdown cleanup")
