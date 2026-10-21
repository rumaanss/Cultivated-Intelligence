#include "cybernet/world/island_world.hpp"
#include "cybernet/simulation/live_manifest.hpp"
#include "cybernet/simulation/live_checkpoint.hpp"
#include <fstream>
#include <iostream>
#include <random>
#include <memory>
using namespace cybernet;
int main(int argc,char** argv){
 if(argc!=2)return 2;
 std::ifstream f(argv[1]);std::string surface{std::istreambuf_iterator<char>(f),{}};
 GeometryWorld geometry(pond_geometry::Objects,.25F,{},&pond_geometry::Field,pond_geometry::Bounds);
 if(geometry.bounds().x!=436||geometry.bounds().y!=212||geometry.bounds().z!=108||!geometry.objects().empty())return 3;
 std::mt19937 random(42);std::uniform_real_distribution<float> x(0,436),y(0,212),z(0,108);
 unsigned accepted=0;
 for(unsigned i=0;i<20000;++i){Vec3 p{x(random),y(random),z(random)};if(geometry.clear(p)){++accepted;auto land=IslandWorld::toIsland(p);auto q=IslandWorld::toPond(land);if((p-q).lengthSquared()>1e-7)return 4;if(land.y>=0)return 5;}}
 if(accepted<1000)return 6;
 IslandWorld a(42),b(42);a.initialize(surface);b.initialize(surface);
 if(a.biology.plants.size()!=96)return 7;
 for(auto& p:a.biology.plants){auto c=a.biology.cell(p.position);if(c>=a.biology.surface.cells.size()||!a.biology.surface.cells[c].valid||p.position.y<3)return 8;}
 // Keep the two large chemistry grids off the Windows thread stack.
 auto caStorage=std::make_unique<ChemistryField>();auto cbStorage=std::make_unique<ChemistryField>();
 auto& ca=*caStorage;auto& cb=*cbStorage;CelestialCycle sa(600,.08F),sb(600,.08F);a.bind(ca,sa);b.bind(cb,sb);
 for(unsigned tick=1;tick<=120;++tick){sa.update(tick);sb.update(tick);a.step(tick,ca,sa);b.step(tick,cb,sb);}
 if(a.snapshot(120)!=b.snapshot(120))return 9;
 IslandWorld restored(42);restored.restore(a.biology.checkpoint());
 // Diagnostic flux samples and callback-backed atmosphere are runtime bindings.
 // Checkpoint state must round-trip exactly; observations resume after rebinding.
 if(restored.biology.checkpoint()!=a.biology.checkpoint())return 10;
 auto cr=std::make_unique<ChemistryField>(ca);CelestialCycle sr(600,.08F);restored.bind(*cr,sr);
 for(unsigned tick=121;tick<=123;++tick){sa.update(tick);sr.update(tick);a.step(tick,ca,sa);restored.step(tick,*cr,sr);}
 if(restored.snapshot(123)!=a.snapshot(123))return 13;
 auto manifest=liveManifest(42,"planet-test");if(manifest.find(planet_contract::Digest)==std::string::npos||manifest.find("\"version\":4")==std::string::npos)return 11;
 if(checkpointAbi().find(planet_contract::Digest)==std::string::npos)return 12;
 std::cout<<"PASS planet geometry, "<<accepted<<" valid wet positions, 96 surveyed land founders, deterministic biology, checkpoint and manifest identity\n";
}
