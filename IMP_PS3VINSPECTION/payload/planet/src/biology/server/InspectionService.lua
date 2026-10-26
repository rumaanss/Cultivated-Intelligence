--!nonstrict
-- One server samples the complete Terrain + explicitly registered optical scene.
-- Player cameras, avatars, client organism LOD and cosmetic grading are excluded.
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local Players=game:GetService("Players")
local Collection=game:GetService("CollectionService")
local Shared=RS:WaitForChild("CI_Biology")
local Space=require(Shared.SimulationSpace)
local Contract=require(Shared.PlanetContract)
local M={}
local started=false
local f=Contract.habitat.frame
local east,north,up=Vector3.new(table.unpack(f.east)),Vector3.new(table.unpack(f.north)),Vector3.new(table.unpack(f.up))
local center=Vector3.new(table.unpack(f.center))
local function vec(p)return Vector3.new(p[1],p[2],p[3])end
local function array(p)return {p.X,p.Y,p.Z}end
local function world(p)return Space.toRobloxXYZ(p[1],p[2],p[3])end
local function sim(p)local q=Space.toSimulation(p);return q and Vector3.new(q.x,q.y,q.z)end
local host=Http:GenerateGUID(false)
local run,boot="",""
local config,event,telemetry
local selections={}
local sceneRevision=0
local registered={}
local function bump()sceneRevision+=1 end
local function register(p)
 if not p:IsA("BasePart") or registered[p] then return end
 local con={p:GetPropertyChangedSignal("CFrame"):Connect(bump),p:GetPropertyChangedSignal("Size"):Connect(bump),p:GetPropertyChangedSignal("CanQuery"):Connect(bump),p:GetAttributeChangedSignal("CI_OpticalTransmission"):Connect(bump)}
 registered[p]=con;bump()
end
local function unregister(p)
 if registered[p]then for _,c in registered[p]do c:Disconnect()end;registered[p]=nil;bump()end
end
local function queryParams(extra)
 local list={workspace.Terrain}
 for p in registered do if p:IsDescendantOf(workspace)then
  local transmission=p:GetAttribute("CI_OpticalTransmission")
  assert(p.CanQuery and type(transmission)=="number" and transmission==transmission and transmission>=0 and transmission<=1,"Every registered surface must be queryable and declare transmission")
  table.insert(list,p);assert(#list<=129,"Registered optical scene budget exceeded")
 end end
 if extra then for _,p in extra do table.insert(list,p)end end
 local p=RaycastParams.new();p.FilterType=Enum.RaycastFilterType.Include;p.FilterDescendantsInstances=list;p.IgnoreWater=true
 return p,list
end
local function transmission(origin,direction)
 local params,list=queryParams();local result=1
 -- Transmission is specified once per registered solid; no invented relation
 -- between Roblox Transparency/Color and biological photons.
 for _=1,8 do
  local hit=workspace:Raycast(origin,direction,params)
  if not hit then return result end
  if hit.Instance==workspace.Terrain then return 0 end
  local t=hit.Instance:GetAttribute("CI_OpticalTransmission")
  assert(type(t)=="number" and t==t and t>=0 and t<=1,"Registered surface needs CI_OpticalTransmission in [0,1]")
  assert(hit.Instance.CanQuery,"Registered surface must be queryable")
  result*=t;if result==0 then return 0 end
  local remaining={};for _,p in list do if p~=hit.Instance then table.insert(remaining,p)end end
  list=remaining;params.FilterDescendantsInstances=list
 end
 error("Optical layer budget exceeded; refusing incomplete sample")
end
local function post(route,payload)
 local response=Http:RequestAsync({Url=string.gsub(config.Url,"/exchange$",route),Method="POST",Headers={["Content-Type"]="application/json",["X-CI-Token"]=config.Token},Body=Http:JSONEncode(payload)})
 assert(response.Success,"Native "..route..": "..tostring(response.StatusCode).." "..string.sub(response.Body,1,180))
 return Http:JSONDecode(response.Body)
end
local function envelope()return {schema=1,run=run,boot=boot,host=host}end
local function geometryProbe(pending)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={workspace.Terrain};params.IgnoreWater=true
 local errors,missing,maxRoundTrip={},0,0
 -- All occupied columns, including near-shore columns. Separate from shading.
 for _,p in pending.points do
  local origin=world({p[2],p[3],130});local down=world({p[2],p[3],-10})-origin
  local hit=workspace:Raycast(origin,down,params)
  if hit then
   local q=sim(hit.Position);table.insert(errors,math.abs(q.Z-p[5]))
  else missing+=1 end
  local q=sim(world({p[2],p[3],p[5]}));maxRoundTrip=math.max(maxRoundTrip,(q-Vector3.new(p[2],p[3],p[5])).Magnitude)
 end
 table.sort(errors)
 return {scope="occupied-column radial heights",count=#pending.points,missing=missing,maxStuds=errors[#errors] or 0,p95Studs=errors[math.max(1,math.ceil(#errors*.95))] or 0,roundTripStuds=maxRoundTrip,
  heightToleranceStuds=.25,roundTripToleranceStuds=.01,passed=missing==0 and (errors[#errors] or math.huge)<=.25 and maxRoundTrip<=.01,
  precision="finite probes; does not certify every edge or curve"}
end
local geometry=nil
local function sample(pending)
 assert(pending.habitat==Contract.habitat.sha256 and pending.optics=="surface-par-1","Scene contract mismatch")
 local before=sceneRevision;local terrainRevision=workspace:GetAttribute("CI_TerrainRevision") or "contract-baseline"
 local sun=east*pending.sunChart[1]+north*pending.sunChart[2]+up*pending.sunChart[3]
 local visibility={};local began=os.clock()
 for _,p in pending.points do
  table.insert(visibility,if pending.surfacePar==0 then 1 else transmission(world({p[2],p[3],p[4]}),sun.Unit*pending.maxRayStuds))
 end
 if not geometry or pending.request%20==1 then geometry=geometryProbe(pending)end
 assert(before==sceneRevision and terrainRevision==(workspace:GetAttribute("CI_TerrainRevision") or "contract-baseline"),"Scene changed during batch; resample")
 local result={schema=1,run=run,boot=boot,request=pending.request,tick=pending.tick,habitat=pending.habitat,optics=pending.optics,
  scene=host..":"..sceneRevision..":"..tostring(terrainRevision),visibility=visibility,geometry=geometry}
 telemetry:SetAttribute("SceneSampleMs",(os.clock()-began)*1000)
 telemetry:SetAttribute("SceneSampleRays",#visibility)
 telemetry:SetAttribute("GeometryMaxErrorStuds",geometry.maxStuds)
 telemetry:SetAttribute("GeometryAgreement",geometry.passed and "Within provisional tolerance" or "Mismatch: inspect calibration report")
 return result
end
local function retina(request)
 local origin=world(request.position);local params=queryParams();local depths={}
 local radial=(origin-center).Unit;local lateral=(east-radial*east:Dot(radial)).Unit;local forward=radial:Cross(lateral)
 for i=0,15 do
  local angle=2*math.pi*i/16;local direction=(lateral*math.cos(angle)+forward*math.sin(angle))*request.rangeStuds
  local hit=workspace:Raycast(origin,direction,params)
  table.insert(depths,hit and hit.Distance or request.rangeStuds)
 end
 return {id=request.id,tick=request.tick,position=request.position,modality=request.modality,depthStuds=depths,scope=request.scope,scene=host..":"..sceneRevision}
end
function M.Start()
 if started then return end;started=true
 config=require(game:GetService("ServerScriptService"):WaitForChild("CI_Integration"):WaitForChild("LiveTransportConfig"))
 telemetry=Instance.new("Folder");telemetry.Name="CI_InspectionStatus";telemetry.Parent=RS
 event=Instance.new("RemoteEvent");event.Name="CI_Inspection";event.Parent=RS
 for _,p in Collection:GetTagged("CI_SensorySurface")do register(p)end
 Collection:GetInstanceAddedSignal("CI_SensorySurface"):Connect(register)
 Collection:GetInstanceRemovedSignal("CI_SensorySurface"):Connect(unregister)
 local requestTimes={}
 event.OnServerEvent:Connect(function(player,q)
  if type(q)~="table" or type(q.id)~="number" or q.id%1~=0 or q.id<1 or q.id>2000000 then return end
  if os.clock()-(requestTimes[player] or -math.huge)<.2 then return end
  if q.run~=run then event:FireClient(player,{reset=true,run=run,boot=boot});return end
  local cursor=q.cursor or 0;if type(cursor)~="number" or cursor%1~=0 or cursor<0 or cursor>2000000 then return end
  requestTimes[player]=os.clock();selections[player]={id=q.id,cursor=cursor,at=os.clock()}
 end)
 Players.PlayerRemoving:Connect(function(p)selections[p]=nil;requestTimes[p]=nil end)
 task.spawn(function()
  local observation=nil
  while true do
   local began=os.clock()
   local ok,err=pcall(function()
    local q=envelope();q.observation=observation
    local s=post("/sensing",q)
    if s.reset then run,boot=s.run,s.boot;observation=nil;geometry=nil;return end
    observation=nil
    telemetry:SetAttribute("Run",run);telemetry:SetAttribute("Boot",boot);telemetry:SetAttribute("Tick",s.tick)
    telemetry:SetAttribute("Mode",s.mode);telemetry:SetAttribute("Status",s.status);telemetry:SetAttribute("LastContact",workspace:GetServerTimeNow())
    if s.pending and not s.accepted then observation=sample(s.pending) end
   end)
   if not ok then observation=nil;telemetry:SetAttribute("Error",string.sub(tostring(err),1,400))else telemetry:SetAttribute("Error",nil)end
   task.wait(math.max(.05,.25-(os.clock()-began)))
  end
 end)
 task.spawn(function()
  while true do
   for player,selection in selections do
    if os.clock()-selection.at>5 then selections[player]=nil;continue end
    local ok,result=pcall(function()local q=envelope();q.id=selection.id;q.cursor=selection.cursor;q.limit=16;return post("/inspection",q)end)
    if ok then
     event:FireClient(player,result)
     if result.probeRequest then
      -- Diagnostic samples return to native storage, not directly to controllers.
      pcall(function()local q=envelope();q.probe=retina(result.probeRequest);post("/sensing",q)end)
     end
    else event:FireClient(player,{error=tostring(result),run=run,id=selection.id})end
   end
   task.wait(1)
  end
 end)
end
-- Studio diagnostics use the exact same query policy as the live photoreceptor.
M.transmission=transmission;M.geometryProbe=geometryProbe
return M
