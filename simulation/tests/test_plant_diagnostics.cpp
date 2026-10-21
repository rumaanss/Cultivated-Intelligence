#include "cybernet/world/island_world.hpp"
#include <memory>
#include <fstream>
#include <iostream>
int main(int argc,char**argv){using namespace cybernet;if(argc!=3)return 2;
 std::ifstream f(argv[1]);std::string surface{std::istreambuf_iterator<char>(f),{}};
 IslandWorld world(42);world.initialize(surface);auto chemistry=std::make_unique<ChemistryField>();CelestialCycle sun(600,.08F);
 GeometryWorld geometry(pond_geometry::Objects,.25F,{},&pond_geometry::Field,pond_geometry::Bounds);sun.setGeometry(&geometry);sun.setOpticalModel(OpticalModel::OpticsV2);world.bind(*chemistry,sun);
 for(unsigned tick=1;tick<=6000;++tick){sun.update(tick);world.step(tick,*chemistry,sun);}
 std::ofstream out(argv[2]);out<<world.snapshot(6000);
 world.biology.validate();std::cout<<"PASS 6000-tick native plant diagnostic fixture\n";
}
