--!strict
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local recorded = false
local Model=require(script.Parent.LightingModel)

export type CelestialState = {
	daylight: number,
	isDay: boolean,
	moonlight: number,
	ambientLight: number,
	phase: number,
}
export type LightingPreset = {
	clockTime: number,
	brightness: number,
	exposureCompensation: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	fogColor: Color3,
	fogStart: number,
	fogEnd: number,
}
export type LightingCycle = { night: LightingPreset, day: LightingPreset }

local Controller = {}
local cycleTicks = 1440
local moonlight = 0.2
local lastTick = 0
local state: CelestialState = {
	daylight = 0, isDay = false, moonlight = moonlight, ambientLight = moonlight, phase = 0,
}

function Controller.update(worldTick: number)
	assert(worldTick == worldTick and math.abs(worldTick) < math.huge, "World tick must be finite")
	lastTick = worldTick
	local phase = (worldTick % cycleTicks) / cycleTicks
	Lighting.ClockTime = (6 + phase * 24) % 24
	local sunHeight = Lighting:GetSunDirection().Y
	state.phase = phase
	recorded = Workspace:GetAttribute("CI_PlaybackMode") == "RecordedPlayback" or Workspace:GetAttribute("CI_PlaybackMode") == "Live"
	if recorded then
		local day = Workspace:GetAttribute("CI_PresentationDaylight")
		local ambient = Workspace:GetAttribute("CI_PresentationAmbient")
		if type(day) == "number" and type(ambient) == "number" then
			state.daylight = math.clamp(day,0,1)
			state.moonlight = moonlight -- Legacy C++ constant baseline, not moon elevation.
			state.ambientLight = math.clamp(ambient,0,1)
			state.isDay = state.daylight > 0
			return
		end
	end
	state.daylight = math.max(0, sunHeight)
	state.isDay = sunHeight > 0
	state.moonlight = moonlight * math.max(0, Lighting:GetMoonDirection().Y)
	state.ambientLight = math.clamp(state.daylight + state.moonlight * (1-state.daylight),0,1)
end

function Controller.initialize(newCycleTicks: number, newMoonlight: number)
	assert(newCycleTicks == newCycleTicks and newCycleTicks > 0 and newCycleTicks < math.huge, "Invalid cycle length")
	assert(newMoonlight == newMoonlight and math.abs(newMoonlight) < math.huge, "Invalid moonlight")
	cycleTicks = math.max(newCycleTicks, 1)
	moonlight = math.clamp(newMoonlight, 0, 1)
	Controller.update(lastTick)
end

function Controller.getState(): CelestialState
	return table.clone(state) -- Inspection cannot mutate internal state.
end

function Controller.applyToLighting(_config: LightingCycle)
 -- Preview affects this client's rendering only, never world ticks or biological light.
 local preview=Workspace:GetAttribute("CI_LightingPreviewHour")
 local hour=(6+state.phase*24)%24
 if type(preview)=="number" and preview==preview and math.abs(preview)<math.huge then hour=preview%24 end
 Lighting.ClockTime=hour
 local visual=Model.evaluate(Lighting:GetSunDirection().Y,Lighting:GetMoonDirection().Y)
 Lighting.Brightness=visual.brightness
 Lighting.Ambient=visual.ambient
 Lighting.OutdoorAmbient=visual.outdoor
 Lighting.EnvironmentDiffuseScale=visual.diffuse
 Lighting.EnvironmentSpecularScale=visual.specular
 Lighting.ColorShift_Top=visual.top
 -- Depth composition owns final exposure/fog. Capture reads this immutable baseline,
 -- never its previous frame's adapted output.
 Workspace:SetAttribute("CI_BaseExposure",visual.exposure)
 Workspace:SetAttribute("CI_BaseFogColor",visual.fog)
 Workspace:SetAttribute("CI_BaseFogStart",visual.fogStart)
 Workspace:SetAttribute("CI_BaseFogEnd",visual.fogEnd)
 Workspace:SetAttribute("CI_VisualDay",visual.day)
 Workspace:SetAttribute("CI_VisualMoon",visual.moon)
 Workspace:SetAttribute("CI_LightingBuild","moonlight-v5-opaque-seam")
end

return Controller
