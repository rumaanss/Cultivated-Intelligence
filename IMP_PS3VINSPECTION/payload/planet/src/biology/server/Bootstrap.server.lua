--!nonstrict
-- Starts only biology transport, after the native habitat identity is acknowledged.
local RS=game:GetService("ReplicatedStorage")
local contract=require(RS:WaitForChild("CI_Biology"):WaitForChild("PlanetContract"))
local state=RS:WaitForChild("CI_ResearchTelemetry",180)
if not state then warn("[CI Biology] Missing habitat preflight");return end
local deadline=os.clock()+180
while state:GetAttribute("HabitatState")~="Exported" and os.clock()<deadline do task.wait(.2)end
if state:GetAttribute("HabitatDigest")~=contract.habitat.sha256 then
 state:SetAttribute("BiologyState","Blocked: habitat mismatch");warn("[CI Biology] Native habitat identity must match the compiled contract");return
end
require(script.Parent.PlantsService)()
require(script.Parent.LiveStateService).Start()

require(script.Parent.InspectionService).Start()
