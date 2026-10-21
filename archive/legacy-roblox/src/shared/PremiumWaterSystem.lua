--!strict
-- v5: viewer-owned water; native terrain is available only as a Studio comparison.
local Workspace = game:GetService("Workspace")
local Surface = require(script.Parent.WaterSurface)
local Optics = require(script.Parent.WaterOptics)
local Caustics = require(script.Parent.WaterCaustics)
export type Options = {
	Width: number, Length: number, Depth: number, SurfaceY: number,
	UnderwaterEffectsEnabled: boolean,
}
export type Handle = {
	Update: (number) -> (), CaptureLightingBase: () -> (),
	SetCausticReceivers: ({ BasePart }) -> (), Destroy: () -> (),
}
local Config = require(script.Parent.WaterPresentationConfig)
local M = {}
function M.new(parent: Instance, options: Options): Handle
	assert(options.Width > 0 and options.Length > 0 and options.Depth > 0, "Invalid basin dimensions")
	local folder = Instance.new("Folder")
	folder.Name = "PremiumWaterSystem"
	folder:SetAttribute("VisualOnly", true)
	folder.Parent = parent
	local surface = Surface.new(folder, { Width = options.Width, Length = options.Length, Depth = options.Depth, SurfaceY = options.SurfaceY })
	local optics = Optics.new(folder, {
		Width = options.Width+2*Config.VisualPaddingStuds, Length = options.Length+2*Config.VisualPaddingStuds, Depth = options.Depth,
		SurfaceY = options.SurfaceY, Enabled = options.UnderwaterEffectsEnabled,
	})
	local caustics: Caustics.Handle? = nil
	local destroyed = false
	local function receivers(parts: { BasePart })
		if destroyed then return end
		if caustics ~= nil then caustics.Destroy() end
		caustics = Caustics.new(parts, options.SurfaceY)
	end
	local function update(dt: number)
		if destroyed or dt ~= dt or dt < 0 or dt == math.huge then return end
		surface.Update(dt)
		local camera = Workspace.CurrentCamera
		local surfaceY = options.SurfaceY
		if camera ~= nil then
			local p = camera.CFrame.Position
			surfaceY = surface.Height(p.X, p.Z)
		end
		optics.Update(dt, surfaceY)
		if caustics ~= nil then caustics.Update(dt) end
	end
	local function capture()
		if not destroyed then optics.CaptureLightingBase() end
	end
	local function destroy()
		if destroyed then return end
		destroyed = true
		if caustics ~= nil then caustics.Destroy() end
		optics.Destroy()
		surface.Destroy()
		folder:Destroy()
	end
	return { Update = update, CaptureLightingBase = capture, SetCausticReceivers = receivers, Destroy = destroy }
end
return M
