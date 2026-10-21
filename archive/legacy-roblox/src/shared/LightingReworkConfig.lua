--!strict
-- Visual lighting only. Never changes C++ energy, vision or the simulation clock.
return table.freeze({
 NightPanorama = "rbxassetid://128628424211288", -- Optional new night image; empty retains SkyArtConfig.NightPanorama.
 MoonBrightness = 2.0,
 NightExposure = 0.18,
 DayExposure = 0.0,
 NightAmbient = Color3.fromRGB(44,51,65),
 NightOutdoorAmbient = Color3.fromRGB(91,105,128),
 DayAmbient = Color3.fromRGB(40,43,48),
 DayOutdoorAmbient = Color3.fromRGB(99,108,120),
 CloudCover = 0.38,
 CloudDensity = 0.48,
 NightSkyOpacity = 0.82,
 UnderwaterExposureFloor = -0.65,
 DeepExposureLoss = 0.85,
 MoonGlintOpacity = 0.22,
})
