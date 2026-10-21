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
