--!strict
-- Only NEW image IDs go here. Keep existing WaterVisualConfig texture IDs.
return table.freeze({
	SkyPanorama = "rbxassetid://128247385900557",
	SunTexture = "rbxassetid://128675487311945",
	MoonTexture = "rbxassetid://111382810906929",
	SkyRadius = 280,
	BodyDistance = 180,
	SunAngularDegrees = 0.8,
	MoonAngularDegrees = 1.2, -- slightly enlarged to show the full-moon detail
	CurrentSpeed = 0.65, -- visual studs/second, not a C++ velocity measurement
	SettlingSpeed = 0.08,
	CurrentUpdateHz = 20,
	OverlayUpdateHz = 5,
	LightExtinction = 0.045, -- artistic scalar; not PAR or calibrated irradiance
})
