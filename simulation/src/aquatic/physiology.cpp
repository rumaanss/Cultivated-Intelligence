#include "cybernet/aquatic/physiology.hpp"
#include "cybernet/world/planet_geometry_generated.hpp"
#include "json.hpp"
#include <algorithm>
#include <cmath>
#include <numeric>
#include <set>
#include <sstream>
#include <stdexcept>

namespace cybernet::aquatic {
using J = nlohmann::json;
namespace {
constexpr double NC = Lake::NC, PC = Lake::PC, DnaRatio = .002;
void need(bool ok, const char *s) {
  if (!ok)
    throw std::runtime_error(s);
}
double portion(double rate) { return -std::expm1(-rate / 600.); }
double sum(const std::array<double, GeneCount> &a) {
  return std::accumulate(a.begin(), a.end(), 0.);
}
Material quota(double c, double n = NC, double p = PC) {
  return {c, c * n, c * p};
}
J mat(Material m) { return J::array({m.c, m.n, m.p}); }
Material materialJson(const J &j) {
  need(j.is_array() && j.size() == 3, "Material schema");
  return {j[0], j[1], j[2]};
}
bool finite(double x) { return std::isfinite(x) && x >= -1e-8; }
std::uint64_t hash(const std::string &s) {
  std::uint64_t h = 1469598103934665603ULL;
  for (unsigned char c : s) {
    h ^= c;
    h *= 1099511628211ULL;
  }
  return h;
}
J configJson(const PhysiologyConfig &c) {
  return {{"mutationProbability", c.mutationProbability},
          {"mortalityPerDay", c.mortalityPerDay},
          {"foundersPerCell", c.foundersPerCell},
          {"ploidy", c.ploidy},
          {"maximumColonies", c.maximumColonies}};
}
} // namespace
void PhysiologyConfig::validate() const {
  need(std::isfinite(mutationProbability) && mutationProbability >= 0 &&
           mutationProbability <= 1,
       "Invalid mutation probability");
  need(std::isfinite(mortalityPerDay) && mortalityPerDay >= 0 &&
           mortalityPerDay <= 1,
       "Invalid mortality");
  need(foundersPerCell >= 1 && foundersPerCell <= 8, "Invalid founder count");
  need(ploidy == 1 || ploidy == 2 || ploidy == 4,
       "Supported ploidy is 1, 2 or 4");
  need(maximumColonies >= 2000 && maximumColonies <= 100000,
       "Invalid colony limit");
}
PhysiologyConfig PhysiologyConfig::parse(const std::string &text) {
  auto j = J::parse(text);
  need(j.is_object(), "Physiology configuration must be an object");
  PhysiologyConfig c;
  for (auto it = j.begin(); it != j.end(); ++it) {
    const auto &k = it.key();
    const auto &v = it.value();
    if (k == "mutationProbability")
      c.mutationProbability = v.get<double>();
    else if (k == "mortalityPerDay")
      c.mortalityPerDay = v.get<double>();
    else {
      need(v.is_number_unsigned() ||
               (v.is_number_integer() && v.get<long long>() >= 0),
           "Integer configuration required");
      auto value = v.get<std::uint64_t>();
      need(value <= 100000, "Configuration integer too large");
      if (k == "foundersPerCell")
        c.foundersPerCell = unsigned(value);
      else if (k == "ploidy")
        c.ploidy = unsigned(value);
      else if (k == "maximumColonies")
        c.maximumColonies = unsigned(value);
      else
        throw std::runtime_error("Unknown physiology configuration: " + k);
    }
  }
  c.validate();
  return c;
}
Physiology::Physiology(std::uint64_t seed, PhysiologyConfig c)
    : environment(seed), config(c), rng_(seed) {
  config.validate();
  initialize();
}
Physiology Physiology::migrate(const Lake &old, PhysiologyConfig c) {
  old.validate();
  Physiology w(old.seed, c);
  w.environment = old;
  w.initialize();
  return w;
}
void Physiology::geometry() {
  auto &cells = environment.cells;
  neighbors_.assign(cells.size(), {});
  for (auto &c : cells)
    c.volume = c.area * (108 - c.floor) * Lake::MetresPerStud * .5;
  for (unsigned i = 0; i < cells.size(); ++i) {
    neighbors_[i].push_back(i ^ 1u);
    for (unsigned j = 0; j < cells.size(); ++j)
      if (i != j && cells[i].layer == cells[j].layer) {
        double d = std::abs(cells[i].x - cells[j].x) +
                   std::abs(cells[i].y - cells[j].y);
        if (std::abs(d - 16) < .01 &&
            planet_geometry::Field.height(
                float((cells[i].x + cells[j].x) * .5),
                float((cells[i].y + cells[j].y) * .5)) < 108)
          neighbors_[i].push_back(j);
      }
  }
}
void Physiology::initialize() {
  colonies.clear();
  genomes.clear();
  ancestry.clear();
  expressions_.clear();
  recentEvents_.clear();
  samples_.clear();
  births = deaths = mutations = 0;
  rng_.seed(environment.seed);
  geometry();
  detritus.assign(environment.cells.size(), {});
  for (unsigned guild = 0; guild < 3; ++guild) {
    Genome g;
    g.id = genomes.size() + 1;
    g.ploidy = config.ploidy;
    g.copies.resize(g.ploidy);
    for (auto &copy : g.copies)
      copy.fill(1.);
    genomes.push_back(g);
    expressions_.push_back(expression(g.id));
  }
  for (unsigned i = 0; i < environment.cells.size(); ++i) {
    auto &cell = environment.cells[i];
    for (unsigned guild = 0; guild < 3; ++guild) {
      auto pool = guild == 0 ? Phyto : guild == 1 ? Mat : Bacteria;
      double all = cell.m[pool];
      cell.m[pool] = 0;
      if (all <= 0)
        continue;
      for (unsigned n = 0; n < config.foundersPerCell; ++n) {
        Colony c;
        c.id = ancestry.size() + 1;
        c.genome = guild + 1;
        c.born = environment.tick;
        c.cell = i;
        c.guild = guild;
        double carbon = all / config.foundersPerCell;
        c.target = c.structure = carbon * .65;
        c.dna = c.target * DnaRatio * config.ploidy;
        for (unsigned k = 0; k < Sensing; ++k) {
          c.rna[k] = c.structure * .008 / 6;
          c.protein[k] = c.structure * .065 / 6;
        }
        place(c);
        auto allocated = material(c);
        c.reserve = quota(carbon);
        c.reserve -= allocated;
        colonies.push_back(c);
        ancestry.push_back({c.id, 0, c.genome, c.born, 0, 0});
      }
    }
  }
  need(colonies.size() < config.maximumColonies,
       "Founder count reaches population limit");
  validate();
}
double Physiology::random() { return double(rng_() >> 11) * 0x1.0p-53; }
std::array<double, GeneCount> Physiology::expression(std::uint64_t id) const {
  const auto &g = genomes.at(id - 1);
  std::array<double, GeneCount> a{};
  for (const auto &copy : g.copies)
    for (unsigned k = 0; k < GeneCount; ++k)
      a[k] += copy[k] / g.ploidy;
  return a;
}
Material Physiology::material(const Colony &c) const {
  Material m = c.reserve;
  m += quota(c.structure);
  m += quota(c.dna + sum(c.rna), .4, .1);
  m += quota(sum(c.protein), .25, 0);
  return m;
}
Totals Physiology::totals() const {
  auto t = environment.totals();
  for (const auto &c : colonies) {
    auto m = material(c);
    t.carbon += m.c;
    t.nitrogen += m.n;
    t.phosphorus += m.p;
  }
  for (auto m : detritus) {
    t.carbon += m.c;
    t.nitrogen += m.n;
    t.phosphorus += m.p;
  }
  return t;
}
void Physiology::respire(Colony &c, double amount) {
  auto &m = environment.cells[c.cell].m;
  amount = std::max(0., std::min({amount, c.reserve.c, m[O2]}));
  c.reserve.c -= amount;
  m[DIC] += amount;
  m[O2] -= amount;
  c.respiration += amount;
  environment.cumulative.respiration += amount;
  environment.cumulative.oxygenNet -= amount;
}
double Physiology::synthesize(Colony &c, double amount, double n, double p) {
  auto &m = environment.cells[c.cell].m;
  constexpr double cost = .12;
  amount =
      std::max(0., std::min({amount, c.reserve.c / (1 + cost),
                             n > 0 ? c.reserve.n / n : amount,
                             p > 0 ? c.reserve.p / p : amount, m[O2] / cost}));
  c.reserve -= quota(amount, n, p);
  respire(c, amount * cost);
  return amount;
}
void Physiology::place(Colony &c) {
  need(c.cell < environment.cells.size(), "Placement cell");
  const auto &cell = environment.cells[c.cell];
  // Stable offsets separate founders without consuming the biological RNG.
  double angle = double(c.id % 10000) * 2.399963229728653;
  double x = cell.x + std::cos(angle) * 1.5;
  double y = cell.y + std::sin(angle) * 1.5;
  double floor = planet_geometry::Field.height(float(x), float(y));
  if (floor > 106.5) { x = cell.x; y = cell.y; floor = cell.floor; }
  double z = c.guild == 1 ? floor + .1 : std::clamp(cell.z, floor + .1, 107.9);
  c.position = c.goal = {x, y, z};
  c.destination = c.cell;
  c.behavior = c.guild == 1 ? 6 : 0;
  c.decision = environment.tick;
}
void Physiology::event(const Colony &c, unsigned kind) {
  if (recentEvents_.size() == 256) recentEvents_.erase(recentEvents_.begin());
  recentEvents_.push_back({double(environment.tick), double(kind), double(c.id),
                          double(c.parent), double(c.cell / 2 + 1),
                          c.position[0], c.position[1], c.position[2]});
}
void Physiology::move(Colony &c) {
  if (c.guild == 1) return;
  auto &cells = environment.cells;
  auto activity = [&](unsigned gene) {
    return std::clamp(c.protein[gene] / std::max(1e-12, .00325 * c.structure), 0., 4.);
  };
  double motor = activity(Motility), sensor = activity(Sensing);
  auto &m = cells[c.cell].m;
  // Both signalling and locomotion require oxidation of stored carbon.
  double senseCost = c.structure * portion(.001) * sensor;
  double paid = std::min({senseCost, c.reserve.c, m[O2]});
  respire(c, paid);
  sensor *= senseCost > 0 ? paid / senseCost : 0;
  auto distance = [&]() {
    return std::sqrt(std::pow(c.goal[0]-c.position[0],2) +
                     std::pow(c.goal[1]-c.position[1],2) +
                     std::pow(c.goal[2]-c.position[2],2));
  };
  // Keep a chosen route until arrival, except when oxygen no longer pays for it.
  if (distance() < 1e-8 && environment.tick >= c.decision) {
    unsigned dest = c.cell;
    c.behavior = motor > .01 ? 1 : 0;
    auto oxygen = [&](unsigned i) { return cells[i].m[O2] / cells[i].volume; };
    bool hypoxic = oxygen(c.cell) < 20;
    auto score = [&](unsigned i) {
      double o = oxygen(i);
      if (hypoxic) return o / (o + 20);
      if (c.guild == 0) return cells[i].light / (cells[i].light + 25);
      double food = (cells[i].m[DOC] + detritus[i].c * .08) / cells[i].volume;
      return food / (food + 5) * o / (o + 30);
    };
    double best = score(c.cell);
    if (motor > .01 && sensor > .01) {
      for (unsigned candidate : neighbors_[c.cell]) {
        double s = score(candidate);
        if (s > best + .005) { dest = candidate; best = s; }
      }
      // Inherited sensory expression controls reliability, not free thrust.
      if (dest != c.cell && random() < sensor / (sensor + .25))
        c.behavior = hypoxic ? 4 : c.guild == 0 ? 2 : 3;
      else dest = c.cell;
    }
    // Symmetric background mixing remains possible without motor machinery.
    if (dest == c.cell && random() < portion(.8 * 80)) {
      const auto &n = neighbors_[c.cell];
      auto candidate = n[std::min(std::size_t(random()*n.size()), n.size()-1)];
      if (random() < std::min(1., cells[candidate].volume * n.size() /
                                  (cells[c.cell].volume * neighbors_[candidate].size()))) {
        dest = candidate; c.behavior = 5;
      }
    }
    if (c.behavior != 0) {
      double angle = random() * 6.283185307179586;
      const auto &target = cells[dest];
      double x = target.x + 3 * std::cos(angle), y = target.y + 3 * std::sin(angle);
      double floor = planet_geometry::Field.height(float(x), float(y));
      if (floor < 106.8) {
        c.destination = dest;
        c.goal = {x,y,std::clamp(target.z, floor + .6, 107.4)};
      }
    }
    c.decision = environment.tick + 80;
  }
  double d = distance();
  if (d <= 1e-8) return;
  bool drift = c.behavior == 5;
  double step = std::min(d, drift ? .025 : .06 * motor);
  if (!drift) {
    double cost = c.structure * portion(.003) * step / .06;
    double payment = std::min({cost, c.reserve.c, m[O2]});
    step *= cost > 0 ? payment / cost : 0;
    respire(c, payment); c.movementRespiration += payment;
  }
  if (step <= 0) return;
  auto pos = c.position;
  for (unsigned k=0;k<3;++k) pos[k] += (c.goal[k]-pos[k]) * step / d;
  double floor = planet_geometry::Field.height(float(pos[0]), float(pos[1]));
  // Never interpolate through dry ground. Shallow routes stop and replan.
  if (floor >= 106.8 || pos[2] < floor + .1) { c.goal=c.position; c.destination=c.cell; c.decision=environment.tick+80; c.behavior=0; return; }
  double moved=0;
  for (unsigned k=0;k<3;++k) moved += std::pow(pos[k]-c.position[k],2);
  c.distance += std::sqrt(moved); c.position = pos;
  if (distance() < 1e-8) c.cell = c.destination;
}

void Physiology::divide(std::size_t index) {
  if (colonies.size() >= config.maximumColonies)
    return;
  auto &c = colonies[index];
  const auto &g = genomes[c.genome - 1];
  double base = c.target * DnaRatio * g.ploidy;
  if (c.structure < c.target * (2 - 1e-12) || c.dna < base * (2 - 1e-12))
    return;
  Colony child = c;
  child.parent = c.id;
  child.id = ancestry.size() + 1;
  child.born = environment.tick;
  child.generation = c.generation + 1;
  child.assimilation = child.respiration = 0;
  c.structure *= .5;
  c.dna *= .5;
  c.reserve = c.reserve * .5;
  for (auto &x : c.rna)
    x *= .5;
  for (auto &x : c.protein)
    x *= .5;
  child.structure = c.structure;
  child.dna = c.dna;
  child.reserve = c.reserve;
  child.rna = c.rna;
  child.protein = c.protein;
  if (random() < config.mutationProbability) {
    Genome mutant = g;
    mutant.parent = g.id;
    mutant.id = genomes.size() + 1;
    auto copy = std::min(unsigned(random() * g.ploidy), g.ploidy - 1);
    auto gene =
        std::min(unsigned(random() * unsigned(GeneCount)), unsigned(GeneCount - 1));
    mutant.copies[copy][gene] =
        std::clamp(mutant.copies[copy][gene] * (.9 + .2 * random()), .25, 4.);
    genomes.push_back(mutant);
    expressions_.push_back(expression(mutant.id));
    child.genome = mutant.id;
    ++mutations;
  }
  if (child.guild == 1 && random() < .25) {
    const auto &n = neighbors_[child.cell];
    std::vector<unsigned> bottom;
    for (auto dest : n)
      if (environment.cells[dest].layer == 1)
        bottom.push_back(dest);
    if (!bottom.empty())
      child.cell = bottom[std::min(std::size_t(random() * bottom.size()),
                                   bottom.size() - 1)];
  }
  if (child.guild == 1) place(child);
  child.decision = environment.tick;
  child.distance = child.movementRespiration = 0;
  event(child, 1);
  ancestry.push_back(
      {child.id, child.parent, child.genome, child.born, 0, child.generation});
  colonies.push_back(child);
  ++births;
}
void Physiology::step(bool gas, bool transport, double sunlight, bool cached) {
  auto &cells = environment.cells;
  double sun =
      sunlight >= 0
          ? std::clamp(sunlight, 0., 1.)
          : std::max(0., std::sin(2 * 3.141592653589793 *
                                  double(environment.tick % Lake::CycleTicks) /
                                  Lake::CycleTicks));
  environment.step(false, gas, transport, sun);
  if (transport) {
    // Decisions use the previous complete environmental field, before uptake.
    for (auto &c : colonies)
      move(c);
    for (unsigned i = 0; i < cells.size(); i += 2) {
      auto moved = detritus[i] * portion(.5);
      detritus[i] -= moved;
      detritus[i + 1] += moved;
    }
  }
  std::vector<std::array<double, 3>> biomass(cells.size());
  for (const auto &c : colonies)
    biomass[c.cell][c.guild] += c.structure;
  auto storageFor = [](const Colony &c) {
    double activity =
        c.protein[Storage] / std::max(1e-12, c.structure * .065 / 6);
    return c.structure * .35 * std::clamp(activity, .25, 4.);
  };
  auto uptakeFor = [](const Colony &c) {
    return c.structure * portion(.5) * c.protein[Transporter] /
           std::max(1e-12, c.structure * .065 / 6);
  };
  // Simultaneous demand budgets avoid birth/order priority at depleted nutrient
  // pools. Unused allocations remain in water and become available on the next
  // tick.
  std::vector<std::array<double, 3>> demand(cells.size()),
      nutrientScale(cells.size());
  for (const auto &c : colonies) {
    double capacity = storageFor(c), uptake = uptakeFor(c);
    double n = std::min(uptake * NC, std::max(0., capacity * NC - c.reserve.n));
    double p = std::min(uptake * PC, std::max(0., capacity * PC - c.reserve.p));
    demand[c.cell][0] += n;
    demand[c.cell][2] += p;
    if (c.guild < 2)
      demand[c.cell][1] += n;
  }
  for (unsigned i = 0; i < cells.size(); ++i) {
    auto &scale = nutrientScale[i];
    const auto &m = cells[i].m;
    scale[0] = demand[i][0] > 0 ? std::min(1., m[NH4] / demand[i][0]) : 0;
    double nitrateDemand = demand[i][1] * (1 - scale[0]);
    scale[1] = nitrateDemand > 0 ? std::min(1., m[NO3] / nitrateDemand) : 0;
    scale[2] = demand[i][2] > 0 ? std::min(1., m[PO4] / demand[i][2]) : 0;
  }
  std::vector<std::array<double, 2>> light(cells.size()), photons(cells.size());
  for (unsigned i = 0; i < cells.size(); i += 2) {
    double incoming = 1000 * sun;
    for (unsigned layer = 0; layer < 2; ++layer) {
      auto &cell = cells[i + layer];
      double attenuation = .12 + .008 * biomass[i + layer][0] / cell.volume +
                           .001 * cell.m[DOC] / cell.volume +
                           .006 * cell.m[POC] / cell.volume;
      double outgoing =
          incoming * std::exp(-attenuation * cell.volume / cell.area);
      cell.light = std::sqrt(incoming * outgoing);
      light[i + layer] = {cell.light, outgoing};
      photons[i + layer][0] =
          (incoming - outgoing) * (.008 * biomass[i + layer][0] / cell.volume) /
          attenuation * cell.area * Lake::SecondsPerTick / 1000.;
      photons[i + layer][1] =
          outgoing * (-std::expm1(-.008 * biomass[i + layer][1] / cell.area)) *
          cell.area * Lake::SecondsPerTick / 1000.;
      incoming = outgoing;
    }
  }
  // One shared extracellular detritus budget per cell; colony count cannot
  // multiply hydrolysis.
  std::vector<Material> available(cells.size());
  for (unsigned i = 0; i < cells.size(); ++i)
    available[i] = detritus[i] * portion(.08);
  const auto count = colonies.size();
  for (std::size_t index = 0; index < count; ++index) {
    auto &c = colonies[index];
    auto &cell = cells[c.cell];
    auto &m = cell.m;
    auto expr = cached ? expressions_[c.genome - 1] : expression(c.genome);
    double spentPhotons = 0;
    if (c.guild < 2) {
      double par = light[c.cell][c.guild];
      double enzyme = c.protein[Photosystem] /
                      std::max(1e-12, c.structure * .065 / 6);
      double fixed = c.structure * portion(c.guild == 1 ? 1.6 : 1.8) * par /
                     (par + 25) * enzyme;
      double share = c.structure / std::max(1e-12, biomass[c.cell][c.guild]);
      fixed = std::min({fixed, photons[c.cell][c.guild] * share / 10., m[DIC],
                        std::max(0., c.structure * 2 - c.reserve.c)});
      fixed = std::max(0., fixed);
      spentPhotons = fixed * 10;
      m[DIC] -= fixed;
      m[O2] += fixed;
      c.reserve.c += fixed;
      c.assimilation += fixed;
      environment.cumulative.production += fixed;
      environment.cumulative.oxygenNet += fixed;
      environment.cumulative.usedPhotons += fixed * 10;
    } else {
      double capacity = c.structure * portion(1.4) * c.protein[Catabolism] /
                        std::max(1e-12, c.structure * .065 / 6);
      double food = std::max(
          0., std::min({capacity * m[DOC] / (m[DOC] + 5 * cell.volume), m[DOC],
                        m[O2] / .65,
                        std::max(0., 2 * c.structure - c.reserve.c) / .35}));
      m[DOC] -= food;
      c.reserve += quota(food);
      respire(c, food * .65);
      c.assimilation += food;
      environment.cumulative.decomposition += food;
      double share = c.structure / std::max(1e-12, biomass[c.cell][2]);
      auto digest = available[c.cell] * share;
      double scale =
          digest.c > 0 ? std::min({1., std::max(0., capacity - food) / digest.c,
                                   m[O2] / (.65 * digest.c),
                                   std::max(0., 2 * c.structure - c.reserve.c) /
                                       (.35 * digest.c)})
                       : 0;
      digest = digest * scale;
      detritus[c.cell] -= digest;
      c.reserve += digest;
      respire(c, digest.c * .65);
      c.assimilation += digest.c;
      environment.cumulative.decomposition += digest.c;
    }
    // Passive turnover returns the exact elemental composition to reserves.
    for (unsigned k = 0; k < GeneCount; ++k) {
      double r = c.rna[k] * portion(.25), p = c.protein[k] * portion(.08);
      c.rna[k] -= r;
      c.protein[k] -= p;
      c.reserve += quota(r, .4, .1);
      c.reserve += quota(p, .25, 0);
    }
    // Paid housekeeping protein reduces maintenance inefficiency; this is a
    // reduced kinetic rule, not a molecular damage model.
    double repair = std::clamp(
        c.protein[Repair] / std::max(1e-12, c.structure * .065 / 6),
        .25, 4.);
    double maintenance = c.structure * portion(.035) / repair;
    if (c.reserve.c < maintenance) {
      double recycle =
          std::min(c.structure, std::max(0., maintenance - c.reserve.c));
      c.structure -= recycle;
      c.reserve += quota(recycle);
    }
    respire(c, maintenance);
    // A single storage-protein capacity sets C, N and P reserve targets.
    // This prevents unrelated fixed N/P quotas from trapping nutrients.
    auto storageCapacity = [&]() { return storageFor(c); };
    double nitrogenTarget = storageCapacity() * NC;
    double phosphorusTarget = storageCapacity() * PC;
    double uptake = uptakeFor(c);
    double nitrogenRequest =
        std::min(uptake * NC, std::max(0., nitrogenTarget - c.reserve.n));
    double nitrogen =
        std::min(m[NH4], nitrogenRequest * nutrientScale[c.cell][0]);
    m[NH4] -= nitrogen;
    c.reserve.n += nitrogen;
    // Nitrate assimilation consumes 16 photons/N and releases 2 O2/N.
    double nitrateLight = 0;
    if (c.guild < 2) {
      double share = c.structure / std::max(1e-12, biomass[c.cell][c.guild]);
      nitrateLight =
          std::max(0., (photons[c.cell][c.guild] * share - spentPhotons) / 16.);
    }
    double nitrate = std::max(
        0., std::min({(nitrogenRequest - nitrogen) * nutrientScale[c.cell][1],
                      m[NO3], nitrateLight}));
    m[NO3] -= nitrate;
    c.reserve.n += nitrate;
    m[O2] += 2 * nitrate;
    environment.cumulative.oxygenNet += 2 * nitrate;
    environment.cumulative.usedPhotons += 16 * nitrate;
    double phosphorusRequest =
        std::min(uptake * PC, std::max(0., phosphorusTarget - c.reserve.p));
    double phosphorus =
        std::min(m[PO4], phosphorusRequest * nutrientScale[c.cell][2]);
    m[PO4] -= phosphorus;
    c.reserve.p += phosphorus;
    double es = std::accumulate(expr.begin(), expr.begin() + Sensing, 0.);
    std::array<double, GeneCount> rtarget{}, rrequest{}, prequest{};
    for (unsigned k = 0; k < GeneCount; ++k) {
      rtarget[k] = c.structure * expr[k] * (k < Sensing ? .008 / es : c.guild == 1 ? 0. : .0004);
      rrequest[k] = std::max(0., rtarget[k] - c.rna[k]) * portion(3);
    }
    double wanted = sum(rrequest), made = synthesize(c, wanted, .4, .1);
    if (wanted > 0)
      for (unsigned k = 0; k < GeneCount; ++k)
        c.rna[k] += made * (rrequest[k] / wanted);
    for (unsigned k = 0; k < GeneCount; ++k) {
      double target = c.structure * expr[k] * (k < Sensing ? .065 / es : c.guild == 1 ? 0. : .00325);
      prequest[k] = std::max(0., target - c.protein[k]) * portion(2) *
                    std::min(1., c.rna[k] / std::max(1e-12, rtarget[k]));
    }
    wanted = sum(prequest);
    made = synthesize(c, wanted, .25, 0);
    if (wanted > 0)
      for (unsigned k = 0; k < GeneCount; ++k)
        c.protein[k] += made * (prequest[k] / wanted);
    double base = c.target * DnaRatio * genomes[c.genome - 1].ploidy;
    double desired = base * std::clamp(c.structure / c.target, 1., 2.);
    double replication = std::max(0., desired - c.dna);
    replication = std::min(replication,
                           base * portion(2) * c.protein[Replication] /
                               std::max(1e-12, c.structure * .065 / 6));
    c.dna += synthesize(c, replication, .4, .1);
    // Storage regulation acts through paid storage protein. Preserve night
    // reserves before growth.
    double surplus = std::max(0., c.reserve.c - storageCapacity());
    double growth = std::min({std::max(0., 2 * c.target - c.structure),
                              c.structure * portion(.7), surplus / 1.12});
    c.structure += synthesize(c, growth, NC, PC);
    // Excess inorganic reserves leak back to the same cell, never disappear.
    double releaseN = std::max(0., c.reserve.n - 1.25 * storageCapacity() * NC),
           releaseP = std::max(0., c.reserve.p - 1.25 * storageCapacity() * PC);
    c.reserve.n -= releaseN;
    m[NH4] += releaseN;
    c.reserve.p -= releaseP;
    m[PO4] += releaseP;
    bool dead = c.structure < .2 * c.target ||
                random() < portion(config.mortalityPerDay);
    if (dead) {
      auto all = material(c);
      detritus[c.cell] += all;
      environment.cumulative.mortality += all.c;
      ancestry[c.id - 1].died = environment.tick;
      event(c, 2);
      c.structure = 0;
      ++deaths;
    }
  }
  colonies.erase(
      std::remove_if(colonies.begin(), colonies.end(),
                     [](const Colony &c) { return c.structure == 0; }),
      colonies.end());
  auto parents = colonies.size();
  for (std::size_t i = 0; i < parents; ++i)
    divide(i);
  // Environmental mineralization and nitrification, disabled in
  // Lake::step(false).
  for (auto &cell : cells) {
    auto &m = cell.m;
    double particulate = m[POC] * portion(.08);
    m[POC] -= particulate;
    m[DOC] += particulate;
    if (cell.layer == 1) {
      double release = m[Sediment] * portion(.03);
      m[Sediment] -= release;
      m[DOC] += release;
      double bind = m[PO4] * portion(.02),
             unbound =
                 m[BoundP] * portion(m[O2] / cell.volume < 30 ? .1 : .005);
      m[PO4] += unbound - bind;
      m[BoundP] += bind - unbound;
    }
    double nitrified = std::min(m[NH4] * portion(.04), m[O2] * .5);
    m[NH4] -= nitrified;
    m[NO3] += nitrified;
    m[O2] -= 2 * nitrified;
    environment.cumulative.nitrification += nitrified;
    environment.cumulative.oxygenNet -= 2 * nitrified;
  }
}
void Physiology::validate() const {
  config.validate();
  need(ancestry.size() <= 2000000 && genomes.size() <= 2000000,
       "Lineage checkpoint budget reached");
  const auto &e = environment;
  need(e.tick < 2147483647ULL, "Tick limit");
  auto validMat = [](Material m) {
    return finite(m.c) && finite(m.n) && finite(m.p);
  };
  need(detritus.size() == e.cells.size(), "Detritus grid mismatch");
  for (auto m : detritus)
    need(validMat(m), "Invalid detritus");
  need(colonies.size() <= config.maximumColonies, "Population cap");
  need(genomes.size() == expressions_.size(), "Expression cache size");
  for (std::size_t i = 0; i < genomes.size(); ++i) {
    const auto &g = genomes[i];
    need(g.id == i + 1 && g.parent < g.id &&
             (g.ploidy == 1 || g.ploidy == 2 || g.ploidy == 4) &&
             g.copies.size() == g.ploidy,
         "Genome layout");
    for (auto a : g.copies)
      for (double x : a)
        need(std::isfinite(x) && x >= .25 && x <= 4, "Genome allele");
    need(expression(g.id) == expressions_[i], "Expression cache mismatch");
  }
  need(recentEvents_.size() <= 256, "Presentation event budget");
  for (const auto &r : recentEvents_)
    need(r[0] <= e.tick && (r[1] == 1 || r[1] == 2) && r[2] >= 1 &&
         r[2] <= ancestry.size() && r[4] >= 1 && r[4] <= e.cells.size()/2,
         "Presentation event identity");
  std::set<std::uint64_t> live;
  for (const auto &c : colonies) {
    need(c.id >= 1 && c.id <= ancestry.size() && live.insert(c.id).second,
         "Colony identity");
    need(c.genome >= 1 && c.genome <= genomes.size() &&
             c.cell < e.cells.size() && c.guild < 3,
         "Colony references");
    need(c.guild != 1 || e.cells[c.cell].layer == 1,
         "Attached colony outside bottom");
    need(finite(c.target) && c.target > 0 && finite(c.structure) &&
             c.structure > 0 && c.structure <= 2 * c.target * (1 + 1e-10),
         "Structural bounds");
    need(validMat(c.reserve) && finite(c.dna), "Physiology material");
    for (double x : c.rna)
      need(finite(x), "RNA amount");
    for (double x : c.protein)
      need(finite(x), "Protein amount");
    double base = c.target * DnaRatio * genomes[c.genome - 1].ploidy;
    need(c.dna >= base * (1 - 1e-10) && c.dna <= 2 * base * (1 + 1e-10),
         "DNA replication bounds");
    const auto &a = ancestry[c.id - 1];
    need(a.died == 0 && a.parent == c.parent && a.genome == c.genome &&
             a.generation == c.generation && a.born == c.born,
         "Living ancestry mismatch");
    need(finite(c.assimilation) && finite(c.respiration), "Invalid metabolism");
    need(c.destination < e.cells.size() && c.behavior <= 6 &&
         c.decision <= e.tick + 100 && finite(c.distance) && finite(c.movementRespiration) &&
         c.movementRespiration <= c.respiration + 1e-8, "Invalid movement state");
    for (auto pos : {c.position, c.goal})
      need(finite(pos[0]) && pos[0] <= 436 && finite(pos[1]) && pos[1] <= 212 &&
           finite(pos[2]) && pos[2] < 108, "Movement coordinates");
    const auto &origin = e.cells[c.cell];
    need(std::hypot(c.position[0] - origin.x, c.position[1] - origin.y) <= 24 &&
         (c.destination == c.cell || std::find(neighbors_[c.cell].begin(), neighbors_[c.cell].end(), c.destination) != neighbors_[c.cell].end()),
         "Movement outside local neighborhood");
    need(c.guild != 1 || (c.destination == c.cell && c.position == c.goal), "Attached colony moved");
  }
  std::uint64_t dead = 0, nonfounders = 0;
  for (std::size_t i = 0; i < ancestry.size(); ++i) {
    const auto &a = ancestry[i];
    need(a.id == i + 1 && a.parent < a.id && a.genome >= 1 &&
             a.genome <= genomes.size() && a.born <= e.tick,
         "Ancestry reference");
    if (a.parent) {
      ++nonfounders;
      const auto &p = ancestry[a.parent - 1];
      need(a.generation == p.generation + 1 && a.born >= p.born &&
               (p.died == 0 || p.died >= a.born),
           "Ancestry chronology");
      need(a.genome == p.genome || genomes[a.genome - 1].parent == p.genome,
           "Genome inheritance");
    } else
      need(a.generation == 0, "Founder generation");
    if (a.died) {
      ++dead;
      need(a.died >= a.born && a.died <= e.tick, "Death chronology");
    } else
      need(live.count(a.id) == 1, "Missing living colony");
  }
  need(deaths == dead && births == nonfounders &&
           mutations == genomes.size() - 3,
       "Event counters");
  for (const auto &c : e.cells) {
    need(c.area > 0 && c.volume > 0 && std::isfinite(c.volume) &&
             std::abs(c.volume - c.area * (108 - c.floor) *
                                     Lake::MetresPerStud * .5) < 1e-7,
         "Geometry mismatch");
    for (double x : c.m)
      need(finite(x), "Environmental amount");
    need(c.m[Phyto] == 0 && c.m[Mat] == 0 && c.m[Bacteria] == 0,
         "Duplicate biomass");
  }
  need(finite(e.airCarbon) && finite(e.airOxygen), "Atmosphere amount");
  auto t = totals();
  auto close = [](double a, double b) {
    return std::isfinite(a) && std::isfinite(b) &&
           std::abs(a - b) <= 1e-8 * std::max(1., std::abs(b));
  };
  need(close(t.carbon, e.initial.carbon) &&
           close(t.nitrogen, e.initial.nitrogen) &&
           close(t.phosphorus, e.initial.phosphorus),
       "Physiology C/N/P conservation");
  need(close(t.oxygen, e.initialOxygen + e.cumulative.oxygenNet),
       "Physiology oxygen ledger");
  need(finite(e.cumulative.usedPhotons) &&
           finite(e.cumulative.incidentPhotons) &&
           e.cumulative.usedPhotons <=
               e.cumulative.incidentPhotons * (1 + 1e-10),
       "Physiology photon ledger");
  for (double f :
       {e.cumulative.production, e.cumulative.respiration,
        e.cumulative.mortality, e.cumulative.decomposition,
        e.cumulative.settling, e.cumulative.gasCarbon, e.cumulative.gasOxygen,
        e.cumulative.nitrification, e.cumulative.oxygenNet})
    need(std::isfinite(f), "Invalid flux ledger");
}
std::string Physiology::checkpoint() const {
  validate();
  const auto &e = environment;
  J cells = J::array(), dead = J::array(), gs = J::array(), cs = J::array(),
    as = J::array();
  for (const auto &c : e.cells)
    cells.push_back({c.m, c.light});
  for (auto m : detritus)
    dead.push_back(mat(m));
  for (const auto &g : genomes)
    gs.push_back({g.id, g.parent, g.ploidy, g.copies});
  for (const auto &c : colonies)
    cs.push_back({c.id, c.parent, c.genome, c.born, c.generation, c.cell,
                  c.guild, c.target, c.structure, c.dna, mat(c.reserve), c.rna,
                  c.protein, c.assimilation, c.respiration, c.position, c.goal,
                  c.destination, c.behavior, c.decision, c.distance, c.movementRespiration});
  for (const auto &a : ancestry)
    as.push_back({a.id, a.parent, a.genome, a.born, a.died, a.generation});
  std::ostringstream state;
  state << rng_;
  J j = {
      {"schema", 2},
      {"model", "pdnarna-4"},
      {"habitat", planet_contract::Digest},
      {"seed", e.seed},
      {"tick", e.tick},
      {"config", configJson(config)},
      {"rng", state.str()},
      {"cells", cells},
      {"detritus", dead},
      {"genomes", gs},
      {"colonies", cs},
      {"ancestry", as},
      {"events", {births, deaths, mutations}},
      {"recentEvents", recentEvents_},
      {"air", {e.airCarbon, e.airOxygen}},
      {"initial",
       {e.initial.carbon, e.initial.nitrogen, e.initial.phosphorus,
        e.initialOxygen}},
      {"flux",
       {e.cumulative.production, e.cumulative.respiration,
        e.cumulative.mortality, e.cumulative.decomposition,
        e.cumulative.settling, e.cumulative.gasCarbon, e.cumulative.gasOxygen,
        e.cumulative.nitrification, e.cumulative.oxygenNet,
        e.cumulative.incidentPhotons, e.cumulative.usedPhotons}}};
  std::string text = j.dump();
  auto output =
      J{{"payload", text}, {"checksum", std::to_string(hash(text))}}.dump();
  need(output.size() < 256 * 1024 * 1024,
       "Physiology checkpoint too large to resume");
  return output;
}
Physiology Physiology::restore(const std::string &text, std::uint64_t seed) {
  need(text.size() < 256 * 1024 * 1024, "Physiology checkpoint too large");
  auto outer = J::parse(text);
  std::string payload = outer.at("payload");
  need(outer.at("checksum") == std::to_string(hash(payload)),
       "Physiology checkpoint checksum");
  auto j = J::parse(payload);
  bool legacy = j.at("model") == "pdnarna-3";
  need(j.at("schema") == 2 && (legacy || j.at("model") == "pdnarna-4") &&
           j.at("habitat") == planet_contract::Digest && j.at("seed") == seed,
       "Physiology checkpoint identity");
  Physiology w(seed, PhysiologyConfig::parse(j.at("config").dump()));
  auto &e = w.environment;
  e.tick = j.at("tick");
  e.airCarbon = j.at("air").at(0);
  e.airOxygen = j.at("air").at(1);
  auto a = j.at("initial").get<std::array<double, 4>>();
  e.initial = {a[0], a[1], a[2], a[3]};
  e.initialOxygen = a[3];
  auto f = j.at("flux").get<std::array<double, 11>>();
  e.cumulative = {f[0], f[1], f[2], f[3], f[4], f[5],
                  f[6], f[7], f[8], f[9], f[10]};
  need(j.at("cells").size() == e.cells.size() &&
           j.at("detritus").size() == e.cells.size(),
       "Checkpoint grid count");
  for (unsigned i = 0; i < e.cells.size(); ++i) {
    e.cells[i].m = j.at("cells")[i].at(0).get<std::array<double, Count>>();
    e.cells[i].light = j.at("cells")[i].at(1);
    w.detritus[i] = materialJson(j.at("detritus")[i]);
  }
  w.genomes.clear();
  w.expressions_.clear();
  need(j.at("genomes").size() <= 2000000, "Genome count budget");
  for (auto r : j.at("genomes")) {
    Genome g;
    g.id = r.at(0);
    g.parent = r.at(1);
    g.ploidy = r.at(2);
    if (legacy) {
      for (const auto &old : r.at(3)) {
        need(old.size() == 6, "Legacy genome width");
        std::array<double, GeneCount> copy{};
        copy.fill(1.);
        for (unsigned k = 0; k < 6; ++k) copy[k] = old.at(k);
        g.copies.push_back(copy);
      }
    } else g.copies = r.at(3).get<std::vector<std::array<double, GeneCount>>>();
    need(g.id == w.genomes.size() + 1 && g.ploidy > 0, "Genome restore layout");
    w.genomes.push_back(g);
    w.expressions_.push_back(w.expression(g.id));
  }
  w.colonies.clear();
  need(j.at("colonies").size() <= w.config.maximumColonies,
       "Colony restore budget");
  for (auto r : j.at("colonies")) {
    Colony c;
    c.id = r.at(0);
    c.parent = r.at(1);
    c.genome = r.at(2);
    c.born = r.at(3);
    c.generation = r.at(4);
    c.cell = r.at(5);
    c.guild = r.at(6);
    c.target = r.at(7);
    c.structure = r.at(8);
    c.dna = r.at(9);
    c.reserve = materialJson(r.at(10));
    if (legacy) {
      need(r.at(11).size() == 6 && r.at(12).size() == 6, "Legacy expression width");
      for (unsigned k = 0; k < 6; ++k) { c.rna[k] = r.at(11).at(k); c.protein[k] = r.at(12).at(k); }
      w.place(c); // No free sensing/motor material; new groups start at zero.
    } else {
      c.rna = r.at(11).get<std::array<double, GeneCount>>();
      c.protein = r.at(12).get<std::array<double, GeneCount>>();
      c.position = r.at(15).get<std::array<double, 3>>();
      c.goal = r.at(16).get<std::array<double, 3>>();
      c.destination = r.at(17); c.behavior = r.at(18); c.decision = r.at(19);
      c.distance = r.at(20); c.movementRespiration = r.at(21);
    }
    c.assimilation = r.at(13);
    c.respiration = r.at(14);
    w.colonies.push_back(c);
  }
  if (!legacy) w.recentEvents_ = j.at("recentEvents").get<std::vector<std::array<double, 8>>>();
  w.ancestry.clear();
  need(j.at("ancestry").size() <= 2000000, "Ancestry restore budget");
  for (auto r : j.at("ancestry"))
    w.ancestry.push_back(
        {r.at(0), r.at(1), r.at(2), r.at(3), r.at(4), r.at(5)});
  auto events = j.at("events").get<std::array<std::uint64_t, 3>>();
  w.births = events[0];
  w.deaths = events[1];
  w.mutations = events[2];
  std::istringstream state(j.at("rng").get<std::string>());
  need(bool(state >> w.rng_), "Invalid RNG state");
  state >> std::ws;
  need(state.eof(), "Trailing RNG data");
  w.validate();
  return w;
}
std::string Physiology::snapshot(const std::string &run) const {
  J j = J::parse(environment.snapshot(run));
  j["schema"] = 2;
  j["model"] = "pdnarna-4";
  auto t = totals();
  const auto &e = environment;
  j["totals"] = {t.carbon, t.nitrogen, t.phosphorus, t.oxygen};
  j["residual"] = {t.carbon - e.initial.carbon, t.nitrogen - e.initial.nitrogen,
                   t.phosphorus - e.initial.phosphorus,
                   t.oxygen - e.initialOxygen - e.cumulative.oxygenNet};
  j["events"] = {births, deaths, mutations};
  j["population"] = colonies.size();
  j["colonies"] = J::array();
  j["lifecycle"] = J::array();
  for (const auto &r : recentEvents_)
    if (r[0] + 200 >= e.tick) j["lifecycle"].push_back(r);
  std::vector<std::array<double, 3>> biomass(e.cells.size() / 2);
  std::vector<const Colony *> byId(ancestry.size()+1);
  for (const auto &c : colonies) { biomass[c.cell/2][c.guild] += material(c).c; byId[c.id] = &c; }
  std::vector<const Colony *> selected;
  std::vector<std::array<unsigned, 3>> counts(e.cells.size()/2);
  std::set<std::uint64_t> chosen;
  auto take = [&](const Colony *c) {
    if (c && counts[c->cell/2][c->guild] < 2 && chosen.insert(c->id).second) {
      selected.push_back(c); ++counts[c->cell/2][c->guild];
    }
  };
  // Retain individuals across cell boundaries. A second slot admits daughters.
  for (auto id : samples_) if (id < byId.size() && byId[id] && !counts[byId[id]->cell/2][byId[id]->guild]) take(byId[id]);
  for (const auto &c : colonies) if (!counts[c.cell/2][c.guild]) take(&c);
  for (auto it=colonies.rbegin();it!=colonies.rend();++it)
    if (it->parent && chosen.count(it->parent) && e.tick-it->born <= 200) take(&*it);
  for (auto id : samples_) if (id < byId.size()) take(byId[id]);
  samples_.clear();
  for (unsigned i=0;i<biomass.size();++i) {
    const auto &a=e.cells[i*2]; double volume=a.volume+e.cells[i*2+1].volume;
    for (unsigned g=0;g<3;++g) j["patches"][i][4+g]=biomass[i][g]/(g==1?a.area:volume);
  }
  for (const auto *c : selected) {
    samples_.push_back(c->id);
    auto m=material(*c); const auto &cell=e.cells[c->cell];
    J row={c->cell/2+1,c->guild,c->id,c->parent,c->genome,c->generation,e.tick-c->born,
           c->structure,c->reserve.c,c->reserve.n,c->reserve.p,c->dna,sum(c->rna),sum(c->protein),
           c->dna/(c->target*DnaRatio*genomes[c->genome-1].ploidy)-1,
           c->assimilation,c->respiration,m.c,m.n,m.p,genomes[c->genome-1].ploidy,cell.z,
           c->position[0],c->position[1],c->position[2],c->target,c->behavior,c->distance,
           c->movementRespiration,
           c->protein[Sensing]/std::max(1e-12,.00325*c->structure),
           c->protein[Motility]/std::max(1e-12,.00325*c->structure)};
    for (double allele : expression(c->genome)) row.push_back(allele);
    j["colonies"].push_back(row);
  }
  return j.dump();
}
} // namespace cybernet::aquatic
