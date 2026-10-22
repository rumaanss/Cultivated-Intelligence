-- Rendering/lifecycle doubles: does not claim Roblox GPU or visual validation.
Vector3.zAxis=Vector3.new(0,0,1)
local cf={};cf.__index=cf;cf.__mul=function(a,b)return a end
CFrame.new=function(x,y,z)return setmetatable({Position=Vector3.new(x or 0,y or 0,z or 0)},cf)end
CFrame.Angles=function()return CFrame.new()end
CFrame.fromMatrix=function(p)return setmetatable({Position=p},cf)end
workspace.CurrentCamera={CFrame={Position=Vector3.new(100,100,100)}}
workspace.Raycast=function(_,p,d)return {Position=Vector3.new(p.X,p.Y,50),Normal=Vector3.zAxis}end
local Contract={habitat={frame={center={0,0,0},east={1,0,0}}}}
local Space={}
Space.toRobloxXYZ=Vector3.new
function Space.toSimulation(p)return {x=p.X,y=p.Y,z=p.Z}end
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
assert(root and #root:GetChildren()==12,"bounded 12 visible patches")
local parts=0;for _,o in root:GetDescendants()do if o:IsA("BasePart")then parts+=1;assert(o.Anchored and not o.CanCollide and not o.CanTouch and not o.CastShadow)end end
assert(parts==192,"bounded 192 parts")
local first=root:GetChildren()[1];event.OnClientEvent:Fire(p);assert(first.Parent==root,"no reallocation on same interest")
for _,r in p.patches do r[5],r[6],r[7]=0,0,0 end
event.OnClientEvent:Fire(p)
for _,o in root:GetDescendants()do if o:IsA("BasePart")then assert(o.Transparency==1 and not o.CanQuery,"no selectable dead biomass illustration")end end
workspace.CurrentCamera.CFrame.Position=Vector3.new(900,900,900);event.OnClientEvent:Fire(p);assert(#root:GetChildren()==0,"interest exit cleanup")
workspace.CurrentCamera.CFrame.Position=Vector3.new(100,100,100);event.OnClientEvent:Fire(p);assert(#root:GetChildren()==12)
now+=6;assert(coroutine.resume(tasks[1]));assert(#root:GetChildren()==0,"stale observation cleanup")
event.OnClientEvent:Fire(p);script.Destroying:Fire()
assert(root.Parent==nil and not pg:FindFirstChild("CI_AquaticResearch"),"shutdown cleanup")
for _,c in event.OnClientEvent.listeners do assert(not c.Connected,"event leak")end
print("PASS aquatic rendering: bounded allocation, grounded mat queries, same-interest reuse, death hiding, range/stale/shutdown cleanup")
