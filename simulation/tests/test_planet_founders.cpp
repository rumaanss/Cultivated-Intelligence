#include "cybernet/world/planet_founders.hpp"
#include <iostream>
int main(){
 using namespace cybernet;
 GeometryWorld geometry(planet_geometry::Objects,.25F,{},&planet_geometry::Field,planet_geometry::Bounds);
 PlanetFounders habitat(geometry);
 const double fraction=habitat.occupiedVolume/habitat.fullVolume;
 if(fraction<.4||fraction>.402)return 1;
 if(PlanetFounders::Cyanobacteria+PlanetFounders::Bacterivores+PlanetFounders::Bodo!=1066)return 2;
 for(unsigned seed:{42,137,991}){
  Random a(seed),b(seed);
  for(unsigned i=0;i<10000;++i){auto p=habitat.sample(a),q=habitat.sample(b);if(!geometry.clear(p)||(p-q).lengthSquared()!=0)return 3;}
 }
 std::cout<<"PASS 30000 deterministic wet founder samples; volume fraction "<<fraction<<"; initial density ratio "<<.4/fraction<<"\n";
}
