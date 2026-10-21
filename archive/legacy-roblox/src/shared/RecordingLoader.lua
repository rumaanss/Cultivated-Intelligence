--!strict
-- Generated recording modules have runtime names, so Studio cannot statically
-- resolve their require paths. Keep that dynamic boundary explicit and validate
-- its result before any JSON parsing or schema validation.
local loadModule = require :: (ModuleScript) -> unknown
local M = {}
function M.read(module: ModuleScript, maximumBytes: number): string
 assert(maximumBytes > 0 and maximumBytes%1 == 0, "Invalid recording size limit")
 local value = loadModule(module)
 assert(type(value) == "string", "Recording module must return JSON text")
 assert(#value <= maximumBytes, "Recording module exceeds its byte budget")
 return value
end
return M

