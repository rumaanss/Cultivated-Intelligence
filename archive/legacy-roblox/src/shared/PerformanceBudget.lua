--!strict

local PerformanceBudget = table.freeze({
	TargetFrameTimeMs = 16.67, -- 60 FPS target
	MinimumSupportedFrameTimeMs = 33.33, -- 30 FPS floor

	BridgeSnapshotsPerSecond = 4,
	MaximumSnapshotAgeSeconds = 1.0,

	MaximumVisibleOrganisms = 1_500,
	MaximumHighDetailOrganisms = 150,
	MaximumMediumDetailOrganisms = 500,

	NearDetailDistance = 120,
	MediumDetailDistance = 350,

	MaximumRenderUpdatesPerSecond = 30,
})

return PerformanceBudget
