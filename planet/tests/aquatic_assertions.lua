local P=require("../src/biology/shared/AquaticProtocol")
local p={schema=1,model="aquatic-foundation-1",run="test",revision=1,token="test:1",totals={1,2,3,4},residual={0,0,0,0},flux={0,0,0,0,0},patches={}}
for i=1,40 do table.insert(p.patches,{i,i*4,100,50,2,40,.8,500,250,200,1500,20,40,2,100,10})end
P.validate(p,"test")
assert(#P.near(p,{80,100,75}).patches==24)
assert(#P.near(p,{1000,1000,1000}).patches==0)
assert(#P.near(p,{80,100,75},12).patches==12)
assert(P.near(p,{80,100,75},1).patches[1][1]==20)
local bad=table.clone(p);bad.run="other";assert(not pcall(P.validate,bad,"test"))
bad=table.clone(p);bad.patches={p.patches[1],p.patches[1]};assert(not pcall(P.validate,bad,"test"))
bad=table.clone(p);bad.patches={table.clone(p.patches[1])};bad.patches[1][5]=0/0;assert(not pcall(P.validate,bad,"test"))
print("PASS aquatic packet budgets, nearest interest, identity and invalid chemistry")
