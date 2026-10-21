#include "cybernet/world/planet_geometry_generated.hpp"
#include "reference_geometry.hpp"
#include <chrono>
#include <iostream>
#include <random>
int main(){
 using namespace cybernet;
 GeometryWorld fast(planet_geometry::Objects,.25F,{},&planet_geometry::Field,planet_geometry::Bounds);
 GeometryWorldReference original(planet_geometry::Objects,.25F,{},&planet_geometry::Field,planet_geometry::Bounds);
 std::mt19937 rng(20261020);std::uniform_real_distribution<float> u(-.1F,1.1F),v(-4,4);
 auto same=[](Vec3 a,Vec3 b){return a.x==b.x&&a.y==b.y&&a.z==b.z;};
 for(unsigned i=0;i<10000;++i){
  Vec3 start{u(rng)*planet_geometry::Bounds.x,u(rng)*planet_geometry::Bounds.y,u(rng)*planet_geometry::Bounds.z};
  auto a=start,b=start;bool aa=fast.projectOutside(a),bb=original.projectOutside(b);
  if(aa!=bb||!same(a,b)){std::cerr<<"Recovery differs at "<<i;return 1;}
  Vec3 va{v(rng),v(rng),v(rng)},vb=va;auto ta=start+va,tb=ta;
  aa=fast.move(start,ta,va);bb=original.move(start,tb,vb);
  if(aa!=bb||!same(ta,tb)||!same(va,vb)){std::cerr<<"Motion differs at "<<i;return 2;}
 }
 std::cout<<"PASS 10000 exact native collision/recovery comparisons, including invalid shoreline starts\n";
}
