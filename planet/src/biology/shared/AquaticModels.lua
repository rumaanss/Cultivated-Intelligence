--!nonstrict
-- Reuse the original body library. These rigs illustrate biochemical populations.
-- Legacy foundation mode uses microdrift; pdnarna-4 uses authoritative tracks.
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
local function baseFor(row,spec,sample)
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
 if sample then z=sample[22] end
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
 if context and context.physiology then model:SetAttribute("Representation","Representative reproductive colonies; magnified microbial designs")end
 if context then
  for pool,group in record.groups do
   local sample=context.colonies and context.colonies[pool]
   local identity=sample and (context.run..":"..sample[3]) or nil
   if group:GetAttribute("CI_ColonyIdentity")~=identity or (context.physiology and not sample)then
    for _,entry in record.entries do if entry.spec.pool==pool then drop(entry)end end
    Collection:RemoveTag(group,"CI_Organism");group:Destroy();record.groups[pool]=nil
   end
  end
 end
 for _,entry in record.entries do
  local spec=entry.spec
  -- Destroy dead representations; their material remains in C++ detritus/sediment.
  if row[spec.pool]<1e-6 or (context and context.physiology and not (context.colonies and context.colonies[spec.pool])) then drop(entry);continue end
  if not entry.rig then
   entry.base=baseFor(row,spec,context and context.colonies and context.colonies[spec.pool])
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
     local sample=context and context.colonies and context.colonies[spec.pool]
     if sample then
      group:SetAttribute("CI_ColonyIdentity",context.run..":"..sample[3])
      group:SetAttribute("CI_OrganismId","aq-"..sample[3])
      group:SetAttribute("CI_BiologyKind","Colony");group:SetAttribute("CI_Lifecycle","Reproductive colony")
      group:SetAttribute("CI_BiomassUnits","mmol C")
     end
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
   local sample=context and context.colonies and context.colonies[spec.pool]
   if sample and not spec.attached then entry.base=baseFor(row,spec,sample) or entry.base end
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
   local sample=context.colonies and context.colonies[pool]
   if sample then
    local upper=sample[22]>(row[4]+108)*.5
    group:SetAttribute("CI_Oxygen",if upper then row[9] else row[10])
    group:SetAttribute("CI_PAR",if upper then row[15] else row[16])
    local keys={"CI_ColonyId","CI_ParentId","CI_GenomeId","CI_Generation","CI_AgeTicks","CI_StructuralCarbon","CI_ReserveCarbon","CI_ReserveNitrogen","CI_ReservePhosphorus","CI_DNA","CI_RNA","CI_Protein","CI_Replication","CI_Assimilation","CI_Respiration","CI_Biomass","CI_OrganicN","CI_OrganicP","CI_Ploidy"}
    for i,key in keys do group:SetAttribute(key,sample[i+2])end
    group:SetAttribute("CI_BiomassUnits","mmol C")
   end
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
-- pdnarna-4: persistent individual tracks, bounded to 24 magnified colonies.
-- Colors encode inherited regulatory alleles; these are research markers.
M.MaximumColonies=24
local tracks={}
local behaviorNames={"Resting","Exploring","Light response","Food response","Oxygen response","Passive mixing","Attached"}
local function vector(row)return Vector3.new(row[23],row[24],row[25])end
local function resize(rig,radius)
 local scale=radius/rig.design.safeRadius
 if math.abs(scale-rig.scale)<1e-6 then return end
 local ratio=scale/rig.scale
 for _,s in rig.states do
  s.part.Size=s.part.Size*ratio
  s.bind=CFrame.new(s.bind.Position*ratio)*s.bind.Rotation
 end
 rig.scale=scale
end
local function removeTrack(id)
 local t=tracks[id];if not t then return end
 Collection:RemoveTag(t.model,"CI_Organism");Factory.destroy(t.rig);t.model:Destroy();tracks[id]=nil
end
function M.clearIndividuals()
 local ids={};for id in tracks do table.insert(ids,id)end
 for _,id in ids do removeTrack(id)end
end
local function poseTrack(t,now)
 local alpha=math.clamp((now-t.started)/t.duration,0,1)
 local p=t.from:Lerp(t.to,alpha)
 t.display=p
 local point=Space.toRobloxXYZ(p.X,p.Y,p.Z)
 local up=(point-center).Unit
 local root=oriented(point,up)
 if t.row[2]==1 then
  local hit=workspace:Raycast(point+up*12,-up*24,ground)
  if hit then root=oriented(hit.Position+hit.Normal*.12,hit.Normal)end
 elseif (t.to-t.from).Magnitude>.001 then
  local endpoint=Space.toRobloxXYZ(t.to.X,t.to.Y,t.to.Z)
  local startpoint=Space.toRobloxXYZ(t.from.X,t.from.Y,t.from.Z)
  local heading=endpoint-startpoint
  heading=heading-up*heading:Dot(up)
  if heading.Magnitude>.001 then
   local forward=heading.Unit;root=CFrame.fromMatrix(point,forward:Cross(up),up,-forward)
  end
 end
 local growth=t.oldGrowth+(t.growth-t.oldGrowth)*alpha
 t.displayGrowth=growth
 if t.dead then
  local fade=math.clamp((now-t.dead)/.8,0,1);growth*=math.max(.05,1-fade)
  for _,state in t.rig.states do state.part.Transparency=fade end
 end
 resize(t.rig,(if t.row[2]==2 then .5 else .3)*growth)
 -- Joint motion accompanies measured travel; stale stationary colonies do not swim.
 local active=if alpha<1 and t.row[2]~=1 then math.clamp((t.to-t.from).Magnitude,0,1) else 0
 Factory.pose(t.rig,root,now*5+t.row[3],active)
 t.model:SetAttribute("CI_DisplayX",p.X);t.model:SetAttribute("CI_DisplayY",p.Y);t.model:SetAttribute("CI_DisplayZ",p.Z)
end
function M.syncIndividuals(packet,parent,stamp,now)
 local patches={};for _,r in packet.patches do patches[r[1]]=r end
 local wanted,rows={},{}
 -- Preserve existing visible IDs first, then admit offspring/other samples.
 for _,r in packet.colonies do if tracks[r[3]] then table.insert(rows,r)end end
 for _,r in packet.colonies do if not tracks[r[3]] then table.insert(rows,r)end end
 local deaths={};for _,e in packet.lifecycle or {} do if e[2]==2 then deaths[e[3]]=true end end
 local present={};for _,r in rows do present[r[3]]=true end
 local used,dying=0,0
 local expired={}
 for id,t in tracks do
  if t.dead and now-t.dead>=.8 then table.insert(expired,id)
  elseif not present[id] and deaths[id] then
   t.dead=t.dead or now;t.model:SetAttribute("CI_Lifecycle","Died; material returned to detritus")
   used+=#t.rig.states;dying+=1;wanted[id]=true
  end
 end
 for _,id in expired do removeTrack(id)end
 local selected={}
 for _,r in rows do
  local key=if r[2]==2 then "Bacterivore" else "Cyanobacteria"
  local cost=Factory.count(key,if r[2]==2 then 1 else 2)
  if #selected+dying<M.MaximumColonies and used+cost<=M.MaximumParts then
   table.insert(selected,r);wanted[r[3]]=true;used+=cost
  end
 end
 local remove={};for id in tracks do if not wanted[id]then table.insert(remove,id)end end
 for _,id in remove do removeTrack(id)end
 local births,divisions={},{}
 for _,e in packet.lifecycle or {} do if e[2]==1 then births[e[3]]=e;divisions[e[4]]=e[3]end end
 for _,r in selected do
  local t=tracks[r[3]]
  if not t then
   local model=Instance.new("Model");model.Name="Colony_"..r[3];model.Parent=parent
   local rig=Factory.create(if r[2]==2 then "Bacterivore" else "Cyanobacteria",model,if r[2]==2 then .5 else .3,if r[2]==2 then 1 else 2)
   t={model=model,rig=rig,row=r,from=vector(r),to=vector(r),display=vector(r),started=now,duration=1,growth=1,oldGrowth=1}
   tracks[r[3]]=t
   model:SetAttribute("CI_OrganismId","aq-"..r[3]);model:SetAttribute("CI_ColonyIdentity",packet.run..":"..r[3])
   model:SetAttribute("CI_BiologyKind","Colony");model:SetAttribute("CI_NeuralController",false)
   model:SetAttribute("CI_Species",if r[2]==2 then "Aerobic decomposer" elseif r[2]==1 then "Attached producer" else "Suspended producer")
   model:SetAttribute("Representation","Sampled colony; magnified body; allele color encoding")
   model:SetAttribute("MotionMeaning","Interpolated C++ position; local non-neural response")
   Collection:AddTag(model,"CI_Organism")
  end
  if t.revision~=packet.revision then
   poseTrack(t,now)
   t.from=t.display;t.to=vector(r);t.started=now
   t.duration=if t.revision then math.clamp((packet.revision-t.revision)/20,.05,2) else 1
   t.oldGrowth=t.displayGrowth or t.growth;t.growth=math.clamp((r[8]/r[26])^(1/3),.5,1.3)
   t.revision=packet.revision;t.row=r
   local model=t.model;local patch=patches[r[1]]
   model:SetAttribute("CI_BiologyTimestamp",stamp);model:SetAttribute("CI_Run",packet.run);model:SetAttribute("CI_SimulationTick",packet.revision)
   model:SetAttribute("CI_PatchId",r[1]);model:SetAttribute("CI_BiomassUnits","mmol C")
   local keys={"CI_ColonyId","CI_ParentId","CI_GenomeId","CI_Generation","CI_AgeTicks","CI_StructuralCarbon","CI_ReserveCarbon","CI_ReserveNitrogen","CI_ReservePhosphorus","CI_DNA","CI_RNA","CI_Protein","CI_Replication","CI_Assimilation","CI_Respiration","CI_Biomass","CI_OrganicN","CI_OrganicP","CI_Ploidy"}
   for i,key in keys do model:SetAttribute(key,r[i+2])end
   model:SetAttribute("CI_Behavior",behaviorNames[r[27]+1]);model:SetAttribute("CI_DistanceStuds",r[28]);model:SetAttribute("CI_MovementCarbon",r[29])
   model:SetAttribute("CI_SensingActivity",r[30]);model:SetAttribute("CI_MotorActivity",r[31])
   model:SetAttribute("CI_SensingAllele",r[38]);model:SetAttribute("CI_MotilityAllele",r[39])
   model:SetAttribute("CI_Lifecycle",if births[r[3]] and r[7]<=200 then "New offspring" elseif divisions[r[3]] then "Divided; offspring "..divisions[r[3]] elseif r[15]>.8 then "DNA replication near completion" else "Growing colony")
   if patch then
    local upper=r[25]>(patch[4]+108)*.5
    model:SetAttribute("CI_Oxygen",if upper then patch[9] else patch[10]);model:SetAttribute("CI_PAR",if upper then patch[15] else patch[16])
    for i,key in {"CI_DIC","CI_NH4","CI_NO3","CI_PO4"}do model:SetAttribute(key,patch[10+i])end
   end
   local hue=0
   for i=32,39 do hue+=(r[i]-1)*(i-30)*1.7 end
   local baseHue=if r[2]==2 then .58 elseif r[2]==1 then .22 else .33
   local tint=Color3.fromHSV((baseHue+hue)%1,.65,.9)
   for _,s in t.rig.states do
    s.part.CanQuery=true;s.part.Transparency=.08;s.originalColor=s.originalColor or s.part.Color
    s.part.Color=s.originalColor:Lerp(tint,.65)
   end
  end
  poseTrack(t,now)
 end
 parent:SetAttribute("VisibleColonies",#selected);parent:SetAttribute("VisibleParts",used)
 parent:SetAttribute("Representation","Bounded sample of real C++ colonies")
end
function M.animateIndividuals(now)
 local expired={}
 for id,t in tracks do
  if t.dead and now-t.dead>=.8 then table.insert(expired,id) else poseTrack(t,now)end
 end
 for _,id in expired do removeTrack(id)end
end

return M
