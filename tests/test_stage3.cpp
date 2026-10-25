#include "cybernet/aquatic/stage3.hpp"
#include "cybernet/aquatic/physiology.hpp"
#include "json.hpp"
#include <iostream>
#include <fstream>
#include <filesystem>
using namespace cybernet::aquatic::stage3;
using J=nlohmann::json;
void require(bool b,const char *why){if(!b)throw std::runtime_error(why);}
int main(int argc,char **argv){try{
  Physiology w(argc>1?std::stoull(argv[1]):42);
  unsigned ticks=argc>2?std::stoul(argv[2]):1800;
  for(unsigned t=0;t<ticks;++t){w.step();if(t%100==0)w.validate();}
  w.validate();auto report=J::parse(w.report());
  for(double x:report["maxResidual"])require(std::abs(x)<1e-6,"Local food ledger residual");
  auto checkpoint=w.checkpoint();auto next=Physiology::restore(checkpoint,w.environment.seed);
  require(next.checkpoint()==checkpoint,"Exact Stage 3 checkpoint roundtrip");
  for(unsigned i=0;i<50;++i){w.step();next.step();}
  require(w.checkpoint()==next.checkpoint(),"Exact Stage 3 stochastic continuation");
  std::array<unsigned,6> counts{};std::array<double,6> mass{},food{};std::array<unsigned,4> forms{};
  for(const auto &c:w.colonies){++counts[c.guild];mass[c.guild]+=w.material(c).c;food[c.guild]+=c.ingested;if(c.guild==5)++forms[w.genomes[c.genome-1].form];}
  std::cout<<J{{"tick",w.environment.tick},{"counts",counts},{"biomass",mass},{"ingested",food},{"forms",forms},{"births",w.births},{"deaths",w.deaths},{"mutations",w.mutations},{"reportResidual",report["maxResidual"]}}.dump()<<'\n';
  if(argc>3){std::ofstream(argv[3])<<w.checkpoint();std::ofstream(std::string(argv[3])+".report.json")<<w.report();std::ofstream(std::string(argv[3])+".snapshot.json")<<w.snapshot("stage3-test");}
  if(argc==1){require(food[3]>0&&food[4]>0,"Both consumers must eat living prey");
    cybernet::aquatic::Physiology old(42);for(unsigned i=0;i<100;++i)old.step();
    auto oldBytes=old.checkpoint();auto upgraded=Physiology::migrateStage2(oldBytes,42);upgraded.validate();
    require(old.checkpoint()==oldBytes,"Migration changed source world");
    auto a=old.totals(),b=upgraded.totals();std::cout<<"Migration C/N/P delta "<<a.carbon-b.carbon<<","<<a.nitrogen-b.nitrogen<<","<<a.phosphorus-b.phosphorus<<"\n";
    require(std::abs(a.carbon-b.carbon)<1e-10*std::max(1.,a.carbon)&&std::abs(a.nitrogen-b.nitrogen)<1e-10*std::max(1.,a.nitrogen)&&std::abs(a.phosphorus-b.phosphorus)<1e-10*std::max(1.,a.phosphorus),"Migration added material");
  }
  return 0;
}catch(const std::exception &e){std::cerr<<e.what()<<'\n';return 1;}}
