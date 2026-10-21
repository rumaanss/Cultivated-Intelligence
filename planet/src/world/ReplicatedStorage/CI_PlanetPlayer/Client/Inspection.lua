--!nonstrict
local Http=game:GetService("HttpService")
local F=require(script.Parent.Parent.Shared.PlanetFrame)
local D={}
function D.capture(character,movement,camera,config)
 local r=character.HumanoidRootPart;local s=movement.snapshot
 local up=F.up(r.Position,config.Center)
 local actual=F.tangent(r.CFrame.LookVector,up)
 local force=r:FindFirstChild("CI_Gravity")
 local count=0;for _,child in r:GetChildren() do if child:IsA("VectorForce") and child.Name=="CI_Gravity" then count+=1 end end
 local backend=movement.backend
 local right=s.forward:Cross(up)
 local drive=r:FindFirstChild("CI_Locomotion")
 local nativeCount=0
 for _,item in character:GetDescendants() do if item:IsA("ControllerManager") then nativeCount+=1 end end
 local obstacle=nil
 if s.desiredTravel and s.desiredTravel.Magnitude>0.01 then
  obstacle=workspace:Spherecast(r.Position,config.CapsuleRadius,s.desiredTravel.Unit*2,movement.backend.params)
 end
 local function v(p) return {p.X,p.Y,p.Z} end
 return {water=s.water,locomotionMode=s.mode,version=config.Version,dataset=config.DatasetId,generation=character:GetAttribute("CI_Generation"),
  time=workspace:GetServerTimeNow(),position=v(r.Position),velocity=v(r.AssemblyLinearVelocity),up=v(up),
  altitude=F.altitude(r.Position,config.Center,config.SeaRadius),grounded=s.grounded,
  groundDistance=if s.hit then s.hit.Distance else nil,
  slopeDegrees=if s.hit then math.deg(math.acos(math.clamp(s.hit.Normal:Dot(up),-1,1))) else nil,
  headingErrorDegrees=math.deg(F.yaw(actual,s.forward,up)),
  upErrorDegrees=math.deg(math.acos(math.clamp(r.CFrame.UpVector:Dot(up),-1,1))),
  gravityAcceleration=if force and not r.Anchored then force.Force.Magnitude/r.AssemblyMass else 0,
  forceCount=count,cameraMode=camera.look.mode,cameraObstructed=camera.obstructed,
  heading=v(s.forward),eye=if camera.eye then v(camera.eye) else nil,
  sensitivity=camera.look.sensitivity,filteredLookSamples=camera.look.filteredSamples,
  contact=s.contact,backend="PhysicalCapsule",requestedController=backend.mode,nativeControllerCount=nativeCount,
  inputX=s.inputX or 0,inputZ=s.inputZ or 0,strafeSpeed=r.AssemblyLinearVelocity:Dot(right),
  forwardSpeed=r.AssemblyLinearVelocity:Dot(s.forward),
  obstruction=if obstacle then {name=obstacle.Instance:GetFullName(),distance=obstacle.Distance,normal=v(obstacle.Normal)} else nil,
  desiredTravel=if s.desiredTravel then v(s.desiredTravel) else nil,
  driveForce=if drive then v(drive.Force) else nil,
  contactSampleAge=if s.contact then workspace:GetServerTimeNow()-s.contact.sampleTime else nil,
  anchored=r.Anchored,spawnSite=character:GetAttribute("CI_SpawnSite"),
  collisionCertified=false}
end
function D.bookmark(character,movement,camera,config)
 local record=D.capture(character,movement,camera,config)
 print("CI_PLAYER_BOOKMARK "..Http:JSONEncode(record));return record
end
return table.freeze(D)
