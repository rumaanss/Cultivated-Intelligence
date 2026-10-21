--!strict
-- Pure locomotion math. Direction and force are world-space, with no world-Y shortcut.
local L={}
function L.project(v: Vector3,n: Vector3): Vector3 return v-n*v:Dot(n) end
function L.limit(v: Vector3,maximum: number): Vector3
 local m=v.Magnitude
 return if m>maximum and m>0 then v*(maximum/m) else v
end
function L.acceleration(direction: Vector3,velocity: Vector3,normal: Vector3,gravity: Vector3,
 speed: number,grounded: boolean,dt: number,c: any): (Vector3,Vector3)
 local magnitude=math.min(1,direction.Magnitude)
 local tangent=L.project(direction,normal)
 local desired=if tangent.Magnitude>1e-6 then tangent.Unit*(speed*magnitude) else Vector3.zero
 local current=L.project(velocity,normal)
 if not grounded and magnitude<1e-6 then return Vector3.zero,desired end
 local response=if magnitude>1e-6 then c.AccelerationTime else c.DecelerationTime
 -- Exact first-order gain for this step, bounded under long frames.
 local gain=(1-math.exp(-math.max(dt,1e-4)/response))/math.max(dt,1e-4)
 local maximum=if grounded then c.GroundAcceleration else c.AirAcceleration
 local acceleration=L.limit((desired-current)*gain,maximum)
 if grounded then acceleration-=L.project(gravity,normal) end
 return acceleration,desired
end
-- Distance from root center to a plane when the capsule's lower sphere touches it.
function L.supportHeight(foot: number,radius: number,normalDotUp: number): number
 return foot-radius+radius/math.max(normalDotUp,0.05)
end
return table.freeze(L)
