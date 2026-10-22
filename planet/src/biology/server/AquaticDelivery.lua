--!nonstrict
local RS=game:GetService("ReplicatedStorage")
local Protocol=require(RS.CI_Biology.AquaticProtocol)
local event=Instance.new("RemoteEvent")
event.Name="CI_AquaticState";event.Parent=RS
local M={token=""}
local cached,received=nil,0
local sent=setmetatable({},{__mode="k"})
function M.clear()
 cached=nil;M.token="";sent=setmetatable({},{__mode="k"})
 event:FireAllClients({clear=true})
end
function M.update(packet,run,observers)
 if packet then
  Protocol.validate(packet,run)
  assert(not cached or packet.run~=cached.run or packet.revision>=cached.revision,"Aquatic revision rollback")
  cached=packet;M.token=packet.token;received=os.clock()
 end
 -- A silent publisher never leaves apparently live biology displayed indefinitely.
 if cached and os.clock()-received>5 then M.clear();return end
 if not cached then return end
 for player,observer in observers do
  if os.clock()-observer.at<5 and (not sent[player] or os.clock()-sent[player]>=1)then
   event:FireClient(player,Protocol.near(cached,observer.region.center))
   sent[player]=os.clock()
  end
 end
end
return M
