#include "cybernet/aquatic/stage3.hpp"
#include "json.hpp"
#include <filesystem>
#include <fstream>
#include <iostream>
#include <chrono>
#include <algorithm>
using namespace cybernet::aquatic::stage3;using J=nlohmann::json;
int main(int argc,char **argv){try{
 if(argc<5)throw std::runtime_error("validate_stage3 SEED END_TICK CHECKPOINT MUTATION [SUNLIGHT]");
 auto seed=std::stoull(argv[1]),end=std::stoull(argv[2]);std::filesystem::path path=argv[3];PhysiologyConfig cfg;cfg.mutationProbability=std::stod(argv[4]);
 double sunlight=argc>5?std::stod(argv[5]):-1;
 Physiology w(seed,cfg);
 if(std::filesystem::exists(path)){std::ifstream f(path);w=Physiology::restore(std::string{std::istreambuf_iterator<char>(f),{}},seed);if(w.config.mutationProbability!=cfg.mutationProbability)throw std::runtime_error("Config mismatch");}
 auto save=[&](){
  auto temp=path;temp+=".tmp";auto backup=path;backup+=".previous";
  {std::ofstream f(temp);f<<w.checkpoint();f.flush();if(!f)throw std::runtime_error("Checkpoint write");}
  if(std::filesystem::exists(path))std::filesystem::copy_file(path,backup,std::filesystem::copy_options::overwrite_existing);
  std::filesystem::copy_file(temp,path,std::filesystem::copy_options::overwrite_existing);std::filesystem::remove(temp);
 };
 std::vector<double> times;auto previous=w.environment.tick;
 while(w.environment.tick<end){auto t=std::chrono::steady_clock::now();w.step(true,true,sunlight);times.push_back(std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-t).count());
  if(w.colonies.size()>=cfg.maximumColonies)throw std::runtime_error("Population cap reached");
  if(w.environment.tick%500==0)w.validate();
  if(w.environment.tick%5000==0)save();
  if(w.environment.tick%1000==0){std::array<unsigned,6> counts{};std::array<double,6> mass{},intake{},represented{};std::array<unsigned,4> forms{},formBirths{},formDeaths{};std::array<unsigned,6> births{},deaths{};
   for(const auto &a:w.ancestry){auto id=a.genome;while(w.genomes[id-1].parent)id=w.genomes[id-1].parent;unsigned guild=id<=5?unsigned(id-1):5;if(a.parent)++births[guild];if(a.died)++deaths[guild];if(id>=6&&id<=9){if(a.parent)++formBirths[id-6];if(a.died)++formDeaths[id-6];}}
   for(const auto &c:w.colonies){++counts[c.guild];mass[c.guild]+=w.material(c).c;intake[c.guild]+=c.ingested;represented[c.guild]+=c.represented;if(c.guild==5)++forms[w.genomes[c.genome-1].form];}
   std::cout<<J{{"seed",seed},{"mutation",cfg.mutationProbability},{"tick",w.environment.tick},{"counts",counts},{"biomass",mass},{"represented",represented},{"forms",forms},{"formBirths",formBirths},{"formDeaths",formDeaths},{"intake",intake},{"births",w.births},{"deaths",w.deaths},{"guildBirths",births},{"guildDeaths",deaths},{"mutations",w.mutations},{"ledger",J::parse(w.report(false))["maxResidual"]}}.dump()<<std::endl;
  }
 }
 w.validate();save();
 std::ofstream(path.string()+".snapshot.json")<<w.snapshot("stage3-validation");std::ofstream(path.string()+".report.json")<<w.report();
 std::sort(times.begin(),times.end());std::cout<<J{{"segmentStart",previous},{"segmentEnd",end},{"p95StepMs",times.empty()?0:times[std::min(times.size()-1,std::size_t(times.size()*.95))]}}.dump()<<std::endl;
 return 0;
}catch(const std::exception &e){std::cerr<<e.what()<<'\n';return 1;}}
