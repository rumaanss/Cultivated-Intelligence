-- Shared constructive volume. Positive margin means solid; not a Euclidean SDF.
local Data=if script then require(script.Parent.CaveData) else require('./CaveData')
local D=if script then require(script.Parent.TerrainDataset) else require('./TerrainDataset')
assert(Data.datasetId==D.Id,'Cave dataset mismatch')
local V={}
function V.active(origin,chunk)
    local result={}
    for _,c in ipairs(Data.caves) do
        -- Convert the center to Roblox axes for conservative chunk culling.
        local cx,cy,cz=c.center[1],c.center[3],-c.center[2]
        local dx=math.max(origin.x-cx,0,cx-origin.x-chunk)
        local dy=math.max(origin.y-cy,0,cy-origin.y-chunk)
        local dz=math.max(origin.z-cz,0,cz-origin.z-chunk)
        if dx*dx+dy*dy+dz*dz <= c.bound*c.bound then table.insert(result,c) end
    end
    return result
end
-- Interior support samples the surrounding surface rather than assuming radial thickness is wall thickness.
function V.supportInner(surface,x,y,z,h,shell)
    local low=h
    for _,d in ipairs({{16,0,0},{-16,0,0},{0,16,0},{0,-16,0},{0,0,16},{0,0,-16}}) do
        low=math.min(low,surface:elevation({x=x+d[1],y=y+d[2],z=z+d[3]}))
    end
    return 4096+low-shell
end
function V.margin(x,y,z,h,shell,caves,supportInner)
    local radius=math.sqrt(x*x+y*y+z*z)
    local outer=4096+h
    local thickness=if supportInner then math.max(shell,outer-supportInner) else shell
    local caveMargin=math.huge
    for _,c in ipairs(caves or Data.caves) do
        local dx,dy,dz=x-c.center[1],y-c.center[2],z-c.center[3]
        local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
        if distance<c.bound then
            local weight=math.clamp((c.bound-distance)/32,0,1)
            weight=weight*weight*(3-2*weight)
            thickness=math.max(thickness,shell+(math.max(shell,outer-c.floorRadius)-shell)*weight)
            for _,s in ipairs(c.segments) do
                local ax,ay,az=s.a[1],s.a[2],s.a[3]
                local bx,by,bz=s.b[1]-ax,s.b[2]-ay,s.b[3]-az
                local length2=bx*bx+by*by+bz*bz
                local t=if length2==0 then 0 else math.clamp(((x-ax)*bx+(y-ay)*by+(z-az)*bz)/length2,0,1)
                local px,py,pz=x-ax-t*bx,y-ay-t*by,z-az-t*bz
                caveMargin=math.min(caveMargin,math.sqrt(px*px+py*py+pz*pz)-s.radius)
            end
        end
    end
    return math.min(outer-radius,radius-(outer-thickness),caveMargin)
end
return table.freeze(V)
