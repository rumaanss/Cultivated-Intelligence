--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Input = game:GetService("UserInputService")
local Config = require(script.Parent.EnvironmentVisualConfig)
local Field = require(script.Parent.VisualCurrentField)
local M = {}

function M.new(parent: Instance, width: number, length: number, depth: number)
	local gui = Instance.new("ScreenGui")
	gui.Name = "CI_ResearchOverlay"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	local player = Players.LocalPlayer
	assert(player ~= nil, "ResearchOverlay must run on the client")
	gui.Parent = player:WaitForChild("PlayerGui")
	local button = Instance.new("TextButton")
	button.Name = "Mode"
	button.AnchorPoint = Vector2.new(1,0)
	button.Position = UDim2.new(1,-16,0,16)
	button.Size = UDim2.fromOffset(260,34)
	button.BackgroundColor3 = Color3.fromRGB(17,29,38)
	button.BackgroundTransparency = 0.15
	button.TextColor3 = Color3.fromRGB(228,239,241)
	button.TextSize = 14
	button.Font = Enum.Font.Gotham
	button.Parent = gui
	local panel = Instance.new("TextLabel")
	panel.AnchorPoint = Vector2.new(1,0)
	panel.Position = UDim2.new(1,-16,0,56)
	panel.Size = UDim2.fromOffset(300,172)
	panel.BackgroundColor3 = button.BackgroundColor3
	panel.BackgroundTransparency = 0.12
	panel.TextColor3 = button.TextColor3
	panel.TextSize = 14
	panel.Font = Enum.Font.Code
	panel.TextXAlignment = Enum.TextXAlignment.Left
	panel.TextYAlignment = Enum.TextYAlignment.Top
	panel.TextWrapped = true
	panel.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingTop = UDim.new(0,12), UDim.new(0,10)
	pad.Parent = panel
	local arrows = Instance.new("Folder")
	arrows.Name = "VisualCurrentArrows"
	arrows:SetAttribute("VisualOnly",true)
	type Arrow = {shaft: Part, left: Part, right: Part, x: number, z: number}
	local records: {Arrow} = {}
	local function bar(): Part
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false,false,false,false
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(93,206,210)
		part.Parent = arrows
		return part
	end
	for i = 1,5 do for j = 1,5 do
		table.insert(records,{shaft=bar(),left=bar(),right=bar(),x=(i-3)*width/6,z=(j-3)*length/6})
	end end
	local mode, elapsed, destroyed = 0, 0, false
	local names = {"Natural", "Currents", "Light"}
	local function setMode()
		button.Text = "View: "..names[mode+1].."  [F6]"
		panel.Visible = mode ~= 0
		arrows.Parent = if mode == 1 then parent else nil
		elapsed = 1 -- refresh immediately on next presentation frame
	end
	local function cycle() mode = (mode+1)%3; setMode() end
	local click = button.Activated:Connect(cycle)
	local input = Input.InputBegan:Connect(function(key: InputObject, processed: boolean)
		if not processed and Input:GetFocusedTextBox() == nil and key.KeyCode == Enum.KeyCode.F6 then cycle() end
	end)
	setMode()
	local function segment(part: Part, a: Vector3, b: Vector3)
		local distance = (b-a).Magnitude
		part.Size = Vector3.new(0.07,0.07,math.max(distance,0.001))
		if distance > 0.001 then part.CFrame = CFrame.lookAt((a+b)*0.5,b) end
		part.Transparency = if distance > 0.001 then 0.15 else 1
	end
	return {Update=function(dt: number, seconds: number, surfaceLight: number)
		if destroyed or mode == 0 then return end
		elapsed += dt
		if elapsed < 1/Config.OverlayUpdateHz then return end
		elapsed = 0
		local camera = Workspace.CurrentCamera
		if camera == nil then return end
		local p = camera.CFrame.Position
		local sampleDepth = math.clamp(-p.Y,1,depth-1)
		local source = tostring(parent:GetAttribute("LightingSource") or "Preview")
		if mode == 1 then
			for _, arrow in records do
				local vx, _, vz = Field.sample(arrow.x,-sampleDepth,arrow.z,seconds,width,length,depth,Config.CurrentSpeed)
				local velocity = Vector3.new(vx,0,vz)
				local origin = Vector3.new(arrow.x,-sampleDepth,arrow.z)
				if velocity.Magnitude < 0.001 then
					arrow.shaft.Transparency, arrow.left.Transparency, arrow.right.Transparency = 1,1,1
				else
					local direction = velocity.Unit
					local tip = origin+direction*math.clamp(velocity.Magnitude*7,0.3,4)
					local side = Vector3.new(-direction.Z,0,direction.X)*0.35
					segment(arrow.shaft,origin,tip)
					segment(arrow.left,tip,tip-direction*0.65+side)
					segment(arrow.right,tip,tip-direction*0.65-side)
				end
			end
			panel.Text = string.format("VISUAL PREVIEW / CURRENT\nSlice depth: %.1f studs\n25 arrows • 5 Hz\nParticles share this field.\nNo C++ fluid forces applied.\nChemistry: unavailable",sampleDepth)
		else
			local value = Field.lightAtDepth(sampleDepth,surfaceLight,Config.LightExtinction)
			panel.Text = string.format("VISUAL PREVIEW / LIGHT\nDepth: %.1f studs • %.1f%%\nSurface %.1f%% | 30u %.1f%%\n60u %.1f%% | clock %.2f\nClock: %s\nApproximation; no occlusion/PAR.",sampleDepth,value*100,surfaceLight*100,Field.lightAtDepth(30,surfaceLight,Config.LightExtinction)*100,Field.lightAtDepth(60,surfaceLight,Config.LightExtinction)*100,Lighting.ClockTime,source)
		end
	end, Destroy=function()
		if destroyed then return end
		destroyed = true
		click:Disconnect()
		input:Disconnect()
		gui:Destroy()
		arrows:Destroy()
		table.clear(records)
	end}
end
return M
