local checked=0
for _,lat in ipairs({-80,-23.133702947184133,0,65})do for _,lon in ipairs({-179,-98.52227260602828,0,160})do
 local a,b=math.rad(lat),math.rad(lon)
 local up=Vector3.new(math.cos(a)*math.cos(b),math.sin(a),-math.cos(a)*math.sin(b))
 local north=Vector3.new(-math.sin(a)*math.cos(b),math.cos(a),math.sin(a)*math.sin(b))
 local f={center=Vector3.new(30,-50,60),radius=4096,up=up,north=north,east=north:Cross(up)}
 for x=-250,250,25 do for y=-150,150,25 do for _,z in ipairs({-104,-50,0,20})do
  local p=Vector3.new(x,y,z);local world=Frame.toWorld(f,p);local back=Frame.fromWorld(f,world)
  assert(back and (back-p).Magnitude<1e-8,"Radial chart round trip failed")
  assert(math.abs((world-f.center).Magnitude-(4096+z))<1e-8,"Wrong radial depth")
  checked+=1
 end end end
 assert(Frame.fromWorld(f,f.center-up*4096)==nil,"Antipode must not map into the lake")
 assert(not pcall(Frame.toWorld,f,Vector3.new(2000,0,0)),"Outside chart must be rejected")
end end
print('PASS habitat radial frame: '..checked..' round trips, depths and antipodal rejection')
