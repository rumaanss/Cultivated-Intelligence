--!strict
local F = require(script.Parent.PlanetFrame)
local G = {}
function G.acceleration(position: Vector3, center: Vector3, magnitude: number): Vector3
 return -F.up(position,center)*magnitude
end
function G.create(root: BasePart): VectorForce
 assert(not root:FindFirstChild("CI_Gravity"), "Duplicate gravity force")
 local attachment=Instance.new("Attachment"); attachment.Name="CI_GravityAttachment"; attachment.Parent=root
 local force=Instance.new("VectorForce"); force.Name="CI_Gravity"; force.Attachment0=attachment
 force.ApplyAtCenterOfMass=true; force.RelativeTo=Enum.ActuatorRelativeTo.World; force.Parent=root
 return force
end
function G.update(force: VectorForce, root: BasePart, center: Vector3, magnitude: number)
 -- Anchored AssemblyMass is infinite. Prime only after unanchoring, in the same task.
 if root.Anchored then force.Force=Vector3.zero; return end
 force.Force=G.acceleration(root.Position,center,magnitude)*root.AssemblyMass
end
return table.freeze(G)
