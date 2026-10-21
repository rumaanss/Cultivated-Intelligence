#include "cybernet/world/optics.hpp"
#include "cybernet/world/photosynthesis.hpp"
#include "cybernet/simulation/run_options.hpp"
#ifdef NDEBUG
#undef NDEBUG
#endif
#include <cassert>
#include <limits>
using namespace cybernet;
int main() {
 OpticalConfig c; OpticalField noon(c,1,0.08F,60,150), night(c,0,0.08F,60,450);
 auto a=noon.sampleLight({50,50,60}), b=noon.sampleLight({50,50,30}), d=noon.sampleLight({50,50,0});
 assert(a.sensor>b.sensor && b.sensor>d.sensor && a.sensor<1);
 assert(a.direct>0 && a.diffuse>0 && a.photosynthetic==a.sensor);
 assert(night.sampleLight({50,50,60}).photosynthetic==0);
 assert(night.sampleLight({50,50,30}).sensor<night.sampleLight({50,50,60}).sensor);
 auto near=noon.sampleVisibility({50,50,60},{51,50,60},30);
 auto far=noon.sampleVisibility({50,50,60},{70,50,60},30);
 assert(near.transmission>far.transmission && near.signal>far.signal && near.detectable);
 assert(!noon.sampleVisibility({50,50,60},{51,50,60},30,false).detectable);
 assert(!noon.sampleVisibility({0,0,60},{31,0,60},30).detectable);
 assert(noon.sampleVisibility({0,0,60},{0,0,60},30).transmission==1);
 assert(!noon.sampleVisibility({NAN,0,0},{0,0,0},30).detectable);
 OpticalConfig clear=c;clear.directExtinction=clear.diffuseExtinction=clear.beamExtinction=0;
 OpticalField clearField(clear,1,0,60,150);
 assert(clearField.sampleLight({0,0,0}).sensor==clearField.sampleLight({0,0,60}).sensor);
 OpticalConfig turbid=c;turbid.beamExtinction=1;
 assert(OpticalField(turbid,1,0,60,150).sampleVisibility({0,0,60},{10,0,60},30).signal<far.signal);
 bool rejected=false;try { OpticalConfig bad=c;bad.directExtinction=-1;bad.validate(); } catch(const std::invalid_argument&) { rejected=true; }assert(rejected);
 Organism o;o.configureSpecies(OrganismType::Cyanobacteria);o.energy=1;
 assert(photosynthesizeLocal(o,0)==0 && photosynthesizeLocal(o,1,0)==0);
 assert(photosynthesizeLocal(o,1)>0);
 o.energy=o.profile().maximumEnergy;assert(photosynthesizeLocal(o,1)==0);
 o.configureSpecies(OrganismType::Bacterivore);assert(photosynthesizeLocal(o,1)==0);
 char app[]="test",opt[]="--optics=v2",bad[]="--optics=nope";
 char* argv[]={app,opt};assert(parseRunOptions(2,argv).options.opticalModel==OpticalModel::OpticsV2);
 argv[1]=bad;assert(!parseRunOptions(2,argv).valid());
 return 0;
}
