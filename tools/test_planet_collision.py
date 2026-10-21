from pathlib import Path
import argparse,json,subprocess,tempfile
p=argparse.ArgumentParser();p.add_argument('--luau',required=True);a=p.parse_args();r=Path(__file__).resolve().parents[1]
s=(r/'planet/tests/mock_runtime.lua').read_text()
for name,path in [('Before','planet/tests/heightfield_reference.lua'),('After','planet/src/biology/shared/Heightfield.lua')]:s+='\nlocal '+name+'=(function()\n'+(r/path).read_text()+'\nend)()\n'
f=json.loads((r/'contracts/planet_geometry.json').read_text())['terrain']['heightfield'];s+='local f={nx='+str(f['nx'])+',ny='+str(f['ny'])+',cell=4,heights={'+','.join(map(str,f['heights']))+'}}\n'
s+='''math.randomseed(127)
local samples={}
for i=1,10000 do
 local x,y=math.random()*440-2,math.random()*216-2
 local floor=Before.height(f,x,y)
 local z=if i%3==0 then floor+(math.random()-.5)*2 else floor+3+math.random()*30
 local a=Vector3.new(x,y,z)
 local b=a+Vector3.new((math.random()-.5)*4,(math.random()-.5)*4,(math.random()-.5)*4)
 local r=if i%11==0 then 0 else .25
 local h,t,n=Before.sweep(f,a,b,r,1);local hh,tt,nn=After.sweep(f,a,b,r,1)
 assert(h==hh and (not h or (math.abs(t-tt)<1e-7 and (n-nn).Magnitude<1e-7)),"Sweep regression at "..i)
 assert(math.abs(Before.floor(f,x,y,r)-After.floor(f,x,y,r))<1e-7,"Floor regression")
 samples[i]={a,b,r}
end
local function bench(module)
 local t=os.clock();local count=0
 for pass=1,3 do for _,s in samples do if module.sweep(f,s[1],s[2],s[3],1)then count+=1 end end end
 return (os.clock()-t)*1000,count
end
local old,n=bench(Before);local new,m=bench(After);assert(n==m)
print(string.format("PASS 10000 differential sweep/floor checks; 30000 sweeps before %.2f ms, after %.2f ms, speedup %.2fx",old,new,old/new))
'''
with tempfile.TemporaryDirectory() as d:
 f=Path(d)/'check.lua';f.write_text(s);subprocess.run([a.luau,str(f)],check=True)
