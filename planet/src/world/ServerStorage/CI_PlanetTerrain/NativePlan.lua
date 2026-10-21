local T=if script then require(script.Parent.TerrainTiles) else require('./TerrainTiles')
local D=if script then require(script.Parent.TerrainDataset) else require('./TerrainDataset')
local P={}
function P.decode(b)
    assert(buffer.len(b)>=52 and buffer.readstring(b,0,8)=='CIPLAN1\0','Invalid native build plan')
    local chunk,shell,count=buffer.readu16(b,8),buffer.readu16(b,10),buffer.readu32(b,12)
    assert((chunk==64 or chunk==128) and (shell==32 or shell==64),'Invalid build dimensions')
    assert(count>0 and count<=1000000 and buffer.len(b)==52+count*6,'Invalid build plan length')
    local identity={}
    for i=0,31 do identity[i+1]=string.format('%02x',buffer.readu8(b,16+i)) end
    assert(table.concat(identity)==D.Id,'Build plan belongs to a different dataset')
    local crc=buffer.readu32(b,48)
    assert(T.crc32(b,52)==crc,'Corrupt native build plan')
    local previous=nil
    for i=1,count do
        local k=52+(i-1)*6
        local x,y,z=buffer.readi16(b,k),buffer.readi16(b,k+2),buffer.readi16(b,k+4)
        assert(math.abs(x*chunk)<=4800 and math.abs(y*chunk)<=4800 and math.abs(z*chunk)<=4800,'Build plan outside world bounds')
        if previous then
            assert(x>previous[1] or (x==previous[1] and (y>previous[2] or (y==previous[2] and z>previous[3]))),'Unsorted or duplicate build chunks')
        end
        previous={x,y,z}
    end
    return {
        count=count,chunk=chunk,shell=shell,identity=D.Id..':'..chunk..':'..shell..':'..crc..':density-2:materials-2',
        origin=function(i)
            assert(i%1==0 and i>=1 and i<=count,'Invalid plan index')
            local k=52+(i-1)*6
            return {x=buffer.readi16(b,k)*chunk,y=buffer.readi16(b,k+2)*chunk,z=buffer.readi16(b,k+4)*chunk}
        end,
    }
end
return table.freeze(P)
