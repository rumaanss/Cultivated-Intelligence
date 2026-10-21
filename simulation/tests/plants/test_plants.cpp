#include "cybernet/plants/plant_world.hpp"
#include <iostream>
#include <cmath>
#include <stdexcept>
using namespace cybernet::plants;
void check(bool b,const char* m){if(!b)throw std::runtime_error(m);}
int main(){try{
 World waiting(7);waiting.founder(0,{0,0,0},Policy::Wait);for(int i=0;i<100;++i)waiting.step();check(waiting.plants[0].organs.empty()&&waiting.plants.size()==1,"Eligibility triggered growth");waiting.validate();
 World viable(8);viable.plants.reserve(MaxPlants);auto& p=viable.founder(0,{0,0,0},Policy::Wait);
 check(!viable.request(p,Action::Seed,0,3),"Seed reproduced");double reserves=p.carbon;p.carbon=0;check(!viable.request(p,Action::Germinate,0,1),"Unaffordable request");p.carbon=reserves;
 check(viable.request(p,Action::Germinate,0,.5),"Germination request");auto resumed=World::restore(viable.checkpoint());
 for(int i=0;i<4;++i){viable.step();resumed.step();}check(viable.checkpoint()==resumed.checkpoint(),"Pending job restore diverged");check(p.organs.size()==2,"Growth not constructed");
 p.policy=Policy::Viable;for(int i=0;i<600;++i){viable.step();viable.validate();}
 check(viable.nextId>2,"No offspring from viable baseline");bool mutated=false;for(auto& q:viable.plants)mutated|=q.mutations>0;check(mutated,"No inherited mutations observed");
 auto saved=viable.checkpoint();auto copy=World::restore(saved);for(int i=0;i<80;++i){viable.step();copy.step();}check(viable.checkpoint()==copy.checkpoint(),"Continuation differs");
 saved[saved.size()/2]^=1;bool rejected=false;try{World::restore(saved);}catch(...){rejected=true;}check(rejected,"Corruption accepted");
 World neural(9);for(unsigned i=0;i<12;++i)neural.founder(i%3,{double(i%4)*8-16,0,double(i/4)*8-8});for(int i=0;i<300;++i){neural.step();neural.validate();}auto n=World::restore(neural.checkpoint());check(n.checkpoint()==neural.checkpoint(),"Neural memory round trip");
 World choice(11);auto& chooser=choice.founder(0,{0,0,0},Policy::Neural);chooser.genome.weights.fill(0);
 constexpr unsigned offset=Hidden*(Inputs+Hidden+1);
 chooser.genome.weights[offset+unsigned(Action::Germinate)*(Hidden+1)+Hidden]=2;
 for(int i=0;i<12;++i){choice.step();}check(choice.plants[0].stage==1,"Neural germination intent ignored");
 World noChoice(11);noChoice.founder(0,{0,0,0},Policy::Neural).genome.weights.fill(0);for(int i=0;i<12;++i)noChoice.step();check(noChoice.plants[0].stage==0,"Neural tie failed to preserve wait");
 choice.validate();noChoice.validate();
 World sharing(12);sharing.plants.reserve(MaxPlants);sharing.founder(0,{0,0,0},Policy::Wait);sharing.founder(0,{0,0,0},Policy::Wait);
 for(auto& q:sharing.plants){check(sharing.request(q,Action::Germinate,0,.5),"Shared root setup");}
 for(int i=0;i<4;++i){sharing.step();}
 for(auto& q:sharing.plants){sharing.ledger.waterOut+=q.water;q.water=0;}
 auto soil=sharing.cell({0,0,0});sharing.ledger.waterOut+=sharing.surface.cells[soil].water-.01;sharing.surface.cells[soil].water=.01;sharing.rainfall=0;sharing.daylight=0;sharing.step();
 check(std::abs(sharing.plants[0].water-sharing.plants[1].water)<1e-12,"Shared uptake unfair");sharing.validate();
 World dry(10);dry.rainfall=0;for(auto& c:dry.surface.cells)c.water=0;dry.ledger.initialWater=0;dry.founder(2,{0,0,0},Policy::Wait);for(int i=0;i<1000;++i){dry.step();dry.validate();}check(dry.plants.empty()||dry.plants[0].stage==2,"Dormant seed immortal");
 std::cout<<"PASS: permission/intent, reservations, three genomes, conserved carbon/water/nutrients, mutation, pending and neural checkpoint replay, corruption rejection, drought death\n";
}catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}}
