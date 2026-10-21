#include "cybernet/world/planet_geometry_generated.hpp"
#include "reference_heightfield.hpp"
#include <random>
#include <iostream>
int main(){using namespace cybernet;const auto& f=planet_geometry::Field;HeightfieldReference ref(f.nx,f.ny,f.cell,f.heights);std::mt19937 rng(42);std::uniform_real_distribution<float>x(-5,441),y(-5,217),z(-5,130);
for(int i=0;i<200000;++i){Vec3 a{x(rng),y(rng),z(rng)},b{x(rng),y(rng),z(rng)},n{},m{};float t=1,u=1;float pad=i%2?.25F:0;bool aa=f.ray(a,b,pad,t,n),bb=ref.ray(a,b,pad,u,m);if(aa!=bb||t!=u||n.x!=m.x||n.y!=m.y||n.z!=m.z)return 1;}
std::cout<<"PASS 200000 exact ray hit/fraction/normal comparisons against initialized-buffer reference\n";}
