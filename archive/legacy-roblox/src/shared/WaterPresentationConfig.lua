--!strict
-- Construct a NEW table: no mutation of a cloned read-only configuration.
-- Texture IDs and user tuning are read from the existing WaterVisualConfig.
local original = require(script.Parent.WaterVisualConfig)
local config = {
	Quality = original.Quality,
	EnableEditableMesh = original.EnableEditableMesh,
	WaveAmplitudeScale = original.WaveAmplitudeScale,
	WaveSpeedScale = original.WaveSpeedScale,
	NearUpdateHz = original.NearUpdateHz,
	FarUpdateHz = original.FarUpdateHz,
	FarDistanceStuds = original.FarDistanceStuds,
	CullDistanceStuds = original.CullDistanceStuds,
	AdaptiveUpdateRate = original.AdaptiveUpdateRate,
	NormalMap = original.NormalMap,
	RoughnessMap = original.RoughnessMap,
	TextureTileStuds = original.TextureTileStuds,
	UVScrollStudsPerSecond = original.UVScrollStudsPerSecond,
	UVUpdateHz = original.UVUpdateHz,
	SurfaceTransparency = 0.48,
	SurfaceReflectance = 0.06,
	SurfaceColor = Color3.fromRGB(64, 132, 149),
	TransitionSeconds = 0.45,
	BoundaryFadeStuds = original.BoundaryFadeStuds,
	SurfaceBlendStuds = original.SurfaceBlendStuds,
	AbsorptionRed = original.AbsorptionRed,
	AbsorptionGreen = original.AbsorptionGreen,
	AbsorptionBlue = original.AbsorptionBlue,
	DepthLayers = original.DepthLayers,
	CausticTexture = original.CausticTexture,
	CausticEnabled = original.CausticEnabled,
	CausticMaxReceivers = original.CausticMaxReceivers,
	CausticTileStuds = original.CausticTileStuds,
	CausticOpacity = 0.16,
	CausticExtinctionPerStud = original.CausticExtinctionPerStud,
	CausticUpdateHz = original.CausticUpdateHz,

 VisualPaddingStuds = 0,
 ShoreWidthStuds = 8,
 EdgeWaveFadeStuds = 8,
 OuterCellsPerSide = 0,
 SurfaceRoughness = 0.23,
 ExposureAdaptSeconds = 0.8,
 LightingCycle = {
  night = { clockTime=0, brightness=0.18, exposureCompensation=-0.35,
   ambient=Color3.fromRGB(8,12,20), outdoorAmbient=Color3.fromRGB(18,24,36),
   fogColor=Color3.fromRGB(12,23,39), fogStart=35, fogEnd=420 },
  day = { clockTime=12, brightness=2.4, exposureCompensation=0,
   ambient=Color3.fromRGB(28,33,38), outdoorAmbient=Color3.fromRGB(65,76,87),
   fogColor=Color3.fromRGB(145,182,199), fogStart=60, fogEnd=600 },
 },
}
export type Config = typeof(config)
return table.freeze(config)
