#include "native_server.hpp"
#include "cybernet/simulation/live_bridge.hpp"
#include "cybernet/world/planet_contract_generated.hpp"
#include "json.hpp"
#include "httplib.h"
#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <deque>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <mutex>
#include <random>
#include <set>
#include <sstream>
#include <thread>
#ifndef _WIN32
#include <sys/stat.h>
#endif
namespace cybernet::transport {
using J=nlohmann::json;
using Clock=std::chrono::steady_clock;
static double age(Clock::time_point at){return std::chrono::duration<double>(Clock::now()-at).count();}
static void need(bool ok,const char* why){if(!ok)throw std::invalid_argument(why);}
static bool integer(const J&v,unsigned lo=0,unsigned hi=2147483647){return v.is_number_integer()&&v.get<double>()>=lo&&v.get<double>()<=hi;}
static bool token(const std::string&s){return !s.empty()&&s.size()<=100&&std::all_of(s.begin(),s.end(),[](unsigned char c){return (c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9')||c=='-'||c=='_';});}
static J readJson(const std::filesystem::path&p){std::ifstream f(p);if(!f)throw std::runtime_error("Missing file: "+p.string());return J::parse(f);}
static std::string secret(){std::random_device r;std::ostringstream s;for(int i=0;i<8;i++)s<<std::hex<<std::setw(8)<<std::setfill('0')<<static_cast<std::uint32_t>(r());return s.str();}
Options parseArguments(int argc,char**argv){
 Options o;o.arguments.push_back(argv[0]);
 for(int i=1;i<argc;++i){std::string a=argv[i];auto value=[&](){if(++i>=argc)throw std::invalid_argument("Missing value for "+a);return std::string(argv[i]);};
  if(a=="--port"){o.port=std::stoi(value());need(o.port>0&&o.port<65536,"Invalid port");}
  else if(a=="--project-root")o.root=value();
  else if(a=="--roblox-root")o.roblox=value();
  else if(a=="--autonomous")o.autonomous=true;
  else if(a=="--unpaced")o.unpaced=true;
  else {o.arguments.push_back(argv[i]);if(a=="--live-dir"){auto v=value();o.runtime=v;o.arguments.push_back(argv[i]);}}
 }
 need(readJson(o.root/"contracts/identity.json")["habitat"]["sha256"]==planet_contract::Digest,"Compiled habitat differs from project contract; rebuild generated contracts first");
 need(readJson(o.runtime/"planet_habitat.json")==readJson(o.root/"contracts/planet_habitat.json"),"Runtime habitat differs from project contract");
 return o;
}
struct NativeServer::Impl {
 LiveBridge& bridge;Options options;httplib::Server server;std::thread thread;
 std::mutex exchangeMutex,metricsMutex;
 std::string key,owner,boot,run,cachedPayload,cachedReply;
 unsigned epoch{},batch{},sentBatch{};
 std::atomic<std::shared_ptr<const J>> aquaticIncoming;
 J snapshot,plants,habitat,identity;std::shared_ptr<const std::string> snapshotPtr,plantPtr;
 Clock::time_point snapshotAt=Clock::now(),plantAt=Clock::now(),lastRequest=Clock::now(),lastTickAt=Clock::now(),rateAt=Clock::now();
 unsigned lastTick{},rateTick{};double rate{};
 std::map<unsigned,J> confirmed,sent;
 struct Row{unsigned id;std::array<double,3> p;std::size_t index;};std::vector<Row> rows;
 std::deque<J> history;
 struct Transfer{std::string id,text;Clock::time_point at;};std::deque<Transfer> transfers;
 std::deque<Clock::time_point> calls,auxiliaryCalls;
 J profile=J::object();std::deque<double> tickTimes,httpTimes;
 std::string transferNonce=secret().substr(0,48);
 std::uint64_t transferCounter{},tickCount{};double totalTickMs{};
 Impl(LiveBridge&b,const Options&o,std::string initialAquatic):bridge(b),options(o),boot(b.bootId()),run(b.runId()),epoch(b.initialEpoch()) {
  if(!initialAquatic.empty())publishAquatic(std::move(initialAquatic));
  habitat=readJson(o.root/"contracts/planet_habitat.json");identity=readJson(o.root/"contracts/identity.json");
  need(readJson(o.root/"contracts/identity.json")["habitat"]["sha256"]==planet_contract::Digest,"Compiled habitat differs from project contract; rebuild generated contracts first");
 need(readJson(o.runtime/"planet_habitat.json")==habitat,"Runtime habitat differs from compiled project contract");
  auto path=o.runtime/"native.token";
  if(std::filesystem::exists(path)){std::ifstream f(path);std::getline(f,key);}else{key=secret();LiveBridge::atomicWrite(path,key+"\n");}
  need(key.size()==64&&token(key),"Invalid native.token");
#ifndef _WIN32
  if(chmod(path.c_str(),0600)!=0)throw std::runtime_error("Cannot restrict native token permissions");
#endif
  server.new_task_queue=[](){return new httplib::ThreadPool(4,8);};
  server.set_payload_max_length(3*1024*1024);server.set_read_timeout(2,0);server.set_write_timeout(2,0);server.set_keep_alive_max_count(100);
  for(const auto* route:{"/exchange","/plants","/habitat","/telemetry","/health"})server.Post(route,[this](const httplib::Request&req,httplib::Response&res){handle(req,res);});
  if(!server.bind_to_port("127.0.0.1",o.port))throw std::runtime_error("Native HTTP port already in use. Stop the old relay; do not run two transports.");
  auto roblox=o.roblox.is_absolute()?o.roblox:o.root/o.roblox;
  if(!std::filesystem::exists(roblox/"default.project.json"))throw std::runtime_error("Invalid Roblox project root");
  LiveBridge::atomicWrite(roblox/"src/server/LiveTransportConfig.lua","--!strict\n-- Generated server-only credentials. Never commit.\nreturn table.freeze({Url=\"http://localhost:"+std::to_string(o.port)+"/exchange\",Token=\""+key+"\"})\n");
  thread=std::thread([this](){server.listen_after_bind();});
  std::cout<<"[CI Native] Loopback HTTP port "<<o.port<<"; in-memory transport; sync Rojo before Play.\n";
 }
 ~Impl(){server.stop();if(thread.joinable())thread.join();}
 bool authorized(const httplib::Request&r){
  if(r.get_header_value_count("X-CI-Token")!=1)return false;
  auto value=r.get_header_value("X-CI-Token");unsigned diff=static_cast<unsigned>(value.size()^key.size());
  for(std::size_t i=0;i<key.size();++i)diff|=static_cast<unsigned char>(key[i])^(i<value.size()?static_cast<unsigned char>(value[i]):0);return diff==0;
 }
 void load(){
  auto p=bridge.memorySnapshot();if(!p)throw std::runtime_error("waiting for C++ publisher");
  if(p==snapshotPtr)return;
  J next=J::parse(*p);need(next["manifest"]["runId"]==run&&next["boot"]==boot,"Publisher identity mismatch");
  need(next["manifest"]["geometry"]["sha256"]==identity["habitat"]["sha256"],"Publisher habitat mismatch");
  std::vector<Row> index;index.reserve(next["agents"].size());
  for(std::size_t i=0;i<next["agents"].size();++i){const auto&r=next["agents"][i];index.push_back({r[0].get<unsigned>(),{r[2].get<double>(),r[3].get<double>(),r[4].get<double>()},i});}
  if(next["tick"]!=lastTick){lastTick=next["tick"];lastTickAt=Clock::now();}
  if(age(rateAt)>=1){rate=(lastTick-rateTick)/age(rateAt);rateTick=lastTick;rateAt=Clock::now();}
  snapshot=std::move(next);rows=std::move(index);snapshotPtr=std::move(p);snapshotAt=Clock::now();
 }
 std::map<unsigned,J> select(const J&q){
  std::set<std::size_t> chosen;
  need(q.contains("observer"),"Native transport requires bounded observer regions");auto&v=q["observer"];
  need(v.is_object()&&v.value("version",0)==1&&v.contains("regions")&&v["regions"].is_array()&&v["regions"].size()>=1&&v["regions"].size()<=4,"observer region budget");
  for(const auto&r:v["regions"]){
   need(r.is_object()&&r.contains("center")&&r["center"].is_array()&&r["center"].size()==3,"observer center");
   std::array<double,3> c;for(int j=0;j<3;++j){need(r["center"][j].is_number(),"observer center");c[j]=r["center"][j];need(std::isfinite(c[j])&&std::abs(c[j])<=10000,"observer center");}
   auto limit=r.value("limit",J(384)),pin=r.value("selected",J(0));need(integer(limit,1,384)&&integer(pin),"observer selection budget");
   std::vector<std::pair<double,std::size_t>> nearest;nearest.reserve(rows.size());
   for(std::size_t i=0;i<rows.size();++i){double d=0;for(int j=0;j<3;++j)d+=(rows[i].p[j]-c[j])*(rows[i].p[j]-c[j]);nearest.emplace_back(d,i);}
   auto n=std::min<std::size_t>(limit.get<unsigned>(),nearest.size());
   std::partial_sort(nearest.begin(),nearest.begin()+n,nearest.end(),[&](auto&a,auto&b){return a.first!=b.first?a.first<b.first:rows[a.second].id<rows[b.second].id;});
   std::vector<std::size_t> ids;for(std::size_t i=0;i<n;++i)ids.push_back(nearest[i].second);
   auto found=std::find_if(rows.begin(),rows.end(),[&](const Row&row){return row.id==pin;});
   if(found!=rows.end()){auto k=static_cast<std::size_t>(found-rows.begin());if(std::find(ids.begin(),ids.end(),k)==ids.end()){if(!ids.empty())ids.pop_back();ids.push_back(k);}}
   chosen.insert(ids.begin(),ids.end());
  }
  std::map<unsigned,J> result;for(auto i:chosen)result.emplace(rows[i].id,snapshot["agents"][rows[i].index]);return result;
 }
 J plantPacket(const J&q){
  need(q.is_object()&&q.value("schema",0)==1,"plant protocol");
  if(q.contains("transfer")&&!q["transfer"].is_null()&&q["transfer"]!=""){
   need(q["transfer"].is_string()&&q["transfer"].get<std::string>().size()==64&&integer(q.value("chunk",J(1)),1,32),"plant transfer query");
   for(auto&t:transfers)if(q["transfer"]==t.id)return page(t,q.value("chunk",1));
  }
  auto p=bridge.memoryPlants();if(!p)throw std::runtime_error("waiting for plant publisher");
  if(p!=plantPtr){need(p->size()<=8*1024*1024,"plant snapshot budget");J next=J::parse(*p);need(next["plants"].size()<=512,"plant budget");if(!plants.is_null()){need(next["revision"]>=plants["revision"],"plant revision rollback");history.push_back(plants);while(history.size()>8)history.pop_front();}plants=std::move(next);plantPtr=p;plantAt=Clock::now();}
  J out=plants;out.erase("plants");out["age"]=age(plantAt);out["upsert"]=J::array();out["removed"]=J::array();out["base"]=0;out["reset"]=true;
  const J*old=nullptr;
  if(q.value("run",J())==plants["run"]&&q.value("revision",J())==plants["revision"])old=&plants;
  else for(auto&i:history)if(q.value("run",J())==i["run"]&&q.value("revision",J())==i["revision"])old=&i;
  if(old){out["reset"]=false;out["base"]=(*old)["revision"];std::map<unsigned,const J*> previous;for(auto&r:(*old)["plants"])previous[r["id"].get<unsigned>()]=&r;
   for(auto&r:plants["plants"]){auto it=previous.find(r["id"].get<unsigned>());if(it==previous.end())out["upsert"].push_back(r);else{if(r!=*it->second){J change=r;if(r.value("organs",J())==it->second->value("organs",J()))change.erase("organs");out["upsert"].push_back(std::move(change));}previous.erase(it);}}
   for(auto&[id,r]:previous)out["removed"].push_back(id);
  }else out["upsert"]=plants["plants"];
  auto encoded=out.dump();if(encoded.size()<=256*1024)return out;need(encoded.size()<=8*1024*1024,"plant transfer budget");
  std::ostringstream id;id<<transferNonce<<std::hex<<std::setw(16)<<std::setfill('0')<<++transferCounter;
  transfers.push_back({id.str(),std::move(encoded),Clock::now()});while(transfers.size()>3)transfers.pop_front();return page(transfers.back(),1);
 }
 J page(const Transfer&t,std::size_t index){auto count=(t.text.size()+256*1024-1)/(256*1024);need(index>=1&&index<=count,"plant chunk index");return {{"chunked",true},{"transfer",t.id},{"index",index},{"count",count},{"data",t.text.substr((index-1)*256*1024,256*1024)},{"age",age(t.at)}};}
 void publishAquatic(std::string text){
  need(text.size()<2*1024*1024,"aquatic snapshot budget");
  // Parse once on publication, never on the latency-sensitive HTTP worker.
  aquaticIncoming.store(std::make_shared<const J>(J::parse(text)));
 }
 J aquaticPacket(const J&q){
  auto p=aquaticIncoming.load();if(!p)return nullptr;
  const auto &aquatic=*p;
  std::set<unsigned> ids;
  for(const auto&r:q["observer"]["regions"]){
   double x=r["center"][0],y=r["center"][1],z=r["center"][2];
   std::vector<std::pair<double,unsigned>> nearest;
   for(unsigned i=0;i<aquatic["patches"].size();++i){auto& row=aquatic["patches"][i];double dx=row[1].get<double>()-x,dy=row[2].get<double>()-y;
    double dz=std::max({row[3].get<double>()-z,z-108.,0.});double d=dx*dx+dy*dy+dz*dz;
    if(d<=160*160)nearest.emplace_back(d,i);}
   std::sort(nearest.begin(),nearest.end());
   for(unsigned i=0;i<std::min<std::size_t>(24,nearest.size());++i)ids.insert(nearest[i].second);
  }
  std::string token=run+":"+std::to_string(aquatic["revision"].get<unsigned>());
  for(auto id:ids)token+=":"+std::to_string(id);
  if(q.value("aquaticToken",std::string())==token)return nullptr;
  J out=J::object();
  // Copy metadata only. Never deep-copy the whole lake just to discard it.
  for(auto it=aquatic.begin();it!=aquatic.end();++it)
   if(it.key()!="patches"&&it.key()!="colonies"&&it.key()!="lifecycle"&&it.key()!="algae"&&it.key()!="food")out[it.key()]=it.value();
  out["patches"]=J::array();for(auto id:ids)out["patches"].push_back(aquatic["patches"][id]);if(aquatic.contains("colonies")){out["colonies"]=J::array();for(const auto& colony:aquatic["colonies"]){auto patch=colony[0].get<unsigned>();if(patch>0&&ids.count(patch-1))out["colonies"].push_back(colony);}}if(aquatic.contains("lifecycle")){out["lifecycle"]=J::array();for(const auto& event:aquatic["lifecycle"]){auto patch=event[4].get<unsigned>();if(patch>0&&ids.count(patch-1))out["lifecycle"].push_back(event);}}for(const auto *key:{"algae","food"})if(aquatic.contains(key)){out[key]=J::array();for(const auto &row:aquatic[key]){auto patch=row[0].get<unsigned>();if(patch>0&&ids.count(patch-1))out[key].push_back(row);}}out["token"]=token;return out;
 }
 J exchange(const J&q){
  auto started=Clock::now();load();auto loadedAt=Clock::now();need(q.is_object()&&q.value("protocol",0)==1&&q.contains("session")&&q["session"].is_string()&&token(q["session"]),"invalid request");
  auto current=select(q);auto selectedAt=Clock::now();auto observed=[&](){J out=snapshot;out["agents"]=J::array();for(auto&[id,r]:current)out["agents"].push_back(r);out["total"]=rows.size();return out;};
  if(q.value("run",J())!=run)return {{"protocol",1},{"reset",true},{"manifest",snapshot["manifest"]},{"snapshot",observed()},{"age",bridge.memorySnapshotAge()}};
  need(integer(q.value("batch",J()),1)&&integer(q.value("ackBatch",J(0))),"invalid batch");unsigned nextBatch=q["batch"],acked=q.value("ackBatch",0u);need(acked<nextBatch,"invalid response acknowledgment");
  for(auto*field:{"poses","actors","events"})need(!q.contains(field)||(q[field].is_array()&&q[field].empty()),"C++ motion world accepts observer heartbeats only");
  need(integer(q.value("correctionAck",J(0))),"invalid correction acknowledgment");
  std::string session=q["session"];
  if(session!=owner){need(owner.empty()||age(lastRequest)>8,"world already leased or has uncommitted events");owner=session;need(epoch<2147483647,"Lease epoch exhausted");++epoch;batch=sentBatch=0;cachedPayload.clear();cachedReply.clear();confirmed.clear();sent.clear();}
  lastRequest=Clock::now();
  if(q.value("boot",J())!=boot)return {{"protocol",1},{"resync",true},{"snapshot",observed()},{"batch",nextBatch},{"epoch",epoch},{"session",session}};
  auto payload=q.dump();need(nextBatch>=batch,"old batch");if(nextBatch==batch)need(payload==cachedPayload,"batch identity reused with different payload");
  LiveInput input;input.run=run;input.boot=boot;input.session=session;input.epoch=epoch;input.batch=nextBatch;input.correctionAck=q.value("correctionAck",0u);bridge.submitObserver(std::move(input));
  if(nextBatch==batch&&!cachedReply.empty())return J::parse(cachedReply);
  auto base=acked==sentBatch?sent:confirmed;
  J added=J::array(),updates=J::array(),removed=J::array(),motions=J::array();
  for(auto&[id,r]:current){auto prior=base.find(id);if(prior==base.end())added.push_back(r);else if(prior->second!=r){J update=J::array({r[0],r[8],r[9]});for(int i=13;i<25;++i)update.push_back(r[i]);updates.push_back(std::move(update));}motions.push_back(J::array({r[0],r[2],r[3],r[4],r[5],r[6],r[7]}));}
  for(auto&[id,r]:base)if(!current.count(id))removed.push_back(id);
  bool same=snapshot["session"]==session;
  J out={{"protocol",1},{"reset",false},{"run",run},{"session",session},{"batch",nextBatch},{"sequence",snapshot["sequence"]},{"tick",snapshot["tick"]},{"ack",same?snapshot["ack"]:J(0)},{"light",snapshot["light"]},{"state",snapshot["state"]},{"age",bridge.memorySnapshotAge()},{"stalled",age(lastTickAt)>3&&lastTick>0},{"total",rows.size()},{"visible",current.size()},{"viewVersion",1},{"added",added},{"updates",updates},{"removed",removed},{"motions",motions},{"epoch",epoch},{"boot",boot},{"durableAck",same?snapshot.value("durableAck",J(0)):J(0)},{"bridgeBuild","hardened-v3"},{"transportBuild","native-memory-v1"},{"corrections",same?snapshot.value("corrections",J::array()):J::array()},{"bridgeStatus",bridge.nativeStatus()},{"cppInputAgeMs",bridge.observerAge()},{"cppReceivedBatch",nextBatch},{"eventError",nullptr}};
  auto agentsAt=Clock::now();
  if(q.contains("plants")){try{out["plants"]=plantPacket(q["plants"]);}catch(const std::exception&e){out["plantError"]=e.what();}}
  auto water=aquaticPacket(q);if(!water.is_null())out["aquatic"]=std::move(water);
  auto plantsAt=Clock::now();
  auto ms=[](auto a,auto b){return std::chrono::duration<double,std::milli>(b-a).count();};
  out["exchangeStagesMs"]={{"snapshot",ms(started,loadedAt)},{"selection",ms(loadedAt,selectedAt)},{"agents",ms(selectedAt,agentsAt)},{"plants",ms(agentsAt,plantsAt)}};
  out["exchangeCounts"]={{"population",rows.size()},{"visible",current.size()}};
  out["relayTimingMs"]=J::array({0,0,age(started)*1000});
  // Commit the identity and delta base together only after encoding succeeds.
  auto encoded=out.dump();confirmed=std::move(base);sent=std::move(current);sentBatch=batch=nextBatch;cachedPayload=std::move(payload);cachedReply=std::move(encoded);return out;
 }
 void handle(const httplib::Request&r,httplib::Response&response){
  auto start=Clock::now();response.set_header("Cache-Control","no-store");
  auto send=[&](int status,const J&v){response.status=status;response.set_content(v.dump(),"application/json");};
  if(!authorized(r)){send(401,{{"error","unauthorized"}});return;}
  try{
   need(!r.has_header("Transfer-Encoding")&&r.get_header_value_count("Content-Length")==1&&!r.body.empty(),"invalid framing");
   std::vector<std::set<std::string>> keys;
   auto q=J::parse(r.body,[&](int depth,J::parse_event_t event,J&value){need(depth<=64,"JSON depth budget");if(event==J::parse_event_t::object_start)keys.emplace_back();else if(event==J::parse_event_t::object_end)keys.pop_back();else if(event==J::parse_event_t::key)need(keys.back().insert(value.get<std::string>()).second,"duplicate JSON key");return true;});
   std::lock_guard lock(exchangeMutex);
   auto& budget=r.path=="/exchange"?calls:auxiliaryCalls;
   while(!budget.empty()&&age(budget.front())>60)budget.pop_front();need(budget.size()<(r.path=="/exchange"?420u:180u),"relay request budget exceeded");budget.push_back(Clock::now());
   if(r.path=="/exchange")send(200,exchange(q));
   else if(r.path=="/plants")send(200,plantPacket(q));
   else if(r.path=="/habitat"){need(q==habitat,"habitat changed; native build requires matching contract");send(200,{{"schema",1},{"id",habitat["id"]},{"sha256",identity["habitat"]["sha256"]},{"biologyEnabled",false}});}
   else {load();std::lock_guard metricLock(metricsMutex);J result=profile;result["schema"]=1;result["SimulationTick"]=snapshot["tick"];result["SimulationTicksPerSecond"]=rate;result["SnapshotAgeSeconds"]=bridge.memorySnapshotAge();result["state"]=bridge.nativeStatus();result["RelayWorkMs"]=age(start)*1000;result["transport"]="native-memory-v1";result["liveFileReads"]=0;result["liveFileWrites"]=0;send(200,result);}
  }catch(const nlohmann::json::exception&e){send(409,{{"error",std::string("invalid JSON/schema: ")+e.what()}});}
  catch(const std::invalid_argument&e){send(409,{{"error",e.what()}});}
  catch(const std::exception&e){send(503,{{"error",e.what()}});}
  std::lock_guard lock(metricsMutex);httpTimes.push_back(age(start)*1000);while(httpTimes.size()>256)httpTimes.pop_front();
 }
 void record(unsigned tick,double ms,const double*phases){
  std::lock_guard lock(metricsMutex);++tickCount;totalTickMs+=ms;tickTimes.push_back(ms);while(tickTimes.size()>256)tickTimes.pop_front();
  auto percentile=[](const std::deque<double>&d,double p){if(d.empty())return 0.;std::vector<double> s(d.begin(),d.end());std::sort(s.begin(),s.end());return s[static_cast<std::size_t>((s.size()-1)*p)];};
  profile["profileTick"]=tick;profile["tickMeanMs"]=totalTickMs/tickCount;profile["tickP95Ms"]=percentile(tickTimes,.95);profile["httpP95Ms"]=percentile(httpTimes,.95);
  const char* names[]={"environmentMs","decisionMs","movementMs","interactionMs","populationMs","metricsMs"};for(int i=0;i<6;++i)profile[names[i]]=phases[i]*1000/tickCount;
 }
};
NativeServer::NativeServer(LiveBridge&b,const Options&o,std::string initialAquatic):impl_(std::make_unique<Impl>(b,o,std::move(initialAquatic))){}
NativeServer::~NativeServer()=default;
void NativeServer::publishAquatic(std::string snapshot){impl_->publishAquatic(std::move(snapshot));}
void NativeServer::recordTick(unsigned tick,double ms,const double*phases){impl_->record(tick,ms,phases);}
}
