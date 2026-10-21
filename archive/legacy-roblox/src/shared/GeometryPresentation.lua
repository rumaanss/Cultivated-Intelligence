--!strict
local Geometry = require(script.Parent.SharedGeometry)
local Space = require(script.Parent.SimulationSpace)
local M = {}
-- Playback-only static proxies. Player state is NOT sent back to C++ yet.
function M.create(scene: Geometry.Scene, parent: Instance, debugMode: boolean, detailed: boolean?): Folder
 local folder = Instance.new("Folder")
 folder.Name = "CI_SharedGeometry"
 folder:SetAttribute("Revision",scene.revision)
 folder:SetAttribute("SourceSHA256",scene.sha256)
 folder:SetAttribute("BodyRadius",scene.bodyRadius)
 if scene.terrain ~= nil then
  local Lakebed = require(script.Parent.LakebedPresentation)
  Lakebed.create(scene,folder,detailed)
 end
 for _,obj in scene.objects do
  local part = Instance.new("Part")
  part.Name = "Geometry_" .. tostring(obj.id)
  part.Shape = if obj.shape == "sphere" then Enum.PartType.Ball else Enum.PartType.Block
  part.Size = Vector3.new(2*obj.halfSize[1],2*obj.halfSize[3],2*obj.halfSize[2])
  part.Position = Space.toRobloxXYZ(obj.center[1],obj.center[2],obj.center[3])
  part.Anchored,part.CanCollide,part.CanTouch = true,obj.solid,false
  part.CanQuery,part.CastShadow = true,obj.opaque
  part.Material = if obj.material == "Sand" then Enum.Material.Sand elseif obj.material == "Rock" then Enum.Material.Rock else Enum.Material.Slate
  part.Color = if obj.material == "Sand" then Color3.fromRGB(149,133,95) else Color3.fromRGB(78,94,96)
  part.Transparency = if obj.opaque then 0 else 0.6
  part:SetAttribute("GeometryID",obj.id)
  part:SetAttribute("Source","C++Recording")
  part.Parent = folder
  if debugMode then
   local outline = Instance.new("SelectionBox")
   outline.Adornee,outline.LineThickness = part,0.035
   outline.Color3,outline.SurfaceTransparency = Color3.fromRGB(80,240,220),1
   outline.Parent = part
  end
 end
 folder.Parent = parent
 return folder
end
return M
