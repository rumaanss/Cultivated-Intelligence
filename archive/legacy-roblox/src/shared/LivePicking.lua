--!strict
-- Click-only bounded geometric picking. Enlarges the click target, not the body.
local M={}
export type Candidate={id:number,position:Vector3,radius:number}
function M.choose(origin:Vector3,direction:Vector3,candidates:{Candidate},pixelSlope:number,visible:(Vector3)->boolean):number?
 if direction.Magnitude<.001 then return nil end
 local ray=direction.Unit
 local best:number?=nil;local bestScore=math.huge;local bestDepth=math.huge
 for _,candidate in candidates do
  local delta=candidate.position-origin
  local depth=delta:Dot(ray)
  if depth>0 then
   local radius=math.max(candidate.radius,depth*pixelSlope)
   local miss=(delta-ray*depth).Magnitude
   local score=miss/radius
   if score<=1 and (score<bestScore-.0001 or (math.abs(score-bestScore)<=.0001 and depth<bestDepth)) and visible(candidate.position) then
    best=candidate.id;bestScore=score;bestDepth=depth
   end
  end
 end
 return best
end
return M
