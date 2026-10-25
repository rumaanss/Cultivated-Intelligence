#include "cybernet/aquatic/stage3.hpp"
#include "json.hpp"
#include <algorithm>
#include <cmath>
#include <iostream>
#include <stdexcept>
using namespace cybernet::aquatic::stage3;
using namespace cybernet::aquatic;
using J=nlohmann::json;
static void check(bool b,const char *s){if(!b)throw std::runtime_error(s);}
static bool near(double a,double b){return std::abs(a-b)<1e-9*std::max({1.,std::abs(a),std::abs(b)});}
static double intake(const Physiology &w,unsigned guild){double s=0;for(const auto &c:w.colonies)if(c.guild==guild)s+=c.ingested;return s;}
static Physiology fixture(){PhysiologyConfig cfg;cfg.mortalityPerDay=0;cfg.mutationProbability=0;Physiology w(42,cfg);
 for(auto &c:w.colonies){c.protein[Capture]=c.protein[Digestion]=c.structure*.00325;c.reserve.c=0;}
 return w;
}
static void balance(const Totals &a,const Totals &b){check(near(a.carbon,b.carbon)&&near(a.nitrogen,b.nitrogen)&&near(a.phosphorus,b.phosphorus),"Control transfer changed C/N/P totals");}
int main(){try{
 {auto w=fixture();auto before=w.totals();w.step(false,false,0);balance(before,w.totals());check(intake(w,3)>0&&intake(w,4)>0,"Consumers did not ingest compatible living prey");}
 {auto w=fixture();std::erase_if(w.colonies,[](auto &c){return c.guild<3;});auto before=w.totals();w.step(false,false,0);balance(before,w.totals());check(intake(w,3)==0&&intake(w,4)==0,"Consumers ate macroalgae or each other");}
 {auto w=fixture();for(auto &c:w.environment.cells)c.m[O2]=0;w.step(false,false,0);check(intake(w,3)==0&&intake(w,4)==0,"Feeding without oxygen");}
 {auto w=fixture();std::erase_if(w.colonies,[](auto &c){return c.guild!=3&&c.guild!=4;});
  double before=0;for(const auto &c:w.colonies)before+=w.material(c).c;
  for(unsigned t=0;t<3000;++t)w.step(false,false,0);
  double after=0;for(const auto &c:w.colonies)after+=w.material(c).c;
  check(after<before*.9 && w.births==0 && intake(w,3)==0&&intake(w,4)==0,"Unfed consumers sustained growth from nonexistent food");
 }
 {auto a=fixture(),b=a;std::reverse(b.colonies.begin(),b.colonies.end());a.step(false,false,0);b.step(false,false,0);
  check(near(intake(a,3),intake(b,3))&&near(intake(a,4),intake(b,4)),"Consumer order biased ingestion");
  for(const auto &c:a.colonies)if(c.guild==3||c.guild==4){auto it=std::find_if(b.colonies.begin(),b.colonies.end(),[&](auto &q){return q.id==c.id;});check(it!=b.colonies.end()&&near(c.ingested,it->ingested),"Individual allocation order bias");}
 }
 {auto w=fixture();auto before=w.totals();double tissue=0;for(auto &c:w.colonies)if(c.guild==5)tissue+=c.structure;
  w.step(false,false,0);balance(before,w.totals());double after=0;for(auto &c:w.colonies)if(c.guild==5){after+=c.structure;double paid=0;for(auto &n:c.segments)paid+=n.carbon;check(near(paid,c.structure),"Unpaid algae after senescence");}
  check(after<tissue,"Dark algal tissue did not turn over");
 }
 {auto w=fixture();for(auto &c:w.colonies)if(c.guild==5){
    c.structure=2*c.target;c.dna*=2;c.reserve={2*c.structure,.5*c.structure,.05*c.structure};c.protein[Attachment]=c.structure*.001625;
  }
  auto before=w.totals();w.step(false,false,1);balance(before,w.totals());std::array<bool,4> reproduced{};
  for(const auto &c:w.colonies)if(c.guild==5&&c.parent)reproduced[w.genomes[c.genome-1].form]=true;
  for(bool born:reproduced)check(born,"Paid mature algae cannot divide while shedding tissue");
  auto packet=J::parse(w.snapshot("birth-visibility"));std::vector<std::uint64_t> shown;for(const auto &r:packet["colonies"])shown.push_back(r[2]);
  std::array<bool,4> visibleFamilies{};
  for(const auto &c:w.colonies)if(c.guild==5&&c.parent&&std::find(shown.begin(),shown.end(),c.parent)!=shown.end()&&std::find(shown.begin(),shown.end(),c.id)!=shown.end())visibleFamilies[w.genomes[c.genome-1].form]=true;
  for(bool visible:visibleFamilies)check(visible,"Native sample never shows an algae parent/daughter pair for a form");
 }
 {Physiology w(42);for(unsigned t=0;t<2400;++t)w.step();w.validate();auto restored=Physiology::restore(w.checkpoint(),42);check(restored.checkpoint()==w.checkpoint(),"Morphology/budgets did not persist");
  bool fork=false;for(const auto &c:w.colonies)if(c.guild==5){std::vector<unsigned> children(c.nextSegment);for(auto &n:c.segments)if(n.parent && ++children[n.parent]>1)fork=true;}
  check(fork,"Algae never formed an actual fork");auto report=J::parse(w.report());for(double x:report["maxResidual"])check(x<1e-6,"Food budget residual");
  auto bad=w.checkpoint();auto envelope=J::parse(bad);auto payload=J::parse(envelope["payload"].get<std::string>());payload["shapes"][0][1]=J::array({J::array({1,7,0,1,1,1,0})});
  auto text=payload.dump();std::uint64_t hash=1469598103934665603ULL;for(unsigned char c:text){hash^=c;hash*=1099511628211ULL;}envelope["payload"]=text;envelope["checksum"]=std::to_string(hash);
  bool rejected=false;try{auto invalid=Physiology::restore(envelope.dump(),42);(void)invalid;}catch(...){rejected=true;}check(rejected,"Malformed topology accepted");
 }
 std::cout<<"PASS compatible feeding, diet exclusions, oxygen limitation, conservative transfers, allocation order, tissue turnover, paid forks, persistence and malformed topology\n";
 return 0;
}catch(const std::exception &e){std::cerr<<e.what()<<'\n';return 1;}}
