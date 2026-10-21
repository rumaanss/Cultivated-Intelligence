#pragma once
#include <filesystem>
#include <memory>
#include <vector>
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
 NativeServer(LiveBridge&,const Options&);
 ~NativeServer();
 void recordTick(unsigned tick,double milliseconds,const double* phases);
};
}
