--!strict
-- Bounded live presentation and local input prediction; server confirms all outcomes.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local InputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local Shared=RS:WaitForChild("Shared")
local Config=require(Shared.LiveConfig)
if not Config.Enabled then return end
local Protocol=require(Shared.LiveProtocol)
local Interpolation=require(Shared.LiveInterpolation)
local Picking=require(Shared.LivePicking)
local Physics=require(Shared.LivePhysics)
local Geometry=require(Shared.SharedGeometry)
local Presentation=require(Shared.GeometryPresentation)
local Scene=require(Shared.LiveScene)
local Space=require(Shared.SimulationSpace)
local player=Players.LocalPlayer
assert(player~=nil,"Live viewer requires a player")
local mouse=player:GetMouse()
local gui=Instance.new("ScreenGui");gui.Name="CI_LiveStatus";gui.ResetOnSpawn=false;gui.Parent=player:WaitForChild("PlayerGui")
local label=Instance.new("TextLabel");label.Size=UDim2.fromOffset(480,120);label.Position=UDim2.fromOffset(12,82);label.BackgroundColor3=Color3.fromRGB(13,27,36);label.BackgroundTransparency=.15;label.TextColor3=Color3.fromRGB(220,240,240);label.Font=Enum.Font.Code;label.TextSize=14;label.TextXAlignment=Enum.TextXAlignment.Left;label.TextYAlignment=Enum.TextYAlignment.Top;label.Text="LIVE · waiting for relay / C++";label.Parent=gui
local remotes=RS:WaitForChild("CI_Live",15)
if remotes==nil then label.Text="Live server unavailable. Check Output and start the relay.";return end
local fetch=remotes:WaitForChild("Fetch") :: RemoteFunction
local input=remotes:WaitForChild("Input") :: RemoteEvent
local root=Instance.new("Folder");root.Name="CI_LivePresentation";root.Parent=Workspace
local scene:Geometry.Scene?=nil
local run=""
local transportBoot=""
local status="Waiting"
local running=true
local received=0
local selected=0
local selection=Instance.new("SelectionBox")
selection.Name="CI_SelectedLiveAgent";selection.LineThickness=.025
selection.Color3=Color3.fromRGB(245,231,133);selection.SurfaceTransparency=1
selection.Parent=gui
local combat=false
local actorId=0
local health=0
local predicted=Vector3.zero
local commandSeq=0
local pending:{{number}}={}
local colliders:{Physics.Actor}={}
local accumulator,sendElapsed=0,0
local lastAttack=0
local feedbackUntil=0
local snapshotTime=0
local links:{RBXScriptConnection}={}
type Display={part:Part,track:Interpolation.Track,to:Vector3}
local display:{[number]:Display}={}
local colors={Color3.fromRGB(81,184,119),Color3.fromRGB(220,181,82),Color3.fromRGB(211,108,95)}
local function world(p:Vector3):Vector3 return Space.toRobloxXYZ(p.X,p.Y,p.Z) end
local function simulation(p:Vector3):Vector3 local q=Space.toSimulation(p);return Vector3.new(q.x,q.y,q.z) end
local function fresh():boolean return status=="Live" and os.clock()-received<Config.StaleSeconds end
local function control(enabled:boolean)
 combat=enabled;Workspace:SetAttribute("CI_LiveCombat",enabled)
 -- Research camera releases ownership on its next render callback.
 task.defer(function()
  task.wait()
  if not combat then return end
  local camera=Workspace.CurrentCamera
  local character=player.Character
  local humanoid=if character then character:FindFirstChildOfClass("Humanoid") else nil
  if camera and humanoid then camera.CameraType=Enum.CameraType.Custom;camera.CameraSubject=humanoid end
 end)
end
local function accept(response:any)
 assert(type(response)=="table","No live frame")
 status=response.state or "Waiting"
 if response.run==nil then return end
 if response.run~=run or (response.boot or "")~=transportBoot then
  local manifest=Protocol.manifest(response.manifest)
  local geometry=manifest.geometry;assert(geometry~=nil,"Missing live scene")
  for _,d in display do d.part:Destroy() end;display={}
  root:ClearAllChildren()
  selected=0;selection.Adornee=nil
  scene=geometry;run=manifest.runId;transportBoot=response.boot or "";pending={};commandSeq=0;actorId=0
  Presentation.create(geometry,root,false)
  Scene.set(manifest)
  Workspace:SetAttribute("CI_PlaybackMode","Live")
  Workspace:SetAttribute("CI_CycleTicks",manifest.cycleTicks)
  Workspace:SetAttribute("CI_Moonlight",manifest.moonlight)
 end
 local active=scene;assert(active~=nil,"Missing scene")
 local rows=Protocol.unpack(response.buffer,active)
 local seen:{[number]:boolean}={}
 local now=os.clock()
 for _,row in rows do
  local id=row[1];seen[id]=true
  local position=Vector3.new(row[3],row[4],row[5])
  local d=display[id]
  if d==nil then
   local part=Instance.new("Part");part.Name="LiveAgent";part.Shape=Enum.PartType.Ball;part.Size=Vector3.one*(active.bodyRadius*2);part.Material=Enum.Material.SmoothPlastic;part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CastShadow=false;part.Color=colors[row[2]+1];part:SetAttribute("CI_AgentId",id);part:SetAttribute("CI_SpeciesId",row[2]);part.Position=world(position);part.Parent=root
   d={part=part,track=Interpolation.new(),to=position};display[id]=d
  else d.to=position end
  d.part:SetAttribute("CI_SpeciesId",row[2])
  Interpolation.push(d.track,response.serverTime,position,if response.warps then response.warps[tostring(id)] else 0)
 end
 if response.full then for id,d in display do if not seen[id] then d.part:Destroy();display[id]=nil end end end
 -- Partial near updates can add new births before the next full membership frame.
 local count=0;for id,d in display do count+=1;if count>Config.MaximumVisibleOrganisms+64 then d.part:Destroy();display[id]=nil end end
 colliders=response.actors or {}
 local actor=response.player
 if actor~=nil then
  if actorId~=actor[1] then actorId=actor[1];pending={};commandSeq=actor[5] end
  health=actor[6]
  local retained:{{number}}={}
  for _,command in pending do if command[1]>actor[5] then table.insert(retained,command) end end
  pending=retained;predicted=Vector3.new(actor[2],actor[3],actor[4])
  for _,command in pending do predicted=Physics.move(active,predicted,Vector3.new(command[2],command[3],command[4])*(Config.PlayerSpeed/60),Config.PlayerRadius+.5,colliders,actorId) end
 end
 received=now;snapshotTime=response.serverTime
 Workspace:SetAttribute("CI_WorldTick",response.tick)
 Workspace:SetAttribute("CI_PresentationDaylight",response.light[1])
 Workspace:SetAttribute("CI_PresentationAmbient",response.light[3])
 selection.Adornee=if display[selected] then display[selected].part else nil
 local details="Click an agent to inspect. F7: swim / research camera"
 if selected>0 and response.inspected==nil then details="Selected agent "..selected.." · awaiting details / no longer available" end
 if response.inspected then local row=response.inspected;details=string.format("Agent %d · energy %.1f · health %.1f\nSensor %.3f · photosynthesis %.3f",row[1],row[9],row[18],row[15],row[16]) end
 local diagnostics=response.diagnostics or {0,0,0,0}
 label.Text=string.format("%s · tick %d · visible %d / %d\n%s\nWASD swim · Space/Ctrl depth · LMB strike · HP %.0f",tostring(status),tonumber(response.tick) or 0,count,tonumber(response.total) or 0,tostring(details),tonumber(health) or 0)..string.format("\nHTTP RTT %.0f ms · relay work %.1f ms\n%.1f/%.1f KiB · pending %d",tonumber(diagnostics[1]) or 0,tonumber(diagnostics[5]) or 0,(tonumber(diagnostics[2]) or 0)/1024,(tonumber(diagnostics[3]) or 0)/1024,tonumber(diagnostics[4]) or 0)
end
local function direction():Vector3
 if not combat or InputService:GetFocusedTextBox()~=nil then return Vector3.zero end
 local camera=Workspace.CurrentCamera;if camera==nil then return Vector3.zero end
 local function key(k:Enum.KeyCode):number return if InputService:IsKeyDown(k) then 1 else 0 end
 local forward=camera.CFrame.LookVector;forward=Vector3.new(forward.X,0,forward.Z)
 if forward.Magnitude>.001 then forward=forward.Unit end
 local right=camera.CFrame.RightVector;right=Vector3.new(right.X,0,right.Z)
 if right.Magnitude>.001 then right=right.Unit end
 local d=forward*(key(Enum.KeyCode.W)-key(Enum.KeyCode.S))+right*(key(Enum.KeyCode.D)-key(Enum.KeyCode.A))+Vector3.yAxis*(key(Enum.KeyCode.Space)-key(Enum.KeyCode.LeftControl))
 if d.Magnitude>1 then d=d.Unit end
 return Vector3.new(d.X,d.Z,d.Y)
end
table.insert(links,InputService.InputBegan:Connect(function(event:InputObject,processed:boolean)
 if processed then return end
 if event.KeyCode==Enum.KeyCode.F7 then control(not combat);return end
 if event.UserInputType~=Enum.UserInputType.MouseButton1 then return end
 local camera=Workspace.CurrentCamera
 local active=scene
 if not camera or not active then return end
 local candidates:{Picking.Candidate}={}
 for id,d in display do
  table.insert(candidates,{id=id,position=d.part.Position,radius=d.part.Size.X*.5})
 end
 local ray=mouse.UnitRay
 local origin=simulation(ray.Origin)
 local id=Picking.choose(ray.Origin,ray.Direction,candidates,
  24*math.tan(math.rad(camera.FieldOfView)*.5)/math.max(camera.ViewportSize.Y,1),
  function(position:Vector3):boolean
   local target=simulation(position)
   return not Geometry.blocked(active,{origin.X,origin.Y,origin.Z},{target.X,target.Y,target.Z},0,false)
  end)
 if id then selected=id;selection.Adornee=display[id].part end
 if combat and fresh() and health>0 and selected>0 and os.clock()-lastAttack>=Config.AttackCooldown then
  lastAttack=os.clock();feedbackUntil=lastAttack+.1 -- Cosmetic anticipation, never confirmed damage.
  input:FireServer("attack",if type(id)=="number" then id else selected,math.min(snapshotTime,Workspace:GetServerTimeNow()-(if display[selected] then Interpolation.delay(display[selected].track) else .12)))
 end
end))
RunService:BindToRenderStep("CI.Live",Enum.RenderPriority.Camera.Value-1,function(dt:number)
 local active=scene;if active==nil then return end
 local now=os.clock()
 for _,d in display do
  local position=Interpolation.sample(d.track,Workspace:GetServerTimeNow()-Interpolation.delay(d.track)) or d.to
  -- Interpolation must not cut across a rock between valid endpoints.
  if Geometry.clear(active,position.X,position.Y,position.Z) and not Geometry.blocked(active,{d.to.X,d.to.Y,d.to.Z},{position.X,position.Y,position.Z},active.bodyRadius,false) then d.part.Position=world(position) else d.part.Position=world(d.to) end
 end
 label.BackgroundColor3=if now<feedbackUntil then Color3.fromRGB(65,65,45) else Color3.fromRGB(13,27,36)
 if not fresh() then accumulator=0;return end
 if health>0 and actorId>0 then
  accumulator=math.min(accumulator+dt,4/60)
  while accumulator>=1/60 do
   accumulator-=1/60
   -- Idle commands keep sequence/time continuity. Bounded queue prevents unbounded prediction.
   if #pending>=120 then break end
   local d=direction();commandSeq+=1
   table.insert(pending,{commandSeq,d.X,d.Y,d.Z})
   predicted=Physics.move(active,predicted,d*(Config.PlayerSpeed/60),Config.PlayerRadius+.5,colliders,actorId)
  end
  if combat then local character=player.Character;if character then character:PivotTo(CFrame.new(world(predicted))) end end
  sendElapsed+=dt
  if sendElapsed>=1/20 and #pending>0 then
   sendElapsed=0;local commands:{{number}}={}
   -- Resend the oldest unacknowledged window; server ignores duplicates.
   for i=1,math.min(#pending,16) do table.insert(commands,pending[i]) end
   input:FireServer("move",commands)
  end
 end
end)
task.spawn(function()
 while running do
  local began=os.clock()
  local camera=Workspace.CurrentCamera
  local ok,err=pcall(function()accept(fetch:InvokeServer(run..":"..transportBoot,selected,if camera then simulation(camera.CFrame.Position) else nil))end)
  if not ok then status="Reconnecting";label.Text="LIVE paused: "..string.sub(tostring(err),1,180) end
  task.wait(math.max(.01,1/Config.ClientSnapshotHz-(os.clock()-began)))
 end
end)
table.insert(links,script.Destroying:Connect(function()
 running=false;control(false);RunService:UnbindFromRenderStep("CI.Live")
 for _,connection in links do connection:Disconnect() end
 root:Destroy();gui:Destroy()
end))
