"""Optional developer checks; Python is not needed to run the ecosystem."""
import argparse,subprocess,tempfile,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--luau',required=True);p.add_argument('--native-packet',type=Path);a=p.parse_args()
here=Path(__file__).resolve().parent;shared=here.parent/'src/biology/shared'
subprocess.run([a.luau,str(here/'aquatic_assertions.lua')],check=True)
protocol='local Stage3Protocol=(function()\n'+(shared/'Stage3Protocol.lua').read_text()+'\nend)()\n'
protocol+='local Protocol=(function()\n'+(shared/'AquaticProtocol.lua').read_text().replace('require(script.Parent.Stage3Protocol)','Stage3Protocol')+'\nend)()\n'
client=(here.parent/'src/biology/client/Aquatic.client.lua').read_text()
for name,module in [('Space','SimulationSpace'),('Protocol','AquaticProtocol'),('Models','AquaticModels'),('Stage3','Stage3Models')]:
 client=client.replace('require(RS.CI_Biology.'+module+')',name)
designs='local designs=(function()\n'+(shared/'AgentDesignData.lua').read_text()+'\nend)()\n'
factory='local Factory=(function()\n'+(shared/'AgentModelFactory.lua').read_text().replace('require(script.Parent.AgentDesignData)','designs')+'\nend)()\n'
model=(shared/'AquaticModels.lua').read_text()
for name,module in [('Factory','AgentModelFactory'),('Space','SimulationSpace'),('Contract','PlanetContract')]:
 model=model.replace('require(script.Parent.'+module+')',name)
models=designs+factory+'local Models=(function()\n'+model+'\nend)()\n'
stage3=(shared/'Stage3Models.lua').read_text().replace('require(script.Parent.Stage3MeshData)','Stage3Data').replace('require(script.Parent.SimulationSpace)','Space')
models+='local Stage3Data=(function()\n'+(shared/'Stage3MeshData.lua').read_text()+'\nend)()\nlocal Stage3=(function()\n'+stage3+'\nend)()\n'
assertions=(here/'aquatic_render_assertions.lua').read_text().replace('CLIENT_SOURCE_PLACEHOLDER',models+'do\n'+client+'\nend')
def lua(v):
 if isinstance(v,dict):return '{'+','.join('['+json.dumps(k)+']='+lua(x) for k,x in v.items())+'}'
 if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
 if v is None:return 'nil'
 return json.dumps(v)
replay=''
if a.native_packet:
 packet=json.loads(a.native_packet.read_text());packet['token']='replay'
 replay='local native='+lua(packet)+"\n"+r'''
local replay=Protocol.near(native,{100,100,90},24);Protocol.validate(replay,replay.run);event.OnClientEvent:Fire(replay);assert(#tags>0 and #tags<=38)
if replay.model=="stage3-1" then
 local seen={};local persistent={};local parts=0
 for _,m in tags do
  seen[m:GetAttribute("CI_Species")]=true;persistent[m:GetAttribute("CI_ColonyId")]=m
  if string.sub(m.Name,1,7)=="Stage3_" then for _,p in m:GetDescendants()do if p:IsA("BasePart")then parts+=1 end end end
 end
 for _,name in {"Bacterial grazer","Microalgal grazer","Ribbon algae","Fan algae","Filament algae","Sheet algae"}do assert(seen[name],"Missing native model: "..name)end
 assert(parts<=2800,"Stage3 part budget")
 event.OnClientEvent:Fire(replay);for _,m in tags do assert(persistent[m:GetAttribute("CI_ColonyId")]==m,"Repeated packet rebuilt identity")end
 local bad=table.clone(replay);bad.food=table.clone(replay.food);table.insert(bad.food,bad.food[1]);assert(not pcall(Protocol.validate,bad,bad.run),"Duplicate food cell accepted")
 bad=table.clone(replay);bad.algae=table.clone(replay.algae);bad.algae[1]=table.clone(bad.algae[1]);bad.algae[1][3]=table.clone(bad.algae[1][3]);bad.algae[1][3][1]=table.clone(bad.algae[1][3][1]);bad.algae[1][3][1][4]+=1;assert(not pcall(Protocol.validate,bad,bad.run),"Unpaid tissue accepted")
 now+=6;assert(coroutine.resume(tasks[1]));assert(#tags==0,"Stage3 stale cleanup")
 event.OnClientEvent:Fire(replay);assert(#tags>0)
 local parent
 for _,m in tags do if m:GetAttribute("CI_TotalSegments")then parent=m;break end end
 assert(parent,"No visible algae parent")
 local id=parent:GetAttribute("CI_ColonyId");local birth=table.clone(replay);birth.colonies=table.clone(replay.colonies);birth.algae=table.clone(replay.algae);birth.revision+=20;birth.population+=1;birth.events=table.clone(replay.events);birth.events[1]+=1;birth.budget=table.clone(replay.budget);birth.budget.endTick=birth.revision
 local child
 for i,r in birth.colonies do if r[3]==id then local p=table.clone(r);p[8]*=.5;birth.colonies[i]=p;child=table.clone(p);child[3]=900000;child[4]=id;child[6]+=1;child[7]=0;break end end
 for i,r in birth.algae do if r[2]==id then local shape={r[1],r[2],{}};for _,n in r[3]do local node=table.clone(n);node[4]*=.5;table.insert(shape[3],node)end;birth.algae[i]=shape;table.insert(birth.algae,{r[1],child[3],{{1,0,birth.revision,child[8],1,1,0}}});break end end
 table.insert(birth.colonies,child);Protocol.validate(birth,birth.run);event.OnClientEvent:Fire(birth)
 local found=false;for _,m in tags do if m:GetAttribute("CI_ColonyId")==child[3]then assert(m:GetAttribute("CI_ParentId")==id and m:GetAttribute("CI_Lifecycle")=="New offspring");found=true end end
 assert(found and parent.Parent~=nil,"Native offspring must remain visible with its parent")
 print("PASS Stage3 actual packet: both grazers, four habitats, stable identities, bounded parts, parent/offspring visibility, invalid tissue/food rejection and stale cleanup")
end
event.OnClientEvent:Fire({clear=true});assert(#tags==0)
'''

assertions=assertions.replace('NATIVE_REPLAY_PLACEHOLDER',replay)
code=(here/'mock_runtime.lua').read_text()+'\n'+protocol+assertions
with tempfile.TemporaryDirectory() as tmp:
 path=Path(tmp)/'aquatic-render.lua';path.write_text(code)
 subprocess.run([a.luau,str(path)],check=True)
