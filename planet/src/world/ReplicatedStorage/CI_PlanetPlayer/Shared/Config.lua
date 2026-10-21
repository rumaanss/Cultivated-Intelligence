--!strict
-- Player tuning is independent of terrain generation. Change only in Edit mode.
return table.freeze({
 Version = "1.3.0",
 DatasetId = "9059c708063c5a43d44f27a03a1944b28d7fe094e507d487dce41e2e7c9f6c9a",
 Center = Vector3.zero, SeaRadius = 4096,
 LakeLatitude = -23.133702947184133, LakeLongitude = -98.52227260602828,
 MetresPerStud = 0.28, Gravity = 9.80665 * 0.75 / 0.28,
 WalkSpeed = 12, SprintSpeed = 19, JumpHeight = 2.5,
 MaxSlope = 48, SpawnSlope = 20, SpawnWaterSetback = 6,
 GroundProbeExtra = 0.25, GroundEnterExtra = 0.15, DiagnosticProbeLength = 16, JumpDetachSeconds = 0.18,
 AccelerationTime = 0.12, DecelerationTime = 0.10,
 AirAcceleration = 9, TurnSpeed = 12, GroundAcceleration = 140,
 CapsuleRadius = 0.85, OrientationResponsiveness = 35,
 FOV = 65, MouseRadiansPerPixel = math.rad(0.12),
 SensitivityMin = 0.04, SensitivityMax = 0.14, SensitivityStep = 0.01,
 MaxLookSampleRadians = math.rad(120),
 ShoreNorth = 220, ShoreEast = 0, ShoreSearchRadius = 48,
 NormalPitchDown = math.rad(75), NormalPitchUp = math.rad(65),
 FreePitchDown = math.rad(90), FreePitchUp = math.rad(85), FreeYaw = math.rad(105),
 RecenterSeconds = 0.20, NeckYaw = math.rad(55), NeckPitch = math.rad(35),
 EyeHeightFraction = 0.20, EyeFrontFraction = 0.48,
 WorldWaitSeconds = 120, ClientReadySeconds = 35,
 MinRadius = 2900, MaxRadius = 6000, KillPlane = -10000,
 DiagnosticHz = 5, PoseHz = 15, RespawnSeconds = 3,
 -- Recovery requests are Studio-only; live combat cannot use them to teleport.
 StudioRecovery = true,
})
