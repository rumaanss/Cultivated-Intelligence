--!strict
-- Pure visual model: one coherent sun/moon state, independent of biology units.
local Config = require(script.Parent.LightingCalibration)
local M = {}
local function smooth(a:number,b:number,x:number):number
 local t=math.clamp((x-a)/(b-a),0,1)
 return t*t*(3-2*t)
end
function M.evaluate(sunHeight:number,moonHeight:number)
 local day=smooth(-0.10,0.30,sunHeight)
 local moon=smooth(-0.035,0.35,moonHeight)*(1-day)
 local dusk=(1-smooth(0.03,0.24,math.abs(sunHeight)))
 return {
  day=day, moon=moon,
  brightness=0.45*(1-day)+Config.MoonBrightness*moon+2.4*day,
  exposure=Config.NightExposure*(1-day)+Config.DayExposure*day,
  ambient=Config.NightAmbient:Lerp(Config.DayAmbient,day),
  outdoor=Config.NightOutdoorAmbient:Lerp(Config.DayOutdoorAmbient,day),
  fog=Color3.fromRGB(42,58,85):Lerp(Color3.fromRGB(164,191,214),day),
  fogStart=0, fogEnd=100000, -- Atmosphere owns air extinction; no nearby fog wall.
  diffuse=0.15+0.55*day, specular=0.32+0.16*day,
  top=Color3.fromRGB(5,8,15):Lerp(Color3.fromRGB(0,0,0),day):Lerp(Color3.fromRGB(25,12,3),dusk*.5),
 }
end
return M
