--!strict
-- Optional binary body-pose payload; NOT a replacement for existing live snapshots.
-- Full pose: 20-byte header + 2 bytes per joint. Transport must scope packets to run ID.
local Contract=require(script.Parent.AgentBodyContract)
local M={}
local MAGIC=0x31425043 -- CPB1 in little endian
local function uint(n:number,max:number):boolean return n==n and n>=0 and n<=max and n%1==0 end
local function design(id:number):any
 for _,d in Contract.designs do if d.id==id then return d end end
 return nil
end
function M.encode(agentId:number,tick:number,designId:number,angles:{number}):buffer
 local d=design(designId);assert(d~=nil,"Unknown body design")
 assert(uint(agentId,4294967295) and uint(tick,4294967295),"IDs/ticks must fit uint32")
 assert(#angles==#d.components,"Expected full component pose")
 local b=buffer.create(20+2*#angles)
 buffer.writeu32(b,0,MAGIC);buffer.writeu16(b,4,Contract.version);buffer.writeu16(b,6,designId)
 buffer.writeu32(b,8,agentId);buffer.writeu32(b,12,tick);buffer.writeu16(b,16,#angles)
 for i,a in angles do
  assert(a==a and math.abs(a)<=math.pi,"Joint angle out of range")
  local q=a*32767/math.pi
  buffer.writei16(b,18+2*i,if q>=0 then math.floor(q+.5) else math.ceil(q-.5))
 end
 return b
end
function M.decode(b:buffer):any
 if buffer.len(b)<20 then return nil,"Truncated header" end
 if buffer.readu32(b,0)~=MAGIC or buffer.readu16(b,4)~=Contract.version then return nil,"Unsupported schema" end
 local id=buffer.readu16(b,6);local d=design(id);local count=buffer.readu16(b,16)
 if not d or count~=#d.components or buffer.len(b)~=20+2*count or buffer.readu16(b,18)~=0 then return nil,"Invalid shape" end
 local angles={}
 for i=1,count do
  local q=buffer.readi16(b,18+2*i);if q==-32768 then return nil,"Invalid angle" end
  angles[i]=q*math.pi/32767
 end
 return {agentId=buffer.readu32(b,8),tick=buffer.readu32(b,12),designId=id,angles=angles},nil
end
return M
