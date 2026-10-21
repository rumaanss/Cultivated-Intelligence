-- Stop Play AND disconnect Rojo before applying. Update repository files before reconnecting.
assert(not game:GetService("RunService"):IsRunning(),"Stop Play first")
local sources={
[1]=[====[
--!strict
local M={}
type Candidate = {id:number,p:any,d:number}
local parent=script.Parent;assert(parent~=nil)
local asset=parent:FindFirstChild("PlantAssetLibrary");assert(asset~=nil and asset:IsA("ModuleScript"))
local Art=require(asset)
function M.new(root:Instance):any return {root=root,plants={},parts=0} end
local function remove(renderer:any,id:number)
 local rig=renderer.plants[id];if not rig then return end
 renderer.parts-=#rig.items;rig.model:Destroy();renderer.plants[id]=nil
end
function M.select(renderer:any,records:any,cameraPosition:Vector3,config:any,roots:boolean)
 local candidates: {Candidate}={}
 for id,p in records do
  local d=(Vector3.new(p.position[1],p.position[2],p.position[3])-cameraPosition).Magnitude
  if d<=config.FarDistance then
   local visual=p
   local resolveGround = config.ResolveGround
   if type(resolveGround)=="function" then
    visual=table.clone(p);visual.position={p.position[1],(resolveGround :: (any) -> number)(p),p.position[3]}
   end
   table.insert(candidates,{id=id,p=visual,d=d})
  end
 end
 table.sort(candidates,function(a:Candidate,b:Candidate)return if a.d==b.d then a.id<b.id else a.d<b.d end)
 local keep={};local plans={};local used=0
 for rank,c in candidates do
  if rank>config.MaximumRenderedPlants then break end
  local lod=if c.d<config.NearDistance then 2 elseif c.d<config.MidDistance then 1 else 0
  local pieces=Art.geometry(c.p,lod,roots)
  if used+#pieces>config.MaximumParts then lod=0;pieces=Art.geometry(c.p,0,false) end
  if used+#pieces>config.MaximumParts then continue end
  keep[c.id]=true;used+=#pieces
  table.insert(plans,{id=c.id,p=c.p,lod=lod,pieces=pieces})
 end
 -- Complete all releases before allocating replacements, including rapid camera jumps.
 local removed={};for id in renderer.plants do if not keep[id] then table.insert(removed,id) end end
 for _,id in removed do remove(renderer,id) end
 for _,plan in plans do
  local rig=renderer.plants[plan.id]
  if rig then
   local wanted={};for _,d in plan.pieces do wanted[d.key]=true end
   local obsolete={};for key in rig.byKey do if not wanted[key] then table.insert(obsolete,key) end end
   for _,key in obsolete do rig.byKey[key].part:Destroy();rig.byKey[key]=nil;renderer.parts-=1 end
  end
 end
 for _,plan in plans do
  local rig=renderer.plants[plan.id]
  if not rig then
   local model=Instance.new("Model");model.Name="Plant_"..plan.id;model:SetAttribute("PlantId",plan.id);model:SetAttribute("Species",plan.p.species);model.Parent=renderer.root
   rig={model=model,items={},byKey={}};renderer.plants[plan.id]=rig
  end
  local ordered={}
  for _,d in plan.pieces do
   local state=rig.byKey[d.key]
   if not state then
    local part:BasePart=if d.shape=="Wedge" then Instance.new("WedgePart") else Instance.new("Part")
    if part:IsA("Part") and d.shape=="Ball" then part.Shape=Enum.PartType.Ball end
    part.Name=d.key;part:SetAttribute("OrganId",d.id);part.Size=d.size*.05;part.CFrame=d.cf;part.Color=d.color
    part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=plan.lod==2
    part.Material=Enum.Material.SmoothPlastic;part.Parent=rig.model
    state={part=part,target=d,base=d.cf};rig.byKey[d.key]=state;renderer.parts+=1
   end
   state.target=d;table.insert(ordered,state)
  end
  rig.items=ordered
  rig.model:SetAttribute("Action",plan.p.action);rig.model:SetAttribute("Result",plan.p.result);rig.model:SetAttribute("Generation",plan.p.generation)
 end
 renderer.root:SetAttribute("NativeParts",renderer.parts)
end
function M.pose(renderer:any,dt:number,time:number)
 local alpha=1-math.exp(-dt*7)
 for id,rig in renderer.plants do for _,state in rig.items do
  local d=state.target;state.base=state.base:Lerp(d.cf,alpha)
  state.part.CFrame=state.base*CFrame.Angles(math.sin(time*1.4+id+d.id*.7)*d.wind,0,0)
  state.part.Size=state.part.Size:Lerp(d.size,alpha);state.part.Color=state.part.Color:Lerp(d.color,alpha)
 end end
end
function M.clear(renderer:any)
 local ids={};for id in renderer.plants do table.insert(ids,id) end
 for _,id in ids do remove(renderer,id) end
end
return M
]====],
[2]=[====[
--!strict
-- These modules are resolved dynamically in live folders and import packages.
local loadModule = require :: (ModuleScript) -> any
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local RunService=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local shared=RS:WaitForChild("Shared")
local function module(name:string):any local m=shared:WaitForChild(name);assert(m:IsA("ModuleScript"));return loadModule(m) end
local Config=module("PlantConfig");if not Config.Enabled then return end
local Protocol=module("PlantProtocol");local Renderer=module("PlantRenderer")
local channel=RS:WaitForChild("CI_PlantChannel",30);if not channel or not channel:IsA("RemoteEvent") then return end
local root=Instance.new("Folder");root.Name="CI_LivingPlants";root.Parent=workspace
-- Align visuals to terrain between coarse simulation samples; no biology is changed.
local groundCache={}
local renderConfig=table.clone(Config)
local terrain=workspace:FindFirstChildOfClass("Terrain")
local groundParams=RaycastParams.new();groundParams.FilterType=Enum.RaycastFilterType.Include
if terrain then groundParams.FilterDescendantsInstances={terrain} end
groundParams.IgnoreWater=false
renderConfig.ResolveGround=function(p:any):number
 local cached=groundCache[p.id]
 if cached and cached.x==p.position[1] and cached.z==p.position[3] then return cached.y end
 local y=p.position[2]
 if terrain then
  local hit=workspace:Raycast(Vector3.new(p.position[1],y+80,p.position[3]),Vector3.new(0,-160,0),groundParams)
  if hit and hit.Material~=Enum.Material.Water then y=hit.Position.Y end
 end
 groundCache[p.id]={x=p.position[1],z=p.position[3],y=y};return y
end
local renderer=Renderer.new(root);local state:any=nil;local pending:any=nil;local lastPacket=0;local roots=Config.ShowRoots
local gui=Instance.new("ScreenGui");gui.Name="CI_PlantInspector";gui.ResetOnSpawn=false;gui.Enabled=false
local player=Players.LocalPlayer
assert(player~=nil,"PlantController must run as a LocalScript")
gui.Parent=player:WaitForChild("PlayerGui")
local policyNames: {string} = {"neural","wait control","viable baseline"}
local label=Instance.new("TextLabel");label.Size=UDim2.fromOffset(390,295);label.Position=UDim2.new(1,-408,0,75)
label.BackgroundColor3=Color3.fromRGB(18,32,30);label.BackgroundTransparency=.1;label.TextColor3=Color3.fromRGB(219,235,209)
label.Font=Enum.Font.Code;label.TextSize=15;label.TextXAlignment=Enum.TextXAlignment.Left;label.TextYAlignment=Enum.TextYAlignment.Top;label.TextWrapped=true;label.Parent=gui
local links={}
local function request()channel:FireServer() end
local received=channel.OnClientEvent:Connect(function(serial:any,index:any,total:any,chunk:any)
 if type(serial)~="number" or serial%1~=0 or serial<=lastPacket or type(index)~="number" or index%1~=0 or type(total)~="number" or total%1~=0 or total<1 or total>175 or index<1 or index>total or type(chunk)~="string" or #chunk>48000 then return end
 if not pending or serial>pending.serial then pending={serial=serial,total=total,chunks={},count=0,bytes=0,at=os.clock()} end
 if serial~=pending.serial or total~=pending.total or pending.chunks[index] then return end
 pending.chunks[index]=chunk;pending.count+=1;pending.bytes+=#chunk
 if pending.bytes>8*1024*1024 then pending=nil;request();return end
 if pending.count~=total then return end
 local text=table.concat(pending.chunks);pending=nil;lastPacket=serial
 local ok,updated=pcall(function()
  local decoded=Http:JSONDecode(text);local value=Protocol.apply(state,decoded);return value
 end)
 if not ok or not updated then request();return end
 if state and updated.run~=state.run then Renderer.clear(renderer);table.clear(groundCache) end
 state=updated
end);table.insert(links,received)
table.insert(links,Input.InputBegan:Connect(function(key,handled)
 if handled then return end
 if key.KeyCode==Enum.KeyCode.P then gui.Enabled=not gui.Enabled end
 if key.KeyCode==Enum.KeyCode.R and gui.Enabled then roots=not roots end
end))
local selection,pose,resync=0,0,0
local update=RunService.Heartbeat:Connect(function(dt)
 selection+=dt;pose+=dt;resync+=dt
 if pending and os.clock()-pending.at>5 then pending=nil;request() end
 if resync>=8 then resync=0;request() end
 local camera=workspace.CurrentCamera;if not camera or not state then return end
 if selection>=Config.SelectionSeconds then
  selection=0;Renderer.select(renderer,state.records,camera.CFrame.Position,renderConfig,roots)
  for id in groundCache do if state.records[id]==nil then groundCache[id]=nil end end
  if gui.Enabled then
   local closest:any=nil;local distance=math.huge
   for _,p in state.records do local d=(Vector3.new(p.position[1],p.position[2],p.position[3])-camera.CFrame.Position).Magnitude;if d<distance then closest=p;distance=d end end
   if closest then
    local p:any=closest
    label.Text=string.format("  PLANT INSPECTOR   [P close / R roots]\n\n  Nearest plant %d | species %d\n  Lineage %d | generation %d\n  Age %d | mutations %d\n  Policy %s\n\n  Carbon %.3f | water %.3f\n  Nutrients %.3f | health %.2f\n\n  Requested: %s @ organ %s\n  Result: %s\n  Funded job: %.2f C / %.0f steps left\n  Sensor light %.2f / soil water %.2f\n\n  Tick %.0f | parts %d",
     p.id,p.species,p.lineage,p.generation,p.age,p.mutations,policyNames[p.policy+1] or "unknown",p.resources[1],p.resources[2],p.resources[3],p.resources[4],tostring(p.action),tostring(p.site),tostring(p.result),p.job[4],p.job[5],p.inputs[6],p.inputs[7],state.tick,renderer.parts
    )
   else label.Text="  No plants in this snapshot." end
  end
 end
 if pose>=1/Config.PoseHz then Renderer.pose(renderer,pose,os.clock());pose=0 end
end);table.insert(links,update)
script.Destroying:Connect(function()for _,link in links do link:Disconnect() end;Renderer.clear(renderer);root:Destroy();gui:Destroy() end)
request()
]====],
[3]=[====[
--!strict
-- These modules are resolved dynamically in live folders and import packages.
local loadModule = require :: (ModuleScript) -> any
-- Independent plant channel using existing server-only relay credentials.
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local shared=RS:WaitForChild("Shared")
local function module(name:string):any
 local value=shared:WaitForChild(name);assert(value:IsA("ModuleScript"));return loadModule(value)
end
local Config=module("PlantConfig");if not Config.Enabled then return end
local Protocol=module("PlantProtocol")
local parent=script.Parent;assert(parent~=nil)
local config=parent:FindFirstChild("LiveTransportConfig")
if not config or not config:IsA("ModuleScript") then warn("[Plants] Server.LiveTransportConfig missing; run the relay setup and sync.");return end
local transport=loadModule(config)
assert(type(transport.Token)=="string" and #transport.Token>=32,"Plant transport token missing")
local url=string.gsub(transport.Url,"/exchange$","/plants")
assert(string.sub(url,1,8)=="https://" or (RunService:IsStudio() and string.match(url,"^http://localhost:%d+/plants$")~=nil),"Plants require HTTPS outside Studio")
assert(RS:FindFirstChild("CI_PlantChannel")==nil,"Duplicate plant server")
local remote=Instance.new("RemoteEvent");remote.Name="CI_PlantChannel";remote.Parent=RS
local state:any=nil
local serial=0
local lastRequest:{[Player]:number}={}
local function send(value:any,player:Player?)
 local encoded=Http:JSONEncode(value);assert(#encoded<=8*1024*1024,"Plant packet exceeds budget")
 serial+=1;local parts=math.ceil(#encoded/48000)
 for i=1,parts do
  local chunk=string.sub(encoded,(i-1)*48000+1,i*48000)
  if player then remote:FireClient(player,serial,i,parts,chunk) else remote:FireAllClients(serial,i,parts,chunk) end
 end
end
remote.OnServerEvent:Connect(function(player:Player)
 local now=os.clock();if now-(lastRequest[player] or -10)<2 then return end;lastRequest[player]=now
 if state then
  local rows={};for _,p in state.records do table.insert(rows,p) end
  send({schema=1,units="studs-Y-up",run=state.run,revision=state.revision,tick=state.tick,surface=state.surface,reset=true,base=0,upsert=rows,removed={},ledger=state.ledger,age=state.age},player)
 end
end)
Players.PlayerRemoving:Connect(function(player)lastRequest[player]=nil end)
while script.Parent do
 local ok,err=pcall(function()
  local response=Http:RequestAsync({Url=url,Method="POST",Headers={["Content-Type"]="application/json",["X-CI-Token"]=transport.Token},Body=Http:JSONEncode({schema=1,run=if state then state.run else "",revision=if state then state.revision else -1})})
  assert(response.Success,"Plant relay HTTP "..response.StatusCode)
  assert(#response.Body<=8*1024*1024,"Oversized response")
  local packet=Http:JSONDecode(response.Body)
  local updated,reason=Protocol.apply(state,packet)
  if not updated then state=nil;error(reason) end
  state=updated
  workspace:SetAttribute("CI_PlantTick",state.tick)
  workspace:SetAttribute("CI_PlantStatus",if (state.age or 0)>10 then "Publisher stale" else "Connected")
  if packet.reset or #packet.upsert>0 or #packet.removed>0 then send(packet,nil) end
 end)
 if not ok then workspace:SetAttribute("CI_PlantStatus",tostring(err)) end
 task.wait(Config.PollSeconds)
end
]====],
[4]=[====[
--!strict
-- These modules are resolved dynamically in live folders and import packages.
local loadModule = require :: (ModuleScript) -> any
-- Included only in the local Studio import package; never runs automatically.
local parent=script.Parent
assert(parent~=nil,"Island installer must be inside its package")
local packageRoot: Instance=parent
local function cloneChecked(source: Instance): Instance
 local copy=source:Clone()
 assert(copy~=nil,"Cannot clone "..source.Name.."; enable its Archivable property")
 return copy
end
local M={}
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local function sharedFolder(): Instance
 local shared=RS:FindFirstChild("Shared")
 assert(shared~=nil,"Open your existing CI Roblox place first; ReplicatedStorage.Shared is missing.")
 return shared
end
function M.Run()
 assert(not RunService:IsRunning(),"Stop Play before installing the island")
 assert(packageRoot:GetAttribute("Installed")~=true,"Already installed. Run require(game.ReplicatedStorage.Shared.ReferenceIslandGenerator).Generate() instead.")
 local shared=sharedFolder()
 local source=packageRoot:FindFirstChild("Shared")
 assert(source~=nil)
 local backups=Instance.new("Folder");backups.Name="OriginalModules";backups.Parent=packageRoot
 for _,item in source:GetChildren() do
  assert(item:IsA("ModuleScript"),"Package must contain only ModuleScripts")
  local existing=shared:FindFirstChild(item.Name)
  if existing then cloneChecked(existing).Parent=backups end
 end
 for _,item in source:GetChildren() do
  local existing=shared:FindFirstChild(item.Name)
  local replacement=cloneChecked(item)
  replacement:SetAttribute("ReferenceIslandPackage",true)
  if existing then existing:Destroy() end
  replacement.Parent=shared
 end
 packageRoot:SetAttribute("Installed",true)
 local generator=shared:FindFirstChild("ReferenceIslandGenerator")
 assert(generator~=nil and generator:IsA("ModuleScript"))
 loadModule(generator).Generate()
end
function M.RestoreModules()
 assert(not RunService:IsRunning(),"Stop Play before restoring modules")
 assert(game.Workspace:FindFirstChild("CI_ReferenceIsland")==nil,"Remove generated island first using ReferenceIslandGenerator.Remove()")
 local shared=sharedFolder()
 local source=packageRoot:FindFirstChild("Shared")
 local backups=packageRoot:FindFirstChild("OriginalModules")
 assert(source~=nil and backups~=nil,"No installed module backup exists")
 for _,item in source:GetChildren() do
  local current=shared:FindFirstChild(item.Name)
  if current and current:GetAttribute("ReferenceIslandPackage")==true then
   current:Destroy()
   local original=backups:FindFirstChild(item.Name)
   if original then cloneChecked(original).Parent=shared end
  end
 end
 backups:Destroy();packageRoot:SetAttribute("Installed",nil)
end
return M
]====],
[5]=[====[
--!strict
-- Native editable fallback rigs. Rich tapered mesh variants are supplied as glTF.
local M={}
export type Joint={name:string,parent:number,pivot:{number},axis:{number},amplitude:number,phase:number}
export type Piece={name:string,size:{number},cf:{number},color:{number},joint:number,shape:string,lod:number}
export type Design={key:string,title:string,kind:string,description:string,joints:{Joint},parts:{Piece},safeRadius:number,partCount:number,triangleCount:number}
export type State={part:BasePart,joint:number,bind:CFrame}
export type Rig={model:Model,design:Design,scale:number,states:{State},frames:{CFrame}}
-- Generated heterogeneous records share the exported Design schema.
local designData: any = require(script.Parent.AgentDesignData)
local designs: {Design} = designData
local index: {[string]:Design}={}
local bodyIds: {[string]:number}={}
for i,design in designs do index[design.key]=design;bodyIds[design.key]=i end
function M.designs(): {Design} return designs end
function M.get(key:string): Design
 local design=index[key];assert(design~=nil,"Unknown agent design: "..key);return design
end
function M.create(key:string,parent:Instance,radius:number?,detail:number?): Rig
 local design=M.get(key)
 local scale=if radius then radius/design.safeRadius else 1
 assert(scale>0 and scale<math.huge,"Invalid model scale")
 local model=Instance.new("Model");model.Name=key
 model:SetAttribute("BodySchemaVersion",1);model:SetAttribute("BodyDesignId",bodyIds[key])
 model:SetAttribute("DesignKey",key);model:SetAttribute("PresentationOnly",true)
 model:SetAttribute("BiologicalClaim",if design.kind=="Live" then "StylizedMarker" else "FutureBodyStudy")
 local states: {State}={}
 for _,piece in design.parts do
  if piece.lod>(detail or 2) then continue end
  local part:BasePart=if piece.shape=="Wedge" then Instance.new("WedgePart") else Instance.new("Part")
  part.Name=piece.name
  part:SetAttribute("BodyComponentId",piece.joint)
  part.Size=Vector3.new(piece.size[1],piece.size[2],piece.size[3])*scale
  part.Material=Enum.Material.SmoothPlastic
  part.Color=Color3.fromRGB(piece.color[1],piece.color[2],piece.color[3])
  part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
  local c=piece.cf
  local bind=CFrame.new(c[1]*scale,c[2]*scale,c[3]*scale,c[4],c[5],c[6],c[7],c[8],c[9],c[10],c[11],c[12])
  part.Parent=model;table.insert(states,{part=part,joint=piece.joint,bind=bind})
 end
 local rig:Rig={model=model,design=design,scale=scale,states=states,frames={}}
 model:SetAttribute("NativePartCount",#states)
 model.Parent=parent
 return rig
end
function M.pose(rig:Rig,root:CFrame,phase:number,strength:number)
 strength=math.clamp(strength,0,1)
 for i,joint in rig.design.joints do
  local p=joint.pivot
  local parent=if joint.parent>0 then rig.frames[joint.parent] else root
  local angle=joint.amplitude*math.sin(phase+joint.phase)*strength
  rig.frames[i]=parent*CFrame.new(p[1]*rig.scale,p[2]*rig.scale,p[3]*rig.scale)
   *CFrame.fromAxisAngle(Vector3.new(joint.axis[1],joint.axis[2],joint.axis[3]),angle)
 end
 for _,state in rig.states do state.part.CFrame=rig.frames[state.joint]*state.bind end
end
-- Apply authoritative component angles from a validated pose packet.
-- Caller owns run/tick ordering, interpolation, root transform and radius.
function M.poseAngles(rig:Rig,root:CFrame,angles:{number})
 assert(#angles==#rig.design.joints,"Expected complete body pose")
 for _,a in angles do assert(a==a and math.abs(a)<=math.pi,"Invalid joint angle") end
 for i,joint in rig.design.joints do
  local p=joint.pivot
  local parent=if joint.parent>0 then rig.frames[joint.parent] else root
  rig.frames[i]=parent*CFrame.new(p[1]*rig.scale,p[2]*rig.scale,p[3]*rig.scale)
   *CFrame.fromAxisAngle(Vector3.new(joint.axis[1],joint.axis[2],joint.axis[3]),angles[i])
 end
 for _,state in rig.states do state.part.CFrame=rig.frames[state.joint]*state.bind end
end
function M.destroy(rig:Rig)
 rig.model:Destroy();table.clear(rig.states);table.clear(rig.frames)
end
return M
]====],
[6]=[====[
--!strict
-- Optional additive live detail. Original marker parts remain the picking/position authority.
local Workspace=game:GetService("Workspace")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Shared=RS:WaitForChild("Shared")
local Config=require(Shared.AgentPresentationConfig)
local Factory=require(Shared.AgentModelFactory)
if not Config.Enabled then return end
local root=Instance.new("Folder");root.Name="CI_AgentDetails";root.Parent=Workspace
local alive=true
local links:{RBXScriptConnection}={}
local markerLinks:{RBXScriptConnection}={}
local liveFolder:Instance?=nil
local markers:{[BasePart]:boolean}={}
type Handle={rig:Factory.Rig,heading:Vector3,last:Vector3,phase:number,oldTransparency:number,species:number}
local handles:{[BasePart]:Handle}={}
local function release(marker:BasePart)
 local h=handles[marker]
 if not h then return end
 if marker.Parent then marker.LocalTransparencyModifier=h.oldTransparency end
 Factory.destroy(h.rig);handles[marker]=nil
end
local function detach()
 for marker in handles do release(marker) end
 table.clear(markers)
 for _,link in markerLinks do link:Disconnect() end
 table.clear(markerLinks);liveFolder=nil
end
local function attach(folder:Instance)
 if folder==liveFolder then return end
 detach();liveFolder=folder
 local function add(child:Instance)
  if child:IsA("BasePart") and typeof(child:GetAttribute("CI_AgentId"))=="number" then markers[child]=true end
 end
 for _,child in folder:GetChildren() do add(child) end
 table.insert(markerLinks,folder.ChildAdded:Connect(add))
 table.insert(markerLinks,folder.ChildRemoved:Connect(function(child:Instance)
  if child:IsA("BasePart") then release(child);markers[child]=nil end
 end))
end
local function selectDetails()
 local folder=Workspace:FindFirstChild("CI_LivePresentation")
 if folder~=liveFolder then if folder then attach(folder) else detach() end end
 local camera=Workspace.CurrentCamera
 if not camera then return end
 type Candidate = {marker:BasePart,distance:number,species:number,id:number}
 local candidates:{Candidate}={}
 local pixels=camera.ViewportSize.Y/(2*math.tan(math.rad(camera.FieldOfView)*.5))
 for marker in markers do
  local species=marker:GetAttribute("CI_SpeciesId")
  if typeof(species)~="number" or species%1~=0 or species<0 or species>2 then release(marker);continue end
  local distance=(marker.Position-camera.CFrame.Position).Magnitude
  local active=handles[marker]
  local limit=if active then Config.ReleaseDistance else Config.DetailDistance
  local screen,onScreen=camera:WorldToViewportPoint(marker.Position)
  local apparent=marker.Size.X*.5*pixels/math.max(screen.Z,.01)
  if distance<=limit and onScreen and screen.Z>0 and apparent>=Config.MinimumProjectedRadiusPixels then
   table.insert(candidates,{marker=marker,distance=distance,species=species,id=marker:GetAttribute("CI_AgentId") :: number})
  else release(marker) end
 end
 table.sort(candidates,function(a:Candidate,b:Candidate)return if a.distance==b.distance then a.id<b.id else a.distance<b.distance end)
 local keep:{[BasePart]:boolean}={};local usedParts=0;local usedAgents=0
 for rank,candidate in candidates do
  local marker=candidate.marker
  local key=Config.SpeciesDesigns[candidate.species+1]
  local count=Factory.get(key).partCount
  if rank>Config.MaximumDetailedAgents or usedParts+count>Config.MaximumNativeParts then release(marker);continue end
  usedParts+=count;usedAgents+=1;keep[marker]=true
  local h=handles[marker]
  if h and h.species~=candidate.species then release(marker);h=nil end
  if not h then
   local rig=Factory.create(key,root,marker.Size.X*.5,2)
   rig.model:SetAttribute("CI_AgentId",candidate.id)
   h={rig=rig,heading=Vector3.new(0,0,-1),last=marker.Position,phase=(candidate.id%127)*.37,oldTransparency=marker.LocalTransparencyModifier,species=candidate.species}
   Factory.pose(rig,CFrame.new(marker.Position),h.phase,0)
   handles[marker]=h
  end
  marker.LocalTransparencyModifier=1
 end
 for marker in handles do if not keep[marker] then release(marker) end end
 root:SetAttribute("DetailedAgents",usedAgents)
 root:SetAttribute("NativeParts",usedParts)
end
local poseElapsed,selectElapsed=0,0
local function update(dt:number)
 if not alive then return end
 poseElapsed+=dt;selectElapsed+=dt
 if selectElapsed>=1/Config.SelectionHz then selectElapsed=0;selectDetails() end
 if poseElapsed<1/Config.PoseHz then return end
 local elapsed=poseElapsed;poseElapsed=0
 for marker,h in handles do
  if not marker.Parent then release(marker);continue end
  local position=marker.Position;local movement=position-h.last
  local speed=movement.Magnitude/math.max(elapsed,.001)
  if movement.Magnitude>.0002 then
   local blend=1-math.exp(-elapsed*10)
   local direction=h.heading:Lerp(movement.Unit,blend)
   if direction.Magnitude>.001 then h.heading=direction.Unit end
  end
  -- Idle flagellar motion is artistic, not measured propulsion or neural output.
  local strength=math.clamp(.2+speed*.3,.2,1)
  h.phase=(h.phase+math.min(elapsed,.15)*(2+math.min(speed,5))*math.pi)%(2*math.pi)
  local up=if math.abs(h.heading.Y)>.96 then Vector3.xAxis else Vector3.yAxis
  Factory.pose(h.rig,CFrame.lookAt(position,position+h.heading,up),h.phase,strength)
  h.last=position
 end
end
local function cleanup()
 if not alive then return end
 alive=false;RunService:UnbindFromRenderStep("CI.AgentDetails")
 detach();for _,link in links do link:Disconnect() end;root:Destroy()
end
RunService:BindToRenderStep("CI.AgentDetails",Enum.RenderPriority.Camera.Value+1,update)
table.insert(links,script.Destroying:Connect(cleanup))
table.insert(links,script:GetPropertyChangedSignal("Enabled"):Connect(function()if not script.Enabled then cleanup()end end))
]====],
[7]=[====[
--!strict
-- These modules are resolved dynamically in live folders and import packages.
local loadModule = require :: (ModuleScript) -> any
local M={}
local parent=script.Parent;assert(parent~=nil)
local packageRoot:Instance=parent
local function copy(value:Instance):Instance local clone=value:Clone();assert(clone~=nil);return clone end
local function module(folder:Instance,name:string):any local m=folder:FindFirstChild(name);assert(m~=nil and m:IsA("ModuleScript"));return loadModule(m) end
function M.Showroom()
 assert(not game:GetService("RunService"):IsRunning(),"Stop Play first")
 assert(workspace:FindFirstChild("CI_PlantShowroom")==nil,"Delete existing CI_PlantShowroom to rebuild")
 local shared=packageRoot:FindFirstChild("Shared");assert(shared~=nil)
 local Renderer=module(shared,"PlantRenderer");local records=module(shared,"PlantShowcaseData")
 local root=Instance.new("Folder");root.Name="CI_PlantShowroom";root.Parent=workspace
 local keyed={};for _,row in records do local p=table.clone(row);p.position={row.position[1],220,row.position[3]};keyed[p.id]=p end
 local renderer=Renderer.new(root)
 Renderer.select(renderer,keyed,Vector3.new(0,224,-20),{NearDistance=100,MidDistance=200,FarDistance=300,MaximumRenderedPlants=3,MaximumParts=2400},false)
 Renderer.pose(renderer,10,0)
 root:SetAttribute("Source","Actual C++ authored growth fixture. Static model review, not a running neural simulation.")
 local camera=workspace.CurrentCamera;if camera then camera.CFrame=CFrame.lookAt(Vector3.new(30,235,-35),Vector3.new(0,222,0)) end
 print("[Plants] Static baseline models at Y=220. Live plants require the C++ publisher; see START_HERE.")
end
function M.Install()
 assert(not game:GetService("RunService"):IsRunning(),"Stop Play before installation")
 assert(packageRoot:GetAttribute("Installed")~=true,"Already installed")
 local RS=game:GetService("ReplicatedStorage");local shared=RS:FindFirstChild("Shared");assert(shared~=nil,"Open existing CI place")
 local server=game:GetService("ServerScriptService"):FindFirstChild("Server");assert(server~=nil,"Server folder missing")
 local scripts=game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts");assert(scripts~=nil)
 local client=scripts:FindFirstChild("Client");assert(client~=nil)
 local controllers=client:FindFirstChild("Controllers");assert(controllers~=nil)
 local source=packageRoot:FindFirstChild("Shared");assert(source~=nil)
 local serverSource=packageRoot:FindFirstChild("Plants");assert(serverSource~=nil)
 local clientSource=packageRoot:FindFirstChild("PlantController");assert(clientSource~=nil)
 -- Validate the complete destination list before changing any sources.
 for _,item in source:GetChildren() do assert(shared:FindFirstChild(item.Name)==nil,"Already exists: Shared."..item.Name..". Update through source sync instead.") end
 assert(server:FindFirstChild("Plants")==nil and controllers:FindFirstChild("PlantController")==nil,"Plant scripts already present")
 for _,item in source:GetChildren() do local value=copy(item);value:SetAttribute("PlantKitOwned",true);value.Parent=shared end
 local a=copy(serverSource);a:SetAttribute("PlantKitOwned",true);a.Parent=server
 local b=copy(clientSource);b:SetAttribute("PlantKitOwned",true);b.Parent=controllers
 packageRoot:SetAttribute("Installed",true)
 print("[Plants] Installed. Export terrain, start the C++ plant publisher, then Play. P opens inspector; R toggles roots while inspecting.")
end
return M
]====],
[8]=[====[
--!strict
-- These modules are resolved dynamically in live folders and import packages.
local loadModule = require :: (ModuleScript) -> any
-- Import package under ServerStorage; showroom is independent of live installation.
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local StarterPlayer=game:GetService("StarterPlayer")
local parent=script.Parent;assert(parent~=nil)
local packageRoot:Instance=parent
local M={}
local function copy(source:Instance):Instance
 local value=source:Clone();assert(value~=nil,"Cannot clone "..source.Name);return value
end
local function requireModule(folder:Instance,name:string):any
 local item=folder:FindFirstChild(name);assert(item~=nil and item:IsA("ModuleScript"),"Missing "..name);return loadModule(item)
end
function M.Showroom()
 assert(not RunService:IsRunning(),"Stop Play before building the model showroom")
 assert(workspace:FindFirstChild("CI_AgentShowroom")==nil,"Showroom already exists; remove that folder to rebuild")
 local bundled=packageRoot:FindFirstChild("Shared");assert(bundled~=nil)
 local Factory=requireModule(bundled,"AgentModelFactory")
 local folder=Instance.new("Folder");folder.Name="CI_AgentShowroom";folder.Parent=workspace
 folder:SetAttribute("PresentationOnly",true)
 for i,design in Factory.designs() do
  local column=(i-1)%3;local row=math.floor((i-1)/3)
  local position=Vector3.new(column*22-22,220,row*24)
  local radius=if design.kind=="Live" then 5 else 8
  local rig=Factory.create(design.key,folder,radius,2)
  Factory.pose(rig,CFrame.new(position),0,0)
  rig.model:SetAttribute("PreviewRadius",radius)
  local plaque=Instance.new("Part");plaque.Name=design.key.."_Label"
  plaque.Size=Vector3.new(18,.2,2);plaque.Position=position+Vector3.new(0,-7,8)
  plaque.Anchored=true;plaque.CanCollide=false;plaque.CanTouch=false;plaque.CanQuery=false
  plaque.Material=Enum.Material.SmoothPlastic;plaque.Color=Color3.fromRGB(25,38,44);plaque.Parent=folder
  local gui=Instance.new("SurfaceGui");gui.Face=Enum.NormalId.Top;gui.CanvasSize=Vector2.new(900,100);gui.Parent=plaque
  local label=Instance.new("TextLabel");label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1
  label.Text=design.title.."  ·  native editable fallback";label.TextColor3=Color3.fromRGB(230,235,218)
  label.Font=Enum.Font.Gotham;label.TextScaled=true;label.Parent=gui
 end
 local camera=workspace.CurrentCamera
 if camera then camera.CFrame=CFrame.lookAt(Vector3.new(55,254,-53),Vector3.new(0,220,14)) end
 print("[Agents] Six editable native studies created. The refined production meshes are the separate glTF files.")
end
function M.EnableLive()
 assert(not RunService:IsRunning(),"Stop Play before installing live models")
 assert(packageRoot:GetAttribute("LiveInstalled")~=true,"Already installed")
 local shared=RS:FindFirstChild("Shared");assert(shared~=nil,"Open your existing CI place first")
 local scripts=StarterPlayer:FindFirstChild("StarterPlayerScripts");assert(scripts~=nil)
 local client=scripts:FindFirstChild("Client");assert(client~=nil,"StarterPlayerScripts.Client missing")
 local controllers=client:FindFirstChild("Controllers");assert(controllers~=nil,"Client.Controllers missing")
 local live=controllers:FindFirstChild("LiveController")
 if live==nil then live=controllers:FindFirstChild("LiveController.client") end
 assert(live~=nil and live:IsA("LocalScript"),"LiveController not found; no source was changed")
 local original=live.Source
 local old='part:SetAttribute("CI_AgentId",id);part.Position'
 local new='part:SetAttribute("CI_AgentId",id);part:SetAttribute("CI_SpeciesId",row[2]);part.Position'
 local start,finish=string.find(original,old,1,true)
 local already=string.find(original,'part:SetAttribute("CI_SpeciesId",row[2])',1,true)~=nil
 assert(start~=nil or already,"LiveController differs from the reviewed version; no source was changed")
 local source=packageRoot:FindFirstChild("Shared");assert(source~=nil)
 local template=packageRoot:FindFirstChild("AgentDetailController");assert(template~=nil and template:IsA("LocalScript"))
 assert(controllers:FindFirstChild("AgentDetailController")==nil,"Detail controller already exists")
 local backups=Instance.new("Folder");backups.Name="LiveBackups";backups.Parent=packageRoot
 local saved=Instance.new("StringValue");saved.Name="OriginalLiveController";saved.Value=original;saved.Parent=backups
 for _,item in source:GetChildren() do
  local existing=shared:FindFirstChild(item.Name)
  if existing then copy(existing).Parent=backups end
 end
 for _,item in source:GetChildren() do
  local existing=shared:FindFirstChild(item.Name)
  local replacement=copy(item);replacement:SetAttribute("AgentKitOwned",true)
  if existing then existing:Destroy() end
  replacement.Parent=shared
 end
 if start and finish then live.Source=string.sub(original,1,start-1)..new..string.sub(original,finish+1) end
 local detail=copy(template);detail.Name="AgentDetailController";detail:SetAttribute("AgentKitOwned",true);detail.Parent=controllers
 packageRoot:SetAttribute("LiveInstalled",true)
 print("[Agents] Live cosmetic detail installed. Stop/restart Play. IDs, collision radius, picking and biology are unchanged.")
end
function M.DisableLive()
 assert(not RunService:IsRunning(),"Stop Play before removing live detail")
 local backups=packageRoot:FindFirstChild("LiveBackups");assert(backups~=nil,"No installation backup")
 local shared=RS:FindFirstChild("Shared");assert(shared~=nil)
 local scripts=StarterPlayer:FindFirstChild("StarterPlayerScripts");assert(scripts~=nil)
 local client=scripts:FindFirstChild("Client");assert(client~=nil)
 local controllers=client:FindFirstChild("Controllers");assert(controllers~=nil)
 local detail=controllers:FindFirstChild("AgentDetailController")
 if detail and detail:GetAttribute("AgentKitOwned")==true then detail:Destroy() end
 local source=packageRoot:FindFirstChild("Shared");assert(source~=nil)
 for _,item in source:GetChildren() do
  local current=shared:FindFirstChild(item.Name)
  if current and current:GetAttribute("AgentKitOwned")==true then
   current:Destroy()
   local previous=backups:FindFirstChild(item.Name)
   if previous then copy(previous).Parent=shared end
  end
 end
 -- Leave harmless species metadata in LiveController; never overwrite later user edits.
 backups:Destroy();packageRoot:SetAttribute("LiveInstalled",false)
 print("[Agents] Detail removed and prior modules restored. Species metadata retained. Restart Play.")
end
return M
]====],
[9]=[====[
--!strict
-- Desktop research camera. Bounds include an explicit exterior overview margin.
return table.freeze({
	InitialHeightAboveSurfaceStuds = 35,
	InitialBackOffsetStuds = 100,
	InitialFocusDepthFraction = 0.5,
	BaseMoveSpeedStudsPerSecond = 45,
	BoostMultiplier = 3,
	MinimumMoveSpeedStudsPerSecond = 5,
	MaximumMoveSpeedStudsPerSecond = 250,
	MouseWheelSpeedStep = 5,
	MouseSensitivityRadiansPerPixel = 0.0025,
	MaximumPitchRadians = math.rad(85),
	MaximumFrameDeltaSeconds = 0.1,
	HorizontalOverviewMarginStuds = 1050,
	MaximumHeightAboveSurfaceStuds = 1000,
	FloorClearanceStuds = 0.5,
	FocusDistanceStuds = 30,
	RotateMouseButton = Enum.UserInputType.MouseButton2,
	ResetKey = Enum.KeyCode.R,
	BoostKey = Enum.KeyCode.LeftShift,
})
]====],
 }
local mapping={PlantRenderer=1,PlantController=2,Plants=3,AgentModelFactory=5,AgentDetailController=6}
local installers={ReferenceIslandPackage=4,PlantLifePackage=7,AgentModelPackage=8}
local pending={}
local function queue(target,source)
 if target.Source~=source then table.insert(pending,{target=target,source=source,original=target.Source}) end
end
for _,service in {"ReplicatedStorage","ServerStorage","ServerScriptService","StarterPlayer"} do
 for _,item in game:GetService(service):GetDescendants() do
  if item:IsA("LuaSourceContainer") then
   local name=item.Name:gsub("%.lua$",""):gsub("%.luau$",""):gsub("%.client$",""):gsub("%.server$","")
   local index=mapping[name]
   if name=="Install" and item.Parent then index=installers[item.Parent.Name] end
   local ancestor=item.Parent
   local allowed=false
   while ancestor do
    if ancestor.Name=="Shared" or ancestor.Name=="Controllers" or ancestor.Name=="Server" or installers[ancestor.Name] then allowed=true;break end
    ancestor=ancestor.Parent
   end
   if index and allowed then queue(item,sources[index]) end
   if service=="StarterPlayer" and (name=="Bootstrap" or name=="ClientBootstrap") then
    -- Preserve the legacy bootstrap's behavior; error() needs a string after pcall.
    local updated,count=item.Source:gsub("error%s*%(%s*([%a_][%w_]*)%s*([,)])",function(value,closing)
     return "error(tostring("..value..")"..closing
    end)
    if count>0 then queue(item,updated) else print("[Fix] Bootstrap unchanged; no error(variable) call: "..item:GetFullName()) end
   end
  end
 end
end
local shared=game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
assert(shared,"ReplicatedStorage.Shared missing; open your CI place")
local config=shared:FindFirstChild("ResearchCameraConfig")
assert(not config or config:IsA("ModuleScript"),"ResearchCameraConfig exists but is not a ModuleScript")
local backup=Instance.new("Folder")
backup.Name="WarningFixBackup_"..game:GetService("HttpService"):GenerateGUID(false)
backup.Parent=game:GetService("ServerStorage")
for i,change in pending do
 local saved=Instance.new("StringValue");saved.Name=tostring(i).."_"..change.target.Name;saved.Value=change.original;saved:SetAttribute("Path",change.target:GetFullName());saved.Parent=backup
 local target=Instance.new("ObjectValue");target.Name="Target";target.Value=change.target;target.Parent=saved
end
local created=nil
local ok,err=pcall(function()
 for _,change in pending do change.target.Source=change.source end
 if not config then
  created=Instance.new("ModuleScript");created.Name="ResearchCameraConfig";created.Source=sources[9];created.Parent=shared
 end
end)
if not ok then
 for _,change in pending do pcall(function()change.target.Source=change.original end) end
 if created then created:Destroy() end
 error(tostring(err))
end
print("[Fix] Updated "..#pending.." scripts. Camera config "..(if config then "already present" else "restored")..". Save the place. Backups: "..backup:GetFullName())
print("[Fix] Copy ZIP src/ and tools/ into your Roblox repository BEFORE reconnecting Rojo.")
