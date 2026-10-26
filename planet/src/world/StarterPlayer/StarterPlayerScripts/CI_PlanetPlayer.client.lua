--!nonstrict
-- CI Research Interface 1.0.0; embedded module source follows.
local ResearchUI=(function()
-- nonstrict
-- CI Research Interface 1.0.0. Presentation only; camera and physics remain owned by CI_PlanetPlayer.
local UI = {}; UI.__index = UI
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Run = game:GetService("RunService")
local Tween = game:GetService("TweenService")
local Collection = game:GetService("CollectionService")
local Replicated = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Http = game:GetService("HttpService")
local P = {
 background=Color3.fromRGB(5,23,32), text=Color3.fromRGB(225,237,242),
 muted=Color3.fromRGB(139,171,184), line=Color3.fromRGB(66,102,118),
 accent=Color3.fromRGB(94,230,235), hover=Color3.fromRGB(20,52,64), warning=Color3.fromRGB(234,190,115),
}
local function new(class, props, parent)
 local o=Instance.new(class)
 for k,v in pairs(props or {}) do o[k]=v end
 o.Parent=parent;return o
end
local function round(o,r) new("UICorner",{CornerRadius=UDim.new(0,r or 6)},o) end
local function stroke(o,color,transparency)
 return new("UIStroke",{Color=color or P.line,Transparency=transparency or 0,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},o)
end
local function label(parent,text,x,y,w,h,size,color)
 return new("TextLabel",{Name="Label",Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
 BackgroundTransparency=1,TextColor3=color or P.text,Font=Enum.Font.Code,TextSize=size or 14,
 TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd},parent)
end
local function rule(parent,y,w) new("Frame",{Position=UDim2.fromOffset(18,y),Size=UDim2.fromOffset(w-36,1),BackgroundColor3=P.line,BackgroundTransparency=0.35,BorderSizePixel=0},parent) end
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<1e15 end
local function number(v,fmt) return finite(v) and string.format(fmt or "%.1f",v) or "—" end
local function short(v) return v~=nil and tostring(v) or "—" end
local function line(parent,x1,y1,x2,y2,color,width)
 local dx,dy=x2-x1,y2-y1
 return new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset((x1+x2)/2,(y1+y2)/2),
 Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy),width or 1.4),Rotation=math.deg(math.atan2(dy,dx)),BorderSizePixel=0,BackgroundColor3=color or P.text},parent)
end
local function icon(parent,kind,x,y,color)
 local f=new("Frame",{Name=kind.."Icon",Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(24,24),BackgroundTransparency=1},parent)
 local function l(a,b,c,d)line(f,a,b,c,d,color)end
 local function circle(a,b,s) local q=new("Frame",{Position=UDim2.fromOffset(a,b),Size=UDim2.fromOffset(s,s),BackgroundTransparency=1},f);round(q,99);stroke(q,color);return q end
 if kind=="Observe" then circle(3,3,18);circle(10,10,4)
 elseif kind=="Organisms" then l(12,22,12,12);l(12,14,4,5);l(4,5,4,12);l(4,12,12,16);l(12,14,20,5);l(20,5,20,12);l(20,12,12,16)
 elseif kind=="Environment" or kind=="Diagnostics" then l(1,17,6,17);l(6,17,9,4);l(9,4,12,20);l(12,20,16,10);l(16,10,19,17);l(19,17,23,17)
 elseif kind=="Notebook" then l(5,2,20,2);l(20,2,20,22);l(20,22,5,22);l(5,22,5,2);l(2,6,7,6);l(2,12,7,12);l(2,18,7,18);l(10,8,16,8);l(10,12,16,12)
 elseif kind=="Settings" then circle(6,6,12);circle(10,10,4);for i=0,7 do local a=i*math.pi/4;l(12+8*math.cos(a),12+8*math.sin(a),12+11*math.cos(a),12+11*math.sin(a))end
 elseif kind=="Close" then l(6,6,18,18);l(6,18,18,6)
 elseif kind=="Pin" then l(8,3,16,3);l(8,3,9,10);l(16,3,15,10);l(9,10,6,15);l(15,10,18,15);l(6,15,18,15);l(12,15,12,23)
 elseif kind=="Camera" then l(2,7,22,7);l(2,7,2,21);l(22,7,22,21);l(2,21,22,21);l(7,7,9,3);l(9,3,16,3);l(16,3,18,7);circle(8,10,8)
 elseif kind=="Site" then circle(5,2,14);l(5,12,12,23);l(19,12,12,23);circle(10,7,4)
 elseif kind=="Plus" then l(12,4,12,20);l(4,12,20,12)
 end
 return f
end
function UI:connect(signal,fn)
 local c=signal:Connect(fn);table.insert(self.connections,c);return c
end
function UI:clearList(parent)
 for _,c in ipairs(self.dynamic[parent]or {})do c:Disconnect()end
 self.dynamic[parent]={}
 for _,v in ipairs(parent:GetChildren())do if v:IsA("GuiObject")then v:Destroy()end end
end
function UI:button(parent,text,x,y,w,h,callback,kind)
 local b=new("TextButton",{Name=text~="" and text or kind or "Button",Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
 BackgroundColor3=P.background,BackgroundTransparency=.22,TextColor3=P.text,TextSize=14,Font=Enum.Font.Code,AutoButtonColor=false,BorderSizePixel=0},parent)
 round(b,5);local outline=stroke(b,P.line)
 local function connect(signal,fn)
  if parent==self.noteList or parent==self.organismList then
   self.dynamic[parent]=self.dynamic[parent]or {};local c=signal:Connect(fn);table.insert(self.dynamic[parent],c)
  else self:connect(signal,fn)end
 end
 if kind then icon(b,kind,8,(h-24)/2,P.text) end
 connect(b.MouseEnter,function()b.BackgroundColor3=P.hover;outline.Color=P.accent end)
 connect(b.MouseLeave,function()b.BackgroundColor3=P.background;outline.Color=P.line end)
 if callback then connect(b.Activated,callback) end
 return b
end
function UI:paragraph(parent,text,x,y,w,h)
 local l=label(parent,text,x,y,w,h,14,P.muted);l.TextWrapped=true;l.TextTruncate=Enum.TextTruncate.None;l.TextYAlignment=Enum.TextYAlignment.Top;return l
end
function UI:row(parent,name,y,w)
 local title=label(parent,name,20,y,math.floor(w*.48),24,14,P.muted);title.Name="RowLabel_"..name
 local value=label(parent,"—",math.floor(w*.49),y,math.floor(w*.51)-20,24,14)
 value.TextXAlignment=Enum.TextXAlignment.Right;return value
end
function UI:panel(name,width,height,right)
 local home=right and UDim2.new(1,-width-28,0,192) or UDim2.fromOffset(28,160)
 local g=new("CanvasGroup",{Name=name,Position=home,Size=UDim2.fromOffset(width,height),BackgroundColor3=P.background,
 BackgroundTransparency=.08,BorderSizePixel=0,GroupTransparency=1,Visible=false},self.root)
 round(g,7);stroke(g,Color3.fromRGB(113,146,159))
 label(g,name,18,11,width-88,28,17)
 local b=self:button(g,"",width-42,10,28,28,function()self:showPanel(name,false)end,"Close");b.BackgroundTransparency=1;b:FindFirstChildOfClass("UIStroke").Transparency=1
 rule(g,50,width)
 self.panels[name]={frame=g,home=home,open=false,revision=0,right=right,width=width,height=height}
 return g
end
function UI:showPanel(name,show)
 local p=self.panels[name];if not p then return end
 if show and self.root.Size.X.Offset<950 then
  for other,q in pairs(self.panels)do if other~=name and q.open then self:showPanel(other,false)end end
 end
 if not p.right and show then
  for other,q in pairs(self.panels)do if not q.right and other~=name and q.open then self:showPanel(other,false)end end
 end
 p.revision=p.revision+1;local rev=p.revision;p.open=show
 if p.tween then p.tween:Cancel() end
 if p.completion then p.completion:Disconnect();p.completion=nil end
 local f=p.frame
 local offset=UDim2.fromOffset(p.right and 10 or -10,0)
 if show and not f.Visible then f.Position=p.home+offset;f.GroupTransparency=1 end
 f.Visible=true;f.Active=show
 if self.reducedMotion then
  f.Position=p.home;f.GroupTransparency=show and 0 or 1;f.Visible=show
 else
  p.tween=Tween:Create(f,TweenInfo.new(show and .18 or .12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
   {GroupTransparency=show and 0 or 1,Position=show and p.home or p.home+offset})
  p.completion=p.tween.Completed:Connect(function()
   if not self.destroyed and p.revision==rev then f.Visible=p.open;p.completion:Disconnect();p.completion=nil end
  end)
  p.tween:Play()
 end
 self:refreshNavigation()
end
function UI:refreshNavigation()
 for name,item in pairs(self.nav or {})do
  local selected=(name=="Observe")
  if name=="Observe" then for _,p in pairs(self.panels)do if p.open and not p.right then selected=false end end
  else selected=self.panels[name] and self.panels[name].open end
  item.underline.Visible=selected;item.text.TextColor3=selected and P.accent or P.text
 end
end
function UI:navigate(name)
 if name=="Organisms" then self:refreshOrganisms()end
 if name=="Observe" then for key,p in pairs(self.panels)do if not p.right and p.open then self:showPanel(key,false)end end
 else self:showPanel(name,not self.panels[name].open) end
 self:refreshNavigation()
end
function UI:notify(text)
 self.toastRevision=self.toastRevision+1;local rev=self.toastRevision
 self.toast.Text=text;self.toast.Visible=true
 task.delay(3.5,function()if not self.destroyed and rev==self.toastRevision then self.toast.Visible=false end end)
end
function UI:setActions(actions)self.actions=actions end
function UI:action(name,...)
 local fn=self.actions[name];if fn then return fn(...) end
end
function UI:toggleDiagnostics()self:navigate("Diagnostics")end
function UI:setCursor(value)
 self.cursor=value;self.controls.Text=value and "V  Return to view  |  Click  Inspect  |  B  Record" or "Alt  Free-look  |  V  Cursor  |  B  Record"
end
function UI:setStatus(state,reason)
 self.state=state or "Waiting"
 local active=state=="Active"
 self.worldStatus.Text=active and "WORLD CONNECTED" or ("PLAYER "..string.upper(self.state))
 self.worldStatus.TextColor3=active and P.text or P.warning
 self.statusBox.Visible=not active
 self.statusText.Text=(state=="Blocked" and "PLAYER INITIALIZATION BLOCKED" or "PREPARING PLAYER").."\n"..(reason or "Waiting for the validated player controller…")
 self.retry.Visible=state=="Blocked"
 if not active then self.latest=nil;self:setCursor(false) end
end
function UI:provider()
 local aquatic=Replicated:FindFirstChild("CI_AquaticResearchData")
 local f=if aquatic and aquatic:GetAttribute("BiologyConnected") then aquatic else Replicated:FindFirstChild("CI_ResearchData")
 if not f then return false,"OFFLINE",nil end
 local stamp=f:GetAttribute("LastUpdate")
 if f:GetAttribute("BiologyConnected")~=true then return false,"OFFLINE",f end
 if not finite(stamp) or workspace:GetServerTimeNow()-stamp>5 or stamp>workspace:GetServerTimeNow()+1 then return false,"STALE",f end
 return true,"LIVE",f
end
function UI:organism(obj)
 while obj and obj~=workspace do
  if obj:GetAttribute("CI_OrganismId")~=nil and (obj:IsA("Model") or obj:IsA("BasePart")) then return obj end
  if Collection:HasTag(obj,"CI_Organism") and (obj:IsA("Model") or obj:IsA("BasePart"))then return obj end
  obj=obj.Parent
 end
 return nil
end
function UI:bounds(obj)
 if not obj or not obj:IsDescendantOf(workspace)then return nil end
 if obj:IsA("Model") then
  if not obj:FindFirstChildWhichIsA("BasePart",true)then return nil end
  return obj:GetBoundingBox()
 end
 if obj:IsA("BasePart") then return obj.CFrame,obj.Size end
 return nil
end
function UI:select(obj)
 if self.budgetScroll then self.budgetScroll.CanvasPosition=Vector2.new(0,0)end
 if self.selected==obj then self:showPanel("Organism",true);return end
 workspace:SetAttribute("CI_SelectedColonyRun",obj and obj:GetAttribute("CI_Run") or nil)
 workspace:SetAttribute("CI_SelectedOrganismId",obj and obj:GetAttribute("CI_OrganismId") or nil)
 self.selected=obj;self.occlusionTime=0;self.pinned=false;self:setPinColor();self.history={};self.lastSample=nil
 if obj then self:showPanel("Organism",true);self:buildPreview(obj);self:updateSelection()else self:showPanel("Organism",false);self.marker.Visible=false end
end
function UI:setPinColor()
 local color=self.pinned and P.accent or P.text
 local glyph=self.pin:FindFirstChild("PinIcon")
 if glyph then for _,v in ipairs(glyph:GetDescendants())do
  if v:IsA("Frame")then v.BackgroundColor3=color elseif v:IsA("UIStroke")then v.Color=color end
 end end
end
function UI:buildPreview(obj)
 self.preview.CurrentCamera=nil;self.preview:ClearAllChildren();self.previewMessage.Visible=false
 if #obj:GetDescendants()>512 then self.previewMessage.Text="Preview too complex";self.previewMessage.Visible=true;return end
 if not obj.Archivable then self.previewMessage.Text="Preview unavailable";self.previewMessage.Visible=true;return end
 local ok,clone=pcall(function()
  local species=obj:GetAttribute("CI_SpeciesId")
  if type(species)=="number" and species>=0 and species<=2 then
   local shared=game:GetService("ReplicatedStorage"):FindFirstChild("CI_Biology")
   if shared then
    local factory=require(shared.AgentModelFactory)
    local rig=factory.create(({"Cyanobacteria","Bacterivore","BodoSaltans"})[species+1],self.preview,.25,2)
    factory.pose(rig,CFrame.new(),0,0);return rig.model
   end
  end
  return obj:Clone()
 end)
 if not ok or not clone then self.previewMessage.Text="Preview unavailable";self.previewMessage.Visible=true;return end
 local world=new("WorldModel",{},self.preview)
 for _,v in ipairs(clone:GetDescendants())do
  if v:IsA("LuaSourceContainer")or v:IsA("Sound")or v:IsA("ParticleEmitter")or v:IsA("Trail")or v:IsA("Beam")then v:Destroy()
  elseif v:IsA("BasePart")then v.Anchored=true;v.CanCollide=false;v.LocalTransparencyModifier=0 end
 end
 clone.Parent=world
 local cf,size
 if clone:IsA("Model")then cf,size=clone:GetBoundingBox()else cf,size=clone.CFrame,clone.Size;clone.Anchored=true end
 local cam=new("Camera",{FieldOfView=35},self.preview)
 local radius=math.max(size.Magnitude*.5,.2)
 cam.CFrame=CFrame.lookAt(cf.Position+Vector3.new(.8,.35,1).Unit*radius/math.sin(math.rad(17.5))*1.2,cf.Position)
 self.preview.CurrentCamera=cam
end
function UI:metric(parent,title,y)
 local titleLabel=label(parent,title,20,y,80,24,14)
 local rail=new("Frame",{Position=UDim2.fromOffset(112,y+7),Size=UDim2.fromOffset(170,13),BackgroundColor3=P.hover,BackgroundTransparency=.2,BorderSizePixel=0},parent);round(rail,7);stroke(rail,P.line)
 local fill=new("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=P.accent,BorderSizePixel=0},rail);round(fill,7)
 local value=label(parent,"—",290,y,38,24,13);value.TextXAlignment=Enum.TextXAlignment.Right
 return {fill=fill,value=value,title=titleLabel,rail=rail}
end
function UI:setMetric(m,value,maxValue,live)
 local valid=live and finite(value)and finite(maxValue)and maxValue>0
 m.fill.Size=UDim2.fromScale(valid and math.clamp(value/maxValue,0,1)or 0,1)
 m.value.Text=valid and string.format("%.0f%%",value/maxValue*100)or "—"
end
function UI:updateSelection()
 local obj=self.selected;if not obj then return end
 local cf,size=self:bounds(obj)
 if not cf then
  if obj:GetAttribute("CI_BiologyKind")=="Colony" then
   self.selectionLive=false;self.marker.Visible=false;self.species.Text="Not rendered. See lineage inspector for native status.";return
  end
  self:select(nil);self:notify("Selected organism is no longer available");return
 end
 local now=workspace:GetServerTimeNow();local connected,status=self:provider()
 local stamp=obj:GetAttribute("CI_BiologyTimestamp")
 local live=connected and finite(stamp)and now-stamp<=5 and now-stamp>=-1
 local available=finite(stamp)
 self.selectionLive=live
 local id=short(obj:GetAttribute("CI_OrganismId")or obj.Name)
 local isColony=obj:GetAttribute("CI_BiologyKind")=="Colony"
 local isPopulation=obj:GetAttribute("CI_BiologyKind")=="Population"
 self.organismTitle.Text=(isColony and "Colony " or isPopulation and "Population " or "Organism ")..id
 self.markerLabel.Text=id
 local species=obj:GetAttribute("CI_Species")
 self.species.Text=species and tostring(species)..(obj:GetAttribute("CI_Lifecycle") and " · "..tostring(obj:GetAttribute("CI_Lifecycle"))or "")or "Species unavailable"
 local camera=workspace.CurrentCamera
 self.distanceValue.Text=camera and number((cf.Position-camera.CFrame.Position).Magnitude).." studs"or "—"
 self.boundsValue.Text=number(math.max(size.X,size.Y,size.Z)).." studs"
 local isPlant=obj:GetAttribute("CI_BiologyKind")=="Plant"
 self.health.title.Text="Health";self.health.rail.Visible=true
 self.health.value.Position=UDim2.fromOffset(290,0);self.health.value.Size=UDim2.fromOffset(38,24)
 self.ageTitle.Text="Age";self.trendHigh.Text="100%";self.trendLow.Text="0%"
 self.populationTrend=isPopulation or isColony
 if isPopulation or isColony then
  self.energy.title.Text="Biomass";self.energy.rail.Visible=false
  self.energy.value.Position=UDim2.fromOffset(130,0);self.energy.value.Size=UDim2.fromOffset(198,24)
  local units=obj:GetAttribute("CI_BiomassUnits")or "mmol C"
  self.energy.value.Text=number(obj:GetAttribute("CI_Biomass"),"%.3f").." "..units
  self.health.title.Text="O₂ (mmol/m³)";self.health.rail.Visible=false
  self.health.value.Position=UDim2.fromOffset(180,0);self.health.value.Size=UDim2.fromOffset(148,24)
  self.health.value.Text=number(obj:GetAttribute("CI_Oxygen"),"%.2f")
  self.ageTitle.Text="PAR (µmol/m²/s)";self.ageValue.Text=number(obj:GetAttribute("CI_PAR"),"%.2f")
  self.sourceLabel.Text=live and "C++ population · live · no individual age/health" or "C++ population · stale last-known values"
  self.sourceLabel.TextColor3=live and P.muted or P.warning
  self.trendStatus.Text=(live and "Biomass · " or "STALE · biomass · ")..units
  if live and stamp~=self.lastSample and finite(obj:GetAttribute("CI_Biomass")) then
   table.insert(self.history,{time=stamp,value=obj:GetAttribute("CI_Biomass")});self.lastSample=stamp
  end
  while #self.history>120 or (#self.history>0 and now-self.history[1].time>60)do table.remove(self.history,1)end
  local function v(key)return number(obj:GetAttribute(key),"%.3f")end
  self.plantBudget.Text="C++ biomass population · patch "..short(obj:GetAttribute("CI_PatchId"))..
   "\nNet change: "..v("CI_NetBiomassChange").." "..units.."/day (sampled)"..
   "\nOrganic N / P: "..v("CI_OrganicN").." / "..v("CI_OrganicP")..
   "\nDIC / NH₄: "..v("CI_DIC").." / "..v("CI_NH4")..
   "\nNO₃ / PO₄: "..v("CI_NO3").." / "..v("CI_PO4").." mmol/m³"..
   "\nSediment: "..v("CI_SedimentCarbon").." mmol C/m²"..
   "\nTick "..short(obj:GetAttribute("CI_SimulationTick")).." · non-neural"..
   "\nN/P follow the model's fixed 106:16:1 quota."
  if isColony then
   self.ageTitle.Text="Age (ticks)";self.ageValue.Text=number(obj:GetAttribute("CI_AgeTicks"),"%.0f")
   self.sourceLabel.Text=live and "C++ colony · live · magnified sample" or "C++ colony · stale last-known values"
   self.plantBudget.Text="Genotype "..short(obj:GetAttribute("CI_GenomeId")).." · generation "..short(obj:GetAttribute("CI_Generation")).." · ploidy "..short(obj:GetAttribute("CI_Ploidy"))..
    "\nParent: "..short(obj:GetAttribute("CI_ParentId")).." · patch "..short(obj:GetAttribute("CI_PatchId"))..
    "\nStructure / reserve C: "..v("CI_StructuralCarbon").." / "..v("CI_ReserveCarbon")..
    "\nReserve N / P: "..v("CI_ReserveNitrogen").." / "..v("CI_ReservePhosphorus")..
    "\nDNA / RNA / protein C: "..v("CI_DNA").." / "..v("CI_RNA").." / "..v("CI_Protein")..
    "\nDNA replication: "..number((obj:GetAttribute("CI_Replication")or 0)*100,"%.1f").."%"..
    "\nAssimilated / respired C: "..v("CI_Assimilation").." / "..v("CI_Respiration")..
    "\nAction: "..short(obj:GetAttribute("CI_Behavior")).." · "..short(obj:GetAttribute("CI_Lifecycle"))..
    "\nTravel (studs) / movement C: "..v("CI_DistanceStuds").." / "..v("CI_MovementCarbon")..
    "\nSensing / motor protein activity: "..v("CI_SensingActivity").." / "..v("CI_MotorActivity")..
    "\nSensing / motility allele: "..v("CI_SensingAllele").." / "..v("CI_MotilityAllele")..
    (if obj:GetAttribute("CI_IngestedCarbon")~=nil then "\nConsumed / egested C: "..v("CI_IngestedCarbon").." / "..v("CI_EgestedCarbon").."\nLocal food C: "..v("CI_AccessibleFoodCarbon") else "")..
    (if obj:GetAttribute("CI_TotalSegments")~=nil then "\nAlgal sections: "..short(obj:GetAttribute("CI_VisibleSegments")).." / "..short(obj:GetAttribute("CI_TotalSegments")) else "")..
    "\nColor encodes inherited alleles. Bodies are magnified samples."
  end
  self:drawTrend(now);return
 end
 self.energy.title.Text=if isPlant then "Carbon (C)" else "Energy"
 self.energy.rail.Visible=not isPlant
 self.energy.value.Position=UDim2.fromOffset(if isPlant then 130 else 290,0)
 self.energy.value.Size=UDim2.fromOffset(if isPlant then 198 else 38,24)
 self:setMetric(self.energy,obj:GetAttribute("CI_Energy"),obj:GetAttribute("CI_MaxEnergy"),available)
 if isPlant then self.energy.value.Text=available and finite(obj:GetAttribute("CI_Carbon")) and number(obj:GetAttribute("CI_Carbon"),"%.1f") or "—" end
 self:setMetric(self.health,obj:GetAttribute("CI_Health"),obj:GetAttribute("CI_MaxHealth"),available)
 self.ageValue.Text=available and finite(obj:GetAttribute("CI_AgeTicks")) and number(obj:GetAttribute("CI_AgeTicks"),"%.0f")..(isPlant and " plant steps" or " ticks") or (live and finite(obj:GetAttribute("CI_AgeSeconds")) and number(obj:GetAttribute("CI_AgeSeconds"),"%.0f").." s" or "—")
 self.sourceLabel.Text=live and "Geometry: Roblox  |  Biology: live"or (available and "Biology: stale · last known values" or "Geometry: Roblox  |  Biology: unavailable")
 self.sourceLabel.TextColor3=live and P.muted or P.warning
 self.trendStatus.Text=live and "Energy / capacity · last 60 seconds"or(status=="STALE"and "Biology feed stale · no new samples"or "Waiting for timestamped biology data")
 if live and finite(obj:GetAttribute("CI_Energy"))and finite(obj:GetAttribute("CI_MaxEnergy"))and obj:GetAttribute("CI_MaxEnergy")>0 and stamp~=self.lastSample then
  table.insert(self.history,{time=stamp,value=math.clamp(obj:GetAttribute("CI_Energy")/obj:GetAttribute("CI_MaxEnergy"),0,1)});self.lastSample=stamp
 end
 while #self.history>120 or (#self.history>0 and now-self.history[1].time>60)do table.remove(self.history,1)end
 if isPlant then
  self.trendStatus.Text="Carbon reserve · model units; no defined energy capacity"
  local function value(key)local v=obj:GetAttribute(key);return finite(v)and number(v,"%.3f")or "—" end
  if self.plantBudget then self.plantBudget.Text="Growth: "..tostring(obj:GetAttribute("Result")or "unavailable").."\nAssimilation / respiration: "..value("CI_Assimilation").." / "..value("CI_Respiration").." C per plant step\nMaintenance required: "..value("CI_Maintenance").."\nStructural C: "..value("CI_StructuralCarbon").."\nWater / nutrients: "..value("CI_Water").." / "..value("CI_Nutrients").."\nC required: "..value("CI_CarbonRequired").." · Leaf light: "..value("CI_PhotosyntheticLight").." · Age stress: "..value("CI_AgeStress")end
 elseif self.plantBudget then self.plantBudget.Text="Record observations in your field notebook. Detailed morphology is presentation; biology values come from C++." end
 self:drawTrend(now)
end
function UI:drawTrend(now)
 local h=self.history
 local scale=1
 if self.populationTrend then
  scale=0;for _,sample in h do scale=math.max(scale,sample.value)end
  scale=math.max(scale*1.1,1e-9)
  self.trendHigh.Text=number(scale,"%.2g");self.trendLow.Text="0"
 end
 for i,seg in ipairs(self.trendSegments)do
  local a,b=h[i],h[i+1]
  seg.Visible=a~=nil and b~=nil and b.time-a.time<=5
  if seg.Visible then
   local x1=math.clamp((a.time-(now-60))/60,0,1)*286;local x2=math.clamp((b.time-(now-60))/60,0,1)*286
   local y1=(1-a.value/scale)*86;local y2=(1-b.value/scale)*86;local dx,dy=x2-x1,y2-y1
   seg.Position=UDim2.fromOffset((x1+x2)/2,(y1+y2)/2);seg.Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy),1.5);seg.Rotation=math.deg(math.atan2(dy,dx))
  end
 end
 self.trendEmpty.Visible=#h<2
end
function UI:selectAtPointer()
 if self.state~="Active" or UIS:GetFocusedTextBox()then return end
 local camera=workspace.CurrentCamera;if not camera then return end
 local point=UIS:GetMouseLocation()
 if not self.cursor then point=camera.ViewportSize*.5 end
 local ray=camera:ViewportPointToRay(point.X,point.Y)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances=self.player.Character and {self.player.Character}or {}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*2000,params)
 if hit then
  local obj=self:organism(hit.Instance)
  if obj then self:select(obj)
  elseif not self.pinned then self:select(nil)end
 elseif not self.pinned then self:select(nil)end
end
function UI:updateMarker()
 local camera=workspace.CurrentCamera;local obj=self.selected
 if not camera or not obj or not self.panels.Organism.open then self.marker.Visible=false;return end
 local cf,size=self:bounds(obj);if not cf then self.marker.Visible=false;return end
 local point,onScreen=camera:WorldToViewportPoint(cf.Position)
 if not onScreen or point.Z<=0 then self.marker.Visible=false;return end
 local params=self.markerQuery
 params.FilterDescendantsInstances=self.player.Character and {self.player.Character,obj}or {obj}
 if os.clock()-self.occlusionTime>.12 then
  self.occlusionTime=os.clock();local hit=workspace:Raycast(camera.CFrame.Position,cf.Position-camera.CFrame.Position,params)
  self.occluded=hit~=nil
 end
 if self.occluded then self.marker.Visible=false;return end
 local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
 for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
  local p=camera:WorldToViewportPoint(cf:PointToWorldSpace(Vector3.new(size.X*x,size.Y*y,size.Z*z)*.5))
  if p.Z<=.1 then self.marker.Visible=false;return end
  minX=math.min(minX,p.X);maxX=math.max(maxX,p.X);minY=math.min(minY,p.Y);maxY=math.max(maxY,p.Y)
 end end end
 local w,h=camera.ViewportSize.X,camera.ViewportSize.Y
 minX=math.clamp(minX-5,0,w);maxX=math.clamp(maxX+5,0,w);minY=math.clamp(minY-5,0,h);maxY=math.clamp(maxY+5,0,h)
 if maxX-minX>w*.65 or maxY-minY>h*.65 then self.marker.Visible=false;return end
 self.marker.Position=UDim2.fromOffset(minX,minY);self.marker.Size=UDim2.fromOffset(maxX-minX,maxY-minY);self.marker.Visible=true
 self.markerLabel.Text=short(obj:GetAttribute("CI_OrganismId")or obj.Name).."\n"..number((cf.Position-camera.CFrame.Position).Magnitude).." studs"
 self.markerLabel.Position=UDim2.fromOffset(2,minY>42 and -42 or 8)
end
function UI:addObservation(record)
 local copy=Http:JSONDecode(Http:JSONEncode(record))
 local obj=self.selected
 if obj then
  local cf,size=self:bounds(obj)
  copy.organismId=short(obj:GetAttribute("CI_OrganismId")or obj.Name)
  if cf then copy.organismPosition={cf.Position.X,cf.Position.Y,cf.Position.Z};copy.modelBounds={size.X,size.Y,size.Z}end
  local connected,status=self:provider();copy.biologyState=status
  local stamp=obj:GetAttribute("CI_BiologyTimestamp")
  if connected and finite(stamp)and workspace:GetServerTimeNow()-stamp<=5 and workspace:GetServerTimeNow()-stamp>=-1 then
   copy.biology={source="CI_ResearchData",timestamp=stamp,species=obj:GetAttribute("CI_Species"),
    energy=obj:GetAttribute("CI_Energy"),maxEnergy=obj:GetAttribute("CI_MaxEnergy"),
    health=obj:GetAttribute("CI_Health"),maxHealth=obj:GetAttribute("CI_MaxHealth"),ageSeconds=obj:GetAttribute("CI_AgeSeconds")}
   copy.biology.kind=obj:GetAttribute("CI_BiologyKind")
   if copy.biology.kind=="Population" or copy.biology.kind=="Colony" then copy.biology.source="CI_AquaticResearchData" end
   for _,key in {"CI_Behavior","CI_Lifecycle","CI_DistanceStuds","CI_MovementCarbon","CI_SensingActivity","CI_MotorActivity","CI_SensingAllele","CI_MotilityAllele","CI_IngestedCarbon","CI_EgestedCarbon","CI_AccessibleFoodCarbon","CI_TotalSegments","CI_VisibleSegments","CI_RepresentedCohort","CI_ColonyId","CI_ParentId","CI_GenomeId","CI_ReserveCarbon","CI_ReserveNitrogen","CI_ReservePhosphorus","CI_DNA","CI_RNA","CI_Protein","CI_Replication","CI_Ploidy","CI_Biomass","CI_BiomassUnits","CI_OrganicN","CI_OrganicP","CI_Oxygen","CI_PAR","CI_DIC","CI_NH4","CI_NO3","CI_PO4","CI_SedimentCarbon","CI_NetBiomassChange","CI_PatchId","CI_SimulationTick","CI_Run","CI_Carbon","CI_StructuralCarbon","CI_Water","CI_Nutrients","CI_Assimilation","CI_Respiration","CI_Maintenance","CI_AgeTicks","CI_Generation"}do
    copy.biology[key]=obj:GetAttribute(key)
   end
  else copy.biologyState=connected and "STALE"or status end
 end
 self.observationCount=self.observationCount+1;copy.observationId=self.observationCount
 copy.note=self.noteBox.Text;self.noteBox.Text=""
 table.insert(self.notes,1,copy)
 if #self.notes>100 then table.remove(self.notes)end
 self.notebookChip.Text="Notebook  "..tostring(#self.notes).." records"
 self.notebookData.Value=Http:JSONEncode({schema="ci.research.notebook.v1",dataset=self.config.DatasetId,records=self.notes});self:refreshNotes();self:notify("Observation "..self.observationCount.." recorded · this session")
end
function UI:refreshNotes()
 self:clearList(self.noteList)
 self.noteEmpty.Visible=#self.notes==0
 for i,record in ipairs(self.notes)do
  local b=self:button(self.noteList,"",0,(i-1)*76,374,68,function()
   self.noteDetail.Text="OBSERVATION "..record.observationId.." · RECORDED\n"..string.format("Server time %.2f",record.time or 0).."\n"..(record.organismId and "Organism "..record.organismId or "Terrain / player inspection").."\n"..(record.note~="" and record.note or "No note attached")
   self.noteDetail.Text=self.noteDetail.Text.."\nCamera: "..short(record.cameraMode).." · Contact: "..short(record.contact and record.contact.reason)
   if record.position then self.noteDetail.Text=self.noteDetail.Text..string.format("\nPosition: %.2f, %.2f, %.2f",unpack(record.position))end
   self.noteDetail.Text=self.noteDetail.Text.."\nSource: recorded player telemetry / Roblox geometry"
   self.noteDetail.Visible=true
  end)
  label(b,string.format("#%03d  %s",record.observationId,record.organismId and "Organism "..record.organismId or "Field observation"),12,8,348,22,14)
  label(b,record.note~="" and record.note or ("Contact: "..short(record.contact and record.contact.reason)),12,34,348,20,12,P.muted)
 end
 self.noteList.CanvasSize=UDim2.fromOffset(0,#self.notes*76)
end
function UI:refreshOrganisms()
 local objects={};local seen={}
 for _,obj in ipairs(Collection:GetTagged("CI_Organism"))do
  if obj:IsDescendantOf(workspace)and(obj:IsA("Model")or obj:IsA("BasePart"))and not seen[obj]then table.insert(objects,obj);seen[obj]=true end
 end
 table.sort(objects,function(a,b)return short(a:GetAttribute("CI_OrganismId")or a.Name)<short(b:GetAttribute("CI_OrganismId")or b.Name)end)
 self:clearList(self.organismList)
 self.organismEmpty.Visible=#objects==0
 self.organismCount.Text=tostring(#objects).." nearby life records"
 local query=string.lower(self.search.Text);local n=0
 for _,obj in ipairs(objects)do
  local id=short(obj:GetAttribute("CI_OrganismId")or obj.Name)
  if query==""or string.find(string.lower(id.." "..short(obj:GetAttribute("CI_Species"))),query,1,true)then
   n=n+1;if n>100 then break end
   self:button(self.organismList,(obj:GetAttribute("CI_BiologyKind")=="Colony" and "Colony " or obj:GetAttribute("CI_BiologyKind")=="Population" and "Population " or "Organism ")..id,0,(n-1)*46,322,38,function()self:select(obj)end)
  end
 end
 self.organismList.CanvasSize=UDim2.fromOffset(0,math.min(n,100)*46)
 self.organismLimit.Text=n>100 and "Showing first 100 · refine the ID filter"or(n==0 and #objects>0 and "No matching organism IDs"or "Select an entry to inspect")
end
function UI:updatePerformance()
 local rows=self.performanceRows;if not rows then return end
 local telemetry=game:GetService("ReplicatedStorage"):FindFirstChild("CI_ResearchTelemetry")
 local now=workspace:GetServerTimeNow()
 local function get(key)return telemetry and telemetry:GetAttribute(key)end
 local function fresh(key)
  local t=get(key);return finite(t) and now-t>=-1 and now-t<=3
 end
 local function metric(key,unit,available)
  local value=get(key)
  return available and finite(value) and number(value,"%.1f")..unit or "—"
 end
 local serverFresh=fresh("ServerTimestamp");local relayFresh=fresh("RelayTimestamp") and get("RelayState")=="Connected"
 rows["Server heartbeat"].Text=metric("ServerHeartbeatHz"," Hz",serverFresh)
 rows["Server step"].Text=metric("ServerStepMs"," ms",serverFresh)
 rows["Relay status"].Text=telemetry and (get("RelayState")=="Connected" and not relayFresh and "Stale" or short(get("RelayState"))) or "Not configured"
 rows["Relay work"].Text=metric(finite(get("ExchangeWorkMs")) and "ExchangeWorkMs" or "RelayWorkMs"," ms",relayFresh)
 rows["HTTP round trip"].Text=metric(finite(get("ExchangeRoundTripMs")) and "ExchangeRoundTripMs" or "HttpRoundTripMs"," ms",relayFresh)
 rows["Simulation state"].Text=relayFresh and short(get("SimulationState")) or "Unavailable"
 rows["Simulation tick"].Text=relayFresh and finite(get("SimulationTick")) and string.format("%.0f",get("SimulationTick")) or "—"
 rows["Simulation rate"].Text=metric("SimulationTicksPerSecond"," ticks/s",relayFresh)
 rows["Snapshot age"].Text=metric("SnapshotAgeSeconds"," s",relayFresh)
 rows.Habitat.Text=short(get("HabitatState"))
 rows.Biology.Text=short(get("BiologyState"))
 local provider=game:GetService("ReplicatedStorage"):FindFirstChild("CI_ResearchData")
 local frameMs=provider and provider:GetAttribute("ClientFrameMs")
 rows["Client frame"].Text=finite(frameMs) and number(frameMs,"%.1f").." ms" or "—"
 rows["State apply"].Text=metric("StateApplyMs"," ms",relayFresh)
 if relayFresh and finite(get("HttpP95Ms")) then rows["HTTP round trip"].Text=rows["HTTP round trip"].Text.." · p95 "..number(get("HttpP95Ms"),"%.1f") end
 if relayFresh and finite(get("ApplyP95Ms")) then rows["State apply"].Text=rows["State apply"].Text.." · p95 "..number(get("ApplyP95Ms"),"%.1f") end
 rows["Exchange error"].Text=get("ExchangeError") and "Active · open details" or (get("LastExchangeError") and "Recovered · "..tostring(get("ExchangeErrorCount")or 0).." errors" or "None")
 if self.exchangeDetail then self.exchangeDetail.Text="Latest error (retained after recovery):\n"..tostring(get("LastExchangeError")or "None").."\n\nCount: "..tostring(get("ExchangeErrorCount")or 0).."\nBridge: "..tostring(get("BridgeReason")or "Unknown").."\nInput age (ms): "..tostring(get("CppInputAgeMs")or "Unavailable").."\n\nRecent transitions:\n"..tostring(get("ExchangeHistory")or "[]")end
end
function UI:update(d)
 self:updatePerformance()
 if self.envRows and self.envRows["Atmospheric carbon"] then
  local plants=workspace:FindFirstChild("CI_PlanetPlants")
  local value=plants and plants:GetAttribute("atmosphericCarbon")
  local aquatic=Replicated:FindFirstChild("CI_AquaticResearchData")
  if aquatic and aquatic:GetAttribute("BiologyConnected") then
   local t=aquatic:GetAttribute("LastUpdate")
   local fresh=finite(t) and workspace:GetServerTimeNow()-t<=5
   value=if fresh then aquatic:GetAttribute("AtmosphericCarbon") else nil
   self.envRows["Atmospheric carbon"].Text=finite(value) and number(value,"%.2g").." mmol C" or "Stale / unavailable"
   self.environmentInfo.Text="Lake C/N/P residuals (mmol): "..number(aquatic:GetAttribute("CarbonResidual"),"%.2g").." / "..number(aquatic:GetAttribute("NitrogenResidual"),"%.2g").." / "..number(aquatic:GetAttribute("PhosphorusResidual"),"%.2g").."\nSelect a colony or population for local water chemistry. Carbon reservoir is not atmospheric ppm."
   if aquatic:GetAttribute("ColonyCount") then
    self.environmentInfo.Text..="\nBiology: "..short(aquatic:GetAttribute("Model")).." · visible sample: "..short(aquatic:GetAttribute("VisibleColonies")).."\nColonies: "..number(aquatic:GetAttribute("ColonyCount"),"%.0f").." · births / deaths / mutations: "..number(aquatic:GetAttribute("Births"),"%.0f").." / "..number(aquatic:GetAttribute("Deaths"),"%.0f").." / "..number(aquatic:GetAttribute("Mutations"),"%.0f")
   end
  else
   self.environmentInfo.Text="Carbon is a model pool, not atmospheric ppm. Light follows the shared simulation clock."
   self.envRows["Atmospheric carbon"].Text=finite(value) and number(value,"%.1f").." C units" or "Unavailable"
  end
 end
 self.latest=d
 local lake=game:GetService("ReplicatedStorage"):FindFirstChild("CI_LakeWater")
 if self.envRows then
  self.envRows["Water generation"].Text=lake and short(lake:GetAttribute("Status")) or "Unavailable"
  if d.water then
   self.envRows["Water generation"].Text=string.format("%s · %.1f studs deep",d.locomotionMode or "Water",math.max(0,d.water.depth))
  end
 end
 local rows=self.diagRows
 rows.Altitude.Text=number(d.altitude).." studs";rows.Speed.Text=d.velocity and number(Vector3.new(unpack(d.velocity)).Magnitude).." studs/s"or "—"
 rows.Gravity.Text=number(d.gravityAcceleration,"%.2f").." studs/s²"
 rows.Contact.Text=short(d.contact and d.contact.reason)
 rows["Ground gap"].Text=number(d.contact and d.contact.gap,"%.3f").." studs"
 rows["Up error"].Text=number(d.upErrorDegrees,"%.2f").."°";rows["Facing error"].Text=number(d.headingErrorDegrees,"%.2f").."°"
 rows.Strafe.Text=number(d.strafeSpeed).." studs/s";rows["Gravity forces"].Text=short(d.forceCount)
 rows["Eye obstruction"].Text=d.cameraObstructed and "Blocked"or "Clear"
 rows["Camera mode"].Text=short(d.cameraMode)
 self.diagFoot.Text="PhysicalCapsule · player "..short(d.version)
 self.sensitivityValue.Text=number(d.sensitivity,"%.2f").."° / pixel"
 self.envRows["Radial altitude"].Text=number(d.altitude).." studs"
 self.envRows["Spawn site"].Text=short(d.spawnSite)
 local character=self.player.Character
 if character then
  self.envRows["Bank setback"].Text=number(character:GetAttribute("CI_LakeBankSetback"),"%.1f").." studs"
 end
 self.envRows.Gravity.Text=number(d.gravityAcceleration,"%.2f").." studs/s²"
end
function UI:layout()
 local size=self.gui.AbsoluteSize
 local width,height=size.X,size.Y
 if width<1 or height<1 then return end
 local scale=math.clamp(math.min(width/1672,height/900),.58,1.35)
 self.scale.Scale=scale;self.root.Size=UDim2.fromOffset(width/scale,height/scale)
 local rw,rh=width/scale,height/scale
 self.navFrame.Position=UDim2.fromOffset(28,64)
 local tight=rw<1100
 self.topStatus.Visible=not tight
 self.heading.TextSize=tight and 17 or 20
 for _,glyph in ipairs(self.headingGlyphs or {})do glyph.TextSize=self.heading.TextSize end
 for _,p in pairs(self.panels)do
  local y=math.max(142,math.min(p.right and 192 or 160,rh-p.height-65))
  p.home=p.right and UDim2.new(1,-p.width-28,0,y)or UDim2.fromOffset(28,y)
  if p.tween then p.tween:Cancel()end
  if p.completion then p.completion:Disconnect();p.completion=nil end
  p.revision=p.revision+1;p.frame.Position=p.home;p.frame.Visible=p.open;p.frame.GroupTransparency=p.open and 0 or 1
 end
 self.controls.Visible=rw>1000
end
function UI.new(player,config)
 local self=setmetatable({player=player,config=config,connections={},dynamic={},panels={},actions={},notes={},history={},observationCount=0,
 nav={},toastRevision=0,cursor=false,occlusionTime=0,reducedMotion=false,selected=nil,pinned=false},UI)
 self.gui=new("ScreenGui",{Name="CI_ResearchInterface",ResetOnSpawn=false,DisplayOrder=25,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets},player:WaitForChild("PlayerGui"))
 self.notebookData=new("StringValue",{Name="NotebookJSON",Value="{}"},self.gui)
 self.root=new("Frame",{Name="Research",BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},self.gui)
 self.scale=new("UIScale",{Scale=1},self.root)
 self.heading=label(self.root,"",48,8,500,30,20)
 self.headingGlyphs={}
 for i=1,#"CULTIVATED INTELLIGENCE" do
  local ch=string.sub("CULTIVATED INTELLIGENCE",i,i)
  self.headingGlyphs[i]=label(self.heading,ch,(i-1)*19,0,19,30,20)
 end
 new("Frame",{Position=UDim2.fromOffset(28,9),Size=UDim2.fromOffset(2,46),BackgroundColor3=P.accent,BorderSizePixel=0},self.root)
 label(self.root,"P L A N E T - 0  /  F I E L D  R E S E A R C H",48,37,620,20,12,P.muted)
 self.navFrame=new("Frame",{Name="Navigation",Position=UDim2.fromOffset(28,64),Size=UDim2.fromOffset(600,66),BackgroundTransparency=1},self.root)
 for i,name in ipairs({"Observe","Organisms","Environment","Diagnostics","Notebook","Settings"})do
  local b=new("TextButton",{Name=name,Position=UDim2.fromOffset((i-1)*98,0),Size=UDim2.fromOffset(94,64),Text="",BackgroundTransparency=1,AutoButtonColor=false},self.navFrame)
  icon(b,name,35,4,P.text);local t=label(b,name,0,35,94,22,13);t.TextXAlignment=Enum.TextXAlignment.Center
  local u=new("Frame",{Position=UDim2.fromOffset(10,61),Size=UDim2.fromOffset(74,2),BackgroundColor3=P.accent,BorderSizePixel=0,Visible=name=="Observe"},b)
  self.nav[name]={text=t,underline=u}
  self:connect(b.Activated,function()self:navigate(name)end)
  self:connect(b.MouseEnter,function()t.TextColor3=P.accent end);self:connect(b.MouseLeave,function()self:refreshNavigation()end)
 end
 self.topStatus=new("Frame",{Position=UDim2.new(1,-250,0,8),Size=UDim2.fromOffset(222,85),BackgroundTransparency=1},self.root)
 label(self.topStatus,"PLAYER CAMERA",0,0,222,24,17)
 icon(self.topStatus,"Camera",0,29,P.accent);self.worldStatus=label(self.topStatus,"WORLD CONNECTING",32,29,190,22,12)
 self.bioStatus=label(self.topStatus,"○  BIOLOGY OFFLINE",0,58,222,22,12,P.muted)
 local site=self:button(self.root,"REFERENCE LAKE / SITE 01",28,0,244,38,function()self:navigate("Environment")end)
 site.AnchorPoint=Vector2.new(0,1);site.Position=UDim2.new(0,28,1,-18)
 self.notebookChip=self:button(self.root,"Notebook  0 records",286,0,190,38,function()self:navigate("Notebook")end)
 self.notebookChip.AnchorPoint=Vector2.new(0,1);self.notebookChip.Position=UDim2.new(0,286,1,-18)
 self.controls=label(self.root,"Alt  Free-look  |  V  Cursor  |  B  Record",0,0,500,28,12,P.muted);self.controls.AnchorPoint=Vector2.new(1,1);self.controls.Position=UDim2.new(1,-28,1,-23);self.controls.TextXAlignment=Enum.TextXAlignment.Right
 self.toast=label(self.root,"",0,0,650,32,14,P.text);self.toast.AnchorPoint=Vector2.new(.5,1);self.toast.Position=UDim2.new(.5,0,1,-68);self.toast.TextXAlignment=Enum.TextXAlignment.Center;self.toast.BackgroundColor3=P.background;self.toast.BackgroundTransparency=.08;self.toast.Visible=false;round(self.toast,5)
 self:buildOrganismPanel();self:buildDrawers()
 self.statusBox=new("Frame",{Name="PlayerStatus",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.45),Size=UDim2.fromOffset(560,170),BackgroundColor3=P.background,BackgroundTransparency=.06,BorderSizePixel=0},self.root);round(self.statusBox,7);stroke(self.statusBox,P.line)
 self.statusText=self:paragraph(self.statusBox,"Preparing player…",20,20,520,90)
 self.retry=self:button(self.statusBox,"Retry spawn · F8",20,118,220,34,function()self:action("recover")end);self.retry.Visible=false
 self.markerGui=new("ScreenGui",{Name="CI_ResearchSelection",IgnoreGuiInset=true,ScreenInsets=Enum.ScreenInsets.None,DisplayOrder=24,ResetOnSpawn=false},self.gui.Parent)
 self.marker=new("Frame",{Name="Selection",BackgroundTransparency=1,Visible=false},self.markerGui)
 for _,v in ipairs({{0,0,0,0},{1,0,-14,0},{0,1,0,-1},{1,1,-14,-1}})do new("Frame",{Position=UDim2.new(v[1],v[3],v[2],v[4]),Size=UDim2.fromOffset(14,1),BackgroundColor3=P.accent,BorderSizePixel=0},self.marker)end
 for _,v in ipairs({{0,0,0,0},{1,0,-1,0},{0,1,0,-14},{1,1,-1,-14}})do new("Frame",{Position=UDim2.new(v[1],v[3],v[2],v[4]),Size=UDim2.fromOffset(1,14),BackgroundColor3=P.accent,BorderSizePixel=0},self.marker)end
 self.markerLabel=label(self.marker,"",2,-42,200,40,12,P.accent)
 self.markerQuery=RaycastParams.new();self.markerQuery.FilterType=Enum.RaycastFilterType.Exclude
 self:connect(UIS.InputBegan,function(input,processed)
  if not processed and input.UserInputType==Enum.UserInputType.MouseButton1 then self:selectAtPointer()end
 end)
 self:connect(self.gui:GetPropertyChangedSignal("AbsoluteSize"),function()self:layout()end)
 self:connect(Collection:GetInstanceAddedSignal("CI_Organism"),function()self.organismsDirty=true end)
 self:connect(Collection:GetInstanceRemovedSignal("CI_Organism"),function()self.organismsDirty=true end)
 local elapsed=0
 self:connect(Run.Heartbeat,function(dt)
  elapsed=elapsed+dt;if elapsed<.2 then return end;elapsed=0
  if self.organismsDirty then self.organismsDirty=false;self:refreshOrganisms() end
  local _,state=self:provider();self.bioStatus.Text="○  BIOLOGY "..state;self.bioStatus.TextColor3=state=="LIVE"and P.accent or(state=="STALE"and P.warning or P.muted)
  self:updateSelection();self.envRows["Local clock"].Text=Lighting.TimeOfDay
 end)
 Run:BindToRenderStep("CI.Research.Selection",Enum.RenderPriority.Camera.Value+2,function()self:updateMarker()end)
 self:layout();self:refreshNavigation();self:refreshOrganisms();self:setStatus(player:GetAttribute("CI_PlayerState"),player:GetAttribute("CI_PlayerReason"))
 return self
end
function UI:buildOrganismPanel()
 local g=self:panel("Organism",350,464,true)
 self.organismTitle=label(g,"Organism",18,11,230,28,17)
 -- The generic title is replaced by the selected stable identity.
 for _,c in ipairs(g:GetChildren())do if c:IsA("TextLabel")and c~=self.organismTitle then c.Visible=false end end
 self.pin=self:button(g,"",270,10,28,28,function()self.pinned=not self.pinned;self:setPinColor();self:notify(self.pinned and "Selection pinned"or "Selection unpinned")end,"Pin");self.pin.BackgroundTransparency=1;self.pin:FindFirstChildOfClass("UIStroke").Transparency=1
 self.preview=new("ViewportFrame",{Position=UDim2.fromOffset(18,66),Size=UDim2.fromOffset(124,72),BackgroundColor3=P.hover,BackgroundTransparency=.6,Ambient=Color3.fromRGB(170,190,200),LightColor=Color3.fromRGB(220,240,255)},g);round(self.preview,4);stroke(self.preview,P.line)
 self.previewMessage=label(g,"",22,76,116,50,11,P.muted);self.previewMessage.TextWrapped=true
 self.species=label(g,"Species unavailable",160,75,172,52,14);self.species.TextWrapped=true
 self.tabs={};self.tabButtons={}
 for i,name in ipairs({"Summary","Trends","Notes"})do
  local b=new("TextButton",{Position=UDim2.fromOffset(18+(i-1)*105,152),Size=UDim2.fromOffset(103,34),Text=name,Font=Enum.Font.Code,TextSize=14,TextColor3=P.muted,BackgroundTransparency=1,AutoButtonColor=false},g)
  local underline=new("Frame",{Position=UDim2.new(0,0,1,-1),Size=UDim2.new(1,-12,0,2),BackgroundColor3=P.accent,BorderSizePixel=0,Visible=i==1},b)
  local page=new("Frame",{Position=UDim2.fromOffset(0,194),Size=UDim2.fromOffset(350,204),BackgroundTransparency=1,Visible=i==1},g)
  self.tabs[name]=page;self.tabButtons[name]={button=b,underline=underline}
  self:connect(b.Activated,function()for n,p in pairs(self.tabs)do p.Visible=n==name;self.tabButtons[n].underline.Visible=n==name;self.tabButtons[n].button.TextColor3=n==name and P.accent or P.muted end end)
 end
 self.tabButtons.Summary.button.TextColor3=P.accent
 local summary=self.tabs.Summary
 self.energy=self:metric(summary,"Energy",0);self.health=self:metric(summary,"Health",34);self.ageValue=self:row(summary,"Age",68,350);self.ageTitle=summary:FindFirstChild("RowLabel_Age")
 rule(summary,104,350);self.distanceValue=self:row(summary,"Distance",117,350);self.boundsValue=self:row(summary,"Model bounds",147,350)
 self.sourceLabel=label(g,"Geometry: Roblox | Biology: unavailable",18,389,314,24,11,P.muted)
 self.recordButton=self:button(g,"+  Record observation",18,420,314,32,function()self:action("capture")end)
 local trends=self.tabs.Trends
 self.trendStatus=label(trends,"Waiting for biology data",18,0,314,26,12,P.muted)
 local plot=new("Frame",{Position=UDim2.fromOffset(40,43),Size=UDim2.fromOffset(286,86),BackgroundTransparency=1,ClipsDescendants=true},trends)
 for i=0,2 do line(plot,0,i*43,286,i*43,P.line,1)end
 self.trendHigh=label(trends,"100%",3,30,36,22,10,P.muted);self.trendLow=label(trends,"0%",12,116,25,22,10,P.muted)
 label(trends,"−60 s",40,136,90,20,11,P.muted);label(trends,"now",286,136,40,20,11,P.muted)
 self.trendSegments={};for i=1,119 do local l=line(plot,0,0,1,0,P.accent,1.5);l.Visible=false;self.trendSegments[i]=l end
 self.trendEmpty=label(trends,"No trend samples",62,73,240,24,13,P.muted)
 self:paragraph(trends,"Gaps remain visible when data stops.",18,168,314,32)
 self.budgetScroll=new("ScrollingFrame",{Position=UDim2.fromOffset(18,4),Size=UDim2.fromOffset(314,146),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.fromOffset(0,0),ClipsDescendants=true},self.tabs.Notes)
 self.plantBudget=self:paragraph(self.budgetScroll,"Record the selection with a note in your field notebook.",0,0,304,0)
 self.plantBudget.Size=UDim2.new(1,-10,0,0);self.plantBudget.AutomaticSize=Enum.AutomaticSize.Y
 self:button(self.tabs.Notes,"Open notebook",18,160,314,34,function()self:showPanel("Notebook",true)end)
end
function UI:buildDrawers()
 local d=self:panel("Diagnostics",360,548,false)
 self.diagRows={};self.performanceRows={}
 local physical=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1},d)
 local performance=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false},d)
 self:button(d,"Player",18,55,154,26,function()physical.Visible=true;performance.Visible=false end)
 self:button(d,"Simulation / relay",180,55,162,26,function()physical.Visible=false;performance.Visible=true end)
 for i,name in ipairs({"Altitude","Speed","Gravity","Contact","Ground gap","Up error","Facing error","Strafe","Gravity forces","Eye obstruction","Camera mode"})do self.diagRows[name]=self:row(physical,name,90+(i-1)*31,360)end
 for i,name in ipairs({"Server heartbeat","Server step","Relay status","Relay work","HTTP round trip","Simulation state","Simulation tick","Simulation rate","Snapshot age","Habitat","Biology","Client frame","State apply","Exchange error"})do self.performanceRows[name]=self:row(performance,name,90+(i-1)*24,360)end
 self:button(performance,"Open full exchange error / history",18,454,324,28,function()self:showPanel("Exchange details",true)end)
 local exchange=self:panel("Exchange details",500,460,false)
 local scroll=new("ScrollingFrame",{Position=UDim2.fromOffset(18,58),Size=UDim2.fromOffset(464,380),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.fromOffset(0,0)},exchange)
 self.exchangeDetail=new("TextBox",{Size=UDim2.new(1,-12,0,360),AutomaticSize=Enum.AutomaticSize.Y,Text="No errors recorded",TextEditable=false,ClearTextOnFocus=false,MultiLine=true,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextSize=12,Font=Enum.Font.Code,TextColor3=P.text,BackgroundTransparency=1},scroll)
 rule(d,442,360);self.diagFoot=label(physical,"PhysicalCapsule · player 1.3",20,454,320,24,12,P.muted)
 self.captureButton=self:button(d,"Record diagnostics · F7 / B",18,496,324,34,nil)
 local e=self:panel("Environment",360,500,false);self.envRows={}
 for i,name in ipairs({"Spawn site","Radial altitude","Gravity","Sea radius","Local clock","Water generation","Bank setback","Atmospheric carbon"})do self.envRows[name]=self:row(e,name,66+(i-1)*36,360)end
 self.envRows["Sea radius"].Text=tostring(self.config.SeaRadius).." studs"
 self.envRows["Water generation"].Text="Initializing lake"
 local environmentScroll=new("ScrollingFrame",{Position=UDim2.fromOffset(20,376),Size=UDim2.fromOffset(320,100),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.fromOffset(0,0),ClipsDescendants=true},e)
 self.environmentInfo=self:paragraph(environmentScroll,"Carbon is a model pool, not atmospheric ppm. Light follows the shared simulation clock.",0,0,310,0)
 self.environmentInfo.Size=UDim2.new(1,-10,0,0);self.environmentInfo.AutomaticSize=Enum.AutomaticSize.Y
 local o=self:panel("Organisms",360,500,false)
 self.organismCount=label(o,"0 registered organisms",20,62,320,24,13,P.muted)
 self.search=new("TextBox",{Position=UDim2.fromOffset(18,96),Size=UDim2.fromOffset(324,36),Text="",PlaceholderText="Filter by ID or species",ClearTextOnFocus=false,TextSize=14,Font=Enum.Font.Code,TextColor3=P.text,PlaceholderColor3=P.muted,BackgroundColor3=P.hover,BackgroundTransparency=.4,BorderSizePixel=0},o);round(self.search,5);stroke(self.search,P.line)
 self.organismList=new("ScrollingFrame",{Position=UDim2.fromOffset(18,148),Size=UDim2.fromOffset(324,292),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=P.accent,CanvasSize=UDim2.fromOffset(0,0)},o)
 self.organismEmpty=self:paragraph(o,"No organisms registered in this world.\n\nThe terrain and player controller remain available for field inspection.",24,164,308,150)
 self.organismLimit=label(o,"Select an entry to inspect",20,456,320,24,12,P.muted)
 self:connect(self.search:GetPropertyChangedSignal("Text"),function()self:refreshOrganisms()end)
 local n=self:panel("Notebook",412,598,false)
 label(n,"SESSION RECORDS",20,61,240,24,12,P.muted)
 label(n,"Local session · up to 100 observations",20,85,374,22,11,P.muted)
 self.noteList=new("ScrollingFrame",{Position=UDim2.fromOffset(18,120),Size=UDim2.fromOffset(376,210),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=P.accent,CanvasSize=UDim2.fromOffset(0,0)},n)
 self.noteEmpty=self:paragraph(n,"Your observations appear here.\n\nB records the current player, camera, and selection context.",26,144,350,140)
 local detailScroll=new("ScrollingFrame",{Position=UDim2.fromOffset(20,344),Size=UDim2.fromOffset(374,90),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=P.accent,CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y},n)
 self.noteDetail=self:paragraph(detailScroll,"Select a record to review its note.",0,0,362,0);self.noteDetail.AutomaticSize=Enum.AutomaticSize.Y
 self.noteBox=new("TextBox",{Position=UDim2.fromOffset(18,443),Size=UDim2.fromOffset(376,84),Text="",PlaceholderText="Add a field note before recording…",MultiLine=true,ClearTextOnFocus=false,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextSize=14,Font=Enum.Font.Code,TextColor3=P.text,PlaceholderColor3=P.muted,BackgroundColor3=P.hover,BackgroundTransparency=.4,BorderSizePixel=0},n);round(self.noteBox,5);stroke(self.noteBox,P.line)
 new("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10),PaddingTop=UDim.new(0,8)},self.noteBox)
 self:connect(self.noteBox:GetPropertyChangedSignal("Text"),function()local boundary=utf8.offset(self.noteBox.Text,2001);if boundary then self.noteBox.Text=string.sub(self.noteBox.Text,1,boundary-1)end end)
 self:button(n,"+  Record with note",18,545,230,34,function()self.noteBox:ReleaseFocus();self:action("capture")end)
 self:button(n,"Log records",258,545,136,34,function()
  print("CI_RESEARCH_NOTEBOOK "..Http:JSONEncode({schema="ci.research.notebook.v1",dataset=self.config.DatasetId,records=self.notes}))
  self:notify("Notebook JSON written to Client Output")
 end)
 local s=self:panel("Settings",360,370,false)
 label(s,"Camera sensitivity",20,68,320,24,14)
 self.sensitivityValue=label(s,"0.12° / pixel",80,112,200,32,16);self.sensitivityValue.TextXAlignment=Enum.TextXAlignment.Center
 self:button(s,"−",20,110,44,36,function()self:action("sensitivity",-1)end)
 self:button(s,"+",296,110,44,36,function()self:action("sensitivity",1)end)
 self:paragraph(s,"Uses the validated controller's sensitivity range and existing input handling.",20,160,320,64)
 self.motionButton=self:button(s,"Reduced motion: OFF",20,244,320,36,function()
  self.reducedMotion=not self.reducedMotion;self.motionButton.Text=self.reducedMotion and "Reduced motion: ON"or "Reduced motion: OFF"
 end)
 self:paragraph(s,"V switches between cursor interaction and camera control.",20,302,320,48)
end
function UI:destroy()
 if self.destroyed then return end;self.destroyed=true
 Run:UnbindFromRenderStep("CI.Research.Selection")
 for _,c in ipairs(self.connections)do c:Disconnect()end
 for _,group in pairs(self.dynamic)do for _,c in ipairs(group)do c:Disconnect()end end
 for _,p in pairs(self.panels)do if p.completion then p.completion:Disconnect()end;if p.tween then p.tween:Cancel()end end
 self.markerGui:Destroy();self.gui:Destroy()
end
return UI

end)()
-- nonstrict
local Players=game:GetService("Players");local Run=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local StarterGui=game:GetService("StarterGui")
local player=Players.LocalPlayer
local package=assert(game:GetService("ReplicatedStorage"):WaitForChild("CI_PlanetPlayer",15),"Missing CI_PlanetPlayer")
local Shared=package.Shared;local Client=package.Client
local C=require(Shared.Config);local LookInput=require(Shared.LookInput);local F=require(Shared.PlanetFrame);local Rig=require(Shared.Rig)
local Input=require(Client.InputController);local Movement=require(Client.MovementController)
local Body=require(Client.BodyController);local Camera=require(Client.CameraController);local Inspection=require(Client.Inspection)
local Lake=(function()
-- nonstrict
-- Read-only habitat query shared by swimming, camera presentation and future biology.
local Lake={};local cached=nil
function Lake.sample(position)
 if not cached then
  local state=game:GetService('ReplicatedStorage'):FindFirstChild('CI_LakeWater')
  if not state or state:GetAttribute('Status')~='Ready' then return nil end
  local data=state:FindFirstChild('FloorMap');if not data then return nil end
  cached={state=state,floors=game:GetService('HttpService'):JSONDecode(data.Value),
   center=state:GetAttribute('Center'),radius=state:GetAttribute('Radius'),grid=state:GetAttribute('Grid'),id=state:GetAttribute('RegionId'),
   up=state:GetAttribute('Up'),east=state:GetAttribute('East'),north=state:GetAttribute('North')}
 end
 if cached.state:GetAttribute('Status')~='Ready' then return nil end
 local relative=position-cached.center
 local dot=relative:Dot(cached.up);if dot<cached.radius-200 then return nil end
 local i=math.floor(relative:Dot(cached.east)*cached.radius/dot/cached.grid+.5)
 local j=math.floor(relative:Dot(cached.north)*cached.radius/dot/cached.grid+.5)
 local floor=cached.floors[tostring(i)..','..tostring(j)]
 if not floor or floor>=0 then return nil end
 local depth=cached.radius-relative.Magnitude
 if depth> -floor+4 then return nil end
 return {depth=depth,floorDepth=-floor,id=cached.id,surfaceRadius=cached.radius}
end
return Lake

end)()
local Waves=(function()
-- strict
-- Pure numeric presentation model, independent of C++ and Roblox physics.
local M = {}
local TAU = 2 * math.pi
local waves = {
	{ x = 0.93969262, z = 0.34202014, amplitude = 0.42, length = 32, period = 6.8, phase = 0.2 },
	{ x = -0.42261826, z = 0.90630779, amplitude = 0.23, length = 18, period = 4.9, phase = 1.7 },
	{ x = 0.70710678, z = -0.70710678, amplitude = 0.10, length = 10, period = 3.3, phase = 3.1 },
}
function M.sample(x: number, z: number, seconds: number, amplitudeScale: number, speedScale: number): (number, number, number)
	local height, dx, dz = 0, 0, 0
	for _, wave in waves do
		local k = TAU / wave.length
		local phase = k * (wave.x * x + wave.z * z) - TAU / wave.period * seconds * speedScale + wave.phase
		local amplitude = wave.amplitude * amplitudeScale
		height += amplitude * math.sin(phase)
		local slope = amplitude * k * math.cos(phase)
		dx += slope * wave.x
		dz += slope * wave.z
	end
	return height, dx, dz
end
function M.smoothstep(value: number): number
	local t = math.clamp(value, 0, 1)
	return t * t * (3 - 2 * t)
end
function M.absorption(depth: number, red: number, green: number, blue: number): (number, number, number)
	local d = math.max(depth, 0)
	return math.exp(-red * d), math.exp(-green * d), math.exp(-blue * d)
end
return table.freeze(M)

end)()
local Surface=(function()
-- nonstrict
-- Adaptation of the accepted CI v5 GlassReference renderer to a radial region.
local Surface={}
function Surface.new(state)
 local radius=state:GetAttribute('Radius');local center=state:GetAttribute('Center')
 local up=state:GetAttribute('Up');local east=state:GetAttribute('East');local north=state:GetAttribute('North')
 local floors=game:GetService('HttpService'):JSONDecode(state:WaitForChild('FloorMap').Value)
 local frame=CFrame.fromMatrix(center+up*radius,east,up,-north)
 local root=Instance.new('Folder');root.Name='CI_GlassLake';root:SetAttribute('Renderer','GlassReference');root.Parent=workspace
 local fallback=Instance.new('Folder');fallback.Name='StaticGlassFallback';fallback.Parent=root
 local alive=true;local editable=nil;local meshPart=nil;local vertices={};local connection=nil
 local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
 for key in pairs(floors) do
  local i,j=string.match(key,'(-?%d+),(-?%d+)');i=tonumber(i)*4;j=tonumber(j)*4
  minX=math.min(minX,i);maxX=math.max(maxX,i);minZ=math.min(minZ,j);maxZ=math.max(maxZ,j)
 end
 local function elevation(x,z) return floors[tostring(math.floor(x/4+.5))..','..tostring(math.floor(z/4+.5))] or 24 end
 local function base(x,z,h)return Vector3.new(x,radius,-z).Unit*(radius+(h or 0))-Vector3.yAxis*radius end
 local function decorate(part)
  part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
  part.Material=Enum.Material.Glass;part.Color=Color3.fromRGB(64,132,149)
  part.Transparency=.48;part.Reflectance=.045
 end
 local function faces(step,emit)
  local function clip(a,b,c)
   local polygon={a,b,c};local result={}
   for index,p in ipairs(polygon)do
    local q=polygon[index%3+1];local dp,dq=2-p[3],2-q[3]
    if dp>=0 then table.insert(result,p)end
    if (dp>=0)~=(dq>=0)then
     local t=dp/(dp-dq);table.insert(result,{p[1]+(q[1]-p[1])*t,p[2]+(q[2]-p[2])*t,2})
    end
   end
   for i=2,#result-1 do
    local a,b,c=result[1],result[i],result[i+1]
    local area=(b[1]-a[1])*(c[2]-a[2])-(b[2]-a[2])*(c[1]-a[1])
    if math.abs(area)>1e-6 then emit(a,b,c)end
   end
  end
  for x=math.floor(minX/step)*step-step,math.ceil(maxX/step)*step,step do
   for z=math.floor(minZ/step)*step-step,math.ceil(maxZ/step)*step,step do
    local a={x,z,elevation(x,z)};local b={x+step,z,elevation(x+step,z)}
    local c={x,z+step,elevation(x,z+step)};local d={x+step,z+step,elevation(x+step,z+step)}
    clip(a,b,c);clip(b,d,c)
   end
  end
 end
 local function wedgeTriangle(pa,pb,pc)
  local a,b,c=base(pa[1],pa[2]),base(pb[1],pb[2]),base(pc[1],pc[2])
  local ab,ac,bc=b-a,c-a,c-b
  if ab:Dot(ab)>ac:Dot(ac) and ab:Dot(ab)>bc:Dot(bc)then a,c=c,a
  elseif ac:Dot(ac)>bc:Dot(bc)then a,b=b,a end
  ab,ac,bc=b-a,c-a,c-b
  local cross=ac:Cross(ab);if cross.Magnitude<1e-6 then return end
  local right,back=cross.Unit,bc.Unit;local vertical=back:Cross(right).Unit
  local height=math.abs(ab:Dot(vertical));local normal=if right.Y>=0 then right else -right
  local function wedge(mid,x,z,length)
   if height<.001 or length<.001 then return end
   local part=Instance.new('WedgePart');part.Name='GlassSurfaceFacet'
   part.Size=Vector3.new(.01,height,length);part.CFrame=frame*CFrame.fromMatrix(mid-normal*.005,x,vertical,z)
   decorate(part);part.Parent=fallback
  end
  wedge((a+b)/2,right,back,math.abs(ab:Dot(back)))
  wedge((a+c)/2,-right,-back,math.abs(ac:Dot(back)))
 end
 faces(16,wedgeTriangle)
 root:SetAttribute('SurfaceMode','StaticGlassFallback')
 local function wave(x,z,t,floor)
  -- Same wave spectrum as the accepted old renderer; fade into the irregular bank.
  local h,dx,dz=Waves.sample(x,z,t,1,1)
  local fade=math.clamp(-floor/8,0,1);fade=fade*fade*(3-2*fade)
  return h*fade,dx*fade,dz*fade
 end
 task.spawn(function()
  local pending=nil;local part=nil
  local ok,err=pcall(function()
   pending=assert(game:GetService('AssetService'):CreateEditableMesh(),'EditableMesh unavailable')
   local cache={}
   local function vertex(p)
    local key=string.format('%.5f:%.5f',p[1],p[2]);if cache[key]then return cache[key]end
    local v={x=p[1],z=p[2],floor=p[3]}
    local h,dx,dz=wave(v.x,v.z,0,v.floor)
    v.id=pending:AddVertex(base(v.x,v.z,h))
    v.normal=pending:AddNormal((Vector3.new(v.x,radius,-v.z).Unit+Vector3.new(-dx,0,dz)).Unit)
    cache[key]=v;table.insert(vertices,v);return v
   end
   faces(4,function(pa,pb,pc)
    local a,b,c=vertex(pa),vertex(pb),vertex(pc)
    local face=pending:AddTriangle(a.id,b.id,c.id)
    pending:SetFaceNormals(face,{a.normal,b.normal,c.normal})
   end)
   assert(alive,'Renderer disposed during creation')
   part=game:GetService('AssetService'):CreateMeshPartAsync(Content.fromObject(pending),{CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Automatic})
   assert(alive,'Renderer disposed during creation')
   part.Name='GlassReference';part.CFrame=frame;part.DoubleSided=true;decorate(part)
   -- No SurfaceAppearance: preserve the accepted Glass response.
   part.Parent=root;editable=pending;meshPart=part;fallback:Destroy()
   root:SetAttribute('SurfaceMode','AnimatedGlass');root:SetAttribute('VertexCount',#vertices)
   local elapsed,accumulated=0,0
   local averageDt,slowSeconds,fastSeconds,throttled=1/60,0,0,false
   connection=game:GetService('RunService').Heartbeat:Connect(function(dt)
    if not alive or dt<=0 or dt~=dt then return end
    elapsed+=math.min(dt,.25);accumulated+=dt
    averageDt+=(math.min(dt,.1)-averageDt)*(1-math.exp(-dt/1.5))
    if averageDt>1/43 then slowSeconds+=dt;fastSeconds=0
    elseif averageDt<1/55 then fastSeconds+=dt;slowSeconds=0
    else slowSeconds=0;fastSeconds=0 end
    if slowSeconds>1.5 then throttled=true end
    if fastSeconds>5 then throttled=false end
    local camera=workspace.CurrentCamera;if not camera then return end
    local distance=(camera.CFrame.Position-(center+up*radius)).Magnitude
    if distance>650 then return end
    local hz=if throttled or distance>140 then 15 else 30
    if accumulated<1/hz then return end;accumulated%=1/hz
    for _,v in ipairs(vertices)do
     local h,dx,dz=wave(v.x,v.z,elapsed,v.floor)
     editable:SetPosition(v.id,base(v.x,v.z,h))
     editable:SetNormal(v.normal,(Vector3.new(v.x,radius,-v.z).Unit+Vector3.new(-dx,0,dz)).Unit)
    end
   end)
  end)
  if not ok then
   if part then part:Destroy()end;if pending then pending:Destroy()end
   table.clear(vertices)
   if alive then root:SetAttribute('SurfaceMode','StaticGlassFallback');warn('[CI Water] Animated Glass unavailable; static Glass remains: '..tostring(err))end
  end
 end)
 return {Destroy=function()
  if not alive then return end;alive=false
  if connection then connection:Disconnect()end
  if meshPart then meshPart:Destroy()end;if editable then editable:Destroy()end
  root:Destroy();table.clear(vertices)
 end}
end
return Surface

end)()
local Presentation=(function()
-- nonstrict
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
   for key in pairs(saved)do saved[key]=lighting[key]end
   for _,a in originals do if a.Parent==lighting then a.Parent=parked end end;scatter.Parent=lighting
  else
   scatter.Parent=parked;for _,a in originals do if a.Parent==parked then a.Parent=lighting end end
   for key,value in pairs(saved)do if key~="Brightness" and key~="Ambient" and key~="OutdoorAmbient" and key~="ShadowSoftness" then lighting[key]=value end end
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
  lighting:SetAttribute("CI_UnderwaterBlend",blend)
  activate(blend>0 and lighting:GetAttribute("CI_DisableWaterPresentation")~=true);grade.Enabled=blend>0;bloom.Enabled=active
  if active then
   -- Existing planet clock remains authoritative; local illumination uses radial up.
   local celestial=workspace:FindFirstChild('CI_PlanetCelestial')
   local solar=celestial and celestial:GetAttribute('SolarDirection') or lighting:GetSunDirection()
   local day=Waves.smoothstep((solar:Dot((p-center).Unit)+.12)/.35)
   local brightness=.18+(2.4-.18)*day
   -- WorldLighting owns illumination; this layer owns water scattering/grading.
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
  if not alive then return end;alive=false;conn:Disconnect();activate(false);lighting:SetAttribute("CI_UnderwaterBlend",nil)
  grade:Destroy();bloom:Destroy();scatter:Destroy();surface.Destroy();root:Destroy()
 end}
end
return Presentation

end)()
local research=ResearchUI.new(player,C)
local gui=research.gui
local captureButton=research.captureButton
local captures=Instance.new("Folder");captures.Name="Captures";captures.Parent=gui
local captureCount=0
local savedSensitivity=math.deg(C.MouseRadiansPerPixel)
local function notify(message) research:notify(message) end
local controls=nil;local active=nil;local token=0;local diagnostic=false;local remoteBodies={};local globalConnections={}
local disposed=false
local lakePresentation=nil
task.spawn(function()
 local state=game:GetService('ReplicatedStorage'):WaitForChild('CI_LakeWater',120)
 if not state or disposed then return end
 local deadline=os.clock()+120
 while state:GetAttribute('Status')~='Ready' and state:GetAttribute('Status')~='Failed' and os.clock()<deadline and not disposed do task.wait(.1)end
 if disposed or state:GetAttribute('Status')~='Ready' then return end
 local ok,result=pcall(Presentation.new,state)
 if ok then
  if disposed then result.Destroy()else lakePresentation=result end
 else warn('[CI Water presentation] '..tostring(result))end
end)
local function track(connection) table.insert(globalConnections,connection);return connection end
local function cleanup()
 if not active then return end
 Run:UnbindFromRenderStep("CI.PlanetPlayer.Camera")
 for _,connection in active.connections do connection:Disconnect() end
 if active.input then active.input:destroy() end
 if active.movement then active.movement:stop() end
 if active.camera then active.camera:destroy() end
 if active.body then active.body:destroy() end
 active=nil
end
local function reportFailure(message,id)
 warn("[CI Player client] "..message)
 if active then
  if active.input then active.input.enabled=false end
  if active.movement then active.movement:stop() end
 end
 research:setStatus("Blocked",message)
 package.Request:FireServer("ClientFault",id,string.sub(message,1,500))
end
local function initialize(character)
 token+=1;local mine=token;cleanup()
 local id=character:GetAttribute("CI_Generation")
 local ok,err=xpcall(function()
  assert(id,"Character does not belong to the planet spawn service")
  local deadline=os.clock()+15
  while os.clock()<deadline and character.Parent and token==mine do
   local root=character:FindFirstChild("HumanoidRootPart")
   local collider=character:FindFirstChild("CI_Controller")
   if root and root:FindFirstChild("CI_Gravity") and root:FindFirstChild("CI_Orientation") and root:FindFirstChild("CI_Locomotion")
    and collider and collider:FindFirstChild("LowerSphere") and collider:FindFirstChild("UpperSphere")
    and collider:FindFirstChild("Middle") and character:FindFirstChild("Head")
    and character:FindFirstChild("Left Leg") and character:FindFirstChild("Right Leg") and character:GetAttribute("CI_HeadOffset") then break end
   task.wait(0.05)
  end
  if token~=mine or not character.Parent then return end
  local rig=Rig.measure(character)
  local a={character=character,id=id,rig=rig,
   connections={},sequence=0,poseTime=0,diagnosticTime=0,failed=false}
  active=a
  local input=Input.new();a.input=input
  local body=Body.new(character,rig,C);a.body=body
  local camera=Camera.new(character,rig,body,C);a.camera=camera;camera.look.sensitivity=savedSensitivity
  local movement=Movement.new(character,rig,C);a.movement=movement
  local function guard(callback)
   if a.failed or active~=a then return end
   local success,message=xpcall(callback,debug.traceback)
   if not success then a.failed=true;reportFailure(message,id) end
  end
  Run:BindToRenderStep("CI.PlanetPlayer.Camera",Enum.RenderPriority.Camera.Value+1,function(dt)
   guard(function() camera:step(dt,input) end)
  end)
  table.insert(a.connections,Run.PreSimulation:Connect(function(dt)
   guard(function()
    input.enabled=player:GetAttribute("CI_PlayerState")=="Active" and not rig.root.Anchored and rig.humanoid.Health>0
    if not input.enabled then movement:stop();return end
    local snapshot=movement:step(input:movement(),camera.look,os.clock(),dt)
    local actual=F.tangent(rig.root.CFrame.LookVector,snapshot.up)
    local yaw=F.yaw(actual,F.transport(camera.look.flat,camera.look.up,snapshot.up),snapshot.up)
    body:step(dt,snapshot,yaw,camera.look.pitch)
    if os.clock()-a.poseTime>=1/C.PoseHz then
     a.poseTime=os.clock();a.sequence+=1;package.Pose:FireServer(id,a.sequence,yaw,camera.look.pitch)
    end
   end)
  end))
  table.insert(a.connections,Run.PostSimulation:Connect(function()
   guard(function()
    movement.snapshot.velocity=rig.root.AssemblyLinearVelocity
    if os.clock()-a.diagnosticTime<1/C.DiagnosticHz then return end
    a.diagnosticTime=os.clock()
    local state=player:GetAttribute("CI_PlayerState")
    research:setStatus(state,player:GetAttribute("CI_PlayerReason"))
    research:setCursor(input.cursor)
    if state~="Active" then return end
    local d=Inspection.capture(character,movement,camera,C)
    research:update(d)
   end)
  end))
  -- Streaming is requested outside frame callbacks and always has a timeout.
  if workspace.StreamingEnabled then player:RequestStreamAroundAsync(rig.root.Position,8) end
  local query=RaycastParams.new();query.FilterType=Enum.RaycastFilterType.Include;query.FilterDescendantsInstances={workspace.Terrain}
  local grounded=false;deadline=os.clock()+10
  while os.clock()<deadline and token==mine and character.Parent do
   local up=F.up(rig.root.Position,C.Center)
   local hit=workspace:Raycast(rig.root.Position,-up*(rig.foot+2),query)
   if hit and hit.Material~=Enum.Material.Water then grounded=true;break end
   task.wait(0.1)
  end
  if token~=mine or not character.Parent then return end
  assert(grounded,"Native terrain has not arrived locally at the spawn site")
  package.Ready:FireServer(id)
 end,debug.traceback)
 if not ok and token==mine then reportFailure(err,id);cleanup() end
end
local function recovery()
 local state=player:GetAttribute("CI_PlayerState")
 if state=="Blocked" then package.Request:FireServer("Retry")
 elseif active and Run:IsStudio() then
  Inspection.bookmark(active.character,active.movement,active.camera,C);package.Request:FireServer("Recover")
 end
end
local function capture()
 if not active or not active.movement or not active.camera then notify("Capture unavailable: player is initializing");return end
 local record=Inspection.bookmark(active.character,active.movement,active.camera,C)
 captureCount+=1
 local saved=Instance.new("StringValue");saved.Name=string.format("Snapshot_%04d",captureCount)
 saved.Value=game:GetService("HttpService"):JSONEncode(record);saved.Parent=captures
 if captureCount>20 then
  local oldest=captures:FindFirstChild(string.format("Snapshot_%04d",captureCount-20))
  if oldest then oldest:Destroy() end
 end
 research:addObservation(record)
end
track(captureButton.Activated:Connect(capture))
research:setActions({
 capture=capture,recover=recovery,
 sensitivity=function(direction)
  savedSensitivity=LookInput.sensitivity(savedSensitivity,direction*C.SensitivityStep,C.SensitivityMin,C.SensitivityMax)
  if active and active.camera then active.camera.look.sensitivity=savedSensitivity end
  research.sensitivityValue.Text=string.format("%.2f° / pixel",savedSensitivity)
 end,
})
local reset=Instance.new("BindableEvent")
track(reset.Event:Connect(function() package.Request:FireServer("Reset") end))
task.spawn(function()
 for _=1,20 do
  if disposed then return end
  local success=pcall(function() StarterGui:SetCore("ResetButtonCallback",reset) end)
  if success then return end
  task.wait(0.25)
 end
 warn("[CI Player] Core reset callback unavailable; use the Studio recovery control and inspect CoreGui setup")
end)
track(UIS.InputBegan:Connect(function(input,processed)
 if UIS:GetFocusedTextBox() then return end
 -- Studio can consume function keys. If F7 reaches UIS, allow capture even when processed.
 if input.KeyCode==Enum.KeyCode.F7 then capture();return end
 if processed then return end
 if input.KeyCode==Enum.KeyCode.F6 then research:toggleDiagnostics()
 elseif input.KeyCode==Enum.KeyCode.F8 then recovery()
 elseif active and input.KeyCode==Enum.KeyCode.V then active.input.cursor=not active.input.cursor;active.input:clear();research:setCursor(active.input.cursor)
 elseif input.KeyCode==Enum.KeyCode.B then capture()
 elseif active and active.input:available() and (input.KeyCode==Enum.KeyCode.Up or input.KeyCode==Enum.KeyCode.Down) then
  local change=if input.KeyCode==Enum.KeyCode.Up then C.SensitivityStep else -C.SensitivityStep
  savedSensitivity=LookInput.sensitivity(savedSensitivity,change,C.SensitivityMin,C.SensitivityMax)
  active.camera.look.sensitivity=savedSensitivity
  notify(string.format("Mouse sensitivity: %.2f°/pixel (%.2f–%.2f)",savedSensitivity,C.SensitivityMin,C.SensitivityMax))
 end
end))
track(player:GetAttributeChangedSignal("CI_PlayerState"):Connect(function()
 local state=player:GetAttribute("CI_PlayerState")
 research:setStatus(state,player:GetAttribute("CI_PlayerReason"))
 if state=="Blocked" or state=="Disposing" then token+=1;cleanup() end
end))
track(package.Pose.OnClientEvent:Connect(function(other,id,seq,yaw,pitch)
 if other==player or typeof(other)~="Instance" then return end
 local entry=remoteBodies[other]
 if entry and entry.id==id and seq>entry.sequence then entry.sequence=seq;entry.yaw=yaw;entry.pitch=pitch;entry.time=os.clock() end
end))
-- Remote presentation is reconstructed locally from replicated physics and bounded pose packets.
-- It never applies forces to another player's character.
track(Run.PreSimulation:Connect(function(dt)
 for _,other in Players:GetPlayers() do
  if other==player then continue end
  local character=other.Character;local entry=remoteBodies[other]
  if entry and (entry.character~=character or not character or not character.Parent) then entry.body:destroy();remoteBodies[other]=nil;entry=nil end
  if not entry and character and character:GetAttribute("CI_Generation") and character:FindFirstChild("Right Leg") and character:FindFirstChild("CI_Controller") then
   local success,rig=pcall(Rig.measure,character)
   if success then
    local query=RaycastParams.new();query.FilterType=Enum.RaycastFilterType.Exclude
    query.FilterDescendantsInstances={character};query.RespectCanCollide=true
    entry={character=character,id=character:GetAttribute("CI_Generation"),rig=rig,body=Body.new(character,rig,C),sequence=-1,yaw=0,pitch=0,time=0,query=query}
    remoteBodies[other]=entry
   end
  end
  if entry then
   local root=entry.rig.root;local up=F.up(root.Position,C.Center)
   local hit=workspace:Raycast(root.Position,-up*(entry.rig.foot+0.7),entry.query)
   local stale=os.clock()-entry.time>0.5
   entry.body:step(dt,{up=up,forward=F.tangent(root.CFrame.LookVector,up),velocity=root.AssemblyLinearVelocity,grounded=hit~=nil},if stale then 0 else entry.yaw,if stale then 0 else entry.pitch)
  end
 end
end))
track(Players.PlayerRemoving:Connect(function(other) local entry=remoteBodies[other];if entry then entry.body:destroy();remoteBodies[other]=nil end end))
-- Disable the default input backend once; Scriptable camera owns camera presentation.
local function disableDefaultControls(module: Instance)
 if module.Name~="PlayerModule" or not module:IsA("ModuleScript") then return end
 task.spawn(function()
  local defaultControls=require(module :: ModuleScript):GetControls()
  if disposed then return end
  controls=defaultControls;controls:Disable()
 end)
end
track(script.Parent.ChildAdded:Connect(disableDefaultControls))
local existingModule=script.Parent:FindFirstChild("PlayerModule")
if existingModule then disableDefaultControls(existingModule) end
track(player.CharacterAdded:Connect(function(character) task.spawn(initialize,character) end))
track(player.CharacterRemoving:Connect(function() token+=1;cleanup() end))
if player.Character then task.spawn(initialize,player.Character) end
script.Destroying:Connect(function()
 disposed=true;token+=1;cleanup();for _,connection in globalConnections do connection:Disconnect() end
 pcall(function() StarterGui:SetCore("ResetButtonCallback",true) end);reset:Destroy()
 for _,entry in remoteBodies do entry.body:destroy() end
 if controls then controls:Enable() end
 if lakePresentation then lakePresentation.Destroy()end
 research:destroy()
end)
