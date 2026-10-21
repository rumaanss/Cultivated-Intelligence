#include "cybernet/world/ecology.hpp"
#include "cybernet/world/celestial.hpp"
#include "cybernet/world/planet_geometry_generated.hpp"
#include <fstream>
#include <chrono>
#include <iostream>
#include <bit>
int main(int argc,char**argv){
 using namespace cybernet;if(argc!=2)return 2;
 std::ifstream input(argv[1]);std::vector<Organism> population;unsigned id,species;float x,y,z;
 while(input>>id>>species>>x>>y>>z){Organism o;o.id=id;o.configureSpecies(OrganismType(species));o.position={x,y,z};population.push_back(o);}
 GeometryWorld geometry(planet_geometry::Objects,.25F,{},&planet_geometry::Field,planet_geometry::Bounds);
 Ecology ecology;ecology.setGeometry(&geometry);CelestialCycle light(600,.08F);light.setGeometry(&geometry);light.setOpticalModel(OpticalModel::OpticsV2);
 std::uint64_t hash=1469598103934665603ULL;const auto start=std::chrono::steady_clock::now();
 for(int tick:{75,150,225,375,450,525}){
  light.update(tick);ecology.refreshSpatialIndex(population,&light);
  for(auto& o:population){auto result=ecology.buildObservation(o,population,light,{.1F,-.1F});
   for(float value:result.observation){hash^=std::bit_cast<std::uint32_t>(value);hash*=1099511628211ULL;}
   hash^=result.nearestPrey?result.nearestPrey->id:0;hash*=1099511628211ULL;
  }
 }
 std::cout<<"observations "<<population.size()*6<<" hash "<<hash<<" ms "<<std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count()<<'\n';
}
