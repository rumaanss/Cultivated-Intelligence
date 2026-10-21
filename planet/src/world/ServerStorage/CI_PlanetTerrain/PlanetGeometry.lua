-- Pure numeric core: C++ coordinates in, explicit conversion at Roblox boundary.
local C = if script then require(script.Parent.PlanetConfig) else require('./PlanetConfig')
local G = {}
local function finite(x)
    return type(x) == 'number' and x == x and math.abs(x) < math.huge
end
local function check(p)
    assert(type(p) == 'table' and finite(p.x) and finite(p.y) and finite(p.z), 'Nonfinite planet position')
end
function G.toRoblox(p)
    check(p)
    return {x=p.x,y=p.z,z=-p.y}
end
function G.toCpp(p)
    check(p)
    return {x=p.x,y=-p.z,z=p.y}
end
function G.radius(p)
    check(p)
    local m = math.max(math.abs(p.x),math.abs(p.y),math.abs(p.z))
    if m == 0 then return 0 end
    return m * math.sqrt((p.x/m)^2+(p.y/m)^2+(p.z/m)^2)
end
function G.elevation(p) return G.radius(p)-C.SeaRadius end
function G.depth(p) return C.SeaRadius-G.radius(p) end
function G.up(p)
    local r=G.radius(p)
    assert(r >= 1e-9, 'Undefined radial up at center')
    return {x=p.x/r,y=p.y/r,z=p.z/r}
end
function G.position(lat,lon,altitude)
    assert(finite(lat) and finite(lon) and finite(altitude) and math.abs(lat)<=math.pi/2 and altitude > -C.SeaRadius, 'Invalid spherical position')
    local r=C.SeaRadius+altitude
    return {x=r*math.cos(lat)*math.cos(lon),y=r*math.cos(lat)*math.sin(lon),z=r*math.sin(lat)}
end
function G.requireContract(schema,version,hash)
    assert(schema==C.Schema and version==C.Version and hash==C.ContractHash, 'Incompatible planet geometry contract; legacy worlds require explicit migration')
end
return table.freeze(G)
