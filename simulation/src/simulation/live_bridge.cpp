#include "cybernet/simulation/live_bridge.hpp"
#include "cybernet/simulation/live_manifest.hpp"
#include "cybernet/world/geometry.hpp"
#include <fstream>
#include "cybernet/plants/plant_world.hpp"
#include <sstream>
#include <unordered_map>
#include <unordered_set>
#include <iomanip>
#include <iostream>
#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#else
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#endif
namespace cybernet {
namespace {
bool token(const std::string& s){return !s.empty()&&s.size()<=100&&s.find_first_not_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")==std::string::npos;}
void require(bool b,const char* message){if(!b)throw std::runtime_error(message);}
std::string readBounded(const std::filesystem::path& p){
#ifdef _WIN32
 // CRT ifstream handles can deny deletion on Windows. Atomic rename needs
 // FILE_SHARE_DELETE even while a reader retains the previous file version.
 // Short read-side retry absorbs atomic-replacement/temporary handle contention.
 // The last accepted input timestamp is NOT refreshed by an unsuccessful read.
 HANDLE handle=INVALID_HANDLE_VALUE;
 const auto deadline=std::chrono::steady_clock::now()+std::chrono::milliseconds(120);
 unsigned attempt=0;
 for(;;){
  handle=CreateFileW(p.c_str(),GENERIC_READ,
      FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,nullptr,OPEN_EXISTING,
      FILE_ATTRIBUTE_NORMAL|FILE_FLAG_SEQUENTIAL_SCAN,nullptr);
  if(handle!=INVALID_HANDLE_VALUE)break;
  const DWORD error=GetLastError();
  if(error==ERROR_FILE_NOT_FOUND||error==ERROR_PATH_NOT_FOUND)return {};
  if((error!=ERROR_SHARING_VIOLATION&&error!=ERROR_LOCK_VIOLATION)||std::chrono::steady_clock::now()>=deadline)
   throw std::runtime_error("Live input open failed after bounded read retry; Windows error "+std::to_string(error)+"; path="+p.string());
  std::this_thread::sleep_for(std::chrono::milliseconds(std::min(2U+(attempt++*2U),12U)));
 }
 struct Close {HANDLE value;~Close(){CloseHandle(value);}} close{handle};
 std::string s(LiveBridge::MaxBytes+1,'\0');DWORD count=0;
 if(!ReadFile(handle,s.data(),static_cast<DWORD>(s.size()),&count,nullptr))
  throw std::runtime_error("Live input read failed; Windows error "+std::to_string(GetLastError()));
 s.resize(count);
#else
 std::ifstream f(p,std::ios::binary);if(!f)return {};
 std::string s(LiveBridge::MaxBytes+1,'\0');
 f.read(s.data(),static_cast<std::streamsize>(s.size()));
 s.resize(static_cast<std::size_t>(f.gcount()));
#endif
 require(s.size()<=LiveBridge::MaxBytes,"Oversized live input");return s;
}
bool finite(Vec3 p){return std::isfinite(p.x)&&std::isfinite(p.y)&&std::isfinite(p.z);}
}
void LiveBridge::atomicWrite(const std::filesystem::path& path,const std::string& text){
 auto temp=path;temp+=".tmp";
 {std::ofstream f(temp,std::ios::binary|std::ios::trunc);require(bool(f),"Live file open failed");f.write(text.data(),static_cast<std::streamsize>(text.size()));f.flush();require(bool(f),"Live file write failed");}
#ifdef _WIN32
 {HANDLE h=CreateFileW(temp.c_str(),GENERIC_WRITE,FILE_SHARE_READ,nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);
  require(h!=INVALID_HANDLE_VALUE,"Cannot flush live temporary file");const bool ok=FlushFileBuffers(h)!=0;CloseHandle(h);require(ok,"Live durable flush failed");}
 bool replaced=false;DWORD lastError=ERROR_SUCCESS;
 const auto deadline=std::chrono::steady_clock::now()+std::chrono::seconds(2);
 for(unsigned attempt=0;;++attempt){
  if(ReplaceFileW(path.c_str(),temp.c_str(),nullptr,0,nullptr,nullptr)!=0){
   replaced=true;break;
  }
  lastError=GetLastError();
  if(lastError==ERROR_FILE_NOT_FOUND){
   // Initial publication only; never delete the existing destination.
   if(MoveFileExW(temp.c_str(),path.c_str(),MOVEFILE_WRITE_THROUGH)!=0){
    replaced=true;break;
   }
   lastError=GetLastError();
  }
  if(lastError!=ERROR_SHARING_VIOLATION&&lastError!=ERROR_ACCESS_DENIED&&lastError!=ERROR_LOCK_VIOLATION)break;
  if(std::chrono::steady_clock::now()>=deadline)break;
  std::this_thread::sleep_for(std::chrono::milliseconds(5+std::min(attempt,15U)));
 }
 if(!replaced)throw std::runtime_error("Live atomic replace failed: "+temp.string()+" -> "+path.string()+"; Windows error "+std::to_string(lastError)+" (after bounded retry)");
#else
 {int fd=open(temp.c_str(),O_RDONLY);require(fd>=0,"Cannot flush live file");int result=fsync(fd);close(fd);require(result==0,"Live durable flush failed");}
 std::filesystem::rename(temp,path);
 {int fd=open(path.parent_path().c_str(),O_RDONLY);if(fd>=0){int result=fsync(fd);close(fd);require(result==0,"Live directory flush failed");}}
#endif
}
LiveInput LiveBridge::parseInput(const std::string& text){
 require(text.size()<=MaxBytes,"Oversized input");std::istringstream in(text);in.imbue(std::locale::classic());
 LiveInput v;std::string magic;std::size_t n=0,a=0,e=0;
 in>>magic>>v.run>>v.session>>v.batch>>n>>a>>e;
 require(bool(in)&&magic=="CIINPUT1"&&token(v.run)&&token(v.session)&&v.batch>0&&v.batch<=2147483647U&&n<=MaxAgents&&a<=MaxActors&&e<=MaxEvents,"Invalid input header");
 std::unordered_set<std::uint32_t> ids;
 for(std::size_t i=0;i<n;++i){LivePose p;in>>p.id>>p.position.x>>p.position.y>>p.position.z>>p.velocity.x>>p.velocity.y>>p.velocity.z;
 require(bool(in)&&p.id>0&&p.id<=2147483647U&&ids.insert(p.id).second&&finite(p.position)&&finite(p.velocity)&&p.position.lengthSquared()<=1e12F&&p.velocity.lengthSquared()<=1e12F,"Invalid live body");v.poses.push_back(p);}
 ids.clear();
 for(std::size_t i=0;i<a;++i){ExternalActor p;in>>p.id>>p.kind>>p.position.x>>p.position.y>>p.position.z>>p.radius>>p.health;
 require(bool(in)&&p.id>0&&p.id<1000000&&ids.insert(p.id).second&&finite(p.position)&&std::isfinite(p.radius)&&p.radius>=.1F&&p.radius<=8&&std::isfinite(p.health)&&p.health>=0&&p.health<=10000&&(p.kind==1||p.kind==2)&&p.position.lengthSquared()<=1e12F,"Invalid external actor");v.actors.push_back(p);}
 std::uint32_t previous=0;
 for(std::size_t i=0;i<e;++i){LiveEvent event;in>>event.sequence>>event.kind>>event.agent>>event.actor>>event.amount;
 require(bool(in)&&event.sequence>previous&&event.agent>0&&(event.kind==1||event.kind==2)&&std::isfinite(event.amount)&&event.amount>0&&event.amount<=100,"Invalid event");previous=event.sequence;v.events.push_back(event);}
 std::string extra;
 if(in>>extra){require(extra=="ACKCORRECTIONS"&&bool(in>>v.correctionAck),"Invalid correction acknowledgment");
  if(in>>extra){require(extra=="EPOCH"&&bool(in>>v.epoch)&&v.epoch>0,"Invalid lease epoch");if(in>>extra){require(extra=="BOOT"&&bool(in>>v.boot)&&token(v.boot),"Invalid boot");require(!(in>>extra),"Trailing input");}}}
 return v;
}
LiveBridge::LiveBridge(std::filesystem::path dir,std::uint64_t seed,bool memory,bool autonomous):memory_(memory),autonomous_(autonomous),directory_(std::move(dir)){
 std::filesystem::create_directories(directory_);
 const auto lock=directory_/"publisher.lock";
#ifdef _WIN32
 const HANDLE h=CreateFileW(lock.c_str(),GENERIC_READ|GENERIC_WRITE,0,nullptr,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);
 require(h!=INVALID_HANDLE_VALUE,"Another publisher owns this live directory");lockHandle_=reinterpret_cast<std::intptr_t>(h);
#else
 int h=open(lock.c_str(),O_CREAT|O_RDWR,0600);require(h>=0,"Cannot open live lock");if(flock(h,LOCK_EX|LOCK_NB)!=0){close(h);throw std::runtime_error("Another publisher owns this live directory");}lockHandle_=h;
#endif
 run_="live-"+std::to_string(seed)+"-"+std::to_string(std::chrono::system_clock::now().time_since_epoch().count());
 boot_=run_;
 if(std::filesystem::exists(directory_/"checkpoint.bin")){
  require(std::filesystem::file_size(directory_/"checkpoint.bin")<256*1024*1024,"Checkpoint exceeds budget");
  std::ifstream f(directory_/"checkpoint.bin",std::ios::binary);std::string text{std::istreambuf_iterator<char>(f),{}};
  restored_=std::make_unique<LiveCheckpoint>(LiveCheckpoint::decode(text));
  require(restored_->run.starts_with("live-"+std::to_string(seed)+"-"),"Checkpoint seed mismatch; use a new live directory");
  run_=restored_->run;session_=restored_->session;ack_=restored_->ack;durableAck_=ack_;durableSession_=session_;epoch_=restored_->epoch;
 }
 manifest_=liveManifest(seed,run_);thread_=std::thread([this]{worker();});if(!memory_)readerThread_=std::thread([this]{reader();});
 std::cout<<"[CI Live] "<<run_<<"; bridge hardened-v3; waiting for Roblox authority\n";
}
LiveBridge::~LiveBridge(){stopping_=true;cv_.notify_one();if(readerThread_.joinable())readerThread_.join();if(thread_.joinable())thread_.join();
#ifdef _WIN32
 if(lockHandle_!=-1)CloseHandle(reinterpret_cast<HANDLE>(lockHandle_));
#else
 if(lockHandle_!=-1)close(static_cast<int>(lockHandle_));
#endif
}
bool LiveBridge::beginTick(std::vector<Organism>& population,const GeometryWorld& terrain){
 if(!ioHealthy_){status("publisher-io-unavailable");return false;}
 if(memory_&&autonomous_){status("running");return true;}
 std::shared_ptr<LiveInput> input;std::chrono::steady_clock::time_point received;
 {std::lock_guard lock(mutex_);input=incoming_;received=incomingAt_;}
 if(!input){status("waiting-for-input");return false;}
#ifdef CI_PLANET_LAKE
 if(!input->poses.empty()||!input->actors.empty()||!input->events.empty()){status("observer-input-required");return false;}
#endif
 if(input->run!=run_){status("wrong-run");return false;}
 if(std::chrono::steady_clock::now()-received>std::chrono::seconds(3)){status("stale-input");return false;}
 if(input->epoch>0&&input->boot!=boot_){status("awaiting-boot-resync");return false;}
 if(input->epoch<epoch_){status("fenced-old-owner");return false;}
 if(input->epoch==epoch_&&!session_.empty()&&input->session!=session_){status("session-epoch-conflict");return false;}
 if(input->session==session_ && input->batch<=batch_)return true;
 // Structural/security failures remain fail-closed. Physical errors are isolated.
 const std::uint32_t baseAck=input->session==session_?ack_:0;
 std::uint32_t next=baseAck+1;
 for(const auto& e:input->events)if(e.sequence>baseAck){if(e.sequence!=next++){status("event-gap");return false;}}
 if(input->correctionAck>correctionVersion_){status("invalid-correction-ack");return false;}
 // Native planetary clients are observers. Reuse the immutable terrain instead
 // of rebuilding its geometry index on every heartbeat.
 if(memory_){
  if(session_!=input->session){session_=input->session;ack_=0;durableAck_=0;corrections_.clear();for(auto& o:population)o.liveQuarantined=false;}
  epoch_=input->epoch;batch_=input->batch;status("running");return true;
 }
 std::unordered_map<std::uint32_t,Organism*> byId;for(auto& o:population)byId[o.id]=&o;
 if(session_!=input->session){
  session_=input->session;ack_=0;durableAck_=0;batch_=0;epoch_=input->epoch;corrections_.clear();
  for(auto& o:population)o.liveQuarantined=false;
 }
 auto correction=[&](std::uint32_t kind,std::uint32_t id,Vec3 p){
  auto key=std::make_pair(kind,id);
  auto found=corrections_.find(key);
  if(found!=corrections_.end()&&input->correctionAck<found->second.version)return;
  corrections_[key]={++correctionVersion_,kind,id,p};
  std::cerr<<"[CI Live hardened-v3] correction "<<correctionVersion_<<" kind="<<kind<<" id="<<id<<"; other entities continue\n";
 };
 for(const auto& p:input->poses){
  auto found=byId.find(p.id);if(found==byId.end()||!found->second->alive())continue;
  auto& o=*found->second;const auto key=std::make_pair(1U,p.id);
  auto pending=corrections_.find(key);
  if(pending!=corrections_.end()&&input->correctionAck<pending->second.version){o.liveQuarantined=true;continue;}
  Vec3 candidate=p.position;
  bool valid=terrain.clear(candidate);
  if(!valid){valid=terrain.projectOutside(candidate)&&terrain.clear(candidate)&&
      (candidate-p.position).lengthSquared()<=0.001F*0.001F;}
  valid=valid&&p.velocity.lengthSquared()<=16;
  if(!valid){
   Vec3 safe=o.position;
   if(!terrain.clear(safe)&&(!terrain.projectOutside(safe)||!terrain.clear(safe)))safe={terrain.bounds().x/2,terrain.bounds().y/2,terrain.bounds().z-terrain.bodyRadius()};
   o.position=safe;o.velocity={};o.liveQuarantined=true;
   o.liveIntent={.5F,.5F,.5F,0,0};o.liveTarget=0;
   o.opticalDiagnostics.photosyntheticEnergy=0;
   correction(1,p.id,safe);continue;
  }
  o.position=candidate;o.velocity=p.velocity;o.liveQuarantined=false;corrections_.erase(key);
 }
 // Remove tombstones so recovery state remains bounded by the live population.
 for(auto it=corrections_.begin();it!=corrections_.end();){
  if(it->second.kind==1&&(!byId.contains(it->second.id)||!byId[it->second.id]->alive()))it=corrections_.erase(it);else ++it;
 }
 auto actors=input->actors;
 for(auto& actor:actors){
  const auto key=std::make_pair(2U,actor.id);auto pending=corrections_.find(key);
  const bool waiting=pending!=corrections_.end()&&input->correctionAck<pending->second.version;
  if(waiting)actor.position=pending->second.position;
  const Vec3 original=actor.position;const float margin=actor.radius+.5F;
  actor.position.x=std::clamp(actor.position.x,margin,terrain.bounds().x-margin);
  actor.position.y=std::clamp(actor.position.y,margin,terrain.bounds().y-margin);
  const float floor=std::max(margin,terrain.floorHeight(actor.position.x,actor.position.y,actor.radius));
  actor.position.z=std::clamp(actor.position.z,margin,terrain.bounds().z-margin);
  if(actor.position.z<floor-.0001F)actor.position.z=floor+.001F;
  if((actor.position-original).lengthSquared()>0){correction(2,actor.id,actor.position);}
  else if(!waiting)corrections_.erase(key);
 }
 for(auto it=corrections_.begin();it!=corrections_.end();){
  if(it->second.kind==2&&std::none_of(actors.begin(),actors.end(),[&](const auto& a){return a.id==it->second.id;}))it=corrections_.erase(it);else ++it;
 }
 std::vector<GeometryObject> objects(terrain.objects().begin(),terrain.objects().end());
 for(const auto& a:actors)objects.push_back({0x80000000U+a.id,GeometryShape::Sphere,a.position,{a.radius,a.radius,a.radius},true,true});
 auto candidate=std::make_unique<GeometryWorld>(objects,terrain.bodyRadius(),terrain.terrainPlanes(),terrain.heightfield(),terrain.bounds());
 for(const auto& event:input->events){
  if(event.sequence<=ack_)continue;
  if(auto i=byId.find(event.agent);i!=byId.end()&&i->second->alive()){
   auto& o=*i->second;
   if(event.kind==1){o.health=std::max(0.0F,o.health-event.amount);if(o.health<=0)o.kill(DeathCause::Predation);}
   // Corpse consumption is an explicit gameplay energy input, never inferred from animation.
   if(event.kind==2 && o.species!=OrganismType::Cyanobacteria)o.gainEnergy(event.amount*o.profile().assimilationEfficiency);
  }
  ack_=event.sequence;
 }
 dynamic_=std::move(candidate);
 actors_=std::move(actors);batch_=input->batch;status(corrections_.empty()?"running":"recovering-entities");return true;
}
bool LiveBridge::restore(std::vector<Organism>& population,ChemistryField& chemistry,Random& random,std::uint32_t& tick,std::uint32_t& nextId,std::string* island){
 if(!restored_)return false;
 auto c=std::move(restored_);
 if(island)*island=c->island;else if(!c->island.empty())throw std::runtime_error("Checkpoint includes island plants; supply --island-surface to resume");
 population=std::move(c->population);chemistry=c->chemistry;random.loadState(c->rng);tick=c->tick;nextId=c->nextId;
 for(auto& o:population)o.liveQuarantined=false;
 std::cout<<"[CI Live] Restored tick "<<tick<<"; durable event "<<ack_<<"; waiting for full resynchronization\n";
 return true;
}
void LiveBridge::checkpoint(std::span<const Organism> population,const ChemistryField& chemistry,const Random& random,std::uint32_t tick,std::uint32_t nextId,const plants::World* island,bool force){
 const auto now=std::chrono::steady_clock::now();const auto interval=ack_>durableAck_?std::chrono::milliseconds(2000):std::chrono::milliseconds(5000);
 if(!force&&checkpointAt_.time_since_epoch().count()!=0&&now-checkpointAt_<interval)return;
 auto c=std::make_unique<LiveCheckpoint>();c->run=run_;c->session=session_;c->tick=tick;c->nextId=nextId;c->ack=ack_;c->epoch=epoch_;
 if(island)c->island=island->checkpoint();
 c->chemistry=chemistry;c->rng=random.saveState();c->population.assign(population.begin(),population.end());
 std::lock_guard lock(mutex_);checkpointPending_=std::move(c);checkpointAt_=now;cv_.notify_one();
}
void LiveBridge::movement(Organism& o,LifecycleAction& a)const noexcept{
 if(!o.alive()||o.liveQuarantined)return;
 // Roblox owns live motion; C++ charges biological movement cost without integrating twice.
 const float before=o.energy;
 const Vec3 direction{a.outputs[1]*2-1,a.outputs[0]*2-1,a.outputs[2]*2-1};
 o.spendEnergy(direction.lengthSquared()>.0225F?o.profile().movementCost+o.velocity.length()*.01F:o.profile().movementCost*.75F);
 a.movementEnergySpent=std::max(0.0F,before-o.energy);
}
void LiveBridge::capture(std::uint32_t tick,const CelestialState& light,std::span<const Organism> population,std::span<const LifecycleAction> actions){
 const auto now=std::chrono::steady_clock::now();if(lastCapture_.time_since_epoch().count()!=0&&now-lastCapture_<std::chrono::milliseconds(100))return;
 auto s=std::make_unique<Sample>();s->tick=tick;s->sequence=sequence_;s->ack=ack_;s->session=session_;s->light=light;
 for(const auto& [key,c]:corrections_)s->corrections.push_back(c);
 s->agents.reserve(std::min(population.size(),MaxAgents));
 for(std::size_t i=0;i<population.size();++i){const auto& o=population[i];if(!o.alive())continue;if(s->agents.size()>=MaxAgents){std::cerr<<"[CI Live] Population exceeds live budget\n";return;}
  std::array<double,25> r{double(o.id),double(o.species),o.position.x,o.position.y,o.position.z,o.velocity.x,o.velocity.y,o.velocity.z,o.energy,double(o.ageTicks),double(o.parentId),double(o.generation),double(o.birthTick),double(o.opticalDiagnostics.tick),o.opticalDiagnostics.sensorLight,o.opticalDiagnostics.photosyntheticLight,o.opticalDiagnostics.photosyntheticEnergy,o.health,o.speed,.5,.5,.5,0,0,0};
  // Action identity is attached to the organism before population compaction/reproduction.
  for(int k=0;k<5;++k){r[19+k]=o.liveIntent[k];}
  r[24]=o.liveTarget;
  if(o.liveQuarantined){r[16]=0;r[19]=r[20]=r[21]=.5;r[22]=r[23]=r[24]=0;}
  s->agents.push_back(r);
 }
 (void)actions;
 // An accepted capture must reach the queue even when the reader/worker owns
 // the mutex briefly. Dropping it here can strand a one-shot correction.
 // Both background threads perform file I/O outside this critical section.
 {
  std::lock_guard lock(mutex_);
  pending_=std::move(s);
  lastCapture_=now;
  ++sequence_;
 }
 cv_.notify_one();
}
std::string LiveBridge::encode(const Sample& s,bool stopped)const{
 std::ostringstream out;out.imbue(std::locale::classic());out<<std::setprecision(9);
 out<<"{\"protocol\":1,\"state\":\""<<(stopped?"stopped":"running")<<"\",\"manifest\":"<<manifest_<<",\"session\":\""<<s.session<<"\",\"ack\":"<<s.ack<<",\"sequence\":"<<s.sequence<<",\"tick\":"<<s.tick<<",\"light\":["<<s.light.daylight<<','<<s.light.moonlight<<','<<s.light.ambientLight<<"],\"agents\":[";
 bool first=true;auto sorted=s.agents;std::sort(sorted.begin(),sorted.end(),[](const auto&a,const auto&b){return a[0]<b[0];});
 for(const auto& row:sorted){if(!first)out<<',';first=false;out<<'[';for(std::size_t i=0;i<row.size();++i){require(std::isfinite(row[i]),"Non-finite live state");if(i)out<<',';out<<row[i];}out<<']';}out<<"],\"bridgeBuild\":\"hardened-v3\",\"boot\":\""<<boot_<<"\",\"durableAck\":"<<(s.session==durableSession_?std::min(s.ack,durableAck_.load()):0)<<",\"corrections\":[";
 first=true;for(const auto& c:s.corrections){if(!first)out<<',';first=false;out<<'['<<c.version<<','<<c.kind<<','<<c.id<<','<<c.position.x<<','<<c.position.y<<','<<c.position.z<<']';}
 out<<"]}";auto result=out.str();require(result.size()<=MaxBytes,"Oversized live snapshot");return result;
}
void LiveBridge::status(const std::string& value){
 std::lock_guard lock(mutex_);if(status_==value)return;status_=value;
 std::cerr<<"[CI Live hardened-v3] "<<value<<'\n';cv_.notify_one();
}
void LiveBridge::reader(){
 std::string previous;auto nextReport=std::chrono::steady_clock::time_point{};
 while(!stopping_){
  try{
   auto text=readBounded(directory_/"input.txt");
   if(!text.empty()&&text!=previous){auto parsed=std::make_shared<LiveInput>(parseInput(text));previous=std::move(text);
    if(parsed->run==run_){std::lock_guard lock(mutex_);if(!incoming_||parsed->epoch>incoming_->epoch||(parsed->epoch==incoming_->epoch&&(parsed->session!=incoming_->session||parsed->batch>incoming_->batch))){incoming_=std::move(parsed);incomingAt_=std::chrono::steady_clock::now();}}
   }

  }catch(const std::exception& e){
   const auto now=std::chrono::steady_clock::now();
   if(now>=nextReport){std::cerr<<"[CI Live input] "<<e.what()<<'\n';nextReport=now+std::chrono::seconds(5);}
  }
  std::this_thread::sleep_for(std::chrono::milliseconds(15));
 }
}
void LiveBridge::publishPlants(std::string snapshot){std::lock_guard lock(mutex_);pendingPlants_=std::move(snapshot);cv_.notify_one();}
void LiveBridge::worker(){
 std::unique_ptr<Sample> last;bool reported=false;auto lastStatus=std::chrono::steady_clock::time_point{};
 while(true){
  std::unique_ptr<Sample> sample;std::unique_ptr<LiveCheckpoint> saved;std::string plants;
  {std::unique_lock lock(mutex_);cv_.wait_for(lock,std::chrono::milliseconds(10),[&]{return pending_||checkpointPending_||!pendingPlants_.empty()||stopping_;});sample=std::move(pending_);saved=std::move(checkpointPending_);plants=std::move(pendingPlants_);pendingPlants_.clear();}
  try{
   if(saved){atomicWrite(directory_/"checkpoint.bin",saved->encode());durableAck_=saved->ack;durableSession_=saved->session;}
   if(!plants.empty()){if(memory_){auto p=std::make_shared<const std::string>(std::move(plants));std::lock_guard lock(mutex_);memoryPlants_=std::move(p);}else atomicWrite(directory_/"plants.json",plants);}
   if(sample){auto encoded=encode(*sample);if(memory_){auto p=std::make_shared<const std::string>(std::move(encoded));std::lock_guard lock(mutex_);memorySnapshot_=std::move(p);memorySnapshotAt_=std::chrono::steady_clock::now();}else atomicWrite(directory_/"snapshot.json",encoded);last=std::move(sample);}
   std::string state;double age=-1;std::uint32_t receivedBatch=0;
   {std::lock_guard lock(mutex_);state=status_;if(incoming_){receivedBatch=incoming_->batch;age=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-incomingAt_).count();}}
   if(!memory_&&(state!=publishedStatus_||std::chrono::steady_clock::now()-lastStatus>std::chrono::seconds(1))){
    atomicWrite(directory_/"bridge_status.json","{\"build\":\"hardened-v3\",\"run\":\""+run_+"\",\"boot\":\""+boot_+"\",\"publishedUtcMs\":"+std::to_string(std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count())+",\"status\":\""+state+"\",\"receivedBatch\":"+std::to_string(receivedBatch)+",\"inputAgeMs\":"+std::to_string(age)+"}");publishedStatus_=state;lastStatus=std::chrono::steady_clock::now();
   }
   ioHealthy_=true;reported=false;
  }catch(const std::exception& e){ioHealthy_=false;if(!reported)std::cerr<<"[CI Live] "<<e.what()<<'\n';reported=true;}
  if(stopping_){
   // Shutdown may arrive during file I/O after a newer forced checkpoint was
   // queued. Drain that work before publishing the stopped marker and exiting.
   bool drained;
   {std::lock_guard lock(mutex_);drained=!pending_&&!checkpointPending_&&pendingPlants_.empty();}
   if(!drained)continue;
   try{if(last&&!memory_)atomicWrite(directory_/"snapshot.json",encode(*last,true));}catch(...){}
   break;
  }
 }
}
std::shared_ptr<const std::string> LiveBridge::memorySnapshot(){std::lock_guard lock(mutex_);return memorySnapshot_;}
std::shared_ptr<const std::string> LiveBridge::memoryPlants(){std::lock_guard lock(mutex_);return memoryPlants_;}
void LiveBridge::submitObserver(LiveInput input){
 if(!memory_||input.run!=run_||input.boot!=boot_||!input.poses.empty()||!input.actors.empty()||!input.events.empty())throw std::runtime_error("Invalid native observer input");
 auto p=std::make_shared<LiveInput>(std::move(input));std::lock_guard lock(mutex_);
 if(!incoming_||p->epoch>incoming_->epoch||(p->epoch==incoming_->epoch&&p->session==incoming_->session&&p->batch>=incoming_->batch)){incoming_=std::move(p);incomingAt_=std::chrono::steady_clock::now();}
}
double LiveBridge::memorySnapshotAge(){std::lock_guard lock(mutex_);return memorySnapshot_?std::chrono::duration<double>(std::chrono::steady_clock::now()-memorySnapshotAt_).count():0;}
double LiveBridge::observerAge(){std::lock_guard lock(mutex_);return incoming_?std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-incomingAt_).count():-1;}
std::string LiveBridge::nativeStatus(){std::lock_guard lock(mutex_);return status_;}

}
