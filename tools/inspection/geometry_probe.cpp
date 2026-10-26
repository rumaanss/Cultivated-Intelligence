#include "cybernet/aquatic/lake.hpp"
#include "cybernet/world/planet_geometry_generated.hpp"
#include "json.hpp"
#include <iostream>
using J=nlohmann::json;
int main(){
 cybernet::aquatic::Lake lake(42);J rays=J::array();
 auto v=[](cybernet::Vec3 p){return J::array({p.x,p.y,p.z});};
 auto emit=[&](cybernet::Vec3 a,cybernet::Vec3 b,const char* kind){float t=1;cybernet::Vec3 normal{};bool hit=cybernet::planet_geometry::Field.ray(a,b,0,t,normal);J r={{"kind",kind},{"from",v(a)},{"to",v(b)},{"hit",hit}};if(hit){r["expected"]=v(a+(b-a)*t);r["normal"]=v(normal);}rays.push_back(r);};
 for(unsigned i=0;i<lake.cells.size();i+=2){const auto&c=lake.cells[i];float x=c.x,y=c.y,z=c.floor;
  emit({x,y,130},{x,y,-10},"occupied radial");
  emit({x-6,y,z+8},{x+6,y,z-8},"occupied oblique");
  emit({x,y-6,z+1},{x,y+6,z+1},"corridor clearance");
 }
 for(float x=4;x<432;x+=16)for(float y=4;y<208;y+=16){float h=cybernet::planet_geometry::Field.height(x,y);if(h>100&&h<120)emit({x,y,130},{x,y,80},"shore/grid edge");}
 std::cout<<J{{"schema",1},{"habitat",cybernet::planet_contract::Digest},{"heightToleranceStuds",.25},{"normalToleranceDegrees",10},{"roundTripToleranceStuds",.01},{"rays",rays},{"note","Native straight chart rays compared to projected Roblox chords; report curvature effects separately. Finite probes cannot certify pinpoint equality."}}.dump(2)<<'\n';
}
