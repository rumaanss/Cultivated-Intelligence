--!strict
local Schema = require(script.Parent.RecordingSchema)
type Frame = Schema.Frame
type Row = Schema.Row
local M = {}
-- Only positions interpolate. Energy/age/light inspection comes from a recorded
-- frame. Membership changes at the next complete snapshot, never early.
function M.bracket(ticks: {number}, tick: number): (number, number, number)
 local low, high = 1, #ticks
 assert(high > 0,"No frames")
 while low < high do
  local middle = math.ceil((low+high)/2)
  if ticks[middle] <= tick then low = middle else high = middle-1 end
 end
 local right = math.min(low+1,#ticks)
 local span = ticks[right]-ticks[low]
 return low,right,if span > 0 then math.clamp((tick-ticks[low])/span,0,1) else 0
end
function M.index(frame: Frame): {[number]: Row}
 local result: {[number]: Row} = {}
 for _, row in frame.agents do result[row[1]] = row end
 return result
end
function M.position(row: Row, nextRow: Row?, alpha: number): (number, number, number)
 if nextRow == nil then return row[3],row[4],row[5] end
 return row[3]+(nextRow[3]-row[3])*alpha,
  row[4]+(nextRow[4]-row[4])*alpha,
  row[5]+(nextRow[5]-row[5])*alpha
end
return M
