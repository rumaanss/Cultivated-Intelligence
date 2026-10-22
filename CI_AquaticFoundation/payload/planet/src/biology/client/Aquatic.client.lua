--!nonstrict
-- Nearby cohort illustrations. All biomass, death and chemistry remain authoritative in C++.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Input=game:GetService("UserInputService")
local Space=require(RS.CI_Biology.SimulationSpace)
local Protocol=require(RS.CI_Biology.AquaticProtocol)
local Contract=require(RS.CI_Biology.PlanetContract)
local frame=Contract.habitat.frame
local center=Vector3.new(unpack(frame.center))
local east=Vector3.new(unpack(frame.east))
local event=RS:WaitForChild("CI_AquaticState")
local root=Instance.new("Folder");root.Name="CI_AquaticCohorts";root.Parent=workspace
root:SetAttribute("Version","aquatic-foundation-1")
root:SetAttribute("Representation","Magnified biomass cohorts; no individual cell or neural controller")
local models={}
local packet,received,selected=nil,0,nil
local open=false
local gui=Instance.new("ScreenGui");gui.Name="CI_AquaticResearch";gui.ResetOnSpawn=false
gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
local button=Instance.new("TextButton");button.Size=UDim2.fromOffset(285,28);button.Position=UDim2.new(1,-300,.4,0)
button.BackgroundColor3=Color3.fromRGB(12,35,37);button.TextColor3=Color3.fromRGB(181,238,212)
button.Text="Lake chemistry · F8";button.TextSize=14;button.Font=Enum.Font.Gotham;button.Visible=false;button.Parent=gui
local panel=Instance.new("TextLabel");panel.Position=UDim2.new(1,-300,.4,32);panel.Size=UDim2.fromOffset(285,225)
panel.BackgroundColor3=Color3.fromRGB(12,26,30);panel.BackgroundTransparency=.12;panel.TextColor3=Color3.fromRGB(219,236,228)
panel.Font=Enum.Font.Code;panel.TextSize=13;panel.TextXAlignment=Enum.TextXAlignment.Left;panel.TextYAlignment=Enum.TextYAlignment.Top
panel.TextWrapped=true;panel.Visible=false;panel.Parent=gui
local padding=Instance.new("UIPadding");padding.PaddingLeft=UDim.new(0,10);padding.PaddingTop=UDim.new(0,10);padding.Parent=panel
local function toggle()open=not open;panel.Visible=open and packet~=nil end
button.Activated:Connect(toggle)
local terrainOnly=RaycastParams.new();terrainOnly.FilterType=Enum.RaycastFilterType.Include;terrainOnly.FilterDescendantsInstances={workspace.Terrain}
local function pose(position,normal)
 local tangent=east-normal*east:Dot(normal)
 if tangent.Magnitude<.01 then tangent=normal:Cross(Vector3.zAxis)end
 return CFrame.fromMatrix(position,tangent.Unit,normal,tangent.Unit:Cross(normal))
end
local function radial(x,y,z)
 local p=Space.toRobloxXYZ(x,y,z);return pose(p,(p-center).Unit)
end
local function part(parent,name,size,cf,color,shape)
 local p=Instance.new("Part");p.Name=name;p.Shape=shape or Enum.PartType.Ball;p.Size=size;p.CFrame=cf;p.Color=color
 p.Material=Enum.Material.SmoothPlastic;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CastShadow=false
 p.Parent=parent;return p
end
local function create(row)
 local m=Instance.new("Model");m.Name="AquaticPatch_"..row[1];m:SetAttribute("PatchId",row[1]);m:SetAttribute("Controller","Non-neural biochemistry")
 local mat=Instance.new("Model");mat.Name="CyanobacterialMat";mat.Parent=m
 -- Ground every mat lobe against the existing terrain. Never preserve floating dead organs.
 for i=1,5 do
  local angle=i*2.39996;local x=row[2]+math.cos(angle)*2;local y=row[3]+math.sin(angle)*2
  local predicted=Space.toRobloxXYZ(x,y,row[4]);local up=(predicted-center).Unit
  local hit=workspace:Raycast(predicted+up*12,-up*24,terrainOnly)
  local sim=hit and Space.toSimulation(hit.Position)
  if hit and sim and sim.z<107.7 then
   part(mat,"LivingMat",Vector3.new(3,.09,2.2),pose(hit.Position+hit.Normal*.07,hit.Normal),Color3.fromRGB(36+i*4,115+i*8,43+i*3))
  end
 end
 local phyto=Instance.new("Model");phyto.Name="SuspendedCyanobacteria";phyto.Parent=m
 local waterZ=row[4]+(108-row[4])*.72
 local cf=radial(row[2],row[3],waterZ)
 -- Two curved filaments rather than generic opaque organism spheres.
 for strand=1,2 do for i=1,4 do
  part(phyto,"FilamentCell",Vector3.new(.25,.22,.25),cf*CFrame.new((i-2.5)*.23,math.sin(i*.8)*.12,strand*.65),Color3.fromRGB(77,175+strand*15,48))
 end end
 local bacteria=Instance.new("Model");bacteria.Name="DecomposerColonies";bacteria.Parent=m
 for i=1,3 do
  local localFrame=radial(row[2]+1,row[3]+i*.45,row[4]+math.min(1.5,(108-row[4])*.3))
  part(bacteria,"Rod",Vector3.new(.38,.12,.12),localFrame*CFrame.Angles(0,i*.9,0),Color3.fromRGB(159,133,90))
 end
 m.Parent=root
 return m
end
local function clear()
 for id,m in models do m:Destroy();models[id]=nil end
 packet=nil;selected=nil;button.Visible=false;panel.Visible=false
end
local function draw()
 if not packet or os.clock()-received>5 then if packet then clear()end;return end
 local camera=workspace.CurrentCamera;if not camera then return end
 local c=Space.toSimulation(camera.CFrame.Position);if not c then return end
 local nearby=Protocol.near(packet,{c.x,c.y,c.z},12)
 local wanted={};for _,r in nearby.patches do wanted[r[1]]=r end
 -- Release before creating, so teleports cannot temporarily double the model budget.
 for id,m in models do if not wanted[id]then m:Destroy();models[id]=nil end end
 for id,r in wanted do
  local m=models[id];if not m then m=create(r);models[id]=m end
  m:SetAttribute("Phytoplankton_mmolC_m3",r[5]);m:SetAttribute("Mat_mmolC_m2",r[6]);m:SetAttribute("Decomposers_mmolC_m3",r[7])
  m:SetAttribute("Sediment_mmolC_m2",r[8]);m:SetAttribute("BottomOxygen_mmol_m3",r[10]);m:SetAttribute("Tick",packet.revision)
  for _,group in m:GetChildren()do
   local biomass=if group.Name=="CyanobacterialMat" then r[6] elseif group.Name=="SuspendedCyanobacteria" then r[5] else r[7]
   local reference=if group.Name=="CyanobacterialMat" then 40 elseif group.Name=="SuspendedCyanobacteria" then 2 else .8
   local transparency=if biomass<1e-6 then 1 else math.clamp(.7-.55*math.sqrt(biomass/reference),.05,.85)
   for _,p in group:GetChildren()do if p:IsA("BasePart")then p.Transparency=transparency;p.CanQuery=transparency<1 end end
  end
 end
 root:SetAttribute("VisiblePatches",#nearby.patches);root:SetAttribute("Tick",packet.revision)
 local row=wanted[selected] or nearby.patches[1]
 if row then
  selected=row[1]
  panel.Text=string.format("PATCH %d · tick %d\nMagnified cohorts · no neural nets\n\nPHYTO %.2f | BACTERIA %.2f C/m³\nMAT %.2f | SEDIMENT %.2f C/m²\nO₂ surface / bed: %.1f / %.1f\nDIC %.1f | NH₄ %.2f\nNO₃ %.2f | PO₄ %.3f\nPAR upper / lower: %.1f / %.1f\n\nLedger residual C/N/P (mmol):\n%.2g / %.2g / %.2g\nAmounts mmol; PAR µmol/m²/s.\nClick a cohort to inspect.",row[1],packet.revision,row[5],row[7],row[6],row[8],row[9],row[10],row[11],row[12],row[13],row[14],row[15],row[16],unpack(packet.residual,1,3))
 else panel.Text="No aquatic patches within observation range.\nC++ continues simulating the lake."end
 button.Visible=true;panel.Visible=open
end
local eventConnection=event.OnClientEvent:Connect(function(p)
 if type(p)~="table" then return end
 if p.clear then clear();return end
 local ok=pcall(Protocol.validate,p,p.run);if not ok then return end
 if packet and packet.run==p.run and p.revision<packet.revision then return end
 if packet and packet.run~=p.run then clear()end
 packet=p;received=os.clock();draw()
end)
local inputConnection=Input.InputBegan:Connect(function(input,processed)
 if processed then return end
 if input.KeyCode==Enum.KeyCode.F8 then toggle()end
 if input.UserInputType==Enum.UserInputType.MouseButton1 and packet then
  local camera=workspace.CurrentCamera;if not camera then return end
  local mouse=Input:GetMouseLocation();local ray=camera:ScreenPointToRay(mouse.X,mouse.Y)
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={root}
  local hit=workspace:Raycast(ray.Origin,ray.Direction*160,params)
  local target=hit and hit.Instance
  while target and target.Parent~=root do target=target.Parent end
  if target then selected=target:GetAttribute("PatchId");open=true;draw()end
 end
end)
task.spawn(function()while gui.Parent do task.wait(.5);draw()end end)
script.Destroying:Connect(function()eventConnection:Disconnect();inputConnection:Disconnect();clear();root:Destroy();gui:Destroy()end)
