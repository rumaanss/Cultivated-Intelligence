--!strict
-- Client visual ownership: remove only native water inside the custom pond
-- surface's domain. Solid terrain is never changed. Restore on teardown.
local Workspace=game:GetService("Workspace")
local M={}
function M.suspend(width:number,length:number,depth:number):()->()
 local terrain=Workspace.Terrain :: Terrain
 local region=Region3.new(Vector3.new(-width/2,-depth,-length/2),Vector3.new(width/2,0,length/2)):ExpandToGrid(4)
 local materials,occupancy=terrain:ReadVoxels(region,4)
 local saved:{{number}}={}
 local joins:{BasePart}={}
 for _,part in Workspace:GetDescendants() do
  if part:IsA("BasePart") and part.Name=="PondWaterJoin" then part.LocalTransparencyModifier=1;table.insert(joins,part) end
 end
 for x,slab in materials do for y,row in slab do for z,material in row do
  if material==Enum.Material.Water then
   table.insert(saved,{x,y,z,occupancy[x][y][z]})
   materials[x][y][z]=Enum.Material.Air;occupancy[x][y][z]=0
  end
 end end end
 if #saved>0 then terrain:WriteVoxels(region,4,materials,occupancy) end
 local restored=false
 return function()
  if restored then return end;restored=true
  for _,part in joins do if part.Parent then part.LocalTransparencyModifier=0 end end
  if #saved==0 then return end
  local current,amount=terrain:ReadVoxels(region,4)
  for _,cell in saved do
   local x,y,z=cell[1],cell[2],cell[3]
   if current[x][y][z]==Enum.Material.Air and amount[x][y][z]==0 then
    current[x][y][z]=Enum.Material.Water;amount[x][y][z]=cell[4]
   end
  end
  terrain:WriteVoxels(region,4,current,amount)
 end
end
return M
