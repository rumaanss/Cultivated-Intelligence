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
