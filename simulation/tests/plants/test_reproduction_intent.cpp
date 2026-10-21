#include "cybernet/world/ecology.hpp"
#include "cybernet/simulation/spawning.hpp"
#include "cybernet/simulation/run_options.hpp"
#include <iostream>
#include <stdexcept>
using namespace cybernet;
void check(bool b,const char* m){if(!b)throw std::runtime_error(m);}
Organism ready(float bias){Organism o;Random random(5);spawnOrganism(o,1,OrganismType::Cyanobacteria,{20,20,10},0,0,random);o.energy=o.profile().reproductionEnergy+10;o.ageTicks=o.profile().minimumReproductionAgeTicks;o.genome.fill(0);
 constexpr auto offset=RnnBrain::InputWeightsSize+RnnBrain::RecurrentWeightsSize+RnnBrain::HiddenBiasesSize+RnnBrain::OutputWeightsSize;
 o.genome[offset+actionIndex(BrainAction::ReproduceIntentV2)]=bias;o.initializeBrain();(void)o.brain.step({});return o;}
int main(){try{Random random(1);unsigned next=2;Ecology e;
 std::vector<Organism> p{ready(-1)};auto changes=e.processPopulation(p,1,next,random);check(changes.births==1,"legacy changed");
 e.setReproductionIntentV2(true);p={ready(-1)};changes=e.processPopulation(p,1,next,random);check(changes.births==0,"eligible without intent reproduced");
 p={ready(1)};changes=e.processPopulation(p,2,next,random);check(changes.births==1,"explicit intent did not reproduce");
 p={ready(1)};p[0].energy=1;changes=e.processPopulation(p,3,next,random);check(changes.births==0,"unfunded reproduced");
 char a[]="sim",b[]="--reproduction",c[]="intent-v2";char* args[]={a,b,c};auto options=parseRunOptions(3,args);check(options.valid()&&options.options.reproductionIntentV2,"policy option");
 std::cout<<"PASS legacy-v1 unchanged; intent-v2 needs both neural intent and eligibility; CLI parsed\n";
}catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}}
