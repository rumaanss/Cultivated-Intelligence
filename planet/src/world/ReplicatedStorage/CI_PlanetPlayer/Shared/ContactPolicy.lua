--!strict
-- Pure classification. Long diagnostic rays never extend the physical support envelope.
local P={}
function P.classify(distance: number?, foot: number, normalDot: number, water: boolean,
 detach: boolean, relativeUp: number, wasGrounded: boolean, enter: number, leave: number, slopeCos: number): (boolean,string)
 if detach then return false,"jump-detach" end
 if distance==nil then return false,"no-hit" end
 if water then return false,"water" end
 if normalDot<slopeCos then return false,"steep" end
 local allowance=if wasGrounded then leave else enter
 if distance>foot+allowance then return false,"out-of-reach" end
 if relativeUp>6 then return false,"ascending" end
 return true,"supported"
end
return table.freeze(P)
