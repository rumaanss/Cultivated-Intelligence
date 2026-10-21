#pragma once
#include "cybernet/world/planet_geometry_generated.hpp"
#include "cybernet/random.hpp"
#include <algorithm>
#include <vector>
#include <stdexcept>
namespace cybernet {
// A reproducible smaller starting cohort, not an equilibrium or a population cap.
// Scale N and occupied wet volume together to preserve initial encounter density.
struct PlanetFounders {
 static constexpr double Fraction=.4;
 static constexpr unsigned Cyanobacteria=1000,Bacterivores=60,Bodo=6;
 struct Cell {float x,y,z,top;double volume,distance;};
 std::vector<Cell> cells;double fullVolume=0,occupiedVolume=0;
 explicit PlanetFounders(const GeometryWorld& geometry){
  const auto& f=*geometry.heightfield();const float r=geometry.bodyRadius()+.001F;
  const float top=geometry.bounds().z-r;
  for(unsigned y=0;y+1<f.ny;++y)for(unsigned x=0;x+1<f.nx;++x){
   float low=std::max({f.heights[y*f.nx+x],f.heights[y*f.nx+x+1],f.heights[(y+1)*f.nx+x],f.heights[(y+1)*f.nx+x+1]})+r;
   if(low>=top)continue;
   const float xx=x*f.cell,yy=y*f.cell;
   const double volume=(f.cell-2*r)*(f.cell-2*r)*(top-low);
   const double east=xx+f.cell*.5+planet_contract::OriginEast,north=yy+f.cell*.5+planet_contract::OriginNorth;
   cells.push_back({xx+r,yy+r,low,top,volume,east*east+north*north});fullVolume+=volume;
  }
  std::stable_sort(cells.begin(),cells.end(),[](auto& a,auto& b){return a.distance<b.distance;});
  std::size_t n=0;while(n<cells.size()&&occupiedVolume<fullVolume*Fraction)occupiedVolume+=cells[n++].volume;
  cells.resize(n);if(cells.empty())throw std::runtime_error("No valid founder habitat");
 }
 Vec3 sample(Random& random)const {
  double draw=random.uniform_float(0,float(occupiedVolume));const Cell* chosen=&cells.back();
  for(const auto& c:cells){draw-=c.volume;if(draw<=0){chosen=&c;break;}}
  constexpr float span=4-2*.251F;
  return {random.uniform_float(chosen->x,chosen->x+span),random.uniform_float(chosen->y,chosen->y+span),random.uniform_float(chosen->z,chosen->top)};
 }
};
}
