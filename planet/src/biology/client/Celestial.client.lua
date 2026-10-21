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
local root=Instance.new("Folder");root.Name="CI_PlanetCelestial";root:SetAttribute("VisualOnly",true);root.Parent=workspace
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
local sky=Lighting:FindFirstChildOfClass("Sky");local ownedSky=not sky
if not sky then sky=Instance.new("Sky");sky.Name="CI_PlanetSky";sky.Parent=Lighting end
local oldOrientation=sky.SkyboxOrientation
local oldSun,oldMoon,oldStars,oldBodies=sky.SunAngularSize,sky.MoonAngularSize,sky.StarCount,sky.CelestialBodiesShown
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
local sun=body("Sun",Color3.fromRGB(255,242,207),1.1,sky.SunTextureId)
local moon=body("Moon",Color3.fromRGB(209,222,241),1.6,sky.MoonTextureId)
local rays=Instance.new("SunRaysEffect");rays.Name="CI_PlanetSunRays";rays.Intensity=.025;rays.Spread=.75;rays.Parent=Lighting
-- The accepted water controller owns underwater scattering. Create atmosphere
-- only if the world has none, and park ours whenever water scattering is active.
local air=nil
local existing=Lighting:FindFirstChildOfClass("Atmosphere")
local waterRoot=workspace:FindFirstChild("CI_LakePresentation")
local parked=waterRoot and waterRoot:FindFirstChild("SuspendedAtmospheres")
if not existing and not (parked and parked:FindFirstChildOfClass("Atmosphere")) then
 air=Instance.new("Atmosphere");air.Name="CI_PlanetAir";air.Density=.23;air.Offset=.1;air.Color=Color3.fromRGB(190,212,232);air.Decay=Color3.fromRGB(103,132,163);air.Glare=.12;air.Haze=1.1;air.Parent=Lighting
end
local elapsed,lastTick,lastAt,rate=0,nil,os.clock(),0
local solarDirection=east
local phase=0
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
   phase=(visualTick%cycle)/cycle
   solarDirection=(east*math.cos(phase*2*math.pi)+up*math.sin(phase*2*math.pi)).Unit
   Lighting.ClockTime=if fit then Clock.hour(fit,phase,orientation) else (phase*24+6)%24
   root:SetAttribute("Daylight",math.max(0,math.sin(phase*2*math.pi)))
   root:SetAttribute("SolarDirection",solarDirection)
   root:SetAttribute("EngineDirectionErrorDegrees",math.deg(math.acos(math.clamp(Lighting:GetSunDirection():Dot(solarDirection),-1,1))))
   root:SetAttribute("Status","Simulation clock");root:SetAttribute("BiologicalTick",tick)
  end
 else root:SetAttribute("Status","Clock held: biology unavailable") end
 local position=camera.CFrame.Position
 sun.Position=position+solarDirection*12000;moon.Position=position-solarDirection*12000
 -- Keep the existing sky texture aligned with the engine atmosphere.
 local submerged=(position-center).Magnitude<contract.habitat.frame.radius
 rays.Enabled=not submerged and solarDirection:Dot((position-center).Unit)>0 and root:GetAttribute("EngineDirectionErrorDegrees")~=nil and root:GetAttribute("EngineDirectionErrorDegrees")<5
 if air then air.Parent=if Lighting:FindFirstChild("CI_LakeScattering") then root else Lighting end
end)
script.Destroying:Connect(function()
 connection:Disconnect();Lighting.ClockTime=savedHour;Lighting.GeographicLatitude=savedLatitude
 if ownedSky then sky:Destroy()else sky.SkyboxOrientation=oldOrientation;sky.SunAngularSize=oldSun;sky.MoonAngularSize=oldMoon;sky.StarCount=oldStars;sky.CelestialBodiesShown=oldBodies end
 if air then air:Destroy()end;rays:Destroy();root:Destroy()
end)
