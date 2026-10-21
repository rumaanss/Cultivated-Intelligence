--!strict
local M={}
type Candidate = {id:number,p:any,d:number}
local parent=script.Parent;assert(parent~=nil)
local asset=parent:FindFirstChild("PlantAssetLibrary");assert(asset~=nil and asset:IsA("ModuleScript"))
local Art=require(asset)
function M.new(root:Instance):any return {root=root,plants={},parts=0} end
local function remove(renderer:any,id:number)
 local rig=renderer.plants[id];if not rig then return end
 renderer.parts-=#rig.items;rig.model:Destroy();renderer.plants[id]=nil
end
function M.select(renderer:any,records:any,cameraPosition:Vector3,config:any,roots:boolean)
 local candidates: {Candidate}={}
 for id,p in records do
  local d=(Vector3.new(p.position[1],p.position[2],p.position[3])-cameraPosition).Magnitude
  if d<=config.FarDistance then
   local visual=p
   local resolveGround = config.ResolveGround
   if type(resolveGround)=="function" then
    visual=table.clone(p);visual.position={p.position[1],(resolveGround :: (any) -> number)(p),p.position[3]}
   end
   table.insert(candidates,{id=id,p=visual,d=d})
  end
 end
 table.sort(candidates,function(a:Candidate,b:Candidate)return if a.d==b.d then a.id<b.id else a.d<b.d end)
 local keep={};local plans={};local used=0
 for rank,c in candidates do
  if rank>config.MaximumRenderedPlants then break end
  local lod=if c.d<config.NearDistance then 2 elseif c.d<config.MidDistance then 1 else 0
  local pieces=Art.geometry(c.p,lod,roots)
  if used+#pieces>config.MaximumParts then lod=0;pieces=Art.geometry(c.p,0,false) end
  if used+#pieces>config.MaximumParts then continue end
  keep[c.id]=true;used+=#pieces
  table.insert(plans,{id=c.id,p=c.p,lod=lod,pieces=pieces})
 end
 -- Complete all releases before allocating replacements, including rapid camera jumps.
 local removed={};for id in renderer.plants do if not keep[id] then table.insert(removed,id) end end
 for _,id in removed do remove(renderer,id) end
 for _,plan in plans do
  local rig=renderer.plants[plan.id]
  if rig then
   local wanted={};for _,d in plan.pieces do wanted[d.key]=true end
   local obsolete={};for key in rig.byKey do if not wanted[key] then table.insert(obsolete,key) end end
   for _,key in obsolete do rig.byKey[key].part:Destroy();rig.byKey[key]=nil;renderer.parts-=1 end
  end
 end
 for _,plan in plans do
  local rig=renderer.plants[plan.id]
  if not rig then
   local model=Instance.new("Model");model.Name="Plant_"..plan.id;model:SetAttribute("PlantId",plan.id);model:SetAttribute("Species",plan.p.species);model.Parent=renderer.root
   rig={model=model,items={},byKey={}};renderer.plants[plan.id]=rig
  end
  local ordered={}
  for _,d in plan.pieces do
   local state=rig.byKey[d.key]
   if not state then
    local part:BasePart=if d.shape=="Wedge" then Instance.new("WedgePart") else Instance.new("Part")
    if part:IsA("Part") and d.shape=="Ball" then part.Shape=Enum.PartType.Ball end
    part.Name=d.key;part:SetAttribute("OrganId",d.id);part.Size=d.size*.05;part.CFrame=d.cf;part.Color=d.color
    part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=plan.lod==2
    part.Material=Enum.Material.SmoothPlastic;part.Parent=rig.model
    state={part=part,target=d,base=d.cf};rig.byKey[d.key]=state;renderer.parts+=1
   end
   state.target=d;table.insert(ordered,state)
  end
  rig.items=ordered
  rig.model:SetAttribute("Action",plan.p.action);rig.model:SetAttribute("Result",plan.p.result);rig.model:SetAttribute("Generation",plan.p.generation)
 end
 renderer.root:SetAttribute("NativeParts",renderer.parts)
end
function M.pose(renderer:any,dt:number,time:number)
 local alpha=1-math.exp(-dt*7)
 for id,rig in renderer.plants do for _,state in rig.items do
  local d=state.target;state.base=state.base:Lerp(d.cf,alpha)
  state.part.CFrame=state.base*CFrame.Angles(math.sin(time*1.4+id+d.id*.7)*d.wind,0,0)
  state.part.Size=state.part.Size:Lerp(d.size,alpha);state.part.Color=state.part.Color:Lerp(d.color,alpha)
 end end
end
function M.clear(renderer:any)
 local ids={};for id in renderer.plants do table.insert(ids,id) end
 for _,id in ids do remove(renderer,id) end
end
return M
