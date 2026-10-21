-- IDs 0 Air, 1 Rock, 2 Sand, 3 Grass, 4 Ground, 5 Slate, 6 Limestone, 7 Snow.
-- Radial altitude and local slope, never global Roblox Y.
local M={}
function M.pick(surface,x,y,z,h,radius)
    if h<8 then return if h < -150 then 1 else 2 end
    local depth=4096+h-radius
    local fold=9*math.sin(x/180+y/210)+6*math.sin(z/130-x/270)
    local band=(radius-4096+fold)%62
    local geology=if band<12 then 6 elseif band<35 then 5 else 1
    if depth>7 then return geology end
    -- Tangent derivatives at the actual spherical location, central stencil.
    local ux,uy,uz=x/radius,y/radius,z/radius
    local tx,ty,tz=-uy,ux,0
    local tl=math.sqrt(tx*tx+ty*ty)
    if tl<.001 then tx,ty,tz=1,0,0 else tx,ty=tx/tl,ty/tl end
    local sx,sy,sz=uy*tz-uz*ty,uz*tx-ux*tz,ux*ty-uy*tx
    local function at(a,b,c) return surface:elevation({x=a,y=b,z=c}) end
    local a=(at(x+tx*8,y+ty*8,z+tz*8)-at(x-tx*8,y-ty*8,z-tz*8))/16
    local b=(at(x+sx*8,y+sy*8,z+sz*8)-at(x-sx*8,y-sy*8,z-sz*8))/16
    local slope=math.sqrt(a*a+b*b)
    local weather=12*math.sin(x/67+y/91)+8*math.sin(z/51-y/83)
    local snowline=266-65*math.abs(uz)+weather
    if h>snowline and slope<.82 and depth<5 then return 7 end
    if slope>.67 then return geology end
    if h>snowline-38 then return if slope>.4 then geology else 4 end
    if slope>.43 or h>190+weather then return 4 end
    return 3
end
return table.freeze(M)
