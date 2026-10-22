--!nonstrict
-- Reuse the original body library. These rigs illustrate biochemical populations.
-- Motion is cosmetic microdrift, not simulated advection or neural behavior.
local Factory=require(script.Parent.AgentModelFactory)
local Space=require(script.Parent.SimulationSpace)
local Contract=require(script.Parent.PlanetContract)
local M={MaximumPatches=6,MaximumParts=192,CyanoRadius=.16,DecomposerRadius=.42}
local frame=Contract.habitat.frame
local center=Vector3.new(unpack(frame.center))
local east=Vector3.new(unpack(frame.east))
local records={}
local Collection=game:GetService("CollectionService")
local ground=RaycastParams.new()
ground.FilterType=Enum.RaycastFilterType.Include
ground.FilterDescendantsInstances={workspace.Terrain}
local function oriented(p,up)
 local tangent=east-up*east:Dot(up)
 if tangent.Magnitude<.01 then tangent=up:Cross(Vector3.zAxis)end
 return CFrame.fromMatrix(p,tangent.Unit,up,tangent.Unit:Cross(up))
end
local function frameAt(x,y,z)
 local p=Space.toRobloxXYZ(x,y,z)
 return oriented(p,(p-center).Unit)
end
local specs={
 {name="SuspendedCyanobacteria",key="Cyanobacteria",pool=5,radius=.16,detail=2,attached=false},
 {name="CyanobacterialMatA",key="Cyanobacteria",pool=6,radius=.16,detail=2,attached=true,offset=-.18},
 {name="CyanobacterialMatB",key="Cyanobacteria",pool=6,radius=.16,detail=2,attached=true,offset=.18},
 {name="DecomposerColony",key="Bacterivore",pool=7,radius=.42,detail=1,attached=false},
}
assert(3*Factory.count("Cyanobacteria",2)+Factory.count("Bacterivore",1)<=M.MaximumParts/M.MaximumPatches,"Aquatic model budget")
local function baseFor(row,spec)
 if spec.attached then
  local p=Space.toRobloxXYZ(row[2]+spec.offset,row[3],row[4])
  local up=(p-center).Unit
  local hit=workspace:Raycast(p+up*12,-up*24,ground)
  local q=hit and Space.toSimulation(hit.Position)
  if not hit or not q or q.z>=107.6 then return nil end
  return oriented(hit.Position+hit.Normal*.085,hit.Normal)
 end
 local depth=108-row[4]
 -- Decomposer's flagellum is included in the clearance radius.
 if depth<spec.radius*2+.15 then return nil end
 local z=if spec.pool==5 then row[4]+depth*.72 else row[4]+math.min(1.5,depth*.5)
 z=math.clamp(z,row[4]+spec.radius+.04,108-spec.radius-.04)
 return frameAt(row[2],row[3],z)
end
local function drop(entry)
 if entry.rig then Factory.destroy(entry.rig);entry.rig=nil end
end
function M.create(row,parent)
 local model=Instance.new("Model");model.Name="AquaticPatch_"..row[1]
 model:SetAttribute("PatchId",row[1]);model:SetAttribute("Controller","Non-neural biochemistry")
 model:SetAttribute("Representation","Biomass population, magnified established microbial designs")
 local entries={}
 for _,spec in specs do table.insert(entries,{spec=spec,rig=nil,base=nil})end
 records[model]={entries=entries,groups={},phase=row[1]*2.39996}
 model.Parent=parent;M.update(model,row)
 return model
end
function M.update(model,row,context)
 local record=records[model];if not record then return end
 record.row=row
 for _,entry in record.entries do
  local spec=entry.spec
  -- Destroy dead representations; their material remains in C++ detritus/sediment.
  if row[spec.pool]<1e-6 then drop(entry);continue end
  if not entry.rig then
   entry.base=baseFor(row,spec)
   if entry.base then
    local group=record.groups[spec.pool]
    if not group then
     group=Instance.new("Model");group.Name=if spec.pool==5 then "SuspendedCyanobacteria" elseif spec.pool==6 then "CyanobacterialMat" else "DecomposerPopulation"
     group.Parent=model;record.groups[spec.pool]=group
     group:SetAttribute("CI_OrganismId","aq-"..row[1].."-"..spec.pool)
     group:SetAttribute("CI_BiologyKind","Population")
     group:SetAttribute("CI_Species",if spec.pool==5 then "Cyanobacteria · suspended" elseif spec.pool==6 then "Cyanobacteria · attached mat" else "Aerobic decomposers")
     group:SetAttribute("CI_BiomassUnits",if spec.pool==6 then "mmol C/m²" else "mmol C/m³")
     group:SetAttribute("CI_Lifecycle","Population")
     Collection:AddTag(group,"CI_Organism")
    end
    entry.rig=Factory.create(spec.key,group,spec.radius,spec.detail)
    entry.rig.model.Name=spec.name
    entry.rig.model:SetAttribute("BiologicalRole",if spec.pool==7 then "Aerobic decomposer; adapted body design" else "Photosynthetic cyanobacterial population")
    entry.rig.model:SetAttribute("NeuralController",false)
    entry.rig.model:SetAttribute("MotionMeaning",if spec.attached then "Attached to substrate" else "Cosmetic microdrift; no hydrodynamic claim")
   end
  end
  if entry.rig then
   local reference=if spec.pool==6 then 40 elseif spec.pool==5 then 2 else .8
   local density=math.clamp(math.sqrt(row[spec.pool]/reference),0,1)
   local opacity=math.clamp(.65-.6*density,.05,.65)
   local par=if spec.attached then row[16] else row[15]
   local activity=par/(par+80)
   entry.rig.model:SetAttribute("Biomass",row[spec.pool])
   entry.rig.model:SetAttribute("BiomassUnits",if spec.attached then "mmol C/m2" else "mmol C/m3")
   entry.rig.model:SetAttribute("PhotosyntheticLightResponse",if spec.pool~=7 then activity else nil)
   for _,state in entry.rig.states do
    state.part.Transparency=opacity;state.part.CanQuery=true
    if spec.pool~=7 then
     -- Keep original pigment blocks; modest daylight tint indicates light availability.
     if not state.originalColor then state.originalColor=state.part.Color end
     state.part.Color=state.originalColor:Lerp(Color3.fromRGB(91,167,77),activity*.3)
    end
   end
   Factory.pose(entry.rig,entry.base,record.phase,0)
  end
 end
 for pool,group in record.groups do
  if row[pool]<1e-6 then
   Collection:RemoveTag(group,"CI_Organism");group:Destroy();record.groups[pool]=nil
  elseif context then
   group:SetAttribute("CI_BiologyTimestamp",context.stamp)
   group:SetAttribute("CI_Run",context.run);group:SetAttribute("CI_SimulationTick",context.revision)
   group:SetAttribute("CI_PatchId",row[1]);group:SetAttribute("CI_Biomass",row[pool])
   group:SetAttribute("CI_OrganicN",row[pool]*16/106);group:SetAttribute("CI_OrganicP",row[pool]/106)
   group:SetAttribute("CI_Oxygen",if pool==5 then row[9] else row[10])
   group:SetAttribute("CI_PAR",if pool==6 then row[16] else row[15])
   group:SetAttribute("CI_DIC",row[11]);group:SetAttribute("CI_NH4",row[12]);group:SetAttribute("CI_NO3",row[13]);group:SetAttribute("CI_PO4",row[14])
   group:SetAttribute("CI_SedimentCarbon",row[8])
   group:SetAttribute("CI_NetBiomassChange",context.rates and context.rates[pool])
   group:SetAttribute("CI_NeuralController",false)
  end
 end
end
function M.animate(model,t)
 local record=records[model];if not record then return end
 for _,entry in record.entries do
  if entry.rig and not entry.spec.attached then
   local phase=t*.7+record.phase
   -- Vertical-only, sub-body-size offset avoids moving into unsurveyed adjacent terrain.
   local drift=math.sin(phase)*.025
   local strength=if entry.spec.pool==7 then .2*math.clamp(record.row[10]/250,0,1) else 0
   Factory.pose(entry.rig,entry.base*CFrame.new(0,drift,0),phase,strength)
  end
 end
end
function M.destroy(model)
 local record=records[model]
 if record then
  for _,group in record.groups do Collection:RemoveTag(group,"CI_Organism")end
  for _,entry in record.entries do drop(entry)end
  records[model]=nil
 end
 model:Destroy()
end
return M
