-- Original designs must retain recognizable bodies at every shipped LOD.
for _,key in {"Cyanobacteria","Bacterivore","BodoSaltans"}do
 local d=Factory.get(key)
 assert(Factory.count(key,0)>=1 and Factory.count(key,0)<=4)
 assert(Factory.count(key,2)==d.partCount)
end
assert(Factory.count("BodoSaltans",0)>Factory.count("Cyanobacteria",0))
-- A non-zenith-reaching engine arc must still cross the correct day/night half.
for _,peak in {.3,.7,.97,1}do
 local fit=Clock.fit(0,peak,0,-peak)
 for i=0,599 do
  local phase=i/600
  local hour=Clock.hour(fit,phase,1)
  local height=fit.offset+fit.amplitude*math.cos(hour*math.pi/12-fit.peak)
  assert(math.abs(height-peak*math.sin(phase*2*math.pi))<.00001)
 end
end
print("PASS original species silhouettes and non-zenith solar cycles")
