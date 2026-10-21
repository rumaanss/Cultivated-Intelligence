--!strict
-- Server-context handoff: one HTTP exchange carries both biological channels.
local changed=Instance.new("BindableEvent")
local M:any={run="",revision=-1,transfer="",nextChunk=1,Changed=changed.Event}
function M.deliver(packet:any) changed:Fire(packet) end
return M
