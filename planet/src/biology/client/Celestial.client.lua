--!nonstrict
-- Bounded physical presentation; C++ remains the biological light authority.
local RS=game:GetService("ReplicatedStorage")
local Lighting=game:GetService("Lighting")
local Run=game:GetService("RunService")
local shared=RS:WaitForChild("CI_Biology")
local contract=require(shared.PlanetContract)
local Clock=require(shared.SolarClock)
local up=Vector3.new(table.unpack(contract.habitat.frame.up))
local east=Vector3.new(table.unpack(contract.habitat.frame.east))
local center=Vector3.new(table.unpack(contract.habitat.frame.center))
local radius=contract.habitat.frame.radius
local root=Instance.new("Folder");root.Name="CI_PlanetCelestial";root:SetAttribute("VisualOnly",true);root:SetAttribute("DiagnosticMode","Normal");root.Parent=workspace
local savedHour,savedLatitude=Lighting.ClockTime,Lighting.GeographicLatitude
local function direction(hour,latitude)
 Lighting.ClockTime=hour%24;Lighting.GeographicLatitude=latitude
 return Lighting:GetSunDirection()
end
-- Engine solar declination prevents some radial zeniths from reaching 1.0.
-- Fit the entire reachable day/night arc instead of aborting sky creation.
local fit,bestLatitude,bestScore=nil,savedLatitude,-math.huge
for latitude=-180,180,30 do
 local heights={}
 for i,hour in {0,6,12,18}do
  direction(hour,latitude);Run.Heartbeat:Wait()
  heights[i]=Lighting:GetSunDirection():Dot(up)
 end
 local candidate=Clock.fit(table.unpack(heights))
 local score=math.min(candidate.maximum,-candidate.minimum)
 if candidate.amplitude>.001 and score>bestScore then fit,bestLatitude,bestScore=candidate,latitude,score end
end
Lighting.ClockTime=savedHour;Lighting.GeographicLatitude=savedLatitude
local orientation=1
if fit and bestScore>0 then
 orientation=if direction(Clock.hour(fit,0,1),bestLatitude):Dot(east)>=0 then 1 else -1
 root:SetAttribute("ZenithFit",fit.maximum)
 root:SetAttribute("EngineSolarApproximation",true)
else
 fit=nil;root:SetAttribute("EngineSolarApproximation",true)
 warn("[CI Sky] Engine radial fit unavailable; canonical celestial bodies and biological light remain active")
end
Lighting.ClockTime=savedHour
-- A dedicated instance makes ownership explicit. Keep the baseline intact for
-- failure recovery and shutdown, rather than borrowing a potentially shared Sky.
local baselineSky=Lighting:FindFirstChildOfClass("Sky")
local sky=Instance.new("Sky");sky.Name="CI_PlanetSky"
if baselineSky then
 for _,key in {"SkyboxBackContent","SkyboxFrontContent","SkyboxRightContent","SkyboxLeftContent","SkyboxUpContent","SkyboxDownContent","SunTextureId","MoonTextureId"}do sky[key]=baselineSky[key]end
end
sky.SunAngularSize=0;sky.MoonAngularSize=0;sky.StarCount=1800;sky.CelestialBodiesShown=true
local function body(name,color,angular,texture)
 local part=Instance.new("Part");part.Name=name;part.Shape=Enum.PartType.Ball;part.Anchored=true
 part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
 part.Material=Enum.Material.Neon;part.Color=color
 local diameter=2*12000*math.tan(math.rad(angular)*.5);part.Size=Vector3.one*diameter
 part.Parent=root
 if texture~="" then
  part.Transparency=1
  local gui=Instance.new("BillboardGui");gui.Size=UDim2.fromScale(diameter,diameter);gui.LightInfluence=0;gui.AlwaysOnTop=false;gui.Adornee=part;gui.Parent=part
  local image=Instance.new("ImageLabel");image.Size=UDim2.fromScale(1,1);image.BackgroundTransparency=1;image.Image=texture;image.Parent=gui
 end
 return part
end
local sun=body("Sun",Color3.fromRGB(255,242,207),1.1,"")
local moon=body("Moon",Color3.fromRGB(209,222,241),1.6,sky.MoonTextureId)
local rays=Instance.new("SunRaysEffect");rays.Name="CI_PlanetSunRays";rays.Intensity=.025;rays.Spread=.75;rays.Parent=Lighting
-- Above-water ownership: suspend global-Y atmosphere and clouds while the
-- radial sky supplies horizon radiance. Water publishes its actual lake blend.
local RadialSky=require(shared.RadialSky)
local radial,radialError=RadialSky.new(sky,root)
local suspended=Instance.new("Folder");suspended.Name="OriginalSkyContributions";suspended.Parent=root
local parked={}
local restoring=false
local function park(object)
 if restoring or object==sky then return end
 local conflict=object:IsA("Sky") or object:IsA("Clouds")
  or (object:IsA("Atmosphere") and object.Name~="CI_LakeScattering")
 if conflict and object.Parent~=suspended then
  if not parked[object] then parked[object]=object.Parent end
  object.Parent=suspended
 end
end
if radial then
 sky.SkyboxOrientation=Vector3.zero
 for _,object in Lighting:GetChildren()do park(object)end
 for _,object in workspace.Terrain:GetChildren()do park(object)end
 sky.Parent=Lighting
 root:SetAttribute("SkyRenderer","Planetary celestial sky v3")
 root:SetAttribute("SkyState","Preparing")
else
 -- No partially initialized sky is installed on allocation failure.
 root:SetAttribute("SkyRenderer","Original retained: "..tostring(radialError))
 warn("[CI Sky] Planetary presentation unavailable: "..tostring(radialError))
end
local added=Lighting.ChildAdded:Connect(function(object)if radial then park(object)end end)
local terrainAdded=workspace.Terrain.ChildAdded:Connect(function(object)if radial then park(object)end end)
local oldLighting={}
for _,key in {"Brightness","Ambient","OutdoorAmbient","ExposureCompensation"}do oldLighting[key]=Lighting[key]end
local elapsed,lastTick,lastAt,rate=0,nil,os.clock(),0
local solarDirection=east
local phase=0
local cycles=0
local cycleLength=600
local originalMoonTransparency=moon.Transparency
root:SetAttribute("PerformanceProbeVersion",1)
local models=nil
local shuttingDown=false
task.spawn(function()
 local Models=require(shared.CelestialModels)
 local value,err=Models.new(root,center,radius,east,up)
 if shuttingDown then if value then value.Destroy()end;return end
 if value then
  models=value;moon.Transparency=1
  for _,object in moon:GetChildren()do if object:IsA("BillboardGui")then object.Enabled=false end end
  root:SetAttribute("CelestialModels","celestial-1")
 else root:SetAttribute("CelestialModels","Original moon retained: "..tostring(err));warn("[CI Sky] Models unavailable: "..tostring(err))end
end)
local connection=Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.05 then return end;elapsed=0
 local provider=RS:FindFirstChild("CI_ResearchData");local camera=workspace.CurrentCamera
 if not camera then return end
 if provider and provider:GetAttribute("BiologyConnected")==true then
  local tick,cycle=provider:GetAttribute("SimulationTick"),provider:GetAttribute("CycleTicks")
  if type(tick)=="number" and type(cycle)=="number" and cycle>0 then
   local now=os.clock()
   if lastTick~=tick then
    if lastTick and tick>lastTick then rate=math.clamp((tick-lastTick)/math.max(now-lastAt,.001),0,30) else rate=0 end
    lastTick,lastAt=tick,now
   end
   local visualTick=tick+math.min(now-lastAt,.2)*rate
   cycleLength=cycle
   cycles=visualTick/cycle
   phase=cycles%1
   solarDirection=(east*math.cos(phase*2*math.pi)+up*math.sin(phase*2*math.pi)).Unit
   if fit then Lighting.GeographicLatitude=bestLatitude end
   Lighting.ClockTime=if fit then Clock.hour(fit,phase,orientation) else (phase*24+6)%24
   root:SetAttribute("Daylight",math.max(0,math.sin(phase*2*math.pi)))
   root:SetAttribute("SolarDirection",solarDirection)
   root:SetAttribute("EngineDirectionErrorDegrees",math.deg(math.acos(math.clamp(Lighting:GetSunDirection():Dot(solarDirection),-1,1))))
   root:SetAttribute("Status","Simulation clock");root:SetAttribute("BiologicalTick",tick)
  end
 else root:SetAttribute("Status","Clock held: biology unavailable") end
 local position=camera.CFrame.Position
 sun.Position=position+solarDirection*12000;moon.Position=position-solarDirection*12000
 local localUp=(position-center).Unit
 local waterBlend=Lighting:GetAttribute("CI_UnderwaterBlend") or 0
 local submerged=waterBlend>.001
 local day=math.clamp((solarDirection:Dot(localUp)+.12)/.35,0,1)
 sky.StarCount=if radial then 0 else math.floor(1800*(1-day)^2)
 root:SetAttribute("LocalUp",localUp);root:SetAttribute("UnderwaterBlend",waterBlend)
 if not submerged then
  Lighting.Brightness=.18+2.22*day
  Lighting.Ambient=Color3.fromRGB(16,20,30):Lerp(Color3.fromRGB(40,43,48),day)
  Lighting.OutdoorAmbient=Color3.fromRGB(24,30,44):Lerp(Color3.fromRGB(99,108,120),day)
  Lighting.ExposureCompensation=.2*(1-day)
 end
 rays.Enabled=not submerged and solarDirection:Dot((position-center).Unit)>0 and root:GetAttribute("EngineDirectionErrorDegrees")~=nil and root:GetAttribute("EngineDirectionErrorDegrees")<5
end)
-- Rendering work has its own bounded heartbeat budget; it does not wait on the
-- relay or run inside the 20 Hz lighting/clock update.
local renderConnection=Run.Heartbeat:Connect(function()
 local camera=workspace.CurrentCamera
 if models and camera and root:GetAttribute("FreezeCelestialModels")~=true then
  local modelCycles=if lastTick then (lastTick+math.min(os.clock()-lastAt,.2)*rate)/cycleLength else cycles
  local ok,err=pcall(models.Update,camera.CFrame.Position,modelCycles,solarDirection,Lighting:GetAttribute("CI_UnderwaterBlend") or 0,os.clock())
  if not ok then models.Destroy();models=nil;moon.Transparency=originalMoonTransparency
   for _,object in moon:GetChildren()do if object:IsA("BillboardGui")then object.Enabled=true end end
   root:SetAttribute("CelestialModels","Original moon retained: "..tostring(err))
   warn("[CI Sky] Model update stopped: "..tostring(err))
  end
 end
 if not radial or root:GetAttribute("FreezeSkyBaking")==true then return end
 local camera=workspace.CurrentCamera;if not camera then return end
 local offset=camera.CFrame.Position-center
 if offset.Magnitude<1 then return end
 local mode=root:GetAttribute("DiagnosticMode") or "Normal"
 local valid=mode=="Normal" or mode=="Solid" or mode=="Faces" or mode=="Horizon" or mode=="OriginalSky"
 if not valid then mode="Normal";root:SetAttribute("DiagnosticMode",mode)end
 sky.SkyboxOrientation=Vector3.zero
 radial.SetEnabled(mode~="OriginalSky")
 local ok,err=pcall(radial.Update,offset.Unit,solarDirection,os.clock(),math.max(0,offset.Magnitude-radius),radius,mode)
 if not ok then
  radial.Destroy();radial=nil;restoring=true
  sky.Parent=nil
  for object,parent in parked do if object.Parent==suspended then object.Parent=parent end end
  root:SetAttribute("SkyState","Failed: "..tostring(err))
  root:SetAttribute("SkyRenderer","Original retained after update failure")
  warn("[CI Sky] Update failed; original sky restored: "..tostring(err))
 end
end)
script.Destroying:Connect(function()
 shuttingDown=true;restoring=true
 if models then models.Destroy();models=nil end
 connection:Disconnect();renderConnection:Disconnect();added:Disconnect();terrainAdded:Disconnect()
 if radial then radial.Destroy()end
 sky:Destroy()
 for object,parent in parked do if object.Parent==suspended then object.Parent=parent end end
 for key,value in oldLighting do Lighting[key]=value end
 Lighting.ClockTime=savedHour;Lighting.GeographicLatitude=savedLatitude
 rays:Destroy();root:Destroy()
end)
