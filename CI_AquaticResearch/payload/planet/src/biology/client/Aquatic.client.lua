--!nonstrict
-- Bounded biological presentation; the existing research interface owns inspection.
local RS=game:GetService("ReplicatedStorage")
local Space=require(RS.CI_Biology.SimulationSpace)
local Protocol=require(RS.CI_Biology.AquaticProtocol)
local Models=require(RS.CI_Biology.AquaticModels)
local event=RS:WaitForChild("CI_AquaticState")
local root=Instance.new("Folder");root.Name="CI_AquaticCohorts";root.Parent=workspace
root:SetAttribute("Version","aquatic-research-2")
local provider=Instance.new("Folder");provider.Name="CI_AquaticResearchData";provider.Parent=RS
local models={};local packet,received,stamp=nil,0,0
local previous,rates={},{}
local alive=true
local function clear()
 for id,m in models do Models.destroy(m);models[id]=nil end
 packet=nil;previous={};rates={}
 provider:SetAttribute("BiologyConnected",false)
 for _,key in {"AtmosphericCarbon","AtmosphericOxygen","CarbonResidual","NitrogenResidual","PhosphorusResidual"}do provider:SetAttribute(key,nil)end
end
local function draw()
 if not packet or os.clock()-received>5 then if packet then clear()end;return end
 local camera=workspace.CurrentCamera;if not camera then return end
 local c=Space.toSimulation(camera.CFrame.Position);if not c then return end
 local nearby=Protocol.near(packet,{c.x,c.y,c.z},Models.MaximumPatches)
 local wanted={};for _,r in nearby.patches do wanted[r[1]]=r end
 for id,m in models do if not wanted[id]then Models.destroy(m);models[id]=nil end end
 for _,r in nearby.patches do
  local id=r[1];local m=models[id]
  if not m then m=Models.create(r,root);models[id]=m end
  Models.update(m,r,{run=packet.run,revision=packet.revision,stamp=stamp,rates=rates[id]})
  Models.animate(m,os.clock())
 end
 root:SetAttribute("VisiblePatches",#nearby.patches);root:SetAttribute("Tick",packet.revision)
end
local connection=event.OnClientEvent:Connect(function(p)
 if type(p)~="table" then return end
 if p.clear then clear();return end
 if not pcall(Protocol.validate,p,p.run)then return end
 if packet and packet.run==p.run and p.revision<packet.revision then return end
 if packet and packet.run~=p.run then clear()end
 if not packet or packet.revision~=p.revision then
  stamp=workspace:GetServerTimeNow()
  local nextPrevious,nextRates={},{}
  for _,row in p.patches do
   local old=previous[row[1]];local rate={}
   if old and type(p.seconds)=="number" and p.seconds>old.seconds then
    for _,pool in {5,6,7}do rate[pool]=(row[pool]-old.row[pool])*86400/(p.seconds-old.seconds)end
   end
   nextPrevious[row[1]]={row=row,seconds=p.seconds or 0};nextRates[row[1]]=rate
  end
  previous,rates=nextPrevious,nextRates
 end
 packet=p;received=os.clock()
 provider:SetAttribute("BiologyConnected",true);provider:SetAttribute("LastUpdate",stamp)
 provider:SetAttribute("SimulationTick",p.revision)
 provider:SetAttribute("AtmosphericCarbon",p.atmosphere and p.atmosphere[1])
 provider:SetAttribute("AtmosphericOxygen",p.atmosphere and p.atmosphere[2])
 for i,key in {"CarbonResidual","NitrogenResidual","PhosphorusResidual"}do provider:SetAttribute(key,p.residual[i])end
 draw()
end)
task.spawn(function()while alive do task.wait(.5);if alive then draw()end end end)
task.spawn(function()
 while alive do
  task.wait(.1)
  if alive and packet and os.clock()-received<=5 then for _,m in models do Models.animate(m,os.clock())end end
 end
end)
script.Destroying:Connect(function()alive=false;connection:Disconnect();clear();root:Destroy();provider:Destroy()end)
