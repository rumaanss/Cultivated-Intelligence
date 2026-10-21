--!strict

local Lighting = game:GetService("Lighting")

local ResearchEnvironmentService = {}

local initialized = false

local function getOrCreateEffect(
	className: string,
	name: string
): Instance
	local existing = Lighting:FindFirstChild(name)

	if existing ~= nil then
		assert(
			existing.ClassName == className,
			string.format("Lighting.%s must be a %s.", name, className)
		)

		return existing
	end

	local effect = Instance.new(className)
	effect.Name = name
	effect.Parent = Lighting

	return effect
end

function ResearchEnvironmentService.Initialize()
	if initialized then
		return
	end

	initialized = true

	debug.profilebegin("Environment:Configure")

	Lighting.Ambient = Color3.fromRGB(4, 6, 10)
	Lighting.OutdoorAmbient = Color3.fromRGB(9, 15, 23)
	Lighting.Brightness = 2.2
	Lighting.ClockTime = 13.5
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.25
	Lighting.GlobalShadows = true
	Lighting.Technology = Enum.Technology.Future

	local atmosphere = getOrCreateEffect(
		"Atmosphere",
		"CambrianAtmosphere"
	) :: any

	atmosphere.Density = 0.28
	atmosphere.Offset = 0.05
	atmosphere.Color = Color3.fromRGB(140, 184, 204)
	atmosphere.Decay = Color3.fromRGB(51, 87, 110)
	atmosphere.Glare = 0.05
	atmosphere.Haze = 1.1

	local colorCorrection = getOrCreateEffect(
		"ColorCorrectionEffect",
		"CambrianColorCorrection"
	) :: any

	colorCorrection.Brightness = -0.02
	colorCorrection.Contrast = 0.08
	colorCorrection.Saturation = -0.08
	colorCorrection.TintColor = Color3.fromRGB(209, 237, 255)

	local bloom = getOrCreateEffect(
		"BloomEffect",
		"CambrianBloom"
	) :: any

	bloom.Intensity = 0.15
	bloom.Size = 18
	bloom.Threshold = 1.4

	debug.profileend()

	print("[planetv000] ResearchEnvironmentService: initialized")
end

return ResearchEnvironmentService
