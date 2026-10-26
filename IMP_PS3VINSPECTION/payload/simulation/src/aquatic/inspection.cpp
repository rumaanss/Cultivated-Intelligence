#include "cybernet/aquatic/inspection.hpp"
#include "cybernet/world/planet_contract_generated.hpp"
#include "json.hpp"
#include <mutex>
#include <map>
#include <cmath>
#include <fstream>
#include <chrono>
#include <algorithm>
namespace cybernet::aquatic::stage3 {
using J=nlohmann::json;
using Clock=std::chrono::steady_clock;
static void require(bool b,const char*s){if(!b)throw std::invalid_argument(s);}
static std::uint64_t number(const J&v,std::uint64_t max=9007199254740991ULL){
 require(v.is_number_integer()&&v.get<double>()>=0&&v.get<double>()<=double(max),"Invalid unsigned identifier");return v.get<std::uint64_t>();
}
static J mat(Material m){return J::array({m.c,m.n,m.p});}
static constexpr unsigned Period=10; // A measured half-second batch at nominal 20 ticks/s.
struct Inspection::Impl {
 std::mutex mutex;
 std::string run,boot,mode,owner,status="Starting";
 std::filesystem::path logPath;
 std::uint64_t publishedTick{},tick{},requestId{},until{},acceptedId{};
 J pending=nullptr,accepted=nullptr,lastReply=nullptr,geometry=J::object();
 std::map<std::uint64_t,J> probes;
 Clock::time_point publishedAt=Clock::now();
 std::vector<double> transmission;
 Clock::time_point requestedAt=Clock::now();
 std::vector<Ancestry> ancestry;
 std::vector<std::vector<std::uint64_t>> children;
 struct LiveRecord {
  Colony colony;
  Material material;
  std::array<double,GeneCount> expression;
  double cellMeanPar;
  unsigned form;
 };
 std::map<std::uint64_t,LiveRecord> live;
 std::vector<std::array<double,4>> patches;
 std::ifstream replay;
 J replayNext=nullptr;
 Impl(std::string r,std::string b,std::string m,const std::filesystem::path&p,const std::filesystem::path&file):run(std::move(r)),boot(std::move(b)),mode(std::move(m)),logPath(p/("scene-observations-"+boot+".jsonl")) {
  require(mode=="native-reference"||mode=="scene"||mode=="replay","Unknown sensor mode");
  if(mode=="replay"){replay.open(file);require(bool(replay),"Cannot open observation replay");}
 }
 J envelope()const{return {{"schema",1},{"package","IMP_PS3VINSPECTION-1"},{"run",run},{"boot",boot},{"tick",tick},{"habitat",planet_contract::Digest},{"mode",mode},{"status",status},{"optics","surface-par-1"}};}
 void publish(const Physiology&w){
  // Build transient fields outside the HTTP lock. This is a publisher cost.
  std::map<std::uint64_t,LiveRecord> next;
  for(const auto&c:w.colonies)
   next.emplace(c.id,LiveRecord{c,w.material(c),w.expression(c.genome),w.environment.cells[c.cell].light,w.genomes[c.genome-1].form});
  std::lock_guard lock(mutex);tick=publishedTick=w.environment.tick;publishedAt=Clock::now();live=std::move(next);
  auto previous=ancestry.size();ancestry=w.ancestry;children.resize(ancestry.size()+1);
  for(std::size_t i=previous;i<ancestry.size();++i)if(ancestry[i].parent)children[ancestry[i].parent].push_back(ancestry[i].id);
  if(patches.empty())for(std::size_t i=0;i<w.environment.cells.size();i+=2){auto&c=w.environment.cells[i];patches.push_back({c.x,c.y,c.floor,c.z});}
 }
 J identity(std::uint64_t id)const{
  if(id==0||id>ancestry.size())return {{"id",id},{"biological","unknown"}};
  const auto&a=ancestry[id-1];auto it=live.find(id);
  J out=J::object();
  if(it!=live.end()){
   const auto&v=it->second;const auto&c=v.colony;
   out={{"id",c.id},{"parent",c.parent},{"genome",c.genome},{"generation",c.generation},
    {"guild",c.guild},{"form",v.form},{"position",c.position},{"goal",c.goal},
    {"cell",c.cell},{"patch",c.cell/2+1},{"structure",c.structure},{"cohortCount",c.represented},
    {"materialCNP",mat(v.material)},{"reservesCNP",mat(c.reserve)},{"dnaCarbon",c.dna},
    {"rnaCarbon",c.rna},{"proteinCarbon",c.protein},{"expression",v.expression},
    {"behavior",c.behavior},{"par",c.sensedPar>=0?J(c.sensedPar):J(nullptr)},{"parUnits","umol photons m^-2 s^-1"},
    {"parStatus",c.sensedPar>=0?"last completed biological step":"not recorded yet"},
    {"cellMeanPar",v.cellMeanPar},{"displayScale","magnified; not cell diameter"}};
  }
  out.update({{"id",id},{"parent",a.parent},{"genome",a.genome},{"generation",a.generation},{"born",a.born},{"died",a.died},{"biological",a.died?"confirmed dead":"alive"}});
  out["events"]=J::array({J{{"key",std::to_string(id)+":birth"},{"kind",a.parent?"offspring":"initialized founder"},{"tick",a.born}}});
  if(a.died){out["events"].push_back({{"key",std::to_string(id)+":death"},{"kind","death"},{"tick",a.died}});out["deathCause"]="not recorded";out["positionStatus"]="historical pose not retained";}
  return out;
 }
 J query(const J&q){
  auto out=envelope();
  if(q.value("run",std::string())!=run){out["reset"]=true;return out;}
  auto id=number(q.value("id",J(0))),cursor=number(q.value("cursor",J(0)),2000000);
  auto limit=number(q.value("limit",J(32)),64);require(limit>0,"Page limit must be positive");
  out["tick"]=publishedTick;out["snapshotAgeSeconds"]=std::chrono::duration<double>(Clock::now()-publishedAt).count();
  out["individual"]=identity(id);out["children"]=J::array();out["cursor"]=cursor;
  if(id&&id<children.size()){
   auto& cs=children[id];require(cursor<=cs.size(),"Invalid child cursor");
   auto end=std::min<std::uint64_t>(cs.size(),cursor+limit);
   for(auto i=cursor;i<end;++i)out["children"].push_back(identitySummary(cs[i]));
   out["nextCursor"]=end<cs.size()?J(end):J(nullptr);out["childCount"]=cs.size();
  }else {out["nextCursor"]=nullptr;out["childCount"]=0;}
  out["light"]=lightStatus();out["geometry"]=geometry;
  if(auto it=live.find(id);it!=live.end())out["probeRequest"]={{"id",id},{"tick",publishedTick},{"position",it->second.colony.position},{"rays",16},{"rangeStuds",64},{"modality","geometric-retina-diagnostic"},{"scope","Terrain and registered optical surfaces; no organism recognition"}};
  if(probes.count(id))out["probe"]=probes.at(id);
  return out;
 }
 J identitySummary(std::uint64_t id)const{
  const auto&a=ancestry[id-1];return {{"id",id},{"parent",a.parent},{"born",a.born},{"died",a.died},{"generation",a.generation},{"biological",a.died?"confirmed dead":"alive"}};
 }
 J lightStatus()const{return {{"mode",mode},{"status",status},{"request",requestId},{"acceptedRequest",acceptedId},{"validBeforeTick",until},{"diffuseFraction",.15},{"scope","column surface occlusion; native water/canopy attenuation"},{"pixelVision","unverified; disabled"},{"otherModalities","reserved; no founder variation introduced"}};}
 J makeRequest(const Physiology&w){
  J p=envelope();p["request"]=++requestId;p["tick"]=w.environment.tick;
  p["applyTick"]=w.environment.tick;p["validBeforeTick"]=w.environment.tick+Period;
  double angle=2*3.141592653589793*double(w.environment.tick%600)/600;
  p["solarPhase"]=double(w.environment.tick%600)/600;p["sunChart"]=J::array({std::cos(angle),0,std::sin(angle)});
  p["surfacePar"]=1000*std::max(0.,std::sin(angle));p["points"]=J::array();
  for(std::size_t i=0;i<patches.size();++i)p["points"].push_back(J::array({i+1,patches[i][0],patches[i][1],108.02,patches[i][2]}));
  p["maxRayStuds"]=12000;p["directFraction"]=.85;p["diffuseFraction"]=.15;
  return p;
 }
 bool prepare(Physiology&w){
  std::lock_guard lock(mutex);tick=w.environment.tick;
  if(mode=="native-reference"){w.sceneTransmission.clear();status="Native reference (no Roblox scene input)";return true;}
  if(tick<until){w.sceneTransmission=transmission;status="Applying accepted scene batch";return true;}
  if(mode=="replay"){
   if(replayNext.is_null()){
    std::string line;
    while(std::getline(replay,line)){if(line.empty())continue;auto j=J::parse(line);if(number(j.at("validBeforeTick"))>tick){replayNext=std::move(j);break;}}
   }
   require(!replayNext.is_null(),"Observation replay exhausted; biology not advanced");
   require(replayNext.at("habitat")==planet_contract::Digest&&replayNext.at("optics")=="surface-par-1"&&number(replayNext.at("applyTick"))<=tick,"Replay contract/tick mismatch");
   require(number(replayNext.at("seed"))==w.environment.seed,"Replay seed mismatch");
   transmission=replayNext.at("transmission").get<std::vector<double>>();
   require(transmission.size()==patches.size(),"Replay coverage mismatch");
   for(double v:transmission)require(std::isfinite(v)&&v>=.15&&v<=1,"Invalid replay transmission");
   until=number(replayNext.at("validBeforeTick"));require(until==number(replayNext.at("applyTick"))+Period,"Replay cadence mismatch");
   replayNext=nullptr;w.sceneTransmission=transmission;status="Recorded scene replay";return true;
  }
  if(pending.is_null()){pending=makeRequest(w);accepted=nullptr;requestedAt=Clock::now();status="Waiting for Roblox scene observations; biology paused";return false;}
  if(accepted.is_null())return false;
  if(Clock::now()-requestedAt>std::chrono::seconds(5)){
   pending=nullptr;accepted=nullptr;status="Expired scene request; resampling without biological advancement";return false;
  }
  transmission.clear();for(const auto&v:accepted.at("visibility"))transmission.push_back(.15+.85*v.get<double>());
  until=tick+Period;acceptedId=requestId;
  J record={{"schema",1},{"run",run},{"boot",boot},{"seed",w.environment.seed},{"habitat",planet_contract::Digest},{"optics","surface-par-1"},{"applyTick",tick},{"validBeforeTick",until},{"request",requestId},{"transmission",transmission},{"scene",accepted.at("scene")}};
  std::ofstream log(logPath,std::ios::app);require(bool(log),"Cannot record scene observation");log<<record.dump()<<'\n';log.flush();require(bool(log),"Scene observation recording failed");
  geometry=accepted.value("geometry",J::object());lastReply=accepted;pending=nullptr;accepted=nullptr;w.sceneTransmission=transmission;status="Scene observation accepted";return true;
 }
 J sense(const J&q){
  auto out=envelope();out["light"]=lightStatus();
  if(q.value("run",std::string())!=run||q.value("boot",std::string())!=boot){out["reset"]=true;return out;}
  if(q.contains("probe")) {
   const auto&v=q.at("probe");auto id=number(v.at("id"));
   require(live.count(id)&&v.at("tick")==publishedTick&&v.at("position")==J(live.at(id).colony.position),"Probe pose/tick expired");
   require(v.at("modality")=="geometric-retina-diagnostic"&&v.at("depthStuds").is_array()&&v.at("depthStuds").size()==16,"Probe modality/coverage");
   for(auto&d:v.at("depthStuds"))require(d.is_number()&&std::isfinite(d.get<double>())&&d.get<double>()>=0&&d.get<double>()<=64,"Probe depth range");
   if(!probes.count(id)&&probes.size()>=4)probes.erase(probes.begin());probes[id]=v;out["probeAccepted"]=id;
  }
  if(q.contains("observation")){
   const auto&v=q.at("observation");
   if(!lastReply.is_null()&&v==lastReply){out["accepted"]=acceptedId;out["pending"]=pending;return out;}
   require(mode=="scene"&&!pending.is_null(),"No pending scene request");
   require(v.is_object()&&v.at("schema")==1&&v.at("run")==run&&v.at("boot")==boot,"Observation identity");
   require(v.at("habitat")==planet_contract::Digest&&v.at("optics")=="surface-par-1","Observation contract mismatch");
   require(number(v.at("request"))==requestId&&v.at("tick")==pending.at("tick"),"Observation request/pose tick mismatch");
   require(v.at("scene").is_string()&&v.at("scene").get<std::string>().size()<=100,"Scene revision");
   const auto&vs=v.at("visibility");require(vs.is_array()&&vs.size()==patches.size(),"Incomplete scene coverage");
   for(auto&x:vs)require(x.is_number()&&std::isfinite(x.get<double>())&&x.get<double>()>=0&&x.get<double>()<=1,"Invalid visibility");
   auto host=q.at("host").get<std::string>();require(!host.empty()&&host.size()<=100,"Invalid sensor host");
   require(owner.empty()||owner==host,"Another sensor host owns this run");
   if(!accepted.is_null())require(accepted==v,"Request reused with changed observation");
   owner=host;accepted=v;out["accepted"]=requestId;
  }
  if(!pending.is_null()&&Clock::now()-requestedAt>std::chrono::seconds(5)){
   // Retries need a new request identity after expiry; never reuse a stale sample.
   pending=nullptr;accepted=nullptr;owner.clear();out["resample"]=true;
  }
  out["pending"]=pending;return out;
 }
};
Inspection::Inspection(std::string run,std::string boot,std::string mode,const std::filesystem::path&p,const std::filesystem::path&r):impl_(std::make_unique<Impl>(std::move(run),std::move(boot),std::move(mode),p,r)){}
Inspection::~Inspection()=default;
void Inspection::publish(const Physiology&w){impl_->publish(w);}
bool Inspection::prepare(Physiology&w){return impl_->prepare(w);}
std::string Inspection::request(const std::string&route,const std::string&body){
 require(body.size()<=128*1024,"Inspection body budget");auto q=J::parse(body);require(q.is_object()&&q.value("schema",0)==1,"Inspection schema");
 std::lock_guard lock(impl_->mutex);return (route=="/inspection"?impl_->query(q):impl_->sense(q)).dump();
}
}
