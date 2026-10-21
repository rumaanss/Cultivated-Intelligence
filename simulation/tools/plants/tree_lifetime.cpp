// Controlled cultivation assay, not proof of ecological or neural success.
// Keep at most eight individuals; excess seeds become conserved dead biomass.
#include "cybernet/plants/plant_world.hpp"
#include <algorithm>
#include <cmath>
#include <iostream>
#include <set>
using namespace cybernet::plants;
int main(int argc,char**){
 const bool neural=argc>1;
 std::cout<<"seed,steps,births,established,mature,founderDeathStep,maxHeight,remaining\n";
 for(unsigned seed=1;seed<=5;++seed){
  World w(seed);auto& founder=w.founder(1,{0,0,0},neural?Policy::Neural:Policy::Viable);
  if(neural){
   founder.stage=1;founder.organs={{1,0,Kind::Root,{0,0,0},{0,-1,0},.12,.5,1,false},
    {2,0,Kind::Stem,{0,0,0},{0,4,0},.15,1.5,1,false},
    {3,2,Kind::Leaf,{0,4,0},{.45,4.2,0},.06,.3,1,false},
    {4,2,Kind::Leaf,{0,4,0},{-.45,4.2,0},.06,.3,1,false}};
   founder.nextOrgan=5;founder.carbon-=2.6;founder.nutrients-=2.6*.05;
  }
  std::set<unsigned> established,mature;unsigned founderDeath=0;double height=0;
  for(unsigned t=0;t<130000;++t){
   w.daylight=std::max(0.,std::sin(t*6.283185307179586/200));
   // Disclosed cultivation capacity. No carbon or nutrient is erased.
   for(std::size_t i=8;i<w.plants.size();++i){auto& p=w.plants[i];p.stage=2;p.health=0;for(auto& o:p.organs)o.dead=true;}
   w.step();
   if(t%1000==0)w.validate();
   bool founderAlive=false;
   for(const auto& p:w.plants){
    founderAlive|=p.id==1;
    if(p.stage==1){established.insert(p.id);if(p.age>=p.genome.maturity)mature.insert(p.id);}
    for(const auto& o:p.organs)if(!o.dead)height=std::max(height,o.end.y);
   }
   if(!founderAlive&&!founderDeath)founderDeath=unsigned(w.tick);
   if(w.plants.empty())break;
  }
  w.validate();std::cout<<seed<<','<<w.tick<<','<<w.nextId-2<<','<<established.size()<<','<<mature.size()<<','<<founderDeath<<','<<height<<','<<w.plants.size()<<std::endl;
 }
}
