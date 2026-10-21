--!strict
local A={}
function A.sensitivity(value: number, delta: number, low: number, high: number): number
 return math.clamp(value+delta,low,high)
end
function A.filter(dx: number,dy: number,gain: number,maximumAngle: number): (number,number,boolean)
 if dx~=dx or dy~=dy or math.abs(dx)==math.huge or math.abs(dy)==math.huge then return 0,0,true end
 local length=math.sqrt(dx*dx+dy*dy)
 local maximumPixels=maximumAngle/gain
 if length>maximumPixels then
  local scale=maximumPixels/length
  return dx*scale,dy*scale,true
 end
 return dx,dy,false
end
return table.freeze(A)
