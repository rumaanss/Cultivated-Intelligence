--!nonstrict
-- Read-only planet integration preflight. Never owns players, terrain or lighting.
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Http=game:GetService('HttpService')
local Frame=(function()
--!strict
-- Regional chart in studs: X=east, Y=north, Z=altitude above the sea sphere.
-- Radial projection, not a translated flat plane. No world mutation.
local M={}
export type Frame={center:Vector3,radius:number,up:Vector3,east:Vector3,north:Vector3}
function M.fromState(state:Instance):Frame
 assert(state:GetAttribute("Status")=="Ready","Lake audit is not ready")
 local f={center=state:GetAttribute("Center"),radius=state:GetAttribute("Radius"),up=state:GetAttribute("Up"),east=state:GetAttribute("East"),north=state:GetAttribute("North")}
 assert(typeof(f.center)=="Vector3" and type(f.radius)=="number" and f.radius>0,"Invalid planet frame")
 for _,axis in {f.up,f.east,f.north} do assert(typeof(axis)=="Vector3" and math.abs(axis.Magnitude-1)<1e-5,"Invalid habitat basis") end
 assert(math.abs(f.up:Dot(f.east))<1e-5 and math.abs(f.up:Dot(f.north))<1e-5 and math.abs(f.east:Dot(f.north))<1e-5,"Nonorthogonal habitat basis")
 return f :: Frame
end
function M.toWorld(f:Frame,p:Vector3):Vector3
 assert(p.X==p.X and p.Y==p.Y and p.Z==p.Z and math.abs(p.X)<=f.radius*.25 and math.abs(p.Y)<=f.radius*.25 and p.Z> -f.radius and p.Z<math.huge,"Position outside regional chart")
 return f.center+(f.up*f.radius+f.east*p.X+f.north*p.Y).Unit*(f.radius+p.Z)
end
function M.fromWorld(f:Frame,p:Vector3):Vector3?
 local delta=p-f.center;local length=delta.Magnitude
 if length<1e-6 then return nil end
 local radial=delta/length;local denominator=radial:Dot(f.up)
 if denominator<=0 then return nil end
 local x,y=f.radius*radial:Dot(f.east)/denominator,f.radius*radial:Dot(f.north)/denominator
 if math.abs(x)>f.radius*.25 or math.abs(y)>f.radius*.25 then return nil end
 return Vector3.new(x,y,length-f.radius)
end
function M.orientation(f:Frame,p:Vector3):CFrame
 local origin=M.toWorld(f,p);local normal=(origin-f.center).Unit
 local east=(f.east-normal*f.east:Dot(normal)).Unit
 return CFrame.fromMatrix(origin,east,normal,east:Cross(normal))
end
return M

end)()
local old=RS:FindFirstChild('CI_ResearchTelemetry');if old then old:Destroy() end
local status=Instance.new('Folder');status.Name='CI_ResearchTelemetry';status.Parent=RS
status:SetAttribute('BiologyState','Awaiting habitat integration')
status:SetAttribute('RelayState','Not configured')
status:SetAttribute('HabitatState','Waiting for lake audit')
local alive=true;local links={};local elapsed,frames=0,0
links[#links+1]=Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;frames+=1
 if elapsed>=1 then
  status:SetAttribute('ServerStepMs',elapsed/frames*1000)
  status:SetAttribute('ServerHeartbeatHz',frames/elapsed)
  status:SetAttribute('ServerTimestamp',workspace:GetServerTimeNow())
  elapsed,frames=0,0
 end
end)
script.Destroying:Connect(function()alive=false;for _,c in links do c:Disconnect()end;status:Destroy()end)
local function vector(v)return {v.X,v.Y,v.Z}end
local function makeHabitat(lake)
 local frame=Frame.fromState(lake);local floors=Http:JSONDecode(lake:WaitForChild('FloorMap').Value)
 local cells={};local minE,maxE,minN,maxN=math.huge,-math.huge,math.huge,-math.huge
 local wet={};local grid=lake:GetAttribute('Grid')
 for key,altitude in pairs(floors)do
  local e,n=string.match(key,'^(-?%d+),(-?%d+)$');assert(e and n,'Invalid floor cell')
  e,n=tonumber(e),tonumber(n);cells[#cells+1]={e,n,altitude}
  minE,maxE,minN,maxN=math.min(minE,e*grid),math.max(maxE,e*grid),math.min(minN,n*grid),math.max(maxN,n*grid)
  if altitude<0 then wet[#wet+1]={e*grid,n*grid}end
 end
 table.sort(cells,function(a,b)return a[2]==b[2] and a[1]<b[1] or a[2]<b[2]end)
 -- Sample a bounded shore region, not the whole planet. All heights use radial rays.
 local spacing=16;local border=80
 local x0=math.floor((minE-border)/spacing)*spacing;local y0=math.floor((minN-border)/spacing)*spacing
 local nx=math.ceil((maxE+border-x0)/spacing);local ny=math.ceil((maxN+border-y0)/spacing)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={workspace.Terrain};params.IgnoreWater=true
 local land={};local valid=0
 for y=0,ny-1 do for x=0,nx-1 do
  assert(alive,'Integration stopped')
  local east,north=x0+(x+.5)*spacing,y0+(y+.5)*spacing
  local origin=Frame.toWorld(frame,Vector3.new(east,north,200));local normal=(origin-frame.center).Unit
  local hit=workspace:Raycast(origin,-normal*400,params)
  assert(hit,'Missing shore terrain sample')
  local altitude=(hit.Position-frame.center).Magnitude-frame.radius
  local slope=hit.Normal:Dot(normal)
  local nearest=math.huge
  for _,q in ipairs(wet)do nearest=math.min(nearest,(east-q[1])^2+(north-q[2])^2)end
  local eligible=altitude>=3 and slope>=.85 and nearest>=12^2 and nearest<=64^2 and hit.Material~=Enum.Material.Water
  land[#land+1]={altitude,slope,eligible};if eligible then valid+=1 end
  if #land%64==0 then task.wait()end
 end end
 assert(valid>0,'No suitable near-lake planting cells')
 return {schema=1,id=lake:GetAttribute('RegionId'),dataset=lake:GetAttribute('Dataset'),unit='stud',coordinates='east-north-radial-altitude',
  frame={center=vector(frame.center),radius=frame.radius,up=vector(frame.up),east=vector(frame.east),north=vector(frame.north)},
  water={grid=grid,cells=cells},land={origin={x0,y0},spacing=spacing,nx=nx,ny=ny,cells=land},
  biologyEnabled=false}
end
local function post(transport,endpoint,body)
 local start=os.clock();local encoded=Http:JSONEncode(body)
 local response=Http:RequestAsync({Url=string.gsub(transport.Url,'/exchange$',endpoint),Method='POST',Headers={['Content-Type']='application/json',['X-CI-Token']=transport.Token},Body=encoded})
 assert(response.Success,'Relay HTTP '..response.StatusCode)
 assert(#response.Body<=65536,'Oversized telemetry response')
 return Http:JSONDecode(response.Body),(os.clock()-start)*1000
end
local function main()
 local lake=RS:WaitForChild('CI_LakeWater',180);assert(lake,'Lake service missing')
 local deadline=os.clock()+180
 while alive and lake:GetAttribute('Status')~='Ready' do
  assert(lake:GetAttribute('Status')~='Failed','Lake audit failed');assert(os.clock()<deadline,'Lake audit timeout');task.wait(.2)
 end
 if not alive then return end
 status:SetAttribute('HabitatState','Surveying shoreline')
 local habitat=makeHabitat(lake)
 status:SetAttribute('HabitatState','Survey ready')
 -- Credentials remain server-only. Absence does not affect water or player movement.
 local integration=game:GetService('ServerScriptService'):FindFirstChild('CI_Integration')
 local config=integration and integration:FindFirstChild('LiveTransportConfig')
 if not config then status:SetAttribute('RelayState','Not configured');return end
 assert(Http.HttpEnabled,'Enable HTTP requests for relay integration')
 local transport=require(config)
 assert(type(transport.Url)=='string' and string.match(transport.Url,'/exchange$') and type(transport.Token)=='string' and #transport.Token>=32,'Invalid local transport configuration')
 assert(string.sub(transport.Url,1,8)=='https://' or (Run:IsStudio() and string.match(transport.Url,'^http://localhost:%d+/exchange$')),'HTTPS required outside Studio')
 local exported=false
 while alive do
  local ok,err=pcall(function()
   if not exported then
    local result=post(transport,'/habitat',habitat)
    assert(type(result.sha256)=='string' and #result.sha256==64,'Invalid habitat acknowledgment')
    status:SetAttribute('HabitatDigest',result.sha256);status:SetAttribute('HabitatState','Exported');exported=true
   end
   local result,rtt=post(transport,'/telemetry',{schema=1})
   assert(result.schema==1,'Telemetry schema mismatch')
   status:SetAttribute('RelayState','Connected');status:SetAttribute('HttpRoundTripMs',rtt)
   for _,key in ipairs({'RelayWorkMs','SimulationTicksPerSecond','SimulationTick','SnapshotAgeSeconds'})do
    local value=result[key];status:SetAttribute(key,if type(value)=='number' and value==value and math.abs(value)<math.huge then value else nil)
   end
   status:SetAttribute('SimulationState',result.state)
   status:SetAttribute('RelayTimestamp',workspace:GetServerTimeNow())
  end)
  if not ok then status:SetAttribute('RelayState','Unavailable');status:SetAttribute('RelayError',string.sub(tostring(err),1,160))end
  task.wait(1)
 end
end
task.spawn(function()local ok,err=xpcall(main,debug.traceback);if not ok and alive then status:SetAttribute('HabitatState','Blocked');warn('[CI Integration] '..tostring(err))end end)
