#pragma once
#include "agent_body_contract.hpp"
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <vector>
#include <stdexcept>
#include <utility>
namespace ci::body {
struct Pose { std::uint32_t agent_id{},tick{}; std::uint16_t design_id{}; std::vector<double> angles; };
inline constexpr double pi=3.14159265358979323846;
inline void put(std::vector<std::uint8_t>& b,std::size_t o,std::uint32_t v,unsigned n) { for(unsigned i=0;i<n;++i)b[o+i]=std::uint8_t(v>>(8*i)); }
inline std::uint32_t get(const std::vector<std::uint8_t>& b,std::size_t o,unsigned n) { std::uint32_t v=0;for(unsigned i=0;i<n;++i)v|=std::uint32_t(b[o+i])<<(8*i);return v; }
inline std::vector<std::uint8_t> encode(const Pose& p) {
 const auto* d=find(p.design_id);if(!d||p.angles.size()!=d->count)throw std::invalid_argument("Invalid body pose");
 std::vector<std::uint8_t> b(20+2*d->count,0);
 put(b,0,0x31425043,4);put(b,4,schema_version,2);put(b,6,p.design_id,2);put(b,8,p.agent_id,4);put(b,12,p.tick,4);put(b,16,d->count,2);
 for(std::size_t i=0;i<p.angles.size();++i){const double a=p.angles[i];if(!std::isfinite(a)||std::abs(a)>pi)throw std::invalid_argument("Invalid angle");const auto q=std::int32_t(std::round(a*32767/pi));put(b,20+2*i,std::uint16_t(q),2);}return b;
}
inline bool decode(const std::vector<std::uint8_t>& b,Pose& out) {
 if(b.size()<20||get(b,0,4)!=0x31425043||get(b,4,2)!=schema_version||get(b,18,2)!=0)return false;
 const auto id=std::uint16_t(get(b,6,2));const auto* d=find(id);if(!d||get(b,16,2)!=d->count||b.size()!=std::size_t(20)+2*d->count)return false;
 Pose p;p.agent_id=get(b,8,4);p.tick=get(b,12,4);p.design_id=id;
 for(unsigned i=0;i<d->count;++i){auto q=std::int32_t(get(b,20+2*i,2));if(q>=32768)q-=65536;if(q==-32768)return false;p.angles.push_back(q*pi/32767);}out=std::move(p);return true;
}
} // namespace ci::body
