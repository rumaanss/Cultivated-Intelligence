#include "cybernet/plants/plant_world.hpp"
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <thread>
#include <stdexcept>
#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#else
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#endif
using namespace cybernet::plants;
namespace {
std::string read(const std::filesystem::path& p){if(std::filesystem::file_size(p)>64*1024*1024)throw std::runtime_error("Input file too large");std::ifstream f(p,std::ios::binary);if(!f)throw std::runtime_error("Cannot read input");return {std::istreambuf_iterator<char>(f),{}};}
void atomic(const std::filesystem::path& path,const std::string& text){auto tmp=path;tmp+=".tmp";{std::ofstream f(tmp,std::ios::binary|std::ios::trunc);f<<text;f.flush();if(!f)throw std::runtime_error("Write failed");}
#ifdef _WIN32
 for(unsigned i=0;i<50;++i){if(MoveFileExW(tmp.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH))return;std::this_thread::sleep_for(std::chrono::milliseconds(10));}throw std::runtime_error("Atomic publication failed");
#else
 int fd=open(tmp.c_str(),O_RDONLY);if(fd<0)throw std::runtime_error("Flush open failed");int result=fsync(fd);close(fd);if(result)throw std::runtime_error("Flush failed");std::filesystem::rename(tmp,path);int directory=open(path.parent_path().c_str(),O_RDONLY);if(directory>=0){int synced=fsync(directory);close(directory);if(synced)throw std::runtime_error("Directory flush failed");}
#endif
}
struct Lock {
#ifdef _WIN32
 HANDLE h=INVALID_HANDLE_VALUE;
 explicit Lock(const std::filesystem::path& p){h=CreateFileW(p.c_str(),GENERIC_READ|GENERIC_WRITE,0,nullptr,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);if(h==INVALID_HANDLE_VALUE)throw std::runtime_error("Plant publisher already running");}~Lock(){CloseHandle(h);}
#else
 int fd;
 explicit Lock(const std::filesystem::path& p):fd(open(p.c_str(),O_CREAT|O_RDWR,0600)){if(fd<0||flock(fd,LOCK_EX|LOCK_NB)){if(fd>=0)close(fd);throw std::runtime_error("Plant publisher already running");}}~Lock(){close(fd);}
#endif
};
}
int main(int argc,char** argv){try{
 std::filesystem::path dir="live/state",surface;std::uint64_t seed=731,ticks=1000;unsigned interval=0,founders=12;bool resume=false;Policy policy=Policy::Neural;double rain=.025,light=1;
 for(int i=1;i<argc;++i){std::string a=argv[i];if(a=="--resume"){resume=true;continue;}if(a=="--help"){std::cout<<"ci_plant_sim --directory PATH --surface FILE --seed N --founders N --policy neural|baseline|wait --ticks N (0=continuous) --interval-ms N --rain N --light N [--resume]\n";return 0;}if(i+1>=argc)throw std::runtime_error("Missing option value");std::string v=argv[++i];
  if(a=="--directory")dir=v;else if(a=="--surface")surface=v;else if(a=="--seed")seed=std::stoull(v);else if(a=="--ticks")ticks=std::stoull(v);else if(a=="--interval-ms")interval=unsigned(std::stoul(v));else if(a=="--founders")founders=unsigned(std::stoul(v));else if(a=="--rain")rain=std::stod(v);else if(a=="--light")light=std::stod(v);else if(a=="--policy"){if(v=="neural")policy=Policy::Neural;else if(v=="baseline")policy=Policy::Viable;else if(v=="wait")policy=Policy::Wait;else throw std::runtime_error("Unknown founder policy");}else throw std::runtime_error("Unknown option: "+a);
 }
 if(founders>128||interval>60000||rain<0||rain>10||light<0||light>1||(!ticks&&!interval))throw std::runtime_error("Option outside budget");
 std::filesystem::create_directories(dir);Lock lock(dir/"plants.publisher.lock");World w(seed);
 if(resume){w=World::restore(read(dir/"plants.checkpoint"));}
 else {if(std::filesystem::exists(dir/"plants.checkpoint"))throw std::runtime_error("Existing plant checkpoint: use --resume or a new directory");if(!surface.empty())w.loadSurface(read(surface));w.rainfall=rain;w.daylight=light;
  // New run identity differs even if a prior scene used the same founder seed.
  w.run="plants-"+std::to_string(seed)+"-"+std::to_string(std::chrono::system_clock::now().time_since_epoch().count());
  unsigned placed=0;for(unsigned attempt=0;attempt<founders*500&&placed<founders;++attempt){unsigned c=unsigned(w.random()*w.surface.cells.size());if(!w.surface.cells[c].valid)continue;V p{w.surface.originX+(c%w.surface.width+.5)*w.surface.cellSize,0,w.surface.originZ+(c/w.surface.width+.5)*w.surface.cellSize};w.founder(placed%3,p,policy);++placed;}if(placed!=founders)throw std::runtime_error("Not enough valid planting cells");
 }
 w.validate();atomic(dir/"plants.checkpoint",w.checkpoint());atomic(dir/"plants.json",w.snapshot());
 auto start=std::chrono::steady_clock::now();for(std::uint64_t n=0;ticks==0||n<ticks;++n){w.step();
 if(!w.events.empty()){
  const auto log=dir/"plant_events.jsonl";
  if(std::filesystem::exists(log)&&std::filesystem::file_size(log)>8*1024*1024){auto old=dir/"plant_events.previous.jsonl";if(std::filesystem::exists(old))std::filesystem::remove(old);std::filesystem::rename(log,old);}
  std::ofstream audit(log,std::ios::app);for(auto& e:w.events)audit<<e<<'\n';audit.flush();if(!audit)throw std::runtime_error("Audit write failed");
 }
 if(n%10==0||n+1==ticks){w.validate();atomic(dir/"plants.checkpoint",w.checkpoint());atomic(dir/"plants.json",w.snapshot());}if(interval)std::this_thread::sleep_for(std::chrono::milliseconds(interval));}
 double elapsed=std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count();std::cout<<"Plants tick="<<w.tick<<" current="<<w.plants.size()<<" births+founders="<<w.nextId-1<<" elapsed="<<elapsed<<"s\n";
}catch(const std::exception& e){std::cerr<<"Plants: "<<e.what()<<'\n';return 1;}}
