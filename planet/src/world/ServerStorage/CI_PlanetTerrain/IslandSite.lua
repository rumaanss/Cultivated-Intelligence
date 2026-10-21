-- Reference-map site. Water is a planned radial level; this package writes no water.
local G=require(script.Parent.PlanetGeometry)
local S={Longitude=-98.52227260602828,Latitude=-23.133702947184133,WaterRadius=4096,DeepFloorDepth=104}
local function frame()
 local lat,lon=math.rad(S.Latitude),math.rad(S.Longitude)
 local p=G.toRoblox(G.position(lat,lon,0));local up=Vector3.new(p.x,p.y,p.z).Unit
 local north=Vector3.new(-math.sin(lat)*math.cos(lon),math.cos(lat),math.sin(lat)*math.sin(lon))
 local east=north:Cross(up).Unit
 return up,north,east
end
function S.View(which)
 assert(not game:GetService('RunService'):IsRunning(),'Use Edit mode')
 local up,north=frame();local target=up*S.WaterRadius
 local distance=if which=='island' then 2600 else 520
 workspace.CurrentCamera.CFrame=CFrame.lookAt(target+up*distance-north*distance*.4,target,north)
 workspace.CurrentCamera.Focus=CFrame.new(target)
 return {id='reference-island-lake',longitude=S.Longitude,latitude=S.Latitude,waterEnabled=false}
end
function S.Audit()
 assert(not game:GetService('RunService'):IsRunning(),'Use Edit mode')
 local up,north,east=frame()
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
 params.FilterDescendantsInstances={workspace.Terrain};params.IgnoreWater=true
 local missing,minDepth,maxDepth,count=0,math.huge,-math.huge,0
 -- Original 100x100 simulation footprint, sampled at 10-stud spacing.
 for x=-50,50,10 do for y=-50,50,10 do
  local u=(up*S.WaterRadius+east*x+north*y).Unit
  local hit=workspace:Raycast(u*(S.WaterRadius+180),-u*450,params)
  count+=1
  if hit then
   local depth=S.WaterRadius-hit.Position.Magnitude
   minDepth=math.min(minDepth,depth);maxDepth=math.max(maxDepth,depth)
  else missing+=1 end
 end end
 return {site='reference-island-lake',samples=count,missingHits=missing,
 minimumDepth=if minDepth<math.huge then minDepth else nil,
 maximumDepth=if maxDepth>-math.huge then maxDepth else nil,
 deepFootprintPassed=missing==0 and minDepth>=100,
 waterWritten=false,wholePlanetCertified=false}
end
return table.freeze(S)
