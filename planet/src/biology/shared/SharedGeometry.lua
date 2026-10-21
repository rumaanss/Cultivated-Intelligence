--!strict
-- Pure geometry contract and queries. Coordinates are C++ X/Y/Z, with Z up.
local M = {}
local Contract=require(script.Parent.PlanetContract)
local Heightfield = require(script.Parent.Heightfield)
export type GeometryObject = {id: number, shape: string, center: {number}, halfSize: {number}, solid: boolean, opaque: boolean, material: string}
export type Scene = {version: number, revision: string, sha256: string, bounds: {number}, bodyRadius: number, objects: {GeometryObject}, terrain: {planes: {{number}}, heightfield: Heightfield.Field?}?}
local function finite(v: any): boolean
 return type(v) == "number" and v == v and math.abs(v) < math.huge
end
local function array(v: any, count: number): boolean
 if type(v) ~= "table" or #v ~= count then return false end
 local n = 0
 for k in pairs(v) do
  if type(k) ~= "number" or k%1 ~= 0 or k < 1 or k > count then return false end
  n += 1
 end
 return n == count
end
function M.validate(v: any): Scene
 assert(type(v) == "table" and v.version == 4,"Unsupported geometry version")
 assert(type(v.revision) == "string" and #v.revision > 0 and #v.revision <= 48 and not string.find(v.revision,"[^%w_-]"),"Invalid geometry revision")
 assert(type(v.sha256) == "string" and #v.sha256 == 64 and not string.find(v.sha256,"[^a-f0-9]"),"Invalid geometry checksum")
 assert(array(v.bounds,3),"Invalid habitat bounds")
 for i=1,3 do assert(v.bounds[i]==Contract.bounds[i],"Habitat bounds mismatch") end
 assert(v.sha256==Contract.habitat.sha256 and type(v.habitat)=="table" and v.habitat.sha256==Contract.habitat.sha256 and v.habitat.id==Contract.habitat.id,"Planet habitat identity mismatch")
 local radius = v.bodyRadius
 assert(finite(radius) and radius > 0 and radius <= 1,"Invalid body radius")
 assert(type(v.objects) == "table" and #v.objects >= 0 and #v.objects <= 128 and array(v.objects,#v.objects),"Invalid geometry count")
 local previous = 0
 for _, obj in v.objects do
  assert(type(obj) == "table" and finite(obj.id) and obj.id%1 == 0 and obj.id > previous and obj.id <= 4294967295,"Invalid object ID")
  previous = obj.id
  assert(obj.shape == "box" or obj.shape == "sphere","Unsupported shape")
  assert(obj.material == "Slate" or obj.material == "Rock" or obj.material == "Sand","Unsupported material")
  assert(type(obj.solid) == "boolean" and type(obj.opaque) == "boolean","Invalid geometry flags")
  assert(array(obj.center,3) and array(obj.halfSize,3),"Invalid geometry vectors")
  for i = 1,3 do
   local c,e = obj.center[i],obj.halfSize[i]
   assert(finite(c) and finite(e) and e > 0 and c-e >= 2*radius and c+e <= v.bounds[i]-2*radius,"Geometry outside body-safe basin")
  end
  if obj.shape == "sphere" then assert(obj.halfSize[1] == obj.halfSize[2] and obj.halfSize[1] == obj.halfSize[3],"Invalid sphere") end
 end
 if v.version == 4 then
  local f = v.terrain and v.terrain.heightfield
  assert(type(f)=="table" and f.nx==Contract.nx and f.ny==Contract.ny and f.cell==4 and array(f.heights,Contract.nx*Contract.ny),"Invalid pond heightfield")
  assert(array(v.terrain.planes,0),"Unexpected pond planes")
  for _,h in f.heights do assert(finite(h) and h>=0 and h<=256,"Invalid pond elevation") end
 elseif v.version == 2 then
  local terrain = v.terrain
  assert(type(terrain) == "table" and type(terrain.planes) == "table" and #terrain.planes >= 1 and #terrain.planes <= 8 and array(terrain.planes,#terrain.planes),"Invalid terrain planes")
  local base = false
  for i,p in terrain.planes do
   assert(array(p,3) and finite(p[1]) and finite(p[2]) and finite(p[3]) and math.abs(p[1]) <= 3 and math.abs(p[2]) <= 3,"Invalid terrain plane")
   if p[1] == 0 and p[2] == 0 and p[3] >= 1 then base = true end
   for j = 1,i-1 do
    local q = terrain.planes[j]
    assert(p[1] ~= q[1] or p[2] ~= q[2] or p[3] ~= q[3],"Duplicate terrain plane")
   end
   local length = math.sqrt(1+p[1]^2+p[2]^2)
   for _,x in {0,100} do for _,y in {0,100} do
    assert(p[1]*x+p[2]*y+p[3]+radius*length < 55,"Terrain lacks surface clearance")
   end end
   for _,o in v.objects do
    local support = if o.shape == "sphere" then o.halfSize[1]*length else math.abs(p[1])*o.halfSize[1]+math.abs(p[2])*o.halfSize[2]+o.halfSize[3]
    assert(o.center[3]-p[1]*o.center[1]-p[2]*o.center[2]-p[3] >= support-0.000001,"Rock penetrates terrain")
   end
  end
  assert(base,"Terrain needs a positive base plane")
 else
  assert(v.terrain == nil,"Unexpected terrain on old geometry")
 end
 for i,a in v.objects do
  for j = i+1,#v.objects do
   local b = v.objects[j]
   if a.solid and b.solid then
    local separated = false
    for axis = 1,3 do
     if math.abs(a.center[axis]-b.center[axis]) > a.halfSize[axis]+b.halfSize[axis]+2*radius+0.001 then separated = true end
    end
    assert(separated,"Solid geometry requires body-width gaps")
   end
  end
 end
 return v :: Scene
end
local function inside(obj: GeometryObject, x: number,y: number,z: number,pad: number): boolean
 local dx,dy,dz = x-obj.center[1],y-obj.center[2],z-obj.center[3]
 if obj.shape == "sphere" then return dx*dx+dy*dy+dz*dz < (obj.halfSize[1]+pad)^2 end
 return math.abs(dx) < obj.halfSize[1]+pad and math.abs(dy) < obj.halfSize[2]+pad and math.abs(dz) < obj.halfSize[3]+pad
end
function M.floorHeight(scene: Scene,x: number,y: number,padding: number): number
 local height = padding
 if scene.terrain and scene.terrain.heightfield then return Heightfield.floor(scene.terrain.heightfield,x,y,padding) end
 local terrain = scene.terrain
 if terrain ~= nil then
  for _,p in terrain.planes do
   height = math.max(height,p[1]*x+p[2]*y+p[3]+padding*math.sqrt(1+p[1]^2+p[2]^2))
  end
 end
 return height
end
function M.clear(scene: Scene,x: number,y: number,z: number): boolean
 local r = scene.bodyRadius
 if not finite(x) or not finite(y) or not finite(z) or x < r-0.00001 or y < r-0.00001 or z < r-0.00001 or x > scene.bounds[1]-r+0.00001 or y > scene.bounds[2]-r+0.00001 or z > scene.bounds[3]-r+0.00001 then return false end
 if z < M.floorHeight(scene,x,y,r-0.00001) then return false end
 for _,obj in scene.objects do
  if obj.solid and inside(obj,x,y,z,r-0.00001) then return false end
 end
 return true
end
function M.blocked(scene: Scene, a: {number}, b: {number}, pad: number, light: boolean): boolean
 local terrain = scene.terrain
 if terrain and terrain.heightfield then
  local hit = Heightfield.sweep(terrain.heightfield,Vector3.new(a[1],a[2],a[3]),Vector3.new(b[1],b[2],b[3]),pad,1)
  if hit then return true end
 end
 if terrain ~= nil then
  local enter,exit = 0,1
  for axis = 1,2 do
   local d = b[axis]-a[axis]
   if math.abs(d) < 1e-12 then
    if a[axis] < 0 or a[axis] > scene.bounds[axis] then exit = -1; break end
   else
    local t1,t2 = -a[axis]/d,(scene.bounds[axis]-a[axis])/d
    if t1 > t2 then t1,t2 = t2,t1 end
    enter,exit = math.max(enter,t1),math.min(exit,t2)
   end
  end
  if enter <= exit then
   for _,p in terrain.planes do
    local offset = p[3]+(pad-0.00005)*math.sqrt(1+p[1]^2+p[2]^2)
    local da = a[3]-p[1]*a[1]-p[2]*a[2]
    local db = b[3]-p[1]*b[1]-p[2]*b[2]
    if da+(db-da)*enter < offset or da+(db-da)*exit < offset then return true end
   end
  end
 end
 local dx,dy,dz = b[1]-a[1],b[2]-a[2],b[3]-a[3]
 for _,obj in scene.objects do
  if (light and obj.opaque) or (not light and obj.solid) then
   if inside(obj,a[1],a[2],a[3],pad) then return true end
   if obj.shape == "sphere" then
    local mx,my,mz = a[1]-obj.center[1],a[2]-obj.center[2],a[3]-obj.center[3]
    local aa,bb = dx*dx+dy*dy+dz*dz,mx*dx+my*dy+mz*dz
    local cc = mx*mx+my*my+mz*mz-(obj.halfSize[1]+pad)^2
    local disc = bb*bb-aa*cc
    if aa >= 1e-16 and bb < 0 and disc >= 0 then
     local t = (-bb-math.sqrt(disc))/aa
     if t >= 0 and t <= 1 then return true end
    end
   else
    local enter,exit,miss = -math.huge,1,false
    for axis = 1,3 do
     local direction = b[axis]-a[axis]
     local lo,hi = obj.center[axis]-obj.halfSize[axis]-pad,obj.center[axis]+obj.halfSize[axis]+pad
     if math.abs(direction) < 1e-12 then
      if a[axis] <= lo or a[axis] >= hi then miss = true; break end
     else
      local t1,t2 = (lo-a[axis])/direction,(hi-a[axis])/direction
      if t1 > t2 then t1,t2 = t2,t1 end
      enter,exit = math.max(enter,t1),math.min(exit,t2)
      if enter > exit then miss = true; break end
     end
    end
    if not miss and enter >= 0 and enter <= 1 then return true end
   end
  end
 end
 return false
end
return M
