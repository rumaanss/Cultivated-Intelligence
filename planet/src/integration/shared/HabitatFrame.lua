--!strict
-- Regional chart in studs: X=east, Y=north, Z=altitude above the sea sphere.
-- Radial projection, not a translated flat plane. No world mutation.
local M={}
export type Frame={center:Vector3,radius:number,up:Vector3,east:Vector3,north:Vector3}
function M.fromState(state:Instance):Frame
 assert(state:GetAttribute("Status")=="Ready","Lake audit is not ready")
 local f={center=state:GetAttribute("Center"),radius=state:GetAttribute("Radius"),up=state:GetAttribute("Up"),east=state:GetAttribute("East"),north=state:GetAttribute("North")}
 assert(typeof(f.center)=="Vector3" and type(f.radius)=="number" and f.radius>0,"Invalid planet frame")
 for _,axis in {f.up,f.east,f.north} do assert(typeof(axis)=="Vector3" and math.abs(axis.Magnitude-1)<1e-5,"Invalid habitat basis") end
 assert(math.abs(f.up:Dot(f.east))<1e-5 and math.abs(f.up:Dot(f.north))<1e-5 and math.abs(f.east:Dot(f.north))<1e-5,"Nonorthogonal habitat basis")
 return f :: Frame
end
function M.toWorld(f:Frame,p:Vector3):Vector3
 assert(p.X==p.X and p.Y==p.Y and p.Z==p.Z and math.abs(p.X)<=f.radius*.25 and math.abs(p.Y)<=f.radius*.25 and p.Z> -f.radius and p.Z<math.huge,"Position outside regional chart")
 return f.center+(f.up*f.radius+f.east*p.X+f.north*p.Y).Unit*(f.radius+p.Z)
end
function M.fromWorld(f:Frame,p:Vector3):Vector3?
 local delta=p-f.center;local length=delta.Magnitude
 if length<1e-6 then return nil end
 local radial=delta/length;local denominator=radial:Dot(f.up)
 if denominator<=0 then return nil end
 local x,y=f.radius*radial:Dot(f.east)/denominator,f.radius*radial:Dot(f.north)/denominator
 if math.abs(x)>f.radius*.25 or math.abs(y)>f.radius*.25 then return nil end
 return Vector3.new(x,y,length-f.radius)
end
function M.orientation(f:Frame,p:Vector3):CFrame
 local origin=M.toWorld(f,p);local normal=(origin-f.center).Unit
 local east=(f.east-normal*f.east:Dot(normal)).Unit
 return CFrame.fromMatrix(origin,east,normal,east:Cross(normal))
end
return M
