-- Shared binary format with cpp/terrain_tiles.hpp. Loader supplies a buffer per tile.
local T = {}
local D=if script then require(script.Parent.TerrainDataset) else require('./TerrainDataset')
local C=if script then require(script.Parent.PlanetConfig) else require('./PlanetConfig')
local function finite(x) return type(x)=='number' and x==x and math.abs(x)<math.huge end
function T.locate(p: {x: number, y: number, z: number})
    assert(finite(p.x) and finite(p.y) and finite(p.z), 'Nonfinite direction')
    local a=math.max(math.abs(p.x),math.abs(p.y),math.abs(p.z))
    assert(a>0, 'Undefined direction at center')
    if math.abs(p.x)==a then
        if p.x>=0 then return 0,p.y/a,p.z/a else return 1,p.y/a,-p.z/a end
    elseif math.abs(p.y)==a then
        if p.y>=0 then return 2,-p.x/a,p.z/a else return 3,p.x/a,p.z/a end
    else
        if p.z>=0 then return 4,p.x/a,p.y/a else return 5,-p.x/a,p.y/a end
    end
end
function T.address(p)
    local f,u,v=T.locate(p)
    local x,y=math.clamp((u+1)*512,0,1024),math.clamp((v+1)*512,0,1024)
    local tx,ty=math.min(math.floor(x/64),15),math.min(math.floor(y/64),15)
    return f,tx,ty,x-tx*64,y-ty*64
end
local crcTable={}
for i=0,255 do
    local c=i
    for _=1,8 do c=bit32.bxor(bit32.rshift(c,1),if bit32.band(c,1)==1 then 0xedb88320 else 0) end
    crcTable[i]=c
end
local function crc32(b,start)
    local c=0xffffffff
    for i=start,buffer.len(b)-1 do
        c=bit32.bxor(bit32.rshift(c,8),crcTable[bit32.band(bit32.bxor(c,buffer.readu8(b,i)),255)])
    end
    return bit32.bnot(c)
end
function T.decode(b,f,tx,ty)
    assert(buffer.len(b)==28+65*65*2,'Invalid terrain tile length')
    assert(buffer.readstring(b,0,8)=='CIPTILE1','Invalid terrain tile magic')
    assert(buffer.readu16(b,8)==f and buffer.readu16(b,10)==tx and buffer.readu16(b,12)==ty,'Wrong terrain tile address')
    assert(f>=0 and f<=5 and tx>=0 and tx<16 and ty>=0 and ty<16,'Invalid tile address')
    assert(buffer.readu16(b,14)==64 and buffer.readu32(b,16)==1024 and buffer.readf32(b,20)==0.0625,'Incompatible terrain tile')
    assert(buffer.readu32(b,24)==D.CRC[f*256+ty*16+tx+1] and buffer.readu32(b,24)==crc32(b,28),'Corrupt or mismatched terrain tile')
    for i=0,65*65-1 do
        local h=buffer.readi16(b,28+i*2)/16
        assert(h>=-1000 and h<=400,'Terrain elevation outside design bounds')
    end
    return b
end
function T.sample(b,x,y)
    assert(finite(x) and finite(y) and x>=0 and y>=0 and x<=64 and y<=64,'Invalid tile coordinate')
    local ix,iy=math.min(math.floor(x),63),math.min(math.floor(y),63)
    local fx,fy=x-ix,y-iy
    local offset=28+2*(iy*65+ix)
    local a=(buffer.readi16(b,offset)*(1-fx)+buffer.readi16(b,offset+2)*fx)/16
    local bvalue=(buffer.readi16(b,offset+130)*(1-fx)+buffer.readi16(b,offset+132)*fx)/16
    return a*(1-fy)+bvalue*fy
end
function T.new(loader,maxTiles)
    assert(D.ContractHash==C.ContractHash,'Terrain dataset belongs to a different geometry contract')
    assert(type(loader)=='function','Tile loader required')
    maxTiles=maxTiles or 64
    assert(maxTiles>=1 and maxTiles<=1536 and maxTiles%1==0,'Invalid tile cache limit')
    local cache,count,clock={},0,0
    return {
        elevation=function(_,p)
            local f,tx,ty,x,y=T.address(p)
            local key=f*256+ty*16+tx
            clock+=1
            local entry=cache[key]
            if not entry then
                local b=T.decode(loader(f,tx,ty),f,tx,ty)
                if count==maxTiles then
                    local oldestKey,oldestTime=nil,math.huge
                    for k,e in pairs(cache) do if e.used<oldestTime then oldestKey,oldestTime=k,e.used end end
                    cache[oldestKey]=nil
                    count-=1
                end
                entry={data=b,used=clock}; cache[key]=entry;count+=1
            end
            entry.used=clock
            return T.sample(entry.data,x,y)
        end,
        cachedTileCount=function() return count end,
    }
end
T.crc32=crc32
return table.freeze(T)
