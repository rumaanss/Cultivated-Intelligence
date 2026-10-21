#pragma once
#include "cybernet/plants/plant_world.hpp"
#include "cybernet/world/celestial.hpp"
#include "cybernet/world/chemistry.hpp"
#include <algorithm>
#include <cmath>
#include <sstream>
#include <stdexcept>
#ifdef CI_FULL_POND
#include "cybernet/world/pond_geometry_generated.hpp"
#endif
namespace cybernet {
// Global coordinates are Roblox X/Y-up/Z in studs; pond offsets follow the domain.
class IslandWorld final: public CanopyField {
public:
 static constexpr unsigned PlantStride=3,PublishStride=15;
 plants::World biology;
 explicit IslandWorld(std::uint64_t seed):biology(seed){}
#ifdef CI_PLANET_LAKE
 static Vec3 toPond(plants::V p){return {float(p.x-planet_contract::OriginEast),float(p.z-planet_contract::OriginNorth),float(p.y+planet_contract::Depth)};}
 static plants::V toIsland(Vec3 p){return {p.x+planet_contract::OriginEast,p.z-planet_contract::Depth,p.y+planet_contract::OriginNorth};}
#else
 static Vec3 toPond(plants::V p){return {float(p.x+config::WORLD_SIZE_X/2),float(p.z+config::WORLD_SIZE_Y/2),float(p.y+config::WORLD_SIZE_Z)};}
 static plants::V toIsland(Vec3 p){return {p.x-config::WORLD_SIZE_X/2,p.z-config::WORLD_SIZE_Z,p.y-config::WORLD_SIZE_Y/2};}
#endif
 void initialize(const std::string& surface,unsigned founders=96){
  biology.loadSurface(surface);validateBounds();
  std::vector<unsigned> sites;for(unsigned i=0;i<biology.surface.cells.size();++i)if(biology.surface.cells[i].valid)sites.push_back(i);
  if(sites.empty())throw std::runtime_error("Island has no land habitat; export terrain first");
  // Deterministic sampling without replacement. Initial bodies are starting
  // phenotypes, not forced controller decisions or evidence of evolved growth.
  founders=std::min<unsigned>(founders,unsigned(sites.size()));
  const auto distance=[&](unsigned c){double x=biology.surface.originX+(c%biology.surface.width+.5)*biology.surface.cellSize,z=biology.surface.originZ+(c/biology.surface.width+.5)*biology.surface.cellSize;return x*x+z*z;};
  std::sort(sites.begin(),sites.end(),[&](unsigned a,unsigned b){const auto da=distance(a),db=distance(b);return da==db?a<b:da<db;});
  for(unsigned n=0;n<founders;++n){unsigned at=n<12?n:n+unsigned(biology.random()*(sites.size()-n));std::swap(sites[n],sites[at]);unsigned c=sites[n];
   plants::V pos{biology.surface.originX+(c%biology.surface.width+.5)*biology.surface.cellSize,0,biology.surface.originZ+(c/biology.surface.width+.5)*biology.surface.cellSize};
   auto& p=biology.founder(n%3,pos,plants::Policy::Neural);p.stage=1;
   const double height=p.genome.species==1?4.:p.genome.species==2?1.2:2.;
   p.organs={{1,0,plants::Kind::Root,{0,0,0},{0,-1,0},.12,.5,1,false},{2,0,plants::Kind::Stem,{0,0,0},{0,height,0},.15,1.5,1,false},
    {3,2,plants::Kind::Leaf,{0,height,0},{.45,height+.2,0},.06,.3,1,false},{4,2,plants::Kind::Leaf,{0,height,0},{-.45,height+.2,0},.06,.3,1,false}};
   p.nextOrgan=5;p.carbon-=2.6;p.nutrients-=2.6*.05;++p.revision;
  }
  biology.validate();rebuildCanopy();
 }
 std::string snapshot(std::uint32_t worldTick)const {
  auto text=biology.snapshot();
#ifdef CI_PLANET_LAKE
  text.insert(1,"\"worldTick\":"+std::to_string(worldTick)+",\"habitatDigest\":\""+planet_contract::Digest+"\",\"plantStride\":3,");return text;
#else
  text.insert(1,"\"worldTick\":"+std::to_string(worldTick)+",\"worldBounds\":[-576,896,-512,448],\"plantStride\":3,");return text;
#endif
 }
 void restore(const std::string& state){biology=plants::World::restore(state);validateBounds();rebuildCanopy();}
 void bind(ChemistryField& chemistry,CelestialCycle& celestial){
  chemistry.enableIslandAtmosphere();celestial.setCanopy(this);
  biology.environmentalLight=[&celestial](plants::V p){return double(celestial.optics().sampleLight(toPond(p)).photosynthetic);};
  biology.assimilateCarbon=[&chemistry](double amount){return chemistry.assimilateAtmosphericCarbon(amount);};
  biology.atmosphereCarbon=[&chemistry](){return chemistry.atmosphericCarbon();};
  biology.returnCarbon=[&chemistry](double amount){chemistry.returnAtmosphericCarbon(amount);};
 }
 void step(std::uint32_t worldTick,ChemistryField& chemistry,const CelestialCycle& celestial){
  if(worldTick%PlantStride)return;
  if(biology.tick!=worldTick/PlantStride-1)throw std::runtime_error("Island clock mismatch");
  biology.daylight=celestial.state().daylight;
  biology.step();runoff(chemistry);biology.validate();rebuildCanopy();
 }
 float transmission(const Vec3& pond)const noexcept override{
  const auto p=toIsland(pond);unsigned c=biology.cell(p);if(c>=biology.surface.cells.size()||canopy_.empty())return 1;
  const double relative=(p.y-biology.surface.cells[c].height)/2;
  if(relative>=126)return 1;
  int layer=std::clamp(int(std::floor(relative))+1,0,63);
  return std::exp(-canopy_[c*64+unsigned(layer)]);
 }
 void rebuildCanopy(){
  canopy_.assign(biology.surface.cells.size()*64,0);
  for(const auto& p:biology.plants)for(const auto& o:p.organs)if(!o.dead&&o.kind==plants::Kind::Leaf){auto v=p.position+o.end;unsigned c=biology.cell(v);if(c<biology.surface.cells.size()){
   int layer=std::clamp(int((v.y-biology.surface.cells[c].height)/2),0,63);canopy_[c*64+unsigned(layer)]+=float(o.mass*p.genome.leafArea*.2);
  }}
  for(unsigned c=0;c<biology.surface.cells.size();++c)for(int l=62;l>=0;--l)canopy_[c*64+unsigned(l)]+=canopy_[c*64+unsigned(l)+1];
 }
private:
 std::vector<float> canopy_;
 std::vector<double> waterDelta_,mineralDelta_;
 void validateBounds(){
  auto& s=biology.surface;
#ifdef CI_PLANET_LAKE
  if(s.width!=planet_contract::LandWidth||s.height!=planet_contract::LandHeight||s.originX!=planet_contract::LandX||s.originZ!=planet_contract::LandZ||s.cellSize!=planet_contract::LandCell||s.revision!=planet_contract::Surface)throw std::runtime_error("Planet habitat surface/schema mismatch");
  for(const auto& cell:s.cells)if(cell.valid&&cell.height<3)throw std::runtime_error("Planet plants require dry surveyed land");
#else
  if(s.width!=46||s.height!=30||s.originX!=-576||s.originZ!=-512||s.cellSize!=32)throw std::runtime_error("Island export must cover X[-576,896], Z[-512,448] in 32-stud cells");
  for(unsigned c=0;c<s.cells.size();++c)if(s.cells[c].valid){double x=s.originX+(c%s.width+.5)*s.cellSize,z=s.originZ+(c/s.width+.5)*s.cellSize;
   if(s.cells[c].height<=0||(std::abs(x)<52&&std::abs(z)<52))throw std::runtime_error("Land plants cannot occupy submerged cells or the pond");
  }
#endif
 }
 void runoff(ChemistryField& chemistry){
  // Conservative dissolved mineral/water transport to the lowest adjacent cell.
  // Invalid planting cells still retain hydrological state; no teleporting
  // nutrients from distant trees straight into the pond.
  auto& s=biology.surface;waterDelta_.assign(s.cells.size(),0);mineralDelta_.assign(s.cells.size(),0);
  auto& dw=waterDelta_;auto& dn=mineralDelta_;
  for(unsigned c=0;c<s.cells.size();++c){auto& a=s.cells[c];if(a.water<=25)continue;unsigned low=c;unsigned x=c%s.width,z=c/s.width;
   for(int d:{-1,1,-int(s.width),int(s.width)}){
    if((d==-1&&x==0)||(d==1&&x+1==s.width)||(d==-int(s.width)&&z==0)||(d==int(s.width)&&z+1==s.height))continue;
    unsigned next=unsigned(int(c)+d);if(s.cells[next].height<s.cells[low].height)low=next;
   }
   if(low==c)continue;
   double water=std::min(.05,(a.water-25)*.01),nutrient=std::min(a.nutrients,a.nutrients*water/std::max(1.,a.water));dw[c]-=water;dn[c]-=nutrient;
   const double wx=s.originX+(low%s.width+.5)*s.cellSize,wz=s.originZ+(low/s.width+.5)*s.cellSize;
   const Vec3 destination=toPond({wx,0,wz});
   bool pond=destination.x>0&&destination.x<config::WORLD_SIZE_X&&destination.y>0&&destination.y<config::WORLD_SIZE_Y;
#ifdef CI_FULL_POND
   pond=pond&&pond_geometry::Field.height(destination.x,destination.y)<config::WORLD_SIZE_Z;
#endif
   if(pond){chemistry.depositMineral(destination,nutrient);biology.ledger.nutrientInput-=nutrient;biology.ledger.waterOut+=water;}
   else {dw[low]+=water;dn[low]+=nutrient;}
  }
  for(unsigned c=0;c<s.cells.size();++c){s.cells[c].water+=dw[c];s.cells[c].nutrients+=dn[c];}
 }
};
}
