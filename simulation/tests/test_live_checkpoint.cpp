#include "cybernet/simulation/live_bridge.hpp"
#include "cybernet/world/lake_geometry_generated.hpp"
#include <fstream>
#include "cybernet/plants/plant_world.hpp"
#include <iostream>
#include <thread>
using namespace cybernet;using namespace std::chrono_literals;
void check(bool v){if(!v)throw std::runtime_error("checkpoint assertion failed");}
std::string read(const std::filesystem::path& p){std::ifstream f(p,std::ios::binary);return {std::istreambuf_iterator<char>(f),{}};}
int main(int argc,char** argv)try{
 if(argc==2){
  ChemistryField chemistry;Random rng(42);std::vector<Organism> population(1);
  population[0].id=1;population[0].configureSpecies(OrganismType::Bacterivore);population[0].position={50,50,40};
  std::uint32_t tick=0,next=2;GeometryWorld terrain(lake_geometry::Objects,lake_geometry::BodyRadius,lake_geometry::Planes);
  LiveBridge bridge(argv[1],42);bridge.restore(population,chemistry,rng,tick,next);
  for(int i=0;i<1000;++i){if(bridge.beginTick(population,terrain))++tick;bridge.checkpoint(population,chemistry,rng,tick,next);bridge.capture(tick,{},population);std::this_thread::sleep_for(10ms);}
  return 0;
 }

 auto dir=std::filesystem::temp_directory_path()/("ci-checkpoint-"+std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()));
 ChemistryField chemistry;Random rng(42);std::vector<Organism> population(2);population[0].id=1;population[1].id=2;
 population[0].position={50,50,40};population[1].position={55,50,40};population[0].initializeBrain();
 (void)rng.uniform_float(0,1);const auto randomBefore=rng.saveState();
 std::uint32_t tick=123,next=3;std::string run;
 plants::World plants(250);plants.founder(0,{0,0,0});const auto savedPlants=plants.checkpoint();
 {
  LiveBridge bridge(dir,42);run=bridge.runId();bridge.checkpoint(population,chemistry,rng,tick,next,&plants);bridge.publishPlants(plants.snapshot());bridge.capture(tick,{},population);
  const auto deadline=std::chrono::steady_clock::now()+3s;
  while(!std::filesystem::exists(dir/"checkpoint.bin")){check(std::chrono::steady_clock::now()<deadline);std::this_thread::sleep_for(10ms);}
 }
 {
  LiveBridge bridge(dir,42);population.clear();tick=0;next=0;rng=Random(7);
  std::string island;check(bridge.restore(population,chemistry,rng,tick,next,&island));check(island==savedPlants);check(bridge.runId()==run&&tick==123&&next==3&&population.size()==2&&rng.saveState()==randomBefore);
  check(population[0].position.z==40&&population[0].brainInitialized);
 }
 check(read(dir/"plants.json")==plants.snapshot());
 // A forced final checkpoint must survive an immediate destructor, including
 // when the writer is already publishing a different snapshot/plant payload.
 for(unsigned attempt=0;attempt<8;++attempt){
  const auto shutdownDir=dir/("shutdown-"+std::to_string(attempt));
  {
   LiveBridge bridge(shutdownDir,42);
   bridge.checkpoint(population,chemistry,rng,1,next);
   bridge.publishPlants("{\"payload\":\""+std::string(1024*1024,'x')+"\"}");
   bridge.capture(1,{},population);
   bridge.checkpoint(population,chemistry,rng,777,next,nullptr,true);
  }
  check(LiveCheckpoint::decode(read(shutdownDir/"checkpoint.bin")).tick==777);
 }

 auto bytes=read(dir/"checkpoint.bin");auto restored=LiveCheckpoint::decode(bytes);check(restored.tick==123);check(restored.encode()==bytes);
 bytes.back()^=1;bool rejected=false;try{(void)LiveCheckpoint::decode(bytes);}catch(...){rejected=true;}check(rejected);
 std::filesystem::remove_all(dir);std::cout<<"PASS full brain/population/chemistry/RNG checkpoint, restart, checksum rejection\n";
}catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
