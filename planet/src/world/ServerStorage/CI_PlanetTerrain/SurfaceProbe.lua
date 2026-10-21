-- Dense outside-in collision inspection. No terrain writes.
local L=require(script.Parent.DatasetLoader)
local P={}
function P.Run(center,extent,spacing)
 assert(not game:GetService('RunService'):IsRunning(),'Use Edit mode')
 center=center or Vector3.new(577.714477,-3732.166687,437.135508)
 extent=extent or 160;spacing=spacing or 8
 assert(extent>0 and extent<=512 and spacing>=4,'Invalid probe size')
 local u=center.Unit;local east=Vector3.yAxis:Cross(u)
 if east.Magnitude<.01 then east=Vector3.xAxis:Cross(u) end
 east=east.Unit;local north=u:Cross(east)
 local surface=L.new(32)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
 params.FilterDescendantsInstances={workspace.Terrain};params.IgnoreWater=true
 local missing,errors,samples={}, {},0
 for x=-extent,extent,spacing do
  for y=-extent,extent,spacing do
   local direction=(u*4096+east*x+north*y).Unit
   local h=surface:elevation({x=direction.X,y=-direction.Z,z=direction.Y})
   local expected=4096+h
   local hit=workspace:Raycast(direction*(expected+100),-direction*220,params)
   samples+=1
   if not hit then table.insert(missing,{x=x,y=y})
   else table.insert(errors,math.abs(hit.Position.Magnitude-expected)) end
  end
  task.wait()
 end
 table.sort(errors)
 return {samples=samples,missingHits=#missing,missingOffsets=missing,
 maximumAbsoluteError=errors[#errors],p95AbsoluteError=errors[math.max(1,math.ceil(#errors*.95))],
 collisionCertified=false,note='Radial collision check; does not certify tangential mesh continuity'}
end
return table.freeze(P)
