--!strict
-- Studio-only comparison. Never used as the C++ simulation's physical water.
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local terrainInstance = Workspace:FindFirstChildOfClass("Terrain")
assert(terrainInstance ~= nil and terrainInstance:IsA("Terrain"), "Workspace Terrain is unavailable")
local terrain: Terrain = terrainInstance
local Config = require(script.Parent.WaterRendererConfig)
local Presentation = require(script.Parent.WaterPresentationConfig)
type Materials = {{{Enum.Material}}}
type Occupancy = {{{number}}}
local M = {}
function M.new(width: number,length: number,depth: number,surfaceY: number)
	-- Round inward to the 4-stud voxel grid. Never extend outside the simulation.
	local halfX, halfZ = math.floor(width/8)*4, math.floor(length/8)*4
	local top = math.floor(surfaceY/4)*4
	local bottom = math.ceil((surfaceY-depth)/4)*4
	assert(halfX>=4 and halfZ>=4 and top>bottom,"Basin too small for native comparison")
	local region = Region3.new(Vector3.new(-halfX,bottom,-halfZ),Vector3.new(halfX,top,halfZ))
	local active = false
	local savedMaterials: Materials? = nil
	local savedOccupancy: Occupancy? = nil
	local old = {color=terrain.WaterColor,transparency=terrain.WaterTransparency,
		reflectance=terrain.WaterReflectance,waveSize=terrain.WaterWaveSize,waveSpeed=terrain.WaterWaveSpeed}
	local function safe(): (boolean,string)
		-- One scan on activation only. Native water must not drive unanchored bodies here.
		for _, item in Workspace:GetDescendants() do
			if item:IsA("BasePart") and not item.Anchored and not item:IsDescendantOf(terrain) then
				local p, r = item.Position,item.Size.Magnitude/2
				if math.abs(p.X)<halfX+r and math.abs(p.Z)<halfZ+r and p.Y+r>bottom and p.Y-r<top+1 then
					return false,"Native comparison blocked by unanchored body: "..item:GetFullName()
				end
			end
		end
		return true,""
	end
	local function disable()
		if not active then return end
		local materials, occupancy = terrain:ReadVoxels(region,4)
		local previousMaterials, previousOccupancy = savedMaterials,savedOccupancy
		if previousMaterials and previousOccupancy then
			-- Restore only cells that still hold this comparison's full water value.
			-- Preserve unrelated edits made since activation.
			for x, slab in materials do for y, row in slab do for z, material in row do
				if material==Enum.Material.Water and occupancy[x][y][z]==1 then
					materials[x][y][z]=previousMaterials[x][y][z]
					occupancy[x][y][z]=previousOccupancy[x][y][z]
				end
			end end end
			terrain:WriteVoxels(region,4,materials,occupancy)
		end
		terrain.WaterColor=old.color
		terrain.WaterTransparency=old.transparency
		terrain.WaterReflectance=old.reflectance
		terrain.WaterWaveSize=old.waveSize
		terrain.WaterWaveSpeed=old.waveSpeed
		active=false
		savedMaterials,savedOccupancy=nil,nil
	end
	local function enable(): (boolean,string)
		if active then return true,"" end
		if not RunService:IsStudio() then return false,"Native comparison is Studio-only" end
		local permitted,reason=safe()
		if not permitted then return false,reason end
		local materials, occupancy = terrain:ReadVoxels(region,4)
		for x,slab in materials do for y,row in slab do for z,material in row do
			if material~=Enum.Material.Air or occupancy[x][y][z]>0 then
				return false,"Native comparison requires empty Terrain voxels inside this basin; existing terrain was preserved"
			end
		end end end
		savedMaterials,savedOccupancy=materials,occupancy
		local waterMaterials: Materials = {}
		local waterOccupancy: Occupancy = {}
		for x,slab in materials do
			waterMaterials[x]={};waterOccupancy[x]={}
			for y,row in slab do
				waterMaterials[x][y]={};waterOccupancy[x][y]={}
				for z in row do waterMaterials[x][y][z]=Enum.Material.Water;waterOccupancy[x][y][z]=1 end
			end
		end
		old={color=terrain.WaterColor,transparency=terrain.WaterTransparency,
			reflectance=terrain.WaterReflectance,waveSize=terrain.WaterWaveSize,waveSpeed=terrain.WaterWaveSpeed}
		active=true -- permits rollback if a subsequent operation errors
		local ok,problem=pcall(function(): boolean
			terrain:WriteVoxels(region,4,waterMaterials,waterOccupancy)
			terrain.WaterColor=Presentation.SurfaceColor
			terrain.WaterTransparency=Config.NativeTransparency
			terrain.WaterReflectance=Config.NativeReflectance
			terrain.WaterWaveSize=Config.NativeWaveSize
			terrain.WaterWaveSpeed=Config.NativeWaveSpeed
			return true
		end)
		if not ok then disable();return false,tostring(problem) end
		return true,""
	end
	return {Enable=enable,Disable=disable,Destroy=disable,CheckSafe=safe,
		Width=halfX*2,Length=halfZ*2,SurfaceY=top}
end
return M

