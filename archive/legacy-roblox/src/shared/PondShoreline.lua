--!strict
local Geometry=require(script.Parent.SharedGeometry)
local M={}
function M.triangles(scene:Geometry.Scene):{{Vector3}}
 local out:{{Vector3}}={}
 local f=scene.terrain and scene.terrain.heightfield
 if not f then return out end
 local function emit(poly:{Vector3})
  local clipped:{Vector3}={}
  for i,a in poly do
   local b=poly[i%#poly+1];local da,db=scene.bounds[3]-a.Z,scene.bounds[3]-b.Z
   if da>=0 then table.insert(clipped,a) end
   if (da>=0)~=(db>=0) then table.insert(clipped,a+(b-a)*(da/(da-db))) end
  end
  for i=2,#clipped-1 do
   local face={}
   for _,p in {clipped[1],clipped[i],clipped[i+1]} do table.insert(face,Vector3.new(p.X-scene.bounds[1]/2,0,p.Y-scene.bounds[2]/2)) end
   table.insert(out,face)
  end
 end
 for y=0,f.ny-2 do for x=0,f.nx-2 do
  local function v(dx:number,dy:number):Vector3 return Vector3.new((x+dx)*f.cell,(y+dy)*f.cell,f.heights[(y+dy)*f.nx+x+dx+1]) end
  emit({v(0,0),v(0,1),v(1,0)});emit({v(1,0),v(0,1),v(1,1)})
 end end
 return out
end
function M.fallback(scene:Geometry.Scene,triangles:{{Vector3}}):({{number}},{{Vector3}})
 local f=scene.terrain and scene.terrain.heightfield
 if not f then return {},triangles end
 local full:{[number]:boolean}={}
 local rectangles:{{number}}={}
 for y=0,f.ny-2 do
  local start:number?=nil
  for x=0,f.nx-1 do
   local wet=x<f.nx-1 and math.max(f.heights[y*f.nx+x+1],f.heights[y*f.nx+x+2],f.heights[(y+1)*f.nx+x+1],f.heights[(y+1)*f.nx+x+2])<=scene.bounds[3]
   if wet then full[y*f.nx+x]=true;if start==nil then start=x end
   elseif start~=nil then
    table.insert(rectangles,{start*f.cell-scene.bounds[1]/2,y*f.cell-scene.bounds[2]/2,(x-start)*f.cell,f.cell});start=nil
   end
  end
 end
 local edges:{{Vector3}}={}
 for _,face in triangles do
  local c=(face[1]+face[2]+face[3])/3
  local x,y=math.floor((c.X+scene.bounds[1]/2)/f.cell),math.floor((c.Z+scene.bounds[2]/2)/f.cell)
  if not full[y*f.nx+x] then table.insert(edges,face) end
 end
 return rectangles,edges
end
return M
