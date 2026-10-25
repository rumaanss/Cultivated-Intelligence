#include "cybernet/aquatic/lake.hpp"
#include "cybernet/aquatic/stage3.hpp"
#include "cybernet/simulation/live_bridge.hpp"
#include "cybernet/world/planet_geometry_generated.hpp"
#include "json.hpp"
#include "native_server.hpp"
#include <chrono>
#include <csignal>
#include <fstream>
#include <iostream>
#include <memory>
#include <thread>
#ifdef _WIN32
#include <windows.h>
#endif
namespace {
volatile std::sig_atomic_t running = 1;
void stop(int) { running = 0; }
#ifdef _WIN32
BOOL WINAPI consoleEvent(DWORD e) {
  if (e == CTRL_C_EVENT || e == CTRL_BREAK_EVENT || e == CTRL_CLOSE_EVENT) {
    running = 0;
    return TRUE;
  }
  return FALSE;
}
#endif
} // namespace
int main(int argc, char **argv) {
  using namespace cybernet;
  using namespace std::chrono;
  try {
    auto options = transport::parseArguments(argc, argv);
    std::uint64_t seed = 42, stopTick = 2147483000;
    bool newWorld = false, physMode = true, fixed = false, seedExplicit = false;
    std::string migration, configFile;
    for (std::size_t i = 1; i < options.arguments.size(); ++i) {
      std::string a = options.arguments[i];
      auto value = [&]() {
        if (++i >= options.arguments.size())
          throw std::runtime_error("Missing value for " + a);
        return std::string(options.arguments[i]);
      };
      if (a == "--seed") { seed = std::stoull(value()); seedExplicit=true; }
      else if (a == "--ticks")
        stopTick = std::stoull(value());
      else if (a == "--new-world")
        newWorld = true;
      else if (a == "--physiology")
        physMode = true;
      else if (a == "--fixed-genome")
        fixed = true;
      else if (a == "--migrate-pdnarna")
        migration = value();
      else if (a == "--physiology-config")
        configFile = value();
      else if (a == "--live-dir")
        value();
      else
        throw std::runtime_error("Unknown aquatic option: " + a);
    }
    if (stopTick >= 2147483647)
      throw std::runtime_error("Stop tick exceeds protocol limit");
    if (!physMode && (fixed || !migration.empty() || !configFile.empty()))
      throw std::runtime_error("Physiology options require --physiology");
    auto path = options.runtime / (physMode ? "stage3.checkpoint.json"
                                            : "aquatic.checkpoint.json");
    auto opposite = options.runtime / (physMode ? "aquatic.checkpoint.json"
                                                : "stage3.checkpoint.json");
    if (std::filesystem::exists(options.runtime / "checkpoint.bin") ||
        std::filesystem::exists(opposite) || std::filesystem::exists(options.runtime / "physiology.checkpoint.json"))
      throw std::runtime_error(
          "Different biology runtime: choose a separate directory.");
    auto read = [](const std::filesystem::path &p, std::uintmax_t max) {
      if (std::filesystem::file_size(p) > max)
        throw std::runtime_error("Checkpoint/config too large");
      std::ifstream f(p);
      if (!f)
        throw std::runtime_error("Cannot read " + p.string());
      return std::string{std::istreambuf_iterator<char>(f), {}};
    };
    if (!migration.empty() && (fixed || !configFile.empty())) throw std::runtime_error("Migration retains the source configuration; omit override flags");
    if(!seedExplicit && (std::filesystem::exists(path)||!migration.empty())) {
      auto envelope=nlohmann::json::parse(read(std::filesystem::exists(path)?path:std::filesystem::path(migration),256*1024*1024));
      seed=nlohmann::json::parse(envelope.at("payload").get<std::string>()).at("seed").get<std::uint64_t>();
    }
    LiveBridge bridge(options.runtime, seed, true, true);
    aquatic::Lake standalone(seed);
    std::unique_ptr<aquatic::stage3::Physiology> physiology;
    if (std::filesystem::exists(path)) {
      if (newWorld || !migration.empty() || fixed || !configFile.empty())
        throw std::runtime_error(
            "Runtime already exists. Resume without creation options.");
      if (physMode) {
        auto original = read(path, 256 * 1024 * 1024);
        physiology = std::make_unique<aquatic::stage3::Physiology>(
            aquatic::stage3::Physiology::restore(original, seed));

      } else
        standalone = aquatic::Lake::restore(read(path, 4 * 1024 * 1024), seed);
    } else {
      if (!newWorld && migration.empty())
        throw std::runtime_error(
            "No checkpoint. Use --new-world or explicit --migrate-pdnarna.");
      if (newWorld && !migration.empty())
        throw std::runtime_error("Choose founders or migration, not both.");
      if (physMode) {
        aquatic::stage3::PhysiologyConfig config;
        if (!configFile.empty())
          config = aquatic::stage3::PhysiologyConfig::parse(read(configFile, 65536));
        if (fixed)
          config.mutationProbability = 0;
        if (migration.empty())
          physiology = std::make_unique<aquatic::stage3::Physiology>(seed, config);
        else
          physiology = std::make_unique<aquatic::stage3::Physiology>(
              aquatic::stage3::Physiology::migrateStage2(read(migration, 256 * 1024 * 1024), seed));
      }
    }
    auto &lake = physiology ? physiology->environment : standalone;
    auto checkpoint = [&]() {
      return physiology ? physiology->checkpoint() : lake.checkpoint();
    };
    auto snapshot = [&]() {
      return physiology ? physiology->snapshot(bridge.runId())
                        : lake.snapshot(bridge.runId());
    };
    auto validate = [&]() {
      if (physiology)
        physiology->validate();
      else
        lake.validate();
    };
    LiveBridge::atomicWrite(path, checkpoint());
    std::signal(SIGINT, stop);
    std::signal(SIGTERM, stop);
#ifdef _WIN32
    SetConsoleCtrlHandler(consoleEvent, TRUE);
#endif
    GeometryWorld geometry(planet_geometry::Objects, .25F, {},
                           &planet_geometry::Field,
                           {planet_contract::Width, planet_contract::Length,
                            planet_contract::Depth});
    std::vector<Organism> empty;
    CelestialCycle sky(aquatic::Lake::CycleTicks);
    sky.update(static_cast<int>(lake.tick));
    bridge.beginTick(empty, geometry);
    bridge.capture(static_cast<unsigned>(lake.tick), sky.state(), empty);
    auto plants = [&]() {
      return nlohmann::json{{"schema", 1},
                            {"run", bridge.runId()},
                            {"revision", lake.tick},
                            {"tick", lake.tick},
                            {"units", "studs-Y-up"},
                            {"surface", planet_contract::Surface},
                            {"plants", nlohmann::json::array()}}
          .dump();
    };
    bridge.publishPlants(plants());
    transport::NativeServer server(bridge, options, snapshot());
    std::cout
        << "[CI Aquatic] Stage 3 producers, decomposers, grazers and algae; "
        << lake.cells.size() << " water cells; seed " << seed
        << "; restored tick " << lake.tick << "\n"
        << "[CI Aquatic] Autonomous, 20 ticks/s; 600 ticks per biological day. "
           "Ctrl+C saves. Existing land runtime retained.\n"
        << std::flush;
    double phases[6] = {};
    auto next = steady_clock::now(), published = next, saved = next;
    auto saveBudget=[&](){
      if(!physiology)return;
      std::filesystem::create_directories(options.runtime/"food-days");
      auto current=physiology->report();
      LiveBridge::atomicWrite(options.runtime/"stage3-food-current.json",current);
      if(lake.tick>0 && lake.tick%600==0)LiveBridge::atomicWrite(options.runtime/"food-days"/(std::to_string(lake.tick)+".json"),current);
      if(!physiology->lastDay.empty()){auto b=nlohmann::json::parse(physiology->lastDay);auto reportPath=options.runtime/"food-days"/(std::to_string(b.at("endTick").get<unsigned>())+".json");LiveBridge::atomicWrite(reportPath,physiology->lastDay);}
    };
    while (running && lake.tick < stopTick) {
      auto began = steady_clock::now();
      if (!bridge.beginTick(empty, geometry))
        throw std::runtime_error("Native publisher unhealthy");
      if (physiology) physiology->step(); else lake.step();
      if(lake.tick%600==1)saveBudget();
      sky.update(static_cast<int>(lake.tick));
      bridge.capture(static_cast<unsigned>(lake.tick), sky.state(), empty);
      if (steady_clock::now() - published >= seconds(1)) {
        validate();
        server.publishAquatic(snapshot());
        bridge.publishPlants(plants());
        published = steady_clock::now();
      }
      if (steady_clock::now() - saved >= seconds(30)) {
        LiveBridge::atomicWrite(path, checkpoint());
        saved = steady_clock::now();
      }
      double ms =
          duration<double, std::milli>(steady_clock::now() - began).count();
      phases[0] += ms / 1000;
      server.recordTick(static_cast<unsigned>(lake.tick), ms, phases);
      if (!options.unpaced) {
        next += milliseconds(50);
        std::this_thread::sleep_until(next);
        if (steady_clock::now() - next > milliseconds(250))
          next = steady_clock::now();
      }
    }
    LiveBridge::atomicWrite(path, checkpoint());
    saveBudget();
    std::cout << "[CI Aquatic] Saved tick " << lake.tick
              << "; C/N/P and oxygen ledgers verified.\n";
    return 0;
  } catch (const std::exception &e) {
    std::cerr << "[CI Aquatic] " << e.what() << "\n";
    return 1;
  }
}
