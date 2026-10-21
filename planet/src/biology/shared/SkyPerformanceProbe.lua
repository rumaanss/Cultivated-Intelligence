--!nonstrict
-- Explicitly invoked client diagnostic. No automatic polling or network calls.
local M={}
local phases={"normal","skyFrozen","modelsFrozen","bothFrozen","bothFrozen","modelsFrozen","skyFrozen","normal"}
local function summary(values)
 if #values==0 then return {count=0}end
 table.sort(values);local total=0
 for _,v in values do total+=v end
 return {count=#values,mean=total/#values,p50=values[math.ceil(#values*.5)],p95=values[math.ceil(#values*.95)],max=values[#values]}
end
function M.Run()
 local Run=game:GetService("RunService")
 assert(Run:IsClient(),"Run this from the CLIENT Command Bar during Play")
 local RS=game:GetService("ReplicatedStorage")
 local Http=game:GetService("HttpService")
 local root=assert(workspace:FindFirstChild("CI_PlanetCelestial"),"Missing sky controller")
 assert(root:GetAttribute("PerformanceProbeVersion")==1,"Sync the updated controller and start a new Play session")
 assert(not root:GetAttribute("PerformanceProbeRunning"),"Probe already running")
 assert(root:GetAttribute("SkyGeneration") and root:GetAttribute("SkyGeneration")>0,"Wait for the first sky generation")
 assert(root:GetAttribute("CelestialModels")=="celestial-1","Wait for celestial models to initialize")
 local telemetry=assert(RS:FindFirstChild("CI_ResearchTelemetry"),"Missing research telemetry")
 local camera=assert(workspace.CurrentCamera,"Missing camera")
 local reference=camera.CFrame
 local savedSky=root:GetAttribute("FreezeSkyBaking")
 local savedModels=root:GetAttribute("FreezeCelestialModels")
 local savedMode=root:GetAttribute("DiagnosticMode")
 assert(savedMode==nil or savedMode=="Normal","Return sky diagnostic mode to Normal first")
 local report={version=1,skyVersion=root:GetAttribute("SkyVersion"),phases={},cameraMoved=false}
 local keys={"ExchangeWorkMs","ExchangeRoundTripMs","ServerStepMs","StateApplyMs","SimulationTicksPerSecond","ExchangeStage_snapshot","ExchangeStage_selection","ExchangeStage_agents","ExchangeStage_plants","ExchangeCount_population","ExchangeCount_visible"}
 root:SetAttribute("PerformanceProbeRunning",true)
 root:SetAttribute("PerformanceProbeCancel",false)
 local connection
 local ok,err=xpcall(function()
  for index,name in phases do
   root:SetAttribute("FreezeSkyBaking",name=="skyFrozen" or name=="bothFrozen")
   root:SetAttribute("FreezeCelestialModels",name=="modelsFrozen" or name=="bothFrozen")
   root:SetAttribute("PerformanceProbePhase",name)
   print(string.format("[CI Sky Profile] %d/8 %s; keep camera still",index,name))
   task.wait(3) -- let a pending bake finish before collecting
   local values={ClientFrameMs={}};for _,key in keys do values[key]={}end
   local item={condition=name,startTick=telemetry:GetAttribute("SimulationTick"),errorsBefore=telemetry:GetAttribute("ExchangeErrorCount"),startGeneration=root:GetAttribute("SkyGeneration"),disconnectedSamples=0}
   local start=os.clock();local sampledAt=0;local previousExchange=nil
   connection=Run.Heartbeat:Connect(function(dt)
    table.insert(values.ClientFrameMs,dt*1000)
    local now=os.clock()
    if now-sampledAt<.1 then return end;sampledAt=now
    if workspace.CurrentCamera~=camera or (camera.CFrame.Position-reference.Position).Magnitude>1 or camera.CFrame.LookVector:Dot(reference.LookVector)<.999 then report.cameraMoved=true end
    local stamp=telemetry:GetAttribute("ExchangeTimestamp")
    if telemetry:GetAttribute("RelayState")~="Connected" or type(stamp)~="number" or workspace:GetServerTimeNow()-stamp>3 then item.disconnectedSamples+=1;return end
    if stamp==previousExchange then return end;previousExchange=stamp
    for _,key in keys do
     local value=telemetry:GetAttribute(key)
     if type(value)=="number" and value==value and math.abs(value)<math.huge then table.insert(values[key],value)end
    end
   end)
   while os.clock()-start<15 do
    task.wait(.2)
    assert(root.Parent and not root:GetAttribute("PerformanceProbeCancel"),"Probe cancelled")
   end
   connection:Disconnect();connection=nil
   item.endTick=telemetry:GetAttribute("SimulationTick");item.errorsAfter=telemetry:GetAttribute("ExchangeErrorCount")
   item.endGeneration=root:GetAttribute("SkyGeneration");item.metrics={}
   for key,list in values do item.metrics[key]=summary(list)end
   table.insert(report.phases,item)
  end
 end,debug.traceback)
 if connection then connection:Disconnect()end
 root:SetAttribute("FreezeSkyBaking",savedSky);root:SetAttribute("FreezeCelestialModels",savedModels)
 root:SetAttribute("PerformanceProbeRunning",false);root:SetAttribute("PerformanceProbePhase",nil)
 report.completed=ok;report.error=if ok then nil else tostring(err)
 local encoded=Http:JSONEncode(report)
 root:SetAttribute("PerformanceProbeResult",encoded)
 print("CI_SKY_PROFILE "..encoded)
 if not ok then warn(err)end
 return report
end
return M
