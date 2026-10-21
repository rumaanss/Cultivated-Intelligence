--!strict
-- Owns environment creation, animation and teardown. Does not mutate C++ state.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
ReplicatedStorage:WaitForChild("Shared")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.BasinVisualConfig)
local Geometry = require(Shared.SharedGeometry)
local Schema = require(Shared.RecordingSchema)
local RecordingLoader = require(Shared.RecordingLoader)
local PlaybackConfig = require(Shared.PlaybackConfig)
local terrainScene: Geometry.Scene? = nil
local LiveConfig = require(Shared.LiveConfig)
local LiveScene = require(Shared.LiveScene)
if LiveConfig.Enabled then
 terrainScene = LiveScene.await().geometry
 LiveScene.Changed:Connect(function(m) terrainScene=m.geometry end)
elseif PlaybackConfig.Enabled then
 local recording = Shared:FindFirstChild("Recording")
 local index = if recording ~= nil then recording:FindFirstChild("Index") else nil
 if index ~= nil and index:IsA("ModuleScript") then
  local indexModule: ModuleScript = index
  local ok,result = pcall(function(): Schema.Manifest
   return Schema.validateManifest(game:GetService("HttpService"):JSONDecode(RecordingLoader.read(indexModule,Schema.MaxIndexBytes)))
  end)
  if ok then
   local manifest = result :: Schema.Manifest
   local scene = manifest.geometry
   if scene ~= nil and scene.terrain ~= nil then terrainScene = scene end
  end
 end
end
local SimulationSpace = require(Shared.SimulationSpace)
local Seabed = require(Shared.SeabedDetailBuilder)
local Geology = require(Shared.GeologyBuilder)
local Particles = require(Shared.ParticleSystemBuilder)
local Celestial = require(Shared.CelestialCycleController)
local Presentation = require(Shared.WaterPresentationConfig)
local ResearchLighting = require(Shared.ResearchLighting)
local Backdrop = require(Shared.BasinBackdrop)
local Water = require(Shared.PremiumWaterSystem)
local Environment = require(Shared.EnvironmentVisualConfig)
local Current = require(Shared.VisualCurrentField)
local SkyPresentation = require(Shared.CelestialPresentation)
local Overlay = require(Shared.ResearchOverlay)

type ParticleRecord = { part: BasePart, phase: number, speed: number, brightness: number, luminous: boolean }
local records: { ParticleRecord } = {}
local connections: { RBXScriptConnection } = {}
local bounds = SimulationSpace.Bounds
local floorY = -bounds.depth
local destroyed = false

local existing = Workspace:FindFirstChild(Config.ROOT_NAME)
assert(existing == nil or existing:IsA("Model"), "Research basin root must be a Model")
local root: Model
local ownsRoot = existing == nil
if existing ~= nil and existing:IsA("Model") then
	root = existing
else
	root = Instance.new("Model")
	root.Name = Config.ROOT_NAME
	root.Parent = Workspace
end

local function folder(name: string, clear: boolean): Folder
	local item = root:FindFirstChild(name)
	if item ~= nil then
		assert(item:IsA("Folder"), name .. " must be a Folder")
		if clear then item:ClearAllChildren() end
		return item
	end
	local result = Instance.new("Folder")
	result.Name = name
	result.Parent = root
	return result
end

local waterFolder = folder("Water", true)
local seabedFolder = folder("Seabed", true)
local geologyFolder = folder("Geology", true)
local particlesFolder = folder("Particles", true)
folder("Debug", false)
folder("RenderRoots", false) -- Never clear organism-owned contents.
root:SetAttribute("DecorationOnly", true)

local oldLighting = {
	ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness,
	ExposureCompensation = Lighting.ExposureCompensation,
	Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
	FogColor = Lighting.FogColor, FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd,
}

local lightingRig = ResearchLighting.new()
local celestialVisuals = SkyPresentation.new(root)
local flowWidth = math.max(4,bounds.width-2*Presentation.ShoreWidthStuds-2)
local flowLength = math.max(4,bounds.length-2*Presentation.ShoreWidthStuds-2)
local overlay = Overlay.new(root,flowWidth,flowLength,bounds.depth)
local flowSeconds = 0
root:SetAttribute("PresentationVersion","5.0-water-lab")
root:SetAttribute("CurrentSource","VisualPreview")
local backdrop = Backdrop.new(root,bounds.width,bounds.length,bounds.depth,Presentation.VisualPaddingStuds,terrainScene ~= nil)

local water = Water.new(waterFolder, {
	Width = bounds.width, Length = bounds.length, Depth = bounds.depth, SurfaceY = 0,
	UnderwaterEffectsEnabled = Config.UNDERWATER_EFFECTS_ENABLED,
})

local base = Instance.new("Part")
base.Name = "SeabedBase"
base.Anchored = true
base.CanCollide = false
base.CanQuery = false
base.CanTouch = false
base.CastShadow = false
base.Size = Vector3.new(bounds.width+2*Presentation.VisualPaddingStuds, Config.FLOOR_THICKNESS, bounds.length+2*Presentation.VisualPaddingStuds)
base.Position = Vector3.new(0, floorY - Config.FLOOR_THICKNESS * 0.5, 0)
base.Color = Config.FLOOR_COLOR
base.Material = Config.FLOOR_MATERIAL
base.Parent = seabedFolder
if terrainScene ~= nil then base.Transparency = 1 end

if terrainScene == nil and Config.SEABED_DETAIL_ENABLED then
	Seabed.buildSeabedDetail(seabedFolder, bounds.width, bounds.length, floorY,
		Config.SEABED_RIPPLE_COUNT, Config.SEABED_RIPPLE_HEIGHT, Config.SEABED_RIPPLE_COLOR_VARIANCE, Config.FLOOR_COLOR)
end
if terrainScene == nil and Config.GEOLOGY_ENABLED then
	if Config.SEDIMENT_LAYERS_ENABLED then
		Geology.buildSedimentLayers(geologyFolder, bounds.width, bounds.length, floorY,
			Config.SEDIMENT_LAYER_COUNT, Config.SEDIMENT_LAYER_THICKNESS, Config.SEDIMENT_LAYER_COLOR_GRADIENT)
	end
	if Config.ROCKY_OUTCROPS_ENABLED then
		Geology.buildRockyOutcrops(geologyFolder, bounds.width, bounds.length, floorY,
			Config.ROCKY_OUTCROP_COUNT, Config.ROCKY_OUTCROP_SIZE_RANGE, Config.ROCKY_OUTCROP_COLOR)
	end
	if Config.SAND_DUNES_ENABLED then
		Geology.buildSandDunes(geologyFolder, bounds.width, bounds.length, floorY,
			Config.SAND_DUNE_COUNT, Config.SAND_DUNE_HEIGHT, Config.SAND_DUNE_COLOR)
	end
	if Config.THERMAL_VENTS_ENABLED then
		Geology.buildThermalVents(geologyFolder, bounds.width, bounds.length, floorY,
			Config.THERMAL_VENT_COUNT, Config.THERMAL_VENT_COLOR)
	end
end

-- Cache eligible static receivers once; no per-frame descendant searches.
local causticReceivers: { BasePart } = { base }
for _, child in geologyFolder:GetChildren() do
	if child:IsA("BasePart") and string.sub(child.Name, 1, 13) == "RockyOutcrop_" then
		table.insert(causticReceivers, child)
	end
end
water.SetCausticReceivers(causticReceivers)
-- Playback creates shared parts after server validation. Register once, not per frame.
if terrainScene ~= nil then
 local function registerShared(instance: Instance)
  if instance:FindFirstAncestor("CI_LiveAuthority") ~= nil then return end
  if instance.Name ~= "CI_SharedGeometry" or not instance:IsA("Folder") then return end
  local receivers: {BasePart} = {}
  for _,part in instance:GetDescendants() do
   if part:IsA("BasePart") then table.insert(receivers,part) end
  end
  water.SetCausticReceivers(receivers)
 end
 table.insert(connections,Workspace.DescendantAdded:Connect(registerShared))
 local organisms = Workspace:FindFirstChild(if LiveConfig.Enabled then "CI_LivePresentation" else "CI_RecordedOrganisms")
 local geometry = if organisms ~= nil then organisms:FindFirstChild("CI_SharedGeometry") else nil
 if geometry ~= nil then registerShared(geometry) end
end

if Config.AMBIENT_PARTICLES_ENABLED then
	local radiusLimit = math.min(flowWidth, flowLength) * 0.5 - 0.5
	if Config.SEDIMENT_PARTICLE_ENABLED then
		Particles.createSedimentParticles(particlesFolder, Config.SEDIMENT_PARTICLE_COUNT,
			math.min(Config.SEDIMENT_PARTICLE_SPAWN_RADIUS, radiusLimit), Config.SEDIMENT_PARTICLE_COLOR,
			Config.SEDIMENT_PARTICLE_SPEED, Config.SEDIMENT_PARTICLE_SIZE, floorY)
	end
	if Config.BIOLUMINESCENCE_ENABLED then
		Particles.createBioluminescentParticles(particlesFolder, Config.BIOLUMINESCENCE_PARTICLE_COUNT,
			math.min(Config.BIOLUMINESCENCE_PARTICLE_SPAWN_RADIUS, radiusLimit), Config.BIOLUMINESCENCE_COLORS,
			Config.BIOLUMINESCENCE_BRIGHTNESS, Config.BIOLUMINESCENCE_PULSE_SPEED, Config.BIOLUMINESCENCE_MIN_DEPTH)
	end
end

local function numberAttribute(instance: Instance, name: string, fallback: number): number
	local value = instance:GetAttribute(name)
	if typeof(value) == "number" and value == value and math.abs(value) < math.huge then return value end
	return fallback
end
for _, child in particlesFolder:GetChildren() do
	if child:IsA("BasePart") then
		child.Position = Vector3.new(math.clamp(child.Position.X,-flowWidth/2+0.1,flowWidth/2-0.1), math.clamp(child.Position.Y, floorY + 0.5, -0.5), math.clamp(child.Position.Z,-flowLength/2+0.1,flowLength/2-0.1))
		table.insert(records, {
			part = child,
			phase = numberAttribute(child, "PulsePhase", 0), speed = numberAttribute(child, "PulseSpeed", 1.5),
			brightness = numberAttribute(child, "Brightness", 2), luminous = child:GetAttribute("PulsePhase") ~= nil,
		})
	end
end

local function updateParticles(dt: number)
	debug.profilebegin("CI:Particles")
	-- Bound catch-up after a debugger pause; visual particles are not simulation state.
	local duration = math.min(dt,0.2)
	for _, record in records do
		local part = record.part
		if part.Parent ~= nil then
			local p = part.Position
			local x,y,z = Current.advance(p.X,p.Y,p.Z,dt,flowSeconds,flowWidth,flowLength,bounds.depth,
				Environment.CurrentSpeed,if record.luminous then 0 else Environment.SettlingSpeed)
			local activeTerrain = terrainScene
   if activeTerrain ~= nil then
    y = math.max(y,Geometry.floorHeight(activeTerrain,x+bounds.width/2,z+bounds.length/2,0)+floorY+0.5)
   end
   part.Position = Vector3.new(x,y,z)
			if record.luminous then
				record.phase = (record.phase+record.speed*2*math.pi*duration) % (2*math.pi)
				local alpha = math.clamp(record.brightness/4,0,1)*(0.35+0.65*(0.5+0.5*math.sin(record.phase)))
				part.Transparency = 1-alpha
			end
		end
	end
	debug.profileend()
end

local previewTick = Config.PREVIEW_START_TICK
local function updateLighting()
	if not Config.CELESTIAL_CYCLE_ENABLED then
		root:SetAttribute("LightingSource","StudioClock")
		return
	end
	local cycle = numberAttribute(Workspace, "CI_CycleTicks", Config.CELESTIAL_CYCLE_DURATION)
	local moonlight = numberAttribute(Workspace, "CI_Moonlight", Config.MOONLIGHT)
	Celestial.initialize(math.max(cycle, 1), moonlight)
	local tick = numberAttribute(Workspace, "CI_WorldTick", -1)
	if tick >= 0 then
		root:SetAttribute("LightingSource", if LiveConfig.Enabled then "LiveC++" elseif Workspace:GetAttribute("CI_PlaybackMode") == "RecordedPlayback" then "RecordedPlayback" else "Simulation")
		Celestial.update(tick)
	else
		root:SetAttribute("LightingSource", if Config.VISUAL_PREVIEW_ENABLED then "VisualPreview" else "StaticPreview")
		Celestial.update(previewTick)
	end
	Celestial.applyToLighting(Presentation.LightingCycle)
	lightingRig.Update()
	water.CaptureLightingBase() -- Capture before depth effects; prevents cumulative darkening.
end

local particleElapsed = 0
local lightingElapsed = 0
updateLighting()
local function update(dt: number)
	if destroyed or dt ~= dt or dt <= 0 or dt == math.huge then return end
	flowSeconds += dt
	if Config.VISUAL_PREVIEW_ENABLED and root:GetAttribute("ComparisonFreezeClock") ~= true then
		previewTick += dt * Config.PREVIEW_TICKS_PER_SECOND
	end
	particleElapsed += dt
	if particleElapsed >= 1/Environment.CurrentUpdateHz then
		-- Integrate elapsed time with a bounded visual catch-up after long pauses.
		updateParticles(particleElapsed)
		particleElapsed = 0
	end
	lightingElapsed += dt
	if lightingElapsed >= Config.LIGHTING_UPDATE_INTERVAL then
		updateLighting()
		lightingElapsed = 0
	end
	celestialVisuals.Update()
	local sunLight = math.max(0,Lighting:GetSunDirection().Y)
	local moonLight = numberAttribute(Workspace,"CI_Moonlight",Config.MOONLIGHT)*math.max(0,Lighting:GetMoonDirection().Y)
	overlay.Update(dt,flowSeconds,math.clamp(sunLight+moonLight*(1-sunLight),0,1))
	water.Update(dt) -- Last: compose depth over this frame's celestial baseline.
end

local function cleanup()
	if destroyed then return end
	destroyed = true
	RunService:UnbindFromRenderStep("CI.BasinPresentation")
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	overlay.Destroy()
	celestialVisuals.Destroy()
	water.Destroy()
	backdrop.Destroy()
	lightingRig.Destroy()
	table.clear(records)
	seabedFolder:ClearAllChildren()
	geologyFolder:ClearAllChildren()
	particlesFolder:ClearAllChildren()
	Lighting.ClockTime = oldLighting.ClockTime
	Lighting.Brightness = oldLighting.Brightness
	Lighting.ExposureCompensation = oldLighting.ExposureCompensation
	Lighting.Ambient = oldLighting.Ambient
	Lighting.OutdoorAmbient = oldLighting.OutdoorAmbient
	Lighting.FogColor = oldLighting.FogColor
	Lighting.FogStart = oldLighting.FogStart
	Lighting.FogEnd = oldLighting.FogEnd

	-- Preserve RenderRoots even when this script originally created the basin.
	if ownsRoot and #folder("RenderRoots", false):GetChildren() == 0 then root:Destroy() end
end
table.insert(connections, script.Destroying:Connect(cleanup))
table.insert(connections, script:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not script.Enabled then cleanup() end
end))
RunService:BindToRenderStep("CI.BasinPresentation", Enum.RenderPriority.Camera.Value + 2, update)

