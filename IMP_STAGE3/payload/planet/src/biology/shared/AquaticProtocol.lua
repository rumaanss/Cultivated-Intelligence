--!nonstrict
-- Patch concentrations are observational summaries, never individual-cell identities.
local M={Version=2,Radius=160,MaximumPatches=24}
local function finite(x)return type(x)=="number" and x==x and math.abs(x)<1e18 end
function M.validate(p,run)
 if type(p)=="table" and p.model=="stage3-1" then return require(script.Parent.Stage3Protocol).validate(p,run,M.validate)end
 assert(type(p)=="table" and ((p.schema==1 and p.model=="aquatic-foundation-1") or (p.schema==2 and (p.model=="pdnarna-3" or p.model=="pdnarna-4"))),"Aquatic schema")
 assert(type(p.run)=="string" and p.run==run,"Aquatic run")
 assert(finite(p.revision) and p.revision>=0 and p.revision%1==0,"Aquatic revision")
 assert(type(p.token)=="string" and #p.token<=1600,"Aquatic token")
 assert(type(p.patches)=="table" and #p.patches<=96,"Aquatic patch budget")
 for _,key in {"totals","residual","flux"}do
  assert(type(p[key])=="table" and #p[key]==(if key=="flux" then 5 else 4),"Aquatic ledger")
  for _,v in p[key]do assert(finite(v),"Aquatic ledger value")end
 end
 if p.atmosphere~=nil then
  assert(type(p.atmosphere)=="table" and #p.atmosphere==2,"Aquatic atmospheric pools")
  for _,v in p.atmosphere do assert(finite(v) and v>=0,"Aquatic atmospheric amount")end
 end
 assert(p.seconds==nil or (finite(p.seconds) and p.seconds>=0),"Aquatic biological time")
 local ids={}
 for _,r in p.patches do
  assert(type(r)=="table" and #r==16,"Aquatic row")
  for _,v in r do assert(finite(v) and v>=-1e-7,"Aquatic concentration")end
  assert(r[1]%1==0 and r[1]>=1 and not ids[r[1]],"Aquatic ID");ids[r[1]]=true
  assert(r[2]<=436 and r[3]<=212 and r[4]<108,"Aquatic bounds")
 end
 if p.schema==2 then
  assert(finite(p.population) and p.population%1==0 and p.population>=0 and p.population<=100000,"Colony census")
  assert(type(p.events)=="table" and #p.events==3,"Lifecycle counters")
  for _,v in p.events do assert(finite(v) and v>=0 and v%1==0,"Lifecycle counter")end
  assert(type(p.colonies)=="table" and #p.colonies<=(if p.model=="pdnarna-4" then 576 else 288),"Colony budget")
  assert(#p.colonies<=p.population,"Sample exceeds census")
  local individuals,slots={},{}
  for _,r in p.colonies do
   assert(type(r)=="table" and #r==(if p.model=="pdnarna-4" then 39 else 22),"Colony row")
   for _,v in r do assert(finite(v) and v>=-1e-9,"Colony amount")end
   for _,i in {1,2,3,4,5,6,7,21}do assert(r[i]%1==0,"Colony integer")end
   assert(ids[r[1]] and r[2]<=2 and r[3]>=1 and r[3]<9007199254740992 and r[4]<r[3] and r[5]>=1,"Colony identity")
   local slot=r[1]..":"..r[2]
   assert(not individuals[r[3]] and (slots[slot] or 0)<(if p.model=="pdnarna-4" then 2 else 1),"Duplicate colony sample");individuals[r[3]]=true;slots[slot]=(slots[slot] or 0)+1
   if p.model=="pdnarna-4" then
    assert(r[23]<=436 and r[24]<=212 and r[25]<108 and r[26]>0 and r[27]%1==0 and r[27]<=6,"Motion state")
    assert(r[29]<=r[17]+1e-8 and r[30]<=1e6 and r[31]<=1e6,"Paid motion state")
    for i=32,39 do assert(r[i]>=.25 and r[i]<=4,"Inherited allele")end
   end
   assert(r[15]<=1+1e-9 and (r[21]==1 or r[21]==2 or r[21]==4) and r[22]<108,"Colony state")
  end
  if p.model=="pdnarna-4" then
   assert(type(p.lifecycle)=="table" and #p.lifecycle<=256,"Lifecycle budget")
   local events={}
   for _,r in p.lifecycle do
    assert(type(r)=="table" and #r==8,"Lifecycle row")
    for _,v in r do assert(finite(v) and v>=0,"Lifecycle value")end
    for i=1,5 do assert(r[i]%1==0,"Lifecycle integer")end
    assert(r[1]<=p.revision and (r[2]==1 or r[2]==2) and r[3]>=1 and r[4]<r[3] and ids[r[5]],"Lifecycle identity")
    assert(r[6]<=436 and r[7]<=212 and r[8]<108,"Lifecycle position")
    local key=r[2]..":"..r[3];assert(not events[key],"Duplicate lifecycle event");events[key]=true
   end
  end
 end
 return p
end
function M.near(p,center,limit)
 local rows={}
 for _,r in p.patches do
  local dz=math.max(r[4]-center[3],center[3]-108,0)
  local d=(r[2]-center[1])^2+(r[3]-center[2])^2+dz^2
  if d<=M.Radius^2 then table.insert(rows,{r=r,d=d})end
 end
 table.sort(rows,function(a,b)return if a.d==b.d then a.r[1]<b.r[1] else a.d<b.d end)
 local out=table.clone(p);out.patches={};local chosen={}
 for i=1,math.min(limit or M.MaximumPatches,#rows)do table.insert(out.patches,rows[i].r);chosen[rows[i].r[1]]=true end
 if p.colonies then out.colonies={};for _,r in p.colonies do if chosen[r[1]]then table.insert(out.colonies,r)end end end
 if p.lifecycle then out.lifecycle={};for _,r in p.lifecycle do if chosen[r[5]]then table.insert(out.lifecycle,r)end end end
 for _,key in {"algae","food"}do if p[key]then out[key]={};for _,r in p[key]do if chosen[r[1]]then table.insert(out[key],r)end end end end
 return out
end
return M
