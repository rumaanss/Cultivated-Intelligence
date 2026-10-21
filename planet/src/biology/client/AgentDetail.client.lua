--!strict
-- Optional additive live detail. Original marker parts remain the picking/position authority.
local Workspace=game:GetService("Workspace")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Shared=RS:WaitForChild("CI_Biology")
local Config=require(Shared.AgentPresentationConfig)
local Factory=require(Shared.AgentModelFactory)
if not Config.Enabled then return end
local root=Instance.new("Folder");root.Name="CI_AgentDetails";root.Parent=Workspace
local alive=true
local links:{RBXScriptConnection}={}
local markerLinks:{RBXScriptConnection}={}
local liveFolder:Instance?=nil
local markers:{[BasePart]:boolean}={}
type Handle={rig:Factory.Rig,heading:Vector3,last:Vector3,phase:number,oldTransparency:number,species:number,detail:number,poseAt:number}
local handles:{[BasePart]:Handle}={}
local detailLimit=Config.MaximumDetailedAgents
local liveParts=0
local pool:{Factory.Rig}={}
local function release(marker:BasePart)
 local h:Handle?=handles[marker]
 if not h then return end
 if marker.Parent then marker.LocalTransparencyModifier=h.oldTransparency end
 liveParts-=#h.rig.states
 if #pool<12 then h.rig.model.Parent=nil;table.insert(pool,h.rig)else Factory.destroy(h.rig)end
 handles[marker]=nil
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
  if child:IsA("BasePart") and typeof(child:GetAttribute("CI_OrganismId"))=="number" then markers[child]=true end
 end
 for _,child in folder:GetChildren() do add(child) end
 table.insert(markerLinks,folder.ChildAdded:Connect(add))
 table.insert(markerLinks,folder.ChildRemoved:Connect(function(child:Instance)
  if child:IsA("BasePart") then release(child);markers[child]=nil end
 end))
end
local function selectDetails()
 local folder=Workspace:FindFirstChild("CI_PlanetMicrobes")
 if folder~=liveFolder then if folder then attach(folder) else detach() end end
 local camera=Workspace.CurrentCamera
 if not camera then return end
 type Candidate = {marker:BasePart,distance:number,species:number,id:number,selected:boolean,near:boolean}
 local candidates:{Candidate}={}
 local provider=RS:FindFirstChild("CI_ResearchData")
 local frameMs=provider and provider:GetAttribute("ClientFrameMs")
 if typeof(frameMs)=="number" then
  if frameMs>22 then detailLimit=math.max(1,math.floor(Config.MaximumDetailedAgents/2))
  elseif frameMs<17 then detailLimit=Config.MaximumDetailedAgents end
 end
 local pixels=camera.ViewportSize.Y/(2*math.tan(math.rad(camera.FieldOfView)*.5))
 for marker in markers do
  local species=marker:GetAttribute("CI_SpeciesId")
  if typeof(species)~="number" or species%1~=0 or species<0 or species>2 then release(marker);continue end
  local distance=(marker.Position-camera.CFrame.Position).Magnitude
  -- Bound detailed rigs by distance and projected size as well as server interest.
  local existing=handles[marker]~=nil
  local selected=Workspace:GetAttribute("CI_SelectedOrganismId")==marker:GetAttribute("CI_OrganismId")
  local near=selected or (distance<=(if existing then Config.ReleaseDistance else Config.DetailDistance) and marker.Size.X*.5*pixels/math.max(distance,.01)>=Config.MinimumProjectedRadiusPixels)
  table.insert(candidates,{marker=marker,distance=distance,species=species,id=marker:GetAttribute("CI_OrganismId") :: number,selected=selected,near=near})
 end
 table.sort(candidates,function(a:Candidate,b:Candidate)if a.selected~=b.selected then return a.selected end;return if a.distance==b.distance then a.id<b.id else a.distance<b.distance end)
 local keep:{[BasePart]:boolean}={};local usedParts=0;local usedAgents=0;local highCount=0;local createdParts=0;local began=os.clock()
 for rank,candidate in candidates do
  local marker=candidate.marker
  local key=Config.SpeciesDesigns[candidate.species+1]
  local detail=if candidate.near and highCount<detailLimit then 2 else 0
  if detail==2 then highCount+=1 end
  local count=Factory.count(key,detail)
  if usedParts+count>Config.MaximumNativeParts then detail=0;count=Factory.count(key,0)end
  if usedParts+count>Config.MaximumNativeParts then release(marker);continue end
  usedParts+=count;usedAgents+=1;keep[marker]=true
  local h:Handle?=handles[marker]
  if h and (h.species~=candidate.species or h.detail~=detail) and createdParts+count<=64 and os.clock()-began<.002 then release(marker);h=nil end
  if not h then
   if liveParts+count>Config.MaximumNativeParts or createdParts+count>64 or (createdParts>0 and os.clock()-began>=.002) then continue end
   createdParts+=count
   local rig:Factory.Rig?=nil
   for i=#pool,1,-1 do
    local cached=pool[i]
    if cached.design.key==key and #cached.states==count and cached.scale==marker.Size.X*.5/Factory.get(key).safeRadius then rig=table.remove(pool,i);break end
   end
   if not rig then rig=Factory.create(key,root,marker.Size.X*.5,detail)else rig.model.Parent=root end
   assert(rig~=nil)
   liveParts+=#rig.states
   rig.model:SetAttribute("CI_OrganismId",candidate.id)
   h={rig=rig,heading=Vector3.new(0,0,-1),last=marker.Position,phase=(candidate.id%127)*.37,oldTransparency=marker.LocalTransparencyModifier,species=candidate.species,detail=detail,poseAt=os.clock()}
   Factory.pose(rig,CFrame.new(marker.Position),h.phase,0)
   handles[marker]=h
  end
  assert(h~=nil)
  marker.LocalTransparencyModifier=1
  marker:SetAttribute("CI_DetailLevel",h.detail)
 end
 for marker in handles do if not keep[marker] then release(marker) end end
 root:SetAttribute("DetailedAgents",usedAgents)
 root:SetAttribute("NativeParts",liveParts)
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
  local now=os.clock()
  if h.detail==0 and now-h.poseAt<.125 then continue end
  local poseDt=math.max(now-h.poseAt,.001);h.poseAt=now
  local position=marker.Position;local movement=position-h.last
  local speed=movement.Magnitude/poseDt
  if movement.Magnitude>.0002 then
   local blend=1-math.exp(-elapsed*10)
   local direction=h.heading:Lerp(movement.Unit,blend)
   if direction.Magnitude>.001 then h.heading=direction.Unit end
  end
  -- Idle flagellar motion is artistic, not measured propulsion or neural output.
  local fresh=marker:GetAttribute("CI_BiologyTimestamp")
  local live=typeof(fresh)=="number" and Workspace:GetServerTimeNow()-fresh<3
  local strength=if live then math.clamp(.2+speed*.3,.2,1)else 0
  h.phase=(h.phase+math.min(elapsed,.15)*(2+math.min(speed,5))*math.pi)%(2*math.pi)
  local radial=position.Unit
  local up=if math.abs(h.heading:Dot(radial))>.96 then Vector3.xAxis else radial
  Factory.pose(h.rig,CFrame.lookAt(position,position+h.heading,up),h.phase,strength)
  h.last=position
 end
end
local function cleanup()
 if not alive then return end
 alive=false;RunService:UnbindFromRenderStep("CI.AgentDetails")
 detach();for _,rig in pool do Factory.destroy(rig)end;table.clear(pool);for _,link in links do link:Disconnect() end;root:Destroy()
end
RunService:BindToRenderStep("CI.AgentDetails",Enum.RenderPriority.Camera.Value+1,update)
table.insert(links,script.Destroying:Connect(cleanup))
table.insert(links,script:GetPropertyChangedSignal("Enabled"):Connect(function()if not script.Enabled then cleanup()end end))
