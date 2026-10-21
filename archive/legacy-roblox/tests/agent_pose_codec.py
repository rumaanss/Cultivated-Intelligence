"""Cross-language byte-for-byte fixtures, boundary and corrupt packet tests."""
from pathlib import Path
import tempfile,subprocess,sys,json
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as temp:
 p=Path(temp)
 cpp=r'''
#include "agent_pose_codec.hpp"
#include <iostream>
#include <iomanip>
#include <cassert>
int main(){using namespace ci::body;
 for(const auto& d:designs){Pose p;p.design_id=d.id;p.agent_id=4294967295u;p.tick=123456;
 for(int i=0;i<d.count;++i)p.angles.push_back((i%3-1)*pi);
 auto b=encode(p);Pose q;assert(decode(b,q));assert(q.agent_id==p.agent_id&&q.tick==p.tick&&q.angles==p.angles);
 for(auto x:b){std::cout<<std::hex<<std::setw(2)<<std::setfill('0')<<int(x);}std::cout<<"\n";
 for(size_t n=0;n<b.size();++n){auto bad=b;bad.resize(n);assert(!decode(bad,q));}
 auto bad=b;bad.push_back(0);assert(!decode(bad,q));bad=b;bad[18]=1;assert(!decode(bad,q));bad=b;bad[20]=0;bad[21]=128;assert(!decode(bad,q));
 }}
'''
 (p/'test.cpp').write_text(cpp)
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-I'+str(ROOT/'assets/agents/cpp'),str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 expected=subprocess.check_output([str(p/'test')],text=True).strip().splitlines()
 contract=(ROOT/'src/shared/AgentBodyContract.lua').read_text()
 codec=(ROOT/'src/shared/AgentPoseCodec.lua').read_text().replace('local Contract=require(script.Parent.AgentBodyContract)','')
 lua='local Contract=(function()\n'+contract+'\nend)()\nlocal Codec=(function()\n'+codec+'\nend)()\n'
 lua+='''for _,d in Contract.designs do
 local angles={};for i=1,#d.components do angles[i]=((i-1)%3-1)*math.pi end
 local b=Codec.encode(4294967295,123456,d.id,angles)
 local decoded=Codec.decode(b);assert(decoded and decoded.agentId==4294967295 and decoded.tick==123456)
 local hex="";for i=0,buffer.len(b)-1 do hex..=string.format("%02x",buffer.readu8(b,i)) end;print(hex)
 for n=0,buffer.len(b)-1 do local bad=buffer.create(n);buffer.copy(bad,0,b,0,n);assert(Codec.decode(bad)==nil) end
 buffer.writeu16(b,18,1);assert(Codec.decode(b)==nil)
 for i=1,#angles do angles[i]=.12345 end
 local q=Codec.decode(Codec.encode(1,1,d.id,angles));for _,a in q.angles do assert(math.abs(a-.12345)<=math.pi/65534) end
end
'''
 (p/'test.luau').write_text(lua)
 actual=subprocess.check_output([sys.argv[1],str(p/'test.luau')],text=True).strip().splitlines()
 assert actual==expected,(actual,expected)
 print('PASS: all 6 designs C++/Luau byte-identical, uint32 IDs, angle limits, truncated/reserved/invalid payloads, quantization error <0.00275 degrees')
