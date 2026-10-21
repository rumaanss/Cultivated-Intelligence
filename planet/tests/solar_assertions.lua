for _,peak in {0,.5,1.7,3.9,5.8}do
 local function height(hour)return .12+.88*math.cos(hour*math.pi/12-peak)end
 local fit=Clock.fit(height(0),height(6),height(12),height(18))
 assert(math.abs(fit.maximum-1)<1e-12)
 for _,orientation in {-1,1}do for i=0,1200 do
  local phase=i/1200;local h=math.sin(phase*2*math.pi)
  local expected=if h>=0 then h else -h*fit.minimum
  local hour=Clock.hour(fit,phase,orientation)
  assert(hour>=0 and hour<24 and math.abs(height(hour)-expected)<1e-10,"Regional solar phase mismatch")
 end end
end
print("PASS regional solar clock inversion: 12010 phases; daylight matches biological phase")
