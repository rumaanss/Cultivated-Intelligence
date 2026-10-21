--!strict
local AssetService = game:GetService("AssetService")
local Workspace = game:GetService("Workspace")
local Config = require(script.Parent.WaterPresentationConfig)
local Presentation = require(script.Parent.WaterPresentationMath)
local Waves = require(script.Parent.WaterWaveMath)

type Vertex = { id: number, normal: number, uv: number, x: number, z: number }
export type Options = { Width: number, Length: number, SurfaceY: number, Reference: boolean? }
export type Handle = { Update: (number) -> (), Height: (number, number) -> number, Destroy: () -> (), SetVisible: (boolean) -> (), SetTime: (number) -> () }
local Field = require(script.Parent.LakeWaveField)
local Renderer = require(script.Parent.WaterRendererConfig)
local M = {}
local LiveScene=require(script.Parent.LiveScene)
local Shoreline=require(script.Parent.PondShoreline)
local Geometry=require(script.Parent.SharedGeometry)
local Lakebed=require(script.Parent.LakebedPresentation)
local NativeWater=require(script.Parent.PondNativeWater)

local function decorate(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Color = Config.SurfaceColor
	part.Material = Enum.Material.Glass
	part.Transparency = Config.SurfaceTransparency
	part.Reflectance = math.min(Config.SurfaceReflectance,0.045) -- restrain broad cubemap blocks; moon glint is directional
end

function M.new(parent: Instance, options: Options): Handle
	local visible = true
	local reference = options.Reference == true
 local manifest=LiveScene.get()
 local scene=if manifest then manifest.geometry else nil
 local pond=if scene and scene.terrain and scene.terrain.heightfield then scene else nil
 local shore=if pond then Shoreline.triangles(pond) else nil
 local restoreWater=if pond then NativeWater.suspend(options.Width,options.Length,pond.bounds[3]) else function() end
	local function sample(x: number, z: number, seconds: number): (number, number, number)
		if not reference then
   local y,dx,dz=Field.sample(x,z,seconds,options.Width,options.Length,Renderer.Amplitude,Renderer.Speed)
   if pond then
    local depth=pond.bounds[3]-Geometry.floorHeight(pond,x+pond.bounds[1]/2,z+pond.bounds[2]/2,0)
    local fade=math.clamp(depth/4,0,1)
    y,dx,dz=y*fade,dx*fade,dz*fade
   end
   return y,dx,dz
  end
  local y,dx,dz=Waves.sample(x,z,seconds,Config.WaveAmplitudeScale,Config.WaveSpeedScale)
  local tx,dtx=Presentation.envelope(x,options.Width-2*Config.EdgeWaveFadeStuds,Config.EdgeWaveFadeStuds)
  local tz,dtz=Presentation.envelope(z,options.Length-2*Config.EdgeWaveFadeStuds,Config.EdgeWaveFadeStuds)
  return y*tx*tz,dx*tx*tz+y*dtx*tz,dz*tx*tz+y*tx*dtz
 end
 local destroyed = false
	local elapsed, accumulated = 0, 0
	local averageDt, slowSeconds, fastSeconds = 1 / 60, 0, 0
	local throttled = false
	local editable: EditableMesh? = nil
	local meshPart: MeshPart? = nil
	local vertices: { Vertex } = {}
	local fallback = Instance.new("Part")
	fallback.Name = "WaterSurfaceFallback"
	fallback.Size = Vector3.new(options.Width+2*Config.VisualPaddingStuds, 0.12, options.Length+2*Config.VisualPaddingStuds)
	fallback.Position = Vector3.new(0, options.SurfaceY - 0.06, 0)
	decorate(fallback)
	local fallbackRoot=Instance.new("Folder");fallbackRoot.Name="WaterSurfaceFallback";fallbackRoot.Parent=parent
 if shore and pond then
  local rectangles,edges=Shoreline.fallback(pond,shore)
  for _,r in rectangles do
   local part=Instance.new("Part");part.Name="WaterStrip"
   part.Size=Vector3.new(r[3],0.12,r[4]);part.Position=Vector3.new(r[1]+r[3]/2,options.SurfaceY-.06,r[2]+r[4]/2)
   decorate(part);part.Parent=fallbackRoot
  end
  for id,face in edges do
   Lakebed.triangle(face[1]+Vector3.yAxis*options.SurfaceY,face[2]+Vector3.yAxis*options.SurfaceY,face[3]+Vector3.yAxis*options.SurfaceY,fallbackRoot,id,Enum.Material.Glass,Config.SurfaceColor)
  end
  for _,part in fallbackRoot:GetChildren() do if part:IsA("BasePart") then decorate(part) end end
  fallback:Destroy()
 else fallback.Parent=fallbackRoot end
	parent:SetAttribute("SurfaceMode", "Initializing")
	parent:SetAttribute("MaterialMode", "GlassWater")

	local function height(x: number, z: number): number
		if meshPart == nil then return options.SurfaceY end
		local y = sample(x,z,elapsed)
		return options.SurfaceY + y
	end

	-- Only startup yields. An immediate fallback keeps the basin usable while assets prepare.
	task.spawn(function()
		if destroyed then return end
		if not Config.EnableEditableMesh then
			parent:SetAttribute("SurfaceMode", "StaticFallback")
			return
		end
		local pendingMesh: EditableMesh? = nil
		local pendingPart: MeshPart? = nil
		local ok, reason = pcall(function(): boolean
			local em = AssetService:CreateEditableMesh()
			assert(em ~= nil, "EditableMesh allocation denied or memory budget exhausted")
			pendingMesh = em
			local levels: { [string]: number } = { Low = 16, Medium = 24, High = 32, Ultra = 48 }
			local centralCells = if reference then (levels[Config.Quality] or 32) else Renderer.Cells
			local outerCells = Config.OuterCellsPerSide
			local cells = centralCells + 2*outerCells
			local stride = cells + 1
   if shore then
    local cache:{[string]:Vertex}={}
    local function vertex(p:Vector3):Vertex
     local key=string.format("%.6f:%.6f",p.X,p.Z)
     local existing=cache[key];if existing then return existing end
     local y,dx,dz=sample(p.X,p.Z,0)
     local v={id=em:AddVertex(Vector3.new(p.X,y,p.Z)),normal=em:AddNormal(Vector3.new(-dx,1,-dz).Unit),uv=em:AddUV(Vector2.new(p.X/Config.TextureTileStuds,p.Z/Config.TextureTileStuds)),x=p.X,z=p.Z}
     cache[key]=v;table.insert(vertices,v);return v
    end
    for _,face in shore do
     local a,b,c=vertex(face[1]),vertex(face[2]),vertex(face[3])
     local id=em:AddTriangle(a.id,b.id,c.id)
     em:SetFaceNormals(id,{a.normal,b.normal,c.normal});em:SetFaceUVs(id,{a.uv,b.uv,c.uv})
    end
   else
			for row = 0, cells do
				for col = 0, cells do
					local x = -options.Width / 2 + options.Width * col / cells
					local z = -options.Length / 2 + options.Length * row / cells
					local y, dx, dz = sample(x,z,0)
					table.insert(vertices, {
						id = em:AddVertex(Vector3.new(x, y, z)),
						normal = em:AddNormal(Vector3.new(-dx, 1, -dz).Unit),
						uv = em:AddUV(Vector2.new(x / Config.TextureTileStuds, z / Config.TextureTileStuds)),
						x = x, z = z,
					})
				end
			end
			local function triangle(a: Vertex, b: Vertex, c: Vertex)
				local face = em:AddTriangle(a.id, b.id, c.id)
				em:SetFaceNormals(face, { a.normal, b.normal, c.normal })
				em:SetFaceUVs(face, { a.uv, b.uv, c.uv })
			end
			for row = 0, cells - 1 do
				for col = 0, cells - 1 do
					local a = row * stride + col + 1
					local b, c, d = a + 1, a + stride, a + stride + 1
					-- +Y winding. DoubleSided handles the submerged view without extra faces.
					triangle(vertices[a], vertices[c], vertices[b])
					triangle(vertices[b], vertices[c], vertices[d])
				end
			end
   end
			local part = AssetService:CreateMeshPartAsync(Content.fromObject(em), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Automatic,
			})
			pendingPart = part
			if destroyed then return false end
			part.Name = "AnimatedWaterSurface"
			-- Preserve the generated mesh scale; do not flatten Size.Y.
			part.CFrame = CFrame.new(0, options.SurfaceY, 0)
			part.DoubleSided = true
			decorate(part)
			-- Preserve the Glass rendering that looked correct before PBR loaded.
			-- SurfaceAppearance changes that response; do not attach it to this water.
			if destroyed then return false end
			part.Parent = if visible then parent else nil
			editable = em
			meshPart = part
			fallbackRoot:Destroy()
			parent:SetAttribute("SurfaceMode", "AnimatedMesh")
			parent:SetAttribute("SurfaceWidthStuds", options.Width)
			parent:SetAttribute("SurfaceLengthStuds", options.Length)
			parent:SetAttribute("WaterBuild", "5.0-water-lab")
			parent:SetAttribute("VertexCount", #vertices)
			parent:SetAttribute("TriangleCount", cells * cells * 2)
			return true
		end)
		if destroyed or not ok then
			if pendingPart ~= nil then pendingPart:Destroy() end
			if pendingMesh ~= nil then pendingMesh:Destroy() end
			table.clear(vertices)
			if not destroyed then
				parent:SetAttribute("SurfaceMode", "StaticFallback")
				warn("[CI Water] Waves unavailable; using static fallback. Check Mesh/Image API access and memory. " .. tostring(reason))
			end
		end
	end)

	local function update(dt: number)
		if destroyed or dt <= 0 or dt ~= dt or dt == math.huge then return end
		elapsed += dt
		accumulated += dt
		local em, part, camera = editable, meshPart, Workspace.CurrentCamera
		if not visible or em == nil or part == nil or camera == nil then return end
		averageDt += (math.min(dt, 0.1) - averageDt) * (1 - math.exp(-dt / 1.5))
		if Config.AdaptiveUpdateRate then
			if averageDt > 1 / 43 then
				slowSeconds += dt
				fastSeconds = 0
			elseif averageDt < 1 / 55 then
				fastSeconds += dt
				slowSeconds = 0
			else
				slowSeconds = 0
				fastSeconds = 0
			end
			if slowSeconds > 1.5 then throttled = true end
			if fastSeconds > 5 then throttled = false end
		end
		local p = camera.CFrame.Position
		local distance = (p - Vector3.new(0, options.SurfaceY, 0)).Magnitude
		if distance > Config.CullDistanceStuds then return end
		local hz = if throttled or distance > Renderer.FarDistance then Renderer.FarHz else Renderer.NearHz
		if accumulated < 1 / hz then return end
		accumulated %= 1 / hz
		debug.profilebegin("CI:WaterWaves")
		for _, v in vertices do
			local y, dx, dz = sample(v.x,v.z,elapsed)
			em:SetPosition(v.id, Vector3.new(v.x, y, v.z))
			em:SetNormal(v.normal, Vector3.new(-dx, 1, -dz).Unit)
		end
		debug.profileend()
	end

	local function destroy()
		if destroyed then return end
		destroyed = true
  restoreWater()
		if meshPart ~= nil then meshPart:Destroy() end
		if editable ~= nil then editable:Destroy() end
		fallbackRoot:Destroy()
		table.clear(vertices)
	end
	return { Update = update, Height = height, Destroy = destroy,
		SetVisible = function(value: boolean)
			if destroyed then return end
			visible = value
			if meshPart then meshPart.Parent = if value then parent else nil
			else fallbackRoot.Parent = if value then parent else nil end
		end,
		SetTime = function(value: number) elapsed = value; accumulated = 1 end,
	}
end
return M

