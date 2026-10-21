#include "cybernet/simulation/plant_publisher_lock.hpp"
#include <stdexcept>
#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#else
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#endif
namespace cybernet {
PlantPublisherLock::PlantPublisherLock(const std::filesystem::path& directory){
 const auto path=directory/"plants.publisher.lock";
#ifdef _WIN32
 const auto handle=CreateFileW(path.c_str(),GENERIC_READ|GENERIC_WRITE,0,nullptr,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);
 if(handle==INVALID_HANDLE_VALUE)throw std::runtime_error("Stop ci_plant_sim: another plant publisher owns this live directory");
 handle_=reinterpret_cast<std::intptr_t>(handle);
#else
 handle_=open(path.c_str(),O_CREAT|O_RDWR,0600);
 if(handle_<0||flock(int(handle_),LOCK_EX|LOCK_NB)){if(handle_>=0)close(int(handle_));handle_=-1;throw std::runtime_error("Stop ci_plant_sim: another plant publisher owns this live directory");}
#endif
}
PlantPublisherLock::~PlantPublisherLock(){
#ifdef _WIN32
 if(handle_!=-1)CloseHandle(reinterpret_cast<HANDLE>(handle_));
#else
 if(handle_>=0)close(int(handle_));
#endif
}
}
