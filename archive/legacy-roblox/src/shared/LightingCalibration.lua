--!strict
-- Display calibration, independent of C++ optical energy.
-- Image IDs stay in LightingReworkConfig / SkyArtConfig.
return table.freeze({
 DisablePreexistingColorGrading=true,
 MoonBrightness=1.8,
 NightExposure=0.20,
 DayExposure=0,
 NightAmbient=Color3.fromRGB(75,86,106),
 NightOutdoorAmbient=Color3.fromRGB(112,126,148),
 DayAmbient=Color3.fromRGB(40,43,48),
 DayOutdoorAmbient=Color3.fromRGB(99,108,120),
 UnderwaterExposureFloor=-0.40,
 DeepExposureLoss=0.80,
})
