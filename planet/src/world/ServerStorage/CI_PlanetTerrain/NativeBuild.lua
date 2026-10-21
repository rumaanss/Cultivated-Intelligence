-- Edit-mode native terrain generation. Never auto-executes and never calls Terrain:Clear().
local RunService=game:GetService('RunService')
local N=require(script.Parent.NativeShell)
local P=require(script.Parent.NativePlan)
local J=require(script.Parent.BuildJournal)
local Loader=require(script.Parent.DatasetLoader)
local B={}
local running=false
local pauseRequested=false
local function fromHex(hex)
    assert(type(hex)=='string' and #hex%2==0 and not string.find(hex,'[^0-9a-f]'),'Invalid plan encoding')
    local b=buffer.create(#hex/2)
    for i=1,#hex,2 do buffer.writeu8(b,(i-1)/2,tonumber(string.sub(hex,i,i+1),16)) end
    return b
end
local function context()
    local root=script.Parent
    local value=assert(root:FindFirstChild('NativePlanData'),'Native build plan missing; regenerate the Studio model')
    assert(value:IsA('Folder'),'Native plan must use paged storage')
    local countValue=assert(value:FindFirstChild('PartCount'),'Plan page count missing')
    local count=countValue.Value
    assert(type(count)=='number' and count%1==0 and count>=1 and count<=2048,'Invalid plan page count')
    local parts=table.create(count)
    for i=1,count do
        local part=assert(value:FindFirstChild(string.format('P%04d',i)),'Plan page missing')
        assert(part:IsA('StringValue') and #part.Value<=16384,'Invalid plan page')
        parts[i]=part.Value
    end
    local plan=P.decode(fromHex(table.concat(parts)))
    local folder=root:FindFirstChild('BuildState')
    if not folder then folder=Instance.new('Folder');folder.Name='BuildState';folder.Parent=root end
    assert(folder:IsA('Folder'),'Invalid build state container')
    local store={
        get=function(k)
            local v=folder:FindFirstChild(k)
            if v then assert(v:IsA('StringValue'),'Invalid journal value');return v.Value end
            return nil
        end,
        set=function(k,value)
            local v=folder:FindFirstChild(k)
            if not v then v=Instance.new('StringValue');v.Name=k;v.Value=value;v.Parent=folder
            else assert(v:IsA('StringValue'),'Invalid journal value');v.Value=value end
        end,
    }
    return plan,J.open(store,plan.identity,plan.count),folder
end
function B.Pause()
    pauseRequested=true
end
function B.Run(maxChunks)
    assert(RunService:IsStudio() and not RunService:IsRunning(),'Run only in Studio edit mode')
    assert(not running,'Native build is already running')
    maxChunks=maxChunks or 64
    assert(type(maxChunks)=='number' and maxChunks%1==0 and maxChunks>=1 and maxChunks<=1000000,'Invalid chunk batch limit')
    -- Terrain.Decoration is NotScriptable; disable it manually in Properties.
    local prior=script.Parent:FindFirstChild('BuildState')
    if not prior or not prior:FindFirstChild('Identity') then
        assert(workspace.Terrain:CountCells()==0,'Start the first build in a new empty place; existing terrain is preserved')
    end
    local plan,journal,state=context()
    local surface=Loader.new(64)
    running=true;pauseRequested=false
    local started=os.clock()
    local written=0
    local lastYield=-math.huge
    local terrain=workspace.Terrain
    local lookup={[0]=Enum.Material.Air,[1]=Enum.Material.Rock,[2]=Enum.Material.Sand,[3]=Enum.Material.Grass,[4]=Enum.Material.Ground,[5]=Enum.Material.Slate,[6]=Enum.Material.Limestone,[7]=Enum.Material.Snow}
    local ok,result=xpcall(function()
        state:SetAttribute('Status','Building');state:SetAttribute('TotalChunks',plan.count)
        local resume=journal.pending()
        local function process(index)
            if journal.isDone(index) then return end
            local recovering=journal.pending()==index
            local o=plan.origin(index)
            local origin=Vector3.new(o.x,o.y,o.z)
            local region=Region3.new(origin,origin+Vector3.one*plan.chunk)
            if not recovering then
                local oldMaterials,oldOccupancy=terrain:ReadVoxels(region,4)
                local size=oldMaterials.Size
                for x=1,size.X do for y=1,size.Y do for z=1,size.Z do
                    assert(oldOccupancy[x][y][z]==0,'Unowned terrain at chunk '..index..'; build stopped without overwriting it')
                end end end
            end
            -- Persist ownership before any write. A pending chunk may be deterministically rewritten.
            journal.begin(index)
            local materials,occupancy,occupied=N.build(surface,o,plan.chunk,plan.shell)
            if occupied>0 or recovering then
                local cells=plan.chunk/4
                for x=1,cells do for y=1,cells do for z=1,cells do
                    materials[x][y][z]=lookup[materials[x][y][z]]
                end end end
                terrain:WriteVoxels(region,4,materials,occupancy)
                -- Do not commit the journal until engine storage agrees with the write.
                local vm,vo=terrain:ReadVoxels(region,4)
                for x=1,cells do for y=1,cells do for z=1,cells do
                    assert(math.abs(vo[x][y][z]-occupancy[x][y][z])<=.02,'Occupancy readback failed at chunk '..index)
                    if occupancy[x][y][z]>.02 then
                        assert(vm[x][y][z]==materials[x][y][z],'Material readback failed at chunk '..index)
                    end
                end end end
            end
            journal.finish(index)
            written+=1
            if written%2048==0 then print("Verified terrain chunks:",journal.completed(),"/",plan.count) end
            state:SetAttribute('CompletedChunks',journal.completed())
            state:SetAttribute('LastChunk',index)
            state:SetAttribute('ElapsedBatchSeconds',os.clock()-started)
            -- Yield only at a committed chunk boundary, so pause does not leave partial arrays.
            if os.clock()-lastYield>=0.025 then
                task.wait()
                lastYield=os.clock()
            end
        end
        if resume>0 then process(resume) end
        for index=1,plan.count do
            if pauseRequested or written>=maxChunks then break end
            process(index)
        end
        local complete=journal.completed()==plan.count
        state:SetAttribute('Status',if complete then 'Complete' else 'Paused')
        return {complete=complete,completedChunks=journal.completed(),totalChunks=plan.count,batchChunks=written,batchSeconds=os.clock()-started,pendingChunk=journal.pending()}
    end,debug.traceback)
    running=false
    if not ok then
        state:SetAttribute('Status','Failed');state:SetAttribute('LastError',tostring(result))
        error(result,0)
    end
    state:SetAttribute('LastError',nil)
    return result
end
return table.freeze(B)
