--!nonstrict
-- Patch concentrations are observational summaries, never individual-cell identities.
local M={Version=1,Radius=160,MaximumPatches=24}
local function finite(x)return type(x)=="number" and x==x and math.abs(x)<1e18 end
function M.validate(p,run)
 assert(type(p)=="table" and p.schema==1 and p.model=="aquatic-foundation-1","Aquatic schema")
 assert(type(p.run)=="string" and p.run==run,"Aquatic run")
 assert(finite(p.revision) and p.revision>=0 and p.revision%1==0,"Aquatic revision")
 assert(type(p.token)=="string" and #p.token<=1600,"Aquatic token")
 assert(type(p.patches)=="table" and #p.patches<=96,"Aquatic patch budget")
 for _,key in {"totals","residual","flux"}do
  assert(type(p[key])=="table" and #p[key]==(if key=="flux" then 5 else 4),"Aquatic ledger")
  for _,v in p[key]do assert(finite(v),"Aquatic ledger value")end
 end
 local ids={}
 for _,r in p.patches do
  assert(type(r)=="table" and #r==16,"Aquatic row")
  for _,v in r do assert(finite(v) and v>=-1e-7,"Aquatic concentration")end
  assert(r[1]%1==0 and r[1]>=1 and not ids[r[1]],"Aquatic ID");ids[r[1]]=true
  assert(r[2]<=436 and r[3]<=212 and r[4]<108,"Aquatic bounds")
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
 local out=table.clone(p);out.patches={}
 for i=1,math.min(limit or M.MaximumPatches,#rows)do table.insert(out.patches,rows[i].r)end
 return out
end
return M
