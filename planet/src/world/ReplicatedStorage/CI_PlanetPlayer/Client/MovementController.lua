--!nonstrict
local Shared=script.Parent.Parent.Shared
local F=require(Shared.PlanetFrame);local B=require(Shared.PhysicsBackend);local S=require(Shared.Scalar)
local Lake=(function()
-- nonstrict
-- Read-only habitat query shared by swimming, camera presentation and future biology.
local Lake={};local cached=nil
function Lake.sample(position)
 if not cached then
  local state=game:GetService('ReplicatedStorage'):FindFirstChild('CI_LakeWater')
  if not state or state:GetAttribute('Status')~='Ready' then return nil end
  local data=state:FindFirstChild('FloorMap');if not data then return nil end
  cached={state=state,floors=game:GetService('HttpService'):JSONDecode(data.Value),
   center=state:GetAttribute('Center'),radius=state:GetAttribute('Radius'),grid=state:GetAttribute('Grid'),id=state:GetAttribute('RegionId'),
   up=state:GetAttribute('Up'),east=state:GetAttribute('East'),north=state:GetAttribute('North')}
 end
 if cached.state:GetAttribute('Status')~='Ready' then return nil end
 local relative=position-cached.center
 local dot=relative:Dot(cached.up);if dot<cached.radius-200 then return nil end
 local i=math.floor(relative:Dot(cached.east)*cached.radius/dot/cached.grid+.5)
 local j=math.floor(relative:Dot(cached.north)*cached.radius/dot/cached.grid+.5)
 local floor=cached.floors[tostring(i)..','..tostring(j)]
 if not floor or floor>=0 then return nil end
 local depth=cached.radius-relative.Magnitude
 if depth> -floor+4 then return nil end
 return {depth=depth,floorDepth=-floor,id=cached.id,surfaceRadius=cached.radius}
end
return Lake

end)()
local Swim=(function()
-- strict
-- Controlled neutral buoyancy for the R6 test diver, not a fluid solver.
local Swim={}
function Swim.verticalTarget(depth: number,axis: number): number
 if axis~=0 then return math.clamp(axis,-1,1)*6 end
 -- Quiet surface float; deeper neutral input holds depth.
 return if depth<3 then math.clamp((depth-1.4)*2,-2,2) else 0
end
function Swim.gain(dt: number): number
 local h=math.clamp(dt,1/240,1/15)
 return (1-math.exp(-5*h))/h
end
return Swim

end)()
local M={};M.__index=M
function M.new(character,rig,c)
 return setmetatable({rig=rig,config=c,backend=B.connect(character,rig,c),detachUntil=0,
  snapshot={grounded=false,velocity=Vector3.zero,forward=rig.root.CFrame.LookVector}},M)
end
function M:step(input,look,now,dt)
 local root=self.rig.root;local up=F.up(root.Position,self.config.Center)
 local forward=F.transport(look.forward,look.up,up)
 local x,z=S.axes(input.x,input.z)
 local direction=forward*z+forward:Cross(up)*x
 local grounded,hit=B.step(self.backend,up,forward,direction,input.sprint,now<self.detachUntil,dt)
 local water=Lake.sample(root.Position)
 local swimming=water~=nil and water.depth>(if self.swimming then -.25 else .5)
 -- At a shallow bank the physical capsule and normal walk/jump retain control.
 if grounded and water and water.depth<1.5 then swimming=false end
 self.swimming=swimming
 if swimming then
  local axis=(if input.ascend then 1 else 0)-(if input.descend then 1 else 0)
  local desired=direction*(if input.sprint then 10 else 7)+up*Swim.verticalTarget(water.depth,axis)
  local acceleration=(desired-root.AssemblyLinearVelocity)*Swim.gain(dt or 1/60)
  if acceleration.Magnitude>45 then acceleration=acceleration.Unit*45 end
  -- Cancel radial gravity for the test diver; never use world-Y buoyancy.
  self.backend.motor.Force=(up*self.config.Gravity+acceleration)*root.AssemblyMass
  self.backend.grounded=false;self.backend.mode="Swim";grounded=false
  self.backend.contact.reason="lake-swimming"
  self.backend.contact.desiredSpeed=desired.Magnitude
 end
 if input.jump and grounded and not swimming then
  self.detachUntil=now+self.config.JumpDetachSeconds
  B.detach(self.backend)
  local speed=S.jumpSpeed(self.config.Gravity,self.config.JumpHeight)
  local relativeUp=root.AssemblyLinearVelocity:Dot(up)
  -- Impulse, not velocity overwrite: preserves tangential momentum and external impulses.
  root:ApplyImpulse(up*math.max(0,speed-relativeUp)*root.AssemblyMass)
  grounded=false
 end
 self.snapshot={up=up,forward=forward,desiredTravel=direction,grounded=grounded,hit=hit,
  inputX=input.x,inputZ=input.z,contact=self.backend.contact,velocity=root.AssemblyLinearVelocity,water=water,mode=if swimming then "Swim" elseif grounded then "Ground" else "Air"}
 return self.snapshot
end
function M:stop()
 B.stop(self.backend)
end
return M
