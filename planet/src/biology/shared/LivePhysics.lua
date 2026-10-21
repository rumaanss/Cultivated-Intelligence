--!strict
-- Pure shared swept-sphere movement. Coordinates: simulation X/Y/Z (Z up).
local Geometry = require(script.Parent.SharedGeometry)
local M = {}
local Heightfield = require(script.Parent.Heightfield)
export type Actor = {id:number, position:Vector3, radius:number}
local function dot(a: Vector3,b: Vector3): number return a:Dot(b) end
function M.floor(scene: Geometry.Scene,p: Vector3,r: number): number
 return Geometry.floorHeight(scene,p.X,p.Y,r)
end
function M.place(scene: Geometry.Scene,p: Vector3,r: number): Vector3
 p=Vector3.new(math.clamp(p.X,r+0.001,scene.bounds[1]-r-0.001),math.clamp(p.Y,r+0.001,scene.bounds[2]-r-0.001),math.clamp(p.Z,r+0.001,scene.bounds[3]-r-0.001))
 p=Vector3.new(p.X,p.Y,math.max(p.Z,M.floor(scene,p,r)+0.001))
 local field=scene.terrain and scene.terrain.heightfield
 if field and p.Z>scene.bounds[3]-r then
  local best,nearest=math.huge,p
  for y=0,field.ny-2 do for x=0,field.nx-2 do
   local q=Vector3.new((x+.5)*field.cell,(y+.5)*field.cell,0)
   q=Vector3.new(q.X,q.Y,math.max(r,M.floor(scene,q,r)+0.001))
   local distance=(q.X-p.X)^2+(q.Y-p.Y)^2
   if q.Z<scene.bounds[3]-r and distance<best then
    local clear=true
    for _,o in scene.objects do
     if o.solid then
      local d=q-Vector3.new(o.center[1],o.center[2],o.center[3])
      if o.shape=="sphere" and d.Magnitude<o.halfSize[1]+r then clear=false;break end
     end
    end
    if clear then best,nearest=distance,q end
   end
  end end
  assert(best<math.huge,"No valid pond placement")
  p=nearest
 end
 for _,o in scene.objects do
  if o.solid then
   local c=Vector3.new(o.center[1],o.center[2],o.center[3])
   if o.shape=="sphere" and (p-c).Magnitude<o.halfSize[1]+r+0.001 then p=Vector3.new(p.X,p.Y,c.Z+o.halfSize[3]+r+0.001) end
  end
 end
 return p
end
function M.move(scene: Geometry.Scene,p: Vector3,displacement: Vector3,r: number,actors: {Actor}?,ignore: number?): (Vector3,Vector3)
 local start=p
 local remaining=displacement
 local terrain=scene.terrain
 for _=1,4 do
  if remaining.Magnitude<0.000001 then break end
  local fraction,normal=1,Vector3.zero
  local function plane(n: Vector3,c: number)
   local a,b=dot(n,p)-c,dot(n,p+remaining)-c
   if b<0 and a>=-0.00001 then
    local t=math.max(0,a)/(math.max(0,a)-b)
    if t<fraction then fraction,normal=t,n end
   end
  end
  plane(Vector3.xAxis,r);plane(-Vector3.xAxis,r-scene.bounds[1])
  plane(Vector3.yAxis,r);plane(-Vector3.yAxis,r-scene.bounds[2])
  plane(Vector3.zAxis,r);plane(-Vector3.zAxis,r-scene.bounds[3])
  if terrain and terrain.heightfield then
   local hit,t,n=Heightfield.sweep(terrain.heightfield,p,p+remaining,r,fraction)
   if hit then fraction,normal=t,n end
  end
  if terrain~=nil then
   for _,q in terrain.planes do
    local n=Vector3.new(-q[1],-q[2],1);local length=n.Magnitude
    plane(n/length,q[3]/length+r)
   end
  end
  local function sphere(c: Vector3,radius: number)
   local d=p-c;local aa=remaining:Dot(remaining);local bb=d:Dot(remaining);local cc=d:Dot(d)-(radius+r)^2
   if cc<0 then
    if bb<0 then fraction,normal=0,if d.Magnitude>0.00001 then d.Unit else Vector3.zAxis end
   elseif bb<0 then
    local disc=bb*bb-aa*cc
    if disc>=0 then
     local t=(-bb-math.sqrt(disc))/aa
     if t>=0 and t<fraction then fraction,normal=t,(p+remaining*t-c).Unit end
    end
   end
  end
  for _,o in scene.objects do
   if o.solid and o.shape=="sphere" then sphere(Vector3.new(o.center[1],o.center[2],o.center[3]),o.halfSize[1]) end
  end
  if actors~=nil then for _,a in actors do if a.id~=ignore then sphere(a.position,a.radius) end end end
  if fraction==1 then p+=remaining;remaining=Vector3.zero;break end
  p+=remaining*math.max(0,fraction-0.001/math.max(remaining.Magnitude,0.001))
  remaining*=1-fraction
  remaining-=normal*math.min(0,remaining:Dot(normal))
 end
 if terrain and terrain.heightfield then
  local ground=M.floor(scene,p,r)
  if p.Z<ground+0.001 and p.Z>=ground-0.002 and ground+0.001<=scene.bounds[3]-r then p=Vector3.new(p.X,p.Y,ground+0.001) end
 end
 if p.Z<M.floor(scene,p,r-0.00001) or p.Z>scene.bounds[3]-r+0.00001 then
  p=start;remaining=Vector3.zero
 end
 return p,remaining
end
function M.intent(velocity: Vector3,output: {number},speed: number): Vector3
 local direction=Vector3.new(output[2]*2-1,output[1]*2-1,output[3]*2-1)
 local nextVelocity=(velocity+direction*(speed*0.2))*0.88
 if nextVelocity.Magnitude>speed then nextVelocity=nextVelocity.Unit*speed end
 return nextVelocity
end
return M
