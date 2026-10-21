#pragma once
#include "cybernet/vec3.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <span>
#include <vector>
#include <bit>
namespace cybernet {
// Piecewise-planar terrain. Matching diagonals and contact math are used in Luau.
struct HeightfieldReference {
 unsigned nx{},ny{};float cell{};std::span<const float> heights;
 unsigned levelsX{},levelsY{};std::vector<float> maxima;
 HeightfieldReference(unsigned x,unsigned y,float spacing,std::span<const float> samples):nx(x),ny(y),cell(spacing),heights(samples){
  levelsX=std::bit_width(nx);levelsY=std::bit_width(ny);
  maxima.resize(std::size_t(levelsX)*levelsY*nx*ny);
  auto at=[&](unsigned lx,unsigned ly,unsigned ix,unsigned iy)->float&{return maxima[((ly*levelsX+lx)*ny+iy)*nx+ix];};
  for(unsigned iy=0;iy<ny;++iy)for(unsigned ix=0;ix<nx;++ix)at(0,0,ix,iy)=heights[iy*nx+ix];
  for(unsigned lx=1;lx<levelsX;++lx)for(unsigned iy=0;iy<ny;++iy)for(unsigned ix=0;ix<nx;++ix)
   at(lx,0,ix,iy)=std::max(at(lx-1,0,ix,iy),at(lx-1,0,std::min(nx-1,ix+(1U<<(lx-1))),iy));
  for(unsigned ly=1;ly<levelsY;++ly)for(unsigned lx=0;lx<levelsX;++lx)for(unsigned iy=0;iy<ny;++iy)for(unsigned ix=0;ix<nx;++ix)
   at(lx,ly,ix,iy)=std::max(at(lx,ly-1,ix,iy),at(lx,ly-1,ix,std::min(ny-1,iy+(1U<<(ly-1)))));
 }
 // Four lookups reject rays lying wholly above the rectangle's highest vertex.
 // This is an exact conservative broad phase: no optical precision is removed.
 float maximum(float x0,float y0,float x1,float y1)const noexcept{
  unsigned ax=unsigned(std::clamp(int(std::floor(std::min(x0,x1)/cell)),0,int(nx)-1));
  unsigned bx=unsigned(std::clamp(int(std::ceil(std::max(x0,x1)/cell)),0,int(nx)-1));
  unsigned ay=unsigned(std::clamp(int(std::floor(std::min(y0,y1)/cell)),0,int(ny)-1));
  unsigned by=unsigned(std::clamp(int(std::ceil(std::max(y0,y1)/cell)),0,int(ny)-1));
  unsigned lx=std::bit_width(bx-ax+1)-1,ly=std::bit_width(by-ay+1)-1;
  auto at=[&](unsigned x,unsigned y){return maxima[((ly*levelsX+lx)*ny+y)*nx+x];};
  unsigned rx=bx-(1U<<lx)+1,ry=by-(1U<<ly)+1;
  return std::max({at(ax,ay),at(rx,ay),at(ax,ry),at(rx,ry)});
 }
 float width()const{return (nx-1)*cell;}float length()const{return (ny-1)*cell;}
 Vec3 plane(float x,float y)const noexcept{
  int ix=std::clamp(int(std::floor(x/cell)),0,int(nx)-2),iy=std::clamp(int(std::floor(y/cell)),0,int(ny)-2);
  float u=x/cell-ix,v=y/cell-iy;
  auto h=[&](int dx,int dy){return heights[(iy+dy)*nx+ix+dx];};
  float ax,ay,z;
  if(u+v<=1){ax=(h(1,0)-h(0,0))/cell;ay=(h(0,1)-h(0,0))/cell;z=h(0,0);}
  else {ax=(h(1,1)-h(0,1))/cell;ay=(h(1,1)-h(1,0))/cell;z=h(1,0)+h(0,1)-h(1,1);}
  return {ax,ay,z-ax*ix*cell-ay*iy*cell};
 }
 float height(float x,float y)const noexcept{auto q=plane(x,y);return q.x*x+q.y*y+q.z;}
 float floor(float x,float y,float radius)const noexcept{
  float high=-1e30F;
  for(float dx:{-radius,0.F,radius})for(float dy:{-radius,0.F,radius})high=std::max(high,height(x+dx,y+dy));
  return high+radius;
 }
 // Exact intersections with every crossed triangle, not step-size ray marching.
 bool ray(Vec3 a,Vec3 b,float verticalPad,float& fraction,Vec3& normal)const noexcept{
  Vec3 d=b-a;float enter=0,exit=1;
  const float origins[]{a.x,a.y},dirs[]{d.x,d.y},bounds[]{width(),length()};
  for(int k=0;k<2;++k){
   if(std::abs(dirs[k])<1e-12F){if(origins[k]<0||origins[k]>bounds[k])return false;}
   else {float t0=-origins[k]/dirs[k],t1=(bounds[k]-origins[k])/dirs[k];if(t0>t1)std::swap(t0,t1);enter=std::max(enter,t0);exit=std::min(exit,t1);}
  }
  if(enter>exit)return false;
  const Vec3 clippedA=a+d*enter,clippedB=a+d*exit;
  if(std::min(clippedA.z,clippedB.z)-verticalPad>=maximum(clippedA.x,clippedA.y,clippedB.x,clippedB.y))return false;
  std::array<float,256> cuts{};unsigned count=0;cuts[count++]=enter;cuts[count++]=exit;
  for(int k=0;k<2;++k)if(std::abs(dirs[k])>1e-12F){
   int lo=std::max(1,int(std::floor((origins[k]+dirs[k]*enter)/cell)));
   int hi=std::min(int(bounds[k]/cell)-1,int(std::ceil((origins[k]+dirs[k]*exit)/cell)));
   if(dirs[k]<0){lo=std::max(1,int(std::floor((origins[k]+dirs[k]*exit)/cell)));hi=std::min(int(bounds[k]/cell)-1,int(std::ceil((origins[k]+dirs[k]*enter)/cell)));}
   for(int i=lo;i<=hi;++i){float t=(i*cell-origins[k])/dirs[k];if(t>enter&&t<exit&&count<cuts.size())cuts[count++]=t;}
  }
  std::sort(cuts.begin(),cuts.begin()+count);
  auto interval=[&](float lo,float hi){
   auto p=a+d*((lo+hi)*.5F);auto q=plane(p.x,p.y);
   float da=a.z+d.z*lo-(q.x*(a.x+d.x*lo)+q.y*(a.y+d.y*lo)+q.z)-verticalPad;
   float db=a.z+d.z*hi-(q.x*(a.x+d.x*hi)+q.y*(a.y+d.y*hi)+q.z)-verticalPad;
   if(da>=-0.00001F&&db>=-0.00001F)return false;
   float t=da<0?lo:lo+(hi-lo)*da/(da-db);
   if(t<=fraction){fraction=t;normal=Vec3{-q.x,-q.y,1}.normalized();return true;}return false;
  };
  for(unsigned i=1;i<count;++i){
   float lo=cuts[i-1],hi=cuts[i];if(hi-lo<1e-9F)continue;
   auto mid=a+d*((lo+hi)*.5F);int ix=int(std::floor(mid.x/cell)),iy=int(std::floor(mid.y/cell));
   float diagonal=std::abs(d.x+d.y)>1e-12F?((ix+iy+1)*cell-a.x-a.y)/(d.x+d.y):-1;
   if(diagonal>lo&&diagonal<hi){if(interval(lo,diagonal)||interval(diagonal,hi))return true;}
   else if(interval(lo,hi))return true;
  }
  return false;
 }
 bool sweep(Vec3 a,Vec3 b,float radius,float& fraction,Vec3& normal)const noexcept{
  if(radius==0)return ray(a,b,0,fraction,normal);
  bool hit=false;
  for(float dx:{-radius,0.F,radius})for(float dy:{-radius,0.F,radius}){
   Vec3 offset{dx,dy,0};hit=ray(a+offset,b+offset,radius,fraction,normal)||hit;
  }
  return hit;
 }
};
}
