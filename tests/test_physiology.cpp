#include "cybernet/aquatic/physiology.hpp"
#include <cmath>
#include <iostream>
#include <stdexcept>
using namespace cybernet::aquatic;
void check(bool b, const char *s) {
  if (!b)
    throw std::runtime_error(s);
}
template <class F> void reject(F f) {
  bool caught = false;
  try {
    f();
  } catch (const std::exception &) {
    caught = true;
  }
  check(caught, "Expected rejection");
}
int main() {
  try {
    for (unsigned ploidy : {1u, 2u, 4u}) {
      PhysiologyConfig cfg;
      cfg.ploidy = ploidy;
      Physiology w(42, cfg);
      w.validate();
      auto r = Physiology::restore(w.checkpoint(), 42);
      check(r.checkpoint() == w.checkpoint(), "Initial checkpoint round trip");
    }
    Lake old(42);
    for (int i = 0; i < 200; ++i)
      old.step();
    auto original = old.checkpoint();
    auto migrated = Physiology::migrate(old);
    migrated.validate();
    check(old.checkpoint() == original, "Migration changed source");
    auto totals = migrated.totals();
    check(std::abs(totals.carbon - old.totals().carbon) < 1e-5,
          "Migration mass");
    Physiology a(42), b(42);
    for (int i = 0; i < 1500; ++i) {
      a.step();
      b.step(true, true, -1, false);
    }
    check(a.checkpoint() == b.checkpoint(), "Cached expression differs");
    auto saved = a.checkpoint();
    auto resumed = Physiology::restore(saved, 42);
    for (int i = 0; i < 1500; ++i) {
      a.step();
      resumed.step();
    }
    check(a.checkpoint() == resumed.checkpoint(),
          "Exact stochastic continuation");
    check(a.births > 0 && a.deaths > 0 && a.mutations > 0,
          "Continuation must cross births, deaths and mutations");
    auto bad = saved;
    bad[bad.size() / 2] ^= 1;
    reject([&] { Physiology::restore(bad, 42); });
    reject([&] { Physiology::restore(saved, 7); });
    reject([&] { Physiology::restore(old.checkpoint(), 42); });
    reject([] { PhysiologyConfig::parse("{\"foundersPerCell\":1.5}"); });
    reject([] { PhysiologyConfig::parse("{\"unrecognized\":1}"); });
    // Fully paid division fixture: move C/N/P from the same environment into
    // parent pools.
    PhysiologyConfig cfg;
    cfg.mutationProbability = 1;
    cfg.mortalityPerDay = 0;
    Physiology birth(42, cfg);
    auto &c = birth.colonies[0];
    auto before = birth.material(c);
    c.structure = 2 * c.target;
    c.dna = 2 * c.target * .002;
    c.reserve = {c.target, c.target * .1, c.target * .01};
    auto after = birth.material(c);
    auto &m = birth.environment.cells[c.cell].m;
    m[DIC] -= after.c - before.c;
    m[NH4] -= after.n - before.n;
    m[PO4] -= after.p - before.p;
    birth.validate();
    birth.step(false, false, 1);
    birth.validate();
    check(birth.births > 0 && birth.mutations > 0, "Paid division / mutation");
    auto &daughter = birth.colonies.back();
    check(daughter.parent > 0 && daughter.generation == 1, "Ancestry");
    check(birth.genomes[daughter.genome - 1].parent == 1,
          "Inherited genome parent");
    Physiology dark(42);
    double production = dark.environment.cumulative.production;
    for (int i = 0; i < 2000; ++i)
      dark.step(false, false, 0);
    dark.validate();
    check(dark.environment.cumulative.production == production,
          "Photosynthesis in darkness");
    check(dark.deaths > 0, "Darkness should have a cost");
    // P starvation cannot create phosphorus in DNA/RNA/structure.
    Physiology limited(7);
    for (auto &cell : limited.environment.cells) {
      limited.environment.initial.phosphorus -= cell.m[PO4];
      cell.m[PO4] = 0;
    }
    for (int i = 0; i < 1000; ++i)
      limited.step(false, false);
    limited.validate();
    Physiology rateA(9), rateB(9);
    for (auto &copy : rateB.genomes[0].copies)
      copy[Photosystem] = 4;
    rateA.step(false, false, 1, false);
    rateB.step(false, false, 1, false);
    check(rateA.environment.cumulative.production ==
              rateB.environment.cumulative.production,
          "Unpaid allele activity boost");
    Physiology stored(12), released(12);
    auto &smallStore = released.colonies.front();
    unsigned storageCell = smallStore.cell;
    double returnedProtein = smallStore.protein[Storage] * .5;
    smallStore.protein[Storage] -= returnedProtein;
    smallStore.reserve += Material{returnedProtein, returnedProtein * .25, 0};
    released.validate();
    stored.step(false, false, 1);
    released.step(false, false, 1);
    stored.validate();
    released.validate();
    check(
        released.environment.cells[storageCell].m[PO4] >
            stored.environment.cells[storageCell].m[PO4],
        "Reducing paid storage capacity must return excess phosphorus locally");
    Physiology maintained(15), impaired(15);
    auto &housekeeping = impaired.colonies.front();
    returnedProtein = housekeeping.protein[Repair] * .5;
    housekeeping.protein[Repair] -= returnedProtein;
    housekeeping.reserve += Material{returnedProtein, returnedProtein * .25, 0};
    impaired.validate();
    maintained.step(false, false, 0);
    impaired.step(false, false, 0);
    maintained.validate();
    impaired.validate();
    check(impaired.environment.cumulative.respiration >
              maintained.environment.cumulative.respiration,
          "Paid housekeeping protein must affect maintenance cost");
    PhysiologyConfig fairConfig;
    fairConfig.foundersPerCell = 2;
    fairConfig.mortalityPerDay = 0;
    Physiology fair(77, fairConfig);
    auto cell = fair.colonies[0].cell;
    for (unsigned i = 0; i < 2; ++i) {
      auto &c = fair.colonies[i];
      fair.environment.cells[cell].m[PO4] += c.reserve.p;
      c.reserve.p = 0;
    }
    auto &phosphate = fair.environment.cells[cell].m[PO4];
    fair.environment.initial.phosphorus += 1e-6 - phosphate;
    phosphate = 1e-6;
    fair.validate();
    const double competitorPhosphorus = fair.material(fair.colonies[0]).p;
    fair.step(false, false, 0);
    fair.validate();
    check(fair.material(fair.colonies[0]).p > competitorPhosphorus,
          "Scarce-phosphate fixture must exercise actual uptake");
    check(std::abs(fair.material(fair.colonies[0]).p -
                   fair.material(fair.colonies[1]).p) < 1e-12,
          "Identical competitors must receive equal total phosphorus");
    check(std::abs(fair.colonies[0].structure - fair.colonies[1].structure) <
              1e-12,
          "Identical competitors must receive equal scarce-phosphate "
          "allocations");
    Physiology balanced(78, fairConfig);
    auto &bc = balanced.colonies[0];
    for (auto &r : bc.rna) {
      bc.reserve += Material{r, r * .4, r * .1};
      r = 0;
    }
    balanced.environment.initial.phosphorus += 1e-9 - bc.reserve.p;
    bc.reserve.p = 1e-9;
    auto &localP = balanced.environment.cells[bc.cell].m[PO4];
    balanced.environment.initial.phosphorus -= localP;
    localP = 0;
    balanced.validate();
    balanced.step(false, false, 0);
    balanced.validate();
    for (unsigned k=0;k<Sensing;++k)
      check(std::abs(balanced.colonies[0].rna[k] - balanced.colonies[0].rna[0]) < 1e-15,
            "Equal gene targets must share scarce RNA material equally");
    std::cout << "PASS material ledgers, ploidy, migration, paid birth, "
                 "mutations, cached reference, exact resume, corruption "
                 "rejection, darkness, P limitation, paid expression, storage "
                 "housekeeping, fair nutrient allocation and proportional RNA\n";
  } catch (const std::exception &e) {
    std::cerr << e.what() << '\n';
    return 1;
  }
}
