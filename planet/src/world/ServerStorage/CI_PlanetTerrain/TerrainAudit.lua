local C=require(script.Parent.CaveData)
local A={}
function A.Run()
    assert(not game:GetService('RunService'):IsRunning(),'Use Edit mode')
    local samples={}
    for lat=-85,85,10 do for lon=-180,170,10 do table.insert(samples,{latitude=lat,longitude=lon}) end end
    table.insert(samples,{latitude=90,longitude=0});table.insert(samples,{latitude=-90,longitude=0})
    local surface=require(script.Parent.CollisionAudit).Run(samples)
    surface.rows=nil
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances={workspace.Terrain};params.IgnoreWater=false
    local caves={}
    for _,c in ipairs(C.caves) do
        local p=c.segments[6].a -- Main chamber center; radius 20 studs.
        local center=Vector3.new(p[1],p[3],-p[2]);local up=center.Unit
        local floor=workspace:Raycast(center,-up*60,params)
        local roof=workspace:Raycast(center,up*60,params)
        local v=Vector3.new(math.floor(center.X/4)*4,math.floor(center.Y/4)*4,math.floor(center.Z/4)*4)
        local _,o=workspace.Terrain:ReadVoxels(Region3.new(v,v+Vector3.one*4),4)
        table.insert(caves,{id=c.id,centerEmpty=o[1][1][1]==0,floorHit=floor~=nil,roofHit=roof~=nil,
            floorDistance=if floor then floor.Distance else nil,roofDistance=if roof then roof.Distance else nil})
    end
    return {surface=surface,caves=caves,collisionCertified=false}
end
return table.freeze(A)
