--!nonstrict
local Catalog=require(script.Parent.CelestialCatalog)
local M={}
function M.new(parent,center,radius,east,up)
 local Asset=game:GetService("AssetService")
 local holder=Instance.new("Folder");holder.Name="CelestialModels";holder.Parent=parent
 local bodies={};local stopped=false;local generation=0
 local function destroy()
  if stopped then return end;stopped=true
  for _,b in bodies do if b.part then b.part:Destroy()end;if b.mesh then b.mesh:Destroy()end end
  holder:Destroy()
 end
 local ok,err=pcall(function()
  for index,definition in Catalog.Bodies do
   local mesh=Asset:CreateEditableMesh();assert(mesh,"Celestial mesh budget unavailable")
   local b={mesh=mesh,definition=definition,vertices={}};table.insert(bodies,b)
   local rings=if definition.kind=="asteroid" then 6 else 12
   local sectors=if definition.kind=="asteroid" then 10 else 24
   local ids,colors,normals={},{},{}
   for j=0,rings do
    ids[j]={};colors[j]={};normals[j]={}
    for i=0,sectors-1 do
     local latitude=math.pi*j/rings;local longitude=2*math.pi*i/sectors
     local n=Vector3.new(math.sin(latitude)*math.cos(longitude),math.cos(latitude),math.sin(latitude)*math.sin(longitude))
     local scale=if definition.kind=="asteroid" then 1+.18*math.noise(n.X*3+index,n.Y*3,n.Z*3)else 1
     ids[j][i]=mesh:AddVertex(n*scale)
     local base=Catalog.surface(definition,n)
     colors[j][i]=mesh:AddColor(base,1);normals[j][i]=mesh:AddNormal(n)
     table.insert(b.vertices,{normal=n,color=colors[j][i],base=base})
    end
   end
   local function triangle(j1,i1,j2,i2,j3,i3)
    local f=mesh:AddTriangle(ids[j1][i1],ids[j2][i2],ids[j3][i3])
    mesh:SetFaceColors(f,{colors[j1][i1],colors[j2][i2],colors[j3][i3]})
    mesh:SetFaceNormals(f,{normals[j1][i1],normals[j2][i2],normals[j3][i3]})
   end
   for j=0,rings-1 do for i=0,sectors-1 do
    local nextI=(i+1)%sectors
    if j>0 then triangle(j,i,j,nextI,j+1,i)end
    if j<rings-1 then triangle(j,nextI,j+1,nextI,j+1,i)end
   end end
   -- Compact immutable topology before retaining the mesh for color updates.
   local result,baked=Asset:CreateDataModelContentAsync(Content.fromObject(mesh))
   assert(result==Enum.CreateContentResult.Success,"Celestial mesh conversion failed: "..tostring(result))
   local compact=Asset:CreateEditableMeshAsync(baked,{FixedSize=true})
   assert(compact,"Celestial compact mesh allocation failed")
   b.mesh=compact;mesh:Destroy();mesh=compact
   -- Stable IDs may change during conversion: remap retained color/normal data.
   -- Rebuild shading references using the compact mesh's actual color IDs.
   b.vertices={}
   for _,colorId in compact:GetColors()do
    local vertices=compact:GetVerticesWithColor(colorId)
    if #vertices>0 then
     local n=compact:GetPosition(vertices[1]).Unit
     table.insert(b.vertices,{normal=n,color=colorId,base=compact:GetColor(colorId)})
    end
   end
   assert(#b.vertices>0,"Celestial color attributes were not preserved")
   local part=Asset:CreateMeshPartAsync(Content.fromObject(mesh),{CollisionFidelity=Enum.CollisionFidelity.Box})
   b.part=part;part.Name=definition.id;part.Anchored=true
   part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
   part.DoubleSided=true;part.Material=Enum.Material.Neon;part.Color=Color3.new(1,1,1)
   part.Transparency=1;part:SetAttribute("VisualOnly",true);part.Parent=holder
   -- Yield between bodies during initialization; no per-tick creation afterwards.
   task.wait()
  end
 end)
 if not ok then destroy();return nil,tostring(err)end
 holder:SetAttribute("CatalogVersion",Catalog.Version);holder:SetAttribute("Seed",Catalog.Seed)
 local workBody,workVertex=1,1;local lastShade=-math.huge;local lightingJob=nil
 local peak=0;local lastMetrics=-math.huge
 return {
  Update=function(position,cycles,sun,waterBlend,now)
   if stopped then return end
   local start=os.clock();local offset=position-center;local localUp=offset.Unit
   local altitude=math.max(0,offset.Magnitude-radius)
   local horizon=-math.sqrt(math.max(0,1-(radius/(radius+altitude))^2))
   local day=math.clamp((sun:Dot(localUp)+.12)/.35,0,1)
   for index,b in bodies do
    local direction,angular=Catalog.apparent(b.definition,cycles,east,up,offset/radius)
    local actualDistance=(Catalog.position(b.definition,cycles,east,up)-offset/radius).Magnitude
    local distance=math.max(Catalog.DisplayDistance,offset.Magnitude+radius*2)+actualDistance*2
    b.part.Size=Vector3.one*math.min(2048,2*distance*math.tan(angular))
    b.part.CFrame=CFrame.new(position+direction*distance)*CFrame.Angles(.2,cycles*b.definition.spin*2*math.pi,0)
    local visible=math.clamp((direction:Dot(localUp)-horizon+math.sin(angular))/(2*math.sin(angular)),0,1)
    local atmosphere=math.clamp((direction:Dot(localUp)-horizon)*3+.25,.25,1)
    b.part.Transparency=1-visible*(1-math.clamp(waterBlend,0,1))*(1-.45*day)*(atmosphere)
   end
   if not lightingJob and now-lastShade>=.2 then
    lightingJob={}
    for i,b in bodies do lightingJob[i]=b.part.CFrame:VectorToObjectSpace(sun)end
    workBody,workVertex=1,1
   end
   if lightingJob then
    -- Never shade more than 64 vertices in one call. No dynamic lights or physics.
    for _=1,64 do
     local b=bodies[workBody];local v=b.vertices[workVertex]
     local light=.035+.65*math.max(0,v.normal:Dot(lightingJob[workBody]))
     b.mesh:SetColor(v.color,Color3.new(v.base.R*light,v.base.G*light,v.base.B*light))
     workVertex+=1
     if workVertex>#b.vertices then workBody+=1;workVertex=1 end
     if workBody>#bodies then lightingJob=nil;lastShade=now;generation+=1;break end
     if os.clock()-start>.00075 then break end
    end
   end
   local ms=(os.clock()-start)*1000;peak=math.max(peak,ms)
   if now-lastMetrics>=.5 then
    lastMetrics=now;holder:SetAttribute("UpdateMs",ms);holder:SetAttribute("MaxUpdateMs",peak);holder:SetAttribute("ShadingGeneration",generation)
   end
  end,
  Destroy=destroy,
 }
end
return M
