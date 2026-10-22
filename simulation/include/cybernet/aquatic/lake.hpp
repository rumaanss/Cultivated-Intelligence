#pragma once
#include <array>
#include <cstdint>
#include <string>
#include <vector>
namespace cybernet::aquatic {
// mmol of named element. Organic pools: mmol C with fixed N/P quotas.
enum Pool { DIC,NH4,NO3,PO4,O2,DOC,POC,Phyto,Mat,Bacteria,Sediment,BoundP,Count };
struct Cell {
 double x{},y{},z{},floor{},volume{},area{},light{};
 unsigned column{},layer{};
 std::array<double,Count> m{};
};
struct Totals { double carbon{},nitrogen{},phosphorus{},oxygen{}; };
struct Flux {double production{},respiration{},mortality{},decomposition{},settling{},gasCarbon{},gasOxygen{},nitrification{},oxygenNet{},incidentPhotons{},usedPhotons{};};
class Lake {
public:
 static constexpr double MetresPerStud=.28,SecondsPerTick=144,NC=16./106,PC=1./106;
 static constexpr unsigned CycleTicks=600;
 std::uint64_t seed{},tick{};
 std::vector<Cell> cells;
 double airCarbon{},airOxygen{},initialOxygen{};
 Totals initial{};Flux cumulative{};
 explicit Lake(std::uint64_t seed=42);
 void step(bool reactions=true,bool gas=true,bool transport=true,double sunlight=-1);
 Totals totals() const;
 void validate() const;
 std::string checkpoint() const;
 static Lake restore(const std::string& text,std::uint64_t expectedSeed);
 std::string snapshot(const std::string& run) const;
private:
 struct Edge{unsigned a,b;};
 std::vector<Edge> edges_;
 void makeGrid();
};
}
