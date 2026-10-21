#include "cybernet/world/lake_geometry_generated.hpp"
#include "cybernet/world/optics.hpp"
#include "cybernet/simulation/run_options.hpp"
#ifdef NDEBUG
#undef NDEBUG
#endif
#include <cassert>
#include <fstream>
#include <random>
using namespace cybernet;
int main(){
 GeometryWorld lake(lake_geometry::Objects,lake_geometry::BodyRadius,lake_geometry::Planes);
 GeometryWorld floor({},0.25F,lake_geometry::Planes);
 assert(floor.floorHeight(50,50)==4);
 assert(floor.floorHeight(0,50)==46);
 Vec3 p{1,1,1};assert(lake.projectOutside(p)&&lake.clear(p));
 Vec3 start{50,50,40},end{50,50,-50},v{0,0,-90};
 assert(lake.move(start,end,v)&&lake.clear(end));assert(end.z>=4.25F&&end.z<4.251F&&v.z==0);
 start={50,50,10};end={1,50,10};v=end-start;
 assert(lake.move(start,end,v)&&lake.clear(end));assert(end.z>10); // Slides up west bank.
 // Lakebed blocks an endpoint beneath it, not a segment wholly in convex water.
 assert(floor.blocked({50,50,10},{50,50,0}));
 assert(!floor.blocked({1,50,50},{-80,50,60})); // No phantom terrain beyond the basin.
 assert(!floor.blocked({20,20,40},{80,80,40}));
 // Rock edge casts a shadow at a physically accessible point beside its contact.
 auto rock=lake_geometry::Objects[0];
 Vec3 shaded{rock.center.x+3.5F,rock.center.y,lake.floorHeight(rock.center.x+3.5F,rock.center.y,.25F)+.1F};assert(lake.clear(shaded));
 OpticalField bright({},1,0.08F,60,150,nullptr,0),dark({},1,0.08F,60,150,&lake,0);
 assert(bright.sampleLight(shaded).direct>0&&dark.sampleLight(shaded).direct==0);
 assert(dark.sampleLight(shaded).diffuse==bright.sampleLight(shaded).diffuse);
 std::mt19937 rng(773);std::uniform_real_distribution<float> xy(-50,150),z(0,60),delta(-100,100);
 std::ofstream rays("lake_rays.jsonl");
 int rejected=0;
 for(int i=0;i<10000;++i){
  Vec3 a{std::floor(xy(rng)),std::floor(xy(rng)),std::floor(z(rng))},b{std::floor(xy(rng)),std::floor(xy(rng)),std::floor(z(rng))};
  rays<<'['<<a.x<<','<<a.y<<','<<a.z<<','<<b.x<<','<<b.y<<','<<b.z<<','<<lake.blocked(a,b,true)<<','<<lake.blocked(a,b,false,.25F)<<"]\n";
  assert(lake.projectOutside(a));
  Vec3 validB=b;assert(lake.projectOutside(validB));
  assert(lake.blocked(a,validB,true)==lake.blockedBetweenBodies(a,validB,true));
  assert(lake.blocked(a,validB,false)==lake.blockedBetweenBodies(a,validB,false));
  v={delta(rng),delta(rng),delta(rng)};end=a+v;
  // Physics rolls back to the valid start if numerical/contact-cap constraints reject a move.
  if(!lake.move(a,end,v)){++rejected;end=a;}
  assert(lake.clear(end));
 }
 assert(rejected<100); // Fewer than 1% conservative rollbacks under extreme 100-unit steps.
 char app[]="test",flag[]="--geometry=lake",opt[]="--optics=v2";char* args[]={app,flag,opt};
 auto parsed=parseRunOptions(3,args);assert(parsed.valid()&&parsed.options.lakeGeometry&&parsed.options.sharedGeometry);
 assert(!parseRunOptions(2,args).valid());
}
