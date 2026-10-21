#include "cybernet/simulation/live_bridge.hpp"
#include "cybernet/world/lake_geometry_generated.hpp"
#include <stdexcept>
#include <fstream>
#include <iostream>
#include <iomanip>
#include <future>

namespace cybernet {
struct LiveBridgeTestAccess {
 static std::unique_lock<std::mutex> holdQueue(LiveBridge& bridge) {
  return std::unique_lock<std::mutex>(bridge.mutex_);
 }
};
}
#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif
#define CHECK(expression) do { if (!(expression)) { \
 throw std::runtime_error(std::string("line ")+std::to_string(__LINE__)+": "+#expression); \
} } while(false)
void stage(const char* text){std::cerr<<"[LiveBridgeTests] "<<text<<std::endl;}
using namespace cybernet;
using namespace std::chrono_literals;
std::string read(const std::filesystem::path& p){
#ifdef _WIN32
 const HANDLE h=CreateFileW(p.c_str(),GENERIC_READ,
  FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,nullptr,OPEN_EXISTING,
  FILE_ATTRIBUTE_NORMAL,nullptr);
 if(h==INVALID_HANDLE_VALUE){
  const auto code=GetLastError();
  if(code==ERROR_FILE_NOT_FOUND||code==ERROR_PATH_NOT_FOUND)return {};
  throw std::runtime_error("Test read open failed: "+p.string()+"; Windows error "+std::to_string(code));
 }
 struct Close {HANDLE h;~Close(){CloseHandle(h);}} close{h};
 std::string value(LiveBridge::MaxBytes+1,'\0');DWORD count=0;
 if(!ReadFile(h,value.data(),static_cast<DWORD>(value.size()),&count,nullptr))
  throw std::runtime_error("Test read failed; Windows error "+std::to_string(GetLastError()));
 CHECK(count<=LiveBridge::MaxBytes);value.resize(count);return value;
#else
 std::ifstream f(p);return {std::istreambuf_iterator<char>(f),{}};
#endif
}
template<class F> bool until(F f,std::chrono::milliseconds timeout=5000ms){
 const auto deadline=std::chrono::steady_clock::now()+timeout;
 while(std::chrono::steady_clock::now()<deadline){if(f())return true;std::this_thread::sleep_for(10ms);}
 return false;
}
int main(int argc,char**argv) try {
 stage("initialize terrain and publisher");
 GeometryWorld terrain(lake_geometry::Objects,lake_geometry::BodyRadius,lake_geometry::Planes);
 auto directory=std::filesystem::temp_directory_path()/std::filesystem::path("ci-live-test-"+std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()));
 if(argc==2)directory=argv[1];
 if(argc!=2){
  stage("one-shot snapshot survives queue contention");
  LiveBridge bridge(directory/"queue-contention",42);
  auto queueLock=LiveBridgeTestAccess::holdQueue(bridge);
  std::promise<void> started;
  auto ready=started.get_future();
  auto capture=std::async(std::launch::async,[&]{
   started.set_value();
   bridge.capture(731,{},std::span<const Organism>{});
  });
  ready.wait();
  const auto duringContention=capture.wait_for(200ms);
  // Release before assertions so a failed check cannot deadlock future cleanup.
  queueLock.unlock();
  capture.get();
  CHECK(duringContention==std::future_status::timeout);
  CHECK(until([&]{return read(directory/"queue-contention/snapshot.json").find("\"tick\":731,")!=std::string::npos;}));
 }
 std::vector<Organism> population(1);auto& o=population[0];o.id=1;o.configureSpecies(OrganismType::Bacterivore);o.position={50,50,40};
 {
 LiveBridge bridge(directory,42);bridge.capture(0,{},population);
 stage("wait for initial snapshot");
 CHECK(until([&]{return std::filesystem::exists(directory/"snapshot.json");}));
 CHECK(!bridge.beginTick(population,terrain));
 // Fixture mode for an actual Python HTTP exchange integration test.
 if(argc==2){
  for(unsigned tick=1;tick<=60;++tick){if(bridge.beginTick(population,terrain))bridge.capture(tick,{},population);std::this_thread::sleep_for(50ms);}
  return 0;
 }
 stage("exclusive publisher lock");
 bool locked=false;try{LiveBridge duplicate(directory,42);}catch(const std::exception&){locked=true;}CHECK(locked);
 auto input=[&](unsigned batch,std::string events){return "CIINPUT1 "+bridge.runId()+" session-a "+std::to_string(batch)+" 1 1 "+(events.empty()?"0":"1")+"\n1 "+std::to_string(batch==1?51:52)+" 50 40 .1 0 0\n1 1 55 50 40 2 100\n"+events;};
 stage("first input and damage acknowledgment");
 #ifdef _WIN32
 // Reproduce the reader's sharing violation with a deliberately exclusive writer.
 {
  const auto path=directory/"input.txt";const auto text=input(1,"1 1 1 1 35\n");
  HANDLE writer=CreateFileW(path.c_str(),GENERIC_WRITE,0,nullptr,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);
  CHECK(writer!=INVALID_HANDLE_VALUE);DWORD written=0;
  const bool wrote=WriteFile(writer,text.data(),static_cast<DWORD>(text.size()),&written,nullptr)!=0;
  std::this_thread::sleep_for(75ms);CloseHandle(writer);
  CHECK(wrote&&written==text.size());
 }
#else
 LiveBridge::atomicWrite(directory/"input.txt",input(1,"1 1 1 1 35\n"));
#endif
 CHECK(until([&]{return bridge.beginTick(population,terrain);}));CHECK(o.health==65&&o.position.x==51&&bridge.acknowledgedEvent()==1);CHECK(bridge.actors().size()==1&&bridge.geometry());
 for(int i=0;i<10;++i){CHECK(bridge.beginTick(population,terrain));}
 CHECK(o.health==65);
 stage("duplicate event in a newly received batch");
 LiveBridge::atomicWrite(directory/"input.txt",input(2,"1 1 1 1 35\n"));
 CHECK(until([&]{return bridge.beginTick(population,terrain)&&o.position.x==52;}));
 CHECK(o.health==65&&bridge.acknowledgedEvent()==1);
 stage("reject event gap before the two-second stale cutoff");
 LiveBridge::atomicWrite(directory/"input.txt",input(3,"3 1 1 1 35\n"));
 CHECK(until([&]{return !bridge.beginTick(population,terrain);},1000ms));
 CHECK(o.health==65&&bridge.acknowledgedEvent()==1);
 stage("valid lethal event after rejected gap");
 LiveBridge::atomicWrite(directory/"input.txt",input(4,"2 1 1 1 100\n"));CHECK(until([&]{return bridge.beginTick(population,terrain)&&bridge.acknowledgedEvent()==2;}));CHECK(!o.alive());
 stage("malformed input rejection");
 for(auto bad:{"CIINPUT1 a b 1 10001 0 0", "CIINPUT1 a b 1 0 1 0\n1 1 1 1 1 9 100", "CIINPUT1 a b 1 0 0 1\n1 1 1 1 nan", "CIINPUT1 a b 1 0 0 0 junk"}){bool rejected=false;try{LiveBridge::parseInput(bad);}catch(const std::exception&){rejected=true;}CHECK(rejected);}
 stage("stale input pause");
 std::this_thread::sleep_for(3100ms);CHECK(!bridge.beginTick(population,terrain));
 CHECK(until([&]{return read(directory/"bridge_status.json").find("stale-input")!=std::string::npos;}));
 stage("new heartbeat resumes after stale input without replaying damage");
 LiveBridge::atomicWrite(directory/"input.txt",input(5,"2 1 1 1 100\n"));
 CHECK(until([&]{return bridge.beginTick(population,terrain);}));
 CHECK(bridge.acknowledgedEvent()==2);
 CHECK(until([&]{return read(directory/"bridge_status.json").find("\"status\":\"running\"")!=std::string::npos;}));
 CHECK(read(directory/"bridge_status.json").find("\"publishedUtcMs\":")!=std::string::npos);
 CHECK(read(directory/"bridge_status.json").find("\"boot\":")!=std::string::npos);
 stage("final snapshot and clean shutdown");
 bridge.capture(5,{},population);CHECK(until([&]{return read(directory/"snapshot.json").find("\"tick\":5")!=std::string::npos;}));
 }
 CHECK(read(directory/"snapshot.json").find("\"state\":\"stopped\"")!=std::string::npos);
 stage("cross-engine lakebed contact rounding and penetration rejection");
 {
  LiveBridge bridge(directory/"precision",42);
  std::vector<Organism> agents(3);
  agents[0].id=1292;agents[1].id=1530;agents[2].id=1783;
  agents[0].position=agents[1].position=agents[2].position={50,50,40};
  const std::array<Vec3,3> contacts{{{64.71993255615234F,93.5111083984375F,0},{75.1860122680664F,48.79301071166992F,0},{52.0289F,97.3673F,0}}};
  auto contact=[&](int batch,bool invalid){
   std::ostringstream out;out<<std::setprecision(17)<<"CIINPUT1 "<<bridge.runId()<<" precision "<<batch<<" 3 0 0\n";
   for(unsigned i=0;i<contacts.size();++i){auto point=contacts[i];point.z=terrain.floorHeight(point.x,point.y,terrain.bodyRadius())-.00001F;
    if(invalid&&i==0)point.z-=5;
    out<<agents[i].id<<' '<<point.x<<' '<<point.y<<' '<<point.z<<" 0 0 0\n";
   }return out.str();
  };
  LiveBridge::atomicWrite(directory/"precision/input.txt",contact(1,false));
  CHECK(until([&]{return bridge.beginTick(agents,terrain);}));
  CHECK(terrain.clear(agents[0].position)&&terrain.clear(agents[1].position));
  const auto before=agents[0].position;
  CHECK(std::abs(before.z-terrain.floorHeight(contacts[0].x,contacts[0].y,terrain.bodyRadius()))<.001F);
  LiveBridge::atomicWrite(directory/"precision/input.txt",contact(2,true));
  CHECK(until([&]{return bridge.beginTick(agents,terrain)&&agents[0].liveQuarantined;},1000ms));
  CHECK(!agents[1].liveQuarantined&&!agents[2].liveQuarantined);
  const float energy=agents[0].energy;LifecycleAction action{};
  bridge.movement(agents[0],action);CHECK(agents[0].energy==energy);
  bridge.capture(51,{},agents);
  CHECK(until([&]{return read(directory/"precision/snapshot.json").find("\"corrections\":[[1,1,1292,")!=std::string::npos;}));
  // A stale in-flight valid pose must not unquarantine before correction acknowledgment.
  LiveBridge::atomicWrite(directory/"precision/input.txt",contact(3,false));
  std::this_thread::sleep_for(40ms);CHECK(bridge.beginTick(agents,terrain));CHECK(agents[0].liveQuarantined);
  LiveBridge::atomicWrite(directory/"precision/input.txt",contact(4,false)+"ACKCORRECTIONS 1\n");
  CHECK(until([&]{return bridge.beginTick(agents,terrain)&&!agents[0].liveQuarantined;}));
  CHECK(terrain.clear(agents[0].position));
  CHECK((agents[0].position-before).lengthSquared()==0);
  stage("out-of-bounds actor recovery does not stop healthy agents");
  auto actorInput="CIINPUT1 "+bridge.runId()+" precision 5 0 1 0\n1 1 -5 50 -3 2 100\nACKCORRECTIONS 1\n";
  LiveBridge::atomicWrite(directory/"precision/input.txt",actorInput);
  CHECK(until([&]{return bridge.beginTick(agents,terrain)&&bridge.actors().size()==1;}));
  CHECK(bridge.actors()[0].position.x>=2.5F);
  CHECK(bridge.actors()[0].position.z>=terrain.floorHeight(2.5F,50,2));
 }
 std::filesystem::remove_all(directory);std::cout<<"PASS live ownership, atomic publisher, event dedup/gaps, bounds, stale pause, lock\n";
}
catch(const std::exception& error){std::cerr<<"[LiveBridgeTests] FAIL: "<<error.what()<<std::endl;return 1;}
catch(...){std::cerr<<"[LiveBridgeTests] FAIL: unknown exception"<<std::endl;return 1;}
