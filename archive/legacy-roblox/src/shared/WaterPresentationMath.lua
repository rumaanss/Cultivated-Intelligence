--!strict
local M = {}
-- Central resolution is preserved; only the outer scenery gets larger cells.
function M.coordinate(index: number, centralCells: number, outerCells: number, width: number, padding: number): number
 if index < outerCells then return -width/2 - padding * (outerCells-index)/outerCells end
 if index > outerCells+centralCells then return width/2 + padding * (index-outerCells-centralCells)/outerCells end
 return -width/2 + width*(index-outerCells)/centralCells
end
-- Smooth envelope and its derivative. Waves flatten at the distant perimeter.
function M.envelope(x: number, width: number, padding: number): (number, number)
 local outside = math.abs(x)-width/2
 if outside <= 0 then return 1,0 end
 if outside >= padding then return 0,0 end
 local u=outside/padding
 return 1-u*u*(3-2*u), -6*u*(1-u)/padding*(if x<0 then -1 else 1)
end
function M.adapt(current: number, target: number, dt: number, seconds: number): number
 return current+(target-current)*(1-math.exp(-math.max(dt,0)/seconds))
end
return table.freeze(M)
