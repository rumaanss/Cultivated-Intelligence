--!strict
-- Desktop research camera. Bounds include an explicit exterior overview margin.
return table.freeze({
	InitialHeightAboveSurfaceStuds = 35,
	InitialBackOffsetStuds = 100,
	InitialFocusDepthFraction = 0.5,
	BaseMoveSpeedStudsPerSecond = 45,
	BoostMultiplier = 3,
	MinimumMoveSpeedStudsPerSecond = 5,
	MaximumMoveSpeedStudsPerSecond = 250,
	MouseWheelSpeedStep = 5,
	MouseSensitivityRadiansPerPixel = 0.0025,
	MaximumPitchRadians = math.rad(85),
	MaximumFrameDeltaSeconds = 0.1,
	HorizontalOverviewMarginStuds = 1050,
	MaximumHeightAboveSurfaceStuds = 1000,
	FloorClearanceStuds = 0.5,
	FocusDistanceStuds = 30,
	RotateMouseButton = Enum.UserInputType.MouseButton2,
	ResetKey = Enum.KeyCode.R,
	BoostKey = Enum.KeyCode.LeftShift,
})
