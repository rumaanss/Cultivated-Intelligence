--!strict

local GeologyBuilder = {}
local random = Random.new(7129)

local function createPart(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = string.sub(name, 1, 13) == "RockyOutcrop_" and size.Y >= 2
	part.Reflectance = if string.sub(name, 1, 13) == "RockyOutcrop_" then 0.035 else 0
	if string.sub(name, 1, 13) == "RockyOutcrop_" or string.sub(name, 1, 9) == "SandDune_" then
		part.Shape = Enum.PartType.Ball
	end
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function GeologyBuilder.buildSedimentLayers(
	folder: Folder,
	basinWidth: number,
	basinLength: number,
	floorY: number,
	layerCount: number,
	layerThickness: number,
	colorGradient: { Color3 }
): nil
	debug.profilebegin("CambrianBasin:BuildSedimentLayers")
	
	for i = 1, layerCount do
		local layerIndex = math.clamp(i, 1, #colorGradient)
		local layerColor = colorGradient[layerIndex]
		local layerY = floorY - (i * layerThickness)
		
		createPart(
			folder,
			"SedimentLayer_" .. i,
			Vector3.new(basinWidth, layerThickness, basinLength),
			Vector3.new(0, layerY - (layerThickness / 2), 0),
			layerColor,
			Enum.Material.Concrete
		)
	end
	
	debug.profileend()
	return nil
end

function GeologyBuilder.buildRockyOutcrops(
	folder: Folder,
	basinWidth: number,
	basinLength: number,
	floorY: number,
	outcropCount: number,
	sizeRange: { min: number, max: number },
	color: Color3
): nil
	debug.profilebegin("CambrianBasin:BuildRockyOutcrops")
	
	assert(sizeRange.min > 0 and sizeRange.max >= sizeRange.min, "Invalid rock size range")
	local minSize = sizeRange.min
	local maxSize = sizeRange.max
	local halfWidth = basinWidth / 2
	local halfLength = basinLength / 2
	
	for i = 1, outcropCount do
		local size = minSize + random:NextNumber() * (maxSize - minSize)
		local x = (random:NextNumber() - 0.5) * math.max(0, basinWidth - 16)
		local z = (random:NextNumber() - 0.5) * math.max(0, basinLength - 16)
		
		createPart(
			folder,
			"RockyOutcrop_" .. i,
			Vector3.new(size * 1.15, size * 0.85, size * 0.9),
			Vector3.new(x, floorY + size * 0.30, z),
			color,
			Enum.Material.Rock
		)
	end
	
	debug.profileend()
	return nil
end

function GeologyBuilder.buildSandDunes(
	folder: Folder,
	basinWidth: number,
	basinLength: number,
	floorY: number,
	duneCount: number,
	duneHeight: number,
	color: Color3
): nil
	debug.profilebegin("CambrianBasin:BuildSandDunes")
	
	local halfWidth = basinWidth / 2
	local halfLength = basinLength / 2
	
	for i = 1, duneCount do
		local x = (random:NextNumber() - 0.5) * math.max(0, basinWidth - 16)
		local z = (random:NextNumber() - 0.5) * math.max(0, basinLength - 16)
		local height = duneHeight * (0.7 + random:NextNumber() * 0.3)
		
		createPart(
			folder,
			"SandDune_" .. i,
			Vector3.new(4, height, 4),
			Vector3.new(x, floorY + height * 0.35, z),
			color,
			Enum.Material.Sand
		)
	end
	
	debug.profileend()
	return nil
end

function GeologyBuilder.buildThermalVents(
	folder: Folder,
	basinWidth: number,
	basinLength: number,
	floorY: number,
	ventCount: number,
	color: Color3
): nil
	debug.profilebegin("CambrianBasin:BuildThermalVents")
	
	for i = 1, ventCount do
		local x = (random:NextNumber() - 0.5) * math.max(0, basinWidth - 16)
		local z = (random:NextNumber() - 0.5) * math.max(0, basinLength - 16)
		
		createPart(
			folder,
			"ThermalVent_" .. i,
			Vector3.new(1, 3, 1),
			Vector3.new(x, floorY + 1.2, z),
			color,
			Enum.Material.Neon
		)
	end
	
	debug.profileend()
	return nil
end

return GeologyBuilder
