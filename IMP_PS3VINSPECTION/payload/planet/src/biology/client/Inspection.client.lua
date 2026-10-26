--!nonstrict
-- Durable administrative inspector. Identity outlives any rendered rig.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Collection=game:GetService("CollectionService")
local Space=require(RS:WaitForChild("CI_Biology").SimulationSpace)
local State=require(RS.CI_Biology.InspectionState)
local Stage3=require(RS.CI_Biology.Stage3Models)
local Microbes=require(RS.CI_Biology.AquaticModels)
local deliveredRun,deliveredPatches,deliveredSamples="",{},{}
local aquatic=RS:WaitForChild("CI_AquaticState",180)
if aquatic then aquatic.OnClientEvent:Connect(function(p)
 deliveredRun=p.run or "";deliveredPatches={};deliveredSamples={}
 for _,v in p.patches or {} do deliveredPatches[v[1]]=true end
 for _,v in p.colonies or {} do deliveredSamples[v[3]]=true end
end)end
local event=RS:WaitForChild("CI_Inspection",180);if not event then return end
local status=RS:WaitForChild("CI_InspectionStatus")
local gui=Instance.new("ScreenGui");gui.Name="CI_LineageInspection";gui.ResetOnSpawn=false;gui.DisplayOrder=11;gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
local panel=Instance.new("Frame");panel.Name="Lineage";panel.Size=UDim2.fromOffset(350,410);panel.Position=UDim2.new(0,20,1,-430);panel.BackgroundColor3=Color3.fromRGB(15,25,30);panel.BackgroundTransparency=.08;panel.Visible=false;panel.Parent=gui
local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,8);corner.Parent=panel
local function label(text,y,height)
 local t=Instance.new("TextLabel");t.BackgroundTransparency=1;t.Size=UDim2.new(1,-24,0,height);t.Position=UDim2.fromOffset(12,y);t.TextXAlignment=Enum.TextXAlignment.Left;t.TextYAlignment=Enum.TextYAlignment.Top;t.Font=Enum.Font.Gotham;t.TextSize=12;t.TextColor3=Color3.fromRGB(211,231,228);t.TextWrapped=true;t.Text=text;t.Parent=panel;return t
end
local title=label("LINEAGE INSPECTION",12,24)
local body=label("Waiting for native confirmation",40,250)
local page=label("",291,38)
local buttons={}
local function button(text,x,y,width,fn)
 local b=Instance.new("TextButton");b.Size=UDim2.fromOffset(width,26);b.Position=UDim2.fromOffset(x,y);b.BackgroundColor3=Color3.fromRGB(35,61,65);b.TextColor3=Color3.fromRGB(220,244,234);b.Font=Enum.Font.Gotham;b.TextSize=11;b.Text=text;b.Parent=panel;b.Activated:Connect(fn);return b
end
local selected,selectedRun,cursor=0,"",0
local latest,lastContact,lastSend=nil,0,0
local chosenChild=1
local function select(id,run)
 selected,selectedRun,cursor=id,run,0;latest=nil;lastContact=0;chosenChild=1;panel.Visible=id>0
 workspace:SetAttribute("CI_SelectedLineageId",id);workspace:SetAttribute("CI_SelectedLineageRun",run)
end
button("Close",282,8,56,function()select(0,"")end)
button("Parent",12,334,65,function()if latest and latest.individual.parent and latest.individual.parent>0 then select(latest.individual.parent,selectedRun)end end)
button("Follow child",84,334,96,function()if latest and latest.children[chosenChild] then select(latest.children[chosenChild].id,selectedRun)end end)
button("Next child",187,334,80,function()if latest and #latest.children>0 then chosenChild=chosenChild%#latest.children+1 end end)
button("More",274,334,64,function()if latest and latest.nextCursor then cursor=latest.nextCursor;chosenChild=1;latest=nil end end)
local input=Instance.new("TextBox");input.Size=UDim2.fromOffset(240,24);input.Position=UDim2.fromOffset(12,368);input.PlaceholderText="Native cohort ID (including dead)";input.Text="";input.TextSize=11;input.Font=Enum.Font.Gotham;input.Parent=panel
button("Inspect",260,368,78,function()local id=tonumber(input.Text);if id and id%1==0 and id>0 and id<=2000000 then select(id,status:GetAttribute("Run") or "")end end)
-- Entry also works when no rendered cohorts exist: press L to open the ID query.
game:GetService("UserInputService").InputBegan:Connect(function(key,processed)
 if not processed and key.KeyCode==Enum.KeyCode.L then panel.Visible=not panel.Visible end
end)
workspace:GetAttributeChangedSignal("CI_SelectedOrganismId"):Connect(function()
 local id=tostring(workspace:GetAttribute("CI_SelectedOrganismId") or ""):match("^aq%-(%d+)$")
 if id then select(tonumber(id),workspace:GetAttribute("CI_SelectedColonyRun") or status:GetAttribute("Run") or "")end
end)
event.OnClientEvent:Connect(function(q)
 if q.reset then if selectedRun~="" and selectedRun~=q.run then body.Text="Run changed. Historical selection retained. Reconnect to the original runtime to query it."end;return end
 if q.run~=selectedRun or not q.individual or q.individual.id~=selected then return end
 latest=q;lastContact=os.clock()
end)
local function displayState()
 for _,obj in Collection:GetTagged("CI_Organism")do
  if obj:GetAttribute("CI_ColonyIdentity")==selectedRun..":"..selected then
   local attachment=obj:GetAttribute("CI_AttachmentStatus")
   if attachment=="Waiting for submerged terrain"then return "missing terrain",obj end
   return "rendered",obj
  end
 end
 if latest and latest.individual.position and workspace.CurrentCamera then
  local p=latest.individual.position;local v=Space.toRobloxXYZ(p[1],p[2],p[3])
  if (workspace.CurrentCamera.CFrame.Position-v).Magnitude>160 then return "outside observer interest"end
 end
 local renderer=latest and latest.individual.guild and (latest.individual.guild>=3 and Stage3 or Microbes)
 local omitted=renderer and renderer.displayRun==selectedRun and renderer.displayStatus and renderer.displayStatus[selected]=="budget omitted"
 return State.display(false,false,omitted==true,deliveredRun==selectedRun and latest~=nil and deliveredPatches[latest.individual.patch]==true,deliveredRun==selectedRun and deliveredSamples[selected]==true)
end
task.spawn(function()
 while true do
  if selected>0 and panel.Visible then
   if os.clock()-lastSend>=1 then event:FireServer({id=selected,run=selectedRun,cursor=cursor});lastSend=os.clock()end
   title.Text="COHORT "..selected.." · LINEAGE"
   if status:GetAttribute("Run")~=selectedRun then body.Text="Run changed. Selection belongs to a different saved world."
   elseif latest then
    local i=latest.individual;local display,rig=displayState()
    local age=os.clock()-lastContact;local connection=State.connection(selectedRun,status:GetAttribute("Run") or "",age,age+(latest.snapshotAgeSeconds or 0))
    local text="Biological: "..State.biological(i.biological).." · Connection: "..connection.."\nDisplay: "..display.."\nConfirmed at tick "..latest.tick.." · "..string.format("%.1fs",age).." ago\n"
    text..="Parent "..tostring(i.parent or "—").." · Generation "..tostring(i.generation or "—").."\nBorn "..tostring(i.born or "—")..(i.died and i.died>0 and " · Died "..i.died or "").."\n"
    if i.materialCNP then
     text..=string.format("C/N/P: %.3f / %.3f / %.3f mmol\n",i.materialCNP[1],i.materialCNP[2],i.materialCNP[3])
     text..=string.format("Cohort equivalents: %.3f (not cell size)\n",i.cohortCount)
    end
    if i.par then text..=string.format("Biological PAR: %.3f umol/m²/s · %s\n",i.par,i.parStatus)end
    if i.position then text..=string.format("Native pose: %.2f, %.2f, %.2f studs\n",table.unpack(i.position))end
    local sky=workspace:FindFirstChild("CI_PlanetCelestial")
    local errorDegrees=sky and sky:GetAttribute("EngineDirectionErrorDegrees")
    if errorDegrees then text..=string.format("Rendered sun direction error: %.2f°\n",errorDegrees)end
    text..="Sensing: "..latest.mode.."\n"..latest.light.status
    if latest.probe then text..="\n16-ray scene probe stored in C++ (diagnostic)"end
    if rig and rig:GetAttribute("CI_GroundOffsetStuds")then text..=string.format("\nVisual grounding correction: %.3f studs",rig:GetAttribute("CI_GroundOffsetStuds"))end
    body.Text=text
    local child=latest.children[chosenChild];page.Text="Children: "..latest.childCount..(child and " · Selected "..child.id.." ("..child.biological..")" or "").."\nFollowing requires an explicit click."
   else body.Text="Waiting for native confirmation. No death is inferred from a missing model."end
  end
  task.wait(.25)
 end
end)
