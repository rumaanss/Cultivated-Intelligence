// Explicit scripted action sequence for art review; NOT evidence of evolved intelligence.
#include "cybernet/plants/plant_world.hpp"
#include <fstream>
#include <iostream>
#include <cmath>
#include <stdexcept>
using namespace cybernet::plants;
int main(int argc,char** argv){try{World w(123);w.run="plants-authored-showcase";w.plants.reserve(MaxPlants);
 for(unsigned species=0;species<3;++species){auto& p=w.founder(species,{double(int(species)-1)*14,0,0},Policy::Wait);
  // Disclosed large initial provision for a model-construction fixture, all ledger-accounted.
  w.ledger.founderCarbon+=120-p.carbon;p.carbon=120;w.ledger.initialWater+=100-p.water;p.water=100;w.ledger.nutrientInput+=12-p.nutrients;p.nutrients=12;
  auto act=[&](Action a,unsigned site,double amount,V dir=V{0,1,0}){if(!w.request(p,a,site,amount,dir))throw std::runtime_error(p.decision.result);for(int t=0;t<4;++t)w.step();return p.nextOrgan-1;};
  act(Action::Germinate,0,.5);unsigned trunk=1;act(Action::Thicken,trunk,1.5);
  std::vector<unsigned> levels{trunk};
  unsigned height=species==1?4:species==0?1:3;
  for(unsigned i=0;i<height;++i){trunk=act(Action::Shoot,trunk,species==1?1.1:.65,{.08,1,.02});act(Action::Thicken,trunk,species==1?1.8:.6);levels.push_back(trunk);}
  for(unsigned i=0;i<(species==1?9U:species==0?8U:5U);++i){double angle=i*2.399963;unsigned level=levels[std::min<std::size_t>(levels.size()-1,1+i%(levels.size()-1))];
   auto available=w.candidates(p,Action::Branch);bool found=false;for(auto id:available)if(id==level)found=true;if(!found){if(available.empty())throw std::runtime_error("No branch candidate");level=available[i%available.size()];}
   unsigned branch=act(Action::Branch,level,species==1?.8:species==0?.6:.35,{std::sin(angle),species==1?.5:.3,std::cos(angle)});
   if(species==1){branch=act(Action::Shoot,branch,.6,{std::sin(angle),.6,std::cos(angle)});}
   for(unsigned k=0;k<(species==2?2U:3U);++k){double a=angle+k*2.1;act(Action::Leaf,branch,species==1?1.7:species==0?.6:.4,{std::sin(a),.35,std::cos(a)});}
  }
  for(unsigned i=0;i<3;++i){double a=i*2.1;act(Action::Root,2,.5,{std::sin(a),-.5,std::cos(a)});}
 }
 w.validate();std::ofstream out(argc>1?argv[1]:"plant_showcase.json");out<<w.snapshot();if(!out)throw std::runtime_error("Output failed");std::cout<<"Authored growth fixture: all actions explicit and resources conserved\n";
}catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}}
