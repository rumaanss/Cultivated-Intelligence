-- Engine-independent bounded array builder. Numeric material IDs are resolved by Studio caller.
-- Positions supplied in Roblox axes; terrain sampler consumes the shared C++ axes.
local V=if script then require(script.Parent.TerrainVolume) else require('./TerrainVolume')
local M=if script then require(script.Parent.TerrainMaterials) else require('./TerrainMaterials')
local N={}
function N.build(surface,origin: {[string]: number},chunkStuds,shellStuds)
    assert(chunkStuds==64 or chunkStuds==128,'Unsupported chunk size')
    assert(shellStuds==32 or shellStuds==64,'Unvalidated shell thickness')
    for _,key in ipairs({'x','y','z'}) do
        local v=origin[key]
        assert(type(v)=='number' and v==v and math.abs(v)<10000 and v%4==0,'Invalid grid origin')
    end
    local active=V.active(origin,chunkStuds)
    local count=chunkStuds/4
    local materials,occupancy={},{}
    local occupied=0
    for ix=1,count do
        local x=origin.x+(ix-.5)*4
        local mx,ox={},{};materials[ix]=mx;occupancy[ix]=ox
        for iy=1,count do
            local y=origin.y+(iy-.5)*4
            local my,oy=table.create(count),table.create(count);mx[iy]=my;ox[iy]=oy
            for iz=1,count do
                local z=origin.z+(iz-.5)*4
                local radius=math.sqrt(x*x+y*y+z*z)
                local o,h=0,0
                if radius>=3096-shellStuds-4 and radius<=4496+4 then
                    h=surface:elevation({x=x,y=-z,z=y})
                    assert(h==h and h>=-1000 and h<=400,'Invalid terrain surface height')
                    -- Skip expensive support sampling above the outer surface.
                    if radius<=4096+h+2 then
                        local inner=V.supportInner(surface,x,-z,y,h,shellStuds)
                        o=math.clamp(V.margin(x,-z,y,h,shellStuds,active,inner)/4+.5,0,1)
                    end
                end
                oy[iz]=o
                my[iz]=if o==0 then 0 else M.pick(surface,x,-z,y,h,radius)
                if o>0 then occupied+=1 end
            end
        end
    end
    return materials,occupancy,occupied
end
return table.freeze(N)
