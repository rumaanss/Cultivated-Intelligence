--!nonstrict
-- Observer-dependent spherical sky radiance. Biological irradiance remains in C++.
local Background=require(script.Parent.CelestialBackground)
local M={}
M.properties={"SkyboxRightContent","SkyboxLeftContent","SkyboxUpContent","SkyboxDownContent","SkyboxBackContent","SkyboxFrontContent"}
-- Roblox views Rt toward -X and Lf toward +X; polar image-up is +/-X.
-- A generic cubemap mapping folds the planetary horizon across the wrong edges.
-- Reference: devforum.roblox.com/t/rendering-skyboxes-in-studio/939151
function M.direction(face,u,v)
 local direction
 if face==1 then
  direction=Vector3.new(-1,-v,-u)
 elseif face==2 then
  direction=Vector3.new(1,-v,u)
 elseif face==3 then
  direction=Vector3.new(-v,1,-u)
 elseif face==4 then
  direction=Vector3.new(v,-1,-u)
 elseif face==5 then
  direction=Vector3.new(-u,-v,1)
 else
  direction=Vector3.new(u,-v,-1)
 end
 return direction.Unit
end
-- Dimensionless radius ratios keep the presentation independent of stud scale.
-- This is a bounded single-scattering-inspired visual approximation, not a
-- replacement for the simulation's irradiance or atmospheric chemistry.
M.Version="planet-sky-3-celestial"
M.FaceSize=64
function M.horizonCosine(radius,altitude)
 local ratio=radius/(radius+math.max(0,altitude))
 return -math.sqrt(math.max(0,1-ratio*ratio))
end
local function smooth(a,b,x)
 local t=math.clamp((x-a)/(b-a),0,1)
 return t*t*(3-2*t)
end
function M.radiance(view,up,sun,altitude,radius)
 radius=radius or 4096;altitude=math.max(0,altitude or 0)
 local h=altitude/radius
 local mu=math.clamp(view:Dot(up),-1,1)
 local solar=math.clamp(sun:Dot(up),-1,1)
 local toward=math.clamp(view:Dot(sun),-1,1)
 local limb=M.horizonCosine(radius,altitude)
 local day=smooth(-.12,.16,solar)
 -- Thin spherical shell. Outside it, only rays intersecting the shell glow.
 local r=1+h;local outer=1.025
 local disc=r*r*mu*mu+outer*outer-r*r
 local near,far=0,0
 if disc>0 then
  near=math.max(0,-r*mu-math.sqrt(disc))
  far=math.max(0,-r*mu+math.sqrt(disc))
 end
 local groundDisc=r*r*mu*mu+1-r*r
 if mu<0 and groundDisc>=0 then
  far=math.min(far,math.max(0,-r*mu-math.sqrt(groundDisc)))
 end
 local path=math.max(0,far-near)
 local optical=0
 -- Four midpoint samples of exponential density; no ray marching in C++ ticks.
 for i=1,4 do
  local t=near+path*(i-.5)/4
  local sampleHeight=math.max(0,math.sqrt(r*r+t*t+2*r*mu*t)-1)
  optical+=math.exp(-sampleHeight/.004)*path/4/.004
 end
 local horizon=math.exp(-math.abs(mu-limb)*7)
 local lit=day+(1-day)*.3*math.exp(-math.abs(solar)*20)
 local rayleigh=.75*(1+toward*toward)
 local haze=math.max(0,toward)^24*horizon
 local twilight=math.exp(-((solar+.025)/.09)^2)*math.max(0,toward)^6*horizon
 local function channel(beta,base,warm)
  local scatter=(1-math.exp(-optical*beta))*lit*rayleigh
  local value=base+scatter+(.18*haze*day)+warm*twilight*(1-math.exp(-optical*.2))
  -- Bounded tone curve, then display encoding.
  return math.clamp((1-math.exp(-value*1.5))^(1/2.2),0,1)*255
 end
 local rC=channel(.055,.0008,.65)
 local gC=channel(.12,.0012,.17)
 local bC=channel(.27,.003,0)
 -- Terrain normally occludes this region. Avoid a bright underside when viewed
 -- over a geometric horizon; preserve the atmosphere limb from altitude.
 local below=1-smooth(limb-.025,limb+.015,mu)
 local ground=Color3.fromRGB(8+day*18,10+day*20,15+day*22)
 return Color3.fromRGB(rC,gC,bC):Lerp(ground,below)
end
local palette={Color3.fromRGB(255,70,70),Color3.fromRGB(70,255,255),Color3.fromRGB(70,255,70),Color3.fromRGB(255,70,255),Color3.fromRGB(70,100,255),Color3.fromRGB(255,220,70)}
function M.sample(mode,face,view,up,sun,altitude,radius)
 if mode=="Solid" then return Color3.fromRGB(255,0,255)end
 if mode=="Faces" then return palette[face]end
 if mode=="Horizon" then
  local elevation=view:Dot(up)-M.horizonCosine(radius,altitude)
  if math.abs(elevation)<.035 then return Color3.fromRGB(255,210,30)end
  if view:Dot(up)>.985 then return Color3.fromRGB(255,255,255)end
  return if elevation>0 then Color3.fromRGB(35,100,190)else Color3.fromRGB(20,25,30)
 end
 return M.radiance(view,up,sun,altitude,radius)
end
function M.new(sky,status)
 local Asset=game:GetService("AssetService")
 local size=M.FaceSize;local background;local faces={};local original={};local destroyed=false
 local function attribute(k,v)if status and not destroyed then status:SetAttribute(k,v)end end
 local ok,err=pcall(function()
  background=Background.build(size,M.direction,task.wait)
  for i,key in M.properties do
   original[key]=sky[key]
   local image=Asset:CreateEditableImage({Size=Vector2.new(size,size)})
   assert(image,"Sky image memory unavailable")
   local f={image=image,pixels=buffer.create(size*size*4),directions={}};faces[i]=f
   for y=0,size-1 do for x=0,size-1 do
    table.insert(f.directions,M.direction(i,x*2/(size-1)-1,y*2/(size-1)-1))
   end end
  end
 end)
 local function disposeImages()for _,f in faces do f.image:Destroy()end;table.clear(faces)end
 if not ok then disposeImages();return nil,tostring(err)end
 local front={};local staging={};local face,pixel=1,1
 local batch,last=nil,nil;local enabled=true;local ready=false
 local generation,repairs,maximumMs=0,0,0
 local token=0;local pending=false;local failures=0;local failure=nil
 local nextBakeAt,nextBatchAt,publishedAt=0,0,0
 local function attach()for i,key in M.properties do sky[key]=front[i]end end
 local function restore()for key,value in original do sky[key]=value end end
 local function cancel()
  token+=1;batch=nil;staging={};face=1;pixel=1
 end
 attribute("SkyVersion",M.Version);attribute("SkyGeneration",0)
 attribute("SkyContentSource","Opaque (baked)");attribute("SkyDisplayVerified",false)
 attribute("SkyBakeFailures",0)
 return {
  Update=function(up,sun,now,altitude,radius,mode)
   if destroyed or not enabled then return end
   altitude=math.max(0,altitude or 0);radius=radius or 4096;mode=mode or "Normal"
   local started=os.clock()
   if ready then
    for i,key in M.properties do
     if sky[key]~=front[i] then repairs+=1;sky[key]=front[i]end
    end
   end
   if batch and batch.mode~=mode then cancel()end
   if failure then
    failures+=1;attribute("SkyBakeFailures",failures);attribute("SkyLastBakeError",failure)
    attribute("SkyState",if ready then "Bake failed; previous sky retained" else "Bake failed; original sky retained")
    cancel();nextBatchAt=now+math.min(30,2^math.min(failures,5));failure=nil
   elseif not pending then
    if batch and face>6 then
     -- Only baked Opaque content reaches Sky. Release the previous generation's
     -- references after all six replacements; no unbounded Lua-side cache.
     front=staging;staging={};attach();ready=true;generation+=1
     last=batch;batch=nil;face=1;pixel=1;publishedAt=now
     nextBatchAt=now+1 -- at most one normal generation per second, plus preparation.
     failures=0;attribute("SkyBakeFailures",0);attribute("SkyLastBakeError",nil)
     attribute("SkyGeneration",generation);attribute("SkyState","Published")
     attribute("SkyBatchSeconds",now-last.started)
    elseif not batch then
     local changed=not last or mode~=last.mode or up:Dot(last.up)<.999995
      or sun:Dot(last.sun)<.99985 or math.abs(altitude-last.altitude)>radius*.00025
     if changed and now>=nextBatchAt then
      batch={up=up,sun=sun,altitude=altitude,radius=radius,mode=mode,started=now}
      attribute("SkyState","Preparing")
     end
    else
     local f=faces[face]
     local stop=math.min(size*size,pixel+511)
     while pixel<=stop do
      local c=M.sample(batch.mode,face,f.directions[pixel],batch.up,batch.sun,batch.altitude,batch.radius)
      if batch.mode=="Normal" then
       local d=f.directions[pixel]
       local night=(1-math.clamp((batch.sun:Dot(batch.up)+.12)/.35,0,1))^2
       local above=math.clamp((d:Dot(batch.up)-M.horizonCosine(batch.radius,batch.altitude))/.08,0,1)
       local star=background[face][pixel];local strength=night*above
       c=Color3.new(math.min(1,c.R+star.r*strength),math.min(1,c.G+star.g*strength),math.min(1,c.B+star.b*strength))
      end
      local offset=(pixel-1)*4
      buffer.writeu8(f.pixels,offset,math.floor(c.R*255+.5))
      buffer.writeu8(f.pixels,offset+1,math.floor(c.G*255+.5))
      buffer.writeu8(f.pixels,offset+2,math.floor(c.B*255+.5));buffer.writeu8(f.pixels,offset+3,255)
      pixel+=1
      if pixel%16==1 and os.clock()-started>=.001 then break end
     end
     if pixel>size*size and now>=nextBakeAt then
      nextBakeAt=now+.1
      local jobToken,jobFace=token,face
      f.image:WritePixelsBuffer(Vector2.zero,Vector2.new(size,size),f.pixels)
      pending=true
      attribute("SkyState","Baking face "..face)
      -- Never yield the heartbeat callback. One in-flight bake at most.
      task.defer(function()
       local bakeStart=os.clock()
       local success,result,content=pcall(function()
        return Asset:CreateDataModelContentAsync(Content.fromObject(f.image))
       end)
       pending=false
       if destroyed then disposeImages();return end
       if token~=jobToken then return end -- mode changed while API yielded
       attribute("SkyLastBakeMs",(os.clock()-bakeStart)*1000)
       if not success or result~=Enum.CreateContentResult.Success or content==nil then
        failure=tostring(result);return
       end
       staging[jobFace]=content;face=jobFace+1;pixel=1
      end)
     end
    end
   end
   local ms=(os.clock()-started)*1000;maximumMs=math.max(maximumMs,ms)
   attribute("SkyPublishedAgeSeconds",if ready then now-publishedAt else -1)
   attribute("SkyUpdateMs",ms);attribute("SkyMaxUpdateMs",maximumMs);attribute("SkyContentRepairs",repairs)
  end,
  SetEnabled=function(value)
   if enabled==value then return end;enabled=value
   if enabled and ready then attach()elseif not enabled then cancel();restore()end
  end,
  Destroy=function()
   if destroyed then return end;destroyed=true;cancel();restore();front={}
   -- A yielding bake may still read its source. Its completion owns disposal.
   if not pending then disposeImages()end
  end,
 }
end
return M
