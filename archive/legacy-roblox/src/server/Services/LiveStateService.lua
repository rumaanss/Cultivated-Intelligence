--!strict
-- Server authority for live body integration and player combat. Biology stays in C++.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Http=game:GetService("HttpService")
local Workspace=game:GetService("Workspace")
local Collection=game:GetService("CollectionService")
local Shared=RS:WaitForChild("Shared")
local Config=require(Shared.LiveConfig)
local Protocol=require(Shared.LiveProtocol)
local Physics=require(Shared.LivePhysics)
local Geometry=require(Shared.SharedGeometry)
local Schema=require(Shared.RecordingSchema)
local Space=require(Shared.SimulationSpace)
local GeometryPresentation=require(Shared.GeometryPresentation)
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
local roundTripMs=0
local requestBytes,responseBytes=0,0
local started=false
local state="Waiting for C++"
local lastSent: {[number]:{number}}={}
local history: {{time:number,positions:{[number]:Vector3},players:{[number]:Vector3}}}={}
local connections: {RBXScriptConnection}={}
local liveRoot: Folder?=nil
local function fromWorld(p: Vector3): Vector3 local q=Space.toSimulation(p);return Vector3.new(q.x,q.y,q.z) end
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
local function createActor(player:Player,character:Model)
 local scene=sceneNow();if scene==nil then return end
 local root=character:FindFirstChild("HumanoidRootPart")
 local humanoid=character:FindFirstChildOfClass("Humanoid")
 if root==nil or not root:IsA("BasePart") or humanoid==nil then return end
 local actorCount=0;for _ in actors do actorCount+=1 end
 if nextActor>=999999 or actorCount>=64 then warn("[CI Live] Actor budget full; player not registered");return end
 local old=playerActors[player]
 if old then actors[old.id]=nil end
 local p=Physics.place(scene,Vector3.new(scene.bounds[1]/2,scene.bounds[2]/2,scene.bounds[3]-20),Config.PlayerRadius+0.5)
 local actor:Actor={id=nextActor,kind=1,position=p,radius=Config.PlayerRadius,health=humanoid.Health,part=root,player=player,character=character,ack=0,credits=4,lastCredit=os.clock(),lastAttack=0,deadAt=0,consumed=false}
 nextActor+=1;actors[actor.id]=actor;playerActors[player]=actor
 root.Anchored=true
 character:PivotTo(CFrame.new(Space.toRobloxXYZ(p.X,p.Y,p.Z)))
 table.insert(connections,humanoid.Died:Connect(function()actor.health=0;actor.deadAt=os.clock()end))
end
local function registerPlayer(player:Player)
 table.insert(connections,player.CharacterAdded:Connect(function(character)
  task.spawn(function()
   local root=character:WaitForChild("HumanoidRootPart",10)
   if root~=nil then createActor(player,character) end
  end)
 end))
 if player.Character then createActor(player,player.Character) end
end
local function reset(snapshot:any)
 assert(type(snapshot)=="table" and Protocol.integer(snapshot.sequence,0,2147483647) and Protocol.integer(snapshot.tick,0,4294967295),"Invalid initial counters")
 assert(type(snapshot.light)=="table" and #snapshot.light==3,"Invalid initial light")
 for _,v in snapshot.light do assert(Protocol.finite(v) and v>=0 and v<=1,"Invalid initial light value") end
 assert(snapshot.bridgeBuild=="hardened-v3","Old C++ executable: rebuild and restart cybernet_sim (requires hardened-v3)")
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
 lastSuccess,lastProgress=os.clock(),os.clock();state="Live"
 if liveRoot then liveRoot:Destroy() end
 local root=Instance.new("Folder");root.Name="CI_LiveAuthority";root.Parent=Workspace;liveRoot=root
 local geometry=GeometryPresentation.create(scene,root,false,false)
 for _,part in geometry:GetDescendants() do if part:IsA("BasePart") then part.Transparency=1;part.CastShadow=false end end
 actors,playerActors,nextActor={},{},1
 for _,player in Players:GetPlayers() do if player.Character then createActor(player,player.Character) end end
 Workspace:SetAttribute("CI_LiveRunId",run)
 Workspace:SetAttribute("CI_BridgeBuild",snapshot.bridgeBuild or "legacy")
 print("[CI Live] Connected: "..run.."; Roblox movement/combat, C++ biology")
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
 assert(response.bridgeBuild=="hardened-v3","Old bridge relay: replace relay.py and restart both terminals")
 assert(response.run==run and response.session==session and response.batch==batch,"Wrong exchange identity")
 assert(Protocol.integer(response.sequence,0,2147483647) and response.sequence>=sequence and Protocol.integer(response.tick,0,4294967295) and response.tick>=tick,"Out-of-order C++ state")
 assert(Protocol.integer(response.ack,ack,nextEvent-1),"Invalid acknowledgment")
 assert(Protocol.integer(response.durableAck,0,response.ack),"Invalid durable acknowledgment")
 assert(Protocol.integer(response.epoch,math.max(1,leaseEpoch),2147483647),"Old lease epoch")
 assert(Protocol.finite(response.age) and response.age>=0 and type(response.stalled)=="boolean" and (response.state=="running" or response.state=="stopped"),"Invalid relay status")
 local scene=sceneNow();assert(scene~=nil,"No scene")
 assert(type(response.added)=="table" and #response.added<=10000 and type(response.updates)=="table" and #response.updates<=10000 and type(response.removed)=="table" and #response.removed<=10000,"Delta budgets")
 -- Validate all changes before applying the batch.
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
   else
    local actor=actors[id]
    if actor then
     actor.position=p
     if actor.character then actor.character:PivotTo(CFrame.new(Space.toRobloxXYZ(p.X,p.Y,p.Z)))
     elseif actor.part then actor.part.Position=Space.toRobloxXYZ(p.X,p.Y,p.Z) end
    end
   end
   correctionAck=math.max(correctionAck,c[1])
  end
 end
 quarantined=nextQuarantine
 Workspace:SetAttribute("CI_LiveBridgeReason",response.bridgeStatus or "unknown")
 Workspace:SetAttribute("CI_LiveCorrections",#corrections)
 Workspace:SetAttribute("CI_BridgeBuild",response.bridgeBuild or "legacy")
 if response.tick>tick then lastProgress=os.clock() end
 tick,sequence,light=response.tick,response.sequence,response.light
 lastSuccess=os.clock()
 state=if response.state=="stopped" then "C++ stopped" elseif response.age>Config.StaleSeconds or response.stalled then "C++ paused/stale" else "Live"
 ackBatch=response.batch
 batch+=1
end
local PlantTransport=require(RS:WaitForChild("Shared"):WaitForChild("PlantTransportBridge"))
local function requestBody(): any
 local poses:{{number}}={}
 for id,b in bodies do
  local p,v=b.position,b.velocity
  local row={id,p.X,p.Y,p.Z,v.X,v.Y,v.Z}
  local previous=lastSent[id];local changed=previous==nil
  if previous then for i=2,7 do if row[i]~=previous[i] then changed=true;break end end end
  if changed then table.insert(poses,row) end
 end
 local actorRows:{{number}}={}
 for _,a in actors do if not a.consumed then table.insert(actorRows,{a.id,a.kind,a.position.X,a.position.Y,a.position.Z,a.radius,a.health}) end end
 return {protocol=1,run=run,session=session,batch=batch,ackBatch=ackBatch,boot=boot,epoch=leaseEpoch,correctionAck=correctionAck,poses=poses,actors=actorRows,events=table.clone(events),plants={schema=1,run=PlantTransport.run,revision=PlantTransport.revision,transfer=PlantTransport.transfer,chunk=PlantTransport.nextChunk}}
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
local function combat(player:Player,target:any,when:any)
 local actor=playerActors[player];local body=if Protocol.integer(target,1,2147483647) then bodies[target] else nil
 local scene=sceneNow()
 if actor==nil or actor.health<=0 or body==nil or body.removed or quarantined[target] or scene==nil or not aliveLink() or os.clock()-actor.lastAttack<Config.AttackCooldown then return end
 actor.lastAttack=os.clock()
 -- Rewind validation is bounded; it never trusts a client hit or client position.
 local timestamp=if Protocol.finite(when) then math.clamp(when,Workspace:GetServerTimeNow()-0.35,Workspace:GetServerTimeNow()) else Workspace:GetServerTimeNow()
 local playerPos,bodyPos=actor.position,body.position
 for i=#history,1,-1 do
  local sample=history[i]
  if sample.time<=timestamp then playerPos=sample.players[actor.id] or playerPos;bodyPos=sample.positions[target] or bodyPos;break end
 end
 if (playerPos-bodyPos).Magnitude>Config.AttackRange or not clearLine(scene,playerPos,bodyPos,actor.id) then return end
 if queueEvent(1,target,actor.id,math.min(Config.AttackDamage,body.health)) then
  body.health=math.max(0,body.health-Config.AttackDamage)
  if body.health<=0 then body.removed=true end
 end
end
function M.Start()
 if started then return end;started=true
 assert(Http.HttpEnabled,"Enable Allow HTTP Requests in Experience Settings > Security")
 local transportModule=script.Parent.Parent:WaitForChild("LiveTransportConfig",10)
 assert(transportModule~=nil and transportModule:IsA("ModuleScript"),"Start relay.py with --roblox-root, then sync Rojo")
 local loadModule=require :: (ModuleScript)->any
 local transport=loadModule(transportModule)
 assert(type(transport.Url)=="string" and type(transport.Token)=="string" and #transport.Token>=32,"Invalid live transport configuration")
 assert(string.sub(transport.Url,1,8)=="https://" or (RunService:IsStudio() and string.match(transport.Url,"^http://localhost:%d+/exchange$")~=nil),"Public games require HTTPS")
 local old=RS:FindFirstChild("CI_Live");if old then old:Destroy() end
 local folder=Instance.new("Folder");folder.Name="CI_Live";folder.Parent=RS
 local fetch=Instance.new("RemoteFunction");fetch.Name="Fetch";fetch.Parent=folder
 local input=Instance.new("RemoteEvent");input.Name="Input";input.Parent=folder
 local rates:{[Player]:{at:number,count:number,frames:number,ids:{number},center:Vector3,chosenAt:number,run:string,total:number}}={}
 fetch.OnServerInvoke=function(player:Player,knownRun:any,selected:any,camera:any): any
  local now=os.clock();local rate=rates[player]
  if rate==nil then rate={at=now,count=0,frames=0,ids={},center=Vector3.zero,chosenAt=0,run="",total=0};rates[player]=rate end
  if now-rate.at>=1 then rate.at,rate.count=now,0 end
  rate.count+=1;if rate.count>20 then return nil end
  rate.frames+=1
  local m=manifest;if m==nil then return {state=state} end
  local center=if playerActors[player]~=nil then playerActors[player].position else Vector3.new(Space.Bounds.width/2,Space.Bounds.length/2,Space.Bounds.depth/2)
  if typeof(camera)=="Vector3" and camera.Magnitude<1000 then center=camera end
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
   rate.ids,rate.center,rate.chosenAt,rate.run,rate.total=ids,center,now,run,total
  end
  local full=rate.frames%3==1 or knownRun~=(run..":"..boot)
  local rows:{{number}}={}
  local packetWarps: {[string]:number}={}
  for i=1,math.min(#rate.ids,if full then Config.MaximumVisibleOrganisms else 64) do
   local id=rate.ids[i];local b=bodies[id]
   if b~=nil and not b.removed then local key=tostring(id);packetWarps[key]=warpVersions[key] or 0;local p=b.position;table.insert(rows,{id,b.row[2],p.X,p.Y,p.Z,0,0,0,b.row[9]}) end
  end
  local actor=playerActors[player]
  local selectedBody=if Protocol.integer(selected,1,2147483647) then bodies[selected] else nil
  local inspected=if selectedBody then table.clone(selectedBody.row) else nil
  if inspected and selectedBody then inspected[18]=selectedBody.health end
  return {run=run,boot=boot,manifest=if knownRun~=(run..":"..boot) then m else nil,state=if aliveLink() then "Live" else state.." / paused",tick=tick,light=light,sequence=sequence,full=full,total=rate.total,diagnostics={roundTripMs,requestBytes,responseBytes,#events,Workspace:GetAttribute("CI_RelayComputeMs") or 0},buffer=Protocol.pack(rows),warps=packetWarps,serverTime=Workspace:GetServerTimeNow(),actors=actorList(),player=if actor then {actor.id,actor.position.X,actor.position.Y,actor.position.Z,actor.ack,actor.health} else nil,inspected=inspected}
 end
 table.insert(connections,input.OnServerEvent:Connect(function(player:Player,kind:any,data:any,when:any)
  if kind=="attack" then combat(player,data,when);return end
  local actor=playerActors[player];local scene=sceneNow()
  if kind~="move" or type(data)~="table" or #data>16 or actor==nil or actor.health<=0 or scene==nil or not aliveLink() then return end
  local now=os.clock();actor.credits=math.min(6,actor.credits+(now-actor.lastCredit)*60);actor.lastCredit=now
  if actor.credits<1 then return end
  local colliders=actorList()
  for _,command in data do
   if type(command)~="table" or #command~=4 or not Protocol.integer(command[1],1,2147483647) then return end
   if command[1]<=actor.ack then continue end
   if command[1]~=actor.ack+1 or actor.credits<1 then break end
   for i=2,4 do if not Protocol.finite(command[i]) or math.abs(command[i])>1 then return end end
   local direction=Vector3.new(command[2],command[3],command[4]);if direction.Magnitude>1 then direction=direction.Unit end
   actor.position=Physics.move(scene,actor.position,direction*(Config.PlayerSpeed/60),actor.radius+0.5,colliders,actor.id)
   actor.ack=command[1];actor.credits-=1
  end
  if actor.character and actor.character.Parent then actor.character:PivotTo(CFrame.new(Space.toRobloxXYZ(actor.position.X,actor.position.Y,actor.position.Z))) end
 end))
 table.insert(connections,Players.PlayerAdded:Connect(registerPlayer))
 for _,player in Players:GetPlayers() do registerPlayer(player) end
 table.insert(connections,Players.PlayerRemoving:Connect(function(player)
  local a=playerActors[player];if a then actors[a.id]=nil end;playerActors[player]=nil;rates[player]=nil
 end))
 local accumulator,historyElapsed=0,0
 table.insert(connections,RunService.Heartbeat:Connect(function(dt:number)
  local scene=sceneNow();if scene==nil then return end
  -- Registered dynamic objects use explicit bounded spherical proxies.
  for _,a in actors do
   if a.kind==2 and (a.part==nil or a.part.Parent==nil or not Collection:HasTag(a.part,"CI_Interactive")) then actors[a.id]=nil
   elseif a.kind==2 and a.part and a.part.Parent then
    a.position=Physics.place(scene,fromWorld(a.part.Position),a.radius+0.5)
    a.part.Position=Space.toRobloxXYZ(a.position.X,a.position.Y,a.position.Z)
   elseif a.kind==1 and a.health<=0 and os.clock()-a.deadAt>10 then actors[a.id]=nil end
  end
  local tagged=Collection:GetTagged("CI_Interactive")
  for _,part in tagged do
   local count=0;for _ in actors do count+=1 end
   if not part:IsA("Part") or part.Shape~=Enum.PartType.Ball or count>=48 then continue end
   if part.Size.X<.2 or part.Size.X>16 or math.abs(part.Size.X-part.Size.Y)>.001 or math.abs(part.Size.X-part.Size.Z)>.001 then continue end
   local found=false;for _,a in actors do if a.part==part then found=true;break end end
   if not found and nextActor<999999 then
    if not part.Anchored then part:SetNetworkOwner(nil) end
    local radius=math.clamp(math.max(part.Size.X,part.Size.Y,part.Size.Z)/2,.1,8)
    actors[nextActor]={id=nextActor,kind=2,position=Physics.place(scene,fromWorld(part.Position),radius+.5),radius=radius,health=100,part=part,ack=0,credits=0,lastCredit=0,lastAttack=0,deadAt=0,consumed=false};nextActor+=1
   end
  end
  if not aliveLink() then return end
  accumulator=math.min(accumulator+dt,4/30)
  local colliders=actorList()
  while accumulator>=1/30 do
   accumulator-=1/30
   for id,b in bodies do
    if b.removed or quarantined[id] then b.velocity=Vector3.zero;continue end
    if os.clock()-b.lastIntent>1 then b.velocity=Vector3.zero;continue end
    local r=b.row
    local velocity=Physics.intent(b.velocity,{r[20],r[21],r[22]},r[19])
    local start=b.position
    for _,a in colliders do
     local delta=start-a.position;local clearance=a.radius+scene.bodyRadius+.001
     if delta.Magnitude<clearance then
      local away=if delta.Magnitude>.00001 then delta.Unit else Vector3.zAxis
      local candidate=Physics.move(scene,start,away*(clearance-delta.Magnitude),scene.bodyRadius,nil,nil)
      if Geometry.clear(scene,candidate.X,candidate.Y,candidate.Z) then start=candidate end
     end
    end
    b.position=Physics.move(scene,start,velocity,scene.bodyRadius,colliders,nil)
    b.velocity=b.position-start
    -- Neural feed willingness and a perceived external target authorize the local action.
    local target=actors[r[25]]
    if r[24]>=.5 and target~=nil and target.kind==1 and not target.consumed and os.clock()-b.lastBite>=Config.AgentBiteCooldown and (b.position-target.position).Magnitude<=target.radius+scene.bodyRadius+.5 and clearLine(scene,b.position,target.position,target.id) then
     b.lastBite=os.clock()
     if target.health>0 then
      target.health=math.max(0,target.health-Config.AgentBiteDamage)
      if target.character then local humanoid=target.character:FindFirstChildOfClass("Humanoid");if humanoid then humanoid.Health=target.health end end
      if target.health<=0 then target.deadAt=os.clock() end
     elseif queueEvent(2,id,target.id,Config.CorpseEnergy) then target.consumed=true end
    end
   end
  end
  historyElapsed+=dt
  if historyElapsed>=.05 then
   historyElapsed=0
   local positions:{[number]:Vector3}={};local players:{[number]:Vector3}={}
   for id,b in bodies do if not b.removed then positions[id]=b.position end end
   for id,a in actors do if a.kind==1 then players[id]=a.position end end
   table.insert(history,{time=Workspace:GetServerTimeNow(),positions=positions,players=players})
   if #history>10 then table.remove(history,1) end
  end
 end))
 task.spawn(function()
  local delay=1/math.clamp(Config.ExchangeHz,1,6)
  local pendingRequest:any=nil
  while started do
   local began=os.clock()
   if pendingRequest==nil then pendingRequest=requestBody() end
   local request=pendingRequest
   local ok,err=pcall(function()
    local encoded=Http:JSONEncode(request);requestBytes=#encoded
    assert(requestBytes<=3*1024*1024,"Request budget exceeded")
    local result=Http:RequestAsync({Url=transport.Url,Method="POST",Headers={["Content-Type"]="application/json",["X-CI-Token"]=transport.Token},Body=encoded})
    roundTripMs=(os.clock()-began)*1000;Workspace:SetAttribute("CI_HttpRoundTripMs",roundTripMs);responseBytes=#result.Body
    assert(result.Success,"Relay HTTP "..tostring(result.StatusCode)..": "..string.sub(result.Body,1,160))
    assert(#result.Body<=12*1024*1024,"Response budget")
    local response=Http:JSONDecode(result.Body)
    Workspace:SetAttribute("CI_CppInputAgeMs",response.cppInputAgeMs)
    Workspace:SetAttribute("CI_LiveEventError",response.eventError)
    Workspace:SetAttribute("CI_RelayDiskMs",if response.relayTimingMs then response.relayTimingMs[2] else 0)
    accept(response)
    if response.plants then PlantTransport.deliver(response.plants) end
    if response.plantError then Workspace:SetAttribute("CI_PlantStatus",response.plantError) end
    Workspace:SetAttribute("CI_RelayComputeMs",if response.relayTimingMs then response.relayTimingMs[3] else 0)
    if response.reset~=true and response.resync~=true then for _,pose in request.poses do if not quarantined[pose[1]] then lastSent[pose[1]]=pose end end end
    pendingRequest=nil
   end)
   if not ok then batch+=1;pendingRequest=nil;state="Reconnecting";Workspace:SetAttribute("CI_LiveError",tostring(err));delay=math.min(2,delay*1.5) else Workspace:SetAttribute("CI_LiveError",nil);delay=1/math.clamp(Config.ExchangeHz,1,6) end
   Workspace:SetAttribute("CI_LiveStatus",state)
   Workspace:SetAttribute("CI_LastExchangeAge",os.clock()-lastSuccess)
   task.wait(math.max(.01,delay-(os.clock()-began)))
  end
 end)
 game:BindToClose(function()started=false;for _,c in connections do c:Disconnect() end end)
end
return M
