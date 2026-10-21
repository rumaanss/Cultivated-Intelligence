#include "cybernet/plants/plant_world.hpp"
#include <cassert>
#include <cmath>
#include <iostream>
#include <fstream>
#include <iterator>
using namespace cybernet::plants;
int main(){
 std::ifstream legacyFile(CI_LEGACY_PLANT_FIXTURE);
 std::string legacy((std::istreambuf_iterator<char>(legacyFile)),{});
 auto migrated=World::restore(legacy);assert(migrated.plants[0].job.active);
 auto migratedCopy=World::restore(migrated.checkpoint());
 for(int i=0;i<8;++i){migrated.step();migratedCopy.step();}
 assert(migrated.checkpoint()==migratedCopy.checkpoint());
 World cancelled(19);auto& cp=cancelled.founder(1,{0,0,0},Policy::Wait);
 assert(cancelled.request(cp,Action::Germinate,0,.5));cp.stage=2;cp.health=0;
 cancelled.step();cancelled.validate();assert(cancelled.plants.empty());

 World starvation(23);auto& dying=starvation.founder(1,{0,0,0},Policy::Wait);
 starvation.ledger.respiration+=dying.carbon;dying.carbon=0;dying.health=.001;
 starvation.step();starvation.validate();assert(starvation.plants.empty());assert(starvation.history.size()==1);
 World broken(29);auto& growing=broken.founder(1,{0,0,0},Policy::Wait);
 assert(broken.request(growing,Action::Germinate,0,.5));for(int i=0;i<4;++i)broken.step();
 assert(broken.request(growing,Action::Leaf,growing.organs.front().id,.5));
 growing.organs.front().health=0;broken.step();broken.validate();assert(!growing.job.active);
 World w(17);auto& p=w.founder(1,{0,0,0},Policy::Wait);
 assert(w.request(p,Action::Germinate,0,.5));for(int i=0;i<4;++i)w.step();
 const auto cell=w.cell(p.position);const auto stem=p.organs.front().id;
 assert(w.request(p,Action::Leaf,stem,.5));for(int i=0;i<4;++i)w.step();
 const auto leaf=p.organs.back().id;assert(w.request(p,Action::Shed,leaf,0));
 w.step();w.validate();assert(w.surface.cells[cell].litter>0);
 for(auto& o:p.organs)assert(o.id!=leaf);
 p.stage=2;p.health=0;for(auto& o:p.organs)o.dead=true;w.daylight=0;p.water=0; // account test's removed water
 w.ledger.waterOut=w.ledger.initialWater+w.ledger.rain-w.waterTotal();
 w.step();w.validate();assert(w.plants.empty());assert(w.history.size()==1);
 auto copy=World::restore(w.checkpoint());assert(copy.checkpoint()==w.checkpoint());
 for(int i=0;i<200;++i){w.step();copy.step();w.validate();}
 assert(w.checkpoint()==copy.checkpoint());assert(w.surface.cells[cell].litter==0);
 assert(w.history.size()==1);std::cout<<"Death, shedding, litter conservation, removal and replay passed\n";
}
