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
  -- Interest selection already bounds the population on the server. Keep
  -- each received organism's real model regardless of camera distance.
  table.insert(candidates,{marker=marker,distance=distance,species=species,id=marker:GetAttribute("CI_AgentId") :: number})
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
