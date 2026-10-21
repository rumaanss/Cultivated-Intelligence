--!strict
local F = {}
local EPS = 1e-7
function F.finite(v: Vector3): boolean
 return v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < math.huge
end
function F.up(position: Vector3, center: Vector3): Vector3
 local d = position - center
 assert(F.finite(d) and d.Magnitude > EPS, "Invalid planetary position (center or non-finite)")
 return d.Unit
end
function F.tangent(v: Vector3, up: Vector3): Vector3
 local p = v - up * v:Dot(up)
 if p.Magnitude < EPS then
  local seed = if math.abs(up.Y) < 0.8 then Vector3.yAxis else Vector3.xAxis
  p = seed - up * seed:Dot(up)
 end
 return p.Unit
end
-- Minimal rotation of the old tangent frame: no geographic pole singularity.
function F.transport(v: Vector3, oldUp: Vector3, newUp: Vector3): Vector3
 local axis = oldUp:Cross(newUp)
 local c = math.clamp(oldUp:Dot(newUp), -1, 1)
 if axis.Magnitude < EPS then
  if c > 0 then return F.tangent(v, newUp) end
  -- Antipodal teleport: deterministic axis, never normalize a zero cross product.
  return F.tangent(v, newUp)
 end
 local k = axis.Unit
 local s = axis.Magnitude
 return F.tangent(v*c + k:Cross(v)*s + k*k:Dot(v)*(1-c), newUp)
end
function F.rotate(v: Vector3, up: Vector3, radians: number): Vector3
 return F.tangent(v*math.cos(radians) + up:Cross(v)*math.sin(radians), up)
end
function F.yaw(from: Vector3, to: Vector3, up: Vector3): number
 return math.atan2(up:Dot(from:Cross(to)), math.clamp(from:Dot(to), -1, 1))
end
function F.fromLatLon(latitude: number, longitude: number): (Vector3, Vector3, Vector3)
 local lat, lon = math.rad(latitude), math.rad(longitude)
 local up = Vector3.new(math.cos(lat)*math.cos(lon), math.sin(lat), -math.cos(lat)*math.sin(lon))
 local north = Vector3.new(-math.sin(lat)*math.cos(lon), math.cos(lat), math.sin(lat)*math.sin(lon))
 return up, north, north:Cross(up).Unit
end
function F.toCpp(v: Vector3): Vector3 return Vector3.new(v.X, -v.Z, v.Y) end
function F.fromCpp(v: Vector3): Vector3 return Vector3.new(v.X, v.Z, -v.Y) end
function F.altitude(position: Vector3, center: Vector3, radius: number): number
 return (position-center).Magnitude-radius
end
return table.freeze(F)
