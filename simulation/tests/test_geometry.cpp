#include "cybernet/world/shared_geometry_generated.hpp"
#include "cybernet/world/celestial.hpp"
#include "cybernet/world/ecology.hpp"
#include "cybernet/simulation/run_options.hpp"
#ifdef NDEBUG
#undef NDEBUG
#endif
#include <cassert>
#include <fstream>
#include <random>
using namespace cybernet;
int main(){
 GeometryWorld world(shared_geometry::Objects,shared_geometry::BodyRadius);
 assert(world.blocked({20,50,25},{50,50,25}));
 assert(!world.blocked({20,10,25},{50,10,25}));
 assert(world.blocked({65,30,20},{65,60,20}));
 Vec3 start{20,50,25},end{80,50,25},velocity{60,0,0};
 assert(world.move(start,end,velocity));assert(end.x<31.751F&&end.x>31.7F&&velocity.x==0&&world.clear(end));
 start={20,40,25};end={50,60,25};velocity={30,20,0};
 assert(world.move(start,end,velocity));assert(end.x<31.751F&&end.y>40&&world.clear(end));
 Vec3 inside{35,50,25};assert(world.projectOutside(inside)&&world.clear(inside));
 inside={65,45,20};assert(world.projectOutside(inside)&&world.clear(inside));
 inside={0,0,60};assert(world.projectOutside(inside)&&world.clear(inside));
 start={31.75F,50,25};end={30,50,25};velocity={-1.75F,0,0};assert(world.move(start,end,velocity)&&end.x==30);
 start={31.75F,50,25};end={34,50,25};velocity={2.25F,0,0};assert(world.move(start,end,velocity)&&end.x<=31.75F);
 OpticalField lit(OpticalConfig{},1,0.08F,60,150), shaded(OpticalConfig{},1,0.08F,60,150,&world,0);
 const auto a=lit.sampleLight({57,75,20}),b=shaded.sampleLight({57,75,20});
 assert(a.direct>0&&b.direct==0&&a.diffuse==b.diffuse&&b.photosynthetic<a.photosynthetic);
 assert(!shaded.sampleVisibility({30,50,25},{40,50,25},30).detectable);
 assert(shaded.sampleVisibility({20,10,60},{21,10,60},30).detectable);
 // An opaque non-solid blocks sight only; a transparent solid blocks bodies only.
 GeometryObject glass{10,GeometryShape::Box,{50,50,30},{0.1F,10,10},true,false};
 GeometryWorld glassWorld(std::span(&glass,1));
 assert(!glassWorld.blocked({49,50,30},{51,50,30},true));
 assert(glassWorld.blocked({49,50,30},{51,50,30},false));
 Ecology ecology;ecology.setGeometry(&glassWorld);
 std::vector<Organism> p(2);p[0].id=1;p[0].configureSpecies(OrganismType::Bacterivore);p[0].position={49.5F,50,30};
 p[1].id=2;p[1].configureSpecies(OrganismType::Cyanobacteria);p[1].position={50.5F,50,30};ecology.beginTick(p);
 assert(!ecology.tryFeed(p[0],&p[1],p,true));assert(p[1].alive());
 // 9 objects exercises the grid rather than the tiny-scene fast path.
 std::vector<GeometryObject> many;for(int i=0;i<9;++i)many.push_back({static_cast<unsigned>(i+1),GeometryShape::Sphere,{5.0F+10*i,90,50},{1,1,1},true,true});
 GeometryWorld indexed(many);assert(indexed.blocked({0,90,50},{100,90,50}));assert(!indexed.blocked({0,80,50},{100,80,50}));
 std::mt19937 rng(123);std::uniform_real_distribution<float> x(0,100),z(0,60),step(-30,30);
 std::ofstream rays("geometry_rays.jsonl");
 for(int i=0;i<2000;++i){
  Vec3 a{x(rng),x(rng),z(rng)},b{x(rng),x(rng),z(rng)};
  // Store integers so C++ and Luau receive identical positions.
  a={std::floor(a.x),std::floor(a.y),std::floor(a.z)};b={std::floor(b.x),std::floor(b.y),std::floor(b.z)};
  rays<<"["<<a.x<<','<<a.y<<','<<a.z<<','<<b.x<<','<<b.y<<','<<b.z<<','<<world.blocked(a,b,true)<<','<<world.blocked(a,b,false,world.bodyRadius())<<"]\n";
  assert(world.projectOutside(a));Vec3 v{step(rng),step(rng),step(rng)},target=a+v;
  assert(world.move(a,target,v));assert(world.clear(target));
 }
 char app[]="test",flag[]="--geometry=demo",opt[]="--optics=v2";char* args[]={app,flag,opt};
 assert(parseRunOptions(3,args).valid()&&parseRunOptions(3,args).options.sharedGeometry);
 assert(!parseRunOptions(2,args).valid());
}
