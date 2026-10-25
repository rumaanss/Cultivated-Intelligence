// Included inside the versioned Stage 3 namespace. All transfers use mmol C/N/P.
double Physiology::activity(const Colony &c,unsigned gene) const {
  return std::clamp(c.protein[gene]/std::max(1e-12,c.structure*(gene>=Width?.001625:.00325)),0.,4.);
}
void Physiology::book(const Colony &c,Flow f,Material m) {
  if(budgets.size()==environment.cells.size()*6) budgets.at(c.cell*6+c.guild).flows[f]+=m;
}
void Physiology::resetBudget() {
  budgetStart=environment.tick;budgets.assign(environment.cells.size()*6,{});
  for(const auto &c:colonies)budgets[c.cell*6+c.guild].opening+=material(c);
}
void Physiology::census() {
  food_.assign(environment.cells.size(),{});canopy_.assign(environment.cells.size(),0.);
  for(const auto &c:colonies){food_[c.cell][c.guild]+=material(c).c;
    if(c.guild==5)for(const auto &n:c.segments)
      canopy_[c.cell]+=n.length*n.width*Lake::MetresPerStud*Lake::MetresPerStud/environment.cells[c.cell].area;
  }
}
void Physiology::seedWeb() {
  // Establish the web by dividing existing material, never by increasing totals.
  unsigned first=unsigned(genomes.size());
  for(unsigned k=0;k<6;++k){Genome g;g.id=genomes.size()+1;g.ploidy=config.ploidy;g.form=k<2?0:k-2;
    g.copies.resize(g.ploidy);for(auto &a:g.copies)a.fill(1.);
    genomes.push_back(g);expressions_.push_back(expression(g.id));}
  auto count=colonies.size();
  for(std::size_t i=0;i<count;++i){
    unsigned oldGuild=colonies[i].guild;
    std::vector<std::pair<unsigned,unsigned>> recruits;
    if(oldGuild==2)recruits.push_back({3,first+1});
    if(oldGuild==0)recruits.push_back({4,first+2});
    if(oldGuild==1)for(unsigned f=0;f<4;++f)recruits.push_back({5,first+3+f});
    if(recruits.empty())continue;
    Colony original=colonies[i];double fraction=oldGuild==1?.08:.20;
    auto scale=[](Colony &c,double f){c.structure*=f;c.target*=f;c.dna*=f;c.reserve=c.reserve*f;for(auto &v:c.rna)v*=f;for(auto &v:c.protein)v*=f;};
    scale(colonies[i],1-fraction*recruits.size());
    for(auto [guild,genome]:recruits){Colony child=original;scale(child,fraction);
      child.id=ancestry.size()+1;child.parent=0;child.generation=0;child.genome=genome;child.guild=guild;child.born=environment.tick;
      child.assimilation=child.respiration=child.distance=child.movementRespiration=0;
      child.segments.clear();child.nextSegment=1;place(child);growShape(child);
      ancestry.push_back({child.id,0,child.genome,child.born,0,0});colonies.push_back(child);
    }
  }
  census();
}
void Physiology::graze() {
  const auto n=environment.cells.size();
  std::vector<std::array<double,2>> demands(n),stock(n);
  std::vector<double> requests(colonies.size());
  for(const auto &p:colonies){if(p.guild==2)stock[p.cell][0]+=material(p).c;else if(p.guild<2)stock[p.cell][1]+=material(p).c;}
  for(std::size_t i=0;i<colonies.size();++i){auto &c=colonies[i];if(c.guild!=3&&c.guild!=4)continue;
    unsigned diet=c.guild-3;const auto &cell=environment.cells[c.cell];double food=stock[c.cell][diet];
    c.availableFood=food;
    double oxygen=cell.m[O2]/cell.volume;
    double capacity=c.structure*portion(.9)*std::min(activity(c,Capture),activity(c,Digestion));
    requests[i]=std::max(0.,std::min(capacity*food*food/(food*food+25.*cell.volume*cell.volume)*oxygen/(oxygen+20),
                                    (2*c.structure-c.reserve.c)/.7));
    demands[c.cell][diet]+=requests[i];
  }
  std::vector<std::array<Material,2>> harvested(n);
  for(auto &p:colonies){if(p.guild>2)continue;unsigned diet=p.guild==2?0:1;
    double available=stock[p.cell][diet];
    double fraction=available>0?std::min(portion(.45),demands[p.cell][diet]/available):0.;
    if(p.guild==1)fraction/=1+4*canopy_[p.cell]; // Attached films have structurally sheltered area.
    auto taken=material(p)*fraction;harvested[p.cell][diet]+=taken;book(p,Grazed,taken);
    // A colony is a biomass cohort: proportional removal includes every material
    // compartment and the represented cohort count, not an anatomical bite.
    double retained=1-fraction;p.structure*=retained;p.target*=retained;p.dna*=retained;
    p.reserve=p.reserve*retained;p.represented*=retained;
    for(auto &x:p.rna)x*=retained;for(auto &x:p.protein)x*=retained;
  }
  for(std::size_t i=0;i<colonies.size();++i){auto &c=colonies[i];if(c.guild!=3&&c.guild!=4)continue;
    unsigned diet=c.guild-3;double demand=demands[c.cell][diet];
    auto meal=harvested[c.cell][diet]*(demand>0?requests[i]/demand:0.);
    auto waste=meal*.3;c.reserve+=meal*.7;detritus[c.cell]+=waste;
    c.ingested+=meal.c;c.egested+=waste.c;c.assimilation+=meal.c*.7;
    book(c,Ingested,meal);book(c,Egested,waste);respire(c,meal.c*.25);
  }
}
void Physiology::growShape(Colony &c) {
  if(c.guild!=5)return;
  const auto &e=expressions_[c.genome-1];unsigned form=genomes[c.genome-1].form;
  // Geometry partitions existing structural carbon; it never creates biomass.
  double width=std::clamp(e[Width]*std::min(1.,activity(c,Width)),.2,3.);
  double extension=std::clamp(e[Extension]*std::min(1.,activity(c,Extension)),.2,3.);
  double branch=std::clamp(e[Branching]*std::min(1.,activity(c,Branching)),0.,4.);
  if(c.segments.empty())c.segments.push_back({c.nextSegment++,0,environment.tick,c.structure,0,0,0});
  double old=0;for(const auto &n:c.segments)old+=n.carbon;
  if(old>c.structure){for(auto &n:c.segments)n.carbon*=c.structure/old;}
  else {
    double extra=c.structure-old;
    std::vector<unsigned> children(c.nextSegment,0),depth(c.nextSegment,0);
    for(const auto &n:c.segments){++children[n.parent];depth[n.id]=depth[n.parent]+1;}
    // Existing terminal tissue receives new carbon; forks develop only when
    // paid branching machinery and enough tissue are both available.
    unsigned tip=unsigned(c.segments.size()-1);
    for(unsigned i=0;i<c.segments.size();++i)
      if(children[c.segments[i].id]==0 && c.segments[i].carbon<c.segments[tip].carbon)tip=i;
    c.segments[tip].carbon+=extra;
    double unit=c.target/(4+4*branch);
    if(extra>0 && branch>.1 && c.segments[tip].carbon>unit && c.segments.size()<24){
      unsigned parent=c.segments[tip].id;
      // Alternate extension with a sibling fork; the stored graph survives
      // checkpointing, starvation and renewed growth.
      if(c.nextSegment%2==0 && c.segments[tip].parent && children[c.segments[tip].parent]<2)
        parent=c.segments[tip].parent;
      if(depth[parent]<6){
        double part=c.segments[tip].carbon*.35;c.segments[tip].carbon-=part;
        double shade=std::clamp(canopy_.empty()?0.:canopy_[c.cell],0.,1.);
        double angle=(c.nextSegment%2?1.:-1.)*(.25+.25*std::min(2.,branch))*(1-.4*shade);
        c.segments.push_back({c.nextSegment++,parent,environment.tick,part,0,0,angle});
      }
    }
  }
  for(auto &n:c.segments){
    double volume=std::max(0.,n.carbon)*.08; // Explicit coarse tissue-volume calibration, stud^3/mmol C.
    double desiredRatio=(form==0?9.:form==1?2.8:form==2?18.:1.2)*extension/width;
    // Mature tissue keeps its proportions. Expression controls new tissue.
    double ratio=n.width>0?n.length/n.width:desiredRatio;
    n.width=std::cbrt(volume/std::max(.01,ratio*.08));n.length=n.width*ratio;
    // Bounded dimensions preserve exact volume via thickness recorded in renderer.
    n.length=std::min(n.length,6.);n.width=std::min(n.width,3.);
  }
}
std::string Physiology::report(bool detailed) const {
  std::vector<Material> closing(environment.cells.size()*6);
  std::vector<double> covers(environment.cells.size());
  for(const auto &c:colonies){closing[c.cell*6+c.guild]+=material(c);if(c.guild==5)for(const auto &n:c.segments)covers[c.cell]+=n.length*n.width*Lake::MetresPerStud*Lake::MetresPerStud/environment.cells[c.cell].area;}
  J rows=J::array();Material maximum{};
  for(unsigned i=0;i<budgets.size();++i){const auto &b=budgets[i];Material predicted=b.opening;
    for(unsigned k=0;k<FlowCount;++k){if(k==Growth)continue;double sign=(k==Release||k==Respiration||k==Mortality||k==Grazed||k==Egested)?-1.:1.;predicted+=b.flows[k]*sign;}
    auto residual=closing[i];residual-=predicted;
    maximum.c=std::max(maximum.c,std::abs(residual.c));maximum.n=std::max(maximum.n,std::abs(residual.n));maximum.p=std::max(maximum.p,std::abs(residual.p));
    J fs=J::array();for(auto m:b.flows)fs.push_back(mat(m));
    if(detailed)rows.push_back({i/12+1,(i/6)%2,i%6,mat(b.opening),mat(closing[i]),fs,mat(residual)});
  }
  J habitat=J::array();
  if(detailed)for(unsigned i=0;i<environment.cells.size();++i){const auto &c=environment.cells[i];std::array<double,6> stock{};
    for(unsigned g=0;g<6;++g)stock[g]=closing[i*6+g].c;
    double cover=covers[i];
    habitat.push_back({i/2+1,i%2,c.x,c.y,c.z,c.area,c.volume,stock,J::array({stock[2],stock[0]+stock[1]/(1+4*cover)}),cover});
  }
  return J{{"schema",1},{"startTick",budgetStart},{"endTick",environment.tick},
    {"biologicalDays",double(environment.tick-budgetStart)/600.},
    {"units","mmol C,N,P; intervals are biological days"},
    {"flowNames",{"fixation","inorganicUptake","release","respiration","mortality","grazed","ingested","egested","netExchange","structuralGrowth"}},
    {"accessibility","same chemistry cell, compatible diet; encounter/handling limited; not perfect reachability"},
    {"maxResidual",mat(maximum)},{"rows",rows},{"habitat",habitat}}.dump();
}
Physiology Physiology::migrateStage2(const std::string &text,std::uint64_t seed) {
  auto envelope=J::parse(text);std::string payload=envelope.at("payload");
  need(envelope.at("checksum")==std::to_string(hash(payload)),"Stage 2 checksum");
  J j=J::parse(payload);need(j.at("model")=="pdnarna-4"&&j.at("seed")==seed,"Expected pdnarna-4 checkpoint and matching seed");
  j["model"]="stage3-1";j["schema"]=3;j["shapes"]=J::array();
  for(auto &g:j["genomes"]){for(auto &a:g[3])while(a.size()<GeneCount)a.push_back(1.);g.push_back(0);}
  for(auto &c:j["colonies"]){for(unsigned field:{11,12})while(c[field].size()<GeneCount)c[field].push_back(0.);
    c.push_back(1.);c.push_back(0.);c.push_back(0.);c.push_back(1);j["shapes"].push_back({c[0],J::array()});}
  std::vector<Material> opening(j.at("cells").size()*6);
  for(const auto &r:j.at("colonies")){
    Material m=materialJson(r.at(10));m+=quota(r.at(8).get<double>());
    double nucleic=r.at(9).get<double>(),protein=0;for(double x:r.at(11))nucleic+=x;for(double x:r.at(12))protein+=x;
    m+=quota(nucleic,.4,.1);m+=quota(protein,.25,0);opening.at(r.at(5).get<unsigned>()*6+r.at(6).get<unsigned>())+=m;
  }
  j["budgets"]=J::array();for(auto m:opening){J flows=J::array();for(unsigned k=0;k<FlowCount;++k)flows.push_back(mat({}));j["budgets"].push_back({mat(m),mat({}),flows});}
  j["budgetStart"]=j["tick"];j["lastDay"]="";
  auto converted=j.dump();Physiology w=restore(J{{"payload",converted},{"checksum",std::to_string(hash(converted))}}.dump(),seed);
  w.seedWeb();w.resetBudget();w.validate();return w;
}
