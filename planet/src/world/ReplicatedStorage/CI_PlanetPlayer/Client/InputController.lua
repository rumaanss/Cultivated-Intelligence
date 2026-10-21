--!nonstrict
local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local Gui=game:GetService("GuiService")
local I={};I.__index=I
function I.new()
 local self=setmetatable({keys={},jump=false,enabled=false,cursor=false,focused=true,connections={}},I)
 local mappings={Forward=Enum.KeyCode.W,Back=Enum.KeyCode.S,Left=Enum.KeyCode.A,Right=Enum.KeyCode.D,
  Sprint=Enum.KeyCode.LeftShift,Free=Enum.KeyCode.LeftAlt,Dive=Enum.KeyCode.LeftControl,Jump=Enum.KeyCode.Space}
 for name,key in mappings do
  CAS:BindActionAtPriority("CI_Player_"..name,function(_,state)
   if not self:available() then self.keys[name]=nil;return Enum.ContextActionResult.Pass end
   self.keys[name]=state==Enum.UserInputState.Begin or state==Enum.UserInputState.Change
   if name=="Jump" and state==Enum.UserInputState.Begin then self.jump=true end
   return Enum.ContextActionResult.Sink
  end,false,3000,key)
 end
 self.mappings=mappings
 table.insert(self.connections,UIS.WindowFocusReleased:Connect(function() self.focused=false;self:clear() end))
 table.insert(self.connections,UIS.WindowFocused:Connect(function() self.focused=true end))
 table.insert(self.connections,UIS.TextBoxFocused:Connect(function() self:clear() end))
 table.insert(self.connections,Gui.MenuOpened:Connect(function() self:clear() end))
 return self
end
function I:available() return self.enabled and self.focused and not self.cursor and not Gui.MenuIsOpen and UIS:GetFocusedTextBox()==nil end
function I:clear() table.clear(self.keys);self.jump=false;self.lookReady=false end
function I:movement()
 if not self:available() then self:clear() end
 -- Poll held movement keys as well as sinking CAS actions: no stale/missed Begin state.
 if self:available() then
  for name,key in self.mappings do
   self.keys[name]=UIS:IsKeyDown(key)
  end
 end
 local k=self.keys;local jump=self.jump;self.jump=false
 return {x=(if k.Right then 1 else 0)-(if k.Left then 1 else 0),z=(if k.Forward then 1 else 0)-(if k.Back then 1 else 0),sprint=k.Sprint==true,jump=jump,ascend=k.Jump==true,descend=k.Dive==true}
end
function I:look()
 if not self:available() then self.lookReady=false;return 0,0,false end
 if UIS.MouseBehavior~=Enum.MouseBehavior.LockCenter then self.lookReady=false;return 0,0,self.keys.Free==true end
 if not self.lookReady then self.lookReady=true;UIS:GetMouseDelta();return 0,0,self.keys.Free==true end
 local delta=UIS:GetMouseDelta() -- Already includes Roblox user sensitivity; never multiply by dt.
 return delta.X,delta.Y,UIS:IsKeyDown(Enum.KeyCode.LeftAlt)
end
function I:destroy()
 self:clear()
 for name in self.mappings do CAS:UnbindAction("CI_Player_"..name) end
 for _,c in self.connections do c:Disconnect() end
end
return I
