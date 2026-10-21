--!strict
local Lighting=game:GetService("Lighting")
local Workspace=game:GetService("Workspace")
local Config=require(script.Parent.LightingReworkConfig)
local Calibration=require(script.Parent.LightingCalibration)
local M={}
function M.new()
 local parkedGrades:{ColorCorrectionEffect}={}
 local function isolate(container:Instance)
  if not Calibration.DisablePreexistingColorGrading then return end
  for _,effect in container:GetChildren() do
   if effect:IsA("ColorCorrectionEffect") and effect.Enabled then
    table.insert(parkedGrades,effect);effect.Enabled=false
    print("[CI Lighting] Suspended pre-existing grade: "..effect:GetFullName())
   end
  end
 end
 isolate(Lighting)
 if Workspace.CurrentCamera then isolate(Workspace.CurrentCamera) end
 local old={GlobalShadows=Lighting.GlobalShadows,ShadowSoftness=Lighting.ShadowSoftness,
  EnvironmentDiffuseScale=Lighting.EnvironmentDiffuseScale,EnvironmentSpecularScale=Lighting.EnvironmentSpecularScale,
  ColorShift_Top=Lighting.ColorShift_Top,ColorShift_Bottom=Lighting.ColorShift_Bottom}
 Lighting.GlobalShadows=true;Lighting.ShadowSoftness=.35;Lighting.ColorShift_Bottom=Color3.new(0,0,0)
 local existingAtmosphere=Lighting:FindFirstChildOfClass("Atmosphere")
 local atmosphere:Atmosphere=existingAtmosphere or Instance.new("Atmosphere")
 local oldAtmosphere={Density=atmosphere.Density,Offset=atmosphere.Offset,Color=atmosphere.Color,Decay=atmosphere.Decay,Haze=atmosphere.Haze,Glare=atmosphere.Glare}
 atmosphere.Name=if existingAtmosphere then atmosphere.Name else "CI_CycleAtmosphere"
 atmosphere.Parent=Lighting
 local terrain = Workspace:WaitForChild("Terrain") :: Terrain
 local existingClouds=terrain:FindFirstChildOfClass("Clouds")
 local clouds:Clouds=existingClouds or Instance.new("Clouds")
 local oldClouds={Enabled=clouds.Enabled,Cover=clouds.Cover,Density=clouds.Density,Color=clouds.Color}
 clouds.Name=if existingClouds then clouds.Name else "CI_DynamicClouds"
 clouds.Enabled=true;clouds.Parent=terrain
 local bloom=Instance.new("BloomEffect")
 bloom.Name="CI_RestrainedBloom";bloom.Intensity=.025;bloom.Size=14;bloom.Threshold=2;bloom.Parent=Lighting
 local destroyed=false
 local function update()
  if destroyed then return end
  local value=Workspace:GetAttribute("CI_VisualDay")
  local day=if type(value)=="number" then math.clamp(value,0,1) else 1
  atmosphere.Density=.28-.10*day;atmosphere.Offset=0
  atmosphere.Color=Color3.fromRGB(172,188,220):Lerp(Color3.fromRGB(205,222,240),day)
  atmosphere.Decay=Color3.fromRGB(65,77,103):Lerp(Color3.fromRGB(106,124,146),day)
  atmosphere.Haze=1.1-.55*day;atmosphere.Glare=.08*day
  clouds.Cover=Config.CloudCover*(.65+.35*day);clouds.Density=Config.CloudDensity
  clouds.Color=Color3.fromRGB(169,184,208):Lerp(Color3.fromRGB(242,244,249),day)
 end
 update()
 return {Update=update,Destroy=function()
  if destroyed then return end;destroyed=true;bloom:Destroy()
  Lighting.GlobalShadows=old.GlobalShadows;Lighting.ShadowSoftness=old.ShadowSoftness
  Lighting.EnvironmentDiffuseScale=old.EnvironmentDiffuseScale;Lighting.EnvironmentSpecularScale=old.EnvironmentSpecularScale
  Lighting.ColorShift_Top=old.ColorShift_Top;Lighting.ColorShift_Bottom=old.ColorShift_Bottom
  for _,effect in parkedGrades do if effect.Parent then effect.Enabled=true end end
  if existingAtmosphere then
   atmosphere.Density=oldAtmosphere.Density;atmosphere.Offset=oldAtmosphere.Offset;atmosphere.Color=oldAtmosphere.Color
   atmosphere.Decay=oldAtmosphere.Decay;atmosphere.Haze=oldAtmosphere.Haze;atmosphere.Glare=oldAtmosphere.Glare
  else atmosphere:Destroy() end
  if existingClouds then
   clouds.Enabled=oldClouds.Enabled;clouds.Cover=oldClouds.Cover;clouds.Density=oldClouds.Density;clouds.Color=oldClouds.Color
  else clouds:Destroy() end
  for _,name in {"CI_BaseExposure","CI_BaseFogColor","CI_BaseFogStart","CI_BaseFogEnd","CI_VisualDay","CI_VisualMoon","CI_LightingBuild"} do Workspace:SetAttribute(name,nil) end
 end}
end
return M
