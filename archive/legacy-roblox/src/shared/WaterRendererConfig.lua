--!strict
-- Renderer controls only. No physical forces or biological state.
return table.freeze({
	DefaultRenderer = "GlassReference", -- Accepted appearance baseline
	ShowComparisonInStudio = false,
	Cells = 40, -- 1,681 vertices / 3,200 triangles, one surface
	NearHz = 30,
	FarHz = 15,
	FarDistance = 140,
	CullDistance = 420,
	Amplitude = 1,
	Speed = 1,
	NativeWaveSize = 0.18,
	NativeWaveSpeed = 8,
	NativeTransparency = 0.72,
	NativeReflectance = 0.22,
})

