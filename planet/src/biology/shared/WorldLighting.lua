--!nonstrict
-- Sole live writer for world illumination. Observer grading remains a separate
-- cosmetic layer and is never sampled by C++ photoreception.
local Lighting=game:GetService("Lighting")
local M={}
function M.apply(day)
 day=math.clamp(day,0,1)
 Lighting.Brightness=.18+2.22*day
 Lighting.Ambient=Color3.fromRGB(16,20,30):Lerp(Color3.fromRGB(40,43,48),day)
 Lighting.OutdoorAmbient=Color3.fromRGB(24,30,44):Lerp(Color3.fromRGB(99,108,120),day)
 Lighting.ShadowSoftness=.35
 Lighting:SetAttribute("CI_WorldDaylight",day)
 if (Lighting:GetAttribute("CI_UnderwaterBlend") or 0)<=.001 then Lighting.ExposureCompensation=.2*(1-day)end
end
return M
