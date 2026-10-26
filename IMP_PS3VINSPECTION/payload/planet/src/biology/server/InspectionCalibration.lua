--!nonstrict
-- Explicit Studio-only diagnostics. Does not change organisms, terrain or time.
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local Space=require(RS.CI_Biology.SimulationSpace)
local Contract=require(RS.CI_Biology.PlanetContract)
local M={}
local function world(v)return Space.toRobloxXYZ(v[1],v[2],v[3])end
local function sim(p)local q=Space.toSimulation(p);return Vector3.new(q.x,q.y,q.z)end
local function arr(p)return {p.X,p.Y,p.Z}end
function M.Geometry(fixture)
 assert(Run:IsStudio(),"Calibration must use a Studio test session")
 assert(fixture.schema==1 and fixture.habitat==Contract.habitat.sha256,"Fixture contract mismatch")
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={workspace.Terrain};params.IgnoreWater=true
 local rows,errors,angles={}, {}, {};local mismatches=0;local roundTrip=0
 for i,r in fixture.rays do
  local a,b=world(r.from),world(r.to);local hit=workspace:Raycast(a,b-a,params)
  local out={index=i,kind=r.kind,expectedHit=r.hit,actualHit=hit~=nil}
  roundTrip=math.max(roundTrip,(sim(a)-Vector3.new(table.unpack(r.from))).Magnitude)
  if r.hit~=(hit~=nil)then mismatches+=1
  elseif hit then
   local e=r.expected;local expected=world(e);local err=(expected-hit.Position).Magnitude
   local n=r.normal;local dx=world({e[1]+.01,e[2],e[3]-.01*n[1]/n[3]})-expected
   local dy=world({e[1],e[2]+.01,e[3]-.01*n[2]/n[3]})-expected
   local normal=dx:Cross(dy).Unit
   if normal:Dot(expected-Vector3.new(table.unpack(Contract.habitat.frame.center)))<0 then normal=-normal end
   local angle=math.deg(math.acos(math.clamp(normal:Dot(hit.Normal),-1,1)))
   out.errorStuds=err;out.normalDegrees=angle;out.actual=arr(hit.Position)
   table.insert(errors,err);table.insert(angles,angle)
  end
  table.insert(rows,out)
  if i%32==0 then task.wait()end
 end
 table.sort(errors);table.sort(angles)
 local summary={schema=1,kind="IMP_PS3VINSPECTION geometry",habitat=fixture.habitat,studio=version(),count=#rows,hitMismatches=mismatches,maxErrorStuds=errors[#errors] or 0,p95ErrorStuds=errors[math.max(1,math.ceil(#errors*.95))] or 0,maxNormalDegrees=angles[#angles] or 0,roundTripStuds=roundTrip,tolerances={fixture.heightToleranceStuds,fixture.normalToleranceDegrees,fixture.roundTripToleranceStuds},rows=rows}
 summary.passed=mismatches==0 and summary.maxErrorStuds<=fixture.heightToleranceStuds and summary.maxNormalDegrees<=fixture.normalToleranceDegrees and roundTrip<=fixture.roundTripToleranceStuds
 print("CI_GEOMETRY_REPORT "..Http:JSONEncode(summary));return summary
end
function M.Blocker(position)
 assert(Run:IsStudio(),"Use an isolated Studio experiment")
 local p=Instance.new("Part");p.Name="CI_OpticalCalibrationBlocker";p.Anchored=true;p.Size=Vector3.new(24,2,24);p.Position=position;p.Material=Enum.Material.Slate
 p:SetAttribute("CI_OpticalTransmission",0);p.Parent=workspace;game:GetService("CollectionService"):AddTag(p,"CI_SensorySurface")
 return p -- Caller removes it when finished. Physics and sensing remain explicit.
end
function M.Sensors(nativePosition)
 assert(Run:IsStudio(),"Use an isolated Studio experiment")
 local Service=require(script.Parent.InspectionService);local origin=world(nativePosition)
 local up=(origin-Vector3.new(table.unpack(Contract.habitat.frame.center))).Unit
 local blocker=M.Blocker(origin+up*10);blocker.CFrame=CFrame.lookAt(origin+up*10,origin)*CFrame.Angles(math.pi/2,0,0)
 task.wait() -- allow deferred CollectionService registration
 local result={studio=version(),origin=nativePosition}
 local ok,err=pcall(function()
  result.opaque=Service.transmission(origin,up*20)
  blocker:SetAttribute("CI_OpticalTransmission",.5);result.transmissive=Service.transmission(origin,up*20)
  blocker:Destroy();result.open=Service.transmission(origin,up*20)
  result.passed=result.opaque==0 and math.abs(result.transmissive-.5)<1e-6 and result.open==1
 end)
 blocker:Destroy();if not ok then result.error=tostring(err);result.passed=false end
 print("CI_SENSOR_CALIBRATION "..Http:JSONEncode(result));return result
end
return M
