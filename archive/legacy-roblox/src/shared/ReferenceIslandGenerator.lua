--!strict
-- Studio edit-mode builder. Writes only empty terrain outside the protected pond.
-- No Clear(), external downloads, Lighting writes, or simulation changes.
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local Http=game:GetService("HttpService")
local C=require(script.Parent.IslandConfig)
local F=require(script.Parent.IslandField)
local Vegetation=require(script.Parent.IslandVegetation)
local M={}
local NAME="CI_ReferenceIsland"
local busy=false
local materialMap: {[string]: Enum.Material}={Grass=Enum.Material.Grass,LeafyGrass=Enum.Material.LeafyGrass,Ground=Enum.Material.Ground,Rock=Enum.Material.Rock,Sand=Enum.Material.Sand}
local terrainInstance=Workspace:FindFirstChildOfClass("Terrain")
assert(terrainInstance~=nil and terrainInstance:IsA("Terrain"),"Workspace Terrain is unavailable")
local terrain: Terrain=terrainInstance
local function eachChunk(callback: (Region3,number,number)->())
 for x=C.MinX,C.MaxX-C.ChunkSize,C.ChunkSize do
  for z=C.MinZ,C.MaxZ-C.ChunkSize,C.ChunkSize do
   callback(Region3.new(Vector3.new(x,C.Bottom,z),Vector3.new(x+C.ChunkSize,C.Top,z+C.ChunkSize)),x,z)
   task.wait()
  end
 end
end
local function cell(h: number,surface: Enum.Material,y: number,waterLevel: number): (Enum.Material,number)
 local occupancy=math.clamp((h-y+2)/4,0,1)
 if occupancy>0 then
  return if y<h-7 then Enum.Material.Rock else surface,occupancy
 end
 if y<waterLevel then return Enum.Material.Water,1 end
 return Enum.Material.Air,0
end
local function removeOwned()
 local folder=Workspace:FindFirstChild(NAME)
 assert(folder~=nil,"No generated island to remove")
 -- Reconstruct only chunks actually written, including interrupted builds.
 for _,record in folder:GetChildren() do
  if record:IsA("Folder") and record.Name=="WrittenChunk" then
   local x,z=record:GetAttribute("X"),record:GetAttribute("Z")
   local bottom,top=record:GetAttribute("Bottom"),record:GetAttribute("Top")
   local size,water=record:GetAttribute("Size"),record:GetAttribute("Water")
   local encoded=record:GetAttribute("Columns")
   assert(typeof(x)=="number" and typeof(z)=="number" and typeof(bottom)=="number" and typeof(top)=="number")
   assert(typeof(size)=="number" and typeof(water)=="number" and typeof(encoded)=="string")
   local columns=Http:JSONDecode(encoded)
   local region=Region3.new(Vector3.new(x,bottom,z),Vector3.new(x+size,top,z+size))
   local materials,occupancy=terrain:ReadVoxels(region,4)
   local index=0
   for ix=1,#materials do for iz=1,#materials[ix][1] do
    index+=1
    local column=columns[index]
    if column[2]=="Protected" then continue end
    for iy=1,#materials[ix] do
     local expected,amount=cell(column[1],materialMap[column[2]],bottom+(iy-0.5)*4,water)
     if materials[ix][iy][iz]==expected and math.abs(occupancy[ix][iy][iz]-amount)<0.005 then
      materials[ix][iy][iz]=Enum.Material.Air;occupancy[ix][iy][iz]=0
     end
    end
   end end
   terrain:WriteVoxels(region,4,materials,occupancy)
   task.wait()
  end
 end
 folder:Destroy()
end
function M.Remove()
 assert(not RunService:IsRunning(),"Stop Play before removing the island")
 assert(not busy,"Island operation already running")
 busy=true
 local ok,err=pcall(removeOwned)
 busy=false
 if not ok then error(err) end
 print("[Island] Generated terrain removed; pond preserved.")
end
function M.Generate()
 assert(not RunService:IsRunning(),"Run this command in Studio EDIT mode, before Play")
 assert(not busy,"Island operation already running")
 assert(Workspace:FindFirstChild(NAME)==nil,"Island already exists. Call .Remove() before regenerating.")
 assert(C.Resolution==4 and C.ChunkSize%4==0,"Terrain uses four-stud voxels")
 assert((C.MaxX-C.MinX)%C.ChunkSize==0 and (C.MaxZ-C.MinZ)%C.ChunkSize==0,"Bounds must contain whole chunks")
 assert(C.MinX%4==0 and C.MinZ%4==0 and C.Bottom%4==0 and C.Top%4==0,"Bounds must align to voxels")
 assert(C.ProtectedHalfSize>=52 and C.WaterLevel==0,"Keep the existing pond protected and its water level at zero")
 busy=true
 local ok,err=pcall(function()
  print("[Island] Checking empty terrain outside the existing pond...")
  -- Complete preflight before the first write. Never erase unrelated authored terrain.
  eachChunk(function(region,x,z)
   local materials,occupancy=terrain:ReadVoxels(region,4)
   for ix=1,#materials do for iz=1,#materials[ix][1] do
    if F.protected(x+(ix-0.5)*4,z+(iz-0.5)*4) then continue end
    for iy=1,#materials[ix] do
     assert(occupancy[ix][iy][iz]==0,"Existing terrain found outside pond. Move it or use a clean copy of the place; nothing was overwritten.")
    end
   end end
  end)
  local folder=Instance.new("Folder");folder.Name=NAME
  folder:SetAttribute("Seed",C.Seed);folder:SetAttribute("Ready",false)
  folder:SetAttribute("SceneryOnly",true);folder.Parent=Workspace
  local count=0
  local total=(C.MaxX-C.MinX)*(C.MaxZ-C.MinZ)/(C.ChunkSize*C.ChunkSize)
  eachChunk(function(region,x,z)
   local materials,occupancy=terrain:ReadVoxels(region,4)
   local columns: {{any}}={}
   for ix=1,#materials do for iz=1,#materials[ix][1] do
    local wx,wz=x+(ix-0.5)*4,z+(iz-0.5)*4
    if F.protected(wx,wz) then table.insert(columns,{0,"Protected"});continue end
    local h,kind=F.sample(wx,wz)
    table.insert(columns,{h,kind})
    for iy=1,#materials[ix] do
     assert(occupancy[ix][iy][iz]==0,"Terrain changed during generation. Build stopped before overwriting this chunk.")
     local mat,amount=cell(h,materialMap[kind],C.Bottom+(iy-0.5)*4,C.WaterLevel)
     materials[ix][iy][iz]=mat;occupancy[ix][iy][iz]=amount
    end
   end end
   -- Persist the exact generated columns so removal survives future config edits.
   local record=Instance.new("Folder");record.Name="WrittenChunk"
   record:SetAttribute("X",x);record:SetAttribute("Z",z)
   record:SetAttribute("Bottom",C.Bottom);record:SetAttribute("Top",C.Top)
   record:SetAttribute("Size",C.ChunkSize);record:SetAttribute("Water",C.WaterLevel)
   record:SetAttribute("Columns",Http:JSONEncode(columns));record.Parent=folder
   terrain:WriteVoxels(region,4,materials,occupancy)
   count+=1
   if count%30==0 then print("[Island] Terrain chunks built: "..count.." / "..total) end
  end)
  print("[Island] Planting woodland and placing rock clusters...")
  Vegetation.build(folder)
  -- Two-stud water seam outside the original 100x100 water. Never covers its center.
  for _,edge in {{0,-51,100,2},{0,51,100,2},{-51,0,2,104},{51,0,2,104}} do
   local p=Instance.new("Part");p.Name="PondWaterJoin"
   p.Size=Vector3.new(edge[3],0.1,edge[4]);p.Position=Vector3.new(edge[1],-0.05,edge[2])
   p.Material=Enum.Material.Glass;p.Color=Color3.fromRGB(64,132,149);p.Transparency=0.48
   p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=folder
  end
  folder:SetAttribute("Ready",true)
  local camera=Workspace.CurrentCamera
  if camera then camera.CFrame=CFrame.lookAt(Vector3.new(750,900,1050),Vector3.new(120,0,-80)) end
  print("[Island] COMPLETE. Enable Terrain.Decoration in Properties for animated grass. Save the place, then Play.")
 end)
 busy=false
 if not ok then
  warn("[Island] Build stopped: "..tostring(err)..". If an island marker exists, call .Remove() to remove completed chunks before retrying.")
  error(err)
 end
end
return M
