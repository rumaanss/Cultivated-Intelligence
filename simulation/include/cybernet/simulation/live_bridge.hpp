#pragma once
#include "cybernet/simulation/organism.hpp"
#include "cybernet/simulation/external_actor.hpp"
#include "cybernet/simulation/lifecycle.hpp"
#include "cybernet/world/celestial.hpp"
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <filesystem>
#include <mutex>
#include <thread>
#include <vector>
#include <memory>
#include <string>
#include <map>
#include "cybernet/simulation/live_checkpoint.hpp"

namespace cybernet {
namespace plants {struct World;}
struct LivePose { std::uint32_t id{}; Vec3 position{},velocity{}; };
struct LiveEvent { std::uint32_t sequence{},kind{},agent{},actor{}; float amount{}; };
struct LiveInput { std::string run,session,boot; std::uint32_t batch{},correctionAck{},epoch{}; std::vector<LivePose> poses; std::vector<ExternalActor> actors; std::vector<LiveEvent> events; };
// One pending outgoing snapshot; one incoming latest batch. No network on the tick thread.
class LiveBridge {
public:
 static constexpr std::size_t MaxAgents=10000,MaxActors=64,MaxEvents=512,MaxBytes=3*1024*1024;
 LiveBridge(std::filesystem::path directory,std::uint64_t seed,bool memory=false,bool autonomous=false);
 ~LiveBridge();
 LiveBridge(const LiveBridge&)=delete;LiveBridge& operator=(const LiveBridge&)=delete;
 bool restore(std::vector<Organism>&,ChemistryField&,Random&,std::uint32_t& tick,std::uint32_t& nextId,std::string* island=nullptr);
 void checkpoint(std::span<const Organism>,const ChemistryField&,const Random&,std::uint32_t tick,std::uint32_t nextId,const plants::World* island=nullptr,bool force=false);
 void publishPlants(std::string snapshot);
 bool beginTick(std::vector<Organism>& population,const GeometryWorld& terrain);
 void movement(Organism& organism,LifecycleAction& action) const noexcept;
 void capture(std::uint32_t tick,const CelestialState& light,std::span<const Organism> population,std::span<const LifecycleAction> actions={});
 std::span<const ExternalActor> actors()const{return actors_;}
 const GeometryWorld* geometry() const{return dynamic_.get();}
 const std::string& runId()const{return run_;}
 std::uint32_t acknowledgedEvent()const{return ack_;}
 static LiveInput parseInput(const std::string& text);
 static void atomicWrite(const std::filesystem::path& path,const std::string& value);
 std::shared_ptr<const std::string> memorySnapshot();
 std::shared_ptr<const std::string> memoryPlants();
 void submitObserver(LiveInput input);
 std::string nativeStatus();
 double memorySnapshotAge();
 double observerAge();
 unsigned initialEpoch()const{return epoch_;}
 const std::string& bootId()const{return boot_;}
private:
 bool memory_{false},autonomous_{false};
 std::shared_ptr<const std::string> memorySnapshot_,memoryPlants_;
 std::chrono::steady_clock::time_point memorySnapshotAt_{};
 // Narrow test access for deterministic queue-contention regression coverage.
 friend struct LiveBridgeTestAccess;
 struct Correction {std::uint32_t version{},kind{},id{};Vec3 position{};};
 std::map<std::pair<std::uint32_t,std::uint32_t>,Correction> corrections_;
 std::uint32_t correctionVersion_{},epoch_{};
 std::atomic<std::uint32_t> durableAck_{0};
 std::unique_ptr<LiveCheckpoint> checkpointPending_,restored_;
 std::string pendingPlants_;
 std::chrono::steady_clock::time_point checkpointAt_{};
 std::string boot_,durableSession_;
 void status(const std::string& value);
 std::string status_,publishedStatus_;
 struct Sample {std::uint32_t tick{},sequence{},ack{};CelestialState light{};std::string session;std::vector<std::array<double,25>> agents;std::vector<Correction> corrections;};
 void reader();void worker();std::string encode(const Sample& s,bool stopped=false)const;
 std::filesystem::path directory_;std::string run_,session_,manifest_;
 std::intptr_t lockHandle_{-1};
 std::mutex mutex_;std::condition_variable cv_;std::unique_ptr<Sample> pending_;std::shared_ptr<LiveInput> incoming_;
 std::chrono::steady_clock::time_point incomingAt_{},lastCapture_{};
 std::unique_ptr<GeometryWorld> dynamic_;
 std::vector<ExternalActor> actors_;std::uint32_t batch_{0},ack_{0},sequence_{0};
 std::atomic<bool> stopping_{false},ioHealthy_{true};std::thread thread_,readerThread_;
};
}
