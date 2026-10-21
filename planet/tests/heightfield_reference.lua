--!strict
-- Shared piecewise-planar collision surface; X/Y horizontal, Z up.
local M = {}
export type Field = {nx:number, ny:number, cell:number, heights:{number}}
function M.plane(f:Field,x:number,y:number):Vector3
 local ix=math.clamp(math.floor(x/f.cell),0,f.nx-2)
 local iy=math.clamp(math.floor(y/f.cell),0,f.ny-2)
 local u,v=x/f.cell-ix,y/f.cell-iy
 local function h(dx:number,dy:number):number return f.heights[(iy+dy)*f.nx+ix+dx+1] end
 if u+v<=1 then
  local ax=(h(1,0)-h(0,0))/f.cell
  local ay=(h(0,1)-h(0,0))/f.cell
  local z=h(0,0)
  return Vector3.new(ax,ay,z-ax*ix*f.cell-ay*iy*f.cell)
 else
  local ax=(h(1,1)-h(0,1))/f.cell
  local ay=(h(1,1)-h(1,0))/f.cell
  local z=h(1,0)+h(0,1)-h(1,1)
  return Vector3.new(ax,ay,z-ax*ix*f.cell-ay*iy*f.cell)
 end
end
function M.height(f:Field,x:number,y:number):number
 local q=M.plane(f,x,y);return q.X*x+q.Y*y+q.Z
end
function M.floor(f:Field,x:number,y:number,r:number):number
 local high=-math.huge
 for _,dx in {-r,0,r} do for _,dy in {-r,0,r} do high=math.max(high,M.height(f,x+dx,y+dy)) end end
 return high+r
end
function M.ray(f:Field,a:Vector3,b:Vector3,pad:number,limit:number):(boolean,number,Vector3)
 local d=b-a;local enter,leave=0,1
 local origins,dirs,bounds={a.X,a.Y},{d.X,d.Y},{(f.nx-1)*f.cell,(f.ny-1)*f.cell}
 for k=1,2 do
  if math.abs(dirs[k])<1e-12 then if origins[k]<0 or origins[k]>bounds[k] then return false,limit,Vector3.zero end
  else
   local t0,t1=-origins[k]/dirs[k],(bounds[k]-origins[k])/dirs[k]
   if t0>t1 then t0,t1=t1,t0 end
   enter,leave=math.max(enter,t0),math.min(leave,t1)
  end
 end
 if enter>leave then return false,limit,Vector3.zero end
 local cuts={enter,leave}
 for k=1,2 do if math.abs(dirs[k])>1e-12 then
  local p0,p1=origins[k]+dirs[k]*enter,origins[k]+dirs[k]*leave
  for i=math.max(1,math.floor(math.min(p0,p1)/f.cell)),math.min(bounds[k]/f.cell-1,math.ceil(math.max(p0,p1)/f.cell)) do
   local t=(i*f.cell-origins[k])/dirs[k];if t>enter and t<leave then table.insert(cuts,t) end
  end
 end end
 table.sort(cuts)
 local function interval(lo:number,hi:number):(boolean,number,Vector3)
  local p=a+d*((lo+hi)*.5);local q=M.plane(f,p.X,p.Y)
  local pa,pb=a+d*lo,a+d*hi
  local da=pa.Z-q.X*pa.X-q.Y*pa.Y-q.Z-pad
  local db=pb.Z-q.X*pb.X-q.Y*pb.Y-q.Z-pad
  if da>=-0.00001 and db>=-0.00001 then return false,limit,Vector3.zero end
  local t=if da<0 then lo else lo+(hi-lo)*da/(da-db)
  if t<=limit then return true,t,Vector3.new(-q.X,-q.Y,1).Unit end
  return false,limit,Vector3.zero
 end
 for i=2,#cuts do
  local lo,hi=cuts[i-1],cuts[i]
  if hi-lo<1e-9 then continue end
  local mid=a+d*((lo+hi)*.5)
  local diagonal=if math.abs(d.X+d.Y)>1e-12 then ((math.floor(mid.X/f.cell)+math.floor(mid.Y/f.cell)+1)*f.cell-a.X-a.Y)/(d.X+d.Y) else -1
  if diagonal>lo and diagonal<hi then
   local hit,t,n=interval(lo,diagonal);if hit then return hit,t,n end
   hit,t,n=interval(diagonal,hi);if hit then return hit,t,n end
  else local hit,t,n=interval(lo,hi);if hit then return hit,t,n end end
 end
 return false,limit,Vector3.zero
end
function M.sweep(f:Field,a:Vector3,b:Vector3,r:number,limit:number):(boolean,number,Vector3)
 local hit,normal=false,Vector3.zero
 if r==0 then return M.ray(f,a,b,0,limit) end
 for _,dx in {-r,0,r} do for _,dy in {-r,0,r} do
  local offset=Vector3.new(dx,dy,0)
  local found,t,n=M.ray(f,a+offset,b+offset,r,limit)
  if found then hit,limit,normal=true,t,n end
 end end
 return hit,limit,normal
end
return M
