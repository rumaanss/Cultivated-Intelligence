--!strict
-- Cheap decorative surface overlays, not real light projection or ray-traced caustics.
local Lighting = game:GetService("Lighting")
local Config = require(script.Parent.WaterPresentationConfig)
type Record = { texture: Texture, depth: number, phase: number }
export type Handle = { Update: (number) -> (), Destroy: () -> () }
local M = {}
function M.new(receivers: { BasePart }, surfaceY: number): Handle
	local records: { Record } = {}
	local elapsed, accumulated = 0, 0
	local destroyed = false
	if Config.CausticEnabled and Config.CausticTexture ~= "" then
		for i = 1, math.min(#receivers, Config.CausticMaxReceivers) do
			local receiver = receivers[i]
			local texture = Instance.new("Texture")
			texture.Name = "CI_CausticOverlay"
			texture.Face = Enum.NormalId.Top
			texture.Texture = Config.CausticTexture
			texture.Color3 = Color3.fromRGB(171, 221, 238)
			texture.StudsPerTileU = Config.CausticTileStuds
			texture.StudsPerTileV = Config.CausticTileStuds
			texture.Transparency = 1
			texture.Parent = receiver
			table.insert(records, { texture = texture, depth = math.max(0, surfaceY - receiver.Position.Y - receiver.Size.Y / 2), phase = i * 0.731 })
		end
	end
	local function update(dt: number)
		if destroyed or #records == 0 then return end
		elapsed += dt
		accumulated += dt
		if accumulated < 1 / Config.CausticUpdateHz then return end
		accumulated %= 1 / Config.CausticUpdateHz
		debug.profilebegin("CI:WaterCaustics")
		local daylight = math.max(0, Lighting:GetSunDirection().Y)
		for _, record in records do
			local texture = record.texture
			if texture.Parent ~= nil then
				local shimmer = 0.83 + 0.17 * math.sin(elapsed * 1.2 + record.phase)
				local strength = Config.CausticOpacity * math.exp(-Config.CausticExtinctionPerStud * record.depth) * daylight * shimmer
				texture.Transparency = 1 - math.clamp(strength, 0, 1)
				texture.OffsetStudsU = (elapsed * 0.31 + record.phase) % Config.CausticTileStuds
				texture.OffsetStudsV = (elapsed * 0.19) % Config.CausticTileStuds
			end
		end
		debug.profileend()
	end
	local function destroy()
		if destroyed then return end
		destroyed = true
		for _, record in records do record.texture:Destroy() end
		table.clear(records)
	end
	return { Update = update, Destroy = destroy }
end
return M
