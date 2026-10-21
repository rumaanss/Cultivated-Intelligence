--!strict
-- Pure deterministic field. No Workspace access; also used by preview/tests.
local C = require(script.Parent.IslandConfig)
local M = {}
local function smooth(a: number,b: number,x: number): number
 local t=math.clamp((x-a)/(b-a),0,1)
 return t*t*(3-2*t)
end
local function hill(x: number,z: number,cx: number,cz: number,rx: number,rz: number,h: number): number
 return h*math.exp(-((x-cx)/rx)^2-((z-cz)/rz)^2)
end
function M.coast(x: number,z: number): number
 local px,pz=x/C.MapScale+C.PondMapX,z/C.MapScale+C.PondMapY
 local inside=false
 local distance=math.huge
 for i,a in C.Outline do
  local b=C.Outline[i%#C.Outline+1]
  local dx,dz=b[1]-a[1],b[2]-a[2]
  local t=math.clamp(((px-a[1])*dx+(pz-a[2])*dz)/(dx*dx+dz*dz),0,1)
  distance=math.min(distance,math.sqrt((px-a[1]-t*dx)^2+(pz-a[2]-t*dz)^2))
  if (a[2]>pz)~=(b[2]>pz) and px<(b[1]-a[1])*(pz-a[2])/(b[2]-a[2])+a[1] then inside=not inside end
 end
 return distance*C.MapScale*(if inside then 1 else -1)
end
function M.protected(x: number,z: number): boolean
 return math.abs(x)<C.ProtectedHalfSize and math.abs(z)<C.ProtectedHalfSize
end
function M.height(x: number,z: number): number
 local coast=M.coast(x,z)+math.noise(x/43,z/43,C.Seed)*3
 local inland=smooth(0,65,coast)
 local rolling=math.noise(x/150,z/150,C.Seed)*15+math.noise(x/51,z/51,C.Seed+5)*4
 -- High northern backbone, gentler southern meadow, western headland.
 local relief=hill(x,z,190,-300,155,115,91)+hill(x,z,340,-285,125,100,58)
  +hill(x,z,-320,-250,85,160,47)+hill(x,z,480,155,145,95,39)
 local ridges=math.abs(math.noise(x/68,z/68,C.Seed+11))*13*smooth(20,75,relief)
 local ground=math.min(coast*0.29,8)+inland*(7+rolling+relief+ridges)
 if coast<0 then ground=math.max(-50,coast*0.42) end
 -- Pond has an oval shore, two small bays, and a fully protected square core.
 local ellipse=math.sqrt((x/101)^2+(z/83)^2)
 local pondDistance=(ellipse-1)*85+math.noise(x/37,z/37,C.Seed+9)*3
 local pondFloor=pondDistance*1.65
 ground=math.min(ground,math.max(-64,pondFloor))
 if M.protected(x,z) then return -64 end
 return math.clamp(ground,-64,148)
end
function M.sample(x: number,z: number): (number,string,number)
 local h=M.height(x,z)
 local dx=(M.height(x+2,z)-M.height(x-2,z))/4
 local dz=(M.height(x,z+2)-M.height(x,z-2))/4
 local slope=math.sqrt(dx*dx+dz*dz)
 local material="Grass"
 if h<3.8 then material="Sand"
 elseif slope>0.65 or h>78 then material="Rock"
 elseif slope>0.43 then material="Ground"
 elseif math.noise(x/74,z/74,C.Seed+3)>0.13 then material="LeafyGrass" end
 return h,material,slope
end
return M
