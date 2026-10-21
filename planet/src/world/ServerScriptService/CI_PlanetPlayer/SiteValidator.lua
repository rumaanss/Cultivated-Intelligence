--!nonstrict
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("CI_PlanetPlayer",10).Shared
local C=require(Shared.Config); local F=require(Shared.PlanetFrame)
local S={}
local terrain=RaycastParams.new(); terrain.FilterType=Enum.RaycastFilterType.Include
terrain.FilterDescendantsInstances={workspace.Terrain}; terrain.IgnoreWater=false
function S.check(up,foot,exclude)
 local hit=workspace:Raycast(C.Center+up*(C.SeaRadius+600),-up*900,terrain)
 if not hit then return nil,"missing-terrain" end
 if hit.Material==Enum.Material.Water then return nil,"water" end
 if (hit.Position-C.Center).Magnitude<C.SeaRadius+C.SpawnWaterSetback then return nil,"below-water-setback" end
 if hit.Normal:Dot(up)<math.cos(math.rad(C.SpawnSlope)) then return nil,"slope" end
 local forward=F.tangent(Vector3.yAxis,up);local right=forward:Cross(up)
 local query=RaycastParams.new();query.FilterType=Enum.RaycastFilterType.Exclude
 query.FilterDescendantsInstances=if exclude then {exclude} else {};query.RespectCanCollide=true
 -- Center + eight perimeter samples: reject edges, local cliffs and missing support.
 for i=0,7 do
  local a=i*math.pi/4;local offset=(right*math.cos(a)+forward*math.sin(a))*1.5
  local sample=workspace:Raycast(hit.Position+offset+up*3,-up*6,terrain)
  if not sample or sample.Material==Enum.Material.Water or sample.Normal:Dot(up)<math.cos(math.rad(C.SpawnSlope))
   or math.abs((sample.Position-hit.Position):Dot(up))>0.8 then return nil,"footprint" end
 end
 -- Cast a box from just above the floor through the complete standing envelope.
 -- Blockcast detects Terrain; GetPartBoundsInBox alone would not detect Terrain.
 local cf=CFrame.lookAt(hit.Position+up*0.95,hit.Position+up*0.95+forward,up)
 local obstruction=workspace:Blockcast(cf,Vector3.new(4.4,0.4,2.4),up*(foot+3),query)
 if obstruction then return nil,"head-body-clearance" end
 local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Exclude
 overlap.FilterDescendantsInstances=if exclude then {exclude} else {};overlap.RespectCanCollide=true
 local box=CFrame.lookAt(hit.Position+up*(foot+0.15),hit.Position+up*(foot+0.15)+forward,up)
 for _,part in workspace:GetPartBoundsInBox(box,Vector3.new(4.4,foot*2,2.4),overlap) do
  if part~=workspace.Terrain then return nil,"occupied" end
 end
 return {position=hit.Position,up=up,forward=forward,root=hit.Position+up*(foot+0.12)},nil
end
-- Find the actual first dry bank while moving outward from the known deep lake.
-- A fixed +220 north offset selected distant ground; it never measured the bank.
function S.select(foot,exclude,reservations)
 local lake,north,east=F.fromLatLon(C.LakeLatitude,C.LakeLongitude)
 local waterRadius=C.SeaRadius
 local function direction(n,e)return (lake*waterRadius+north*n+east*e).Unit end
 local function surface(up)
  return workspace:Raycast(C.Center+up*(waterRadius+600),-up*900,terrain)
 end
 local core=surface(lake)
 if not core then return nil,{tested=0,rejected={missingLakeCenter=1}} end
 local coreDepth=waterRadius-(core.Position-C.Center).Magnitude
 -- Filled water will mask the floor in the ordinary query; verify the solid bed independently.
 if core.Material==Enum.Material.Water then
  local dry=RaycastParams.new();dry.FilterType=Enum.RaycastFilterType.Include
  dry.FilterDescendantsInstances={workspace.Terrain};dry.IgnoreWater=true
  core=workspace:Raycast(C.Center+lake*(waterRadius+600),-lake*900,dry)
  if not core then return nil,{tested=0,rejected={missingLakeBed=1}}end
  coreDepth=waterRadius-(core.Position-C.Center).Magnitude
 end
 if coreDepth<90 then return nil,{tested=0,rejected={lakeIdentityDepthCheck=1},centerDepth=coreDepth}end
 local reasons={};local count=0
 -- East bank first: the baked source shows a low, comparatively level bank there.
 local bearings={90,270,180,0}
 for a=0,345,15 do if a%90~=0 then table.insert(bearings,a)end end
 for _,bearing in bearings do
  local angle=math.rad(bearing);local dn,de=math.cos(angle),math.sin(angle)
  local previous=0;local edge=nil;local missing=false
  for distance=8,320,8 do
   local hit=surface(direction(dn*distance,de*distance))
   if not hit then missing=true;break end
   if hit.Material~=Enum.Material.Water and (hit.Position-C.Center).Magnitude>=waterRadius then
    local lo,hi=previous,distance
    for _=1,4 do
     local mid=(lo+hi)*.5;local m=surface(direction(dn*mid,de*mid))
     if not m then missing=true;break end
     if m.Material~=Enum.Material.Water and (m.Position-C.Center).Magnitude>=waterRadius then hi=mid else lo=mid end
    end
    if not missing then edge=hi end
    break
   end
   previous=distance
  end
  if edge then
   for _,setback in {8,12,16,20,24,28}do
    local distance=edge+setback
    local up=direction(dn*distance,de*distance)
    local site,reason=S.check(up,foot,exclude);count+=1
    if site then
     local reserved=false
     for _,p in reservations do if (p-site.root).Magnitude<10 then reserved=true;break end end
     if reserved then reason="reserved"
     else
      -- Require a clear view of the nearby rim, rather than selecting land behind a ridge.
      local rimUp=direction(dn*edge,de*edge)
      local rim=surface(rimUp)
      local eye=site.root+up*1.5
      local target=rim and rim.Position+rimUp*2
      local visible=target and not workspace:Raycast(eye,target-eye,terrain)
      if visible then
       site.forward=F.tangent(C.Center+lake*waterRadius-site.position,up)
       site.name="reference-lake-bank";site.bankSetback=setback
       site.lakeDistance=distance;site.lakeBearing=bearing;site.lakeCenterDepth=coreDepth
       return site,{tested=count,rejected=reasons,site=site.name,bankSetback=setback,
        lakeDistance=distance,bearing=bearing,centerDepth=coreDepth}
      end
      reason="lake-rim-occluded"
     end
    end
    reasons[reason or "invalid"]=(reasons[reason or "invalid"]or 0)+1
   end
  else reasons[missing and "missing-bank-terrain"or "no-nearby-bank"]=(reasons[missing and "missing-bank-terrain"or "no-nearby-bank"]or 0)+1 end
 end
 return nil,{tested=count,rejected=reasons,centerDepth=coreDepth,maxBankSetback=28}
end
return S
