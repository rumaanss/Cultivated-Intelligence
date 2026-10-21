--!strict
-- Validate complete packets before replacing authoritative client state.
local M={}
local Contract=require(script.Parent.PlanetContract)
local function finite(n:any):boolean return type(n)=="number" and n==n and math.abs(n)<1e12 end
local function integer(n:any,lo:number,hi:number):boolean return finite(n) and n%1==0 and n>=lo and n<=hi end
local function vector(v:any,n:number)
 assert(type(v)=="table" and #v==n,"Invalid plant vector")
 for _,x in v do assert(finite(x),"Nonfinite plant value") end
end
function M.validate(s:any)
 assert(type(s)=="table" and s.schema==1 and s.units=="studs-Y-up","Unsupported plant schema")
 assert(type(s.run)=="string" and #s.run<=100 and string.match(s.run,"^[%w_-]+$")~=nil,"Invalid run")
 assert(integer(s.revision,0,9007199254740991) and integer(s.tick,0,9007199254740991),"Invalid counters")
 assert(type(s.reset)=="boolean" and integer(s.base,0,9007199254740991),"Invalid revision base")
 assert(s.surface==Contract.surface,"Plant habitat revision mismatch")
 assert(type(s.upsert)=="table" and #s.upsert<=512 and type(s.removed)=="table" and #s.removed<=512,"Plant budget")
 if s.environment~=nil then
  assert(type(s.environment)=="table","Invalid plant environment")
  for _,key in {"daylight","assimilationTotal","respirationTotal"}do
   assert(finite(s.environment[key]) and s.environment[key]>=0,"Invalid plant environment value")
  end
  local carbon=s.environment.atmosphericCarbon
  assert(carbon==nil or (finite(carbon) and carbon>=0),"Invalid atmospheric carbon")
 end
 if s.litter~=nil then
  assert(type(s.litter)=="table" and #s.litter<=16384,"Litter budget")
  local cells={}
  for _,row in s.litter do vector(row,5);assert(integer(row[1],0,16383) and not cells[row[1]] and row[5]>=0,"Invalid litter");cells[row[1]]=true end
 end
 local seen={}
 for _,p in s.upsert do
  assert(type(p)=="table" and integer(p.id,1,4294967295) and not seen[p.id],"Duplicate/invalid plant")
  seen[p.id]=true
  assert(integer(p.species,0,2) and integer(p.stage,0,2) and integer(p.generation,0,4294967295),"Plant state")
  assert(integer(p.lineage,1,4294967295) and integer(p.age,0,4294967295) and integer(p.policy,0,2) and integer(p.mutations,0,4294967295),"Plant metadata")
  assert(finite(p.hue) and p.hue>=0 and p.hue<=1 and finite(p.leafArea) and p.leafArea>=.35 and p.leafArea<=1.6,"Plant traits")
  assert(type(p.action)=="string" and #p.action<40 and type(p.result)=="string" and #p.result<80,"Decision metadata")
  if p.growthCost~=nil then vector(p.growthCost,3)end
  if p.flux~=nil then vector(p.flux,8);assert(type(p.fluxValid)=="boolean","Invalid flux state")end
  if p.structureCarbon~=nil then assert(finite(p.structureCarbon) and p.structureCarbon>=0,"Invalid structural carbon")end
  vector(p.position,3);vector(p.resources,4);vector(p.inputs,24);vector(p.job,5)
  assert(type(p.organs)=="table" and #p.organs<=128,"Organ budget")
  local organs={}
  for _,o in p.organs do
   vector(o,13)
   assert(integer(o[1],1,4294967295) and not organs[o[1]] and integer(o[2],0,4294967295) and (o[2]==0 or organs[o[2]]),"Organ topology")
   assert(integer(o[3],0,3) and o[10]>0 and o[10]<1000 and o[11]>=0 and o[11]<1e6 and o[12]>=0 and o[12]<=1 and integer(o[13],0,1),"Organ dimensions")
   organs[o[1]]=true
  end
 end
 for _,id in s.removed do assert(integer(id,1,4294967295) and not seen[id],"Invalid removal") end
 return s
end
function M.apply(state:any,s:any):(any,string?)
 -- Omitted organ arrays mean unchanged structure, never an empty body.
 assert(type(s)=="table" and type(s.upsert)=="table" and #s.upsert<=512,"Invalid packet")
 if s.reset~=true then
  if state==nil or state.run~=s.run or state.revision~=s.base then return nil,"resync" end
  local expanded=table.clone(s);expanded.upsert={}
  for _,p in s.upsert do
   assert(type(p)=="table","Invalid plant")
   if p.organs==nil then
    local old=state.records[p.id];assert(old~=nil,"Missing topology on new plant")
    local row=table.clone(p);row.organs=old.organs;table.insert(expanded.upsert,row)
   else table.insert(expanded.upsert,p) end
  end
  s=expanded
 end
 M.validate(s)
 if not s.reset and (state==nil or state.run~=s.run or state.revision~=s.base) then return nil,"resync" end
 if state and state.run==s.run and s.revision<state.revision then return nil,"stale" end
 local records=if s.reset then {} else table.clone(state.records)
 for _,p in s.upsert do records[p.id]=p end
 for _,id in s.removed do records[id]=nil end
 local count=0;for _ in records do count+=1 end;assert(count<=512,"State population budget")
 return {run=s.run,revision=s.revision,tick=s.tick,worldTick=s.worldTick,surface=s.surface,records=records,litter=s.litter or {},deathCount=s.deathCount,ledger=s.ledger,environment=s.environment,age=s.age},nil
end
return M
