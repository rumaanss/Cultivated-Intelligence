--!strict
-- Bounded, anchored scenery. Reusable procedural forms, no external asset IDs.
local C=require(script.Parent.IslandConfig)
local F=require(script.Parent.IslandField)
local M={}
local function part(parent: Instance,name: string,size: Vector3,cf: CFrame,color: Color3,material: Enum.Material,shape: Enum.PartType?): Part
 local p=Instance.new("Part")
 p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color;p.Material=material
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
 p.CastShadow=name=="Trunk" or name=="Crown" or name=="Boulder"
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 if shape then p.Shape=shape end
 p.Parent=parent;return p
end
function M.build(parent: Instance)
 local rng=Random.new(C.Seed)
 local trees=Instance.new("Folder");trees.Name="Woodland";trees.Parent=parent
 local rocks=Instance.new("Folder");rocks.Name="RockClusters";rocks.Parent=parent
 local plants=Instance.new("Folder");plants.Name="Understory";plants.Parent=parent
 local treeCount,rockCount,plantCount=0,0,0
 -- Separate minimum-distance tests keep crowns from forming an opaque carpet.
 local occupied: {Vector3}={}
 for attempt=1,6500 do
  local x,z=rng:NextNumber(C.MinX+60,C.MaxX-60),rng:NextNumber(C.MinZ+60,C.MaxZ-60)
  local h,material,slope=F.sample(x,z)
  if h<5 or F.protected(x,z) or F.coast(x,z)<12 then continue end
  local p=Vector3.new(x,h,z)
  local woodland=math.noise(x/125,z/125,C.Seed+27)
  if treeCount<C.TreeBudget and slope<0.38 and h<73 and woodland> -0.04 then
   local clear=true
   for _,q in occupied do if (p-q).Magnitude<20 then clear=false;break end end
   if clear then
    table.insert(occupied,p);treeCount+=1
    local model=Instance.new("Model");model.Name="CoastalTree_"..treeCount;model.Parent=trees
    local size=rng:NextNumber(0.8,1.5);local height=rng:NextNumber(14,21)*size
    local frame=CFrame.new(p)*CFrame.Angles(0,rng:NextNumber(0,math.pi*2),0)
    part(model,"Trunk",Vector3.new(height,1.5*size,1.5*size),frame*CFrame.new(0,height/2-1,0)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(91,76,55),Enum.Material.Wood,Enum.PartType.Cylinder)
    for j=1,3 do
     local angle=j*math.pi*2/3
     local color=Color3.fromRGB(rng:NextInteger(62,84),rng:NextInteger(91,117),rng:NextInteger(43,64))
     part(model,"Crown",Vector3.new(12*size,7*size,10*size),frame*CFrame.new(math.cos(angle)*3*size,height-2+(j%2)*2,math.sin(angle)*3*size),color,Enum.Material.Grass,Enum.PartType.Ball)
    end
   end
  elseif rockCount<C.RockBudget and (slope>0.32 or woodland< -0.08) then
   rockCount+=1
   local model=Instance.new("Model");model.Name="Outcrop_"..rockCount;model.Parent=rocks
   local scale=rng:NextNumber(3,8)
   for j=1,2 do
    local rx,rz=x+(j-1)*scale*0.55,z+(j-1)*scale*0.3
    local rh=F.height(rx,rz)
    local cf=CFrame.new(rx,rh+scale*0.18,rz)*CFrame.Angles(rng:NextNumber(-0.25,0.25),rng:NextNumber(0,6.28),rng:NextNumber(-0.2,0.2))
    part(model,"Boulder",Vector3.new(scale*1.4,scale*0.8,scale),cf,Color3.fromRGB(101+j*5,107+j*4,97+j*4),Enum.Material.Rock,Enum.PartType.Ball)
   end
  elseif plantCount<C.PlantBudget and slope<0.35 then
   plantCount+=1
   local frame=CFrame.new(x,h,z)*CFrame.Angles(0,rng:NextNumber(0,6.28),0)
   for j=1,3 do
    part(plants,"Shrub",Vector3.new(2.4,1.8,2.2),frame*CFrame.new((j-2)*1.1,0.7,math.sin(j)*0.8),Color3.fromRGB(88,112+j*4,58),Enum.Material.Grass,Enum.PartType.Ball)
   end
  end
  if attempt%400==0 then task.wait() end
  if treeCount>=C.TreeBudget and rockCount>=C.RockBudget and plantCount>=C.PlantBudget then break end
 end
 parent:SetAttribute("Trees",treeCount);parent:SetAttribute("RockClusters",rockCount);parent:SetAttribute("Shrubs",plantCount)
end
return M
