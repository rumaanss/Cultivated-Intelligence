-- Paste into the Studio CLIENT command bar while playing. Read-only inventory.
local Lighting=game:GetService("Lighting")
local root=workspace:FindFirstChild("CI_PlanetCelestial")
print("[Sky diagnostic]",root and root:GetAttributes())
for _,container in {Lighting,workspace.Terrain}do
 for _,item in container:GetChildren()do
  if item:IsA("Sky") or item:IsA("Atmosphere") or item:IsA("PostEffect") or item:IsA("Clouds")then
   print(item.ClassName,item:GetFullName())
  end
 end
end
print("In Explorer select CI_PlanetCelestial. Compare DiagnosticMode: Normal, OriginalSky, EngineAtmosphere. Restore Normal afterwards.")
print("To isolate underwater effects, set Lighting attribute CI_DisableWaterPresentation=true; remove it afterwards. Physics and biology are unaffected.")
