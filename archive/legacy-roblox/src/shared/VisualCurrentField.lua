--!strict
-- Analytic horizontal streamfunction: closed-basin circulation, zero normal
-- velocity at walls, depth shear and a slowly varying secondary eddy.
-- Deliberately independent of Vector3/Instances for numerical testing.
local M = {}
function M.sample(x: number, y: number, z: number, t: number,
	width: number, length: number, depth: number, speed: number): (number, number, number)
	if width <= 0 or length <= 0 or depth <= 0 then return 0, 0, 0 end
	local u, v = 2*x/width, 2*z/length
	if math.abs(u) >= 1 or math.abs(v) >= 1 or y > 0 or y < -depth then return 0, 0, 0 end
	local a, b = 1-u*u, 1-v*v
	local k = 0.28*math.sin(t*0.035)
	local f = a*a*(1+k*u)
	local df = -4*u*a*(1+k*u)+a*a*k
	local g, dg = b*b, -4*v*b
	local shear = 0.35+0.65*math.exp(2*math.clamp(y/depth,-1,0))
	local scale = speed*math.min(width,length)*0.15*shear
	return scale*f*dg*2/length, 0, -scale*df*g*2/width
end

function M.advance(x: number, y: number, z: number, dt: number, endTime: number,
	width: number, length: number, depth: number, speed: number, settling: number): (number,number,number)
	if dt <= 0 or dt ~= dt or dt == math.huge then return x,y,z end
	local duration = math.min(dt,0.2)
	local steps = math.max(1,math.ceil(duration/0.05))
	local h = duration/steps
	for step = 1,steps do
		local t = endTime-duration+(step-1)*h
		local vx, _, vz = M.sample(x,y,z,t,width,length,depth,speed)
		local mx, _, mz = M.sample(x+vx*h/2,y,z+vz*h/2,t+h/2,width,length,depth,speed)
		x = math.clamp(x+mx*h,-width/2+0.01,width/2-0.01)
		z = math.clamp(z+mz*h,-length/2+0.01,length/2-0.01)
		y -= settling*h
		if y < -depth+0.3 then y = -0.5 end
	end
	return x,y,z
end

function M.lightAtDepth(depth: number, surfaceLight: number, extinction: number): number
	return math.clamp(surfaceLight,0,1)*math.exp(-math.max(0,extinction)*math.max(0,depth))
end
return M
