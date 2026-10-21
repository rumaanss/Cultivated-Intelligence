-- Lightweight Luau test doubles; these do not simulate Roblox rendering or physics.
local activeConnections=0
local function signal()
 local s={listeners={}}
 function s:Connect(fn)
  local c={Connected=true,fn=fn};activeConnections+=1
  function c:Disconnect()if self.Connected then self.Connected=false;activeConnections-=1 end end
  table.insert(self.listeners,c);return c
 end
 function s:Fire(...)for _,c in ipairs(table.clone(self.listeners))do if c.Connected then c.fn(...)end end end
 return s
end
local function enumCategory(name)return setmetatable({},{__index=function(t,k)local v={Name=k,Value=k=="Camera"and 200 or 0};rawset(t,k,v);return v end})end
local Enum=setmetatable({},{__index=function(t,k)local c=enumCategory(k);rawset(t,k,c);return c end})
local Color3={fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end}
local UDim={new=function(s,o)return {Scale=s,Offset=o}end}
local udmeta={};local UDim2={}
function UDim2.new(xs,xo,ys,yo)return setmetatable({X=UDim.new(xs,xo),Y=UDim.new(ys,yo)},udmeta)end
function UDim2.fromOffset(x,y)return UDim2.new(0,x,0,y)end
function UDim2.fromScale(x,y)return UDim2.new(x,0,y,0)end
udmeta.__add=function(a,b)return UDim2.new(a.X.Scale+b.X.Scale,a.X.Offset+b.X.Offset,a.Y.Scale+b.Y.Scale,a.Y.Offset+b.Y.Offset)end
local Vector2={new=function(x,y)return {X=x,Y=y}end}
local vm={};local Vector3={}
function Vector3.new(x,y,z)return setmetatable({X=x,Y=y,Z=z},vm)end
vm.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vm.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vm.__unm=function(a)return Vector3.new(-a.X,-a.Y,-a.Z)end
vm.__mul=function(a,b)if type(a)=="number"then a,b=b,a end;return Vector3.new(a.X*b,a.Y*b,a.Z*b)end
vm.__div=function(a,b)return Vector3.new(a.X/b,a.Y/b,a.Z/b)end
vm.__index=function(a,k)
 if k=="Magnitude"then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)elseif k=="Unit"then return a/a.Magnitude
 elseif k=="Lerp"then return function(a,b,t)return a+(b-a)*t end
 elseif k=="Dot"then return function(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end
 elseif k=="Cross"then return function(a,b)return Vector3.new(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X)end end
end
Vector3.zero=Vector3.new(0,0,0);Vector3.yAxis=Vector3.new(0,1,0);Vector3.xAxis=Vector3.new(1,0,0)
local CFrame={lookAt=function(pos,target,up)return {Position=pos}end}
local RaycastParams={new=function()return {}end};local OverlapParams={new=function()return {}end}
local TweenInfo={new=function(...)return {...}end}
local function clone(v)if type(v)~="table"then return v end;local c={};for k,x in pairs(v)do c[k]=clone(x)end;return c end
local function encode(v)
 if type(v)=="string"then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"' end
 if type(v)=="number"or type(v)=="boolean"then return tostring(v)end
 if type(v)=="nil"then return 'null'end
 local out={};if #v>0 then for _,x in ipairs(v)do table.insert(out,encode(x))end;return '['..table.concat(out,',')..']'end
 for k,x in pairs(v)do if type(x)~="function"then table.insert(out,encode(tostring(k))..':'..encode(x))end end;return '{'..table.concat(out,',')..'}'
end
local Instance={};local methods={};local im={};local instances={}
local guiClasses={Frame=true,CanvasGroup=true,TextLabel=true,TextButton=true,TextBox=true,ViewportFrame=true,ScrollingFrame=true}
function Instance.new(class)
 local t=setmetatable({_p={ClassName=class,Name=class,Visible=true,Text="",Archivable=true,BackgroundTransparency=0,TextTransparency=0,
 Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(100,100),AnchorPoint=Vector2.new(0,0),AbsoluteSize=Vector2.new(1672,900)},_children={},_signals={},_attributes={}},im)
 table.insert(instances,t);return t
end
im.__index=function(t,k)
 if methods[k]then return methods[k]end
 if t._p[k]~=nil then return t._p[k]end
 if k=="Activated"or k=="MouseEnter"or k=="MouseLeave"or k=="Destroying"then t._signals[k]=t._signals[k]or signal();return t._signals[k]end
 for _,c in ipairs(t._children)do if c.Name==k then return c end end
 return nil
end
im.__newindex=function(t,k,v)
 if k=="Parent"then
  local old=t._p.Parent
  if old then local i=table.find(old._children,t);if i then table.remove(old._children,i)end end
  if v then table.insert(v._children,t)end
 end
 local changed=t._p[k]~=v;t._p[k]=v
 if changed and t._signals[k]then t._signals[k]:Fire()end
end
function methods:IsA(c)return self.ClassName==c or(c=="GuiObject"and guiClasses[self.ClassName])or(c=="BasePart"and self.ClassName=="Part")or(c=="LuaSourceContainer"and self.ClassName=="LocalScript")end
function methods:GetChildren()return table.clone(self._children)end
function methods:GetDescendants()local out={};for _,c in ipairs(self._children)do table.insert(out,c);for _,v in ipairs(c:GetDescendants())do table.insert(out,v)end end;return out end
function methods:FindFirstChild(name)for _,c in ipairs(self._children)do if c.Name==name then return c end end end
function methods:FindFirstChildOfClass(cl)for _,c in ipairs(self._children)do if c:IsA(cl)then return c end end end
methods.FindFirstChildWhichIsA=methods.FindFirstChildOfClass
function methods:WaitForChild(name)return assert(self:FindFirstChild(name),name)end
function methods:GetAttribute(n)return self._attributes[n]end
function methods:SetAttribute(n,v)self._attributes[n]=v end
function methods:GetPropertyChangedSignal(k)self._signals[k]=self._signals[k]or signal();return self._signals[k]end
function methods:IsDescendantOf(root)local p=self.Parent;while p do if p==root then return true end;p=p.Parent end;return false end
function methods:Destroy()
 for _,v in ipairs(self:GetChildren())do v:Destroy()end
 for _,s in pairs(self._signals)do for _,c in ipairs(s.listeners)do c:Disconnect()end end
 self.Parent=nil;self._p.destroyed=true
end
function methods:ClearAllChildren()for _,v in ipairs(self:GetChildren())do v:Destroy()end end
function methods:ReleaseFocus()end
local delays={};local task={delay=function(_,fn)table.insert(delays,fn)end}
local now=100
local workspace=Instance.new("Workspace");workspace.Terrain=Instance.new("Terrain");workspace.Terrain.Parent=workspace
workspace.GetServerTimeNow=function()return now end
workspace.Raycast=function()return nil end
local player=Instance.new("Player");local pg=Instance.new("PlayerGui");pg.Name="PlayerGui";pg.Parent=player
local replicated=Instance.new("ReplicatedStorage")
local tags={};local tagAdded=signal();local tagRemoved=signal()
local services={Players={LocalPlayer=player},UserInputService={InputBegan=signal(),GetFocusedTextBox=function()return nil end},
 RunService={Heartbeat=signal(),BindToRenderStep=function()end,UnbindFromRenderStep=function()end},
 CollectionService={GetTagged=function()return tags end,HasTag=function(_,o)return table.find(tags,o)~=nil end,GetInstanceAddedSignal=function()return tagAdded end,GetInstanceRemovedSignal=function()return tagRemoved end},
 ReplicatedStorage=replicated,Lighting={TimeOfDay="12:00:00"},
 HttpService={JSONEncode=function(_,v)return encode(v)end,JSONDecode=function(_,v)return {time=now,position={1,2,3},contact={reason="supported"},cameraMode="Normal"}end},
 TweenService={pending={}}}
function services.TweenService:Create(obj,info,goals)
 local t={Completed=signal(),cancelled=false}
 function t:Play()table.insert(services.TweenService.pending,self)end
 function t:Cancel()self.cancelled=true;self.Completed:Fire(Enum.PlaybackState.Cancelled)end
 function t:finish()if not self.cancelled then for k,v in pairs(goals)do obj[k]=v end;self.Completed:Fire(Enum.PlaybackState.Completed)end end
 return t
end
local function finishTweens()local all=services.TweenService.pending;services.TweenService.pending={};for _,t in ipairs(all)do t:finish()end end
local game={GetService=function(_,name)return assert(services[name],name)end}
