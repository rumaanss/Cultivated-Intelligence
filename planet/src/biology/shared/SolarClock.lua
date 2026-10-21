--!strict
-- Invert the engine's solar-height sinusoid in a region's radial frame.
local M={}
function M.fit(h0:number,h6:number,h12:number,h18:number)
 local a,b,c=(h0-h12)*.5,(h6-h18)*.5,(h0+h12)*.5
 local amplitude=math.sqrt(a*a+b*b)
 return {offset=c,amplitude=amplitude,peak=math.atan2(b,a),minimum=c-amplitude,maximum=c+amplitude}
end
function M.hour(f:any,phase:number,orientation:number):number
 local h=math.sin(phase*2*math.pi)
 -- Daylight follows the biological model. Night uses the reachable engine arc.
 local target=if h>=0 then h*math.min(1,f.maximum) else -h*math.min(0,f.minimum)
 local angle=math.acos(math.clamp((target-f.offset)/f.amplitude,-1,1))
 local side=if math.cos(phase*2*math.pi)>=0 then -1 else 1
 return ((f.peak+side*orientation*angle)*12/math.pi)%24
end
return M
