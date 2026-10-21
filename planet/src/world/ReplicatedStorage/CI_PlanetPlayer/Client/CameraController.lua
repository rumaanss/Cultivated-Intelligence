--!nonstrict
local UIS=game:GetService("UserInputService")
local F=require(script.Parent.Parent.Shared.PlanetFrame)
local Look=require(script.Parent.Parent.Shared.LookState)
local Camera={};Camera.__index=Camera
function Camera.new(character,rig,body,config)
 local up=F.up(rig.root.Position,config.Center)
 local self=setmetatable({character=character,rig=rig,body=body,config=config,hidden={},visible={},accessories={},
  look=Look.new(up,F.tangent(rig.root.CFrame.LookVector,up),config),camera=workspace.CurrentCamera},Camera)
 self.saved={type=self.camera.CameraType,fov=self.camera.FieldOfView,fovMode=self.camera.FieldOfViewMode,
  subject=self.camera.CameraSubject,mouse=UIS.MouseBehavior,icon=UIS.MouseIconEnabled}
 self.params=RaycastParams.new();self.params.FilterType=Enum.RaycastFilterType.Exclude
 self.params.FilterDescendantsInstances={character};self.params.RespectCanCollide=true
 self:add(rig.head)
 for _,part in character:GetDescendants() do self:add(part) end
 self.descendant=character.DescendantAdded:Connect(function(part) self:add(part) end)
 self.look:step(up,0,0,false,0)
 return self
end
function Camera:add(part)
 if not part:IsA("BasePart") then return end
 if part==self.rig.head then self.hidden[part]=part.LocalTransparencyModifier
 elseif part:FindFirstAncestorWhichIsA("Accessory") then self.accessories[part]=part.LocalTransparencyModifier
 elseif part.Parent==self.character then self.visible[part]=part.LocalTransparencyModifier end
end
function Camera:step(dt,input)
 local root=self.rig.root;local up=F.up(root.Position,self.config.Center)
 local dx,dy,free=input:look();self.look:step(up,dx,dy,free,dt)
 local look=self.look
 local eye=self.body:eye(up,look.flat)
 local origin=root.Position+up*0.5
 local hit=workspace:Spherecast(origin,0.18,eye-origin,self.params)
 self.obstructed=hit~=nil
 if hit then eye=origin+(eye-origin).Unit*math.max(0,hit.Distance-0.08) end
 -- An explicit up vector avoids lookAt singularities when looking straight down.
 local right=look.flat:Cross(up).Unit
 local cf=CFrame.fromMatrix(eye,right,look.viewUp,-look.gaze)
 local camera=workspace.CurrentCamera;self.camera=camera
 camera.CameraType=Enum.CameraType.Scriptable
 camera.FieldOfViewMode=Enum.FieldOfViewMode.Vertical;camera.FieldOfView=self.config.FOV
 camera.CFrame=cf;camera.Focus=CFrame.new(eye+look.gaze*20)
 UIS.MouseBehavior=if input:available() then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
 UIS.MouseIconEnabled=not input:available()
 for part in self.hidden do if part.Parent then part.LocalTransparencyModifier=1 end end
 -- Override stock first-person transparency after the default camera render priority.
 -- RootPart stays invisible through its actual Transparency, not a hidden-body modifier.
 for part in self.visible do if part.Parent then part.LocalTransparencyModifier=0 end end
 for part,original in self.accessories do
  if not part.Parent then self.accessories[part]=nil;continue end
  local weld=part:FindFirstChildWhichIsA("Weld")
  local headMounted=weld and (weld.Part0==self.rig.head or weld.Part1==self.rig.head)
  local p=part.CFrame:PointToObjectSpace(eye);local half=part.Size*0.5+Vector3.one*0.25
  local obstructs=math.abs(p.X)<half.X and math.abs(p.Y)<half.Y and math.abs(p.Z)<half.Z
  part.LocalTransparencyModifier=if headMounted or obstructs then 1 else original
 end
 self.eye=eye
 return look
end
function Camera:gameplayAim()
 -- Free-look gaze is inspection only. Weapons must use this explicit policy boundary.
 local l=self.look
 return {origin=self.eye,direction=l.forward*math.cos(l.pitch)+l.up*math.sin(l.pitch),
  allowed=l.mode=="Normal",time=workspace:GetServerTimeNow()}
end
function Camera:destroy()
 self.descendant:Disconnect()
 for part,value in self.hidden do if part.Parent then part.LocalTransparencyModifier=value end end
 for part,value in self.visible do if part.Parent then part.LocalTransparencyModifier=value end end
 for part,value in self.accessories do if part.Parent then part.LocalTransparencyModifier=value end end
 if self.camera then
  self.camera.CameraType=self.saved.type;self.camera.FieldOfView=self.saved.fov
  self.camera.FieldOfViewMode=self.saved.fovMode;self.camera.CameraSubject=self.saved.subject
 end
 UIS.MouseBehavior=self.saved.mouse;UIS.MouseIconEnabled=self.saved.icon
end
return Camera
