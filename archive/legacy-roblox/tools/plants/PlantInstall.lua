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
