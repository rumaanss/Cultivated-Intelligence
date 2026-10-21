--!strict
-- Pure numeric presentation model, independent of C++ and Roblox physics.
local M = {}
local TAU = 2 * math.pi
local waves = {
	{ x = 0.93969262, z = 0.34202014, amplitude = 0.42, length = 32, period = 6.8, phase = 0.2 },
	{ x = -0.42261826, z = 0.90630779, amplitude = 0.23, length = 18, period = 4.9, phase = 1.7 },
	{ x = 0.70710678, z = -0.70710678, amplitude = 0.10, length = 10, period = 3.3, phase = 3.1 },
}
function M.sample(x: number, z: number, seconds: number, amplitudeScale: number, speedScale: number): (number, number, number)
	local height, dx, dz = 0, 0, 0
	for _, wave in waves do
		local k = TAU / wave.length
		local phase = k * (wave.x * x + wave.z * z) - TAU / wave.period * seconds * speedScale + wave.phase
		local amplitude = wave.amplitude * amplitudeScale
		height += amplitude * math.sin(phase)
		local slope = amplitude * k * math.cos(phase)
		dx += slope * wave.x
		dz += slope * wave.z
	end
	return height, dx, dz
end
function M.smoothstep(value: number): number
	local t = math.clamp(value, 0, 1)
	return t * t * (3 - 2 * t)
end
function M.absorption(depth: number, red: number, green: number, blue: number): (number, number, number)
	local d = math.max(depth, 0)
	return math.exp(-red * d), math.exp(-green * d), math.exp(-blue * d)
end
return table.freeze(M)
