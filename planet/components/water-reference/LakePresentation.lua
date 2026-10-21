--!nonstrict
-- Viewer-only lighting and ambient particles adapted from CI v5. No biology startup.
local Presentation={}
function Presentation.new(state)
 local lighting=game:GetService('Lighting')
 local center=state:GetAttribute('Center');local radius=state:GetAttribute('Radius')
 local up=state:GetAttribute('Up');local east=state:GetAttribute('East');local north=state:GetAttribute('North')
 local origin=center+up*radius
 local surface=Surface.new(state)
 local root=Instance.new('Folder');root.Name='CI_LakePresentation';root:SetAttribute('VisualOnly',true);root:SetAttribute('BiologyEnabled',false);root.Parent=workspace
 local saved={};for _,key in ipairs({'Brightness','ExposureCompensation','Ambient','OutdoorAmbient','FogColor','FogStart','FogEnd','ShadowSoftness'})do saved[key]=lighting[key]end
 local parked=Instance.new('Folder');parked.Name='SuspendedAtmospheres';parked.Parent=root
 local originals={};for _,a in lighting:GetChildren()do if a:IsA('Atmosphere')then table.insert(originals,a)end end
 local air=originals[1]
 local scatter=Instance.new('Atmosphere');scatter.Name='CI_LakeScattering'
 local grade=Instance.new('ColorCorrectionEffect');grade.Name='CI_LakeDepthAbsorption';grade.Enabled=false;grade.Parent=lighting
 local bloom=Instance.new('BloomEffect');bloom.Name='CI_RestrainedBloom';bloom.Intensity=.025;bloom.Size=14;bloom.Threshold=2;bloom.Enabled=false;bloom.Parent=lighting
 local active=false;local alive=true;local blend,near,depth=0,0,0;local elapsed,accum=0,0
 local function activate(value)
  if active==value then return end;active=value
  if value then
   for _,a in originals do if a.Parent==lighting then a.Parent=parked end end;scatter.Parent=lighting
  else
   scatter.Parent=parked;for _,a in originals do if a.Parent==parked then a.Parent=lighting end end
   for key,value in pairs(saved)do lighting[key]=value end
  end
 end
 local random=Random.new(2391);local particles={}
 local colors={Color3.fromRGB(0,255,150),Color3.fromRGB(100,200,255),Color3.fromRGB(0,200,100)}
 for i=1,85 do
  local luminous=i>60
  local angle=random:NextNumber()*math.pi*2;local r=math.sqrt(random:NextNumber())*48
  local x,z=math.cos(angle)*r,math.sin(angle)*r
  local direction=(up*radius+east*x+north*z).Unit
  local sample=Lake.sample(center+direction*(radius-50))
  if sample then
   local d=if luminous then 45+random:NextNumber()*10 else math.max(8,sample.floorDepth-20-random:NextNumber()*10)
   d=math.min(d,sample.floorDepth-3)
   local part=Instance.new('Part');part.Name=if luminous then 'AmbientBioluminescence' else 'SuspendedSediment'
   part.Shape=Enum.PartType.Ball;part.Size=Vector3.one*(if luminous then .5 else .15)
   part.Color=if luminous then colors[(i-61)%3+1] else Color3.fromRGB(130,120,100)
   part.Material=if luminous then Enum.Material.Neon else Enum.Material.SmoothPlastic
   part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
   part:SetAttribute('VisualOnly',true);part.Position=center+direction*(radius-d);part.Parent=root
   table.insert(particles,{part=part,x=x,z=z,depth=d,phase=random:NextNumber()*math.pi*2,luminous=luminous})
  end
 end
 local layers={{0,Color3.fromRGB(51,128,146),145,-.02},{12,Color3.fromRGB(29,95,126),105,-.04},{30,Color3.fromRGB(15,60,99),70,-.07},{60,Color3.fromRGB(7,30,66),42,-.10}}
 local function update(dt)
  if not alive or dt<=0 or dt~=dt then return end
  dt=math.min(dt,.1);elapsed+=dt;accum+=dt
  local camera=workspace.CurrentCamera;if not camera then return end
  local p=camera.CFrame.Position;local sample=Lake.sample(p)
  local targetDepth=if sample then math.max(0,sample.depth)else 0
  local target=if sample then Waves.smoothstep(sample.depth/.8)*Waves.smoothstep((sample.floorDepth-sample.depth+.25)/.5)else 0
  local targetNear=math.clamp((500-(p-origin).Magnitude)/180,0,1)
  near+=(targetNear-near)*(1-math.exp(-dt/.8))
  blend+=(target-blend)*(1-math.exp(-dt/.45));depth+=(targetDepth-depth)*(1-math.exp(-dt/.45))
  if target==0 and blend<.001 then blend=0 end
  if targetNear==0 and near<.001 then near=0 end
  activate(near>0 or blend>0);grade.Enabled=blend>0;bloom.Enabled=active
  if active then
   -- Existing planet clock remains authoritative; local illumination uses radial up.
   local day=Waves.smoothstep((lighting:GetSunDirection():Dot(up)+.12)/.35)
   local brightness=.18+(2.4-.18)*day
   lighting.Brightness=saved.Brightness+(brightness-saved.Brightness)*near
   lighting.Ambient=saved.Ambient:Lerp(Color3.fromRGB(75,86,106):Lerp(Color3.fromRGB(40,43,48),day),near)
   lighting.OutdoorAmbient=saved.OutdoorAmbient:Lerp(Color3.fromRGB(112,126,148):Lerp(Color3.fromRGB(99,108,120),day),near)
   lighting.ShadowSoftness=saved.ShadowSoftness+(.35-saved.ShadowSoftness)*near
   local lo,hi=layers[1],layers[#layers]
   for i=1,#layers-1 do if depth<=layers[i+1][1]then lo,hi=layers[i],layers[i+1];break end end
   if depth>=60 then lo,hi=layers[4],layers[4]end
   local t=if lo[1]==hi[1]then 0 else Waves.smoothstep((depth-lo[1])/(hi[1]-lo[1]))
   local tint=lo[2]:Lerp(hi[2],t);local visibility=lo[3]+(hi[3]-lo[3])*t
   local daylight=.16+.84*math.sqrt(math.clamp(brightness/2.4,0,1))
   tint=Color3.new(tint.R*daylight,tint.G*daylight,tint.B*daylight)
   local airColor=Color3.fromRGB(172,188,220):Lerp(Color3.fromRGB(205,222,240),day)
   local airDecay=Color3.fromRGB(65,77,103):Lerp(Color3.fromRGB(106,124,146),day)
   local baseColor=if air then air.Color else saved.FogColor
   local baseDecay=if air then air.Decay else saved.FogColor
   local airDensity=(if air then air.Density else .18)+((.28-.10*day)-(if air then air.Density else .18))*near
   scatter.Density=airDensity+(math.clamp(.28+10/visibility,.28,.55)-airDensity)*blend
   scatter.Color=baseColor:Lerp(airColor,near):Lerp(tint,blend)
   scatter.Decay=baseDecay:Lerp(airDecay,near):Lerp(tint,blend)
   scatter.Haze=(if air then air.Haze else .55)*(1-near)+(1.1-.55*day)*near
   scatter.Haze+=(2-scatter.Haze)*blend;scatter.Glare=.08*day*near*(1-blend);scatter.Offset=0
   local r,g,b=Waves.absorption(depth,.013,.005,.0015)
   grade.TintColor=Color3.new(1,1,1):Lerp(Color3.new(math.max(r,.48),math.max(g,.65),math.max(b,.80)),blend)
   grade.Saturation=(lo[4]+(hi[4]-lo[4])*t)*blend;grade.Contrast=.025*blend;grade.Brightness=0
   local exposure=saved.ExposureCompensation+((.2*(1-day))-saved.ExposureCompensation)*near
   local targetExposure=math.max(-.4,exposure-.8*Waves.smoothstep(depth/104)*blend)
   lighting.ExposureCompensation+=(targetExposure-lighting.ExposureCompensation)*(1-math.exp(-dt/.8))
  end
  if accum>=.05 then
   accum=0
   for _,v in ipairs(particles)do
    local d=v.depth+math.sin(elapsed*.12+v.phase)*.6
    local x=v.x+math.sin(elapsed*.09+v.phase)*1.5
    local z=v.z+math.cos(elapsed*.08+v.phase)*1.5
    local position=center+(up*radius+east*x+north*z).Unit*(radius-d)
    v.part.Position=position
    local visibility=math.clamp((130-(position-p).Magnitude)/65,0,1)
    local pulse=if v.luminous then .5+.5*math.sin(elapsed*1.8+v.phase)else 0
    v.part.Transparency=1-visibility*(if v.luminous then .4+.45*pulse else .5)
   end
  end
 end
 local conn=game:GetService('RunService').RenderStepped:Connect(update)
 return {Destroy=function()
  if not alive then return end;alive=false;conn:Disconnect();activate(false)
  grade:Destroy();bloom:Destroy();scatter:Destroy();surface.Destroy();root:Destroy()
 end}
end
return Presentation
