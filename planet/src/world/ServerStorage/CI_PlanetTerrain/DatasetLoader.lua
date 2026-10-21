-- Edit-mode data stays in ServerStorage. Do not put the source tiles in ReplicatedStorage.
local T=require(script.Parent.TerrainTiles)
local D=require(script.Parent.TerrainDataset)
local C=require(script.Parent.PlanetConfig)
local L={}
function L.new(maxTiles)
    local root=script.Parent
    assert(root:FindFirstChild('DatasetId') and root.DatasetId.Value==D.Id,'Wrong terrain dataset')
    assert(root:FindFirstChild('ContractHash') and root.ContractHash.Value==C.ContractHash,'Wrong planet contract')
    local tiles=assert(root:FindFirstChild('Tiles'),'Terrain tile folder missing')
    return T.new(function(f,x,y)
        local value=assert(tiles:FindFirstChild(string.format('f%d_%d_%d',f,x,y)),'Terrain tile missing')
        local hex=value.Value
        assert(#hex==(28+65*65*2)*2 and not string.find(hex,'[^0-9a-f]'),'Invalid terrain payload encoding')
        local b=buffer.create(#hex/2)
        for i=1,#hex,2 do buffer.writeu8(b,(i-1)/2,tonumber(string.sub(hex,i,i+1),16)) end
        return b
    end,maxTiles)
end
return table.freeze(L)
