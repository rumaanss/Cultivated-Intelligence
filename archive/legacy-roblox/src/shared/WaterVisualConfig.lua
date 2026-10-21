--!strict
-- All settings are visual. Restart Play after changing geometry or texture IDs.
return table.freeze({
	Quality = "High", -- Low=16, Medium=24, High=32, Ultra=48 cells per side.
	EnableEditableMesh = true,
	WaveAmplitudeScale = 1,
	WaveSpeedScale = 1,
	NearUpdateHz = 30,
	FarUpdateHz = 15,
	FarDistanceStuds = 140,
	CullDistanceStuds = 420,
	AdaptiveUpdateRate = true, -- Reduces update frequency, never rebuilds the mesh.
	NormalMap = "rbxassetid://110685993506013", -- Upload assets/water-ripple-normal.png; paste rbxassetid://ID.
	RoughnessMap = "rbxassetid://87860725710758", -- Optional authored roughness asset; no invented asset IDs.
	TextureTileStuds = 18,
	UVScrollStudsPerSecond = 0.16,
	UVUpdateHz = 10,
	SurfaceTransparency = 0.32,
	SurfaceReflectance = 0.12,
	SurfaceColor = Color3.fromRGB(30, 105, 130),
	TransitionSeconds = 0.32,
	BoundaryFadeStuds = 2,
	SurfaceBlendStuds = 0.8,
	AbsorptionRed = 0.013,
	AbsorptionGreen = 0.005,
	AbsorptionBlue = 0.0015,
	-- Art-directed depth knots in studs, continuously interpolated.
	DepthLayers = {
		{ Depth = 0, FogColor = Color3.fromRGB(51, 128, 146), Visibility = 145, Exposure = -0.04, Saturation = -0.02 },
		{ Depth = 12, FogColor = Color3.fromRGB(29, 95, 126), Visibility = 105, Exposure = -0.15, Saturation = -0.04 },
		{ Depth = 30, FogColor = Color3.fromRGB(15, 60, 99), Visibility = 70, Exposure = -0.35, Saturation = -0.07 },
		{ Depth = 60, FogColor = Color3.fromRGB(7, 30, 66), Visibility = 42, Exposure = -0.65, Saturation = -0.10 },
	},
	CausticTexture = "", -- Upload assets/water-caustics.png; paste rbxassetid://ID.
	CausticEnabled = true,
	CausticMaxReceivers = 24,
	CausticTileStuds = 14,
	CausticOpacity = 0.18,
	CausticExtinctionPerStud = 0.045,
	CausticUpdateHz = 15,
})
