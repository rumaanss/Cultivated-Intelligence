--!strict
-- Static surface styling only; source geometry remains the collision authority.
return table.freeze({
 Seed = 71.29,
 CellSize = 12.5, -- Eight cells per axis; no per-frame terrain work.
 PatchScale = 29,
 RockSlope = 0.85,
 ColorVariation = 0.16,
 DeepSilt = Color3.fromRGB(82,91,83),
 ShallowSand = Color3.fromRGB(185,164,120),
 DeepRock = Color3.fromRGB(64,76,80),
 ShallowRock = Color3.fromRGB(122,126,115),
 Silt = Color3.fromRGB(102,99,75),
 WarmSediment = Color3.fromRGB(163,143,106),
})
