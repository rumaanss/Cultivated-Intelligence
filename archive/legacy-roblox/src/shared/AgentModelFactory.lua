--!strict
-- Native editable fallback rigs. Rich tapered mesh variants are supplied as glTF.
local M={}
export type Joint={name:string,parent:number,pivot:{number},axis:{number},amplitude:number,phase:number}
export type Piece={name:string,size:{number},cf:{number},color:{number},joint:number,shape:string,lod:number}
export type Design={key:string,title:string,kind:string,description:string,joints:{Joint},parts:{Piece},safeRadius:number,partCount:number,triangleCount:number}
export type State={part:BasePart,joint:number,bind:CFrame}
export type Rig={model:Model,design:Design,scale:number,states:{State},frames:{CFrame}}
-- Generated heterogeneous records share the exported Design schema.
local designData: any = require(script.Parent.AgentDesignData)
local designs: {Design} = designData
local index: {[string]:Design}={}
local bodyIds: {[string]:number}={}
for i,design in designs do index[design.key]=design;bodyIds[design.key]=i end
function M.designs(): {Design} return designs end
function M.get(key:string): Design
 local design=index[key];assert(design~=nil,"Unknown agent design: "..key);return design
end
function M.create(key:string,parent:Instance,radius:number?,detail:number?): Rig
 local design=M.get(key)
 local scale=if radius then radius/design.safeRadius else 1
 assert(scale>0 and scale<math.huge,"Invalid model scale")
 local model=Instance.new("Model");model.Name=key
 model:SetAttribute("BodySchemaVersion",1);model:SetAttribute("BodyDesignId",bodyIds[key])
 model:SetAttribute("DesignKey",key);model:SetAttribute("PresentationOnly",true)
 model:SetAttribute("BiologicalClaim",if design.kind=="Live" then "StylizedMarker" else "FutureBodyStudy")
 local states: {State}={}
 for _,piece in design.parts do
  if piece.lod>(detail or 2) then continue end
  local part:BasePart=if piece.shape=="Wedge" then Instance.new("WedgePart") else Instance.new("Part")
  part.Name=piece.name
  part:SetAttribute("BodyComponentId",piece.joint)
  part.Size=Vector3.new(piece.size[1],piece.size[2],piece.size[3])*scale
  part.Material=Enum.Material.SmoothPlastic
  part.Color=Color3.fromRGB(piece.color[1],piece.color[2],piece.color[3])
  part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
  local c=piece.cf
  local bind=CFrame.new(c[1]*scale,c[2]*scale,c[3]*scale,c[4],c[5],c[6],c[7],c[8],c[9],c[10],c[11],c[12])
  part.Parent=model;table.insert(states,{part=part,joint=piece.joint,bind=bind})
 end
 local rig:Rig={model=model,design=design,scale=scale,states=states,frames={}}
 model:SetAttribute("NativePartCount",#states)
 model.Parent=parent
 return rig
end
function M.pose(rig:Rig,root:CFrame,phase:number,strength:number)
 strength=math.clamp(strength,0,1)
 for i,joint in rig.design.joints do
  local p=joint.pivot
  local parent=if joint.parent>0 then rig.frames[joint.parent] else root
  local angle=joint.amplitude*math.sin(phase+joint.phase)*strength
  rig.frames[i]=parent*CFrame.new(p[1]*rig.scale,p[2]*rig.scale,p[3]*rig.scale)
   *CFrame.fromAxisAngle(Vector3.new(joint.axis[1],joint.axis[2],joint.axis[3]),angle)
 end
 for _,state in rig.states do state.part.CFrame=rig.frames[state.joint]*state.bind end
end
-- Apply authoritative component angles from a validated pose packet.
-- Caller owns run/tick ordering, interpolation, root transform and radius.
function M.poseAngles(rig:Rig,root:CFrame,angles:{number})
 assert(#angles==#rig.design.joints,"Expected complete body pose")
 for _,a in angles do assert(a==a and math.abs(a)<=math.pi,"Invalid joint angle") end
 for i,joint in rig.design.joints do
  local p=joint.pivot
  local parent=if joint.parent>0 then rig.frames[joint.parent] else root
  rig.frames[i]=parent*CFrame.new(p[1]*rig.scale,p[2]*rig.scale,p[3]*rig.scale)
   *CFrame.fromAxisAngle(Vector3.new(joint.axis[1],joint.axis[2],joint.axis[3]),angles[i])
 end
 for _,state in rig.states do state.part.CFrame=rig.frames[state.joint]*state.bind end
end
function M.destroy(rig:Rig)
 rig.model:Destroy();table.clear(rig.states);table.clear(rig.frames)
end
return M
