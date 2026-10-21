-- Explicit, isolated edit-mode benchmark. Does not run on require or start a full-world bake.
local RunService=game:GetService('RunService')
local N=require(script.Parent.NativeShell)
local B={}
local running=false
function B.Measure(surface,origin,chunkStuds,shellStuds)
    assert(RunService:IsStudio() and not RunService:IsRunning(),'Run only in an isolated Studio edit session')
    assert(not running,'A terrain measurement is already running')
    assert(typeof(origin)=='Vector3','Vector3 origin required')
    assert(chunkStuds==64 or chunkStuds==128,'Unsupported chunk size')
    assert(shellStuds==32 or shellStuds==64,'Unsupported shell thickness')
    assert(origin.X%4==0 and origin.Y%4==0 and origin.Z%4==0,'Origin must be grid aligned')
    local terrain=workspace.Terrain
    local region=Region3.new(origin,origin+Vector3.one*chunkStuds)
    local originalMaterials,originalOccupancy=terrain:ReadVoxels(region,4)
    local size=originalMaterials.Size
    -- Numeric iteration: ReadVoxels includes nonnumeric Size metadata.
    for x=1,size.X do for y=1,size.Y do for z=1,size.Z do
        assert(originalOccupancy[x][y][z]==0,'Benchmark refuses to overwrite existing terrain')
    end end end
    running=true
    local wrote=false
    local ok,result=xpcall(function()
        local started=os.clock()
        local mats,occ,occupied=N.build(surface,{x=origin.X,y=origin.Y,z=origin.Z},chunkStuds,shellStuds)
        local generated=os.clock()
        local lookup={[0]=Enum.Material.Air,[1]=Enum.Material.Rock,[2]=Enum.Material.Sand,[3]=Enum.Material.Grass,[4]=Enum.Material.Ground,[5]=Enum.Material.Slate,[6]=Enum.Material.Limestone,[7]=Enum.Material.Snow}
        for x=1,size.X do for y=1,size.Y do for z=1,size.Z do mats[x][y][z]=lookup[mats[x][y][z]] end end end
        local writeStart=os.clock()
        wrote=true -- Restore even if WriteVoxels throws after partially mutating terrain.
        terrain:WriteVoxels(region,4,mats,occ)
        local written=os.clock()
        return {chunkStuds=chunkStuds,shellStuds=shellStuds,occupiedCells=occupied,arrayBuildSeconds=generated-started,materialConversionSeconds=writeStart-generated,writeSeconds=written-writeStart,frameRateMeasured=false}
    end,debug.traceback)
    local restored,restoreError=true,nil
    if wrote then restored,restoreError=pcall(function()terrain:WriteVoxels(region,4,originalMaterials,originalOccupancy)end) end
    running=false
    assert(restored,'Benchmark cleanup failed; restore the isolated place backup: '..tostring(restoreError))
    assert(ok,result)
    return result
end
return table.freeze(B)
