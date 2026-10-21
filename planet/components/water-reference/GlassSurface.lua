--!nonstrict
-- Adaptation of the accepted CI v5 GlassReference renderer to a radial region.
local Surface={}
function Surface.new(state)
 local radius=state:GetAttribute('Radius');local center=state:GetAttribute('Center')
 local up=state:GetAttribute('Up');local east=state:GetAttribute('East');local north=state:GetAttribute('North')
 local floors=game:GetService('HttpService'):JSONDecode(state:WaitForChild('FloorMap').Value)
 local frame=CFrame.fromMatrix(center+up*radius,east,up,-north)
 local root=Instance.new('Folder');root.Name='CI_GlassLake';root:SetAttribute('Renderer','GlassReference');root.Parent=workspace
 local fallback=Instance.new('Folder');fallback.Name='StaticGlassFallback';fallback.Parent=root
 local alive=true;local editable=nil;local meshPart=nil;local vertices={};local connection=nil
 local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
 for key in pairs(floors) do
  local i,j=string.match(key,'(-?%d+),(-?%d+)');i=tonumber(i)*4;j=tonumber(j)*4
  minX=math.min(minX,i);maxX=math.max(maxX,i);minZ=math.min(minZ,j);maxZ=math.max(maxZ,j)
 end
 local function elevation(x,z) return floors[tostring(math.floor(x/4+.5))..','..tostring(math.floor(z/4+.5))] or 24 end
 local function base(x,z,h)return Vector3.new(x,radius,-z).Unit*(radius+(h or 0))-Vector3.yAxis*radius end
 local function decorate(part)
  part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
  part.Material=Enum.Material.Glass;part.Color=Color3.fromRGB(64,132,149)
  part.Transparency=.48;part.Reflectance=.045
 end
 local function faces(step,emit)
  local function clip(a,b,c)
   local polygon={a,b,c};local result={}
   for index,p in ipairs(polygon)do
    local q=polygon[index%3+1];local dp,dq=2-p[3],2-q[3]
    if dp>=0 then table.insert(result,p)end
    if (dp>=0)~=(dq>=0)then
     local t=dp/(dp-dq);table.insert(result,{p[1]+(q[1]-p[1])*t,p[2]+(q[2]-p[2])*t,2})
    end
   end
   for i=2,#result-1 do
    local a,b,c=result[1],result[i],result[i+1]
    local area=(b[1]-a[1])*(c[2]-a[2])-(b[2]-a[2])*(c[1]-a[1])
    if math.abs(area)>1e-6 then emit(a,b,c)end
   end
  end
  for x=math.floor(minX/step)*step-step,math.ceil(maxX/step)*step,step do
   for z=math.floor(minZ/step)*step-step,math.ceil(maxZ/step)*step,step do
    local a={x,z,elevation(x,z)};local b={x+step,z,elevation(x+step,z)}
    local c={x,z+step,elevation(x,z+step)};local d={x+step,z+step,elevation(x+step,z+step)}
    clip(a,b,c);clip(b,d,c)
   end
  end
 end
 local function wedgeTriangle(pa,pb,pc)
  local a,b,c=base(pa[1],pa[2]),base(pb[1],pb[2]),base(pc[1],pc[2])
  local ab,ac,bc=b-a,c-a,c-b
  if ab:Dot(ab)>ac:Dot(ac) and ab:Dot(ab)>bc:Dot(bc)then a,c=c,a
  elseif ac:Dot(ac)>bc:Dot(bc)then a,b=b,a end
  ab,ac,bc=b-a,c-a,c-b
  local cross=ac:Cross(ab);if cross.Magnitude<1e-6 then return end
  local right,back=cross.Unit,bc.Unit;local vertical=back:Cross(right).Unit
  local height=math.abs(ab:Dot(vertical));local normal=if right.Y>=0 then right else -right
  local function wedge(mid,x,z,length)
   if height<.001 or length<.001 then return end
   local part=Instance.new('WedgePart');part.Name='GlassSurfaceFacet'
   part.Size=Vector3.new(.01,height,length);part.CFrame=frame*CFrame.fromMatrix(mid-normal*.005,x,vertical,z)
   decorate(part);part.Parent=fallback
  end
  wedge((a+b)/2,right,back,math.abs(ab:Dot(back)))
  wedge((a+c)/2,-right,-back,math.abs(ac:Dot(back)))
 end
 faces(16,wedgeTriangle)
 root:SetAttribute('SurfaceMode','StaticGlassFallback')
 local function wave(x,z,t,floor)
  -- Same wave spectrum as the accepted old renderer; fade into the irregular bank.
  local h,dx,dz=Waves.sample(x,z,t,1,1)
  local fade=math.clamp(-floor/8,0,1);fade=fade*fade*(3-2*fade)
  return h*fade,dx*fade,dz*fade
 end
 task.spawn(function()
  local pending=nil;local part=nil
  local ok,err=pcall(function()
   pending=assert(game:GetService('AssetService'):CreateEditableMesh(),'EditableMesh unavailable')
   local cache={}
   local function vertex(p)
    local key=string.format('%.5f:%.5f',p[1],p[2]);if cache[key]then return cache[key]end
    local v={x=p[1],z=p[2],floor=p[3]}
    local h,dx,dz=wave(v.x,v.z,0,v.floor)
    v.id=pending:AddVertex(base(v.x,v.z,h))
    v.normal=pending:AddNormal((Vector3.new(v.x,radius,-v.z).Unit+Vector3.new(-dx,0,dz)).Unit)
    cache[key]=v;table.insert(vertices,v);return v
   end
   faces(4,function(pa,pb,pc)
    local a,b,c=vertex(pa),vertex(pb),vertex(pc)
    local face=pending:AddTriangle(a.id,b.id,c.id)
    pending:SetFaceNormals(face,{a.normal,b.normal,c.normal})
   end)
   assert(alive,'Renderer disposed during creation')
   part=game:GetService('AssetService'):CreateMeshPartAsync(Content.fromObject(pending),{CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Automatic})
   assert(alive,'Renderer disposed during creation')
   part.Name='GlassReference';part.CFrame=frame;part.DoubleSided=true;decorate(part)
   -- No SurfaceAppearance: preserve the accepted Glass response.
   part.Parent=root;editable=pending;meshPart=part;fallback:Destroy()
   root:SetAttribute('SurfaceMode','AnimatedGlass');root:SetAttribute('VertexCount',#vertices)
   local elapsed,accumulated=0,0
   local averageDt,slowSeconds,fastSeconds,throttled=1/60,0,0,false
   connection=game:GetService('RunService').Heartbeat:Connect(function(dt)
    if not alive or dt<=0 or dt~=dt then return end
    elapsed+=math.min(dt,.25);accumulated+=dt
    averageDt+=(math.min(dt,.1)-averageDt)*(1-math.exp(-dt/1.5))
    if averageDt>1/43 then slowSeconds+=dt;fastSeconds=0
    elseif averageDt<1/55 then fastSeconds+=dt;slowSeconds=0
    else slowSeconds=0;fastSeconds=0 end
    if slowSeconds>1.5 then throttled=true end
    if fastSeconds>5 then throttled=false end
    local camera=workspace.CurrentCamera;if not camera then return end
    local distance=(camera.CFrame.Position-(center+up*radius)).Magnitude
    if distance>650 then return end
    local hz=if throttled or distance>140 then 15 else 30
    if accumulated<1/hz then return end;accumulated%=1/hz
    for _,v in ipairs(vertices)do
     local h,dx,dz=wave(v.x,v.z,elapsed,v.floor)
     editable:SetPosition(v.id,base(v.x,v.z,h))
     editable:SetNormal(v.normal,(Vector3.new(v.x,radius,-v.z).Unit+Vector3.new(-dx,0,dz)).Unit)
    end
   end)
  end)
  if not ok then
   if part then part:Destroy()end;if pending then pending:Destroy()end
   table.clear(vertices)
   if alive then root:SetAttribute('SurfaceMode','StaticGlassFallback');warn('[CI Water] Animated Glass unavailable; static Glass remains: '..tostring(err))end
  end
 end)
 return {Destroy=function()
  if not alive then return end;alive=false
  if connection then connection:Disconnect()end
  if meshPart then meshPart:Destroy()end;if editable then editable:Destroy()end
  root:Destroy();table.clear(vertices)
 end}
end
return Surface
