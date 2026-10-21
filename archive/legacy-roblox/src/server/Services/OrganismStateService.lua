--!strict
-- Bounded offline data preflight. No physics and no live HTTP publisher.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.PlaybackConfig)
local Schema = require(Shared.RecordingSchema)
local RecordingLoader = require(Shared.RecordingLoader)
local Service = {}
local started = false
function Service.Start()
 if started then return end
 started = true
 if require(Shared.LiveConfig).Enabled then require(script.Parent.LiveStateService).Start(); return end
 if not Config.Enabled then Workspace:SetAttribute("CI_RecordingStatus","Disabled"); return end
 Workspace:SetAttribute("CI_RecordingStatus","Validating")
 task.spawn(function()
  local ok, err = pcall(function(): boolean
   local folder = Shared:FindFirstChild("Recording")
   assert(folder ~= nil,"Shared.Recording missing; run recording_to_rojo.py")
   local index = folder:FindFirstChild("Index")
   assert(index ~= nil and index:IsA("ModuleScript"),"Recording.Index missing")
   local text = RecordingLoader.read(index, Schema.MaxIndexBytes)
   assert(type(text) == "string" and #text <= Schema.MaxIndexBytes,"Invalid index size")
   local manifest = Schema.validateManifest(HttpService:JSONDecode(text))
   local bytes = #text
   local previous: {[number]: boolean} = {}
   local retired: {[number]: boolean} = {}
   local identities: {[number]: string} = {}
   for i = 1,manifest.frameCount do
    local module = folder:FindFirstChild(string.format("Frame_%04d",i-1))
    assert(module ~= nil and module:IsA("ModuleScript"),"Missing frame module")
    local frameText = RecordingLoader.read(module, Schema.MaxFrameBytes)
    assert(type(frameText) == "string" and #frameText <= Schema.MaxFrameBytes,"Oversized frame")
    bytes += #frameText
    assert(bytes <= Schema.MaxBytes,"Recording exceeds memory/import budget")
    local frame = Schema.validateFrame(HttpService:JSONDecode(frameText),manifest,i)
    local current: {[number]: boolean} = {}
    for _, row in frame.agents do
     local id = row[1]
     local identity = string.format("%d/%d/%d/%d",row[2],row[11],row[12],row[13])
     assert(not retired[id] and (identities[id] == nil or identities[id] == identity),"Reused/changed organism identity")
     identities[id],current[id] = identity,true
    end
    for id in previous do if not current[id] then retired[id] = true end end
    previous = current
    task.wait() -- Yield between frames; never block a whole recording in one frame.
   end
   Workspace:SetAttribute("CI_RecordingRunId",manifest.runId)
   Workspace:SetAttribute("CI_RecordingStatus","Ready")
   print(string.format("[CI Playback] Validated %d frames; source %s",manifest.frameCount,manifest.runId))
   return true
  end)
  if not ok then
   Workspace:SetAttribute("CI_RecordingError",tostring(err))
   Workspace:SetAttribute("CI_RecordingStatus","Failed")
   warn("[CI Playback] Recording rejected: "..tostring(err))
  end
 end)
end
return Service

