--!strict
local Schema=require(script.Parent.RecordingSchema)
local Geometry=require(script.Parent.SharedGeometry)
local M={Stride=24,MaxVisible=1024}
function M.finite(v: any): boolean return type(v)=="number" and v==v and math.abs(v)<math.huge end
function M.integer(v: any,lo: number,hi: number): boolean return M.finite(v) and v%1==0 and v>=lo and v<=hi end
function M.manifest(v: any): Schema.Manifest
 assert(type(v)=="table" and v.schemaVersion==3 and v.geometry~=nil and v.geometry.version==4,"Live bridge requires lake geometry")
 assert(v.motionAuthority=="cpp-v1","Rebuild C++: planet requires native motion authority")
 for _,object in v.geometry.objects do assert(object.shape=="sphere","Live physics currently requires spherical rocks") end
 local copy=table.clone(v)
 copy.frameCount,copy.frameTicks,copy.intervalTicks=1,{0},1
 copy.sourceSha256,copy.stopReason=string.rep("0",64),"completed"
 return Schema.validateManifest(copy)
end
function M.row(r: any,scene: Geometry.Scene): {number}
 assert(type(r)=="table" and #r==25,"Invalid live row")
 for _,x in r do assert(M.finite(x),"Non-finite live row") end
 assert(M.integer(r[1],1,2147483647) and M.integer(r[2],0,2),"Invalid live identity")
 assert(Geometry.clear(scene,r[3],r[4],r[5]),"Body intersects terrain")
 assert(r[9]>=0 and r[18]>=0 and r[18]<=10000 and r[19]>0 and r[19]<=2,"Invalid biological state")
 for i=20,24 do assert(r[i]>=0 and r[i]<=1,"Invalid neural intent") end
 assert(M.integer(r[25],0,999999),"Invalid target")
 return r
end
function M.pack(rows: {{number}}): buffer
 assert(#rows<=M.MaxVisible,"Display budget")
 local b=buffer.create(#rows*M.Stride)
 for i,r in rows do
  local o=(i-1)*M.Stride
  buffer.writeu32(b,o,r[1]);buffer.writeu32(b,o+4,r[2])
  buffer.writef32(b,o+8,r[3]);buffer.writef32(b,o+12,r[4]);buffer.writef32(b,o+16,r[5]);buffer.writef32(b,o+20,r[9])
 end
 return b
end
function M.unpack(b: buffer,scene: Geometry.Scene): {{number}}
 local size=buffer.len(b);assert(size%M.Stride==0 and size<=M.MaxVisible*M.Stride,"Bad display buffer")
 local rows: {{number}}={};local seen: {[number]:boolean}={}
 for offset=0,size-1,M.Stride do
  local id,species=buffer.readu32(b,offset),buffer.readu32(b,offset+4)
  local x,y,z=buffer.readf32(b,offset+8),buffer.readf32(b,offset+12),buffer.readf32(b,offset+16)
  local energy=buffer.readf32(b,offset+20)
  assert(id>0 and not seen[id] and species<=2 and M.finite(energy) and energy>=0,"Bad display identity")
  assert(Geometry.clear(scene,x,y,z),"Invalid displayed position")
  seen[id]=true;table.insert(rows,{id,species,x,y,z,0,0,0,energy})
 end
 return rows
end
return M
