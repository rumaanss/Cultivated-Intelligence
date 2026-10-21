#pragma once
#include <array>
#include <cstdint>
#include <string>
#include <vector>
#include <functional>
namespace cybernet::plants {
constexpr unsigned Schema=1, Inputs=24, Hidden=16, Outputs=14;
constexpr unsigned Weights=Hidden*(Inputs+Hidden+1)+Outputs*(Hidden+1)+12;
constexpr unsigned MaxPlants=512, MaxOrgans=128;
enum class Action:unsigned {Wait,Shoot,Branch,Thicken,Root,Leaf,Repair,Shed,Seed,Release,Germinate};
enum class Kind:unsigned {Root,Stem,Leaf,Pod};
enum class Policy:unsigned {Neural,Wait,Viable};
struct V {double x{},y{},z{};V operator+(V b)const{return{x+b.x,y+b.y,z+b.z};}V operator*(double s)const{return{x*s,y*s,z*s};}};
struct Genome {
 unsigned version=1,species=0; // morphology v1 + controller v1, separate from microbes
 std::array<double,Weights> weights{};
 double angle=.65,elongation=1,leafArea=1,wood=1,waterLoss=1,maturity=40,hue=0;
};
struct Organ {unsigned id{},parent{};Kind kind=Kind::Stem;V start{},end{};double radius=.1,mass=0,health=1;bool dead=false;};
struct Job {bool active=false;Action action=Action::Wait;unsigned site=0;double carbon=0;unsigned remaining=0;V direction{};};
struct Decision {Action requested=Action::Wait;unsigned site=0;double investment=0;std::string result="not-scheduled";std::array<double,Inputs> inputs{};};
struct Plant {
 unsigned id{},parent{},lineage{},generation{},age{},nextOrgan=1,revision=0,mutations=0,cursor=0;
 double mutationDistance=0;V position{};Genome genome{};std::array<double,Hidden> memory{};
 unsigned stage=0; // 0 dormant seed, 1 established, 2 dead
 double carbon=6,water=2,nutrients=.5,health=1;
 // Diagnostic samples are derived runtime data, never checkpoint state.
 bool fluxValid=false;std::array<double,8> flux{};
 Policy policy=Policy::Neural;Job job{};Decision decision{};std::vector<Organ> organs;
};
// Historical samples are informational: they never own carbon or nutrients.
struct DeathRecord {unsigned id{},lineage{},species{},age{};std::uint64_t tick{};double carbon{};};
struct Cell {double height=0,depth=8,water=20,nutrients=8,litter=0;bool valid=true;double dissolvedCarbon=0;};
struct Surface {unsigned width=16,height=16;double originX=-64,originZ=-64,cellSize=8;std::string revision="flat-test-v1";std::vector<Cell> cells;};
struct Ledger {double founderCarbon=0,assimilation=0,respiration=0,rain=0,waterOut=0,nutrientInput=0,initialWater=0,initialNutrients=0;};
struct World {
 Surface surface;std::vector<Plant> plants;Ledger ledger{};
 std::vector<DeathRecord> history;std::uint64_t retiredRecords=0; // durable history, separate from resource ownership
 std::vector<std::string> events; // bounded to one step; worker writes rotating audit log
 std::uint64_t rng=1,tick=0;unsigned nextId=1,revision=0;std::string run="plants-1";
 double rainfall=.025,daylight=1;bool mutation=true;
 // Runtime bindings are derived, never persisted; restored by the island owner.
 std::function<double(V)> environmentalLight;
 std::function<double(double)> assimilateCarbon;
 std::function<void(double)> returnCarbon;
 std::function<double()> atmosphereCarbon;
 explicit World(std::uint64_t seed=1);
 double random();
 unsigned cell(V position)const;
 Plant& founder(unsigned species,V position,Policy policy=Policy::Neural);
 void step();
 bool request(Plant& p,Action action,unsigned site,double investment,V direction={0,1,0});
 std::vector<unsigned> candidates(const Plant& p,Action action)const;
 double carbonTotal()const;double nutrientTotal()const;double waterTotal()const;
 std::string snapshot()const;
 std::string checkpoint()const;
 static World restore(const std::string& text);
 void loadSurface(const std::string& text);
 void validate()const;
 private:
 std::vector<double> canopy_; // derived, rebuilt each ecology step
 void decide(Plant& p);void grow(Plant& p);void release(Plant& p,unsigned site);
 double light(const Plant& p,const Organ& o)const;
 Genome inherit(const Plant& p,unsigned& changed,double& distance);
};
const char* actionName(Action a);
}
