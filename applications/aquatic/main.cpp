#include "cybernet/aquatic/lake.hpp"
#include "cybernet/simulation/live_bridge.hpp"
#include "cybernet/world/planet_geometry_generated.hpp"
#include "native_server.hpp"
#include "json.hpp"
#include <chrono>
#include <csignal>
#include <fstream>
#include <iostream>
#include <thread>
#ifdef _WIN32
#include <windows.h>
#endif
namespace {volatile std::sig_atomic_t running=1;void stop(int){running=0;}
#ifdef _WIN32
BOOL WINAPI consoleEvent(DWORD e){if(e==CTRL_C_EVENT||e==CTRL_BREAK_EVENT||e==CTRL_CLOSE_EVENT){running=0;return TRUE;}return FALSE;}
#endif
}
int main(int argc,char** argv){
 using namespace cybernet;using namespace std::chrono;
 try {
  auto options=transport::parseArguments(argc,argv);
  std::uint64_t seed=42,stopTick=2147483000;bool newWorld=false;
  for(std::size_t i=1;i<options.arguments.size();++i){std::string a=options.arguments[i];
   auto value=[&](){if(++i>=options.arguments.size())throw std::runtime_error("Missing value for "+a);return std::string(options.arguments[i]);};
   if(a=="--seed")seed=std::stoull(value());else if(a=="--ticks")stopTick=std::stoull(value());else if(a=="--new-world")newWorld=true;
   else if(a=="--live-dir")value();else throw std::runtime_error("Unknown aquatic option: "+a);
  }
  if(stopTick>=2147483647)throw std::runtime_error("Stop tick exceeds protocol limit");
  auto path=options.runtime/"aquatic.checkpoint.json";
  if(std::filesystem::exists(options.runtime/"checkpoint.bin"))throw std::runtime_error("Legacy biology runtime: choose a separate aquatic runtime.");
  // Acquire the existing native publisher lock before reading or writing durable state.
  LiveBridge bridge(options.runtime,seed,true,true);
  aquatic::Lake lake(seed);
  if(std::filesystem::exists(path)){
   if(newWorld)throw std::runtime_error("Aquatic runtime already exists. Omit --new-world to resume, or choose another directory.");
   if(std::filesystem::file_size(path)>4*1024*1024)throw std::runtime_error("Aquatic checkpoint too large");
   std::ifstream f(path);std::string text{std::istreambuf_iterator<char>(f),{}};lake=aquatic::Lake::restore(text,seed);
  }else if(!newWorld)throw std::runtime_error("No aquatic checkpoint. Explicitly use --new-world for founders.");
  LiveBridge::atomicWrite(path,lake.checkpoint());
  std::signal(SIGINT,stop);std::signal(SIGTERM,stop);
#ifdef _WIN32
  SetConsoleCtrlHandler(consoleEvent,TRUE);
#endif
  GeometryWorld geometry(planet_geometry::Objects,.25F,{},&planet_geometry::Field,{planet_contract::Width,planet_contract::Length,planet_contract::Depth});
  std::vector<Organism> empty;CelestialCycle sky(aquatic::Lake::CycleTicks);
  sky.update(static_cast<int>(lake.tick));bridge.beginTick(empty,geometry);bridge.capture(static_cast<unsigned>(lake.tick),sky.state(),empty);
  auto plants=[&](){return nlohmann::json{{"schema",1},{"run",bridge.runId()},{"revision",lake.tick},{"tick",lake.tick},{"units","studs-Y-up"},{"surface",planet_contract::Surface},{"plants",nlohmann::json::array()}}.dump();};
  bridge.publishPlants(plants());
  transport::NativeServer server(bridge,options);server.publishAquatic(lake.snapshot(bridge.runId()));
  std::cout<<"[CI Aquatic] Non-neural producers/decomposers; "<<lake.cells.size()<<" water cells; seed "<<seed<<"; restored tick "<<lake.tick<<"\n"
   <<"[CI Aquatic] Autonomous, 20 ticks/s; 600 ticks per biological day. Ctrl+C saves. Existing land runtime retained.\n"<<std::flush;
  double phases[6]={};auto next=steady_clock::now(),published=next,saved=next;
  while(running&&lake.tick<stopTick){
   auto began=steady_clock::now();
   if(!bridge.beginTick(empty,geometry))throw std::runtime_error("Native publisher unhealthy");
   lake.step();sky.update(static_cast<int>(lake.tick));bridge.capture(static_cast<unsigned>(lake.tick),sky.state(),empty);
   if(steady_clock::now()-published>=seconds(1)){
    lake.validate();server.publishAquatic(lake.snapshot(bridge.runId()));bridge.publishPlants(plants());published=steady_clock::now();
   }
   if(steady_clock::now()-saved>=seconds(30)){LiveBridge::atomicWrite(path,lake.checkpoint());saved=steady_clock::now();}
   double ms=duration<double,std::milli>(steady_clock::now()-began).count();phases[0]+=ms/1000;server.recordTick(static_cast<unsigned>(lake.tick),ms,phases);
   if(!options.unpaced){next+=milliseconds(50);std::this_thread::sleep_until(next);if(steady_clock::now()-next>milliseconds(250))next=steady_clock::now();}
  }
  LiveBridge::atomicWrite(path,lake.checkpoint());std::cout<<"[CI Aquatic] Saved tick "<<lake.tick<<"; C/N/P and oxygen ledgers verified.\n";
  return 0;
 }catch(const std::exception& e){std::cerr<<"[CI Aquatic] "<<e.what()<<"\n";return 1;}
}
