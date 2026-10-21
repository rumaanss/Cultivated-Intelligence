--!strict
-- Camera-relative visual bodies. Roblox's directional light supplies shadows.
local AssetService = game:GetService("AssetService")
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Config = require(script.Parent.EnvironmentVisualConfig)
local Art = require(script.Parent.SkyArtConfig)
local Rework = require(script.Parent.LightingReworkConfig)
local NightImage = if Rework.NightPanorama ~= "" then Rework.NightPanorama else Art.NightPanorama
local M = {}

function M.new(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "CelestialPresentation"
	folder:SetAttribute("VisualOnly", true)
	folder.Parent = parent
	folder:SetAttribute("SunTextureLoaded",false)
	folder:SetAttribute("MoonTextureLoaded",false)
	local oldSky = Lighting:FindFirstChildOfClass("Sky")
	local sky: Sky = oldSky or Instance.new("Sky")
	local ownedSky = oldSky == nil
	local oldSunSize, oldMoonSize = sky.SunAngularSize, sky.MoonAngularSize
	local oldStars = sky.StarCount
	folder:SetAttribute("PresentationBuild","5.1-opaque-night-overlap")
	sky.Parent = Lighting
	local destroyed = false
	
	local dome: MeshPart? = nil

	local editable: EditableMesh? = nil
 local seamEditable:EditableMesh?=nil
 local seamDome:MeshPart?=nil
	local skyImage: EditableImage? = nil

	local function body(name: string, texture: string, degrees: number, fallback: Color3): (Part, ImageLabel?, BillboardGui?)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Ball
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = fallback
		local diameter = 2*Config.BodyDistance*math.tan(math.rad(degrees)*0.5)
		p.Size = Vector3.one*diameter
		p.Parent = folder
		if texture == "" then return p, nil, nil end
		p.Transparency = 1
		local gui = Instance.new("BillboardGui")
		gui.Name = "CelestialTexture"
		gui.Size = UDim2.fromScale(diameter,diameter)
		gui.AlwaysOnTop = false -- terrain/rocks can occlude it
		gui.LightInfluence = 0
		gui.Adornee = p
		gui.Parent = p
		local label = Instance.new("ImageLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1,1)
		label.Image = texture
		label.Parent = gui
		folder:SetAttribute(name.."ImageStatus","Loading")
		task.spawn(function()
			local fetched = false
			local ok, problem = pcall(function(): boolean
				ContentProvider:PreloadAsync({label},function(_id: string,status: Enum.AssetFetchStatus)
					fetched = status == Enum.AssetFetchStatus.Success
				end)
				return true
			end)
			if destroyed then return end
			folder:SetAttribute(name.."ImageStatus",if ok and fetched then "Loaded" else "Failed")
			if not ok then warn("[CI Sky] "..name..": "..tostring(problem)) end
		end)
		return p, label, gui
	end
	local sun, sunImage, sunGui = body("Sun",Config.SunTexture,Config.SunAngularDegrees,Color3.fromRGB(255,240,209))
	local moon, moonImage, moonGui = body("FullMoon",Config.MoonTexture,Config.MoonAngularDegrees,Color3.fromRGB(207,221,240))
	sky.SunAngularSize, sky.MoonAngularSize = 0, 0 -- preserve native star rendering

	-- One static UV sphere, built once. Never rebuild texture/mesh per frame.
	if NightImage ~= "" then
		task.spawn(function()
			local pendingMesh: EditableMesh? = nil
			local pendingPart: MeshPart? = nil
			local ok, problem = pcall(function(): boolean
				local probe = Instance.new("ImageLabel")
				probe.Image = NightImage
				local fetched = false
				local preloadOK, preloadError = pcall(function(): boolean
					ContentProvider:PreloadAsync({probe},function(_id: string,status: Enum.AssetFetchStatus)
						fetched = status == Enum.AssetFetchStatus.Success
					end)
					return true
				end)
				probe:Destroy()
				if destroyed then return false end
				assert(preloadOK,tostring(preloadError))
				assert(fetched,"Sky panorama image could not load")
                -- Direct texture assets keep uploaded resolution and avoid EditableImage permissions.
                -- Linear longitude preserves proportions; the opaque base has no alpha hole.
                
                folder:SetAttribute("SkySeamMode","OpaqueBase_OverlappingTexture")
				local mesh = AssetService:CreateEditableMesh()
				assert(mesh ~= nil, "Sky mesh memory budget unavailable")
				pendingMesh = mesh
				local vertices: {number}, uvs: {number}, normals: {number}, colors: {number} = {}, {}, {}, {}
				local columns, rows = 96, 48
				for row = 0, rows do
					local v = row/rows
					-- Avoid zero-area pole triangles while keeping a tiny imperceptible cap.
					local polar = math.clamp(v*math.pi,0.0001,math.pi-0.0001)
					for col = 0, columns do
						local u = col/columns
						local phi = if col == columns then 0 else u*math.pi*2
						table.insert(vertices,mesh:AddVertex(Vector3.new(math.sin(polar)*math.cos(phi),math.cos(polar),math.sin(polar)*math.sin(phi))*Config.SkyRadius))
						local textureU = u
                        table.insert(colors,mesh:AddColor(Color3.new(1,1,1),1))
						table.insert(uvs,mesh:AddUV(Vector2.new(textureU,v)))
						table.insert(normals,mesh:AddNormal(-Vector3.new(math.sin(polar)*math.cos(phi),math.cos(polar),math.sin(polar)*math.sin(phi))))
					end
				end
				local function triangle(a: number,b: number,c: number)
					local face = mesh:AddTriangle(vertices[a],vertices[b],vertices[c])
					mesh:SetFaceUVs(face,{uvs[a],uvs[b],uvs[c]})
                    mesh:SetFaceColors(face,{colors[a],colors[b],colors[c]})
					mesh:SetFaceNormals(face,{normals[a],normals[b],normals[c]})
				end
				for row = 0, rows-1 do
					for col = 0, columns-1 do
						local a = row*(columns+1)+col+1
						local b = a+columns+1
						triangle(a,b,a+1)
						triangle(a+1,b,b+1)
					end
				end
				local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh),{CollisionFidelity=Enum.CollisionFidelity.Box})
				pendingPart = part
				if destroyed then return false end
				part.Name = "NightSkyPanorama"
                part.Color = Color3.new(1,1,1)
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
				part.DoubleSided = true
				part.Material = Enum.Material.Neon
				if skyImage then part.TextureContent = Content.fromObject(skyImage) else part.TextureID = NightImage end
				part.Transparency = 1 -- first update sets position and visibility together
				part.Parent = folder
				dome, editable = part, mesh

                -- Cross-blend opposite texture edges across the join, over
                -- an opaque base. Never reveal the black native sky through the join.
                local seamOK,seamError=pcall(function()
                    local cover=AssetService:CreateEditableMesh()
                    assert(cover,"Seam mesh budget unavailable")
                    seamEditable=cover
                    -- Full spherical bounds match the base mesh, avoiding any
                    -- off-center MeshPart placement for a narrow sector mesh.
                    local columns2,rows2=96,48
                    local width=.045
                    local ids:{number},uv:{number},alpha:{number}={},{},{}
                    for row=0,rows2 do
                        local v=row/rows2
                        local polar=math.clamp(v*math.pi,.0001,math.pi-.0001)
                        for col=0,columns2 do
                            local u=col/columns2
                            local phi=if col==columns2 then 0 else u*math.pi*2
                            table.insert(ids,cover:AddVertex(Vector3.new(math.sin(polar)*math.cos(phi),math.cos(polar),math.sin(polar)*math.sin(phi))*Config.SkyRadius*.992))
                            table.insert(uv,cover:AddUV(Vector2.new(1-u,v)))
                            local weight=1-math.clamp(math.min(u,1-u)/width,0,1)
                            table.insert(alpha,cover:AddColor(Color3.new(1,1,1),.5*weight*weight*(3-2*weight)))
                        end
                    end
                    local function face(a:number,b:number,c:number)
                        local f=cover:AddTriangle(ids[a],ids[b],ids[c])
                        cover:SetFaceUVs(f,{uv[a],uv[b],uv[c]})
                        cover:SetFaceColors(f,{alpha[a],alpha[b],alpha[c]})
                    end
                    for row=0,rows2-1 do for col=0,columns2-1 do
                        local a=row*(columns2+1)+col+1;local b=a+columns2+1
                        face(a,b,a+1);face(a+1,b,b+1)
                    end end
                    local overlay=AssetService:CreateMeshPartAsync(Content.fromObject(cover),{CollisionFidelity=Enum.CollisionFidelity.Box})
                    if destroyed then overlay:Destroy();return end
                    overlay.Name="NightSeamOverlap";overlay.Anchored=true
                    overlay.CanCollide=false;overlay.CanQuery=false;overlay.CanTouch=false;overlay.CastShadow=false
                    overlay.DoubleSided=true;overlay.Material=Enum.Material.Neon;overlay.Color=Color3.new(1,1,1)
                    overlay.TextureID=NightImage;overlay.Transparency=1;overlay.Parent=folder;seamDome=overlay
                end)
                folder:SetAttribute("SeamOverlapLoaded",seamOK)
                if not seamOK then
                    if seamEditable then seamEditable:Destroy();seamEditable=nil end
                    warn("[CI Sky] Seam overlap unavailable: "..tostring(seamError))
                end

				pendingPart, pendingMesh = nil, nil
				folder:SetAttribute("SkyMode","NativeDay_LinearNight")
                folder:SetAttribute("NightSkyLoaded",true)
				return true
			end)
			if pendingPart then pendingPart:Destroy() end
			if pendingMesh then pendingMesh:Destroy() end
			if not ok and skyImage then skyImage:Destroy(); skyImage = nil end
			if not ok and not destroyed then
				folder:SetAttribute("SkyMode","NativeFallback")
				warn("[CI Sky] Native sky retained: "..tostring(problem))
			end
		end)
	else
		folder:SetAttribute("SkyMode","NativeFallback_NoImageID")
	end

	local function update()
		if destroyed then return end
		local camera = Workspace.CurrentCamera
		if camera == nil then return end
		local origin = camera.CFrame.Position
		local sunDir, moonDir = Lighting:GetSunDirection(), Lighting:GetMoonDirection()
		-- Hide decorative celestial sprites underwater: they do not receive volumetric fog.
		local wet = math.clamp((-origin.Y)/1.2,0,1)
		local sunVisibility = math.clamp((sunDir.Y+0.015)/0.035,0,1)*(1-wet)
		local moonVisibility = math.clamp((moonDir.Y+0.015)/0.035,0,1)*(1-wet)
		sun.Position = origin+sunDir*Config.BodyDistance
		moon.Position = origin+moonDir*Config.BodyDistance
		local sunTint = Color3.fromRGB(255,150,91):Lerp(Color3.new(1,1,1),math.clamp(sunDir.Y/0.3,0,1))
		local hasSun = sunImage ~= nil and sunImage.IsLoaded
		local hasMoon = moonImage ~= nil and moonImage.IsLoaded
		-- These are diagnostics, not toggles. Restore truth if edited during Play.
		if folder:GetAttribute("SunTextureLoaded") ~= hasSun then folder:SetAttribute("SunTextureLoaded",hasSun) end
		if folder:GetAttribute("MoonTextureLoaded") ~= hasMoon then folder:SetAttribute("MoonTextureLoaded",hasMoon) end
		if sunImage and hasSun then
			sun.Transparency = 1
			sunImage.ImageTransparency = 1-sunVisibility
			sunImage.ImageColor3 = sunTint
		else
			if sunImage then sunImage.ImageTransparency = 1 end
			sun.Transparency = 1-sunVisibility
			sun.Color = sunTint
		end
		if moonImage and hasMoon then
			moon.Transparency = 1
			moonImage.ImageTransparency = 1-moonVisibility
		else
			if moonImage then moonImage.ImageTransparency = 1 end
			moon.Transparency = 1-moonVisibility
		end
		if sunGui then sunGui.Enabled = sunVisibility > 0 end
		if moonGui then moonGui.Enabled = moonVisibility > 0 end
        if dome then
            local amount=1-math.clamp((sunDir.Y+.12)/.20,0,1)
            amount=amount*amount*(3-2*amount)
            dome.Position=origin
			dome.Color=Color3.fromRGB(180,185,195)
            dome.Transparency=1-amount*(1-wet)
            if seamDome then
                local opacity=1-dome.Transparency
                seamDome.Position=origin
                -- Correct alpha composition even while the base fades at twilight.
                seamDome.Transparency=1-(2*opacity/(1+opacity))
            end
            sky.StarCount=if amount>.05 then 0 else oldStars
        else
            sky.StarCount=math.max(oldStars,1800)
        end
	end
	return {Update=update, Destroy=function()
		if destroyed then return end
		destroyed = true
		folder:Destroy()
		if editable then editable:Destroy() end
        if seamEditable then seamEditable:Destroy() end
		if skyImage then skyImage:Destroy(); skyImage = nil end
		if ownedSky then sky:Destroy() else
			sky.SunAngularSize, sky.MoonAngularSize = oldSunSize, oldMoonSize
			sky.StarCount = oldStars
		end
	end}
end
return M

