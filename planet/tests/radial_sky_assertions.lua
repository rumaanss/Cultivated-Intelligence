local function close(a,b)assert(math.abs(a-b)<1e-8)end
-- Fixed Roblox joins, independent of M.direction. A generic cube can be
-- internally continuous while displaying the wrong faces in Roblox.
-- Reference: devforum.roblox.com/t/rendering-skyboxes-in-studio/939151
local joins={
 {5,"top",3,"left",false},{5,"bottom",4,"left",true},
 {5,"left",2,"right",false},{5,"right",1,"left",false},
 {6,"top",3,"right",true},{6,"bottom",4,"right",false},
 {6,"left",1,"right",false},{6,"right",2,"left",false},
 {2,"top",3,"top",true},{2,"bottom",4,"bottom",true},
 {1,"top",3,"bottom",false},{1,"bottom",4,"top",false},
}
local function edge(face,side,t)
 if side=="top" then return Sky.direction(face,t,-1)end
 if side=="bottom" then return Sky.direction(face,t,1)end
 if side=="left" then return Sky.direction(face,-1,t)end
 return Sky.direction(face,1,t)
end
for _,j in joins do for i=0,64 do
 local t=i/32-1
 local a=edge(j[1],j[2],t);local b=edge(j[3],j[4],if j[5]then -t else t)
 assert((a-b).Magnitude<1e-8,"Roblox face join mismatch: "..j[1].." "..j[2])
end end
-- World-space centers and image-up vectors from the independent camera capture
-- convention. This also catches a seamless but globally rotated cubemap.
local forward={Vector3.new(-1,0,0),Vector3.new(1,0,0),Vector3.yAxis,-Vector3.yAxis,Vector3.new(0,0,1),Vector3.new(0,0,-1)}
local top={Vector3.yAxis,Vector3.yAxis,Vector3.xAxis,-Vector3.xAxis,Vector3.yAxis,Vector3.yAxis}
for f=1,6 do
 assert((Sky.direction(f,0,0)-forward[f]).Magnitude<1e-8)
 assert((Sky.direction(f,0,-1)-(forward[f]+top[f]).Unit).Magnitude<1e-8)
end
for _,up in {Vector3.yAxis,Vector3.xAxis,Vector3.new(0,-1,0),Vector3.new(-.136,-.393,.909).Unit}do
 local east=(if math.abs(up.X)<.8 then up:Cross(Vector3.xAxis) else up:Cross(Vector3.yAxis)).Unit
 for _,sun in {east,up,-east,-up}do
  for f=1,6 do for y=-1,1,.2 do for x=-1,1,.2 do
   local c=Sky.radiance(Sky.direction(f,x,y),up,sun)
   for _,v in {c.R,c.G,c.B}do assert(v==v and v>=0 and v<=1)end
  end end end
 end
 local noon=Sky.radiance(up,up,up);local night=Sky.radiance(up,up,-up)
 assert(noon.B>night.B and noon.R>night.R)
end
print("PASS radial sky: all 12 Roblox face joins and world orientation and dawn/noon/dusk/night at four planetary positions")
-- Rotational covariance: a global rotation must not change sky radiance.
local function rotate(v)return Vector3.new(v.Z,v.X,v.Y)end
for _,height in {0,10,100,1000,10000}do
 for _,up in {Vector3.yAxis,Vector3.new(-.136,-.393,.909).Unit}do
  local sun=Vector3.new(.4,.7,.2).Unit
  for face=1,6 do
   local view=Sky.direction(face,.3,-.6)
   local a=Sky.radiance(view,up,sun,height,4096)
   local b=Sky.radiance(rotate(view),rotate(up),rotate(sun),height,4096)
   close(a.R,b.R);close(a.G,b.G);close(a.B,b.B)
   for _,v in {a.R,a.G,a.B}do assert(v==v and v>=0 and v<=1)end
  end
 end
end
close(Sky.horizonCosine(4096,0),0)
assert(Sky.horizonCosine(4096,100)<0)
close(Sky.horizonCosine(4096,100),Sky.horizonCosine(8192,200))
-- Mock only transport to EditableImages, never claim this verifies GPU display.
Content={fromObject=function(image)return image end}
Vector2.zero=Vector2.new(0,0)
local uploads,created=0,{}
services.AssetService={CreateEditableImage=function()
 local image={destroyed=false}
 function image:WritePixelsBuffer(_,_,pixels)
  assert(not self.destroyed);uploads+=1;self.pixels=buffer.create(buffer.len(pixels));buffer.copy(self.pixels,0,pixels)
 end
 function image:Destroy()self.destroyed=true end
 table.insert(created,image);return image
end}
local jobs={};local bakeCalls=0
function task.defer(fn)table.insert(jobs,fn)end
local function finishBake()
 local job=table.remove(jobs,1);if job then job()end
end
local function bake(_,image)
 bakeCalls+=1
 local pixels=buffer.create(buffer.len(image.pixels));buffer.copy(pixels,0,image.pixels)
 return Enum.CreateContentResult.Success,{SourceType="Opaque",pixels=pixels}
end
services.AssetService.CreateDataModelContentAsync=bake
local sky={};for _,key in Sky.properties do sky[key]="original"end
local state={};local status={SetAttribute=function(_,k,v)state[k]=v end}
local renderer=assert(Sky.new(sky,status))
local clock=0
local function update(mode)
 clock+=1/60;local previous=uploads
 renderer.Update(Vector3.yAxis,Vector3.yAxis,clock,0,4096,mode)
 assert(uploads-previous<=1,"More than one image upload per update")
 assert(#jobs<=1,"Concurrent bake jobs")
 finishBake()
end
for _=1,2000 do
 update("Solid")
 if state.SkyGeneration==1 then break end
 for _,key in Sky.properties do assert(sky[key]=="original","Partial initial publication")end
end
assert(state.SkyGeneration==1,"Sky never committed")
for _,key in Sky.properties do
 local image=sky[key];assert(image.SourceType=="Opaque","Live image assigned to sky");assert(buffer.readu8(image.pixels,0)==255 and buffer.readu8(image.pixels,1)==0)
end
local previous=sky[Sky.properties[1]]
for _=1,2000 do
 update("Horizon")
 if state.SkyGeneration==2 then break end
 assert(sky[Sky.properties[1]]==previous,"Front bank modified before commit")
end
assert(state.SkyGeneration==2)
sky[Sky.properties[1]]="foreign writer";update("Horizon")
assert(state.SkyContentRepairs==1 and sky[Sky.properties[1]]~="foreign writer")
renderer.SetEnabled(false);for _,key in Sky.properties do assert(sky[key]=="original")end
renderer.SetEnabled(true);assert(sky[Sky.properties[1]]~="original")
-- Failed baking must retain the complete previous generation and back off.
local retained=sky[Sky.properties[1]]
services.AssetService.CreateDataModelContentAsync=function()bakeCalls+=1;return Enum.CreateContentResult.StorageLimitExceeded,nil end
for _=1,2000 do update("Faces");if state.SkyBakeFailures==1 then break end end
assert(state.SkyBakeFailures==1)
assert(sky[Sky.properties[1]]==retained,"Bake failure replaced working sky")
local count=bakeCalls
for _=1,60 do update("Faces")end
assert(bakeCalls==count,"Bake failure retried without backoff")
services.AssetService.CreateDataModelContentAsync=bake
for _=1,2000 do update("Faces");if state.SkyGeneration==3 then break end end
assert(state.SkyGeneration==3 and state.SkyBakeFailures==0)
-- Cancel a queued bake without publishing its stale mode.
for _=1,2000 do
 clock+=1/60;renderer.Update(Vector3.yAxis,Vector3.yAxis,clock,0,4096,"Solid")
 if #jobs==1 then break end
end
assert(#jobs==1)
clock+=1/60;renderer.Update(Vector3.yAxis,Vector3.yAxis,clock,0,4096,"Horizon")
finishBake();assert(state.SkyGeneration==3)
-- Destroy during an outstanding API call: retain its source until it completes.
for _=1,2000 do
 clock+=1/60;renderer.Update(Vector3.yAxis,Vector3.yAxis,clock,0,4096,"Horizon")
 if #jobs==1 then break end
end
assert(#jobs==1)
renderer.Destroy();renderer.Destroy();finishBake()
for _,key in Sky.properties do assert(sky[key]=="original")end
for _,image in created do assert(image.destroyed)end
local calls=0
services.AssetService.CreateEditableImage=function()
 calls+=1;if calls==3 then return nil end
 local image={destroyed=false,Destroy=function(self)self.destroyed=true end}
 table.insert(created,image);return image
end
local failed=Sky.new(sky,status);assert(failed==nil)
for _,image in created do assert(image.destroyed,"Allocation failure leaked image")end
print("PASS sky rotation/altitude, Opaque-only publication, serialized baking, failure/backoff/recovery, mode cancellation, destruction during bake and allocation cleanup")
