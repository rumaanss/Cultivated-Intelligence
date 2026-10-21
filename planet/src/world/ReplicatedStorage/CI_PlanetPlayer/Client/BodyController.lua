--!nonstrict
local S=require(script.Parent.Parent.Shared.Scalar)
local Body={};Body.__index=Body
function Body.new(character,rig,config)
 local self=setmetatable({character=character,rig=rig,config=config,joints={},phase=0,yaw=0,pitch=0,blend=0},Body)
 for _,name in {"Neck","Left Shoulder","Right Shoulder","Left Hip","Right Hip"} do
  local joint=rig.torso:FindFirstChild(name)
  if joint and joint:IsA("Motor6D") then self.joints[name]={joint=joint,base=joint.C0} end
 end
 return self
end
function Body:pose(name,rotation)
 local entry=self.joints[name];if not entry then return end
 -- Modify the joint rest frame from its saved baseline. Animator owns Transform.
 -- No cumulative multiplication; no stale Transform layering when Animator throttles.
 entry.joint.C0=CFrame.new(entry.base.Position)*rotation*entry.base.Rotation
end
function Body:step(dt,snapshot,yaw,pitch)
 local c=self.config
 self.yaw+=(math.clamp(yaw,-c.NeckYaw,c.NeckYaw)-self.yaw)*S.alpha(20,dt)
 self.pitch+=(math.clamp(pitch,-c.NeckPitch,c.NeckPitch)-self.pitch)*S.alpha(20,dt)
 local up=snapshot.up;local velocity=snapshot.velocity
 local speed=(velocity-up*velocity:Dot(up)).Magnitude
 local target=if snapshot.grounded then math.clamp(speed/c.WalkSpeed,0,1.35) else 0
 self.blend+=(target-self.blend)*S.alpha(14,dt)
 self.phase=(self.phase+dt*speed*0.72)%(math.pi*2)
 -- Asset-independent classic R6 gait on actual joints, with action-track opt-out.
 -- Future animation/weapon systems set CI_ProceduralWeight=0 while they own limbs.
 local weight=math.clamp(self.character:GetAttribute("CI_ProceduralWeight") or 1,0,1)
 local animator=self.rig.humanoid:FindFirstChildOfClass("Animator")
 if animator then
  for _,track in animator:GetPlayingAnimationTracks() do
   if track.Priority~=Enum.AnimationPriority.Core and track.Priority~=Enum.AnimationPriority.Idle
    and track.WeightCurrent>0.01 then weight=0;break end
  end
 end
 local swing=math.sin(self.phase)*0.52*self.blend*weight
 local signed=if velocity:Dot(snapshot.forward)<-0.5 then -1 else 1
 local neckWeight=math.clamp(self.character:GetAttribute("CI_NeckWeight") or 1,0,1)
 self:pose("Neck",CFrame.Angles(self.pitch*neckWeight,self.yaw*neckWeight,0))
 self:pose("Left Hip",CFrame.Angles(swing*signed,0,0))
 self:pose("Right Hip",CFrame.Angles(-swing*signed,0,0))
 self:pose("Left Shoulder",CFrame.Angles(-swing*0.75*signed,0,0))
 self:pose("Right Shoulder",CFrame.Angles(swing*0.75*signed,0,0))
end
function Body:eye(up,flat)
 local r=self.rig
 -- Measured neutral head height; animation rotation cannot feed back into gaze.
 -- Front offset follows gaze around a bounded anatomical eye pivot.
 return r.root.Position+up*(r.headOffset.Y+r.headSize.Y*self.config.EyeHeightFraction)
  +flat*(r.headSize.Z*self.config.EyeFrontFraction)
end
function Body:destroy()
 for _,entry in self.joints do if entry.joint.Parent then entry.joint.C0=entry.base end end
end
return Body
