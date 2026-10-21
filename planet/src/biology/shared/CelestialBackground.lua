--!nonstrict
-- Cached, seeded spherical background. Analytic angular splats cross cube edges.
local B={Seed=271828,StarCount=800}
function B.catalog()
 local state=B.Seed
 local function random()state=(state*48271)%2147483647;return state/2147483647 end
 local stars={}
 for _=1,B.StarCount do
  local y=2*random()-1;local a=2*math.pi*random();local r=math.sqrt(1-y*y)
  local brightness=.06+.6*random()^5;local warmth=random()
  table.insert(stars,{direction=Vector3.new(r*math.cos(a),y,r*math.sin(a)),brightness=brightness,
   color=Color3.new(.8+.2*warmth,.85+.12*warmth,1-.2*warmth)})
 end
 return stars
end
function B.project(face:number,d:Vector3):(number?,number?)
 local scale,u,v
 if face==1 then scale=-d.X;u=-d.Z;v=-d.Y
 elseif face==2 then scale=d.X;u=d.Z;v=-d.Y
 elseif face==3 then scale=d.Y;u=-d.Z;v=-d.X
 elseif face==4 then scale=-d.Y;u=-d.Z;v=d.X
 elseif face==5 then scale=d.Z;u=-d.X;v=-d.Y
 else scale=-d.Z;u=d.X;v=-d.Y end
 if scale<=0 then return nil,nil end
 return u/scale,v/scale
end
function B.build(size,direction,yieldFrame)
 local result={};local stars=B.catalog();local axis=Vector3.new(.3,.7,-.64).Unit
 for face=1,6 do
  local pixels={};result[face]=pixels
  for y=0,size-1 do for x=0,size-1 do
   local d=direction(face,x*2/(size-1)-1,y*2/(size-1)-1)
   local plane=math.exp(-(d:Dot(axis)/.13)^2)
   local dust=.6+.4*math.noise(d.X*9+13,d.Y*9,d.Z*9)
   local glow=.035*plane*dust
   pixels[y*size+x+1]={r=glow*.8,g=glow*.85,b=glow,direction=d}
  end end
  if yieldFrame then yieldFrame()end
  for _,star in stars do
   local u,v=B.project(face,star.direction)
   if u~=nil and v~=nil and math.abs(u)<1.2 and math.abs(v)<1.2 then
    local px=(u+1)*(size-1)/2;local py=(v+1)*(size-1)/2
    local extent=math.ceil(size*.07)
    for y=math.max(0,math.floor(py)-extent),math.min(size-1,math.ceil(py)+extent)do
     for x=math.max(0,math.floor(px)-extent),math.min(size-1,math.ceil(px)+extent)do
      local p=pixels[y*size+x+1]
      local dot=p.direction:Dot(star.direction)
      if dot>math.cos(.035)then
       local weight=math.exp(-(1-dot)/.00005)*star.brightness
       p.r+=weight*star.color.R;p.g+=weight*star.color.G;p.b+=weight*star.color.B
      end
     end
    end
   end
  end
 end
 return result
end
return B
