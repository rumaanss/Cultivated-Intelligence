--!nonstrict
return function()
-- strict
-- These modules are resolved dynamically in live folders and import packages.
local loadModule = require :: (ModuleScript) -> any
-- Independent plant channel using existing server-only relay credentials.
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local shared=RS:WaitForChild("CI_Biology")
local function module(name:string):any
 local value=shared:WaitForChild(name);assert(value:IsA("ModuleScript"));return loadModule(value)
end
local Config=module("PlantConfig");if not Config.Enabled then return end
local Protocol=module("PlantProtocol")
local parent=script.Parent;assert(parent~=nil)
local config=game:GetService("ServerScriptService"):WaitForChild("CI_Integration"):FindFirstChild("LiveTransportConfig")
if not config or not config:IsA("ModuleScript") then warn("[Plants] Server.LiveTransportConfig missing; run the relay setup and sync.");return end
local transport=loadModule(config)
assert(type(transport.Token)=="string" and #transport.Token>=32,"Plant transport token missing")
local url=string.gsub(transport.Url,"/exchange$","/plants")
assert(string.sub(url,1,8)=="https://" or (RunService:IsStudio() and string.match(url,"^http://localhost:%d+/plants$")~=nil),"Plants require HTTPS outside Studio")
assert(RS:FindFirstChild("CI_PlantChannel")==nil,"Duplicate plant server")
local remote=Instance.new("RemoteEvent");remote.Name="CI_PlantChannel";remote.Parent=RS
local state:any=nil
local serial=0
local lastRequest:{[Player]:number}={}
local function send(value:any,player:Player?)
 local encoded=Http:JSONEncode(value);assert(#encoded<=8*1024*1024,"Plant packet exceeds budget")
 serial+=1;local parts=math.ceil(#encoded/48000)
 for i=1,parts do
  local chunk=string.sub(encoded,(i-1)*48000+1,i*48000)
  if player then remote:FireClient(player,serial,i,parts,chunk) else remote:FireAllClients(serial,i,parts,chunk) end
 end
end
remote.OnServerEvent:Connect(function(player:Player)
 local now=os.clock();if now-(lastRequest[player] or -10)<2 then return end;lastRequest[player]=now
 if state then
  local rows={};for _,p in state.records do table.insert(rows,p) end
  send({schema=1,units="studs-Y-up",run=state.run,revision=state.revision,tick=state.tick,surface=state.surface,reset=true,base=0,upsert=rows,removed={},ledger=state.ledger,age=state.age},player)
 end
end)
Players.PlayerRemoving:Connect(function(player)lastRequest[player]=nil end)

local Bridge=module("PlantTransportBridge")
local chunks:{string}={}
local transferCount,transferBytes=0,0
local function applyPacket(packet:any)
 if packet.chunked==true then
  assert(type(packet.transfer)=="string" and #packet.transfer==64 and not string.find(packet.transfer,"[^a-f0-9]"),"Invalid plant transfer")
  assert(type(packet.index)=="number" and packet.index%1==0 and type(packet.count)=="number" and packet.count%1==0 and packet.count>=1 and packet.count<=32,"Invalid chunk counters")
  assert(type(packet.data)=="string" and #packet.data<=256*1024,"Invalid plant chunk")
  if packet.transfer~=Bridge.transfer then
   assert(packet.index==1,"Plant transfer must start at chunk one")
   table.clear(chunks);transferBytes=0;transferCount=packet.count
   Bridge.transfer=packet.transfer;Bridge.nextChunk=1
  end
  assert(packet.count==transferCount,"Plant transfer changed size")
  if packet.index<Bridge.nextChunk then return end -- retry already accepted
  assert(packet.index==Bridge.nextChunk,"Plant chunk gap")
  transferBytes+=#packet.data;assert(transferBytes<=8*1024*1024,"Plant transfer budget")
  table.insert(chunks,packet.data);Bridge.nextChunk+=1
  if packet.index<packet.count then return end
  local decoded=Http:JSONDecode(table.concat(chunks))
  decoded.age=(decoded.age or 0)+(packet.age or 0)
  packet=decoded
  table.clear(chunks);Bridge.transfer="";Bridge.nextChunk=1
 end
 assert(packet.run==workspace:GetAttribute("CI_LiveRunId"),"Plant and microbe runs differ")
 local previousRevision=if state then state.revision else -1
 local updated,reason=Protocol.apply(state,packet)
 if not updated then state=nil;Bridge.run="";Bridge.revision=-1;error(reason) end
 state=updated;Bridge.run=state.run;Bridge.revision=state.revision
 table.clear(chunks);Bridge.transfer="";Bridge.nextChunk=1
 workspace:SetAttribute("CI_PlantTick",state.tick)
 workspace:SetAttribute("CI_IslandWorldTick",packet.worldTick)
 workspace:SetAttribute("CI_PlantStatus",if (state.age or 0)>10 then "Publisher stale" else "Connected")
 -- Even an empty delta advances the client's base revision.
 if packet.reset or state.revision~=previousRevision then send(packet,nil) end
end
if Config.CombinedExchange then
 local connection=Bridge.Changed:Connect(function(packet:any)
  local ok,err=pcall(applyPacket,packet)
  if not ok then table.clear(chunks);Bridge.transfer="";Bridge.nextChunk=1;workspace:SetAttribute("CI_PlantStatus",tostring(err)) end
 end)
 script.Destroying:Connect(function() connection:Disconnect() end)
else
 while script.Parent do
  local ok,err=pcall(function()
   local response=Http:RequestAsync({Url=url,Method="POST",Headers={["Content-Type"]="application/json",["X-CI-Token"]=transport.Token},Body=Http:JSONEncode({schema=1,run=Bridge.run,revision=Bridge.revision})})
   assert(response.Success,"Plant relay HTTP "..response.StatusCode)
   assert(#response.Body<=8*1024*1024,"Oversized response")
   applyPacket(Http:JSONDecode(response.Body))
  end)
  if not ok then table.clear(chunks);Bridge.transfer="";Bridge.nextChunk=1;workspace:SetAttribute("CI_PlantStatus",tostring(err)) end
  task.wait(Config.PollSeconds)
 end
end

end
