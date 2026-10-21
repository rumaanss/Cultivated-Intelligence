#include "cybernet/world/pond_geometry_generated.hpp"
#include "cybernet/world/island_world.hpp"
#include <iostream>
#include <random>
#include <stdexcept>
using namespace cybernet;
void check(bool ok,const char* message){if(!ok)throw std::runtime_error(message);}
int main(){try{
 GeometryWorld world(pond_geometry::Objects,.25F,{},&pond_geometry::Field,pond_geometry::Bounds);
 check(config::WORLD_SIZE_X==208 && config::WORLD_SIZE_Y==176 && config::WORLD_SIZE_Z==68,"wrong compiled domain");
 check(ChemistryField::GridX==21&&ChemistryField::GridY==18&&ChemistryField::GridZ==7,"chemistry resolution");
 auto origin=IslandWorld::toPond({0,0,0});check(origin.x==104&&origin.y==88&&origin.z==68,"world transform");
 auto roundtrip=IslandWorld::toIsland(origin);check(roundtrip.x==0&&roundtrip.y==0&&roundtrip.z==0,"world transform inverse");
 unsigned outerHabitat=0;
 for(unsigned y=1;y<175;++y)for(unsigned x=1;x<207;++x)
  if((x<54||x>154||y<38||y>138)&&world.clear({float(x),float(y),67}))++outerHabitat;
 check(outerHabitat>5000,"full pond habitat not available");
 std::mt19937 rng(42);std::uniform_real_distribution<float> x(0,208),y(0,176),z(0,68),step(-4,4);
 for(unsigned i=0;i<3000;++i){Vec3 p{x(rng),y(rng),z(rng)};
  check(world.projectOutside(p)&&world.clear(p),"placement fails");
  for(unsigned j=0;j<8;++j){Vec3 velocity{step(rng),step(rng),step(rng)};Vec3 target=p+velocity;if(!world.move(p,target,velocity)){std::cerr<<"start "<<p.x<<","<<p.y<<","<<p.z<<" target "<<target.x<<","<<target.y<<","<<target.z<<" floor "<<world.floorHeight(target.x,target.y,.25F)<<"\n";throw std::runtime_error("movement unresolved");}p=target;check(world.clear(p),"movement penetrates ground");}
 }
 // A ridge between two clear endpoints must block vision and continuous motion.
 const std::array<float,6> ridge{0,8,0,0,8,0};Heightfield test{3,2,4,ridge};float t=1;Vec3 normal;
 check(test.sweep({0,2,4},{8,2,4},0,t,normal)&&std::abs(t-.25F)<1e-5F,"ridge tunneling");
 t=1;check(!test.sweep({0,2,9},{8,2,9},0,t,normal),"false ridge collision");
 std::cout<<"Full pond: transforms, chemistry grid, "<<outerHabitat<<" outer habitat sites, 3000 placements, 24000 movements and ridge crossings passed\n";
 return 0;
 }catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}}
