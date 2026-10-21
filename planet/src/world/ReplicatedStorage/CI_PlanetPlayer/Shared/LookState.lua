--!nonstrict
-- Pure state machine: rendering consumes this state; physics never writes it.
local F = require(script.Parent.PlanetFrame)
local InputFilter=require(script.Parent.LookInput)
local L = {}; L.__index = L
function L.new(up, forward, config)
 return setmetatable({up=up, forward=forward, pitch=0, yaw=0, mode="Normal", config=config, returning=0, sensitivity=math.deg(config.MouseRadiansPerPixel), filteredSamples=0}, L)
end
function L.step(self: any, up: Vector3, dx: number, dy: number, free: boolean, dt: number)
 local c = self.config
 self.sensitivity=math.clamp(self.sensitivity,c.SensitivityMin,c.SensitivityMax)
 local gain=math.rad(self.sensitivity)
 local filtered
 dx,dy,filtered=InputFilter.filter(dx,dy,gain,c.MaxLookSampleRadians)
 if filtered then self.filteredSamples+=1 end
 self.forward = F.transport(self.forward, self.up, up); self.up=up
 if free and self.mode ~= "Free" then
  -- Re-enter during a return without changing the retained travel basis.
  self.mode="Free"; self.returning=0
 elseif not free and self.mode == "Free" then
  self.mode="Return"; self.returning=0; self.returnYaw=self.yaw; self.returnPitch=self.pitch
 end
 if self.mode == "Return" then
  if math.abs(dx)+math.abs(dy) > 0 then
   -- Fresh input takes control of current gaze, avoiding lost flick input.
   self.forward=F.rotate(self.forward,up,self.yaw); self.yaw=0; self.mode="Normal"
  else
   self.returning+=dt
   local t=math.clamp(self.returning/c.RecenterSeconds,0,1); local eased=t*t*(3-2*t)
   self.yaw=self.returnYaw*(1-eased)
   self.pitch=self.returnPitch+(math.clamp(self.returnPitch,-c.NormalPitchDown,c.NormalPitchUp)-self.returnPitch)*eased
   if t>=1 then self.mode="Normal"; self.yaw=0 end
  end
 end
 if self.mode == "Normal" then
  self.forward=F.rotate(self.forward,up,-dx*gain)
  -- A return interrupted at -90 degrees must not snap instantly to -75.
  local lower=math.min(-c.NormalPitchDown,self.pitch)
  local upper=math.max(c.NormalPitchUp,self.pitch)
  self.pitch=math.clamp(self.pitch-dy*gain,lower,upper)
  local target=math.clamp(self.pitch,-c.NormalPitchDown,c.NormalPitchUp)
  self.pitch+=(target-self.pitch)*(1-math.exp(-20*math.max(0,dt)))
 elseif self.mode == "Free" then
  self.yaw=math.clamp(self.yaw-dx*gain,-c.FreeYaw,c.FreeYaw)
  self.pitch=math.clamp(self.pitch-dy*gain,-c.FreePitchDown,c.FreePitchUp)
 end
 local flat=F.rotate(self.forward,up,self.yaw)
 self.gaze=flat*math.cos(self.pitch)+up*math.sin(self.pitch)
 self.viewUp=up*math.cos(self.pitch)-flat*math.sin(self.pitch)
 self.flat=flat
 return self
end
return L
