--!nonstrict
-- Physical capsule support. No ControllerManager, levitation controller, or CFrame movement.
local G=require(script.Parent.GravityField)
local F=require(script.Parent.PlanetFrame)
local Policy=require(script.Parent.ContactPolicy)
local Motion=require(script.Parent.LocomotionMath)
local B={}
function B.prepare(character,rig,c)
 local h,root=rig.humanoid,rig.root
 local animate=character:FindFirstChild("Animate")
 if animate and (animate:IsA("LocalScript") or animate:IsA("Script")) then animate.Enabled=false end
 h.AutoRotate=false;h.EvaluateStateMachine=false;h.WalkSpeed=0;h.JumpPower=0;h.BreakJointsOnDeath=false
 for _,part in character:GetDescendants() do
  if part:IsA("ControllerManager") then part:Destroy()
  elseif part:IsA("BasePart") then part.CanCollide=false end
 end
 local animator=h:FindFirstChildOfClass("Animator")
 if not animator then animator=Instance.new("Animator");animator.Parent=h end
 assert(not character:FindFirstChild("CI_Controller"),"Duplicate player backend")
 local container=Instance.new("Folder");container.Name="CI_Controller";container.Parent=character
 container:SetAttribute("Backend","PhysicalCapsule")
 local radius=c.CapsuleRadius
 local bottom=-rig.foot+radius
 local top=rig.headOffset.Y+rig.headSize.Y*0.5-radius
 assert(top>bottom,"Invalid capsule calibration")
 local function collider(name,shape,size,offset)
  local part=Instance.new("Part");part.Name=name;part.Shape=shape;part.Size=size
  part.Transparency=1;part.CastShadow=false;part.Massless=true
  part.CanCollide=true;part.CanTouch=false;part.CanQuery=true
  part.CustomPhysicalProperties=PhysicalProperties.new(0.7,0,0,100,100)
  part.CFrame=root.CFrame*offset;part.Parent=container
  local weld=Instance.new("WeldConstraint");weld.Part0=root;weld.Part1=part;weld.Parent=part
  return part
 end
 local diameter=radius*2
 collider("LowerSphere",Enum.PartType.Ball,Vector3.one*diameter,CFrame.new(0,bottom,0))
 collider("UpperSphere",Enum.PartType.Ball,Vector3.one*diameter,CFrame.new(0,top,0))
 -- Roblox cylinders run along local X; rotate to the character's local Y.
 collider("Middle",Enum.PartType.Cylinder,Vector3.new(top-bottom,diameter,diameter),
  CFrame.new(0,(top+bottom)*0.5,0)*CFrame.Angles(0,0,math.pi/2))
 G.create(root)
 local attachment=Instance.new("Attachment");attachment.Name="CI_MotionAttachment";attachment.Parent=root
 local force=Instance.new("VectorForce");force.Name="CI_Locomotion";force.Attachment0=attachment
 force.RelativeTo=Enum.ActuatorRelativeTo.World;force.ApplyAtCenterOfMass=true;force.Parent=root
 local align=Instance.new("AlignOrientation");align.Name="CI_Orientation";align.Attachment0=attachment
 align.Mode=Enum.OrientationAlignmentMode.OneAttachment;align.AlignType=Enum.AlignType.AllAxes
 align.RigidityEnabled=false;align.Responsiveness=c.OrientationResponsiveness
 align.MaxTorque=1e8;align.MaxAngularVelocity=c.TurnSpeed;align.CFrame=root.CFrame.Rotation;align.Parent=root
end
function B.connect(character,rig,c)
 rig.humanoid.AutoRotate=false;rig.humanoid.EvaluateStateMachine=false
 local root=rig.root
 local collider=assert(character:FindFirstChild("CI_Controller"),"Missing capsule backend")
 assert(collider:FindFirstChild("LowerSphere") and collider:FindFirstChild("UpperSphere") and collider:FindFirstChild("Middle"),"Capsule has not replicated")
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={character};params.RespectCanCollide=true;params.IgnoreWater=true
 return {container=assert(character:FindFirstChild("CI_Controller")),root=root,rig=rig,config=c,params=params,
  force=assert(root:FindFirstChild("CI_Gravity")),motor=assert(root:FindFirstChild("CI_Locomotion")),
  orientation=assert(root:FindFirstChild("CI_Orientation")),mode="Air",grounded=false}
end
function B.step(b,up,facing,direction,sprint,detach,dt)
 local c,root=b.config,b.root
 G.update(b.force,root,c.Center,c.Gravity)
 b.orientation.CFrame=CFrame.lookAt(Vector3.zero,F.tangent(facing,up),up)
 local hit=workspace:Raycast(root.Position,-up*c.DiagnosticProbeLength,b.params)
 -- Shape cast a slightly smaller sole from above its resting center. This matches
 -- the real collider footprint on slopes without treating every perimeter ray as a flat foot.
 local radius=c.CapsuleRadius
 local lift=0.5
 local origin=root.Position-up*(b.rig.foot-radius)+up*lift
 local sole=workspace:Spherecast(origin,radius-0.04,-up*(lift+c.GroundProbeExtra+0.2),b.params)
 if sole and sole.Material~=Enum.Material.Water and sole.Normal:Dot(up)>=math.cos(math.rad(c.MaxSlope)) then hit=sole end
 local normalDot=if hit then hit.Normal:Dot(up) else 0
 local height=if hit then (root.Position-hit.Position):Dot(up) else nil
 -- Plane distance is evaluated at root's radial line, not at an offset contact point.
 if hit and normalDot>0.05 then height=(root.Position-hit.Position):Dot(hit.Normal)/normalDot end
 local expected=Motion.supportHeight(b.rig.foot,radius,normalDot)
 local platformVelocity=Vector3.zero
 if hit and hit.Instance:IsA("BasePart") then platformVelocity=hit.Instance:GetVelocityAtPosition(hit.Position) end
 local relative=root.AssemblyLinearVelocity-platformVelocity
 local separating=if hit then relative:Dot(hit.Normal) else relative:Dot(up)
 local grounded,reason=Policy.classify(height,expected,normalDot,
  hit~=nil and hit.Material==Enum.Material.Water,detach,separating,b.grounded,c.GroundEnterExtra,c.GroundProbeExtra,math.cos(math.rad(c.MaxSlope)))
 if grounded~=b.grounded then b.transitions=(b.transitions or 0)+1 end
 b.grounded=grounded;b.mode=if grounded then "Ground" else "Air"
 local normal=if grounded then hit.Normal else up
 local acceleration,desired=Motion.acceleration(direction,relative,normal,-up*c.Gravity,
  if sprint then c.SprintSpeed else c.WalkSpeed,grounded,dt or 1/60,c)
 b.motor.Force=if root.Anchored then Vector3.zero else acceleration*root.AssemblyMass
 b.contact={reason=reason,phase="PreSimulation",sampleTime=workspace:GetServerTimeNow(),
  transitions=b.transitions or 0,relativeUp=relative:Dot(up),separatingSpeed=separating,
  footOffset=b.rig.foot,supportHeight=expected,distance=height,
  gap=if height then height-expected else nil,reach=expected+(if grounded then c.GroundProbeExtra else c.GroundEnterExtra),
  hitName=if hit then hit.Instance:GetFullName() else "none",material=if hit then hit.Material.Name else "none",
  desiredSpeed=desired.Magnitude,actualSpeed=Motion.project(relative,normal).Magnitude,
  acceleration=acceleration.Magnitude,backend="PhysicalCapsule"}
 return grounded,hit
end
function B.detach(b)
 b.grounded=false;b.mode="Air";b.motor.Force=Vector3.zero
 if b.contact then b.contact.reason="jump-detach" end
end
function B.stop(b) if b.motor.Parent then b.motor.Force=Vector3.zero end end
return table.freeze(B)
