#include "cybernet/aquatic/lake.hpp"
#include "cybernet/world/planet_geometry_generated.hpp"
#include "json.hpp"
#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <map>
using J=nlohmann::json;
namespace cybernet::aquatic {
namespace {
constexpr double Day=86400, dt=Lake::SecondsPerTick, spacing=16;
void need(bool b,const char* why){if(!b)throw std::runtime_error(why);}
double portion(double rate){return -std::expm1(-rate*dt/Day);}
void transfer(double& a,double& b,double n){if(a<=0||n<=0)return;n=std::min(n,a);a-=n;b+=n;}
std::uint64_t hash(const std::string& s){std::uint64_t h=1469598103934665603ULL;for(unsigned char c:s){h^=c;h*=1099511628211ULL;}return h;}
J totalsJson(Totals t){return J::array({t.carbon,t.nitrogen,t.phosphorus,t.oxygen});}
}
void Lake::makeGrid(){
 std::map<std::pair<int,int>,unsigned> grid;
 for(int iy=0;iy<14;++iy)for(int ix=0;ix<28;++ix){
  double x=(ix+.5)*spacing,y=(iy+.5)*spacing;
  if(x>=planet_contract::Width||y>=planet_contract::Length)continue;
  double sumDepth=0;unsigned wet=0;
  for(double ox:{-5.,0.,5.})for(double oy:{-5.,0.,5.}){
   double depth=108-planet_geometry::Field.height(float(x+ox),float(y+oy));
   if(depth>0){sumDepth+=depth;++wet;}
  }
  double floor=planet_geometry::Field.height(float(x),float(y));
  if(wet==0||floor>=107)continue;
  double area=spacing*spacing*MetresPerStud*MetresPerStud*wet/9.;
  double depth=sumDepth/wet;
  unsigned base=unsigned(cells.size());grid[{ix,iy}]=base;
  for(unsigned layer=0;layer<2;++layer){Cell c;c.x=x;c.y=y;c.floor=floor;c.z=108-(108-floor)*(layer==0?.25:.75);c.area=area;c.volume=area*depth*MetresPerStud*.5;c.column=base/2;c.layer=layer;cells.push_back(c);}
  edges_.push_back({base,base+1});
 }
 for(auto [key,base]:grid)for(auto d:{std::pair{1,0},std::pair{0,1}}){
  auto it=grid.find({key.first+d.first,key.second+d.second});if(it==grid.end())continue;
  if(planet_geometry::Field.height(float((cells[base].x+cells[it->second].x)*.5),float((cells[base].y+cells[it->second].y)*.5))>=108)continue;
  for(unsigned layer=0;layer<2;++layer)edges_.push_back({base+layer,it->second+layer});
 }
 need(!cells.empty(),"Aquatic survey has no wet cells");
}
Lake::Lake(std::uint64_t s):seed(s){
 makeGrid();double water=0;
 for(unsigned i=0;i<cells.size();++i){auto& c=cells[i];auto& m=c.m;double v=c.volume;water+=v;
  auto h=hash(std::to_string(seed)+":"+std::to_string(i));double variation=.8+double(h%10000)/25000.;
  m[DIC]=1500*v;m[NH4]=20*v;m[NO3]=40*v;m[PO4]=2*v;m[O2]=250*v;
  m[DOC]=12*v;m[POC]=4*v;m[Phyto]=2*v*variation;m[Bacteria]=.8*v*variation;
  if(c.layer==1){m[Mat]=40*c.area*variation;m[Sediment]=500*c.area;m[BoundP]=2*c.area;}
 }
 airCarbon=water*15000;airOxygen=water*50000;initial=totals();initialOxygen=initial.oxygen;
}
Totals Lake::totals()const{
 Totals t{airCarbon,0,0,airOxygen};
 for(auto& c:cells){auto& m=c.m;double organic=m[DOC]+m[POC]+m[Phyto]+m[Mat]+m[Bacteria]+m[Sediment];
  t.carbon+=m[DIC]+organic;t.nitrogen+=m[NH4]+m[NO3]+organic*NC;t.phosphorus+=m[PO4]+m[BoundP]+organic*PC;t.oxygen+=m[O2];}
 return t;
}
void Lake::step(bool reactions,bool gas,bool transport,double sunlight){
 double sun=sunlight>=0?std::clamp(sunlight,0.,1.):std::max(0.,std::sin(2*3.141592653589793*double(tick%CycleTicks)/CycleTicks));
 double waterVolume=0;for(const auto& c:cells)waterVolume+=c.volume;
 if(transport){
  // Finite-volume two-way mixing, not a hydrodynamic current solver.
  for(auto e:edges_){auto& a=cells[e.a];auto& b=cells[e.b];double water=std::min(a.volume,b.volume)*portion(a.column==b.column?.8:.2);
   for(int k=0;k<=Phyto;++k){double exchange=(a.m[k]/a.volume-b.m[k]/b.volume)*water;if(exchange>=0)transfer(a.m[k],b.m[k],exchange);else transfer(b.m[k],a.m[k],-exchange);}
   double exchange=(a.m[Bacteria]/a.volume-b.m[Bacteria]/b.volume)*water;if(exchange>=0)transfer(a.m[Bacteria],b.m[Bacteria],exchange);else transfer(b.m[Bacteria],a.m[Bacteria],-exchange);
  }
  for(unsigned i=0;i<cells.size();i+=2){auto& top=cells[i];auto& bottom=cells[i+1];
   double a=top.m[POC]*portion(.5),b=bottom.m[POC]*portion(.5);transfer(top.m[POC],bottom.m[POC],a);transfer(bottom.m[POC],bottom.m[Sediment],b);cumulative.settling+=b;}
 }
 for(unsigned i=0;i<cells.size();i+=2){
  double incident=1000*sun;
  cumulative.incidentPhotons+=incident*cells[i].area*dt/1000;
  for(unsigned layer=0;layer<2;++layer){auto& c=cells[i+layer];auto& m=c.m;double thickness=c.volume/c.area;
   double attenuation=.12+.015*m[Phyto]/c.volume+.001*m[DOC]/c.volume+.006*m[POC]/c.volume;
   double entering=incident;
   c.light=incident*std::exp(-attenuation*thickness*.5);incident*=std::exp(-attenuation*thickness);
   if(gas&&layer==0){
    // Fixed carbonate approximation, not a dynamic pH/carbonate solver.
    double flux=(1500*airCarbon/(waterVolume*15000)-m[DIC]/c.volume)*c.volume*portion(.03);
    if(flux>=0){flux=std::min(flux,airCarbon);transfer(airCarbon,m[DIC],flux);}else{flux=-std::min(-flux,m[DIC]);transfer(m[DIC],airCarbon,-flux);}cumulative.gasCarbon+=flux;
    double oxygen=(280*airOxygen/(waterVolume*50000)-m[O2]/c.volume)*c.volume*portion(.6);
    if(oxygen>=0){oxygen=std::min(oxygen,airOxygen);transfer(airOxygen,m[O2],oxygen);}else{oxygen=-std::min(-oxygen,m[O2]);transfer(m[O2],airOxygen,-oxygen);}cumulative.gasOxygen+=oxygen;
   }
   if(!reactions)continue;
   // Fixed organic quota: 106C:16N:1P. Rates are scenario parameters, not calibrated species fits.
   for(int guild:{int(Phyto),int(Mat)}){
    if(guild==Mat&&layer==0)continue;
    double light=guild==Mat?incident:c.light;
    double capacity=guild==Mat?c.area*1200:c.volume*100;
    double growth=m[guild]*portion(guild==Mat?.35:.8)*light/(light+80)*std::max(0.,1-m[guild]/capacity);
    // Carbon fixation is bounded by photons actually absorbed by this guild.
    double photons=guild==Mat?incident*(-std::expm1(-.01*m[Mat]/c.area))*c.area*dt/1000:
     (entering-incident)*(.015*m[Phyto]/c.volume)/attenuation*c.area*dt/1000;
    growth=std::min(growth,photons/(10+16*NC));
    growth=std::max(0.,std::min({growth,m[DIC],(m[NH4]+m[NO3])/NC,m[PO4]/PC}));
    m[DIC]-=growth;m[guild]+=growth;double nitrogen=growth*NC,nh=std::min(nitrogen,m[NH4]);m[NH4]-=nh;m[NO3]-=nitrogen-nh;m[PO4]-=growth*PC;
    double nitrate=nitrogen-nh;double oxygenProduced=growth+2*nitrate;
    m[O2]+=oxygenProduced;cumulative.production+=growth;cumulative.oxygenNet+=oxygenProduced;
    cumulative.usedPhotons+=10*growth+16*nitrate;
   }
   if(layer==1){double released=m[Sediment]*portion(.03);transfer(m[Sediment],m[DOC],released);
    double desired=m[PO4]*portion(.02),release=m[BoundP]*portion(m[O2]/c.volume<30?.1:.005);
    transfer(m[PO4],m[BoundP],desired);transfer(m[BoundP],m[PO4],release);}
   transfer(m[POC],m[DOC],m[POC]*portion(.08));
   double feed=m[Bacteria]*portion(1.2)*(m[DOC]/c.volume)/(m[DOC]/c.volume+5);
   constexpr double yield=.3;
   feed=std::min({feed,m[DOC],m[O2]/(1-yield)});
   m[DOC]-=feed;m[Bacteria]+=feed*yield;m[DIC]+=feed*(1-yield);m[NH4]+=feed*(1-yield)*NC;m[PO4]+=feed*(1-yield)*PC;m[O2]-=feed*(1-yield);
   cumulative.decomposition+=feed;cumulative.respiration+=feed*(1-yield);cumulative.oxygenNet-=feed*(1-yield);
   for(int guild:{int(Phyto),int(Mat),int(Bacteria)}){
    double requested=m[guild]*portion(guild==Bacteria?.08:.04);double resp=std::min(requested,m[O2]);
    m[guild]-=resp;m[DIC]+=resp;m[NH4]+=resp*NC;m[PO4]+=resp*PC;m[O2]-=resp;cumulative.respiration+=resp;cumulative.oxygenNet-=resp;
    double dead=std::min(m[guild],m[guild]*portion(.02)+(requested-resp));
    transfer(m[guild],m[POC],dead);cumulative.mortality+=dead;
   }
   double nitrified=std::min(m[NH4]*portion(.04),m[O2]*.5);transfer(m[NH4],m[NO3],nitrified);m[O2]-=2*nitrified;cumulative.nitrification+=nitrified;cumulative.oxygenNet-=2*nitrified;
  }
 }
 ++tick;
}
void Lake::validate()const{
 need(std::isfinite(cumulative.incidentPhotons)&&std::isfinite(cumulative.usedPhotons)&&cumulative.usedPhotons>=0&&cumulative.usedPhotons<=cumulative.incidentPhotons*(1+1e-10),"Aquatic photon budget");
 for(double f:{cumulative.production,cumulative.respiration,cumulative.mortality,cumulative.decomposition,cumulative.settling,cumulative.gasCarbon,cumulative.gasOxygen,cumulative.nitrification,cumulative.oxygenNet})need(std::isfinite(f),"Invalid aquatic flux");
 for(auto& c:cells)for(double x:c.m)need(std::isfinite(x)&&x>=-1e-8,"Invalid aquatic material pool");
 need(std::isfinite(airCarbon)&&airCarbon>=0&&std::isfinite(airOxygen)&&airOxygen>=0,"Invalid atmosphere pool");
 auto t=totals();auto close=[](double a,double b){return std::isfinite(b)&&std::abs(a-b)<=1e-8*std::max(1.,std::abs(b));};
 need(close(t.carbon,initial.carbon)&&close(t.nitrogen,initial.nitrogen)&&close(t.phosphorus,initial.phosphorus),"Aquatic elemental ledger drift");
 need(close(t.oxygen,initialOxygen+cumulative.oxygenNet),"Aquatic oxygen reaction ledger drift");
}
std::string Lake::checkpoint()const{
 validate();J rows=J::array();for(auto& c:cells)rows.push_back(c.m);
 J body={{"schema",1},{"model","aquatic-foundation-1"},{"habitat",planet_contract::Digest},{"seed",seed},{"tick",tick},{"air",{airCarbon,airOxygen}},{"initial",totalsJson(initial)},{"cells",rows},{"flux",{cumulative.production,cumulative.respiration,cumulative.mortality,cumulative.decomposition,cumulative.settling,cumulative.gasCarbon,cumulative.gasOxygen,cumulative.nitrification,cumulative.oxygenNet,cumulative.incidentPhotons,cumulative.usedPhotons}}};
 auto text=body.dump();return J{{"checksum",std::to_string(hash(text))},{"payload",text}}.dump();
}
Lake Lake::restore(const std::string& text,std::uint64_t expectedSeed){
 need(text.size()<4*1024*1024,"Aquatic checkpoint exceeds budget");auto outer=J::parse(text);std::string payload=outer.at("payload");need(outer.at("checksum")==std::to_string(hash(payload)),"Aquatic checkpoint checksum mismatch");auto j=J::parse(payload);
 need(j.at("schema")==1&&j.at("model")=="aquatic-foundation-1"&&j.at("habitat")==planet_contract::Digest,"Aquatic checkpoint contract mismatch");need(j.at("seed")==expectedSeed,"Aquatic checkpoint seed mismatch");
 Lake w(expectedSeed);need(j.at("cells").size()==w.cells.size(),"Aquatic cell count mismatch");w.tick=j.at("tick");need(w.tick<2147483647ULL,"Aquatic tick limit");w.airCarbon=j.at("air").at(0);w.airOxygen=j.at("air").at(1);
 auto a=j.at("initial");need(a.size()==4,"Aquatic initial ledger schema");w.initial={a[0],a[1],a[2],a[3]};w.initialOxygen=w.initial.oxygen;
 auto f=j.at("flux").get<std::array<double,11>>();w.cumulative={f[0],f[1],f[2],f[3],f[4],f[5],f[6],f[7],f[8],f[9],f[10]};
 for(unsigned i=0;i<w.cells.size();++i)w.cells[i].m=j.at("cells").at(i).get<std::array<double,Count>>();
 w.validate();return w;
}
std::string Lake::snapshot(const std::string& run)const{
 J rows=J::array();for(unsigned i=0;i<cells.size();i+=2){auto& a=cells[i];auto& b=cells[i+1];double v=a.volume+b.volume;
  rows.push_back({i/2+1,a.x,a.y,a.floor,(a.m[Phyto]+b.m[Phyto])/v,b.m[Mat]/b.area,(a.m[Bacteria]+b.m[Bacteria])/v,b.m[Sediment]/b.area,a.m[O2]/a.volume,b.m[O2]/b.volume,(a.m[DIC]+b.m[DIC])/v,(a.m[NH4]+b.m[NH4])/v,(a.m[NO3]+b.m[NO3])/v,(a.m[PO4]+b.m[PO4])/v,a.light,b.light});}
 auto t=totals();return J{{"schema",1},{"model","aquatic-foundation-1"},{"run",run},{"revision",tick},{"seed",seed},{"seconds",tick*SecondsPerTick},{"metresPerStud",MetresPerStud},{"patches",rows},{"totals",totalsJson(t)},{"residual",{t.carbon-initial.carbon,t.nitrogen-initial.nitrogen,t.phosphorus-initial.phosphorus,t.oxygen-initialOxygen-cumulative.oxygenNet}},{"flux",{cumulative.production,cumulative.respiration,cumulative.mortality,cumulative.decomposition,cumulative.settling}},{"photons",{cumulative.incidentPhotons,cumulative.usedPhotons}},{"cells",cells.size()}}.dump();
}
}
