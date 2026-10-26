--!strict
-- Independent axes. Never derive biological death from presentation/transport.
local M={}
function M.connection(expectedRun:string,currentRun:string,contactAge:number,snapshotAge:number):string
 if expectedRun~=currentRun then return "run changed" end
 if contactAge>10 then return "disconnected" end
 if contactAge>3 or snapshotAge>3 then return "stale" end
 return "fresh"
end
function M.biological(value:any):string
 if value=="alive" or value=="confirmed dead" then return value end
 return "unknown"
end
function M.display(hasRig:boolean,missingTerrain:boolean,budgetOmitted:boolean,patchDelivered:boolean,sampleDelivered:boolean):string
 if missingTerrain then return "missing terrain" end
 if hasRig then return "rendered" end
 if budgetOmitted then return "omitted by display budget" end
 if sampleDelivered then return "awaiting render" end
 if patchDelivered then return "omitted by native display sample" end
 return "outside delivered observer interest"
end
return table.freeze(M)
