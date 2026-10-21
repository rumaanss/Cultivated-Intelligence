--!strict
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Config = require(script.Parent.WaterPresentationConfig)
local Art = require(script.Parent.LightingCalibration)
local Math = require(script.Parent.WaterWaveMath)
export type Options = { Width: number, Length: number, Depth: number, SurfaceY: number, Enabled: boolean }
export type Handle = { Update: (number, number) -> (), CaptureLightingBase: () -> (), Destroy: () -> () }
local M = {}
local LiveScene=require(script.Parent.LiveScene)
local Geometry=require(script.Parent.SharedGeometry)

function M.new(parent: Instance, options: Options): Handle
	local destroyed = false
	local blend, depth = 0, 0
	local fogColor, fogStart, fogEnd = Lighting.FogColor, Lighting.FogStart, Lighting.FogEnd
	local exposure = Lighting.ExposureCompensation
	local brightness = Lighting.Brightness
	local adaptedExposure = exposure
 local auditElapsed=0
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "CI_DepthAbsorption"
	grade.Enabled = false
	grade.Parent = Lighting
	local parked = Instance.new("Folder")
	parked.Name = "SuspendedAtmospheres"
	parked.Parent = parent
	local atmospheres: { Atmosphere } = {}
	for _, instance in Lighting:GetChildren() do
		if instance:IsA("Atmosphere") then table.insert(atmospheres, instance) end
	end
	local waterAtmosphere = Instance.new("Atmosphere")
 waterAtmosphere.Name = "CI_WaterScattering"
 local suspended = false
	local function suspend(value: boolean)
		if suspended == value then return end
		suspended = value
  waterAtmosphere.Parent = if value then Lighting else parked
		for _, atmosphere in atmospheres do
			if value and atmosphere.Parent == Lighting then
				atmosphere.Parent = parked
			elseif not value and atmosphere.Parent == parked then
				atmosphere.Parent = Lighting
			end
		end
	end
	local function capture()
        local e=Workspace:GetAttribute("CI_BaseExposure")
        local c=Workspace:GetAttribute("CI_BaseFogColor")
        local a=Workspace:GetAttribute("CI_BaseFogStart")
        local b=Workspace:GetAttribute("CI_BaseFogEnd")
        exposure=if type(e)=="number" then e else Lighting.ExposureCompensation
        fogColor=if typeof(c)=="Color3" then c else Lighting.FogColor
        fogStart=if type(a)=="number" then a else Lighting.FogStart
        fogEnd=if type(b)=="number" then b else Lighting.FogEnd
        brightness=Lighting.Brightness
	end
	local function update(dt: number, surfaceY: number)
		if destroyed then return end
		debug.profilebegin("CI:WaterOptics")
		local targetBlend, targetDepth = 0, 0
		local camera = Workspace.CurrentCamera
		if options.Enabled and camera ~= nil then
			local p = camera.CFrame.Position
			local edge = math.min(options.Width / 2 - math.abs(p.X), options.Length / 2 - math.abs(p.Z))
			local floorY=options.SurfaceY-options.Depth
   local manifest=LiveScene.get()
   local scene=if manifest then manifest.geometry else nil
   if scene and scene.terrain and scene.terrain.heightfield then
    floorY=Geometry.floorHeight(scene,p.X+scene.bounds[1]/2,p.Z+scene.bounds[2]/2,0)-scene.bounds[3]
    edge=math.min(edge,(options.SurfaceY-floorY)*2)
   end
   local floorDistance = p.Y-floorY
			local wetDepth = surfaceY - p.Y
			local boundary = Math.smoothstep(edge / Config.BoundaryFadeStuds)
			local bottom = Math.smoothstep((floorDistance + 0.25) / 0.5)
			targetBlend = Math.smoothstep(wetDepth / Config.SurfaceBlendStuds) * boundary * bottom
			targetDepth = math.clamp(options.SurfaceY - p.Y, 0, options.Depth)
		end
		local alpha = 1 - math.exp(-dt / Config.TransitionSeconds)
		blend += (targetBlend - blend) * alpha
		depth += (targetDepth - depth) * alpha
		if targetBlend == 0 and blend < 0.001 then blend = 0 end
		-- Fog is distance-based; no stacked translucent volumes are created.
		suspend(blend > 0)
		grade.Enabled = blend > 0
		local layers = Config.DepthLayers
		local lower, upper = layers[1], layers[#layers]
		for i = 1, #layers - 1 do
			if depth <= layers[i + 1].Depth then
				lower, upper = layers[i], layers[i + 1]
				break
			end
		end
		if depth >= layers[#layers].Depth then lower, upper = layers[#layers], layers[#layers] end
		local fraction = if upper.Depth == lower.Depth then 0 else Math.smoothstep((depth - lower.Depth) / (upper.Depth - lower.Depth))
		local visibility = lower.Visibility + (upper.Visibility - lower.Visibility) * fraction
		local visualDay=Workspace:GetAttribute("CI_VisualDay")
		local daylight=if type(visualDay)=="number" then math.clamp(visualDay,0,1) else 1
			visibility *= 0.75+0.25*daylight
		local tint = lower.FogColor:Lerp(upper.FogColor, fraction)
		-- Scattered water light must dim at night along with the sky illumination.
		local fogLight = 0.16+0.84*math.sqrt(math.clamp(brightness/Config.LightingCycle.day.brightness,0,1))
		tint = Color3.new(tint.R*fogLight,tint.G*fogLight,tint.B*fogLight)
		local attenuation = -Art.DeepExposureLoss * Math.smoothstep(depth / math.max(options.Depth,1))
		local saturation = lower.Saturation + (upper.Saturation - lower.Saturation) * fraction
		local r, g, b = Math.absorption(depth, Config.AbsorptionRed, Config.AbsorptionGreen, Config.AbsorptionBlue)
		grade.TintColor = Color3.new(1, 1, 1):Lerp(Color3.new(math.max(r,0.48), math.max(g,0.65), math.max(b,0.80)), blend)
		grade.Saturation = saturation * blend
		grade.Contrast = 0.025 * blend
		grade.Brightness = 0 -- Exposure carries brightness; avoid double darkening.
		local targetExposure = math.clamp(exposure + attenuation * blend,Art.UnderwaterExposureFloor,1)
		adaptedExposure += (targetExposure-adaptedExposure)*(1-math.exp(-dt/Config.ExposureAdaptSeconds))
		Lighting.ExposureCompensation = adaptedExposure
		Lighting.FogColor = fogColor:Lerp(tint, blend)
		-- Atmosphere supplies a continuous distance response instead of a
  -- finite FogEnd wall. Blend from the current air owner at the interface.
  local base = atmospheres[1]
  local baseDensity = if base then base.Density else .18
  local baseHaze = if base then base.Haze else .55
  local baseColor = if base then base.Color else fogColor
  local baseDecay = if base then base.Decay else fogColor
  local density = math.clamp(.28 + 10 / math.max(visibility, 1), .28, .55)
  waterAtmosphere.Density = baseDensity + (density-baseDensity)*blend
  waterAtmosphere.Haze = baseHaze + (2-baseHaze)*blend
  waterAtmosphere.Offset = if base then base.Offset*(1-blend) else 0
  waterAtmosphere.Color = baseColor:Lerp(tint,blend)
  waterAtmosphere.Decay = baseDecay:Lerp(tint,blend)
  waterAtmosphere.Glare = if base then base.Glare*(1-blend) else 0
  Lighting.FogStart = 0
  Lighting.FogEnd = 100000
        auditElapsed+=dt
        if auditElapsed>=.5 then
            auditElapsed=0
            Workspace:SetAttribute("CI_FinalExposure",adaptedExposure)
            Workspace:SetAttribute("CI_OpticsDepth",depth)
            Workspace:SetAttribute("CI_OpticsBlend",blend)
        end
		debug.profileend()
	end
	local function destroy()
		if destroyed then return end
		destroyed = true
		suspend(false)
		Lighting.FogColor, Lighting.FogStart, Lighting.FogEnd = fogColor, fogStart, fogEnd
		Lighting.ExposureCompensation = exposure
		grade:Destroy()
		waterAtmosphere:Destroy()
		parked:Destroy()
		table.clear(atmospheres)
	end
	return { Update = update, CaptureLightingBase = capture, Destroy = destroy }
end
return M

