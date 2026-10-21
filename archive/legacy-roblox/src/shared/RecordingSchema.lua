--!strict
-- Data-only contract. No Lighting, RNG, biology, or engine objects.
local Geometry = require(script.Parent.SharedGeometry)
local M = {}
export type Row = {number}
export type Manifest = {
 schemaVersion: number, runId: string, seed: string, modelVersion: string,
 bounds: {number}, cycleTicks: number, moonlight: number, intervalTicks: number,
 frameTicks: {number}, frameCount: number, opticalModel: string,
 sourceSha256: string, stopReason: string,
 opticalParameters: {number}?, opticalStages: {string}?, geometry: Geometry.Scene?,
}
export type Frame = {
 runId: string, sequence: number, tick: number, complete: boolean,
 count: number, light: {number}, agents: {Row},
}
M.MaxIndexBytes = 64*1024
M.MaxFrames = 120
M.MaxAgents = 10000
M.MaxFrameBytes = 2*1024*1024
M.MaxBytes = 8*1024*1024
local columns = {"id","species","x","y","z","vx","vy","vz","energy","ageTicks","parentId","generation","birthTick"}
local function finite(v: any): boolean
 return type(v) == "number" and v == v and math.abs(v) < math.huge
end
local function integer(v: any, lo: number, hi: number): boolean
 return finite(v) and v >= lo and v <= hi and v%1 == 0
end
local function array(v: any, count: number): boolean
 if type(v) ~= "table" or #v ~= count then return false end
 local n = 0
 for k in pairs(v) do
  if not integer(k,1,count) then return false end
  n += 1
 end
 return n == count
end
function M.validateManifest(v: any): Manifest
 assert(type(v) == "table" and v.type == "header" and (v.schemaVersion == 1 or v.schemaVersion == 2 or v.schemaVersion == 3),"Unsupported recording schema")
 assert(type(v.runId) == "string" and #v.runId > 0 and #v.runId <= 100 and not string.find(v.runId,"[^%w_-]"),"Invalid run ID")
 assert(type(v.seed) == "string" and #v.seed > 0 and #v.seed <= 20 and not string.find(v.seed,"%D"),"Invalid seed")
 local seed = string.gsub(v.seed,"^0+","")
 assert(#seed < 20 or seed <= "18446744073709551615","Seed exceeds uint64")
 assert(type(v.modelVersion) == "string" and #v.modelVersion > 0 and #v.modelVersion <= 100,"Invalid model version")
 assert(array(v.bounds,3) and ((v.bounds[1] == 100 and v.bounds[2] == 100 and v.bounds[3] == 60) or (v.bounds[1] == 208 and v.bounds[2] == 176 and v.bounds[3] == 68)),"Unsupported basin bounds")
 assert(v.coordinates == "xyz-z-up" and v.positionUnit == "simulation-unit" and v.velocityUnit == "simulation-unit/tick","Unsupported spatial units")
 assert(v.energyUnit == "model-energy" and v.timeUnit == "tick" and v.sampleStage == "end-of-tick","Unsupported state units")
 local v2 = v.schemaVersion >= 2
 if v.schemaVersion == 3 then
  Geometry.validate(v.geometry)
  for i=1,3 do assert(v.bounds[i]==v.geometry.bounds[i],"Manifest/geometry bounds mismatch") end
 else assert(v.geometry == nil,"Unexpected geometry") end
 assert(v.opticalModel == (if v.schemaVersion == 3 then "normalized-flat-water-geometry-v3" elseif v2 then "normalized-flat-water-v2" else "legacy-linear-depth40-global-vision-v1"),"Unsupported optical model")
 if v2 then
  assert(array(v.opticalStages,3) and v.opticalStages[1] == "pre-movement" and v.opticalStages[2] == "post-movement" and v.opticalStages[3] == "actual-gain","Invalid optical phases")
  local p = v.opticalParameters
  assert(array(p,7),"Invalid optical parameters")
  for _, x in p do assert(finite(x),"Non-finite optical parameter") end
  for i = 1,3 do assert(p[i] >= 0 and p[i] <= 10,"Invalid extinction") end
  assert(p[4] >= 0 and p[4] <= 1 and p[5] >= 0 and p[5] <= 1 and p[6] > 1 and p[6] <= 2 and p[7] > 0 and p[7] <= 1,"Invalid optical parameters")
 end
 local expectedColumns = table.clone(columns)
 if v2 then
  for _, name in {"opticalTick","sensorLight","photosyntheticLight","photosyntheticEnergy"} do table.insert(expectedColumns,name) end
 end
 assert(array(v.agentColumns,#expectedColumns),"Invalid row layout")
 for i, name in expectedColumns do assert(v.agentColumns[i] == name,"Wrong column order") end
 assert(integer(v.cycleTicks,1,4294967295) and integer(v.intervalTicks,1,4294967295),"Invalid time settings")
 assert(finite(v.moonlight) and v.moonlight >= 0 and v.moonlight <= 1,"Invalid moonlight")
 assert(integer(v.frameCount,1,M.MaxFrames) and array(v.frameTicks,v.frameCount),"Invalid frame count")
 local last = -1
 for i, tick in v.frameTicks do
  assert(integer(tick,0,4294967295) and tick > last,"Non-increasing tick")
  if i > 1 then assert(tick-last == v.intervalTicks,"Wrong frame interval") end
  last = tick
 end
 assert(type(v.sourceSha256) == "string" and #v.sourceSha256 == 64 and not string.find(v.sourceSha256,"[^a-f0-9]"),"Missing source checksum")
 assert(v.stopReason == "completed" or v.stopReason == "frame-limit" or v.stopReason == "byte-limit" or v.stopReason == "population-limit" or v.stopReason == "frame-byte-limit","Invalid recording completion")
 return v :: Manifest
end
function M.validateFrame(v: any, manifest: Manifest, index: number): Frame
 assert(integer(index,1,manifest.frameCount),"Invalid frame index")
 assert(type(v) == "table" and v.type == "frame" and v.runId == manifest.runId,"Wrong run/frame")
 assert(v.complete == true and v.sequence == index-1 and v.tick == manifest.frameTicks[index],"Incomplete/out-of-order frame")
 assert(integer(v.count,0,M.MaxAgents) and array(v.agents,v.count),"Invalid population count")
 assert(array(v.light,3),"Invalid light sample")
 for _, value in v.light do assert(finite(value) and value >= 0 and value <= 1,"Non-finite light") end
 local day = math.max(0,math.sin(2*math.pi*(v.tick%manifest.cycleTicks)/manifest.cycleTicks))
 assert(math.abs(v.light[1]-day) < 0.00002 and math.abs(v.light[2]-manifest.moonlight) < 0.00002,"Light/tick mismatch")
 assert(math.abs(v.light[3]-(v.light[2]+(1-v.light[2])*v.light[1])) < 0.00002,"Ambient light mismatch")
 local previousId = 0
 for _, row in v.agents do
  assert(array(row,if manifest.schemaVersion >= 2 then 17 else 13),"Wrong row length")
  for _, value in row do assert(finite(value),"Non-finite agent state") end
  assert(integer(row[1],1,4294967295) and row[1] > previousId,"Duplicate/unsorted ID")
  previousId = row[1]
  assert(integer(row[2],0,2),"Unknown species")
  for i = 1,3 do assert(row[i+2] >= 0 and row[i+2] <= manifest.bounds[i],"Position outside basin") end
  assert(row[9] >= 0,"Negative energy")
  for i = 10,13 do assert(integer(row[i],0,4294967295),"Invalid age/lineage") end
  assert(row[13] <= v.tick,"Birth is in the future")
  if manifest.geometry ~= nil then assert(Geometry.clear(manifest.geometry,row[3],row[4],row[5]),"Recorded body intersects geometry") end
  if manifest.schemaVersion >= 2 then
   assert(integer(row[14],-1,4294967295) and (row[14] == -1 or row[14] == v.tick),"Stale optical sample")
   assert(row[15] >= 0 and row[15] <= 1 and row[16] >= 0 and row[16] <= 1 and row[17] >= 0,"Invalid optical sample")
   assert(row[14] ~= -1 or (row[15] == 0 and row[16] == 0 and row[17] == 0),"Unsampled agent has optical data")
   assert(row[2] == 0 or row[17] == 0,"Non-producer gained photosynthetic energy")
  end
 end
 return v :: Frame
end
return M
