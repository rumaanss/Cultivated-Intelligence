--!nonstrict
local Contract=require(script.Parent.PlanetContract)
local Frame=require(script.Parent.HabitatFrame)
local h=Contract.habitat
local function v(a)return Vector3.new(a[1],a[2],a[3])end
local f={center=v(h.frame.center),radius=h.frame.radius,up=v(h.frame.up),east=v(h.frame.east),north=v(h.frame.north)}
local M={Bounds={width=Contract.bounds[1],length=Contract.bounds[2],depth=Contract.bounds[3]}}
function M.configure(bounds)for i=1,3 do assert(bounds[i]==Contract.bounds[i],"Wrong habitat bounds")end end
function M.toRobloxXYZ(x,y,z)return Frame.toWorld(f,Vector3.new(x+h.origin[1],y+h.origin[2],z-h.depth))end
function M.toRoblox(p)return M.toRobloxXYZ(p.x,p.y,p.z)end
function M.toSimulation(p)
 local q=Frame.fromWorld(f,p);if not q then return nil end
 return {x=q.X-h.origin[1],y=q.Y-h.origin[2],z=q.Z+h.depth}
end
function M.plantPosition(p)return Frame.toWorld(f,Vector3.new(p[1],p[3],p[2]))end
function M.plantFrame(p)return Frame.orientation(f,Vector3.new(p[1],p[3],p[2]))end
function M.isWithinBounds(p)return p.x>=0 and p.y>=0 and p.z>=0 and p.x<=Contract.bounds[1] and p.y<=Contract.bounds[2] and p.z<=Contract.bounds[3]end
return M
