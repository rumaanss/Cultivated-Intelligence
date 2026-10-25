--!nonstrict
local M={}
local function finite(v)return type(v)=="number" and v==v and math.abs(v)<1e18 end
local function integer(v,lo,hi)return finite(v)and v%1==0 and v>=lo and v<=hi end
local function material(v,signed)
 assert(type(v)=="table"and #v==3,"Stage3 material")
 for _,x in v do assert(finite(x)and(signed or x>=-1e-7),"Stage3 material amount")end
end
function M.validate(p,run,baseValidate)
 assert(p.schema==3 and p.model=="stage3-1","Stage3 identity")
 local base=table.clone(p);base.schema=2;base.model="pdnarna-4";base.colonies={}
 assert(type(p.colonies)=="table"and #p.colonies<=1728 and #p.colonies<=p.population,"Stage3 sample budget")
 local ids,patches={},{};for _,r in p.patches do patches[r[1]]=true end
 for _,r in p.colonies do
  assert(type(r)=="table"and #r==50,"Stage3 colony width")
  for _,v in r do assert(finite(v)and v>=-1e-8,"Stage3 colony values")end
  assert(integer(r[1],1,1000000)and patches[r[1]]and integer(r[2],0,5)and integer(r[3],1,9007199254740991)and not ids[r[3]],"Stage3 colony identity")
  ids[r[3]]=r;assert(integer(r[4],0,r[3]-1)and integer(r[5],1,9007199254740991)and integer(r[6],0,9007199254740991)and integer(r[7],0,p.revision),"Stage3 lineage")
  assert(r[23]<=436 and r[24]<=212 and r[25]<108 and r[26]>0 and integer(r[27],0,6),"Stage3 position")
  assert(integer(r[46],0,3)and r[47]>0 and r[47]<=1 and r[49]<=r[48]+1e-7,"Stage3 feeding")
  for k=32,45 do assert(r[k]>=.25 and r[k]<=4,"Stage3 allele")end
  if r[2]<3 then local row={};for k=1,39 do row[k]=r[k]end;table.insert(base.colonies,row)end
 end
 baseValidate(base,run)
 assert(type(p.algae)=="table"and #p.algae<=768,"Stage3 algae budget")
 local shapes={}
 for _,r in p.algae do
  assert(type(r)=="table"and #r==3 and ids[r[2]]and ids[r[2]][2]==5 and ids[r[2]][1]==r[1]and not shapes[r[2]],"Stage3 shape identity")
  shapes[r[2]]=true;assert(type(r[3])=="table"and #r[3]>=1 and #r[3]<=24,"Stage3 segments")
  local nodes={};local carbon=0
  for _,n in r[3]do
   assert(type(n)=="table"and #n==7,"Stage3 segment width")
   for _,v in n do assert(finite(v),"Stage3 segment value")end
   assert(integer(n[1],1,1000000)and integer(n[2],0,n[1]-1)and(n[2]==0 or nodes[n[2]])and not nodes[n[1]],"Stage3 segment topology")
   nodes[n[1]]=true;assert(integer(n[3],0,p.revision)and n[4]>=0 and n[5]>=0 and n[5]<=6 and n[6]>=0 and n[6]<=3,"Stage3 segment state");carbon+=n[4]
  end
  assert(math.abs(carbon-ids[r[2]][8])<1e-7*math.max(1,carbon),"Stage3 unpaid geometry")
 end
 for id,r in ids do if r[2]==5 then assert(shapes[id],"Missing algal structure")end end
 assert(type(p.food)=="table"and #p.food<=192,"Stage3 food cells")
 local cells={};for _,r in p.food do
  assert(#r==4 and patches[r[1]]and integer(r[2],0,1)and type(r[3])=="table"and #r[3]==6 and finite(r[4])and r[4]>=0,"Stage3 food cell")
  local key=r[1]..":"..r[2];assert(not cells[key],"Duplicate food cell");cells[key]=true;for _,x in r[3]do assert(finite(x)and x>=0,"Stage3 stock")end
 end
 local b=p.budget;assert(type(b)=="table"and b.schema==1 and integer(b.startTick,0,p.revision)and b.endTick==p.revision and finite(b.biologicalDays)and b.biologicalDays>=0,"Stage3 budget time")
 assert(type(b.guilds)=="table"and #b.guilds==6,"Stage3 guild budget");material(b.maxResidual,false)
 for i,r in b.guilds do assert(#r==4 and r[1]==i-1 and #r[4]==10,"Stage3 flow width");material(r[2],false);material(r[3],false);for k,v in r[4]do material(v,k==9)end end
 return p
end
return M
