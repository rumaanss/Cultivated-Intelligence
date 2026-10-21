--!strict
-- v3.2: submerged rocky banks + supported shallow sand shelves inside the domain.
local Config = require(script.Parent:WaitForChild("WaterPresentationConfig"))
local M = {}
function M.new(parent: Instance, width: number, length: number, depth: number, _padding: number, sharedTerrain: boolean?)
 local island=game:GetService("Workspace"):FindFirstChild("CI_ReferenceIsland")
 if island ~= nil and island:GetAttribute("Ready") == true then
  return {Destroy=function() end}
 end
 assert(width>=32 and length>=32 and depth>=8, "Lake shoreline requires width/length >=32, depth >=8")
 local folder=Instance.new("Folder")
 folder.Name="LakeShoreline"
 folder:SetAttribute("VisualOnly",true)
 folder:SetAttribute("ShorelineBuild","3.2-sand-shelves")
 folder.Parent=parent
 local shore=math.min(Config.ShoreWidthStuds,width/8,length/8)
 local beach=shore*0.45
 local bank=shore-beach
 local top=2
 local shelfBottom=-3
 local rock=Color3.fromRGB(72,78,70)
 local sand=Color3.fromRGB(174,153,109)
 local function part(wedge: boolean,name: string,size: Vector3,cf: CFrame,material: Enum.Material,color: Color3,shadow: boolean): BasePart
  local p: BasePart
  if wedge then p=Instance.new("WedgePart") else p=Instance.new("Part") end
  p.Name=name; p.Size=size; p.CFrame=cf
  p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
  p.CastShadow=shadow; p.Material=material; p.Color=color; p.Parent=folder
  return p
 end
 -- Shared terrain replaces all interior decorative banks. The seal inner faces
 -- coincide with the C++ basin bounds; decorative thickness is outside the domain.
 if sharedTerrain == true then
  part(false,"NorthBoundary",Vector3.new(width+0.4,depth+top,0.2),CFrame.new(0,(top-depth)/2,-length/2-0.1),Enum.Material.Rock,rock,true)
  part(false,"SouthBoundary",Vector3.new(width+0.4,depth+top,0.2),CFrame.new(0,(top-depth)/2,length/2+0.1),Enum.Material.Rock,rock,true)
  part(false,"WestBoundary",Vector3.new(0.2,depth+top,length),CFrame.new(-width/2-0.1,(top-depth)/2,0),Enum.Material.Rock,rock,true)
  part(false,"EastBoundary",Vector3.new(0.2,depth+top,length),CFrame.new(width/2+0.1,(top-depth)/2,0),Enum.Material.Rock,rock,true)
  for _,p in folder:GetChildren() do if p:IsA("BasePart") then p.CanCollide=true; p.CanQuery=true end end
  return {Destroy=function() folder:Destroy() end}
 end
 local height=depth+top
 local cy=(top-depth)/2
 part(false,"NorthSeal",Vector3.new(width,height,0.4),CFrame.new(0,cy,-length/2+0.2),Enum.Material.Rock,rock,false)
 part(false,"SouthSeal",Vector3.new(width,height,0.4),CFrame.new(0,cy,length/2-0.2),Enum.Material.Rock,rock,false)
 part(false,"WestSeal",Vector3.new(0.4,height,length),CFrame.new(-width/2+0.2,cy,0),Enum.Material.Rock,rock,false)
 part(false,"EastSeal",Vector3.new(0.4,height,length),CFrame.new(width/2-0.2,cy,0),Enum.Material.Rock,rock,false)
 -- Each frame maps local +Z toward the outer shore. Tangential lengths exclude corners.
 local function side(name: string,origin: CFrame,tangent: number)
  local bankHeight=depth+shelfBottom
  part(true,name.."DeepBank",Vector3.new(tangent,bankHeight,bank),
   origin*CFrame.new(0,(shelfBottom-depth)/2,-shore+bank/2),Enum.Material.Rock,rock,true)
  -- A solid support joins the beach underside to the deep bank: no floating sand.
  part(false,name.."ShelfSupport",Vector3.new(tangent,bankHeight,beach),
   origin*CFrame.new(0,(shelfBottom-depth)/2,-beach/2),Enum.Material.Rock,rock,true)
  part(true,name.."SandBeach",Vector3.new(tangent,top-shelfBottom,beach),
   origin*CFrame.new(0,(top+shelfBottom)/2,-beach/2),Enum.Material.Sand,sand,true)
 end
 side("South",CFrame.new(0,0,length/2),width-2*shore)
 side("North",CFrame.new(0,0,-length/2)*CFrame.Angles(0,math.pi,0),width-2*shore)
 side("East",CFrame.new(width/2,0,0)*CFrame.Angles(0,math.pi/2,0),length-2*shore)
 side("West",CFrame.new(-width/2,0,0)*CFrame.Angles(0,-math.pi/2,0),length-2*shore)
 for _,x in {-1,1} do
  for _,z in {-1,1} do
   local px,pz=x*(width/2-shore/2),z*(length/2-shore/2)
   part(false,"CornerSupport",Vector3.new(shore,depth+shelfBottom,shore),CFrame.new(px,(shelfBottom-depth)/2,pz),Enum.Material.Rock,rock,true)
   part(false,"CornerSand",Vector3.new(shore,top-shelfBottom,shore),CFrame.new(px,(top+shelfBottom)/2,pz),Enum.Material.Sand,sand,true)
  end
 end
 local rng=Random.new(781)
 for edge=1,4 do
  for i=1,6 do
   local along=(i-3.5)/6*(if edge<=2 then width-2*shore else length-2*shore)
   local sx,sy,sz=rng:NextNumber(1.3,2.4),rng:NextNumber(0.8,1.5),rng:NextNumber(1.3,2.4)
   local x,z=along,0
   if edge==1 then z=-length/2+sz/2 elseif edge==2 then z=length/2-sz/2
   elseif edge==3 then x=-width/2+sx/2; z=along else x=width/2-sx/2; z=along end
   local b=part(false,"ShoreRock",Vector3.new(sx,sy,sz),CFrame.new(x,top-0.4,z),Enum.Material.Rock,rock,true)
   if b:IsA("Part") then b.Shape=Enum.PartType.Ball end
  end
 end
 local destroyed=false
 return { Destroy=function() if not destroyed then destroyed=true; folder:Destroy() end end }
end
return M

