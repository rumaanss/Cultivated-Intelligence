--!strict

local ParticleSystemBuilder = {}
local random = Random.new(2391)

local function createParticlePart(
	parent: Folder,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Shape = Enum.PartType.Ball
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function ParticleSystemBuilder.createSedimentParticles(
	folder: Folder,
	particleCount: number,
	spawnRadius: number,
	color: Color3,
	speed: number,
	size: number,
	floorY: number
): nil
	debug.profilebegin("CambrianBasin:CreateSedimentParticles")
	
	for i = 1, particleCount do
		local angle = random:NextNumber() * math.pi * 2
		local radius = math.sqrt(random:NextNumber()) * spawnRadius
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local y = floorY + 20 + random:NextNumber() * 10
		
		local velX = (random:NextNumber() - 0.5) * speed
		local velY = -speed * 0.1
		local velZ = (random:NextNumber() - 0.5) * speed
		
		local particle = createParticlePart(
			folder,
			"SedimentParticle_" .. i,
			Vector3.new(size, size, size),
			Vector3.new(x, y, z),
			color
		)
		
		particle:SetAttribute("Velocity_X", velX)
		particle:SetAttribute("Velocity_Y", velY)
		particle:SetAttribute("Velocity_Z", velZ)
	end
	
	debug.profileend()
	return nil
end

function ParticleSystemBuilder.createBioluminescentParticles(
	folder: Folder,
	particleCount: number,
	spawnRadius: number,
	colors: { Color3 },
	brightness: number,
	pulseSpeed: number,
	minDepth: number
): nil
	assert(#colors > 0, "Bioluminescence requires at least one color")
	debug.profilebegin("CambrianBasin:CreateBioluminescentParticles")
	
	for i = 1, particleCount do
		local angle = random:NextNumber() * math.pi * 2
		local radius = math.sqrt(random:NextNumber()) * spawnRadius
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local y = minDepth - random:NextNumber() * 10
		
		local colorIndex = ((i - 1) % #colors) + 1
		local particleColor = colors[colorIndex]
		
		local particle = createParticlePart(
			folder,
			"BioluminescentParticle_" .. i,
			Vector3.new(0.5, 0.5, 0.5),
			Vector3.new(x, y, z),
			particleColor
		)
		
		particle:SetAttribute("PulsePhase", random:NextNumber() * math.pi * 2)
		particle:SetAttribute("PulseSpeed", pulseSpeed)
		particle:SetAttribute("Brightness", brightness)
	end
	
	debug.profileend()
	return nil
end

function ParticleSystemBuilder.createPhotonicBoundaryMarker(
	folder: Folder,
	basinWidth: number,
	basinLength: number,
	phototicY: number
): nil
	debug.profilebegin("CambrianBasin:CreatePhotonicBoundaryMarker")
	
	local marker = Instance.new("Part")
	marker.Name = "PhotiticBoundary"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.Size = Vector3.new(basinWidth, 0.1, basinLength)
	marker.CFrame = CFrame.new(0, phototicY, 0)
	marker.Color = Color3.fromRGB(255, 255, 0)
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.5
	marker.Parent = folder
	
	debug.profileend()
	return nil
end

return ParticleSystemBuilder

