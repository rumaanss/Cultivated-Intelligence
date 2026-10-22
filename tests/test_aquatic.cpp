#include "cybernet/aquatic/lake.hpp"
#include <chrono>
#include <cmath>
#include <iostream>
#include <stdexcept>
using namespace cybernet::aquatic;
void check(bool b,const char* message){if(!b)throw std::runtime_error(message);}
double pool(const Lake& w,int k){double n=0;for(auto&c:w.cells)n+=c.m[k];return n;}
int main(){try{
 Lake a(42);check(a.cells.size()>10,"wet habitat");a.validate();
 auto b=a;for(int i=0;i<600;++i)b.step(false,false,true);b.validate();check(pool(b,Sediment)>pool(a,Sediment),"settling");
 auto dark=a;for(int i=0;i<600;++i)dark.step(true,false,false,0);dark.validate();check(dark.cumulative.production==0,"night photosynthesis");check(dark.cumulative.respiration>0,"respiration");check(dark.cumulative.decomposition>0,"decomposition");check(dark.cumulative.mortality>0,"death");
 auto light=a;for(int i=0;i<600;++i)light.step(true,false,false,1);light.validate();check(pool(light,Phyto)>pool(dark,Phyto),"light growth");
 auto limited=a;for(auto&c:limited.cells){c.m[BoundP]+=c.m[PO4];c.m[PO4]=0;c.m[BoundP]=0;}limited.initial=limited.totals();limited.initialOxygen=limited.initial.oxygen;
 // First step has no dissolved phosphate, before recycling can release any.
 limited.step(true,false,false,1);check(limited.cumulative.production==0,"phosphate limitation");limited.validate();
 auto anoxic=a;for(auto&c:anoxic.cells)c.m[O2]=0;anoxic.initial=anoxic.totals();anoxic.initialOxygen=anoxic.initial.oxygen;anoxic.step(true,false,false,0);anoxic.validate();check(anoxic.cumulative.decomposition==0,"oxygen limited decomposer");
 auto restored=Lake::restore(light.checkpoint(),42);for(int i=0;i<600;++i){light.step();restored.step();}check(light.checkpoint()==restored.checkpoint(),"checkpoint continuation");
 bool rejected=false;try{Lake::restore(light.checkpoint(),43);}catch(...){rejected=true;}check(rejected,"seed mismatch");
 auto broken=light.checkpoint();broken[broken.size()/2]='X';rejected=false;try{Lake::restore(broken,42);}catch(...){rejected=true;}check(rejected,"corruption");
 auto began=std::chrono::steady_clock::now();
 for(auto seed:{1,42,9876}){Lake w(seed);for(int i=0;i<100000;++i){w.step();if(i%1000==0)w.validate();}w.validate();
  check(pool(w,Phyto)>1&&pool(w,Mat)>1&&pool(w,Bacteria)>1,"long run guild persistence");
  std::cout<<"seed "<<seed<<" tick "<<w.tick<<" biomass phyto/mat/bacteria "<<pool(w,Phyto)<<"/"<<pool(w,Mat)<<"/"<<pool(w,Bacteria)<<" snapshot bytes "<<w.snapshot("test").size()<<"\n";
 }
 std::cout<<"Aquatic acceptance passed; 300000 ticks in "<<std::chrono::duration<double>(std::chrono::steady_clock::now()-began).count()<<" s\n";
 return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<"\n";return 1;}}
