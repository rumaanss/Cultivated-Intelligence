local config={DatasetId="test",SeaRadius=4096}
local ui=UI.new(player,config)
ui:setStatus("Active");assert(not ui.statusBox.Visible)
assert(not ui.panels.Diagnostics.open and not ui.panels.Organism.open)
ui:showPanel("Notebook",true);ui:showPanel("Notebook",false);ui:showPanel("Notebook",true);finishTweens()
assert(ui.panels.Notebook.frame.Visible and ui.panels.Notebook.frame.GroupTransparency==0,"Interrupted panel open")
ui:showPanel("Diagnostics",true);finishTweens()
assert(not ui.panels.Notebook.open and ui.panels.Diagnostics.open,"Drawer exclusivity")
ui:showPanel("Diagnostics",false);finishTweens();assert(not ui.panels.Diagnostics.frame.Visible)
ui:setStatus("Blocked","fixture");assert(ui.retry.Visible and ui.statusBox.Visible)
ui:setStatus("Active");assert(not ui.retry.Visible and not ui.statusBox.Visible)
ui:setCursor(true);assert(ui.controls.Text:find("Return"));ui:setCursor(false)
local live,state=ui:provider();assert(not live and state=="OFFLINE")
local provider=Instance.new("Folder");provider.Name="CI_ResearchData";provider.Parent=replicated;provider:SetAttribute("BiologyConnected",true)
live,state=ui:provider();assert(not live and state=="STALE")
provider:SetAttribute("LastUpdate",now);live,state=ui:provider();assert(live and state=="LIVE")
now=106;live,state=ui:provider();assert(not live and state=="STALE")
ui:setMetric(ui.energy,0,100,true);assert(ui.energy.value.Text=="0%")
ui:setMetric(ui.energy,nil,100,true);assert(ui.energy.value.Text=="—"and ui.energy.fill.Size.X.Scale==0)
ui:setMetric(ui.energy,1,0,true);assert(ui.energy.value.Text=="—")
ui:setMetric(ui.energy,50,100,true);assert(ui.energy.fill.Size.X.Scale==.5)
ui.reducedMotion=true;ui:showPanel("Notebook",true);assert(ui.panels.Notebook.frame.GroupTransparency==0)
for i=1,120 do ui.noteBox.Text="Record "..i;ui:addObservation({time=now,contact={reason="supported"}})end
assert(#ui.notes==100 and ui.notes[1].observationId==120 and ui.notes[100].observationId==21,"Bounded notebook")
local before=activeConnections
for i=1,50 do ui:refreshNotes();ui:refreshOrganisms()end
assert(activeConnections==before,"Repeated list rebuild leaks connections")
ui.gui.AbsoluteSize=Vector2.new(1280,720);ui:layout()
for _,p in pairs(ui.panels)do assert(p.home.Y.Offset+p.height<ui.root.Size.Y.Offset,"Panel exceeds vertical area")end
ui:showPanel("Notebook",false);ui:showPanel("Organism",true)

local telemetry=Instance.new("Folder");telemetry.Name="CI_ResearchTelemetry";telemetry.Parent=replicated
telemetry:SetAttribute("ServerTimestamp",now);telemetry:SetAttribute("RelayTimestamp",now)
telemetry:SetAttribute("RelayState","Connected");telemetry:SetAttribute("ServerHeartbeatHz",60)
telemetry:SetAttribute("SimulationTicksPerSecond",0);telemetry:SetAttribute("SimulationTick",123)
ui:updatePerformance();assert(ui.performanceRows["Server heartbeat"].Text=="60.0 Hz")
assert(ui.performanceRows["Simulation rate"].Text=="0.0 ticks/s","Real zero must remain distinguishable from unavailable")
assert(ui.performanceRows["Relay work"].Text=="—","Missing timing must not display zero")
now+=4;ui:updatePerformance();assert(ui.performanceRows["Simulation rate"].Text=="—")
assert(ui.performanceRows["Relay status"].Text=="Stale")

provider:SetAttribute("LastUpdate",now)
local plant=Instance.new("Part");plant.Parent=workspace;plant:SetAttribute("CI_BiologyKind","Plant");plant:SetAttribute("CI_Carbon",12.5);plant:SetAttribute("CI_BiologyTimestamp",now)
local oldBounds=ui.bounds;ui.bounds=function()return {Position=Vector3.zero},Vector3.new(1,1,1)end
ui.selected=plant;ui:updateSelection()
assert(ui.energy.title.Text=="Carbon (C)" and ui.energy.value.Text=="12.5" and not ui.energy.rail.Visible,"Plant reserves must show actual carbon without invented percentage")
plant:SetAttribute("CI_Species","Plant type 1");plant:SetAttribute("CI_Lifecycle","Seed")
now+=10;ui:updateSelection()
assert(ui.species.Text:find("Seed") and ui.energy.value.Text=="12.5" and ui.sourceLabel.Text:find("stale"),"Stale data must retain labeled values")
telemetry:SetAttribute("LastExchangeError","http: full diagnostic error text");telemetry:SetAttribute("ExchangeErrorCount",3)
ui:updatePerformance();assert(ui.exchangeDetail.Text:find("full diagnostic error text"),"Error details must not truncate")
local population=Instance.new("Part");population.Parent=workspace
population:SetAttribute("CI_BiologyKind","Population");population:SetAttribute("CI_OrganismId","aq-1-5")
population:SetAttribute("CI_Species","Cyanobacteria · suspended")
population:SetAttribute("CI_Biomass",2.5);population:SetAttribute("CI_BiomassUnits","mmol C/m³")
population:SetAttribute("CI_Oxygen",220);population:SetAttribute("CI_PAR",160)
population:SetAttribute("CI_PatchId",1);population:SetAttribute("CI_BiologyTimestamp",now)
provider:SetAttribute("LastUpdate",now)
ui.selected=population;ui.history={};ui.lastSample=nil;ui:updateSelection()
assert(ui.organismTitle.Text:find("Population") and ui.energy.value.Text:find("2.500"))
assert(not ui.energy.rail.Visible and not ui.health.rail.Visible and ui.ageTitle.Text:find("PAR"))
assert(ui.health.value.Text=="220.00" and ui.ageValue.Text=="160.00")
assert(#ui.history==1 and ui.history[1].value==2.5,"raw biomass trend, not invented capacity")
assert(ui.plantBudget.Text:find("non%-neural") and ui.plantBudget.Text:find("106:16:1"))
ui:addObservation({time=now});assert(ui.notes[1].biology.CI_Biomass==2.5 and ui.notes[1].biology.source=="CI_AquaticResearchData")
now+=6;ui:updateSelection();assert(ui.sourceLabel.Text:find("stale") and #ui.history==1,"stale population cannot add trend samples")

local colony=Instance.new("Model");colony.Name="SampleColony";colony.Parent=workspace
local body=Instance.new("Part");body.Parent=colony
colony:SetAttribute("CI_OrganismId","aq-101");colony:SetAttribute("CI_BiologyKind","Colony")
colony:SetAttribute("CI_BiologyTimestamp",now);colony:SetAttribute("CI_GenomeId",17);colony:SetAttribute("CI_Generation",4)
colony:SetAttribute("CI_ParentId",90);colony:SetAttribute("CI_Biomass",3);colony:SetAttribute("CI_DNA",.02)
provider:SetAttribute("LastUpdate",now)
ui.selected=colony;ui.history={};ui.lastSample=nil;ui:updateSelection()
assert(ui.organismTitle.Text:find("Colony") and ui.plantBudget.Text:find("Genotype 17"))
assert(ui.plantBudget.Text:find("DNA / RNA / protein") and not ui.plantBudget.Text:find("106:16:1"))
ui:addObservation({time=now});assert(ui.notes[1].biology.CI_GenomeId==17 and ui.notes[1].biology.CI_ParentId==90)
colony:Destroy();ui.selected=nil

population:Destroy()
ui.selected=nil;ui.bounds=oldBounds;plant:Destroy()
ui:destroy();assert(activeConnections==0,"Cleanup must disconnect all UI connections")
for _,fn in ipairs(delays)do fn()end
print("PASS UI behavioral checks")
