#include "cybernet/plants/plant_world.hpp"
#include <algorithm>
#include <cmath>
#include <iomanip>
#include <limits>
#include <locale>
#include <map>
#include <set>
#include <sstream>
#include <stdexcept>
namespace cybernet::plants {
namespace {
double length(V a){return std::sqrt(a.x*a.x+a.y*a.y+a.z*a.z);} V unit(V a){double n=length(a);return n>1e-9?a*(1/n):V{0,1,0};}
void need(bool v,const char* message){if(!v)throw std::runtime_error(message);}
bool finite(double x){return std::isfinite(x);}
Organ* organ(Plant& p,unsigned id){for(auto& o:p.organs)if(o.id==id)return &o;return nullptr;}
unsigned count(const Plant& p,Kind kind){unsigned n=0;for(auto& o:p.organs)if(o.kind==kind&&!o.dead)++n;return n;}
double mass(const Plant& p){double n=0;for(auto& o:p.organs)if(!o.dead)n+=o.mass;return n;}
void vec(std::ostream& s,V v){s<<' '<<v.x<<' '<<v.y<<' '<<v.z;}void vec(std::istream& s,V& v){s>>v.x>>v.y>>v.z;}
void add(Plant& p,Kind kind,unsigned parent,V start,V end,double m){p.organs.push_back({p.nextOrgan++,parent,kind,start,end,std::max(.035,std::sqrt(m)*.12),m,1,false});++p.revision;}
std::uint64_t hash(std::string_view s){std::uint64_t h=1469598103934665603ULL;for(unsigned char c:s){h^=c;h*=1099511628211ULL;}return h;}
}
const char* actionName(Action a){static const char* names[]={"wait","shoot","branch","thicken","root","foliage","repair","shed","seed","release","germinate"};return names[static_cast<unsigned>(a)];}
World::World(std::uint64_t seed):rng(seed?seed:1),run("plants-"+std::to_string(seed)){plants.reserve(MaxPlants);surface.cells.resize(surface.width*surface.height);ledger.initialWater=surface.cells.size()*20.;ledger.initialNutrients=surface.cells.size()*8.;}
double World::random(){rng^=rng>>12;rng^=rng<<25;rng^=rng>>27;return double((rng*2685821657736338717ULL)>>11)*0x1.0p-53;}
unsigned World::cell(V p)const {int x=int(std::floor((p.x-surface.originX)/surface.cellSize)),z=int(std::floor((p.z-surface.originZ)/surface.cellSize));if(x<0||z<0||x>=int(surface.width)||z>=int(surface.height))return unsigned(surface.cells.size());return unsigned(z)*surface.width+unsigned(x);}
Plant& World::founder(unsigned species,V pos,Policy policy){need(species<3&&plants.size()<MaxPlants,"Founder limit/species");auto c=cell(pos);need(c<surface.cells.size()&&surface.cells[c].valid,"Invalid planting cell");Plant p;p.id=nextId++;p.lineage=p.id;p.position={pos.x,surface.cells[c].height,pos.z};p.policy=policy;p.genome.species=species;
 for(auto& w:p.genome.weights)w=(random()*2-1)*.35;
 if(species==1){p.genome.wood=1.7;p.genome.elongation=1.4;p.genome.maturity=90;p.genome.angle=.5;}
 if(species==2){p.genome.leafArea=.55;p.genome.waterLoss=.5;p.genome.elongation=.8;p.genome.angle=.8;p.genome.maturity=65;}
 p.genome.hue=random();ledger.founderCarbon+=p.carbon;ledger.initialWater+=p.water;ledger.nutrientInput+=p.nutrients;plants.push_back(p);++revision;return plants.back();}
std::vector<unsigned> World::candidates(const Plant& p,Action a)const {
 std::vector<unsigned> out;if(p.stage==2)return out;
 if(a==Action::Wait){out.push_back(0);return out;}
 if(p.stage==0){if(a==Action::Germinate){auto c=cell(p.position);if(c<surface.cells.size()&&surface.cells[c].valid&&surface.cells[c].water>.2)out.push_back(0);}return out;}
 if(a==Action::Germinate)return out;
 if(a==Action::Seed&&p.age<p.genome.maturity)return out;
 for(auto& o:p.organs){if(o.dead)continue;bool allowed=false;
  switch(a){
   case Action::Shoot:case Action::Branch:case Action::Leaf:case Action::Seed:allowed=o.kind==Kind::Stem;break;
   case Action::Thicken:allowed=o.kind==Kind::Stem||o.kind==Kind::Root;break;
   case Action::Root:allowed=o.kind==Kind::Root;break;
   case Action::Repair:allowed=o.health<.95;break;
   case Action::Shed:allowed=o.kind==Kind::Leaf||o.parent!=0;break;
   case Action::Release:allowed=o.kind==Kind::Pod;break;
   default:break;
  }
  unsigned children=0;for(auto& child:p.organs)if(child.parent==o.id&&!child.dead)++children;
  if((a==Action::Shoot||a==Action::Branch)&&children>=4)allowed=false;
  if(a==Action::Leaf&&children>=7)allowed=false;
  // Tree leaders favor shoot continuation; shrub stems admit more lateral buds.
  if(a==Action::Branch && p.genome.species==1 && (o.mass<.35 || children>=3))allowed=false;
  if(a==Action::Leaf && p.genome.species==2 && children>=4)allowed=false;
  if(allowed)out.push_back(o.id);
 }
 return out;
}
bool World::request(Plant& p,Action a,unsigned site,double investment,V direction){
 if(static_cast<unsigned>(a)>10){p.decision.result="invalid-action";return false;}
 p.decision.requested=a;p.decision.site=site;p.decision.investment=investment;
 auto reject=[&](const char* why){p.decision.result=why;return false;};
 if(static_cast<unsigned>(a)>10||!finite(investment)||investment<0||!finite(length(direction)))return reject("invalid-intent");
 if(p.stage==2)return reject("dead");
 if(a==Action::Wait){p.decision.result="chosen-wait";return true;}
 if(p.job.active)return reject("committed-job-active");
 auto options=candidates(p,a);if(std::find(options.begin(),options.end(),site)==options.end())return reject("ineligible-site-or-stage");
 if(a==Action::Release){if(plants.size()>=MaxPlants)return reject("system-population-budget");release(p,site);return p.decision.result=="seed-released";}
 if(a==Action::Shed){std::set<unsigned> dead{site};bool changed=true;while(changed){changed=false;for(auto& o:p.organs)if(dead.count(o.parent)&&!dead.count(o.id)){dead.insert(o.id);changed=true;}}
  for(auto& o:p.organs){if(dead.count(o.id))o.dead=true;}++p.revision;p.decision.result="organ-shed";return true;}
 const double minimum=a==Action::Seed?3.:a==Action::Germinate?.5:.12;
 if(investment<minimum)return reject("below-construction-minimum");
 double amount=std::min(investment,a==Action::Seed?8.:2.);
 if(p.carbon<amount)return reject("carbon-limited");
 if(p.nutrients<amount*.05)return reject("nutrient-limited");
 if(p.water<amount*.1)return reject("water-limited");
 // Keep enough mobile carbon for the 100-step night plus dawn/dusk.
 // Germination and a first leaf can spend seed capital to establish income.
 // This is an eligibility constraint, not a forced neural action.
 if(p.stage==1 && !(a==Action::Leaf && count(p,Kind::Leaf)==0)) {
  const double committedMass=mass(p)+(a==Action::Repair?0:amount);
  const double reserve=120*(.008+.004*committedMass*p.genome.wood);
  if(p.carbon-amount<reserve)return reject("night-reserve");
 }
 unsigned additions=a==Action::Germinate?2:1;
 if(a!=Action::Thicken&&a!=Action::Repair&&p.organs.size()+additions>MaxOrgans)return reject("system-organ-budget");
 if(a==Action::Germinate)direction={0,1,0};
 direction=unit(direction);
 if(a==Action::Root)direction.y=-std::max(.25,std::abs(direction.y));else direction.y=std::max(.15,direction.y);
 direction=unit(direction);
 if(site&&(a==Action::Root||a==Action::Shoot||a==Action::Branch)){
  auto* o=organ(p,site);V end=p.position+o->end+direction*(amount*p.genome.elongation*2);auto c=cell(end);
  if(c>=surface.cells.size()||!surface.cells[c].valid)return reject("outside-soil");
  if(a==Action::Root&&end.y<surface.cells[c].height-surface.cells[c].depth)return reject("soil-depth");
  if(a!=Action::Root){
   if(o->radius<.04||end.y-p.position.y>2+mass(p)*2*p.genome.wood)return reject("insufficient-support");
   for(auto& other:plants)for(auto& node:other.organs)if(!node.dead&&node.kind==Kind::Stem&&!(other.id==p.id&&node.id==site)){
    V q=other.position+node.end; if(length(end+q*(-1))<.15)return reject("occupied-space");
   }
  }
 }
 p.carbon-=amount;p.nutrients-=amount*.05;p.water-=amount*.1;ledger.waterOut+=amount*.1;
 p.job={true,a,site,amount,4,direction};p.decision.result="funded";return true;
}
void World::grow(Plant& p){auto& j=p.job;if(!j.active)return;if(--j.remaining)return;
 auto a=j.action;double c=j.carbon;unsigned id=j.site;V dir=j.direction;
 if(a==Action::Germinate){add(p,Kind::Stem,0,{0,0,0},{0,.55,0},c*.5);add(p,Kind::Root,0,{0,0,0},{0,-.55,0},c*.5);p.stage=1;}
 else {auto* o=organ(p,id);
  if(!o||o->dead){p.carbon+=c;p.nutrients+=c*.05;p.decision.result="job-cancelled-site-lost";j={};return;}
  if(a==Action::Thicken){o->mass+=c;o->radius=std::sqrt(o->mass)*.12;++p.revision;}
  else if(a==Action::Repair){o->health=std::min(1.,o->health+c);ledger.respiration+=c;p.nutrients+=c*.05;++p.revision;}
  else {Kind kind=a==Action::Root?Kind::Root:a==Action::Leaf?Kind::Leaf:a==Action::Seed?Kind::Pod:Kind::Stem;
   V start=o->end;V end=start+dir*(kind==Kind::Leaf?.35:kind==Kind::Pod?.2:c*p.genome.elongation*2);
   add(p,kind,id,start,end,c);
  }
 }
 j={};p.decision.result="job-completed";
}
Genome World::inherit(const Plant& p,unsigned& changed,double& distance){Genome g=p.genome;
 auto mutate=[&](double& v,double lo,double hi){if(mutation&&random()<.06){double old=v;v=std::clamp(v+(random()*2-1)*.12,lo,hi);if(v!=old){++changed;distance+=std::abs(v-old);}}};
 for(auto& w:g.weights)mutate(w,-3,3);
 mutate(g.angle,.2,1.2);mutate(g.elongation,.5,1.8);mutate(g.leafArea,.35,1.6);mutate(g.wood,.6,2.4);mutate(g.waterLoss,.35,1.6);mutate(g.maturity,20,160);mutate(g.hue,0,1);return g;
}
void World::release(Plant& p,unsigned site){auto* o=organ(p,site);V pos=p.position+V{(random()*2-1)*9,0,(random()*2-1)*9};auto c=cell(pos);
 if(c>=surface.cells.size()||!surface.cells[c].valid){p.decision.result="seed-release-site-invalid";return;}
 Plant child;child.id=nextId++;child.parent=p.id;child.lineage=p.lineage;child.generation=p.generation+1;child.position={pos.x,surface.cells[c].height,pos.z};
 child.genome=inherit(p,child.mutations,child.mutationDistance);child.carbon=o->mass;child.nutrients=o->mass*.05;child.water=std::min(.4,p.water);p.water-=child.water;child.policy=p.policy; // policy is experiment mode; real neural populations remain neural
 o->mass=0;o->dead=true;++p.revision;p.decision.result="seed-released";
 events.push_back("{\"tick\":"+std::to_string(tick)+",\"kind\":\"birth\",\"id\":"+std::to_string(child.id)+",\"parent\":"+std::to_string(p.id)+",\"generation\":"+std::to_string(child.generation)+",\"mutations\":"+std::to_string(child.mutations)+"}");
 plants.push_back(child); // caller reserves MaxPlants before decision phase
}
double World::light(const Plant& p,const Organ& o)const {
 const double illumination=environmentalLight?environmentalLight(p.position+o.end):daylight;
 auto c=cell(p.position+o.end);if(c>=surface.cells.size()||canopy_.empty())return illumination;
 int layer=std::clamp(int((p.position.y+o.end.y-surface.cells[c].height)/2),0,63);
 double shade=layer<63?canopy_[c*64+unsigned(layer+1)]:0;
 return environmentalLight?illumination:illumination*std::exp(-shade);
}
void World::decide(Plant& p){std::array<double,Inputs> in{};
 auto c=cell(p.position);in[0]=std::tanh(p.carbon/8);in[1]=std::tanh(p.water/4);in[2]=std::tanh(p.nutrients);in[3]=p.health;in[4]=std::min(1.,p.age/p.genome.maturity);in[5]=daylight;in[6]=surface.cells[c].water/40;in[7]=surface.cells[c].nutrients/16;in[8]=std::tanh(mass(p)/15);in[9]=count(p,Kind::Root)/16.;in[10]=count(p,Kind::Leaf)/16.;in[11]=count(p,Kind::Stem)/32.;in[12]=count(p,Kind::Pod)/4.;in[13]=p.stage==0?1:0;in[14]=1;
 // Local perception only: soil at current collar, sampled leaves, organ-local candidates.
 double exposure=0;unsigned leaves=0;for(auto& o:p.organs)if(!o.dead&&o.kind==Kind::Leaf){exposure+=light(p,o);++leaves;}in[15]=leaves?exposure/leaves:daylight;
 for(unsigned a=1;a<=8;++a)in[15+a]=candidates(p,Action(a)).empty()?0:1;
 p.decision.inputs=in;
 Action selected=Action::Wait;double investment=.3;V direction{0,1,0};std::array<double,Outputs> output{};
 if(p.policy==Policy::Wait){request(p,Action::Wait,0,0);return;}
 if(p.policy==Policy::Viable){ // disclosed mechanical baseline, not a neural success claim
  if(p.stage==0){selected=Action::Germinate;investment=.5;}
  else if(count(p,Kind::Pod)){selected=Action::Release;}
  else if(count(p,Kind::Leaf)<2){selected=Action::Leaf;investment=.5;}
  else if(p.water<1&&count(p,Kind::Root)<10){selected=Action::Root;investment=.4;}
  else if(p.carbon>7&&p.age>=p.genome.maturity&&count(p,Kind::Stem)>=(p.genome.species==1?6U:3U)){selected=Action::Seed;investment=3;}
  else if(p.carbon>2){unsigned mode=(p.age/4)%5;selected=mode==0?Action::Thicken:mode==1?Action::Leaf:mode==2?Action::Root:mode==3?Action::Branch:Action::Shoot;investment=.45;}
 }else{
  std::array<double,Hidden> next{};unsigned k=0;
  for(unsigned h=0;h<Hidden;++h){double s=0;for(auto x:in)s+=p.genome.weights[k++]*std::clamp(x,-1.,1.);for(auto x:p.memory)s+=p.genome.weights[k++]*x;s+=p.genome.weights[k++];next[h]=std::tanh(s);}p.memory=next;
  for(auto& v:output){for(auto h:next)v+=p.genome.weights[k++]*h;v+=p.genome.weights[k++];}
  double best=output[0];for(unsigned a=1;a<11;++a)if(output[a]>best&&!candidates(p,Action(a)).empty()){selected=Action(a);best=output[a];}
  investment=(selected==Action::Seed?3.:selected==Action::Germinate?.5:.12)+(selected==Action::Seed?3.:.8)*(std::tanh(output[11])+1)*.5;
 }
 auto sites=candidates(p,selected);if(sites.empty()){request(p,Action::Wait,0,0);return;}
 unsigned site=sites[p.cursor%sites.size()];double best=-1e99;
 for(unsigned n=0;n<std::min<std::size_t>(16,sites.size());++n){auto id=sites[(p.cursor+n)%sites.size()];auto* o=organ(p,id);double score=0;if(o){std::array<double,12> f{light(p,*o),o->health,o->radius,o->end.y/20,o->mass,p.memory[0],p.memory[1],1.,double(unsigned(o->kind))/3,0,0,0};for(unsigned i=0;i<12;++i)score+=f[i]*p.genome.weights[Weights-12+i];}if(p.policy==Policy::Viable&&o){
 if(selected==Action::Shoot)score=o->end.y;
 else if(selected==Action::Leaf){unsigned children=0;for(auto& q:p.organs)if(q.parent==id&&q.kind==Kind::Leaf&&!q.dead)++children;score=o->end.y*.1-children;}
 else if(selected==Action::Root)score=-o->end.y*.1+std::sin(double(p.cursor+id));
 }
 if(score>best){best=score;site=id;}}
 ++p.cursor;
 double azimuth=(p.id*2.399963+p.cursor*2.399963)+std::tanh(output[12])*.6;
 double angle=p.genome.angle+std::tanh(output[13])*.2;
 direction={std::sin(azimuth)*std::sin(angle),std::cos(angle),std::cos(azimuth)*std::sin(angle)};
 if(selected==Action::Shoot)direction=unit(V{direction.x*.3,1,direction.z*.3});
 request(p,selected,site,investment,direction);
}
void World::step(){const double respirationBefore=ledger.respiration;events.clear();plants.reserve(MaxPlants);++tick;++revision;
 // The island owns the shared canopy; standalone tests keep their local field.
 if(!environmentalLight){
 // Two-stud vertical light columns. Far/offscreen plants contribute identically.
 canopy_.assign(surface.cells.size()*64,0);
 for(auto& p:plants)for(auto& o:p.organs)if(!o.dead&&o.kind==Kind::Leaf){auto c=cell(p.position+o.end);if(c>=surface.cells.size())continue;
  unsigned layer=unsigned(std::clamp(int((p.position.y+o.end.y-surface.cells[c].height)/2),0,63));
  canopy_[c*64+layer]+=o.mass*p.genome.leafArea*.2;
 }
 for(unsigned c=0;c<surface.cells.size();++c)for(int layer=62;layer>=0;--layer)canopy_[c*64+unsigned(layer)]+=canopy_[c*64+unsigned(layer)+1];
 }
 for(auto& c:surface.cells)if(c.valid){double rain=std::min(rainfall,std::max(0.,40-c.water));c.water+=rain;ledger.rain+=rain;double evap=std::min(c.water,.006*daylight);c.water-=evap;ledger.waterOut+=evap;double decay=std::min(c.litter,.015);c.litter-=decay;c.nutrients+=decay*.05;ledger.respiration+=decay;double mobileDecay=std::min(c.dissolvedCarbon,.03);c.dissolvedCarbon-=mobileDecay;ledger.respiration+=mobileDecay;}
 // Shared uptake is staged then proportionally allocated, independent of plant order.
 struct Demand {std::size_t plant;unsigned cell;double water,nutrient;};std::vector<Demand> demands;std::vector<double> wd(surface.cells.size()),nd(surface.cells.size());
 for(std::size_t i=0;i<plants.size();++i){auto& p=plants[i];if(p.stage==2)continue;for(auto& o:p.organs)if(!o.dead&&o.kind==Kind::Root){auto c=cell(p.position+o.end);if(c>=surface.cells.size())continue;double w=std::max(0.,5-p.water)*.035,n=std::max(0.,1.5-p.nutrients)*.012;demands.push_back({i,c,w,n});wd[c]+=w;nd[c]+=n;}}
 std::vector<double> ws(wd.size(),1),ns(nd.size(),1);for(unsigned c=0;c<wd.size();++c){if(wd[c]>0)ws[c]=std::min(1.,surface.cells[c].water/wd[c]);if(nd[c]>0)ns[c]=std::min(1.,surface.cells[c].nutrients/nd[c]);}
 for(auto d:demands){double w=d.water*ws[d.cell],n=d.nutrient*ns[d.cell];plants[d.plant].water+=w;plants[d.plant].nutrients+=n;surface.cells[d.cell].water-=w;surface.cells[d.cell].nutrients-=n;}
 const auto initial=plants.size();for(std::size_t i=0;i<initial;++i){auto& p=plants[i];const bool alreadyDead=p.stage==2;++p.age;auto c=cell(p.position);
  p.fluxValid=false;
  if(p.stage==2){for(auto& o:p.organs)o.dead=true;if(p.job.active){p.carbon+=p.job.carbon;p.nutrients+=p.job.carbon*.05;p.job={};}}
  if(p.stage!=2){double intake=0,leafWeight=0;for(auto& o:p.organs)if(!o.dead&&o.kind==Kind::Leaf){intake+=o.mass*p.genome.leafArea*light(p,o)*.22*o.health;leafWeight+=o.mass*p.genome.leafArea*o.health;}
   p.flux={intake,0,0,0,leafWeight>0?intake/(leafWeight*.22):0,std::min(1.,p.water),std::min(1.,p.nutrients*5),0};p.fluxValid=true;
   intake*=std::min(1.,p.water)*std::min(1.,p.nutrients*5);p.flux[0]=intake;if(assimilateCarbon)intake=assimilateCarbon(intake);p.flux[1]=intake;p.carbon+=intake;ledger.assimilation+=intake;
   double use=std::min(p.water,.003+intake*.12*p.genome.waterLoss);p.water-=use;ledger.waterOut+=use;
   double cost=(p.stage==0?.0015:.008+.004*mass(p)*p.genome.wood);double paid=std::min(p.carbon,cost);p.carbon-=paid;ledger.respiration+=paid;
   p.flux[2]=cost;p.flux[3]=paid;
   if(paid<cost||p.water<.005)p.health-=.025;else p.health=std::min(1.,p.health+.002);
   // Species life history in plant steps (three world ticks each). Avoid
   // synchronizing all founders to the same fixed 4,000-step death cliff.
   const double lifespan=p.genome.species==1?60000.:p.genome.species==2?12000.:6000.;
   const double ageStress=std::max(0.,double(p.age)/lifespan-1.);
   p.flux[7]=ageStress;
   if(ageStress>0)p.health-=std::min(.02,.0025*ageStress);
   if(p.health<=0){p.stage=2;p.health=0;for(auto& o:p.organs)o.dead=true;if(p.job.active){p.carbon+=p.job.carbon;p.nutrients+=p.job.carbon*.05;p.job={};}p.decision.result="biological-death";
    events.push_back("{\"tick\":"+std::to_string(tick)+",\"kind\":\"death\",\"id\":"+std::to_string(p.id)+"}");}
  }
  if(p.stage==1){
   std::set<unsigned> failed;
   for(auto& o:p.organs)if(!o.dead){
    double load=0;for(auto& child:p.organs)if(child.parent==o.id&&!child.dead)load+=child.mass;
    if((o.kind==Kind::Leaf&&p.water<.05)||(o.kind==Kind::Stem&&load>o.mass*p.genome.wood*8))o.health=std::max(0.,o.health-.01);
    if(o.health==0)failed.insert(o.id);
   }
   bool changed=true;while(changed){changed=false;for(auto& o:p.organs)if(failed.count(o.parent)&&!failed.count(o.id)){failed.insert(o.id);changed=true;}}
   for(auto& o:p.organs)if(failed.count(o.id)&&!o.dead){o.dead=true;++p.revision;}
  }
  if(p.job.active&&p.job.action!=Action::Germinate){auto* site=organ(p,p.job.site);
   if(!site||site->dead){p.carbon+=p.job.carbon;p.nutrients+=p.job.carbon*.05;p.job={};p.decision.result="job-cancelled-site-lost";}
  }
  double detachedCarbon=0;for(auto& o:p.organs)if(o.dead&&o.mass>0){detachedCarbon+=o.mass;// Detachment transfers ownership once; soil litter decomposes independently.
   surface.cells[c].litter+=o.mass;o.mass=0;++p.revision;}
  if(p.stage==2){
   double structural=detachedCarbon;
   history.push_back({p.id,p.lineage,p.genome.species,alreadyDead?0:p.age,alreadyDead?0:tick,p.carbon+structural});
   // Mobile carbon decomposes separately: it has no structural nutrient ratio.
   surface.cells[c].dissolvedCarbon+=p.carbon;p.carbon=0;
   surface.cells[c].nutrients+=p.nutrients;p.nutrients=0;
   surface.cells[c].water+=p.water;p.water=0;continue;
  }
  if(p.job.active)grow(p);else if((tick+p.id)%4==0){decide(p);
   events.push_back("{\"tick\":"+std::to_string(tick)+",\"kind\":\"decision\",\"id\":"+std::to_string(p.id)+",\"action\":\""+actionName(p.decision.requested)+"\",\"result\":\""+p.decision.result+"\",\"site\":"+std::to_string(p.decision.site)+",\"investment\":"+std::to_string(p.decision.investment)+"}");
  }
 }
 for(auto& p:plants){
  bool changed=true;while(changed){changed=false;for(auto it=p.organs.begin();it!=p.organs.end();++it){if(!it->dead||it->mass>1e-9)continue;bool parent=false;for(auto& o:p.organs)if(o.parent==it->id){parent=true;break;}if(!parent){p.organs.erase(it);++p.revision;changed=true;break;}}}
 }
 if(returnCarbon)returnCarbon(ledger.respiration-respirationBefore);
 plants.erase(std::remove_if(plants.begin(),plants.end(),[](const Plant& p){if(p.stage!=2||p.carbon>1e-9)return false;for(auto& o:p.organs)if(o.mass>1e-9)return false;return true;}),plants.end());
}
double World::carbonTotal()const{double v=0;for(auto& c:surface.cells)v+=c.litter+c.dissolvedCarbon;for(auto& p:plants){v+=p.carbon+p.job.carbon;for(auto& o:p.organs)v+=o.mass;}return v;}
double World::nutrientTotal()const{double v=0;for(auto& c:surface.cells)v+=c.nutrients+c.litter*.05;for(auto& p:plants){v+=p.nutrients+p.job.carbon*.05;for(auto& o:p.organs)v+=o.mass*.05;}return v;}
double World::waterTotal()const{double v=0;for(auto& c:surface.cells)v+=c.water;for(auto& p:plants)v+=p.water;return v;}
void World::validate()const {
 need(surface.width>0&&surface.height>0&&surface.width<=128&&surface.height<=128&&surface.cells.size()==surface.width*surface.height,"Surface shape");
 need(finite(surface.cellSize)&&surface.cellSize>0&&finite(surface.originX)&&finite(surface.originZ),"Surface coordinates");
 need(run.size()<100&&!run.empty()&&run.find_first_not_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")==std::string::npos,"Run identity");
 need(plants.size()<=MaxPlants&&nextId>0&&rng!=0&&finite(daylight)&&daylight>=0&&daylight<=1&&finite(rainfall)&&rainfall>=0&&rainfall<=10,"World limits");
 for(auto& c:surface.cells)need(finite(c.height)&&finite(c.depth)&&c.depth>0&&finite(c.water)&&c.water>=-1e-8&&finite(c.nutrients)&&c.nutrients>=-1e-8&&finite(c.litter)&&c.litter>=0&&finite(c.dissolvedCarbon)&&c.dissolvedCarbon>=0,"Invalid soil");
 need(history.size()<=1000000,"History checkpoint budget");
 std::set<unsigned> ids;
 for(auto& p:plants){need(p.id>0&&p.id<nextId&&ids.insert(p.id).second&&p.stage<=2&&unsigned(p.policy)<=2&&p.genome.version==1&&p.genome.species<3,"Plant identity/schema");need(p.organs.size()<=MaxOrgans&&finite(length(p.position))&&cell(p.position)<surface.cells.size(),"Plant shape/location");
  need(finite(p.carbon)&&p.carbon>=-1e-8&&finite(p.water)&&p.water>=-1e-8&&finite(p.nutrients)&&p.nutrients>=-1e-8&&finite(p.health)&&p.health>=0&&p.health<=1,"Plant reserves");
  for(auto w:p.genome.weights){need(finite(w)&&std::abs(w)<=20,"Genome weight");}
  for(auto m:p.memory){need(finite(m)&&std::abs(m)<=1,"Controller memory");}
  need(p.genome.angle>=.2&&p.genome.angle<=1.2&&p.genome.elongation>=.5&&p.genome.elongation<=1.8&&p.genome.leafArea>=.35&&p.genome.leafArea<=1.6&&p.genome.wood>=.6&&p.genome.wood<=2.4&&p.genome.waterLoss>=.35&&p.genome.waterLoss<=1.6&&p.genome.maturity>=20&&p.genome.maturity<=160&&p.genome.hue>=0&&p.genome.hue<=1,"Trait bounds");
  std::set<unsigned> organs;
  for(auto& o:p.organs){need(o.id>0&&o.id<p.nextOrgan&&(!o.parent||organs.count(o.parent))&&organs.insert(o.id).second&&unsigned(o.kind)<=3,"Organ topology");need(finite(length(o.start))&&finite(length(o.end))&&finite(o.mass)&&o.mass>=0&&finite(o.radius)&&o.radius>0&&o.health>=0&&o.health<=1,"Organ state");}
  need(unsigned(p.job.action)<=10&&finite(p.job.carbon)&&p.job.carbon>=0&&finite(length(p.job.direction)),"Job state");
  if(p.job.active)need(p.job.remaining>0&&p.job.remaining<=4&&(p.job.action==Action::Germinate||organs.count(p.job.site)),"Job reference");
  else need(p.job.carbon==0,"Unowned reservation");
 }
 const double carbonExpected=ledger.founderCarbon+ledger.assimilation-ledger.respiration;
 need(std::abs(carbonTotal()-carbonExpected)<1e-6*std::max(1.,ledger.founderCarbon+ledger.assimilation),"Carbon conservation");
 need(std::abs(nutrientTotal()-ledger.initialNutrients-ledger.nutrientInput)<1e-6*std::max(1.,ledger.initialNutrients+ledger.nutrientInput),"Nutrient conservation");
 need(std::abs(waterTotal()-ledger.initialWater-ledger.rain+ledger.waterOut)<1e-6*std::max(1.,ledger.initialWater+ledger.rain),"Water conservation");
}
std::string World::checkpoint()const {validate();std::ostringstream s;s.imbue(std::locale::classic());s<<std::setprecision(17);
 s<<rng<<' '<<tick<<' '<<nextId<<' '<<revision<<' '<<run<<' '<<rainfall<<' '<<daylight<<' '<<mutation<<'\n';
 s<<surface.width<<' '<<surface.height<<' '<<surface.originX<<' '<<surface.originZ<<' '<<surface.cellSize<<' '<<surface.revision<<'\n';
 for(auto& c:surface.cells)s<<c.height<<' '<<c.depth<<' '<<c.water<<' '<<c.nutrients<<' '<<c.litter<<' '<<c.valid<<' '<<c.dissolvedCarbon<<'\n';
 s<<ledger.founderCarbon<<' '<<ledger.assimilation<<' '<<ledger.respiration<<' '<<ledger.rain<<' '<<ledger.waterOut<<' '<<ledger.nutrientInput<<' '<<ledger.initialWater<<' '<<ledger.initialNutrients<<'\n'<<plants.size()<<'\n';
 for(auto& p:plants){s<<p.id<<' '<<p.parent<<' '<<p.lineage<<' '<<p.generation<<' '<<p.age<<' '<<p.nextOrgan<<' '<<p.revision<<' '<<p.mutations<<' '<<p.cursor<<' '<<p.mutationDistance;vec(s,p.position);s<<' '<<p.stage<<' '<<p.carbon<<' '<<p.water<<' '<<p.nutrients<<' '<<p.health<<' '<<unsigned(p.policy)<<'\n';
  auto& g=p.genome;s<<g.version<<' '<<g.species<<' '<<g.angle<<' '<<g.elongation<<' '<<g.leafArea<<' '<<g.wood<<' '<<g.waterLoss<<' '<<g.maturity<<' '<<g.hue<<'\n';for(auto v:g.weights)s<<v<<' ';s<<'\n';for(auto v:p.memory)s<<v<<' ';s<<'\n';
  auto& j=p.job;s<<j.active<<' '<<unsigned(j.action)<<' '<<j.site<<' '<<j.carbon<<' '<<j.remaining;vec(s,j.direction);s<<'\n';
  auto& d=p.decision;s<<unsigned(d.requested)<<' '<<d.site<<' '<<d.investment<<' '<<d.result<<'\n';for(auto x:d.inputs)s<<x<<' ';s<<'\n';
  s<<p.organs.size()<<'\n';for(auto& o:p.organs){s<<o.id<<' '<<o.parent<<' '<<unsigned(o.kind);vec(s,o.start);vec(s,o.end);s<<' '<<o.radius<<' '<<o.mass<<' '<<o.health<<' '<<o.dead<<'\n';}
 }
 s<<"HISTORY1 "<<retiredRecords<<' '<<history.size()<<'\n';
 for(const auto& d:history)s<<d.id<<' '<<d.lineage<<' '<<d.species<<' '<<d.age<<' '<<d.tick<<' '<<d.carbon<<'\n';
 auto body=s.str();return "CIPLANTS2 "+std::to_string(hash(body))+"\n"+body;
}
World World::restore(const std::string& text){need(text.size()<64*1024*1024,"Checkpoint too large");auto nl=text.find('\n');need(nl!=std::string::npos,"Checkpoint header");std::istringstream header(text.substr(0,nl));std::string magic;std::uint64_t checksum;need(bool(header>>magic>>checksum)&&(magic=="CIPLANTS1"||magic=="CIPLANTS2")&&hash(std::string_view(text).substr(nl+1))==checksum,"Checkpoint checksum/schema");std::istringstream s(text.substr(nl+1));s.imbue(std::locale::classic());World w;
 s>>w.rng>>w.tick>>w.nextId>>w.revision>>w.run>>w.rainfall>>w.daylight>>w.mutation;
 auto& f=w.surface;s>>f.width>>f.height>>f.originX>>f.originZ>>f.cellSize>>f.revision;need(bool(s)&&f.width>0&&f.height>0&&f.width<=128&&f.height<=128,"Checkpoint surface budget");f.cells.resize(f.width*f.height);
 for(auto& c:f.cells){s>>c.height>>c.depth>>c.water>>c.nutrients>>c.litter>>c.valid;if(magic=="CIPLANTS2")s>>c.dissolvedCarbon;}
 auto& l=w.ledger;s>>l.founderCarbon>>l.assimilation>>l.respiration>>l.rain>>l.waterOut>>l.nutrientInput>>l.initialWater>>l.initialNutrients;unsigned n;s>>n;need(bool(s)&&n<=MaxPlants,"Checkpoint plant budget");w.plants.resize(n);
 for(auto& p:w.plants){unsigned policy;s>>p.id>>p.parent>>p.lineage>>p.generation>>p.age>>p.nextOrgan>>p.revision>>p.mutations>>p.cursor>>p.mutationDistance;vec(s,p.position);s>>p.stage>>p.carbon>>p.water>>p.nutrients>>p.health>>policy;p.policy=Policy(policy);
  auto& g=p.genome;s>>g.version>>g.species>>g.angle>>g.elongation>>g.leafArea>>g.wood>>g.waterLoss>>g.maturity>>g.hue;for(auto& v:g.weights)s>>v;for(auto& v:p.memory)s>>v;
  unsigned action;auto& j=p.job;s>>j.active>>action>>j.site>>j.carbon>>j.remaining;vec(s,j.direction);j.action=Action(action);
  auto& d=p.decision;s>>action>>d.site>>d.investment>>d.result;d.requested=Action(action);for(auto& x:d.inputs)s>>x;
  unsigned count;s>>count;need(bool(s)&&count<=MaxOrgans,"Checkpoint organ budget");p.organs.resize(count);for(auto& o:p.organs){unsigned kind;s>>o.id>>o.parent>>kind;vec(s,o.start);vec(s,o.end);s>>o.radius>>o.mass>>o.health>>o.dead;o.kind=Kind(kind);}
 }
 if(magic=="CIPLANTS2"){
  std::string tag;unsigned records=0;s>>tag>>w.retiredRecords>>records;
  need(bool(s)&&tag=="HISTORY1"&&records<=1000000,"Checkpoint history budget");
  w.history.resize(records);for(auto& d:w.history){s>>d.id>>d.lineage>>d.species>>d.age>>d.tick>>d.carbon;
   need(d.id>0&&d.id<w.nextId&&d.lineage>0&&d.lineage<w.nextId&&d.species<3&&d.tick<=w.tick&&finite(d.carbon)&&d.carbon>=0,"Invalid history");}
 }
 need(bool(s),"Checkpoint truncated");std::string extra;need(!(s>>extra),"Checkpoint trailing bytes");w.validate();return w;
}
void World::loadSurface(const std::string& text){need(plants.empty(),"Load terrain before founders");std::istringstream s(text);s.imbue(std::locale::classic());std::string magic;Surface f;s>>magic>>f.revision>>f.width>>f.height>>f.originX>>f.originZ>>f.cellSize;
 need(bool(s)&&magic=="CIPLANTSURFACE1"&&f.width>0&&f.height>0&&f.width<=128&&f.height<=128&&f.revision.size()<80&&f.revision.find_first_not_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")==std::string::npos,"Surface header");f.cells.resize(f.width*f.height);double w=0,n=0;for(auto& c:f.cells){s>>c.height>>c.depth>>c.water>>c.nutrients>>c.valid;w+=c.water;n+=c.nutrients;}need(bool(s),"Surface truncated");std::string extra;need(!(s>>extra),"Surface trailing data");surface=std::move(f);ledger.initialWater=w;ledger.initialNutrients=n;validate();}
std::string World::snapshot()const {std::ostringstream s;s.imbue(std::locale::classic());s<<std::setprecision(9);
 s<<"{\"schema\":1,\"run\":\""<<run<<"\",\"revision\":"<<revision<<",\"tick\":"<<tick<<",\"surface\":\""<<surface.revision<<"\",\"units\":\"studs-Y-up\",\"plants\":[";
 bool first=true;for(auto& p:plants){if(!first)s<<',';first=false;
 double structure=0;for(const auto& o:p.organs)structure+=o.mass;
 const double required=std::min(p.decision.investment,p.decision.requested==Action::Seed?8.:2.);
 s<<"{\"id\":"<<p.id<<",\"parent\":"<<p.parent<<",\"lineage\":"<<p.lineage<<",\"generation\":"<<p.generation<<",\"species\":"<<p.genome.species<<",\"stage\":"<<p.stage<<",\"revision\":"<<p.revision<<",\"age\":"<<p.age<<",\"position\":["<<p.position.x<<','<<p.position.y<<','<<p.position.z<<"],\"resources\":["<<p.carbon<<','<<p.water<<','<<p.nutrients<<','<<p.health<<"],\"hue\":"<<p.genome.hue<<",\"leafArea\":"<<p.genome.leafArea<<",\"policy\":"<<unsigned(p.policy)<<",\"mutations\":"<<p.mutations<<",\"action\":\""<<actionName(p.decision.requested)<<"\",\"result\":\""<<p.decision.result<<"\",\"site\":"<<p.decision.site<<",\"investment\":"<<p.decision.investment<<",\"job\":["<<p.job.active<<','<<unsigned(p.job.action)<<','<<p.job.site<<','<<p.job.carbon<<','<<p.job.remaining<<"],\"inputs\":[";
 for(unsigned i=0;i<Inputs;++i){if(i)s<<',';s<<p.decision.inputs[i];}s<<"],\"organs\":[";bool f=true;for(auto& o:p.organs){if(!f)s<<',';f=false;s<<'['<<o.id<<','<<o.parent<<','<<unsigned(o.kind)<<','<<o.start.x<<','<<o.start.y<<','<<o.start.z<<','<<o.end.x<<','<<o.end.y<<','<<o.end.z<<','<<o.radius<<','<<o.mass<<','<<o.health<<','<<o.dead<<']';}s<<"],\"structureCarbon\":"<<structure<<",\"growthCost\":["<<required<<','<<required*.1<<','<<required*.05<<"],\"fluxValid\":"<<(p.fluxValid?"true":"false")<<",\"flux\":[";
 for(unsigned i=0;i<p.flux.size();++i){if(i)s<<',';s<<p.flux[i];}s<<"]}";
 }
 s<<"],\"litter\":[";bool firstLitter=true;
 for(unsigned i=0;i<surface.cells.size();++i){const auto& c=surface.cells[i];if(c.litter<=1e-9)continue;
  if(!firstLitter){s<<',';}firstLitter=false;
  s<<'['<<i<<','<<surface.originX+(i%surface.width+.5)*surface.cellSize<<','<<c.height<<','<<surface.originZ+(i/surface.width+.5)*surface.cellSize<<','<<c.litter<<']';
 }
 s<<"],\"deathCount\":"<<retiredRecords+history.size()<<",\"environment\":{\"daylight\":"<<daylight<<",\"atmosphericCarbon\":";
 if(atmosphereCarbon)s<<atmosphereCarbon();else s<<"null";
 s<<",\"assimilationTotal\":"<<ledger.assimilation<<",\"respirationTotal\":"<<ledger.respiration<<"},\"ledger\":{\"carbon\":"<<carbonTotal()<<",\"carbonExpected\":"<<ledger.founderCarbon+ledger.assimilation-ledger.respiration<<",\"water\":"<<waterTotal()<<",\"nutrients\":"<<nutrientTotal()<<"}}";return s.str();}
}
