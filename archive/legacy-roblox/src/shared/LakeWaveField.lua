--!strict
-- VISUAL PREVIEW ONLY. Coherent multi-scale lake waves, analytic derivatives.
-- Units: Roblox studs, seconds, radians. These are NOT a C++ fluid solution.
local M = {}
local TAU = math.pi*2
local components = {
	{dx=0.94,dz=0.342,a=0.24,length=30,period=7.5,phase=0.2},
	{dx=0.819,dz=0.574,a=0.105,length=16,period=4.8,phase=1.8},
	{dx=-0.342,dz=0.94,a=0.055,length=10,period=3.9,phase=3.1},
	{dx=0.97,dz=-0.243,a=0.024,length=6.4,period=2.7,phase=0.7},
}
-- Analytic quintic shore taper: zero height and zero slope at the basin edge.
local function envelope(position: number, extent: number): (number,number)
	local band = math.min(8,extent*0.2)
	local t = math.clamp((extent/2-math.abs(position))/band,0,1)
	local value = t*t*t*(t*(6*t-15)+10)
	local derivative = if t<=0 or t>=1 then 0 else -math.sign(position)*30*t*t*(t-1)*(t-1)/band
	return value,derivative
end
function M.sample(x: number,z: number,time: number,width: number,length: number,amplitude: number,speed: number): (number,number,number)
	local height, dx, dz = 0,0,0
	for _, wave in components do
		local k = TAU/wave.length
		local phase = k*(wave.dx*x+wave.dz*z)-TAU/wave.period*time*speed+wave.phase
		-- Very weak second harmonic sharpens crests without a repeating scale texture.
		local value = math.sin(phase)+0.08*math.sin(2*phase)
		local slope = math.cos(phase)+0.16*math.cos(2*phase)
		height += wave.a*amplitude*value
		dx += wave.a*amplitude*k*wave.dx*slope
		dz += wave.a*amplitude*k*wave.dz*slope
	end
	local ex, dex = envelope(x,width)
	local ez, dez = envelope(z,length)
	return height*ex*ez, dx*ex*ez+height*dex*ez, dz*ex*ez+height*ex*dez
end
return table.freeze(M)
