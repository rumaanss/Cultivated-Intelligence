--!strict

local PlanetConfig = {
	-- Roblox world placement.
	GlobeCenter = Vector3.new(0, 0, 0),
	GlobeRadiusStuds = 750,

	-- The original deterministic C++ world.
	SimulationWorldWidth = 100,
	SimulationWorldLength = 100,
	SimulationWorldDepth = 60,

	-- C++ depth standard. Do not change these values.
	SurfaceZ = 60,
	DeepZ = 0,

	-- How deep the visual research basin extends below the globe surface.
	-- This does not alter C++ biology or simulation depth.
	VisualBasinDepthStuds = 90,

	-- Temporary visual basin placement.
	-- Replace these only after you provide the 510 Ma map and chosen basin.
	BasinCenterLatitudeDegrees = 0,
	BasinCenterLongitudeDegrees = 0,
	BasinAngularWidthDegrees = 14,
	BasinAngularHeightDegrees = 10,

	-- Workspace object names.
	GlobeModelName = "CambrianGlobe",
	ResearchBasinModelName = "ResearchBasin",
	DepthLayersFolderName = "DepthLayers",
	DevelopmentMarkersFolderName = "DevelopmentMarkers",
	DebugFolderName = "Debug",
	RenderRootsFolderName = "RenderRoots",
}

return table.freeze(PlanetConfig)
