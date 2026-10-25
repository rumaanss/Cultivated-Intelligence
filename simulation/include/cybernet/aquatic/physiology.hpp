#pragma once
#include "cybernet/aquatic/lake.hpp"
#include <array>
#include <random>

namespace cybernet::aquatic {
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
  GeneCount
};
struct Genome {
  std::uint64_t id{}, parent{};
  unsigned ploidy{1};
  std::vector<std::array<double, GeneCount>> copies;
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
class Physiology {
public:
  Lake environment;
  PhysiologyConfig config;
  std::vector<Colony> colonies;
  std::vector<Genome> genomes;
  std::vector<Ancestry> ancestry;
  std::vector<Material> detritus;
  std::uint64_t births{}, deaths{}, mutations{};
  explicit Physiology(std::uint64_t seed = 42, PhysiologyConfig config = {});
  static Physiology migrate(const Lake &, PhysiologyConfig config = {});
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
} // namespace cybernet::aquatic
