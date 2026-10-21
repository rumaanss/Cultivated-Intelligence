--!nonstrict
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local Run=game:GetService("RunService")
local shared=RS:WaitForChild("CI_Biology")
local Config=table.clone(require(shared.PlantConfig))
local Protocol=require(shared.PlantProtocol)
local Renderer=require(shared.PlantRenderer)
local Space=require(shared.SimulationSpace)
local Contract=require(shared.PlanetContract)
local remote=RS:WaitForChild("CI_PlantChannel",200)
if not remote then return end
local root=Instance.new("Folder");root.Name="CI_PlanetPlants";root.Parent=workspace
local renderer=Renderer.new(root)
local litterRoot=Instance.new("Folder");litterRoot.Name="GroundLitter";litterRoot.Parent=root
local litterParts={}
local function renderLitter(rows,camera)
 local candidates={}
 for _,row in rows do
  local position=Space.plantPosition({row[2],row[3],row[4]})
  local distance=(position-camera).Magnitude
  if distance<Config.FarDistance then table.insert(candidates,{row=row,d=distance})end
 end
 table.sort(candidates,function(a,b)return a.d<b.d end)
 local keep={}
 for index,item in candidates do
  if index>128 then break end
  local row=item.row;local id=row[1];keep[id]=true
  local part=litterParts[id]
  if not part then
   part=Instance.new("Part");part.Name="LitterCell_"..id;part.Anchored=true
   part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
   part.Material=Enum.Material.Ground;part.Color=Color3.fromRGB(70,54,35)
   part.Parent=litterRoot;litterParts[id]=part
  end
  local position={row[2],row[3],row[4]}
  position[2]=Config.ResolveGround({id="litter-"..id,position=position})
  local extent=math.clamp(math.sqrt(row[5])*.3,.15,3)
  part.Size=Vector3.new(extent,.035,extent)
  part.CFrame=Space.plantFrame(position)*CFrame.new(0,.018,0)
  part:SetAttribute("StoredCarbon",row[5])
 end
 for id,part in litterParts do if not keep[id]then part:Destroy();litterParts[id]=nil end end
end
local state=nil
local transfer=nil
local lastRequest=-10
local function resync()
 if os.clock()-lastRequest>=2 then lastRequest=os.clock();remote:FireServer() end
end
local cache={}
local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={workspace.Terrain};params.IgnoreWater=true
local center=Vector3.new(table.unpack(Contract.habitat.frame.center))
Config.ResolveGround=function(p)
 local old=cache[p.id]
 if old and old.x==p.position[1] and old.z==p.position[3] then return old.y end
 local position=Space.plantPosition(p.position);local up=(position-center).Unit
 local hit=workspace:Raycast(position+up*80,-up*160,params)
 local y=if hit then (hit.Position-center).Magnitude-Contract.habitat.frame.radius else p.position[2]
 -- Terrain may stream in later; only cache a successful native hit.
 if hit then cache[p.id]={x=p.position[1],z=p.position[3],y=y} end
 return y
end
local receive=remote.OnClientEvent:Connect(function(serial,index,count,data)
 local ok,err=pcall(function()
  assert(type(serial)=="number" and serial%1==0 and type(index)=="number" and index%1==0 and type(count)=="number" and count%1==0 and count>=1 and count<=175 and index>=1 and index<=count,"Invalid plant chunk counters")
  assert(type(data)=="string" and #data<=48000,"Invalid plant chunk bytes")
  if not transfer or transfer.id~=serial then assert(index==1,"Missing first plant chunk");transfer={id=serial,count=count,next=1,bytes=0,parts={},at=os.clock()} end
  assert(transfer.count==count and transfer.next==index,"Plant chunk gap")
  transfer.bytes+=#data;assert(transfer.bytes<=8*1024*1024,"Plant packet budget")
  table.insert(transfer.parts,data);transfer.next+=1
  if index<count then return end
  local packet=Http:JSONDecode(table.concat(transfer.parts));transfer=nil
  local updated,reason=Protocol.apply(state,packet);assert(updated,reason)
  if not state or state.run~=updated.run then Renderer.clear(renderer);table.clear(cache) end
  state=updated
  for id in cache do if type(id)=="number" and not state.records[id]then cache[id]=nil end end
  Config.SnapshotTime=workspace:GetServerTimeNow()-math.max(0,tonumber(packet.age) or 0)
  local environment=state.environment
  if environment then
   for _,key in {"daylight","atmosphericCarbon","assimilationTotal","respirationTotal"}do
    root:SetAttribute(key,environment[key])
   end
  end
  root:SetAttribute("Tick",state.tick);root:SetAttribute("Status","Connected")
 end)
 if not ok then transfer=nil;root:SetAttribute("Status",tostring(err));resync() end
end)
local selectElapsed,poseElapsed=0,0
local frame=Run.Heartbeat:Connect(function(dt)
 if transfer and os.clock()-transfer.at>5 then transfer=nil;resync() end
 if not state then resync();return end
 selectElapsed+=dt;poseElapsed+=dt
 if selectElapsed>=Config.SelectionSeconds then
  selectElapsed=0
  local camera=workspace.CurrentCamera
  if camera then Renderer.select(renderer,state.records,camera.CFrame.Position,Config,Config.ShowRoots);renderLitter(state.litter,camera.CFrame.Position) end
 end
 if poseElapsed>=1/Config.PoseHz then Renderer.pose(renderer,poseElapsed,os.clock());poseElapsed=0 end
end)
resync()
script.Destroying:Connect(function()receive:Disconnect();frame:Disconnect();Renderer.clear(renderer);root:Destroy()end)
