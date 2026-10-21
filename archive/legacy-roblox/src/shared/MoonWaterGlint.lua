--!strict
-- Bounded view-dependent visual approximation. No illumination or biological energy.
local Asset=game:GetService("AssetService")
local Lighting=game:GetService("Lighting")
local Workspace=game:GetService("Workspace")
local Art=require(script.Parent.SkyArtConfig)
local Rework=require(script.Parent.LightingReworkConfig)
local Config=require(script.Parent.WaterPresentationConfig)
local Waves=require(script.Parent.WaterWaveMath)
local Math=require(script.Parent.WaterPresentationMath)
local M={}
function M.new(parent:Instance,width:number,length:number,surfaceY:number)
 local mesh:EditableMesh?=nil;local part:MeshPart?=nil
 local vertices:{{id:number,color:number,x:number,z:number}}={}
 local elapsed,accumulator=0,0
 local destroyed=false
 if Art.MoonGlintEnabled then task.spawn(function()
  local ok,err=pcall(function()
   local em=Asset:CreateEditableMesh();assert(em,"Mesh budget unavailable");mesh=em
   local n=24
   for z=0,n do for x=0,n do
    local px=(x/n-.5)*width;local pz=(z/n-.5)*length
    table.insert(vertices,{id=em:AddVertex(Vector3.new(px,surfaceY+.025,pz)),color=em:AddColor(Color3.fromRGB(200,220,242),0),x=px,z=pz})
   end end
   local function face(a:number,b:number,c:number)
    local id=em:AddTriangle(vertices[a].id,vertices[b].id,vertices[c].id)
    em:SetFaceColors(id,{vertices[a].color,vertices[b].color,vertices[c].color})
   end
   for z=0,n-1 do for x=0,n-1 do local a=z*(n+1)+x+1;local b=a+n+1;face(a,b,a+1);face(a+1,b,b+1) end end
   local p=Asset:CreateMeshPartAsync(Content.fromObject(em),{CollisionFidelity=Enum.CollisionFidelity.Box})
   if destroyed then p:Destroy();em:Destroy();return end
   p.Name="MoonWaterGlint";p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
   p.Material=Enum.Material.Neon;p.Transparency=.02;p.Color=Color3.new(1,1,1);p.Parent=parent;part=p
  end)
  if not ok then if mesh then mesh:Destroy();mesh=nil end;warn("[CI Moon] Glint unavailable: "..tostring(err)) end
 end) end
 return {Update=function(dt:number)
  elapsed+=dt;accumulator+=dt
  if accumulator<1/20 then return end;accumulator=0
  local em,p,camera=mesh,part,Workspace.CurrentCamera
  if not em or not p or not camera then return end
  local origin=camera.CFrame.Position;local moon=Lighting:GetMoonDirection();local sun=Lighting:GetSunDirection()
  local strength=math.clamp(moon.Y*3,0,1)*(1-math.clamp((sun.Y+.08)/.18,0,1))
  p.Transparency=if origin.Y<=surfaceY+.1 or strength<=0 then 1 else .02
  if p.Transparency==1 then return end
  for _,v in vertices do
   local y,dx,dz=Waves.sample(v.x,v.z,elapsed,Config.WaveAmplitudeScale,Config.WaveSpeedScale)
   local ex,dex=Math.envelope(v.x,width-2*Config.EdgeWaveFadeStuds,Config.EdgeWaveFadeStuds)
   local ez,dez=Math.envelope(v.z,length-2*Config.EdgeWaveFadeStuds,Config.EdgeWaveFadeStuds)
   local pos=Vector3.new(v.x,surfaceY+y*ex*ez+.025,v.z)
   local normal=Vector3.new(-(dx*ex*ez+y*dex*ez),1,-(dz*ex*ez+y*ex*dez)).Unit
   local view=(origin-pos).Unit;local half=view+moon
   local alignment=if half.Magnitude>.001 then math.max(0,normal:Dot(half.Unit)) else 0
   local fresnel=.02+.98*(1-math.max(0,normal:Dot(view)))^5
   local edge=math.clamp(math.min(width*.5-math.abs(v.x),length*.5-math.abs(v.z))/5,0,1)
   em:SetPosition(v.id,pos)
   em:SetColorAlpha(v.color,math.clamp(alignment^48*(.2+.8*fresnel)*strength*Rework.MoonGlintOpacity*edge,0,.25))
  end
 end,Destroy=function()destroyed=true;if part then part:Destroy() end;if mesh then mesh:Destroy() end end}
end
return M
