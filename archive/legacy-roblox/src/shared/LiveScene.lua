--!strict
local Schema = require(script.Parent.RecordingSchema)
local changed = Instance.new("BindableEvent")
local current: Schema.Manifest? = nil
local M = {Changed=changed.Event}
function M.set(manifest: Schema.Manifest)
 require(script.Parent.SimulationSpace).configure(manifest.bounds)
 current = manifest
 changed:Fire(manifest)
end
function M.get(): Schema.Manifest? return current end
function M.await(): Schema.Manifest
 while current == nil do changed.Event:Wait() end
 return current :: Schema.Manifest
end
return M
