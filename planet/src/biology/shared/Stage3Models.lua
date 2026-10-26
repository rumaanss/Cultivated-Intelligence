--!nonstrict
-- Self-contained native mesh fallback. Biological dimensions come from C++.
local M={MaximumParts=2800,MaximumGrazersPerGuild=3,MaximumAlgae=8}
local Data=require(script.Parent.Stage3MeshData)
local Space=require(script.Parent.SimulationSpace)
local Collection=game:GetService("CollectionService")
local ground=RaycastParams.new()
ground.FilterType=Enum.RaycastFilterType.Include
ground.FilterDescendantsInstances={workspace.Terrain}
ground.IgnoreWater=true
local tracks={}
-- Intersect the authored mesh once; cilia roots follow its actual surface,
-- including the asymmetric bacterial notch and recessed microalgal waist.
local anchors={}
for _,key in {"BacterialGrazer","MicroalgalGrazer"} do
 local data=Data[key];local roots={};anchors[key]=roots
 local function vertex(i)local v=data.vertices[i+1];return Vector3.new(v[1],v[2],v[3])end
 for i=1,12 do
  local angle=i*math.pi/6;local direction=Vector3.new(math.cos(angle),0,math.sin(angle))
  local origin=Vector3.new(0,-.12,0);local nearest=math.huge
  for _,face in data.faces do
   local a,b,c=vertex(face[1]),vertex(face[2]),vertex(face[3])
   local e1,e2=b-a,c-a;local h=direction:Cross(e2);local det=e1:Dot(h)
   if math.abs(det)>1e-8 then
    local inv=1/det;local offset=origin-a;local u=offset:Dot(h)*inv
    local q=offset:Cross(e1);local v=direction:Dot(q)*inv;local distance=e2:Dot(q)*inv
    if u>=-1e-6 and v>=-1e-6 and u+v<=1+1e-6 and distance>0 then nearest=math.min(nearest,distance)end
   end
  end
  assert(nearest<math.huge,"Missing grazer cilium surface")
  roots[i]={origin+direction*(nearest-.025),direction}
 end
end
local function part(t,index)
 local p=t.parts[index]
 if not p then p=Instance.new("WedgePart");p.Name="Tissue";p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=true;p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic;p.Parent=t.model;t.parts[index]=p end
 return p
end
local function triangle(t,a,b,c,color,root)
 local ab,ac,bc=b-a,c-a,c-b
 if ab:Dot(ab)>ac:Dot(ac) and ab:Dot(ab)>bc:Dot(bc)then c,a=a,c
 elseif ac:Dot(ac)>bc:Dot(bc)then a,b=b,a end
 ab,ac,bc=b-a,c-a,c-b
 local cross=ac:Cross(ab);if cross.Magnitude<1e-7 or bc.Magnitude<1e-7 then return end
 local right=cross.Unit;local back=bc.Unit;local up=bc:Cross(right).Unit
 local height=math.abs(ab:Dot(up))
 for _,q in {{(a+b)*.5,right,up,back,math.abs(ab:Dot(back))},{(a+c)*.5,-right,up,-back,math.abs(ac:Dot(back))}}do
  t.used+=1;local p=part(t,t.used);p.Size=Vector3.new(.012,math.max(.012,height),math.max(.012,q[5]));p.CFrame=root*CFrame.fromMatrix(q[1],q[2],q[3],q[4]);p.Color=color
 end
end
local function mesh(t,key,frame,size,tint)
 local data=Data[key];local points={}
 for i,v in data.vertices do points[i]=frame:PointToWorldSpace(Vector3.new(v[1]*size.X,v[2]*size.Y,v[3]*size.Z))end
 for i,f in data.faces do local rgb=data.colors[i];local color=Color3.fromRGB(rgb[1],rgb[2],rgb[3]);if tint then color=color:Lerp(tint,.12)end
  triangle(t,points[f[1]+1],points[f[2]+1],points[f[3]+1],color,t.root)
 end
end
local function clearTrack(id)
 local t=tracks[id];if t then Collection:RemoveTag(t.model,"CI_Organism");t.model:Destroy();tracks[id]=nil end
end
function M.clear()M.displayStatus={};local ids={};for id in tracks do table.insert(ids,id)end;for _,id in ids do clearTrack(id)end end
local function rootAt(position,attachment)
 local point=Space.toRobloxXYZ(position.X,position.Y,position.Z)
 local up=Space.toRobloxXYZ(position.X,position.Y,position.Z+.1)-point;up=up.Unit
 local direction=Space.toRobloxXYZ(position.X+.1,position.Y,position.Z)-point
 local right=direction:Cross(up).Unit
 return CFrame.fromMatrix(attachment or point,right,up,right:Cross(up))
end
local function pose(t,now)
 local alpha=math.clamp((now-t.start)/t.duration,0,1);local position=t.from:Lerp(t.to,alpha);t.display=position;t.root=rootAt(position);t.used=0
 local row=t.row;local tint=Color3.fromHSV((row[42]*.06+.25)%1,.45,.65)
 if row[2]==5 then
  -- Native placement remains authoritative. Correct only the visual height
  -- against Roblox's voxel surface; water and organism parts cannot be hits.
  -- Algae are posed on snapshot revisions, so this is never a per-frame ray.
  local point=Space.toRobloxXYZ(position.X,position.Y,position.Z)
  local up=(Space.toRobloxXYZ(position.X,position.Y,position.Z+.1)-point).Unit
  local hit=workspace:Raycast(point+up*12,-up*24,ground)
  local q=hit and Space.toSimulation(hit.Position)
  if not hit or not q or q.z>=107.8 then
   for _,p in t.parts do p:Destroy()end;t.parts={}
   t.model:SetAttribute("CI_AttachmentStatus","Waiting for submerged terrain")
   return
  end
  t.root=rootAt(position,hit.Position-up*.06)
  t.model:SetAttribute("CI_AttachmentStatus","Grounded on terrain")
  t.model:SetAttribute("CI_GroundOffsetStuds",(hit.Position-point):Dot(up))
  -- The holdfast illustrates the existing structural tissue, not added biomass.
  local rootWidth=math.clamp((t.nodes[1] and t.nodes[1][6] or .3) :: number,.2,.8)
  mesh(t,"Holdfast",CFrame.new(),Vector3.new(rootWidth,.65,rootWidth),tint)
  local frames={[0]=CFrame.new()};local form=row[46];local key=({"Ribbon","Fan","Filament","Sheet"})[form+1]
  -- The near view renders up to eight persistent sections. Omitted descendants
  -- remain in C++; the model explicitly advertises a structural LOD.
  local n=math.min(8,#t.nodes)
  for i=1,n do local node=t.nodes[i];local base=frames[node[2]] or CFrame.new();local yaw=(form==1 and 0 or node[1]*2.399963)
   local orientation=base*CFrame.Angles(0,yaw,node[7]);local length=node[5] :: number;local width=node[6] :: number
   -- Bound presentation to the water surface without changing biological tissue.
   length=math.min(length,math.max(.05,107.9-q.z-base.Position.Y))
   mesh(t,key,orientation,Vector3.new(width,length,form==3 and length or math.max(.05,width)),tint)
   frames[node[1]]=orientation*CFrame.new(0,form==3 and .08 or length*.65,form==3 and length*.6 or 0)
  end
  t.model:SetAttribute("CI_VisibleSegments",n);t.model:SetAttribute("CI_TotalSegments",#t.nodes)
 else
  local growth=math.clamp((row[8]/row[26])^(1/3),.5,1.3)
  local width=math.clamp(row[42] :: number,.7,1.4);local size=Vector3.new(.42*growth*width,.42*growth,.42*growth/width)
  local bodyFrame=CFrame.Angles(0,t.heading or 0,0)
  mesh(t,row[2]==3 and "BacterialGrazer" or "MicroalgalGrazer",bodyFrame,size,tint)
  -- Short cilia: no trailing flagella. Oscillation illustrates paid travel/intake.
  local active=math.clamp((t.to-t.from).Magnitude+(row[48]-(t.previousIntake or row[48])),0,1)
  if alpha>=1 then active=0 end
  local key=if row[2]==3 then "BacterialGrazer" else "MicroalgalGrazer"
  for i,anchor in anchors[key] do
   local base,direction=anchor[1],anchor[2]
   local tip=base+direction*.20-Vector3.new(0,.22+.06*math.sin(now*5+i)*active,0)
   local tangent=Vector3.new(-direction.Z,0,direction.X)*.025
   local function point(v)return bodyFrame:PointToWorldSpace(Vector3.new(v.X*size.X,v.Y*size.Y,v.Z*size.Z))end
   triangle(t,point(base-tangent),point(base+tangent),point(tip),Color3.fromRGB(187,196,151),t.root)
  end
 end
 for i=#t.parts,t.used+1,-1 do t.parts[i]:Destroy();t.parts[i]=nil end
 t.model:SetAttribute("CI_DisplayX",position.X);t.model:SetAttribute("CI_DisplayY",position.Y);t.model:SetAttribute("CI_DisplayZ",position.Z)
end
function M.sync(packet,parent,stamp,now)
 M.displayStatus={};M.displayRun=packet.run
 local shapes={};for _,r in packet.algae or {}do shapes[r[2]]=r[3]end
 local rows={};for _,r in packet.colonies do if r[2]>=3 then table.insert(rows,r)end end
 -- Reserve one observed parent/daughter pair per visible guild/form. Otherwise
 -- persistent display slots could hide every newborn behind older samples.
 local families={};local available={};for _,r in rows do available[r[3]]=true end
 local function group(r)return if r[2]==5 then 5+r[46]else r[2]end
 for _,r in rows do if r[4]>0 and r[7]<=200 and tracks[r[4]]and available[r[4]]then local k=group(r);if not families[k]or r[4]<families[k][1]then families[k]={r[4],r[3]}end end end
 local function priority(r)local f=families[group(r)];if f then if r[3]==f[1]then return 0 elseif r[3]==f[2]then return 1 end end;return if tracks[r[3]]then 2 else 3 end
 table.sort(rows,function(a,b)local ap,bp=priority(a),priority(b);if ap~=bp then return ap<bp end;return a[3]<b[3]end)
 local wanted={};local guilds={[3]=0,[4]=0};local forms={};local budget=0
 for _,r in rows do
  local algae=r[2]==5;local nodes=shapes[r[3]] or {};local cost=algae and (math.min(8,#nodes)*(r[46]==2 and 32 or 24)+#Data.Holdfast.faces*2) or (#Data[r[2]==3 and "BacterialGrazer" or "MicroalgalGrazer"].faces*2+24)
  local eligible=if algae then (forms[r[46]]or 0)<2 else guilds[r[2]]<M.MaximumGrazersPerGuild
  M.displayStatus[r[3]]="budget omitted"
  if eligible and budget+cost<=M.MaximumParts then
   M.displayStatus[r[3]]="awaiting render"
   budget+=cost;if algae then forms[r[46]]=(forms[r[46]]or 0)+1 else guilds[r[2]]+=1 end;wanted[r[3]]=true
   local t=tracks[r[3]]
   if not t then local model=Instance.new("Model");model.Name="Stage3_"..r[3];model.Parent=parent;t={model=model,parts={},row=r,nodes=nodes,from=Vector3.new(r[23],r[24],r[25]),to=Vector3.new(r[23],r[24],r[25]),start=now,duration=1};t.display=t.to;tracks[r[3]]=t;Collection:AddTag(model,"CI_Organism")end
   if t.revision~=packet.revision then
    t.from=t.display;t.to=Vector3.new(r[23],r[24],r[25]);t.start=now;t.duration=if t.revision then math.clamp((packet.revision-t.revision)/20,.05,2)else 1
    local travel=t.to-t.from;if travel.Magnitude>.0001 then t.heading=math.atan2(travel.X,travel.Y)end
    t.previousIntake=t.row[48];t.row=r;t.nodes=nodes;t.revision=packet.revision
   end
   local m=t.model;m:SetAttribute("CI_OrganismId","aq-"..r[3]);m:SetAttribute("CI_ColonyIdentity",packet.run..":"..r[3]);m:SetAttribute("CI_BiologyKind","Colony");m:SetAttribute("CI_NeuralController",false)
   m:SetAttribute("CI_Species",if algae then ({"Ribbon algae","Fan algae","Filament algae","Sheet algae"})[r[46]+1]elseif r[2]==3 then "Bacterial grazer"else "Microalgal grazer")
   for i,key in {"CI_ColonyId","CI_ParentId","CI_GenomeId","CI_Generation","CI_AgeTicks","CI_StructuralCarbon","CI_ReserveCarbon","CI_ReserveNitrogen","CI_ReservePhosphorus","CI_DNA","CI_RNA","CI_Protein","CI_Replication","CI_Assimilation","CI_Respiration","CI_Biomass","CI_OrganicN","CI_OrganicP","CI_Ploidy"}do m:SetAttribute(key,r[i+2])end
   m:SetAttribute("CI_DistanceStuds",r[28]);m:SetAttribute("CI_MovementCarbon",r[29]);m:SetAttribute("CI_SensingActivity",r[30]);m:SetAttribute("CI_MotorActivity",r[31]);m:SetAttribute("CI_SensingAllele",r[38]);m:SetAttribute("CI_MotilityAllele",r[39]);
   m:SetAttribute("CI_BiologyTimestamp",stamp);m:SetAttribute("CI_Run",packet.run);m:SetAttribute("CI_SimulationTick",packet.revision);m:SetAttribute("CI_PatchId",r[1]);m:SetAttribute("CI_RepresentedCohort",r[47]);m:SetAttribute("CI_IngestedCarbon",r[48]);m:SetAttribute("CI_EgestedCarbon",r[49]);m:SetAttribute("CI_AccessibleFoodCarbon",r[50])
   m:SetAttribute("CI_Behavior",if algae then "Attached growth"else ({"Resting","Exploring","Light response","Food response","Oxygen response","Passive mixing","Attached"})[r[27]+1]);m:SetAttribute("CI_Lifecycle",if r[4]>0 and r[7]<200 then "New offspring"elseif r[7]<200 then "Young founder"else "Growing colony")
   m:SetAttribute("Representation",if algae then "Paid C++ segments; bounded structural LOD"else "Magnified microbial cohort; C++ feeding; cosmetic cilia")
   if not algae or t.paintedRevision~=packet.revision then pose(t,now);t.paintedRevision=packet.revision end
  end
 end
 local gone={};for id in tracks do if not wanted[id]then table.insert(gone,id)end end;for _,id in gone do clearTrack(id)end
 parent:SetAttribute("Stage3Parts",budget);parent:SetAttribute("Stage3Visible",guilds[3]+guilds[4]+(forms[0]or 0)+(forms[1]or 0)+(forms[2]or 0)+(forms[3]or 0))
end
function M.animate(now)for _,t in tracks do if t.row[2]~=5 then pose(t,now)end end end
return M
