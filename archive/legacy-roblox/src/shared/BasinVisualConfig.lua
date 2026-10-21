--!strict

local BasinVisualConfig = {
	ROOT_NAME = "CartesianResearchBasin",

	SURFACE_Y = 0,
	FLOOR_Y = -60,

	WATER_SURFACE_THICKNESS = 0.2,
	FLOOR_THICKNESS = 2,
	WALL_THICKNESS = 0.5,

	SHOW_BOUNDARY_WALLS = false,  -- DISABLED: Cleaner visuals
	SHOW_DEPTH_LAYERS = false,

	-- Water surface
	-- Caustic fields are reserved; no caustic renderer is enabled in this package.
	WATER_SURFACE_COLOR = Color3.fromRGB(34, 130, 150),
	WATER_SURFACE_TRANSPARENCY = 0.38,
	WATER_CAUSTIC_ENABLED = false,
	WATER_CAUSTIC_SPEED = 0.3,
	WATER_CAUSTIC_SCALE = 8,

	-- Seabed base
	FLOOR_COLOR = Color3.fromRGB(47, 62, 57),
	FLOOR_MATERIAL = Enum.Material.Slate,

	-- Seabed geological features
	SEABED_DETAIL_ENABLED = true,
	SEABED_RIPPLE_COUNT = 75,  -- Increased for more detail
	SEABED_RIPPLE_HEIGHT = 0.6,  -- Slightly taller
	SEABED_RIPPLE_COLOR_VARIANCE = 15,  -- More color variation

	-- Geological zones (layered sediment, substrate variation)
	GEOLOGY_ENABLED = true,
	SEDIMENT_LAYERS_ENABLED = true,
	SEDIMENT_LAYER_COUNT = 5,  -- More layers for stratification
	SEDIMENT_LAYER_THICKNESS = 0.8,
	SEDIMENT_LAYER_COLOR_GRADIENT = {
		Color3.fromRGB(75, 95, 88),   -- Top layer (recent, lighter)
		Color3.fromRGB(65, 85, 78),   -- Layer 2
		Color3.fromRGB(52, 68, 62),   -- Middle layer (older)
		Color3.fromRGB(48, 62, 56),   -- Layer 4
		Color3.fromRGB(42, 55, 50),   -- Bottom layer (oldest, darkest)
	},

	-- Rocky outcrops for substrate diversity (clustered)
	ROCKY_OUTCROPS_ENABLED = true,
	ROCKY_OUTCROP_COUNT = 18,  -- Increased
	ROCKY_OUTCROP_SIZE_RANGE = { min = 1.5, max = 6 },  -- Better size range
	ROCKY_OUTCROP_COLOR = Color3.fromRGB(85, 100, 110),  -- Slightly lighter

	-- Decorative sand dunes; no simulated ecological effect
	SAND_DUNES_ENABLED = true,
	SAND_DUNE_COUNT = 35,  -- More dunes
	SAND_DUNE_COLOR = Color3.fromRGB(115, 125, 105),
	SAND_DUNE_HEIGHT = 1.8,  -- Taller dunes
	SAND_DUNE_WIDTH_VARIANCE = 1.5,  -- Varied widths

	-- Particle effects
	AMBIENT_PARTICLES_ENABLED = true,

	-- Ambient sediment particles; not measured nutrient cycling
	SEDIMENT_PARTICLE_ENABLED = true,
	SEDIMENT_PARTICLE_COUNT = 60,  -- More particles
	SEDIMENT_PARTICLE_SPAWN_RADIUS = 48,
	SEDIMENT_PARTICLE_COLOR = Color3.fromRGB(130, 120, 100),  -- Slightly lighter
	SEDIMENT_PARTICLE_SPEED = 0.8,  -- Slightly faster drift
	SEDIMENT_PARTICLE_SIZE = 0.15,  -- Slightly larger

	-- Ambient bioluminescence; not measured biomass
	BIOLUMINESCENCE_ENABLED = true,
	BIOLUMINESCENCE_PARTICLE_COUNT = 25,  -- More bioluminescence
	BIOLUMINESCENCE_PARTICLE_SPAWN_RADIUS = 48,
	BIOLUMINESCENCE_COLORS = {
		Color3.fromRGB(0, 255, 150),   -- Cyan
		Color3.fromRGB(100, 200, 255), -- Light blue
		Color3.fromRGB(0, 200, 100),   -- Green
	},
	BIOLUMINESCENCE_BRIGHTNESS = 2.5,  -- Slightly brighter
	BIOLUMINESCENCE_PULSE_SPEED = 1.8,  -- Faster pulse
	BIOLUMINESCENCE_MIN_DEPTH = -45,

	-- Thermal vent markers
	THERMAL_VENTS_ENABLED = true,
	THERMAL_VENT_COUNT = 3,
	THERMAL_VENT_COLOR = Color3.fromRGB(220, 120, 60),
	THERMAL_VENT_PARTICLE_COUNT = 20,

	-- Day/Night Cycle (24 minutes = 1 full cycle)
	CELESTIAL_CYCLE_ENABLED = true,
	CELESTIAL_CYCLE_DURATION = 1440,  -- Simulation ticks; preview advances at its configured rate

	-- Day/Night Lighting Presets
	LIGHTING_PRESETS = {
		-- Midnight (0:00)
		midnight = {
			clockTime = 0,
			brightness = 0.3,
			exposureCompensation = -0.5,
			ambient = Color3.fromRGB(20, 25, 40),
			outdoorAmbient = Color3.fromRGB(30, 35, 55),
			fogColor = Color3.fromRGB(10, 15, 35),
			fogStart = 40,
			fogEnd = 350,
		},
		-- Early Morning (6:00)
		dawn = {
			clockTime = 6,
			brightness = 1.2,
			exposureCompensation = -0.2,
			ambient = Color3.fromRGB(50, 65, 90),
			outdoorAmbient = Color3.fromRGB(100, 130, 170),
			fogColor = Color3.fromRGB(40, 85, 130),
			fogStart = 50,
			fogEnd = 400,
		},
		-- Noon (12:00)
		noon = {
			clockTime = 12,
			brightness = 2.8,
			exposureCompensation = 0.3,
			ambient = Color3.fromRGB(70, 100, 130),
			outdoorAmbient = Color3.fromRGB(150, 180, 220),
			fogColor = Color3.fromRGB(60, 120, 160),
			fogStart = 60,
			fogEnd = 500,
		},
		-- Late Afternoon (18:00)
		dusk = {
			clockTime = 18,
			brightness = 1.5,
			exposureCompensation = 0.1,
			ambient = Color3.fromRGB(80, 70, 50),
			outdoorAmbient = Color3.fromRGB(180, 140, 100),
			fogColor = Color3.fromRGB(120, 85, 50),
			fogStart = 50,
			fogEnd = 400,

		},
	},

	-- Atmosphere (underwater ambiance)
	ATMOSPHERE = {
		name = "CambrianAtmosphere",
		color = Color3.fromRGB(141, 211, 225),
		decay = Color3.fromRGB(74, 146, 161),
		density = 0.35,
		glare = 0.12,
		haze = 2.0,
		offset = 0,
	},
}

BasinVisualConfig.LIGHTING_CYCLE = {
		night = {
		clockTime = 0,
		brightness = 0.3,
		exposureCompensation = -0.5,
		ambient = Color3.fromRGB(20, 25, 40),
		outdoorAmbient = Color3.fromRGB(30, 35, 55),
		fogColor = Color3.fromRGB(10, 15, 35),
		fogStart = 40,
		fogEnd = 350,
	},
	day = {
		clockTime = 12,
		brightness = 2.8,
		exposureCompensation = 0.3,
		ambient = Color3.fromRGB(70, 100, 130),
		outdoorAmbient = Color3.fromRGB(150, 180, 220),
		fogColor = Color3.fromRGB(60, 120, 160),
		fogStart = 60,
		fogEnd = 500,
	},
}

-- Preview is presentation only. CI_WorldTick on Workspace switches to authoritative ticks.
BasinVisualConfig.VISUAL_PREVIEW_ENABLED = true
BasinVisualConfig.PREVIEW_START_TICK = 360
BasinVisualConfig.PREVIEW_TICKS_PER_SECOND = 1
BasinVisualConfig.MOONLIGHT = 0.2
BasinVisualConfig.UNDERWATER_EFFECTS_ENABLED = true
BasinVisualConfig.WATER_DETAIL_TEXTURE = "" -- Optional approved texture asset, not a normal map.
BasinVisualConfig.WATER_TEXTURE_TILE_STUDS = 12
BasinVisualConfig.WATER_TEXTURE_SCROLL_SPEED = 0.2
BasinVisualConfig.LIGHTING_UPDATE_INTERVAL = 0.1
return table.freeze(BasinVisualConfig)

