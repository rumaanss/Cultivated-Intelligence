--!nonstrict
-- Bounded observer presentation only. Does not own input, camera, lighting or the player.
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Collection=game:GetService('CollectionService')
local Shared=RS:WaitForChild('CI_Biology')
local Protocol=require(Shared.LiveProtocol);local Space=require(Shared.SimulationSpace)
local Geometry=require(Shared.SharedGeometry);local Interpolation=require(Shared.LiveInterpolation)
local Config=require(Shared.LiveConfig)
local folder=RS:WaitForChild('CI_Live',200);if not folder then warn('[CI Biology] Transport not ready');return end
local fetch=folder:WaitForChild('Fetch')
assert(not workspace:FindFirstChild('CI_PlanetMicrobes'),'Duplicate microbial presentation')
local root=Instance.new('Folder');root.Name='CI_PlanetMicrobes';root.Parent=workspace
local provider=Instance.new('Folder');provider.Name='CI_ResearchData';provider:SetAttribute('BiologyConnected',false);provider.Parent=RS
local colors={Color3.fromRGB(81,184,119),Color3.fromRGB(220,181,82),Color3.fromRGB(211,108,95)}
local species={'Cyanobacteria','Bacterivore','Bodo saltans'}
local capacity={100,150,250} -- Species maximumEnergy values in organism_types.hpp.
local display={};local scene=nil;local run,boot='','';local alive=true;local lastReceived=0
local function clear()for id,d in pairs(display)do d.part:Destroy();display[id]=nil end end
local function accept(response)
 if type(response)~='table' then return end
 if response.error then provider:SetAttribute('BiologyConnected',false);provider:SetAttribute('Error',tostring(response.error));return end
 if not response.manifest and not scene then return end
 if response.manifest then
  local m=Protocol.manifest(response.manifest);scene=m.geometry;Space.configure(m.bounds)
  if run~=response.run or boot~=response.boot then clear()end
  run,boot=response.run,response.boot
  provider:SetAttribute("CycleTicks",m.cycleTicks);provider:SetAttribute("Moonlight",m.moonlight)
 end
 if response.run~=run or response.boot~=boot then return end
 assert(type(response.serverTime)=='number','Missing server timestamp')
 local rows=Protocol.unpack(response.buffer,scene);local seen={}
 for _,row in ipairs(rows)do
  local id=row[1];seen[id]=true;local position=Vector3.new(row[3],row[4],row[5]);local d=display[id]
  if not d then
   local part=Instance.new('Part');part.Name='Microbe_'..id;part.Shape=Enum.PartType.Block;part.Size=Vector3.one*scene.bodyRadius*2
   part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=true;part.CastShadow=false;part.Material=Enum.Material.SmoothPlastic
   part.Color=colors[row[2]+1];part.Position=Space.toRobloxXYZ(position.X,position.Y,position.Z)
   part:SetAttribute('CI_SpeciesId',row[2]);part:SetAttribute('CI_OrganismId',id);part:SetAttribute('CI_BiologyKind','Microbe');part:SetAttribute('CI_Species',species[row[2]+1])
   part:SetAttribute('CI_Lifecycle','Alive')
   part:SetAttribute('CI_MaxEnergy',capacity[row[2]+1]);part:SetAttribute('CI_MaxHealth',100)
   part.Parent=root;Collection:AddTag(part,'CI_Organism')
   d={part=part,track=Interpolation.new(),to=position,posedAt=0,lastRendered=nil};display[id]=d
  end
  d.to=position;d.part:SetAttribute('CI_Energy',row[9])
  if response.state=='Live' then d.part:SetAttribute('CI_BiologyTimestamp',response.sampleTime or response.serverTime)end
  Interpolation.push(d.track,response.sampleTime or response.serverTime,position,response.warps and response.warps[tostring(id)] or 0)
 end
 if response.full then for id,d in pairs(display)do if not seen[id]then d.part:Destroy();display[id]=nil end end end
 local count=0;for id,d in pairs(display)do count+=1;if count>Config.MaximumVisibleOrganisms+64 then d.part:Destroy();display[id]=nil end end
 local row=response.inspected
 if row and display[row[1]] then
  local part=display[row[1]].part;part:SetAttribute('CI_Health',row[18]);part:SetAttribute('CI_AgeTicks',row[10]);part:SetAttribute('CI_Generation',row[12])
 end
 provider:SetAttribute('Error',nil)
 provider:SetAttribute('BiologyConnected',response.state=='Live');provider:SetAttribute('LastUpdate',response.serverTime)
 provider:SetAttribute('SimulationTick',response.tick);provider:SetAttribute('Daylight',response.light and response.light[1]);provider:SetAttribute('TotalMicrobes',response.total)
 lastReceived=os.clock()
end
local renderElapsed=0
local frameTime,frameCount=0,0
local connection=Run.RenderStepped:Connect(function(dt)
 frameTime+=dt;frameCount+=1
 if frameTime>=1 then provider:SetAttribute("ClientFrameMs",frameTime/frameCount*1000);frameTime,frameCount=0,0 end
 renderElapsed+=dt;if renderElapsed<1/30 then return end;renderElapsed=0
 if not scene then return end
 if os.clock()-lastReceived>Config.StaleSeconds then provider:SetAttribute('BiologyConnected',false)end
 local camera=workspace.CurrentCamera
 local now=os.clock();local selected=workspace:GetAttribute('CI_SelectedOrganismId')
 for id,d in pairs(display)do
  local near=id==selected or not camera or (d.part.Position-camera.CFrame.Position).Magnitude<90
  if now-d.posedAt<(if near then 1/30 else 1/10)then continue end
  d.posedAt=now
  local p=Interpolation.sample(d.track,workspace:GetServerTimeNow()-Interpolation.delay(d.track)) or d.to
  if d.lastRendered and p==d.lastRendered then continue end
  if not Geometry.clear(scene,p.X,p.Y,p.Z) or Geometry.blocked(scene,{d.to.X,d.to.Y,d.to.Z},{p.X,p.Y,p.Z},scene.bodyRadius,false)then p=d.to end
  d.part.Position=Space.toRobloxXYZ(p.X,p.Y,p.Z);d.lastRendered=p
 end
end)
script.Destroying:Connect(function()alive=false;connection:Disconnect();clear();root:Destroy();provider:Destroy()end)
task.spawn(function()
 while alive do
  local start=os.clock();local camera=workspace.CurrentCamera;local q=camera and Space.toSimulation(camera.CFrame.Position)
  local selected=workspace:GetAttribute('CI_SelectedOrganismId')
  local ok,err=pcall(function()accept(fetch:InvokeServer(run..':'..boot,type(selected)=='number' and selected or 0,q and Vector3.new(q.x,q.y,q.z)))end)
  if not ok then provider:SetAttribute('BiologyConnected',false);provider:SetAttribute('Error',string.sub(tostring(err),1,180))end
  task.wait(math.max(.01,1/Config.ClientSnapshotHz-(os.clock()-start)))
 end
end)
