#pragma once
#include "cybernet/aquatic/lake.hpp"
#include <array>
#include <random>

namespace cybernet::aquatic::stage3 {
// Element amounts are mmol. RNA/protein arrays contain mmol carbon, not
// activity flags.
struct Material {
  double c{}, n{}, p{};
  Material &operator+=(Material b) {
    c += b.c;
    n += b.n;
    p += b.p;
    return *this;
  }
  Material &operator-=(Material b) {
    c -= b.c;
    n -= b.n;
    p -= b.p;
    return *this;
  }
  Material operator*(double x) const { return {c * x, n * x, p * x}; }
};
enum Gene {
  Photosystem,
  Transporter,
  Catabolism,
  Repair,
  Storage,
  Replication,
  Sensing,
  Motility,
  Capture, Digestion, Width, Branching, Extension, Attachment,
  GeneCount
};
struct Genome {
  std::uint64_t id{}, parent{};
  unsigned ploidy{1}, form{};
  std::vector<std::array<double, GeneCount>> copies;
};
struct Segment {
  unsigned id{}, parent{};
  std::uint64_t born{};
  double carbon{}, length{}, width{}, angle{};
};
struct Colony {
  std::uint64_t id{}, parent{}, genome{}, born{};
  unsigned generation{}, cell{},
      guild{}; // 0 suspended producer, 1 attached producer, 2 decomposer
  double target{}, structure{}, dna{};
  Material reserve{};
  std::array<double, GeneCount> rna{}, protein{};
  double assimilation{}, respiration{};
  // Continuous habitat coordinates in studs; chemistry belongs to cell until
  // arrival. All motion state is durable, including the next decision tick.
  std::array<double, 3> position{}, goal{};
  unsigned destination{}, behavior{};
  std::uint64_t decision{};
  double distance{}, movementRespiration{};
  double sensedPar{-1}; // Last biological light field, not rendered brightness.
  double represented{1}, ingested{}, egested{}, availableFood{};
  std::vector<Segment> segments;
  unsigned nextSegment{1};
};
struct Ancestry {
  std::uint64_t id{}, parent{}, genome{}, born{}, died{};
  unsigned generation{};
};
struct PhysiologyConfig {
  double mutationProbability{.02}, mortalityPerDay{.015};
  unsigned foundersPerCell{1}, ploidy{1}, maximumColonies{50000};
  void validate() const;
  static PhysiologyConfig parse(const std::string &);
};
// Per cell/guild material flows; Growth is internal structural production.
enum Flow {Fixation, Uptake, Release, Respiration, Mortality, Grazed, Ingested, Egested, Exchange, Growth, FlowCount};
struct Budget { Material opening{}, closing{}; std::array<Material,FlowCount> flows{}; };
class Physiology {
public:
  Lake environment;
  PhysiologyConfig config;
  std::vector<Colony> colonies;
  std::vector<Genome> genomes;
  std::vector<Ancestry> ancestry;
  std::vector<Material> detritus;
  std::uint64_t births{}, deaths{}, mutations{};
  std::uint64_t budgetStart{};
  std::vector<Budget> budgets;
  std::string lastDay;
  std::string report(bool detailed=true) const;
  static Physiology migrateStage2(const std::string &, std::uint64_t seed);
  explicit Physiology(std::uint64_t seed = 42, PhysiologyConfig config = {});
  static Physiology migrate(const Lake &, PhysiologyConfig config = {});
  // Empty means the unchanged native reference. Otherwise one external surface
  // transmission per water column, applied before native water/canopy losses.
  std::vector<double> sceneTransmission;
  void step(bool gas = true, bool transport = true, double sunlight = -1,
            bool cached = true);
  Totals totals() const;
  Material material(const Colony &) const;
  void validate() const;
  std::string checkpoint() const;
  static Physiology restore(const std::string &, std::uint64_t expectedSeed);
  std::string snapshot(const std::string &run) const;
  std::array<double, GeneCount> expression(std::uint64_t genome) const;

private:
  std::mt19937_64 rng_;
  std::vector<std::array<double, GeneCount>> expressions_;
  std::vector<std::vector<unsigned>> neighbors_;
  // Bounded observational event history; never drives biology.
  std::vector<std::array<double, 8>> recentEvents_;
  mutable std::vector<std::uint64_t> samples_;
  std::vector<std::array<double,6>> food_;
  std::vector<double> canopy_;
  void seedWeb();
  void census();
  void graze();
  void growShape(Colony &);
  void resetBudget();
  void book(const Colony &, Flow, Material);
  double activity(const Colony &, unsigned) const;
  bool producer(const Colony &c) const { return c.guild<2 || c.guild==5; }
  bool attached(const Colony &c) const { return c.guild==1 || c.guild==5; }
  void place(Colony &);
  void move(Colony &);
  void event(const Colony &, unsigned kind);
  void initialize();
  void geometry();
  double random();
  void respire(Colony &, double amount);
  double synthesize(Colony &, double amount, double n, double p);
  void divide(std::size_t index);
};
} // namespace cybernet::aquatic::stage3
