--!strict
-- Convex water region: z >= max(a*x+b*y+c). Clip each plane's visible facet.
-- Each facet is tessellated into static wedge pairs; no EditableMesh permission.
local Geometry = require(script.Parent.SharedGeometry)
local Space = require(script.Parent.SimulationSpace)
local Style = require(script.Parent.TerrainVisualConfig)
local M = {}
type Point = {number}
function M.facets(scene: Geometry.Scene): {{Point}}
 local terrain = scene.terrain
 local result: {{Point}} = {}
 if terrain == nil then return result end
 if terrain.heightfield then
  local f=terrain.heightfield
  -- The uploaded place already renders the outer native terrain. Fill only its
  -- deliberately empty protected core with the same collision triangles.
  for y=0,f.ny-2 do for x=0,f.nx-2 do
   local wx,wz=(x+.5)*f.cell-scene.bounds[1]/2,(y+.5)*f.cell-scene.bounds[2]/2
   if math.abs(wx)<52 and math.abs(wz)<52 then
    local function v(dx:number,dy:number):Point return {(x+dx)*f.cell,(y+dy)*f.cell,f.heights[(y+dy)*f.nx+x+dx+1]} end
    table.insert(result,{v(0,0),v(1,0),v(0,1)})
    table.insert(result,{v(1,0),v(1,1),v(0,1)})
   end
  end end
  return result
 end
 for i,p in terrain.planes do
  local polygon: {Point} = {{0,0},{100,0},{100,100},{0,100}}
  for j,q in terrain.planes do
   if i == j then continue end
   local clipped: {Point} = {}
   for k,a in polygon do
    local b = polygon[k%#polygon+1]
    local da = (p[1]-q[1])*a[1]+(p[2]-q[2])*a[2]+p[3]-q[3]
    local db = (p[1]-q[1])*b[1]+(p[2]-q[2])*b[2]+p[3]-q[3]
    if da >= 0 then table.insert(clipped,a) end
    if (da >= 0) ~= (db >= 0) then
     local t = da/(da-db)
     table.insert(clipped,{a[1]+t*(b[1]-a[1]),a[2]+t*(b[2]-a[2])})
    end
   end
   polygon = clipped
   if #polygon == 0 then break end
  end
  local face: {Point} = {}
  for _,v in polygon do table.insert(face,{v[1],v[2],p[1]*v[1]+p[2]*v[2]+p[3]}) end
  table.insert(result,face)
 end
 return result
end
local function triangle(a: Vector3,b: Vector3,c: Vector3,parent: Instance,id: number,material: Enum.Material,color: Color3)
 local ab,ac,bc = b-a,c-a,c-b
 -- Longest edge becomes BC so its altitude falls inside that edge.
 if ab:Dot(ab) > ac:Dot(ac) and ab:Dot(ab) > bc:Dot(bc) then a,c = c,a
 elseif ac:Dot(ac) > bc:Dot(bc) then a,b = b,a end
 ab,ac,bc = b-a,c-a,c-b
 local cross = ac:Cross(ab)
 if cross.Magnitude < 0.000001 then return end
 local right,back = cross.Unit,bc.Unit
 local up = back:Cross(right).Unit
 local height = math.abs(ab:Dot(up))
 local normal = if right.Y >= 0 then right else -right
 local offset = normal * -0.05 -- Upper face coincides with the physical plane.
 local function wedge(mid: Vector3,x: Vector3,z: Vector3,length: number)
  if height < 0.001 or length < 0.001 then return end
  local part = Instance.new("WedgePart")
  part.Name = "LakebedFacet_"..tostring(id)
  part.Size = Vector3.new(0.1,height,length)
  part.CFrame = CFrame.fromMatrix(mid+offset,x,up,z)
  part.Anchored,part.CanCollide,part.CanTouch = true,true,false
  part.CanQuery,part.CastShadow = true,true
  part.Material = material
  part.Color = color
  part:SetAttribute("TerrainFacet",id)
  part:SetAttribute("Source","C++Recording")
  part.Parent = parent
 end
 wedge((a+b)/2,right,back,math.abs(ab:Dot(back)))
 wedge((a+c)/2,-right,-back,math.abs(ac:Dot(back)))
end
-- Clip in simulation XY; interpolating Z keeps every vertex on the source plane.
local function clip(face: {Point},axis: number,bound: number,sign: number): {Point}
 local out: {Point} = {}
 for i,a in face do
  local b=face[i%#face+1]
  local da,db=(a[axis]-bound)*sign,(b[axis]-bound)*sign
  if da>=0 then table.insert(out,a) end
  if (da>=0)~=(db>=0) then
   local t=da/(da-db)
   table.insert(out,{a[1]+t*(b[1]-a[1]),a[2]+t*(b[2]-a[2]),a[3]+t*(b[3]-a[3])})
  end
 end
 return out
end
function M.style(x: number,y: number,z: number,slope: number): (Enum.Material,Color3)
 local sediment=math.noise(x/Style.PatchScale,y/Style.PatchScale,Style.Seed)
 local band=math.noise(x/9,y/9,Style.Seed+17)
 local shallow=math.clamp(z/Space.Bounds.depth,0,1)
 local material=Enum.Material.Sand
 local color=Style.DeepSilt:Lerp(Style.ShallowSand,shallow)
 if slope>Style.RockSlope or (slope>0.35 and sediment>0.12) then
  material=Enum.Material.Rock
  color=Style.DeepRock:Lerp(Style.ShallowRock,shallow)
 elseif sediment< -0.12 then
  material=Enum.Material.Ground
  color=color:Lerp(Style.Silt,0.4)
 end
 local tint=math.clamp(0.5+band,0,1)*Style.ColorVariation
 return material,color:Lerp(Style.WarmSediment,tint)
end
function M.create(scene: Geometry.Scene,parent: Instance,detailed: boolean?): Folder
 local folder = Instance.new("Folder")
 folder.Name = "Lakebed"
 folder:SetAttribute("TerrainStyle","NaturalBasin2")
 local terrain=scene.terrain
 local function emit(face: {Point},id: number)
  if #face<3 then return end
  local x,y,z=0,0,0
  for _,v in face do x+=v[1];y+=v[2];z+=v[3] end
  local plane=if terrain and not terrain.heightfield then terrain.planes[id] else {0,0,0}
  local material,color=M.style(x/#face,y/#face,z/#face,math.sqrt(plane[1]^2+plane[2]^2))
  local a=Space.toRobloxXYZ(face[1][1],face[1][2],face[1][3])
  for i=2,#face-1 do
   local b,c=face[i],face[i+1]
   triangle(a,Space.toRobloxXYZ(b[1],b[2],b[3]),Space.toRobloxXYZ(c[1],c[2],c[3]),folder,id,material,color)
  end
 end
 for id,face in M.facets(scene) do
  if detailed==false or (terrain and terrain.heightfield) then emit(face,id);continue end
  for x=0,100-Style.CellSize,Style.CellSize do
   for y=0,100-Style.CellSize,Style.CellSize do
    local cell=clip(clip(clip(clip(face,1,x,1),1,x+Style.CellSize,-1),2,y,1),2,y+Style.CellSize,-1)
    emit(cell,id)
   end
  end
 end
 folder:SetAttribute("PartCount",#folder:GetChildren())
 folder.Parent = parent
 return folder
end
M.triangle = triangle
return M
