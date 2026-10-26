#include "cybernet/aquatic/inspection.hpp"
#include "cybernet/world/planet_contract_generated.hpp"
#include "json.hpp"
#include <iostream>
#include <fstream>
#include <chrono>
using namespace cybernet::aquatic::stage3;
using J=nlohmann::json;
void check(bool b,const char*s){if(!b)throw std::runtime_error(s);}
template<class F> void reject(F f){bool failed=false;try{f();}catch(const std::exception&){failed=true;}check(failed,"Expected rejection");}
int main(){auto root=std::filesystem::temp_directory_path()/("ci-inspection-"+std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()));std::filesystem::create_directories(root);
try {
 { // Destroy all Inspection replay readers before removing their fixtures.
 Physiology w(42);for(int i=0;i<100;++i)w.step();
 auto initial=w.checkpoint();Inspection service("test-run","boot-a","scene",root);service.publish(w);
 auto query=[&](J q){q["schema"]=1;return J::parse(service.request("/inspection",q.dump()));};
 auto sense=[&](J q){q["schema"]=1;return J::parse(service.request("/sensing",q.dump()));};
 check(query({{"run","other"},{"id",1}}).at("reset"),"Wrong run reset");
 auto r=query({{"run","test-run"},{"id",w.colonies.front().id}});check(r["individual"]["biological"]=="alive","Native alive identity");
 check(query({{"run","test-run"},{"id",2000000}})["individual"]["biological"]=="unknown","Unknown not dead");
 reject([&]{query({{"run","test-run"},{"id",-1}});});reject([&]{query({{"run","test-run"},{"id",1},{"limit",65}});});
 auto request=J{{"run","test-run"},{"boot","boot-a"},{"host","roblox-server"}};
 for(int batch=0;batch<3;++batch){
  auto tick=w.environment.tick;check(!service.prepare(w),"Scene feed must pause");check(w.environment.tick==tick,"No biological time spent waiting");
  auto s=sense(request);auto p=s.at("pending");check(p["points"].size()==w.environment.cells.size()/2,"Complete column coverage");
  J v={{"schema",1},{"run","test-run"},{"boot","boot-a"},{"request",p["request"]},{"tick",p["tick"]},{"habitat",p["habitat"]},{"optics","surface-par-1"},{"scene","scene-1"},{"visibility",J::array()},{"geometry",{{"passed",true}}}};
  for(auto&point:p["points"])v["visibility"].push_back(batch==1?0.:1.);
  auto bad=request;bad["observation"]=v;bad["observation"]["boot"]="old";reject([&]{sense(bad);});
  bad["observation"]=v;bad["observation"]["visibility"].erase(0);reject([&]{sense(bad);});
  bad["observation"]=v;bad["observation"]["visibility"][0]=2;reject([&]{sense(bad);});
  auto q=request;q["observation"]=v;auto ack=sense(q);check(ack["accepted"]==p["request"],"Scene acceptance");
  check(sense(q)["accepted"]==p["request"],"Same request idempotent before application");
  q["observation"]["visibility"][0]=.4;reject([&]{sense(q);});
  for(int i=0;i<10;++i){check(service.prepare(w),"Accepted observation did not advance");w.step();w.validate();}
  service.publish(w);
 }
 auto selected=query({{"run","test-run"},{"id",w.colonies.front().id}});
 auto probe=selected.at("probeRequest");probe["depthStuds"]=J::array();for(int i=0;i<16;++i)probe["depthStuds"].push_back(64.);
 auto sensor=request;sensor["probe"]=probe;auto unchanged=w.checkpoint();
 check(sense(sensor)["probeAccepted"]==probe["id"],"Native-pose diagnostic accepted");
 check(query({{"run","test-run"},{"id",probe["id"]}}).contains("probe"),"Diagnostic returned through native inspector");
 check(w.checkpoint()==unchanged,"Diagnostic must not grant biological actions or materials");
 sensor["probe"]["position"][0]=9999;reject([&]{sense(sensor);});
 auto replayWorld=Physiology::restore(initial,42);Inspection replay("replay-run","boot-b","replay",root,root/"scene-observations-boot-a.jsonl");replay.publish(replayWorld);
 for(int i=0;i<30;++i){check(replay.prepare(replayWorld),"Replay advance");replayWorld.step();}
 check(w.checkpoint()==replayWorld.checkpoint(),"Recorded observations must reproduce exact biological state");
 auto middle=Physiology::restore(initial,42);Inspection first("mid-run","mid-boot","replay",root,root/"scene-observations-boot-a.jsonl");first.publish(middle);
 for(int i=0;i<5;++i){check(first.prepare(middle),"Replay initial interval");middle.step();}
 auto continued=Physiology::restore(middle.checkpoint(),42);Inspection second("mid-run","new-boot","replay",root,root/"scene-observations-boot-a.jsonl");second.publish(continued);
 for(int i=0;i<25;++i){check(second.prepare(continued),"Replay checkpoint inside interval");continued.step();}
 check(w.checkpoint()==continued.checkpoint(),"Replay resumes within a recorded interval");
 reject([&]{replay.prepare(replayWorld);});
 auto native=Physiology::restore(initial,42),open=native,shade=native;open.sceneTransmission.assign(open.environment.cells.size()/2,1);shade.sceneTransmission.assign(shade.environment.cells.size()/2,.15);
 for(int i=0;i<100;++i){native.step();open.step();shade.step();}native.validate();open.validate();shade.validate();
 check(native.environment.cumulative.production==open.environment.cumulative.production,"Open scene must retain reference photosynthesis");
 check(shade.environment.cumulative.production<open.environment.cumulative.production,"Shade must reduce fixation");
 check(shade.environment.cumulative.incidentPhotons<open.environment.cumulative.incidentPhotons,"Occlusion in photon ledger");
 // Durable death/offspring recovery after the live presentation window expires.
 for(int i=0;i<800;++i)w.step();service.publish(w);
 std::uint64_t dead=0,parent=0;for(auto&a:w.ancestry){if(a.died)dead=a.id;if(a.parent)parent=a.parent;}
 check(dead&&parent,"Fixture must include deaths and offspring");
 auto d=query({{"run","test-run"},{"id",dead}});check(d["individual"]["biological"]=="confirmed dead"&&d["individual"]["events"].size()==2,"Durable tombstone and lifecycle");
 auto child=query({{"run","test-run"},{"id",parent},{"limit",1}});check(child["children"].size()==1&&child["children"][0]["parent"]==parent,"Bounded child page");
 auto saved=Physiology::restore(w.checkpoint(),42);Inspection resumed("test-run","new-boot","native-reference",root);resumed.publish(saved);
 auto q=J{{"schema",1},{"run","test-run"},{"id",dead}};check(J::parse(resumed.request("/inspection",q.dump()))["individual"]==d["individual"],"Death retained through checkpoint/restart");
 } // Replay ifstreams are closed here, including on Windows.
 std::filesystem::remove_all(root);std::cout<<"PASS identity, tombstones, bounded pages, validation, shade ledgers, exact recorded replay, restart\n";return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<" (fixtures "<<root<<")\n";return 1;}}
