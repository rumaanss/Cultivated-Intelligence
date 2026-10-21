#include "cybernet/world/island_world.hpp"
#include "cybernet/simulation/live_checkpoint.hpp"
#include <iostream>
#include <fstream>
#include "cybernet/simulation/plant_publisher_lock.hpp"
#include <chrono>
#include <stdexcept>
using namespace cybernet;
void check(bool ok,const char* why){if(!ok)throw std::runtime_error(why);}
std::string habitat(){std::ostringstream s;s<<"CIPLANTSURFACE1 island-test 46 30 -576 -512 32\n";for(int z=0;z<30;++z)for(int x=0;x<46;++x){double wx=-576+(x+.5)*32,wz=-512+(z+.5)*32;bool land=std::abs(wx)>60||std::abs(wz)>60;s<<(land?12:-56)<<" 8 20 8 "<<land<<'\n';}return s.str();}
int main(int argc,char** argv){
 IslandWorld world(250);world.initialize(habitat());check(world.biology.plants.size()==96,"founders");
 if(argc>1){std::ofstream out(argv[1]);out<<world.snapshot(0);check(bool(out),"write integration fixture");}
 ChemistryField chemistry;CelestialCycle light;light.setOpticalModel(OpticalModel::OpticsV2);world.bind(chemistry,light);
 for(auto& p:world.biology.plants){check(p.position.y>0,"land only");check(p.policy==plants::Policy::Neural,"neural policy");check(p.organs.size()==4,"initial phenotype");p.policy=plants::Policy::Wait;}
 const double conserved=chemistry.atmosphericCarbon()+world.biology.carbonTotal();
 for(unsigned tick=1;tick<=150;++tick){light.update(int(tick));world.step(tick,chemistry,light);}
 check(world.biology.tick==50,"one world clock");
 check(std::abs(conserved-chemistry.atmosphericCarbon()-world.biology.carbonTotal())<1e-6,"plant-air carbon conservation");
 for(auto& p:world.biology.plants)check(p.organs.size()==4&&!p.job.active,"eligibility must not force growth");
 check(light.optics().sampleLight({1000,1000,80}).photosynthetic>.99,"air not underwater attenuation");
 check(light.optics().sampleLight({50,50,5}).photosynthetic<light.optics().sampleLight({50,50,59}).photosynthetic,"pond depth attenuation");
 LiveCheckpoint c;c.run="island-test";c.rng="test";c.tick=150;c.chemistry=chemistry;c.island=world.biology.checkpoint();
 auto restored=LiveCheckpoint::decode(c.encode());check(restored.island==c.island&&restored.chemistry.sameState(chemistry),"unified checkpoint");
 IslandWorld replay(1);replay.restore(restored.island);CelestialCycle replayLight;replayLight.setOpticalModel(OpticalModel::OpticsV2);replay.bind(restored.chemistry,replayLight);
 for(unsigned t=151;t<=240;++t){light.update(int(t));replayLight.update(int(t));world.step(t,chemistry,light);replay.step(t,restored.chemistry,replayLight);}
 check(world.biology.checkpoint()==replay.biology.checkpoint()&&chemistry.sameState(restored.chemistry),"deterministic whole-world replay");
 auto damaged=c.encode();damaged.back()^=1;bool rejected=false;try{LiveCheckpoint::decode(damaged);}catch(...){rejected=true;}check(rejected,"corruption rejected");
 IslandWorld invalid(1);rejected=false;auto bad=habitat();bad.replace(bad.find("-576"),4,"-575");try{invalid.initialize(bad);}catch(...){rejected=true;}check(rejected,"wrong bounds rejected");
 auto& seed=world.biology.plants[0];auto center=seed.position;auto sim=IslandWorld::toPond(center);check(std::abs(IslandWorld::toIsland(sim).x-center.x)<1e-4,"coordinates round trip");
 // Rain-driven mineral transport must reach the local pond, with matching soil debit.
 IslandWorld drainage(4);drainage.initialize(habitat(),0);ChemistryField drainageChem;CelestialCycle drainageLight;drainageLight.setOpticalModel(OpticalModel::OpticsV2);drainage.bind(drainageChem,drainageLight);
 unsigned wet=drainage.biology.cell({-48,12,-80});drainage.biology.surface.cells[wet].water+=10;drainage.biology.ledger.initialWater+=10;
 const double beforeMinerals=drainageChem.summary().averagePhosphate;
 drainageLight.update(3);drainage.step(3,drainageChem,drainageLight);
 check(drainageChem.summary().averagePhosphate>beforeMinerals,"runoff enters pond chemistry");
 check(drainage.biology.ledger.nutrientInput<0,"soil records mineral export");
 // Shared canopy shades biological light queries, not just Roblox rendering.
 auto leaf=world.biology.plants.front().position;float shaded=world.transmission(IslandWorld::toPond(leaf));check(shaded<1,"shared canopy shade");
 const auto temp=std::filesystem::temp_directory_path()/("ci-island-lock-"+std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()));std::filesystem::create_directory(temp);
 {PlantPublisherLock lock(temp);bool blocked=false;try{PlantPublisherLock second(temp);}catch(...){blocked=true;}check(blocked,"exclusive plant writer");}
 {PlantPublisherLock again(temp);}std::filesystem::remove_all(temp);
 std::cout<<"PASS island bounds, land founders, distinct neural policy, shared clock, air-water optics, carbon exchange, wait autonomy, unified checkpoint and deterministic replay\n";
}
