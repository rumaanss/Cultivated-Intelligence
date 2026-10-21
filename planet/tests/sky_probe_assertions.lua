local simulatedTime=0;local heartbeat=services.RunService.Heartbeat
local os={clock=function()return simulatedTime end}
services.RunService.IsClient=function()return true end
workspace.GetServerTimeNow=function()return simulatedTime end
workspace.CurrentCamera={CFrame={Position=Vector3.zero,LookVector=Vector3.xAxis}}
local root=Instance.new('Folder');root.Name='CI_PlanetCelestial';root.Parent=workspace
root:SetAttribute('PerformanceProbeVersion',1)
root:SetAttribute('SkyGeneration',1);root:SetAttribute('CelestialModels','celestial-1')
local telemetry=Instance.new('Folder');telemetry.Name='CI_ResearchTelemetry';telemetry.Parent=replicated
telemetry:SetAttribute('RelayState','Connected');telemetry:SetAttribute('ExchangeWorkMs',12)
telemetry:SetAttribute('SimulationTick',1);telemetry:SetAttribute('ExchangeErrorCount',0)
local cancelAt=nil
local task={wait=function(duration)
 for _=1,math.ceil((duration or 1/60)*60)do
  simulatedTime+=1/60
  telemetry:SetAttribute('ExchangeTimestamp',math.floor(simulatedTime*10)/10)
  if cancelAt and simulatedTime>cancelAt then root:SetAttribute('PerformanceProbeCancel',true)end
  heartbeat:Fire(1/60)
 end
end}
local Probe=PROBE_SOURCE_PLACEHOLDER
local before=activeConnections
local report=Probe.Run()
assert(report.completed and #report.phases==8 and not report.cameraMoved)
assert(report.phases[1].metrics.ExchangeWorkMs.mean==12)
assert(report.phases[1].metrics.ClientFrameMs.count>800)
assert(report.phases[1].metrics.ExchangeWorkMs.count<200,'duplicates sampled per frame')
assert(root:GetAttribute('FreezeSkyBaking')==nil and root:GetAttribute('FreezeCelestialModels')==nil)
assert(activeConnections==before,'connection leak')
cancelAt=simulatedTime+4
local cancelled=Probe.Run()
assert(not cancelled.completed and #cancelled.phases==0)
assert(not root:GetAttribute('PerformanceProbeRunning'))
assert(root:GetAttribute('FreezeSkyBaking')==nil and root:GetAttribute('FreezeCelestialModels')==nil)
assert(activeConnections==before,'cancellation connection leak')
print('PASS sky isolation probe: eight balanced phases, distinct exchange sampling, restoration on completion and cancellation')
