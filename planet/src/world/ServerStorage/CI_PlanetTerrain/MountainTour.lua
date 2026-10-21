-- Camera-only helpers. No terrain or gameplay changes.
local C=require(script.Parent.CaveData)
local T={}
local function vector(p) return Vector3.new(p[1],p[3],-p[2]) end
local function editOnly() assert(not game:GetService('RunService'):IsRunning(),'Use Edit mode') end
function T.ApplyPalette()
    editOnly()
    local palette={
        Grass={94,112,69},Ground={112,91,68},Rock={111,115,116},
        Slate={81,87,93},Limestone={151,143,127},Snow={225,232,235},Sand={166,154,123},
    }
    for name,rgb in pairs(palette) do workspace.Terrain:SetMaterialColor(Enum.Material[name],Color3.fromRGB(rgb[1],rgb[2],rgb[3])) end
end
function T.Cave(index)
    editOnly()
    local cave=assert(C.caves[index or 1],'Cave index must be 1 through 10')
    local a,b=vector(cave.segments[1].a),vector(cave.segments[1].b)
    local up=b.Unit
    workspace.CurrentCamera.CFrame=CFrame.lookAt(a+(a-b).Unit*18+up*5,b,up)
    return {id=cave.id,longitude=cave.entranceLonLat[1],latitude=cave.entranceLonLat[2]}
end
function T.Range(index)
    editOnly()
    local cave=assert(C.caves[index or 1],'Range index must be 1 through 10')
    local a,b=vector(cave.segments[1].a),vector(cave.segments[1].b)
    local forward=(b-a).Unit;local up=b.Unit
    workspace.CurrentCamera.CFrame=CFrame.lookAt(b-forward*360+up*200,b+forward*130,up)
    return cave.id
end
return table.freeze(T)
