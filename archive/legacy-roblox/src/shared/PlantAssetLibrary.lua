--!strict
-- Reusable native geometry. Every visible piece belongs to a stable simulated organ.
local M={}
local palettes={
 {bark=Color3.fromRGB(112,78,52),leaf=Color3.fromRGB(76,139,64),tip=Color3.fromRGB(166,189,77),pod=Color3.fromRGB(190,93,54)},
 {bark=Color3.fromRGB(88,67,58),leaf=Color3.fromRGB(43,104,79),tip=Color3.fromRGB(106,161,103),pod=Color3.fromRGB(174,127,65)},
 {bark=Color3.fromRGB(130,102,76),leaf=Color3.fromRGB(81,143,133),tip=Color3.fromRGB(165,189,143),pod=Color3.fromRGB(209,132,89)},
}
local function position(p:any):Vector3 return Vector3.new(p[1],p[2],p[3]) end
local function span(a:Vector3,b:Vector3):CFrame
 local d=b-a;local up=if math.abs(d.Unit.Y)>.98 then Vector3.xAxis else Vector3.yAxis
 return CFrame.lookAt((a+b)*.5,b,up)
end
function M.geometry(p:any,lod:number,roots:boolean):{any}
 local pieces={};local base=position(p.position);local palette=palettes[p.species+1]
 local stress=1-math.clamp(p.resources[4],0,1)
 local leaf=palette.leaf:Lerp(palette.tip,p.hue*.35):Lerp(Color3.fromRGB(151,115,58),stress*.7)
 local function add(id:number,key:string,size:Vector3,cf:CFrame,color:Color3,shape:string,wind:number)
  table.insert(pieces,{id=id,key=tostring(id).."_"..key,size=size,cf=cf,color=color,shape=shape,wind=wind})
 end
 if p.stage==0 then
  add(0,"seed",Vector3.new(.18,.12,.25),CFrame.new(base+Vector3.new(0,.07,0)),palette.pod,"Ball",0);return pieces
 end

 for _,o in p.organs do
  local id,kind=o[1],o[3];local dead=o[13]==1
  if kind==0 and not roots then continue end
  if o[11]<=.00001 then continue end
  local a=base+Vector3.new(o[4],o[5],o[6]);local b=base+Vector3.new(o[7],o[8],o[9]);local distance=math.max((b-a).Magnitude,.01)
  local tint=if dead then Color3.fromRGB(112,103,85) else palette.bark
  if kind==0 or kind==1 then
   local radius=math.max(.035,o[10]);add(id,"wood",Vector3.new(radius*2,radius*2,distance),span(a,b),tint,"Block",0)
   if lod==2 then
    add(id,"joint",Vector3.new(radius*2.2,radius*2.2,radius*2.2),CFrame.new(a),tint,"Ball",0)
    -- Tapered top edge adds angular bark silhouette without a physics joint.
    add(id,"taper",Vector3.new(radius*1.4,radius*.7,distance*.94),span(a,b)*CFrame.new(0,radius*.8,0),tint:Lerp(Color3.new(1,1,1),.09),"Wedge",0)
   end
  elseif kind==2 then
   local size=math.max(.15,math.sqrt(o[11]*p.leafArea)*1.8)
   if lod<=1 then
    -- Crossed leaf blades preserve organ placement and species coloration.
    for k=1,2 do
     add(id,"blade"..k,Vector3.new(size*.55,.07,size),CFrame.new(b)*CFrame.Angles(-.25,id*2.399963+k*math.pi/2,0),if dead then tint else leaf,"Wedge",.025)
    end
   else
    add(id,"petiole",Vector3.new(.035,.035,distance),span(a,b),palette.bark,"Block",.02)
    for k=1,5 do
     local angle=id*2.399963+k*math.pi*2/5
     local cf=CFrame.new(b)*CFrame.Angles(0,angle,0)*CFrame.new(0,.03,size*.23)*CFrame.Angles(-.32,0,.09)
     local color=if dead then tint else leaf:Lerp(palette.tip,(k%3)*.13)
     add(id,"leaf"..k,Vector3.new(size*.38,.07,size*.78),cf,color,"Wedge",.07)
    end
   end
  elseif kind==3 then
   local size=math.max(.12,math.sqrt(o[11])*.22)
   add(id,"pod",Vector3.new(size,size*1.4,size),CFrame.new(b),palette.pod,"Ball",.02)
  end
 end
 return pieces
end
return M
