--!strict
local S = {}
function S.finite(x: number): boolean return x == x and math.abs(x) < math.huge end
function S.alpha(rate: number, dt: number): number return 1 - math.exp(-rate * math.max(0, dt)) end
function S.wrap(a: number): number return (a + math.pi) % (2 * math.pi) - math.pi end
function S.jumpSpeed(g: number, height: number): number
 assert(g > 0 and height >= 0, "Invalid jump tuning")
 return math.sqrt(2 * g * height)
end
function S.axes(x: number, y: number): (number, number)
 local length = math.sqrt(x*x + y*y)
 if length > 1 then return x/length, y/length end
 return x,y
end
return table.freeze(S)
