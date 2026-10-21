--!strict

export type OrganismId = number

export type OrganismSnapshot = {
	id: OrganismId,
	speciesId: number,
	position: Vector3,
	velocity: Vector3,
	heading: Vector3,
	energy: number,
	age: number,
	isAlive: boolean,
}

export type RenderTier = "Near" | "Medium" | "Far" | "Culled"

export type RenderHandle = {
	id: OrganismId,
	tier: RenderTier,
}

return {}
