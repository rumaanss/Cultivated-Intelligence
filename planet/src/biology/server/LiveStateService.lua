--!strict
-- Server authority for microbial body integration only. Biology stays in C++.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Http=game:GetService("HttpService")
local Workspace=game:GetService("Workspace")
local Collection=game:GetService("CollectionService")
local Shared=RS:WaitForChild("CI_Biology")
local Config=require(Shared.LiveConfig)
local Protocol=require(Shared.LiveProtocol)
local Physics=require(Shared.LivePhysics)
local Geometry=require(Shared.SharedGeometry)
local Schema=require(Shared.RecordingSchema)
local Space=require(Shared.SimulationSpace)
local Contract=require(Shared.PlanetContract)
local Metrics=require(Shared.ObservationMetrics)
local httpWindow,applyWindow=Metrics.new(120),Metrics.new(120)
local lastMetricExport=0
local rateTick,rateAt=0,0
local observers:{[Player]:any}={}
local populationTotal=0
local M={}
type Body={row:{number},position:Vector3,velocity:Vector3,health:number,lastIntent:number,lastBite:number,removed:boolean}
type Actor={id:number,kind:number,position:Vector3,radius:number,health:number,part:BasePart?,player:Player?,character:Model?,ack:number,credits:number,lastCredit:number,lastAttack:number,deadAt:number,consumed:boolean}
local bodies: {[number]:Body}={}
local actors: {[number]:Actor}={}
local playerActors: {[Player]:Actor}={}
local nextActor=1
local session=Http:GenerateGUID(false)
local manifest: Schema.Manifest?=nil
local run=""
local batch,sequence,tick,ack,nextEvent=1,-1,0,0,1
local warpVersions: {[string]:number}={}
local correctionAck=0
local boot=""
local leaseEpoch=0
local durableAck=0
local ackBatch=0
local quarantined: {[number]:boolean}={}
local events: {{number}}={}
local light={0,0.08,0.08}
local lastSuccess,lastProgress=0,0
local sampleTime=0
local errorCount=0
local lastError=""
local lastErrorAt=0
local transitions={}
local observedState=""
local function recordTransition(nextState:string,reason:string)
 if nextState==observedState and reason=="" then return end
 observedState=nextState
 table.insert(transitions,{time=Workspace:GetServerTimeNow(),state=nextState,reason=string.sub(reason,1,1000),run=run,boot=boot,batch=batch,sequence=sequence,tick=tick})
 if #transitions>32 then table.remove(transitions,1)end
end
local roundTripMs=0
local requestBytes,responseBytes=0,0
local started=false
local state="Waiting for C++"
local lastSent: {[number]:{number}}={}
local history: {{time:number,positions:{[number]:Vector3},players:{[number]:Vector3}}}={}
local connections: {RBXScriptConnection}={}
local liveRoot: Folder?=nil
local function aliveLink(): boolean return manifest~=nil and os.clock()-lastSuccess<Config.StaleSeconds and os.clock()-lastProgress<Config.StaleSeconds and state=="Live" end
local function sceneNow(): Geometry.Scene?
 local m=manifest
 return if m~=nil then m.geometry else nil
end
local function actorList(): {Physics.Actor}
 local list: {Physics.Actor}={}
 for _,a in actors do if not a.consumed then table.insert(list,{id=a.id,position=a.position,radius=a.radius}) end end
 return list
end
local function pendingDamage(id: number): number
 local amount=0
 for _,event in events do if event[1]>ack and event[2]==1 and event[3]==id then amount+=event[5] end end
 return amount
end
local function queueEvent(kind:number,id:number,actor:number,amount:number): boolean
 if #events>=512 then state="Waiting for combat acknowledgments";return false end
 table.insert(events,{nextEvent,kind,id,actor,amount});nextEvent+=1;return true
end
local function reset(snapshot:any)
 assert(type(snapshot)=="table" and Protocol.integer(snapshot.sequence,0,2147483647) and Protocol.integer(snapshot.tick,0,4294967295),"Invalid initial counters")
 assert(type(snapshot.light)=="table" and #snapshot.light==3,"Invalid initial light")
 for _,v in snapshot.light do assert(Protocol.finite(v) and v>=0 and v<=1,"Invalid initial light value") end
 assert(snapshot.bridgeBuild=="hardened-v3","Old C++ executable: rebuild and restart cybernet_sim (requires hardened-v3)")
 populationTotal=snapshot.total or #snapshot.agents
 local m=Protocol.manifest(snapshot.manifest)
 local scene=m.geometry;assert(scene~=nil,"Missing live geometry")
 local newBodies: {[number]:Body}={}
 assert(type(snapshot.agents)=="table" and #snapshot.agents<=10000,"Population budget")
 for _,raw in snapshot.agents do
  local row=Protocol.row(raw,scene)
  assert(newBodies[row[1]]==nil,"Duplicate body")
  newBodies[row[1]]={row=row,position=Vector3.new(row[3],row[4],row[5]),velocity=Vector3.new(row[6],row[7],row[8]),health=row[18],lastIntent=os.clock(),lastBite=0,removed=false}
 end
 Space.configure(m.bounds)
 manifest,run,bodies=m,m.runId,newBodies
 batch,sequence,tick,ack,nextEvent=1,snapshot.sequence,snapshot.tick,0,1
 ackBatch=0;boot=snapshot.boot or "";durableAck=snapshot.durableAck or 0
 events,lastSent,history={},{},{}
 correctionAck=0;quarantined={};warpVersions={}
 session=Http:GenerateGUID(false)
 light=snapshot.light
 sampleTime=Workspace:GetServerTimeNow()
 lastSuccess,lastProgress=os.clock(),os.clock();state="Live"
 if liveRoot then liveRoot:Destroy() end
 local root=Instance.new("Folder");root.Name="CI_LiveAuthority";root.Parent=Workspace;liveRoot=root
 actors,playerActors,nextActor={},{},1
 Workspace:SetAttribute("CI_LiveRunId",run)
 Workspace:SetAttribute("CI_BridgeBuild",snapshot.bridgeBuild or "legacy")
 print("[CI Biology] Connected: "..run.."; planetary habitat; existing player controller retained")
end
local function accept(response:any)
 assert(type(response)=="table" and response.protocol==1,"Live protocol mismatch")
 if response.reset==true then reset(response.snapshot);return end
 if response.resync==true then
  assert(response.session==session and response.snapshot.manifest.runId==run,"Bad resync identity")
  local oldSession,oldEvents,oldNext=session,events,nextEvent
  reset(response.snapshot)
  session=oldSession;events=oldEvents;nextEvent=oldNext;batch=response.batch+1;leaseEpoch=response.epoch
  ack=response.snapshot.ack;durableAck=response.snapshot.durableAck or 0
  return
 end
 assert(response.bridgeBuild=="hardened-v3","Transport protocol mismatch: rebuild the native application and sync this project")
 assert(response.run==run and response.session==session and response.batch==batch,"Wrong exchange identity")
 assert(Protocol.integer(response.sequence,0,2147483647) and response.sequence>=sequence and Protocol.integer(response.tick,0,4294967295) and response.tick>=tick,"Out-of-order C++ state")
 assert(Protocol.integer(response.ack,ack,nextEvent-1),"Invalid acknowledgment")
 assert(Protocol.integer(response.durableAck,0,response.ack),"Invalid durable acknowledgment")
 assert(Protocol.integer(response.epoch,math.max(1,leaseEpoch),2147483647),"Old lease epoch")
 assert(Protocol.finite(response.age) and response.age>=0 and type(response.stalled)=="boolean" and (response.state=="running" or response.state=="stopped"),"Invalid relay status")
 local scene=sceneNow();assert(scene~=nil,"No scene")
 assert(type(response.added)=="table" and #response.added<=10000 and type(response.updates)=="table" and #response.updates<=10000 and type(response.removed)=="table" and #response.removed<=10000,"Delta budgets")
 -- Validate all changes before applying the batch.
 local motions=response.motions
 assert(type(motions)=="table" and #motions<=10000,"Missing native motion stream")
 local motionIds={}
 for _,pose in motions do
  assert(type(pose)=="table" and #pose==7 and Protocol.integer(pose[1],1,2147483647) and not motionIds[pose[1]],"Invalid native motion identity")
  motionIds[pose[1]]=true
  for _,value in pose do assert(Protocol.finite(value),"Invalid native motion value") end
  assert(Geometry.clear(scene,pose[2],pose[3],pose[4]),"Native motion outside habitat")
 end
 local additions: {{number}}={};local changes: {{number}}={}
 for _,row in response.added do table.insert(additions,Protocol.row(row,scene)) end
 for _,update in response.updates do
  assert(type(update)=="table" and #update==15,"Bad biological delta")
  local body=bodies[update[1]];assert(body~=nil,"Delta before birth")
  local row=table.clone(body.row);row[9],row[10]=update[2],update[3]
  for i=4,15 do row[i+10]=update[i] end
  table.insert(changes,Protocol.row(row,scene))
 end
 for _,id in response.removed do assert(Protocol.integer(id,1,2147483647),"Bad death ID") end
 assert(type(response.light)=="table" and #response.light==3,"Bad light")
 for _,value in response.light do assert(Protocol.finite(value) and value>=0 and value<=1,"Bad light value") end
 local corrections=response.corrections or {}
 assert(type(corrections)=="table" and #corrections<=10064,"Correction budget")
 for _,c in corrections do
  assert(type(c)=="table" and #c==6 and Protocol.integer(c[1],1,2147483647) and (c[2]==1 or c[2]==2) and Protocol.integer(c[3],1,2147483647),"Bad correction identity")
  assert(Protocol.finite(c[4]) and Protocol.finite(c[5]) and Protocol.finite(c[6]) and c[4]>=0 and c[4]<=Space.Bounds.width and c[5]>=0 and c[5]<=Space.Bounds.length and c[6]>=0 and c[6]<=Space.Bounds.depth,"Bad correction position")
 end
 ack=response.ack;durableAck=response.durableAck or 0;leaseEpoch=response.epoch or leaseEpoch
 local remaining:{{number}}={};for _,event in events do if event[1]>durableAck then table.insert(remaining,event) end end;events=remaining
 for _,row in additions do
  local body=bodies[row[1]]
  if body==nil then
   bodies[row[1]]={row=row,position=Vector3.new(row[3],row[4],row[5]),velocity=Vector3.new(row[6],row[7],row[8]),health=math.max(0,row[18]-pendingDamage(row[1])),lastIntent=os.clock(),lastBite=0,removed=false}
  else table.insert(changes,row) end
 end
 for _,row in changes do
  local body=bodies[row[1]]
  body.row=row;body.health=math.max(0,row[18]-pendingDamage(row[1]));body.lastIntent=os.clock()
  if body.health<=0 then body.removed=true end
 end
 for _,id in response.removed do bodies[id]=nil;lastSent[id]=nil;warpVersions[tostring(id)]=nil end
 local nextQuarantine: {[number]:boolean}={}
 local previousAck=correctionAck
 for _,c in corrections do
  local id=c[3]
  if c[2]==1 then nextQuarantine[id]=true end
  if c[1]>previousAck then
   local p=Vector3.new(c[4],c[5],c[6])
   if c[2]==1 then
    local body=bodies[id]
    if body then warpVersions[tostring(id)]=c[1];body.position=p;body.velocity=Vector3.zero;lastSent[id]=nil end
   end
   correctionAck=math.max(correctionAck,c[1])
  end
 end
 quarantined=nextQuarantine
 Workspace:SetAttribute("CI_LiveBridgeReason",response.bridgeStatus or "unknown")
 Workspace:SetAttribute("CI_LiveCorrections",#corrections)
 Workspace:SetAttribute("CI_BridgeBuild",response.bridgeBuild or "legacy")
 if response.tick>tick then lastProgress=os.clock() end
 if response.sequence>sequence then sampleTime=Workspace:GetServerTimeNow() end
 tick,sequence,light=response.tick,response.sequence,response.light
 lastSuccess=os.clock()
 state=if response.state=="stopped" then "C++ stopped" elseif response.age>Config.StaleSeconds or response.stalled then "C++ paused/stale" else "Live"
 for _,pose in motions do
  local body=bodies[pose[1]]
  if body then body.position=Vector3.new(pose[2],pose[3],pose[4]);body.velocity=Vector3.new(pose[5],pose[6],pose[7]);body.row[3],body.row[4],body.row[5]=pose[2],pose[3],pose[4] end
 end
 populationTotal=response.total or populationTotal
 ackBatch=response.batch
 batch+=1
end
local PlantTransport=require(RS:WaitForChild("CI_Biology"):WaitForChild("PlantTransportBridge"))
local function requestBody(): any
 local poses:{{number}}={} -- C++ owns all microbial motion.
 local actorRows:{{number}}={}
 for _,a in actors do if not a.consumed then table.insert(actorRows,{a.id,a.kind,a.position.X,a.position.Y,a.position.Z,a.radius,a.health}) end end
 local regions={}
 local ordered:{{player:Player,observer:any}}={};for player,observer in observers do if os.clock()-observer.at<5 then table.insert(ordered,{player=player,observer=observer})end end
 table.sort(ordered,function(a:{player:Player,observer:any},b:{player:Player,observer:any})return a.player.UserId<b.player.UserId end)
 for i=1,math.min(4,#ordered)do table.insert(regions,ordered[i].observer.region)end
 if #regions==0 then table.insert(regions,{center={Space.Bounds.width/2,Space.Bounds.length/2,Space.Bounds.depth/2},limit=Config.MaximumVisibleOrganisms,selected=0})end
 return {observer={version=1,regions=regions},protocol=1,run=run,session=session,batch=batch,ackBatch=ackBatch,boot=boot,epoch=leaseEpoch,correctionAck=correctionAck,poses=poses,actors=actorRows,events=table.clone(events),plants={schema=1,run=PlantTransport.run,revision=PlantTransport.revision,transfer=PlantTransport.transfer,chunk=PlantTransport.nextChunk}}
end
local function clearLine(scene:Geometry.Scene,a:Vector3,b:Vector3,ignore:number?):boolean
 if Geometry.blocked(scene,{a.X,a.Y,a.Z},{b.X,b.Y,b.Z},0,true) then return false end
 local d=b-a;local length=d:Dot(d)
 if length<.000001 then return true end
 for id,actor in actors do
  if id~=ignore and not actor.consumed then
   local t=math.clamp((actor.position-a):Dot(d)/length,0,1)
   if (a+d*t-actor.position).Magnitude<actor.radius then return false end
  end
 end
 return true
end
function M.Start()
 if started then return end;started=true
 assert(Http.HttpEnabled,"Enable Allow HTTP Requests in Experience Settings > Security")
 local transportModule=game:GetService("ServerScriptService"):WaitForChild("CI_Integration"):WaitForChild("LiveTransportConfig",10)
 assert(transportModule~=nil and transportModule:IsA("ModuleScript"),"Start relay.py with --roblox-root, then sync Rojo")
 local loadModule=require :: (ModuleScript)->any
 local transport=loadModule(transportModule)
 assert(type(transport.Url)=="string" and type(transport.Token)=="string" and #transport.Token>=32,"Invalid live transport configuration")
 assert(string.sub(transport.Url,1,8)=="https://" or (RunService:IsStudio() and string.match(transport.Url,"^http://localhost:%d+/exchange$")~=nil),"Public games require HTTPS")
 local old=RS:FindFirstChild("CI_Live");if old then old:Destroy() end
 local folder=Instance.new("Folder");folder.Name="CI_Live";folder.Parent=RS
 local fetch=Instance.new("RemoteFunction");fetch.Name="Fetch";fetch.Parent=folder
 -- Observer integration intentionally exposes no legacy movement/combat remote.
 local rates:{[Player]:{at:number,count:number,frames:number,cursor:number,ids:{number},center:Vector3,chosenAt:number,run:string,total:number}}={}
 fetch.OnServerInvoke=function(player:Player,knownRun:any,selected:any,camera:any): any
  local active=Players:GetPlayers();table.sort(active,function(a:Player,b:Player)return a.UserId<b.UserId end)
  if (table.find(active,player)or 5)>4 then return {error="Observer capacity: four concurrent research regions"}end
  local now=os.clock();local rate=rates[player]
  if rate==nil then rate={at=now,count=0,frames=0,cursor=0,ids={},center=Vector3.zero,chosenAt=0,run="",total=0};rates[player]=rate end
  if now-rate.at>=1 then rate.at,rate.count=now,0 end
  rate.count+=1;if rate.count>20 then return nil end
  rate.frames+=1
  local m=manifest;if m==nil then return {state=state} end
  local center=if playerActors[player]~=nil then playerActors[player].position else Vector3.new(Space.Bounds.width/2,Space.Bounds.length/2,Space.Bounds.depth/2)
  if typeof(camera)=="Vector3" and camera.Magnitude<1000 then center=camera end
  observers[player]={at=now,region={center={center.X,center.Y,center.Z},limit=Config.MaximumVisibleOrganisms,selected=if Protocol.integer(selected,1,2147483647)then selected else 0}}
  -- Cache interest membership; sort only the nearest distance buckets, not the population per request.
  if now-rate.chosenAt>=.25 or rate.run~=run or (center-rate.center).Magnitude>5 then
   local buckets:{[number]:{{id:number,distance:number}}}={};local total=0
   for id,b in bodies do if not b.removed then
    total+=1;local distance=(b.position-center).Magnitude;local bin=math.min(220,math.floor(distance/5))
    if buckets[bin]==nil then buckets[bin]={} end
    table.insert(buckets[bin],{id=id,distance=distance})
   end end
   local ids:{number}={}
   for bin=0,220 do
    local bucket=buckets[bin]
    if bucket~=nil then
     table.sort(bucket,function(a:{id:number,distance:number},b:{id:number,distance:number}):boolean return if a.distance==b.distance then a.id<b.id else a.distance<b.distance end)
     for _,entry in bucket do table.insert(ids,entry.id);if #ids>=Config.MaximumVisibleOrganisms then break end end
    end
    if #ids>=Config.MaximumVisibleOrganisms then break end
   end
   if Protocol.integer(selected,1,2147483647) and bodies[selected] and not table.find(ids,selected) then
    if #ids>=Config.MaximumVisibleOrganisms then table.remove(ids)end;table.insert(ids,selected)
   end
   rate.ids,rate.center,rate.chosenAt,rate.run,rate.total=ids,center,now,run,total
  end
  local full=rate.frames%3==1 or knownRun~=(run..":"..boot)
  local rows:{{number}}={}
  local packetWarps: {[string]:number}={}
  for i=1,math.min(#rate.ids,if full then Config.MaximumVisibleOrganisms else 64) do
   local index=if full then i else (rate.cursor+i-1)%#rate.ids+1
   local id=rate.ids[index];local b=bodies[id]
   if b~=nil and not b.removed then local key=tostring(id);packetWarps[key]=warpVersions[key] or 0;local p=b.position;table.insert(rows,{id,b.row[2],p.X,p.Y,p.Z,0,0,0,b.row[9]}) end
  end
  if not full and #rate.ids>0 then rate.cursor=(rate.cursor+64)%#rate.ids end
  local actor=playerActors[player]
  local selectedBody=if Protocol.integer(selected,1,2147483647) then bodies[selected] else nil
  local inspected=if selectedBody then table.clone(selectedBody.row) else nil
  if inspected and selectedBody then inspected[18]=selectedBody.health end
  return {run=run,boot=boot,manifest=if knownRun~=(run..":"..boot) then m else nil,state=if aliveLink() then "Live" else state.." / paused",tick=tick,light=light,sequence=sequence,full=full,total=populationTotal,diagnostics={roundTripMs,requestBytes,responseBytes,#events,Workspace:GetAttribute("CI_RelayComputeMs") or 0},buffer=Protocol.pack(rows),warps=packetWarps,serverTime=Workspace:GetServerTimeNow(),sampleTime=sampleTime,actors=actorList(),player=if actor then {actor.id,actor.position.X,actor.position.Y,actor.position.Z,actor.ack,actor.health} else nil,inspected=inspected}
 end
 table.insert(connections,Players.PlayerRemoving:Connect(function(player)
  local a=playerActors[player];if a then actors[a.id]=nil end;playerActors[player]=nil;rates[player]=nil;observers[player]=nil
 end))
 Workspace:SetAttribute("CI_BiologyPhysicsMs",0)
 Workspace:SetAttribute("CI_MotionAuthority","cpp-v1")
 task.spawn(function()
  local delay=1/math.clamp(Config.ExchangeHz,1,6)
  local pendingRequest:any=nil
  while started do
   local began=os.clock()
   if pendingRequest==nil then pendingRequest=requestBody() end
   local request=pendingRequest
   local phase="encode"
   local ok,err=pcall(function()
    local encoded=Http:JSONEncode(request);requestBytes=#encoded
    assert(requestBytes<=3*1024*1024,"Request budget exceeded")
    phase="http"
    local result=Http:RequestAsync({Url=transport.Url,Method="POST",Headers={["Content-Type"]="application/json",["X-CI-Token"]=transport.Token},Body=encoded})
    roundTripMs=(os.clock()-began)*1000;Workspace:SetAttribute("CI_HttpRoundTripMs",roundTripMs);responseBytes=#result.Body
    if not result.Success and (result.StatusCode==409 or result.StatusCode==503) then
     local decoded,problem=pcall(function()return Http:JSONDecode(result.Body)end)
     local reason=if decoded and type(problem)=="table" then problem.error else nil
     if result.StatusCode==503 and reason=="waiting for C++ publisher" then
      state="Waiting for C++ publisher";return
     elseif result.StatusCode==409 and reason=="world already leased or has uncommitted events" then
      state="Waiting for previous observer ownership";return
     end
    end
    assert(result.Success,"Relay HTTP "..tostring(result.StatusCode)..": "..string.sub(result.Body,1,1000))
    assert(#result.Body<=12*1024*1024,"Response budget")
    Metrics.push(httpWindow,roundTripMs)
    phase="decode"
    local response=Http:JSONDecode(result.Body)
    Workspace:SetAttribute("CI_CppInputAgeMs",response.cppInputAgeMs)
    Workspace:SetAttribute("CI_LiveEventError",response.eventError)
    Workspace:SetAttribute("CI_RelayDiskMs",if response.relayTimingMs then response.relayTimingMs[2] else 0)
    local telemetry=RS:FindFirstChild("CI_ResearchTelemetry")
    if telemetry then
     local snapshot=response.snapshot or response
     local currentTick=snapshot.tick
     local now=os.clock()
     if type(currentTick)=="number" then
      if rateAt==0 or currentTick<rateTick then rateTick,rateAt=currentTick,now
      elseif now-rateAt>=1 then telemetry:SetAttribute("SimulationTicksPerSecond",(currentTick-rateTick)/(now-rateAt));rateTick,rateAt=currentTick,now end
      telemetry:SetAttribute("SimulationTick",currentTick)
     end
     telemetry:SetAttribute("SimulationState",snapshot.state or "resynchronizing")
     telemetry:SetAttribute("SnapshotAgeSeconds",response.age or 0)
     telemetry:SetAttribute("RelayState","Connected")
     telemetry:SetAttribute("RelayTimestamp",Workspace:GetServerTimeNow())
     telemetry:SetAttribute("ExchangeTimestamp",Workspace:GetServerTimeNow())
    end
    local applyStarted=os.clock()
    phase="validate/apply"
    accept(response)
    phase="plants"
    if response.plants then PlantTransport.deliver(response.plants) end
    if response.plantError then Workspace:SetAttribute("CI_PlantStatus",response.plantError) end
    local applyMs=(os.clock()-applyStarted)*1000
    Metrics.push(applyWindow,applyMs)
    Workspace:SetAttribute("CI_BiologyApplyMs",applyMs)
    Workspace:SetAttribute("CI_RelayComputeMs",if response.relayTimingMs then response.relayTimingMs[3] else 0)
    if response.reset~=true and response.resync~=true then for _,pose in request.poses do if not quarantined[pose[1]] then lastSent[pose[1]]=pose end end end
    pendingRequest=nil
   end)
   if not ok then
    local message=phase..": "..string.sub(tostring(err),1,1000)
    if message~=lastError or Workspace:GetServerTimeNow()-lastErrorAt>10 then warn("[CI Exchange] "..message)end
    errorCount+=1;lastError=message;lastErrorAt=Workspace:GetServerTimeNow()
    recordTransition("Reconnecting",lastError)
    batch+=1;pendingRequest=nil;state="Reconnecting";Workspace:SetAttribute("CI_LiveError",tostring(err));delay=math.min(2,delay*1.5) else Workspace:SetAttribute("CI_LiveError",nil);delay=1/math.clamp(Config.ExchangeHz,1,6) end
   recordTransition(state,"")
   Workspace:SetAttribute("CI_LiveStatus",state)
   local telemetry=RS:FindFirstChild("CI_ResearchTelemetry")
   if telemetry then telemetry:SetAttribute("BiologyState",if aliveLink() then "Live" else state);telemetry:SetAttribute("ExchangeWorkMs",Workspace:GetAttribute("CI_RelayComputeMs"));telemetry:SetAttribute("ExchangeRoundTripMs",roundTripMs);telemetry:SetAttribute("StateApplyMs",Workspace:GetAttribute("CI_BiologyApplyMs"));telemetry:SetAttribute("ExchangeError",Workspace:GetAttribute("CI_LiveError")) end
   if telemetry then
    if os.clock()-lastMetricExport>=1 then
     lastMetricExport=os.clock()
     local h50,h95,h99=Metrics.summary(httpWindow)
     local a50,a95,a99=Metrics.summary(applyWindow)
     telemetry:SetAttribute("HttpP50Ms",h50);telemetry:SetAttribute("HttpP95Ms",h95);telemetry:SetAttribute("HttpP99Ms",h99)
     telemetry:SetAttribute("ApplyP50Ms",a50);telemetry:SetAttribute("ApplyP95Ms",a95);telemetry:SetAttribute("ApplyP99Ms",a99)
    end
    telemetry:SetAttribute("LastExchangeError",lastError~="" and lastError or nil)
    telemetry:SetAttribute("LastExchangeErrorAt",lastErrorAt)
    telemetry:SetAttribute("ExchangeErrorCount",errorCount)
    telemetry:SetAttribute("ExchangeHistory",Http:JSONEncode(transitions))
    telemetry:SetAttribute("CppInputAgeMs",Workspace:GetAttribute("CI_CppInputAgeMs"))
    telemetry:SetAttribute("BridgeReason",Workspace:GetAttribute("CI_LiveBridgeReason"))
   end
   local lake=RS:FindFirstChild("CI_LakeWater");if lake then lake:SetAttribute("BiologyEnabled",aliveLink())end
   Workspace:SetAttribute("CI_LastExchangeAge",os.clock()-lastSuccess)
   task.wait(math.max(.01,delay-(os.clock()-began)))
  end
 end)
 game:BindToClose(function()started=false;for _,c in connections do c:Disconnect() end end)
end
return M
