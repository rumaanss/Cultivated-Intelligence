--!strict
-- Offline recorded playback. Display markers are not physical organism bodies.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local Input = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
if require(Shared.LiveConfig).Enabled then return end
local Config = require(Shared.PlaybackConfig)
if not Config.Enabled then return end
local Schema = require(Shared.RecordingSchema)
local RecordingLoader = require(Shared.RecordingLoader)
local State = require(Shared.PlaybackState)
local Geometry = require(Shared.SharedGeometry)
local GeometryPresentation = require(Shared.GeometryPresentation)
local Space = require(Shared.SimulationSpace)
type RecordedFrame = Schema.Frame
type Row = Schema.Row
type Cached = {frame: RecordedFrame, byId: {[number]: Row}}
type Candidate = {row: Row, distance: number}
local player = Players.LocalPlayer
assert(player ~= nil,"Playback requires a LocalPlayer")
local gui = Instance.new("ScreenGui")
gui.Name,gui.ResetOnSpawn = "CI_RecordedPlayback",false
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.Size,panel.Position = UDim2.fromOffset(440,190),UDim2.fromOffset(12,82)
panel.BackgroundColor3,panel.BackgroundTransparency = Color3.fromRGB(13,27,36),0.12
panel.Parent = gui
local title = Instance.new("TextLabel")
title.Size,title.Position = UDim2.new(1,-16,0,72),UDim2.fromOffset(8,4)
title.BackgroundTransparency,title.TextSize = 1,14
title.Font,title.TextColor3 = Enum.Font.Code,Color3.fromRGB(218,234,242)
title.TextXAlignment,title.TextYAlignment = Enum.TextXAlignment.Left,Enum.TextYAlignment.Top
title.TextWrapped,title.Text = true,"RECORDED C++ PLAYBACK\nValidating data..."
title.Parent = panel
local function button(text: string, x: number, width: number): TextButton
 local b = Instance.new("TextButton")
 b.Text,b.Size,b.Position = text,UDim2.fromOffset(width,28),UDim2.fromOffset(x,78)
 b.BackgroundColor3,b.TextColor3 = Color3.fromRGB(35,61,74),Color3.fromRGB(238,245,249)
 b.TextSize,b.Font,b.Parent = 13,Enum.Font.Gotham,panel
 return b
end
local play,back,forward,restart = button("Play",8,70),button("< Frame",84,80),button("Frame >",170,80),button("Restart",256,70)
local idBox = Instance.new("TextBox")
idBox.Size,idBox.Position = UDim2.fromOffset(96,28),UDim2.fromOffset(332,78)
idBox.PlaceholderText,idBox.Text,idBox.TextSize = "Agent ID","",13
idBox.BackgroundColor3,idBox.TextColor3 = Color3.fromRGB(35,61,74),Color3.fromRGB(238,245,249)
idBox.ClearTextOnFocus,idBox.Parent = false,panel
local detail = title:Clone()
detail.Position,detail.Size,detail.Text = UDim2.fromOffset(8,112),UDim2.new(1,-16,0,74),"Click a marker or enter an ID to inspect recorded values."
detail.Parent = panel
local folder = Instance.new("Folder")
folder.Name,folder.Parent = "CI_RecordedOrganisms",Workspace
folder:SetAttribute("Source","RecordedC++")
folder:SetAttribute("PhysicalBodies",false)
local slots: {Part} = {}
local alive, failed = true,false
local connections: {RBXScriptConnection} = {}
local attributes = {"CI_PlaybackMode","CI_WorldTick","CI_CycleTicks","CI_Moonlight","CI_PresentationDaylight","CI_PresentationAmbient","CI_RecordedFrameTick"}
local old: {[string]: any} = {}
for _, name in attributes do old[name] = Workspace:GetAttribute(name) end
local function cleanup()
 if not alive then return end
 alive = false
 RunService:UnbindFromRenderStep("CI.RecordedPlayback")
 for _, connection in connections do connection:Disconnect() end
 for _, name in attributes do Workspace:SetAttribute(name,old[name]) end
 for _, part in slots do part:Destroy() end
 folder:Destroy(); gui:Destroy()
end
table.insert(connections,script.Destroying:Connect(cleanup))
table.insert(connections,script:GetPropertyChangedSignal("Enabled"):Connect(function() if not script.Enabled then cleanup() end end))
local function fail(message: string)
 failed = true
 title.Text = "RECORDING REJECTED\n"..message
 play.Text = "Unavailable"
 warn("[CI Playback] "..message)
end
local deadline = os.clock()+30
while alive and Workspace:GetAttribute("CI_RecordingStatus") ~= "Ready" do
 if Workspace:GetAttribute("CI_RecordingStatus") == "Failed" then fail(tostring(Workspace:GetAttribute("CI_RecordingError"))); return end
 if os.clock() >= deadline then fail("Server validation did not finish; check Output and the new ServerBootstrap."); return end
 task.wait(0.1)
end
if not alive then return end
local recording = Shared:FindFirstChild("Recording")
if recording == nil then fail("Shared.Recording is missing."); return end
local indexModule = recording:FindFirstChild("Index")
if indexModule == nil or not indexModule:IsA("ModuleScript") then fail("Recording.Index is missing."); return end
local okManifest, manifestOrError = pcall(function(): Schema.Manifest
 return Schema.validateManifest(HttpService:JSONDecode(RecordingLoader.read(indexModule, Schema.MaxIndexBytes)))
end)
if not okManifest then fail(tostring(manifestOrError)); return end
local manifest = manifestOrError :: Schema.Manifest
if manifest.runId ~= Workspace:GetAttribute("CI_RecordingRunId") then fail("Server/client recordings differ; stop Play and resync Rojo."); return end
local scene = manifest.geometry
if scene ~= nil then
 GeometryPresentation.create(scene,folder,Workspace:GetAttribute("CI_GeometryDebug") == true)
 folder:SetAttribute("GeometryRevision",scene.revision)
end
local interpolationBlocked: {[number]: boolean} = {}
local interpolationIndex = -1
local hasLake = scene ~= nil and scene.terrain ~= nil
local motionNote: string = if hasLake then "Lake foundation: shared slopes and grounded rocks." elseif scene ~= nil then "Shared body sizes; obstructed interpolation is held." else "Markers are enlarged; water motion remains decorative."
local ticks = manifest.frameTicks
local targetTick,tick = ticks[1],ticks[1]
local paused = Config.StartPaused
local selectedId: number? = nil
local cache: {[number]: Cached} = {}
local displayed: Cached? = nil
local rightDisplayed: Cached? = nil
local displayAlpha = 0
local displayedIndex = 0
local drawRows: {Row} = {}
local highlighted = Instance.new("Highlight")
highlighted.Name,highlighted.FillTransparency = "SelectedRecordedAgent",1
highlighted.OutlineColor = Color3.fromRGB(244,235,163)
highlighted.DepthMode,highlighted.Parent = Enum.HighlightDepthMode.Occluded,folder
local colors = {Color3.fromRGB(81,184,119),Color3.fromRGB(220,181,82),Color3.fromRGB(211,108,95)}
local function shortNumber(value: any): string
 local numeric = tonumber(value)
 if numeric == nil then return "?" end
 return string.format("%.4f",numeric)
end
local modelLabel: string = if hasLake then "Lake+Optics" elseif manifest.schemaVersion >= 2 then (if manifest.schemaVersion == 3 then "Geometry+Optics" else "OpticsV2") else "LegacyV1"
local names = {"Cyanobacteria","Bacterivore","Bodo saltans"}
local dirty, selectElapsed, renderElapsed, uiElapsed = true,0,0,0
local buffering = true
local function setTarget(value: number)
 targetTick = math.clamp(value,ticks[1],ticks[#ticks])
end
table.insert(connections,play.Activated:Connect(function() if not failed then paused = not paused end end))
table.insert(connections,back.Activated:Connect(function()
 paused = true
 local left = State.bracket(ticks,targetTick)
 setTarget(ticks[math.max(1,if targetTick > ticks[left] then left else left-1)])
end))
table.insert(connections,forward.Activated:Connect(function()
 paused = true; local left = State.bracket(ticks,targetTick); setTarget(ticks[math.min(#ticks,left+1)])
end))
table.insert(connections,restart.Activated:Connect(function() paused = true; setTarget(ticks[1]) end))
table.insert(connections,idBox.FocusLost:Connect(function(enter: boolean)
 if not enter then return end
 local id = tonumber(idBox.Text)
 if id ~= nil and id >= 1 and id%1 == 0 then selectedId = id; dirty = true end
end))
local mouse = player:GetMouse()
table.insert(connections,Input.InputBegan:Connect(function(input: InputObject, processed: boolean)
 if processed or Input:GetFocusedTextBox() ~= nil then return end
 if input.UserInputType == Enum.UserInputType.MouseButton1 then
  local part = mouse.Target
  if part ~= nil and part.Parent == folder then
   local id = part:GetAttribute("OrganismId")
   if type(id) == "number" then selectedId = id; idBox.Text = tostring(id); dirty = true end
  end
 end
end))
-- Decoding/loading stays out of the render callback. Retain only a small
-- current/lookahead cache; source strings have an 8 MiB import budget.
task.spawn(function()
 while alive and not failed do
  local left,right = State.bracket(ticks,targetTick)
  local wanted = {left,right,math.min(right+1,#ticks)}
  for _, index in wanted do
   if not alive then return end
   if cache[index] == nil then
    local ok, result = pcall(function(): Cached
     local module = recording:WaitForChild(string.format("Frame_%04d",index-1),10)
     assert(module ~= nil and module:IsA("ModuleScript"),"Missing frame module")
     local text = RecordingLoader.read(module, Schema.MaxFrameBytes)
     assert(type(text) == "string" and #text <= Schema.MaxFrameBytes,"Oversized frame")
     local frame = Schema.validateFrame(HttpService:JSONDecode(text),manifest,index)
     return {frame=frame,byId=State.index(frame)}
    end)
    if not alive then return end
    if not ok then fail(tostring(result)); return end
    cache[index] = result :: Cached
    task.wait()
   end
  end
  for index in cache do
   if index ~= left and index ~= right and index ~= wanted[3] and index ~= displayedIndex then cache[index] = nil end
  end
  task.wait(0.03)
 end
end)
local function chooseRows(current: Cached)
 local camera = Workspace.CurrentCamera
 if camera == nil then return end
 local origin = camera.CFrame.Position
 local candidates: {Candidate} = {}
 for _, row in current.frame.agents do
  local p = Space.toRobloxXYZ(row[3],row[4],row[5])
  local delta = p-origin
  table.insert(candidates,{row=row,distance=if row[1] == selectedId then -1 else delta:Dot(delta)})
 end
 table.sort(candidates,function(a: Candidate, b: Candidate): boolean
  if a.distance == b.distance then return a.row[1] < b.row[1] end
  return a.distance < b.distance
 end)
 table.clear(drawRows)
 for i = 1,math.min(Config.MaximumVisibleOrganisms,#candidates) do drawRows[i] = candidates[i].row end
end
local function update(dt: number)
 local activeScene = manifest.geometry
 if not alive or failed then return end
 if not paused and not buffering then setTarget(targetTick+math.min(dt,0.25)*Config.TicksPerSecond) end
 local left,right,alpha = State.bracket(ticks,targetTick)
 local current,nextFrame = cache[left],cache[right]
 buffering = current == nil or nextFrame == nil
 if current ~= nil and nextFrame ~= nil then
  tick,displayAlpha = targetTick,alpha
  if displayedIndex ~= left then dirty = true end
  displayed, rightDisplayed, displayedIndex = current,nextFrame,left
  Workspace:SetAttribute("CI_PlaybackMode","RecordedPlayback")
  Workspace:SetAttribute("CI_WorldTick",tick)
  Workspace:SetAttribute("CI_CycleTicks",manifest.cycleTicks)
  Workspace:SetAttribute("CI_Moonlight",manifest.moonlight)
  Workspace:SetAttribute("CI_RecordedFrameTick",current.frame.tick)
  Workspace:SetAttribute("CI_PresentationDaylight",current.frame.light[1]+(nextFrame.frame.light[1]-current.frame.light[1])*alpha)
  Workspace:SetAttribute("CI_PresentationAmbient",current.frame.light[3]+(nextFrame.frame.light[3]-current.frame.light[3])*alpha)
  if tick >= ticks[#ticks] then paused = true end
 end
 local a,b = displayed,rightDisplayed
 selectElapsed += dt; renderElapsed += dt; uiElapsed += dt
 if a ~= nil and b ~= nil then
  if dirty or selectElapsed >= 1/Config.SelectionUpdateHz then chooseRows(a); selectElapsed = 0; dirty = false end
  if renderElapsed >= 1/Config.RenderUpdateHz then
   renderElapsed = 0
   local creates = 0
   highlighted.Adornee = nil
   for i,row in drawRows do
    local part = slots[i]
    if part == nil then
     if creates >= 75 then break end -- Spread initial marker creation across frames.
     creates += 1
     part = Instance.new("Part")
     part.Name,part.Shape,part.Anchored = "RecordedAgent",Enum.PartType.Ball,true
     part.CanCollide,part.CanTouch,part.CanQuery,part.CastShadow = false,false,true,false
     part.Material,part.Size = Enum.Material.SmoothPlastic,Vector3.one*(2*(if activeScene ~= nil then activeScene.bodyRadius else Config.DisplayRadiusStuds))
     slots[i] = part
    end
    part.Parent,part.Color = folder,colors[row[2]+1]
    local nextRow = b.byId[row[1]]
    local alphaForBody = displayAlpha
    if activeScene ~= nil and nextRow ~= nil then
     if interpolationIndex ~= displayedIndex then table.clear(interpolationBlocked); interpolationIndex = displayedIndex end
     local blocked = interpolationBlocked[row[1]]
     if blocked == nil then
      blocked = Geometry.blocked(activeScene,{row[3],row[4],row[5]},{nextRow[3],nextRow[4],nextRow[5]},activeScene.bodyRadius,false)
      interpolationBlocked[row[1]] = blocked
     end
     if blocked then alphaForBody = 0 end -- No invented path through a wall between sparse samples.
    end
    local x,y,z = State.position(row,nextRow,alphaForBody)
    part:SetAttribute("InterpolationHeld",alphaForBody ~= displayAlpha)
    part.Position = Space.toRobloxXYZ(x,y,z)
    part:SetAttribute("OrganismId",row[1])
    part:SetAttribute("SpeciesId",row[2])
    part:SetAttribute("RecordedEnergy",row[9])
    part:SetAttribute("RecordedTick",a.frame.tick)
    if row[1] == selectedId then highlighted.Adornee = part end
   end
   for i = #drawRows+1,#slots do slots[i].Parent = nil end
  end
 end
 if uiElapsed >= 0.15 then
  uiElapsed = 0
  local count: number = 0
  if a ~= nil then count = a.frame.count end
  local statusText: string = "PLAYING"
  if buffering then statusText = "BUFFERING" elseif paused then statusText = "PAUSED" end
  local drawnCount: number = math.min(#slots,#drawRows)
  local playbackSpeed: number = Config.TicksPerSecond
  title.Text = string.format("RECORDED C++ / %s\nView tick %.2f | frame %d/%d | %d agents\nDrawing %d | %.0f ticks/s | " .. modelLabel,statusText,tick,displayedIndex,#ticks,count,drawnCount,playbackSpeed)
  play.Text = if paused then "Play" else "Pause"
  local selected = if a ~= nil and selectedId ~= nil then a.byId[selectedId] else nil
  if selected ~= nil and a ~= nil then
   local lightText: string = "global light " .. tostring(a.frame.light[3])
   if manifest.schemaVersion >= 2 then
    lightText = if selected[14] == -1 then "Optics: not sampled yet" else
     "Sensor(pre) " .. shortNumber(selected[15]) .. " | photo(post) " .. shortNumber(selected[16]) .. "\nPhoto energy gained " .. shortNumber(selected[17])
   end
   detail.Text = "ID " .. tostring(selected[1]) .. " • " .. tostring(names[selected[2]+1])
    .. " • recorded tick " .. tostring(a.frame.tick)
    .. "\nEnergy " .. shortNumber(selected[9]) .. " | age " .. tostring(selected[10]) .. " ticks"
    .. "\n" .. lightText
  elseif selectedId ~= nil then
   detail.Text = string.format("ID %d is absent from this complete frame.\nBirth/death timing is only known to snapshot resolution.",selectedId)
  elseif a ~= nil then
   detail.Text = string.format("Recorded tick %d | daylight %.4f | ambient %.4f\nClick a marker or enter an ID.\n" .. motionNote,a.frame.tick,a.frame.light[1],a.frame.light[3])
  end
 end
end
RunService:BindToRenderStep("CI.RecordedPlayback",Enum.RenderPriority.Camera.Value+1,update)

