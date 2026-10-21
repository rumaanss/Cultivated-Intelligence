--!nonstrict
local R={}
-- Neutral joint geometry, independent of asynchronous Motor6D solve / animation / replication.
function R.neutralFrames(character,root)
 local frames={[root]=CFrame.identity}
 for _=1,12 do
  local changed=false
  for _,joint in character:GetDescendants() do
   if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
    if frames[joint.Part0] and not frames[joint.Part1] then
     frames[joint.Part1]=frames[joint.Part0]*joint.C0*joint.C1:Inverse();changed=true
    elseif frames[joint.Part1] and not frames[joint.Part0] then
     frames[joint.Part0]=frames[joint.Part1]*joint.C1*joint.C0:Inverse();changed=true
    end
   end
  end
  if not changed then break end
 end
 return frames
end
function R.measure(character)
 local root=assert(character:FindFirstChild("HumanoidRootPart"),"Missing R6 root")
 local head=assert(character:FindFirstChild("Head"),"Missing R6 head")
 local torso=assert(character:FindFirstChild("Torso"),"Expected default R6 Torso")
 local humanoid=assert(character:FindFirstChildOfClass("Humanoid"),"Missing Humanoid")
 assert(humanoid.RigType==Enum.HumanoidRigType.R6,"IMP_PPLAYERSPAWN requires R6")
 local foot=character:GetAttribute("CI_FootOffset")
 local hp=character:GetAttribute("CI_HeadOffset")
 if foot==nil or hp==nil then
  local frames=R.neutralFrames(character,root);foot=0
  for _,name in {"Left Leg","Right Leg"} do
   local leg=assert(character:FindFirstChild(name),"Missing R6 leg")
   local frame=assert(frames[leg],"R6 joints not fully replicated")
   local size=leg.Size*0.5
   local extent=math.abs(frame.RightVector.Y)*size.X+math.abs(frame.UpVector.Y)*size.Y+math.abs(frame.LookVector.Y)*size.Z
   foot=math.max(foot,-frame.Position.Y+extent)
  end
  hp=assert(frames[head],"Missing R6 head joint chain").Position
 end
 assert(type(foot)=="number" and foot>1 and foot<6,"Unsupported R6 dimensions")
 return {root=root,head=head,torso=torso,humanoid=humanoid,foot=foot,headOffset=hp,
  headSize=character:GetAttribute("CI_HeadSize") or head.Size}
end
return table.freeze(R)
