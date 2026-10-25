#include "cybernet/aquatic/physiology.hpp"
#include "json.hpp"
#include <cmath>
#include <fstream>
#include <iostream>
#include <stdexcept>
using namespace cybernet::aquatic;
using J=nlohmann::json;
void check(bool ok,const char* message){if(!ok)throw std::runtime_error(message);}
void equip(Colony &c) {
  for (unsigned k : {unsigned(Sensing),unsigned(Motility)}) {
    double amount=c.structure*.00325;
    c.reserve-=Material{amount,amount*.25,0};c.protein[k]+=amount;
  }
}
int main(int argc,char**argv) {try {
 PhysiologyConfig cfg;cfg.mortalityPerDay=0;
 Physiology light(42,cfg),dark(42,cfg);
 for(auto* w:{&light,&dark})for(auto& c:w->colonies)equip(c);
 auto attached=light.colonies[2].position;
 // Compare the same inherited machinery under an illuminated and a dark field.
 for(int i=0;i<120;++i){light.step(false,true,1);dark.step(false,true,0);}
 light.validate();dark.validate();
 unsigned photo=0,darkPhoto=0;double moved=0,paid=0;
 for(const auto&c:light.colonies){photo+=c.behavior==2;moved+=c.distance;paid+=c.movementRespiration;if(c.guild==1)check(c.distance==0,"Attached colonies moved");}
 for(const auto&c:dark.colonies)darkPhoto+=c.behavior==2;
 check(photo>0 && darkPhoto==0,"Light-directed behavior must respond to local light");
 check(moved>10 && paid>0,"Visible travel must incur carbon oxidation");
 // Food and oxygen responses are tested independently from light.
 Physiology fed(45,cfg),oxygen(45,cfg);
 for(auto *w:{&fed,&oxygen}) {
  for(auto &cell:w->environment.cells) {
   const double desired=(&oxygen==w && cell.layer==1) ? 1.*cell.volume : 250.*cell.volume;
   w->environment.initialOxygen+=desired-cell.m[O2];cell.m[O2]=desired;
   if(w==&fed) {
    double food=(cell.layer==0?500.:.01)*cell.volume;
    double delta=food-cell.m[DOC];cell.m[DOC]=food;
    w->environment.initial.carbon+=delta;w->environment.initial.nitrogen+=delta*Lake::NC;w->environment.initial.phosphorus+=delta*Lake::PC;
   }
  }
  for(auto &c:w->colonies)equip(c);
  w->step(false,true,0);w->validate();
 }
 unsigned foodResponses=0,oxygenResponses=0;
 for(const auto &c:fed.colonies)foodResponses+=c.guild==2 && c.behavior==3;
 for(const auto &c:oxygen.colonies)oxygenResponses+=c.behavior==4;
 check(foodResponses>0 && oxygenResponses>0,"Local food/oxygen responses absent");
 // Exact stochastic continuation includes position, route, decisions and events.
 auto resumed=Physiology::restore(light.checkpoint(),42);
 for(int i=0;i<100;++i){resumed.step();light.step();}
 check(resumed.checkpoint()==light.checkpoint(),"Movement resume diverged");
 // Set a paid motor on an existing route, then remove all oxygen atomically.
 Physiology anoxic(91,cfg);
 for(auto &cell:anoxic.environment.cells){anoxic.environment.initialOxygen-=cell.m[O2];cell.m[O2]=0;}
 auto &c=anoxic.colonies.front();equip(c);c.goal[0]+=.5;c.behavior=1;c.decision=80;
 auto position=c.position;
 anoxic.step(false,true,0);anoxic.validate();
 check(c.position==position && c.movementRespiration==0,"Unpaid active movement in anoxia");
 // Speed must follow paid motor abundance, not a renderer parameter.
 Physiology fast(84,cfg),slow(84,cfg);
 for(auto *w:{&fast,&slow}) {auto &c=w->colonies.front();equip(c);c.goal[0]+=.5;c.behavior=1;c.decision=80;}
 auto &slowColony=slow.colonies.front();double returned=slowColony.protein[Motility]*.5;
 slowColony.protein[Motility]-=returned;slowColony.reserve+=Material{returned,returned*.25,0};
 fast.step(false,true,0);slow.step(false,true,0);fast.validate();slow.validate();
 check(std::abs(fast.colonies.front().distance-2*slow.colonies.front().distance)<1e-9 && fast.colonies.front().distance>0,
       "Paid motor abundance must affect travel speed");
 // Alleles alone cannot give an instant motor or sensory capability.
 Physiology base(82,cfg),mutant(82,cfg);
 mutant.genomes[0].copies[0][Motility]=4;
 base.step(false,true,1,false);mutant.step(false,true,1,false);
 for(unsigned i=0;i<base.colonies.size();++i)
   check(base.colonies[i].position==mutant.colonies[i].position,"Unpaid genetic speed boost");
 // Export a real native packet for the Luau consumer replay test.
 auto packet=J::parse(light.snapshot("behavior-test"));
 check(packet["model"]=="pdnarna-4" && packet["colonies"].size()>0,"Native observation missing");
 for(const auto&r:packet["colonies"]) {
  check(r.size()==39,"Observation width");
  auto id=r[2].get<std::uint64_t>();
  const Colony *actual=nullptr;for(const auto &c:light.colonies)if(c.id==id){actual=&c;break;}
  check(actual && r[3]==actual->parent && r[4]==actual->genome,"Observed identity/lineage mismatch");
  for(unsigned k=0;k<3;++k)check(r[22+k]==actual->position[k],"Observed position differs from biology");
  auto traits=light.expression(actual->genome);
  for(unsigned k=0;k<GeneCount;++k)check(r[31+k]==traits[k],"Observed allele differs from inherited genome");
 }
 if(argc>1){std::ofstream f(argv[1]);f<<packet.dump();}
 std::cout<<"PASS local light response, resource-paid travel, attached immobility, anoxia, inherited expression, exact motion continuation and native observation\n";
} catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}}
