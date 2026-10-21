--!strict

local SimulationSpace = {}

export type SimulationPosition = {
	x: number,
	y: number,
	z: number,
}

export type SimulationBounds = {
	width: number,
	length: number,
	depth: number,
}

SimulationSpace.Bounds = {
	width = 100,
	length = 100,
	depth = 60,
} :: SimulationBounds

function SimulationSpace.configure(bounds: {number})
 assert(#bounds == 3 and bounds[1]>0 and bounds[2]>0 and bounds[3]>0,"Invalid simulation bounds")
 SimulationSpace.Bounds.width,SimulationSpace.Bounds.length,SimulationSpace.Bounds.depth=bounds[1],bounds[2],bounds[3]
end

function SimulationSpace.toRoblox(position: SimulationPosition): Vector3
	return Vector3.new(
		position.x - (SimulationSpace.Bounds.width * 0.5),
		position.z - SimulationSpace.Bounds.depth,
		position.y - (SimulationSpace.Bounds.length * 0.5)
	)
end

function SimulationSpace.toRobloxXYZ(x: number, y: number, z: number): Vector3
	return SimulationSpace.toRoblox({
		x = x,
		y = y,
		z = z,
	})
end

function SimulationSpace.isWithinBounds(position: SimulationPosition): boolean
	return position.x >= 0
		and position.x <= SimulationSpace.Bounds.width
		and position.y >= 0
		and position.y <= SimulationSpace.Bounds.length
		and position.z >= 0
		and position.z <= SimulationSpace.Bounds.depth
end

function SimulationSpace.toSimulation(robloxPosition: Vector3): SimulationPosition
	return {
		x = robloxPosition.X + (SimulationSpace.Bounds.width * 0.5),
		y = robloxPosition.Z + (SimulationSpace.Bounds.length * 0.5),
		z = robloxPosition.Y + SimulationSpace.Bounds.depth,
	}
end

function SimulationSpace.getHeadingVector(simHeading: number): Vector3
	-- simHeading is a yaw angle in radians (0 = +X direction)
	return Vector3.new(math.cos(simHeading), 0, math.sin(simHeading))
end

function SimulationSpace.getDepthFraction(robloxY: number): number
	-- Returns 0.0 (surface) to 1.0 (seabed)
	return math.clamp(
		(0 - robloxY) / SimulationSpace.Bounds.depth,
		0,
		1
	)
end

function SimulationSpace.getWorldCenter(): Vector3
	return Vector3.new(0, -SimulationSpace.Bounds.depth * 0.5, 0)
end

return SimulationSpace
