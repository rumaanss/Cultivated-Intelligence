#include "cybernet/world/island_world.hpp"
#include <stdexcept>
#include <iostream>
using namespace cybernet;
void require(bool ok,const char* why){if(!ok)throw std::runtime_error(why);}
std::string habitat(){std::ostringstream s;s<<"CIPLANTSURFACE1 survival-fixture 46 30 -576 -512 32\n";for(int z=0;z<30;++z)for(int x=0;x<46;++x){bool land=std::abs(-576+(x+.5)*32)>110||std::abs(-512+(z+.5)*32)>100;s<<(land?12:-56)<<" 8 20 8 "<<land<<'\n';}return s.str();}
int main(){
 for(unsigned seed:{42,250,731}){
  IslandWorld w(seed);w.initialize(habitat());ChemistryField chemistry;CelestialCycle light;
  light.setOpticalModel(OpticalModel::OpticsV2);w.bind(chemistry,light);
  auto&p=w.biology.plants.front();p.carbon=3.4;
  require(!w.biology.request(p,plants::Action::Shoot,2,2),"construction spent night reserve");
  require(p.decision.result=="night-reserve","reserve rejection reason");
  double carbon=chemistry.atmosphericCarbon()+w.biology.carbonTotal();
  for(unsigned tick=1;tick<=30000;++tick){light.update(tick);w.step(tick,chemistry,light);}
  unsigned alive=0;for(auto&plant:w.biology.plants){if(plant.stage!=2)++alive;require(plant.policy==plants::Policy::Neural,"policy changed");}
  require(alive>0,"producer extinction");
  require(std::abs(carbon-chemistry.atmosphericCarbon()-w.biology.carbonTotal())<1e-4,"carbon conservation");
  std::cout<<"seed "<<seed<<": "<<alive<<" living plants at world tick 30000\n";
 }
 plants::World drought(1);auto& p=drought.founder(0,{0,0,0},plants::Policy::Wait);
 p.water=0;drought.rainfall=0;for(auto&c:drought.surface.cells)c.water=0;
 for(unsigned i=0;i<50;++i)drought.step();
 require(p.stage==2,"drought mortality disabled");
 std::cout<<"PASS reserves, 50 cycles, neural autonomy, carbon accounting, drought mortality\n";
}
