#include "cybernet/aquatic/stage3.hpp"
#include <array>
#include <iostream>
#include <stdexcept>
using namespace cybernet::aquatic::stage3;
void require(bool b,const char *m){if(!b)throw std::runtime_error(m);}
double producers(const Physiology&w){double mass=0;for(const auto &c:w.colonies)if(c.guild<2||c.guild==5)mass+=w.material(c).c;return mass;}
int main(){try{
 Physiology w(77);for(unsigned t=0;t<3000;++t)w.step();w.validate();
 auto production=w.environment.cumulative.production;double mass=producers(w);
 for(unsigned t=0;t<2400;++t)w.step(true,true,0);w.validate();
 require(w.environment.cumulative.production==production,"Photosynthesis during total blackout");
 require(producers(w)<mass,"Blackout did not consume producer material");
 auto checkpoint=w.checkpoint();w=Physiology::restore(checkpoint,77);
 for(unsigned t=0;t<6000;++t)w.step();w.validate();
 require(w.environment.cumulative.production>production,"Photosynthesis did not resume after light returned");
 std::array<unsigned,6> counts{};std::array<unsigned,4> forms{};for(const auto &c:w.colonies){++counts[c.guild];if(c.guild==5)++forms[w.genomes[c.genome-1].form];}
 for(auto n:counts)require(n>0,"Guild lost during bounded blackout control");for(auto n:forms)require(n>0,"Algal form lost during bounded blackout control");
 require(w.births>0&&w.deaths>0,"No demographic turnover");
 std::cout<<"PASS four-day blackout: no fixation, declining producer material, exact saved state, fixation resumes and all guilds/forms persist through ten-day recovery observation; not proof of complete recovery\n";
 return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}}
