--!strict
-- Replaces the existing LocalScript. No organism-follow behavior is fabricated.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("ResearchCameraConfig"))
local SimulationSpace = require(Shared:WaitForChild("SimulationSpace"))
local bounds = SimulationSpace.Bounds
local BINDING = "CI.ResearchCamera"
local INPUT_ACTION = "CI.ResearchCamera.Movement"
local connections: { RBXScriptConnection } = {}
local pressed: { [Enum.KeyCode]: boolean } = {}
local activeCamera: Camera? = nil
local previousCameraType: Enum.CameraType? = nil
local previousCameraFrame: CFrame? = nil
local previousCameraFocus: CFrame? = nil
local previousMouseBehavior: Enum.MouseBehavior? = nil
local previousMouseIconEnabled: boolean? = nil
local rotating = false
local windowFocused = true
local destroyed = false
local speed = Config.BaseMoveSpeedStudsPerSecond
local position = Vector3.zero
local yaw = 0
local pitch = 0

local function clampPosition(value: Vector3): Vector3
	local halfWidth = bounds.width * 0.5 + Config.HorizontalOverviewMarginStuds
	local halfLength = bounds.length * 0.5 + Config.HorizontalOverviewMarginStuds
	return Vector3.new(
		math.clamp(value.X, -halfWidth, halfWidth),
		math.clamp(value.Y, -bounds.depth + Config.FloorClearanceStuds, Config.MaximumHeightAboveSurfaceStuds),
		math.clamp(value.Z, -halfLength, halfLength)
	)
end

local function resetView()
	position = clampPosition(Vector3.new(0, Config.InitialHeightAboveSurfaceStuds, Config.InitialBackOffsetStuds))
	local target = Vector3.new(0, -bounds.depth * Config.InitialFocusDepthFraction, 0)
	local direction = (target - position).Unit
	yaw = math.atan2(-direction.X, -direction.Z)
	pitch = math.asin(math.clamp(direction.Y, -1, 1))
	table.clear(pressed)
end

local function releaseMouse()
	if rotating then
		rotating = false
		local behavior = previousMouseBehavior
		local iconEnabled = previousMouseIconEnabled
		if behavior ~= nil then UserInputService.MouseBehavior = behavior end
		if iconEnabled ~= nil then UserInputService.MouseIconEnabled = iconEnabled end
		previousMouseBehavior = nil
		previousMouseIconEnabled = nil
	end
end

local function clearInput()
	table.clear(pressed)
	releaseMouse()
end

local function inputAllowed(): boolean
	return Workspace:GetAttribute("CI_LiveCombat") ~= true and windowFocused and not GuiService.MenuIsOpen and UserInputService:GetFocusedTextBox() == nil
end

local function restoreCamera()
	local camera = activeCamera
	if camera ~= nil and camera.Parent ~= nil and camera.CameraType == Enum.CameraType.Scriptable then
		local oldType = previousCameraType
		local oldFrame = previousCameraFrame
		local oldFocus = previousCameraFocus
		if oldFrame ~= nil then camera.CFrame = oldFrame end
		if oldFocus ~= nil then camera.Focus = oldFocus end
		if oldType ~= nil then camera.CameraType = oldType end
	end
	activeCamera = nil
	previousCameraType = nil
	previousCameraFrame = nil
	previousCameraFocus = nil
end

local function adoptCurrentCamera()
	local camera = Workspace.CurrentCamera
	if camera == activeCamera then return end
	restoreCamera()
	if camera ~= nil then
		activeCamera = camera
		previousCameraType = camera.CameraType
		previousCameraFrame = camera.CFrame
		previousCameraFocus = camera.Focus
		camera.CameraType = Enum.CameraType.Scriptable
	end
end

local function movementAction(_name: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		pressed[input.KeyCode] = nil
	end
	if not inputAllowed() then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then pressed[input.KeyCode] = true end
	return Enum.ContextActionResult.Sink
end

local function axis(positive: Enum.KeyCode, negative: Enum.KeyCode): number
	return (if pressed[positive] then 1 else 0) - (if pressed[negative] then 1 else 0)
end

local function update(deltaTime: number)
	if destroyed then return end
 if Workspace:GetAttribute("CI_LiveCombat") == true then clearInput();restoreCamera();return end
	debug.profilebegin("CI:ResearchCamera")
	adoptCurrentCamera()
	local camera = activeCamera
	if camera == nil then
		debug.profileend()
		return
	end
	if inputAllowed() then
		if rotating then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
			local delta = UserInputService:GetMouseDelta()
			yaw = (yaw - delta.X * Config.MouseSensitivityRadiansPerPixel) % (2 * math.pi)
			pitch = math.clamp(pitch - delta.Y * Config.MouseSensitivityRadiansPerPixel,
				-Config.MaximumPitchRadians, Config.MaximumPitchRadians)
		end
		local horizontal = CFrame.Angles(0, yaw, 0)
		local up = if pressed[Enum.KeyCode.Q] or pressed[Enum.KeyCode.Space] then 1 else 0
		local down = if pressed[Enum.KeyCode.E] or pressed[Enum.KeyCode.LeftControl] then 1 else 0
		local move = horizontal.LookVector * axis(Enum.KeyCode.W, Enum.KeyCode.S)
			+ horizontal.RightVector * axis(Enum.KeyCode.D, Enum.KeyCode.A)
			+ Vector3.new(0, up - down, 0)
		if move.Magnitude > 0 then
			local multiplier = if UserInputService:IsKeyDown(Config.BoostKey) then Config.BoostMultiplier else 1
			local dt = math.clamp(deltaTime, 0, Config.MaximumFrameDeltaSeconds)
			-- Clamp authoritative camera state, not only the displayed transform.
			position = clampPosition(position + move.Unit * speed * multiplier * dt)
		end
	else
		clearInput()
	end
	local frame = CFrame.new(position) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = frame
	camera.Focus = CFrame.new(position + frame.LookVector * Config.FocusDistanceStuds)
	debug.profileend()
end

table.insert(connections, UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or not inputAllowed() then return end
	if input.UserInputType == Config.RotateMouseButton and not rotating then
		previousMouseBehavior = UserInputService.MouseBehavior
		previousMouseIconEnabled = UserInputService.MouseIconEnabled
		rotating = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		UserInputService.MouseIconEnabled = false
	elseif input.KeyCode == Config.ResetKey then
		resetView()
	end
end))
table.insert(connections, UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Config.RotateMouseButton then releaseMouse() end
end))
table.insert(connections, UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
	if not processed and inputAllowed() and input.UserInputType == Enum.UserInputType.MouseWheel then
		speed = math.clamp(speed + input.Position.Z * Config.MouseWheelSpeedStep,
			Config.MinimumMoveSpeedStudsPerSecond, Config.MaximumMoveSpeedStudsPerSecond)
	end
end))
table.insert(connections, UserInputService.WindowFocusReleased:Connect(function()
	windowFocused = false
	clearInput()
end))
table.insert(connections, UserInputService.WindowFocused:Connect(function() windowFocused = true end))
table.insert(connections, UserInputService.TextBoxFocused:Connect(clearInput))
table.insert(connections, GuiService.MenuOpened:Connect(clearInput))

local function cleanup()
	if destroyed then return end
	destroyed = true
	RunService:UnbindFromRenderStep(BINDING)
	ContextActionService:UnbindAction(INPUT_ACTION)
	clearInput()
	restoreCamera()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
end
table.insert(connections, script.Destroying:Connect(cleanup))
table.insert(connections, script:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not script.Enabled then cleanup() end
end))

resetView()
adoptCurrentCamera()
ContextActionService:BindActionAtPriority(INPUT_ACTION, movementAction, false,
	Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
	Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.Space, Enum.KeyCode.LeftControl)
RunService:BindToRenderStep(BINDING, Enum.RenderPriority.Camera.Value + 1, update)

