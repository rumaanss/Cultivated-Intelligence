--!strict

local SeabedDetailBuilder = {}
local random = Random.new(9137)

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
	part.CastShadow = false
	part.Shape = Enum.PartType.Ball
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function SeabedDetailBuilder.buildSeabedDetail(
	folder: Folder,
	basinWidth: number,
	basinLength: number,
	floorY: number,
	rippleCount: number,
	rippleHeight: number,
	colorVariance: number,
	baseColor: Color3
): nil
	debug.profilebegin("CambrianBasin:BuildSeabedDetail")
	
	local halfWidth = basinWidth / 2
	local halfLength = basinLength / 2
	
	for i = 1, rippleCount do
		local x = random:NextNumber() * (basinWidth - 4) - halfWidth + 2
		local z = random:NextNumber() * (basinLength - 1.2) - halfLength + 0.6
		local height = rippleHeight * (0.5 + random:NextNumber())
		
		local variance = (colorVariance / 255) * (random:NextNumber() - 0.5)
		local r = math.clamp(baseColor.R + variance, 0, 1)
		local g = math.clamp(baseColor.G + variance, 0, 1)
		local b = math.clamp(baseColor.B + variance, 0, 1)
		local rippleColor = Color3.new(r, g, b)
		
		createPart(
			folder,
			"SeabedRipple_" .. i,
			Vector3.new(4, height, 1.2),
			Vector3.new(x, floorY + height * 0.35, z),
			rippleColor,
			Enum.Material.Sand
		)
	end
	
	debug.profileend()
	return nil
end

return SeabedDetailBuilder

