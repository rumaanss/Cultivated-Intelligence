#pragma once
#include <filesystem>
#include <functional>
#include <memory>
#include <vector>
#include <string>
namespace cybernet {class LiveBridge;}
namespace cybernet::transport {
struct Options {
 bool enabled=true,autonomous=false,unpaced=false;
 int port=8765;
 std::filesystem::path root=".",runtime="runtime/planet-native-v1",roblox="planet";
 std::vector<char*> arguments;
};
Options parseArguments(int argc,char**argv);
class NativeServer {
 struct Impl;std::unique_ptr<Impl> impl_;
public:
 using Extension = std::function<std::string(const std::string&, const std::string&)>;
 NativeServer(LiveBridge&,const Options&,std::string initialAquatic={}, Extension extension={});
 ~NativeServer();
 void publishAquatic(std::string snapshot);
 void recordTick(unsigned tick,double milliseconds,const double* phases);
};
}
