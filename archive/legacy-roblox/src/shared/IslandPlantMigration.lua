--!strict
-- Explicit edit-mode migration. Trees are archived, never deleted or regenerated.
local M={}
function M.ArchiveTrees()
 assert(game:GetService("RunService"):IsStudio() and not game:GetService("RunService"):IsRunning(),"Stop Play before archiving trees")
 local island=workspace:FindFirstChild("CI_ReferenceIsland")
 assert(island~=nil,"CI_ReferenceIsland is missing")
 local trees=island:FindFirstChild("Woodland")
 if not trees then print("[Island] Decorative woodland already removed");return end
 assert(trees:IsA("Folder"),"Unexpected Woodland object; no changes made")
 local archive=Instance.new("Folder")
 archive.Name="IslandTreeBackup_"..game:GetService("HttpService"):GenerateGUID(false)
 archive.Parent=game:GetService("ServerStorage")
 trees.Parent=archive
 island:SetAttribute("Trees",0)
 island:SetAttribute("LivingPlantWorld",true)
 print("[Island] Decorative trees archived in "..archive:GetFullName()..". Living plants come from the unified C++ world.")
end
return M
