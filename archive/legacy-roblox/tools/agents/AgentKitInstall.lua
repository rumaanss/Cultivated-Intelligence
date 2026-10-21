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
