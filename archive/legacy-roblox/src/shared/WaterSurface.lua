--!strict
-- One renderer visible at a time. Comparison UI and native mode are Studio-only.
local Workspace=game:GetService("Workspace")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local Renderer=require(script.Parent.WaterRendererConfig)
local Procedural=require(script.Parent.ProceduralLakeSurface)
local Native=require(script.Parent.NativeLakeSurface)
export type Options={Width:number,Length:number,Depth:number?,SurfaceY:number}
export type Handle={Update:(number)->(),Height:(number,number)->number,Destroy:()->()}
local Glint=require(script.Parent.MoonWaterGlint)
local M={}
function M.new(parent:Instance,options:Options):Handle
	local glint=Glint.new(parent,options.Width,options.Length,options.SurfaceY)
	local destroyed=false
	local seconds=0
	local mode=if Renderer.DefaultRenderer=="GlassReference" then "GlassReference" else "Procedural"
	local roots:{[string]:Folder}={}
	local handles:{[string]:Procedural.Handle}={}
	local native=Native.new(options.Width,options.Length,options.Depth or 60,options.SurfaceY)
	local connections:{RBXScriptConnection}={}
	local basin=parent:FindFirstAncestorOfClass("Model")
	local gui:ScreenGui?=nil
	local modeButton:TextButton?=nil
	local stats:TextLabel?=nil
	local status=""
	local samples:{number}={}
	local luaTotal,frameTotal,count,statsElapsed=0,0,0,0
	local transitionUntil=0
	local safetyElapsed=0
	local function surface(name:string):Procedural.Handle
		local cached=handles[name]
		if cached then return cached end
		local folder=Instance.new("Folder")
		folder.Name=name
		folder.Parent=parent
		roots[name]=folder
		local handle=Procedural.new(folder,{Width=options.Width,Length=options.Length,SurfaceY=options.SurfaceY,Reference=name=="GlassReference"})
		handles[name]=handle
		handle.SetTime(seconds)
		return handle
	end
	local function refreshButton()
		if modeButton then modeButton.Text="Water: "..mode.."  [F7]" end
	end
	local function selectMode(nextMode:string)
		if destroyed or nextMode==mode then return end
		if nextMode=="Native" then
			local ok,reason=native.Enable()
			if not ok then status=reason;warn("[CI Water Lab] "..reason);return end
		else
			native.Disable()
		end
		for _,handle in handles do handle.SetVisible(false) end
		mode=nextMode
		if mode~="Native" then local handle=surface(mode);handle.SetTime(seconds);handle.SetVisible(true) end
		status=""
		parent:SetAttribute("ActiveRenderer",mode)
		parent:SetAttribute("SurfaceMode",if mode=="Native" then "NativeTerrain" else "Initializing")
		parent:SetAttribute("NativeWidthStuds",native.Width)
		parent:SetAttribute("NativeLengthStuds",native.Length)
		table.clear(samples);luaTotal=0;frameTotal=0;count=0;statsElapsed=0
		transitionUntil=os.clock()+2 -- exclude switching/asset warmup from timing display
		refreshButton()
	end
	surface(mode).SetVisible(true)
	parent:SetAttribute("ActiveRenderer",mode)
	parent:SetAttribute("WaterBuild","5.0-comparison")
	parent:SetAttribute("DataSource","VisualPreview")
	if Renderer.ShowComparisonInStudio and RunService:IsStudio() then
		local player=Players.LocalPlayer
		assert(player~=nil,"Water comparison UI requires a client")
		local screen=Instance.new("ScreenGui")
		screen.Name="CI_WaterComparison"
		screen.ResetOnSpawn=false
		screen.Parent=player:WaitForChild("PlayerGui")
		gui=screen
		local button=Instance.new("TextButton")
		button.AnchorPoint=Vector2.new(0,1)
		button.Position=UDim2.new(0,16,1,-98)
		button.Size=UDim2.fromOffset(350,34)
		button.BackgroundColor3=Color3.fromRGB(16,30,40)
		button.BackgroundTransparency=0.12
		button.TextColor3=Color3.fromRGB(227,240,244)
		button.TextSize=14
		button.Font=Enum.Font.Gotham
		button.Parent=screen
		modeButton=button
		local label=Instance.new("TextLabel")
		label.AnchorPoint=Vector2.new(0,1)
		label.Position=UDim2.new(0,16,1,-16)
		label.Size=UDim2.fromOffset(350,78)
		label.BackgroundColor3=button.BackgroundColor3
		label.BackgroundTransparency=0.12
		label.TextColor3=button.TextColor3
		label.Font=Enum.Font.Code
		label.TextSize=12
		label.TextWrapped=true
		label.Text="Measuring; F8 freezes the preview lighting clock"
		label.Parent=screen
		stats=label
		local function cycle()
			selectMode(if mode=="Procedural" then "GlassReference" elseif mode=="GlassReference" then "Native" else "Procedural")
		end
		table.insert(connections,button.Activated:Connect(cycle))
		table.insert(connections,Input.InputBegan:Connect(function(key:InputObject,processed:boolean)
			if processed or Input:GetFocusedTextBox()~=nil then return end
			if key.KeyCode==Enum.KeyCode.F7 then cycle() end
			if key.KeyCode==Enum.KeyCode.F8 and basin then
				local pause=basin:GetAttribute("ComparisonFreezeClock")~=true
				basin:SetAttribute("ComparisonFreezeClock",pause)
			end
		end))
		refreshButton()
	end
	local function update(dt:number)
		if destroyed or dt<=0 or dt~=dt or dt==math.huge then return end
		seconds+=dt
		glint.Update(dt)
		local start=os.clock()
		if mode~="Native" then
			local handle=handles[mode]
			handle.Update(dt)
			local folder=roots[mode]
			local surfaceMode=folder:GetAttribute("SurfaceMode")
			if parent:GetAttribute("SurfaceMode")~=surfaceMode then parent:SetAttribute("SurfaceMode",surfaceMode) end
		else
			safetyElapsed+=dt
			if safetyElapsed>=0.5 then
				safetyElapsed=0
				local safe,reason=native.CheckSafe()
				if not safe then selectMode("Procedural");status=reason end
			end
		end
		local cost=(os.clock()-start)*1000
		if stats then
			statsElapsed+=dt
			if os.clock()>=transitionUntil then
				luaTotal+=cost;frameTotal+=dt*1000;count+=1
				if #samples<600 then table.insert(samples,dt*1000) end
			end
			if statsElapsed>=2 then
				statsElapsed=0
				table.sort(samples)
				local p95=if #samples>0 then samples[math.max(1,math.ceil(#samples*0.95))] else 0
				local paused=basin~=nil and basin:GetAttribute("ComparisonFreezeClock")==true
				local clockLabel=if basin and basin:GetAttribute("LightingSource")=="Simulation" then "external" elseif paused then "paused" else "running"
				stats.Text=if status~="" then status else string.format("Frame avg %.1f ms | p95 %.1f ms\nWater Lua avg %.3f ms (NOT GPU cost)\nPreview clock %s [F8] | visual only",frameTotal/math.max(count,1),p95,luaTotal/math.max(count,1),clockLabel)
				table.clear(samples);luaTotal=0;frameTotal=0;count=0
			end
		end
	end
	local function height(x:number,z:number):number
		if mode=="Native" then return native.SurfaceY end -- engine ripple height is not exposed
		return handles[mode].Height(x,z)
	end
	local function destroy()
		if destroyed then return end
		destroyed=true;glint.Destroy()
		for _,connection in connections do connection:Disconnect() end
		for _,handle in handles do handle.Destroy() end
		for _,folder in roots do folder:Destroy() end
		native.Destroy()
		if basin then basin:SetAttribute("ComparisonFreezeClock",nil) end
		if gui then gui:Destroy() end
		table.clear(handles);table.clear(roots);table.clear(connections)
	end
	return {Update=update,Height=height,Destroy=destroy}
end
return M

