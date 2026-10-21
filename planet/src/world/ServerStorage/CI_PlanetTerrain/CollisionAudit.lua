local RunService=game:GetService('RunService')
local G=require(script.Parent.PlanetGeometry)
local Loader=require(script.Parent.DatasetLoader)
local A={}
-- Reports measured disagreement; does not invent a tolerance or certify ecology collision.
function A.Run(samples)
    assert(RunService:IsStudio(),'Collision audit is a Studio tool')
    assert(type(samples)=='table' and #samples>=1 and #samples<=10000,'Invalid audit sample list')
    local terrain=workspace.Terrain
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances={terrain}
    params.IgnoreWater=false
    local surface=Loader.new(64)
    local rows,errors={},{}
    local missing,water=0,0
    for i,q in ipairs(samples) do
        assert(type(q)=='table' and type(q.latitude)=='number' and type(q.longitude)=='number','Invalid geographic sample')
        assert(q.latitude>=-90 and q.latitude<=90 and q.longitude>=-180 and q.longitude<=180,'Invalid geographic coordinates')
        local lat,lon=math.rad(q.latitude),math.rad(q.longitude)
        local p=G.position(lat,lon,0)
        local expected=surface:elevation(p)
        local u=G.toRoblox(G.up(p))
        local axis=Vector3.new(u.x,u.y,u.z)
        local hit=workspace:Raycast(axis*4560,-axis*1600,params)
        local row={latitude=q.latitude,longitude=q.longitude,expectedElevation=expected,hit=hit~=nil}
        if hit then
            local actual=hit.Position.Magnitude-4096
            row.actualElevation=actual;row.errorStuds=actual-expected;row.material=hit.Material.Name
            table.insert(errors,math.abs(actual-expected))
            if hit.Material==Enum.Material.Water then water+=1 end
        else missing+=1 end
        rows[i]=row
        if i%32==0 then task.wait() end
    end
    table.sort(errors)
    local function percentile(p)
        if #errors==0 then return nil end
        return errors[math.max(1,math.ceil(#errors*p))]
    end
    return {samples=#samples,missingHits=missing,waterHits=water,maximumAbsoluteError=percentile(1),p95AbsoluteError=percentile(.95),rows=rows,collisionCertified=false}
end
return table.freeze(A)
