--!strict

local DevelopmentConfig = {
	-- The spherical globe prototype is intentionally disabled.
	-- The active Phase 2 world is CartesianResearchBasin.
	EnableGlobeProxy = false,

	-- Disable temporary planet/basin debug geometry.
	EnableResearchBasinBounds = false,
	EnableDevelopmentMarkers = false,
	EnableDepthMarkers = false,

	-- Retained for future debug-mode reactivation.
	GlobeProxyTransparency = 0.72,
	GlobeProxyColor = Color3.fromRGB(21, 69, 86),

	BasinOutlineThicknessStuds = 2,
	BasinOutlineTransparency = 0.1,
	BasinOutlineColor = Color3.fromRGB(255, 213, 74),

	SurfaceMarkerColor = Color3.fromRGB(74, 211, 255),
	DeepMarkerColor = Color3.fromRGB(18, 45, 115),
	HorizontalMarkerColor = Color3.fromRGB(255, 213, 74),

	MarkerSizeStuds = 12,
	DepthMarkerSizeStuds = 16,
}

return table.freeze(DevelopmentConfig)
