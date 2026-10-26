--!nonstrict
-- Manual experiment only. Never takes over the player's camera or feeds biology.
if not game:GetService("RunService"):IsStudio() or workspace:GetAttribute("CI_RunPixelCapabilityProbe")~=true then return end
local Http=game:GetService("HttpService")
local result={schema=1,studio=version(),context="client",independentCamera=false,biologicalInput=false,started=os.clock()}
local finished=false
local function report()
 if finished then return end;finished=true;result.elapsedMs=(os.clock()-result.started)*1000;result.started=nil
 print("CI_PIXEL_CAPABILITY "..Http:JSONEncode(result))
end
local ok,err=pcall(function()
 game:GetService("CaptureService"):CaptureScreenshot(function(contentId)
  if finished then return end;result.capture=true
  local image=nil
  local success,why=pcall(function()
   image=game:GetService("AssetService"):CreateEditableImageAsync(Content.fromUri(contentId))
   assert(image,"No editable image (allocation/permission/format)")
   result.width=image.Size.X;result.height=image.Size.Y
   local pixels=image:ReadPixelsBuffer(Vector2.zero,Vector2.new(1,1))
   result.readable=buffer.len(pixels)==4
  end)
  if image then image:Destroy()end
  if not success then result.error=tostring(why)end
  result.conclusion="Main-view capture experiment only; independent organism framebuffer not established"
  report()
 end)
end)
if not ok then result.error=tostring(err);report()end
task.delay(15,function()if not finished then result.error="Capture callback timed out";report()end end)
