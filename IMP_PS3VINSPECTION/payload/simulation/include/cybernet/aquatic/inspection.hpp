#pragma once
#include "cybernet/aquatic/stage3.hpp"
#include <memory>
#include <filesystem>
namespace cybernet::aquatic::stage3 {
// Server callbacks access copies owned by this service, never the live world.
// Administrative identity is deliberately separate from sensory channels.
class Inspection {
 struct Impl; std::unique_ptr<Impl> impl_;
public:
 Inspection(std::string run,std::string boot,std::string mode,
            const std::filesystem::path& runtime,const std::filesystem::path& replay={});
 ~Inspection();
 void publish(const Physiology&);
 // Called only by simulation thread before step. False means wait without advancing biology.
 bool prepare(Physiology&);
 std::string request(const std::string& route,const std::string& body);
};
}
