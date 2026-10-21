--!strict
-- Presentation only. Never writes authoritative simulation positions.
local M={}
export type Sample={time:number,position:Vector3}
export type Track={samples:{Sample},warp:number}
function M.new():Track return {samples={},warp=0} end
function M.push(track:Track,t:number,p:Vector3,warp:number?)
 local samples=track.samples
 local last=samples[#samples]
 local version=warp or 0
 if version~=track.warp or (last and (p-last.position).Magnitude>8) then table.clear(samples);last=nil;track.warp=version end
 if last and t<=last.time then return end
 table.insert(samples,{time=t,position=p})
 if #samples>8 then table.remove(samples,1) end
end
function M.delay(track:Track):number
 local samples=track.samples;local n=#samples
 if n<2 then return .12 end
 return math.clamp((samples[n].time-samples[1].time)/(n-1)*1.2,.10,.30)
end
function M.sample(track:Track,time:number):Vector3?
 local samples=track.samples;local n=#samples
 if n==0 then return nil end
 if time<=samples[1].time then return samples[1].position end
 for i=2,n do
  local b,a=samples[i],samples[i-1]
  if time<=b.time then return a.position:Lerp(b.position,math.clamp((time-a.time)/(b.time-a.time),0,1)) end
 end
 local last=samples[n]
 if n<2 then return last.position end
 local previous=samples[n-1];local interval=last.time-previous.time
 if interval<=0 or interval>.75 then return last.position end
 local velocity=(last.position-previous.position)/interval
 if velocity.Magnitude>30 then velocity=velocity.Unit*30 end
 return last.position+velocity*math.clamp(time-last.time,0,.10)
end
return M
