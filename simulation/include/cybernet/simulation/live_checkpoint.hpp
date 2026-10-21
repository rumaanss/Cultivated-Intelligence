#pragma once
#include "cybernet/simulation/organism.hpp"
#include "cybernet/world/chemistry.hpp"
#include "cybernet/random.hpp"
#include <cstring>
#include <sstream>
#include <type_traits>
#ifdef CI_FULL_POND
#include "cybernet/world/pond_geometry_generated.hpp"
#endif
namespace cybernet {
// Local, same-build checkpoint. Never import untrusted or cross-build files.
// Complete mutable biological state; derived spatial indexes rebuild after load.
inline std::string checkpointAbi(){
#ifdef _MSC_VER
 std::string abi="msvc-"+std::to_string(_MSC_VER);
#else
 std::string abi=std::string("gcc-")+__VERSION__;
#endif
#ifdef CI_FULL_POND
 abi+="-pond-";abi+=pond_geometry::Digest;abi+="-producer2";
#endif
#ifdef CI_PLANET_LAKE
 abi+="-cpp-motion-v1";
#endif
 return abi;
}
inline std::uint64_t checkpointHash(std::string_view s){std::uint64_t h=1469598103934665603ULL;for(unsigned char c:s){h^=c;h*=1099511628211ULL;}return h;}
struct LiveCheckpoint {
 std::string run,session,rng,island;std::uint32_t tick{},nextId{},ack{},epoch{};
 ChemistryField chemistry;std::vector<Organism> population;
 std::string encode()const{
  static_assert(std::is_trivially_copyable_v<Organism> && std::is_trivially_copyable_v<ChemistryField>);
  std::string bytes(reinterpret_cast<const char*>(&chemistry),sizeof chemistry);
  if(!population.empty())bytes.append(reinterpret_cast<const char*>(population.data()),population.size()*sizeof(Organism));
  std::ostringstream out;out.imbue(std::locale::classic());
  std::ostringstream metadata;metadata.imbue(std::locale::classic());metadata<<run<<' '<<(session.empty()?"-":session)<<' '<<tick<<' '<<nextId<<' '<<ack<<' '<<epoch<<'\n'<<rng<<'\n'<<island.size()<<'\n';
  bytes.insert(0,metadata.str());bytes.append(island);
  out<<"CICKPT4 "<<checkpointAbi()<<' '<<sizeof(Organism)<<' '<<sizeof(ChemistryField)<<' '<<population.size()<<' '<<checkpointHash(bytes)<<'\n';
  return out.str()+bytes;
 }
 static LiveCheckpoint decode(const std::string& text){
  std::istringstream in(text);in.imbue(std::locale::classic());std::string magic,abi;std::size_t os,cs,n;std::uint64_t hash;
  if(!(in>>magic>>abi>>os>>cs>>n>>hash)||magic!="CICKPT4"||abi!=checkpointAbi()||os!=sizeof(Organism)||cs!=sizeof(ChemistryField)||n>10000)throw std::runtime_error("Checkpoint build/schema mismatch");
  in.ignore(std::numeric_limits<std::streamsize>::max(),'\n');
  const auto offset=static_cast<std::size_t>(in.tellg());
  if(offset>text.size()||checkpointHash(std::string_view(text).substr(offset))!=hash)throw std::runtime_error("Checkpoint checksum mismatch");
  LiveCheckpoint c;if(!(in>>c.run>>c.session>>c.tick>>c.nextId>>c.ack>>c.epoch))throw std::runtime_error("Checkpoint header corrupt");
  if(c.session=="-"){c.session.clear();}
  in.ignore(std::numeric_limits<std::streamsize>::max(),'\n');std::getline(in,c.rng);
  std::size_t islandSize=0;if(!(in>>islandSize)||islandSize>32*1024*1024)throw std::runtime_error("Island checkpoint size");
  in.ignore(std::numeric_limits<std::streamsize>::max(),'\n');
  std::string bytes{std::istreambuf_iterator<char>(in),{}};
  if(bytes.size()!=cs+n*os+islandSize)throw std::runtime_error("Checkpoint checksum/length mismatch; refusing silent rollback");
  std::memcpy(&c.chemistry,bytes.data(),cs);c.population.resize(n);if(n)std::memcpy(c.population.data(),bytes.data()+cs,n*os);
  c.island=bytes.substr(cs+n*os,islandSize);return c;
 }
};
}
