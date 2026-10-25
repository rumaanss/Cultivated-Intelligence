#include "cybernet/aquatic/physiology.hpp"
#include <algorithm>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <memory>
#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif
using namespace cybernet::aquatic;
int main(int argc, char **argv) {
  try {
    if (argc != 6)
      throw std::runtime_error(
          "Usage: validate_physiology SEED END_TICK CHECKPOINT "
          "MUTATION_PROBABILITY sunlight(-1=cycle)");
    auto seed = std::stoull(argv[1]), end = std::stoull(argv[2]);
    std::filesystem::path path = argv[3];
    PhysiologyConfig cfg;
    cfg.mutationProbability = std::stod(argv[4]);
    double sunlight = std::stod(argv[5]);
    std::unique_ptr<Physiology> w;
    if (std::filesystem::exists(path)) {
      std::ifstream f(path);
      std::string text{std::istreambuf_iterator<char>(f), {}};
      w = std::make_unique<Physiology>(Physiology::restore(text, seed));
      if (w->config.mutationProbability != cfg.mutationProbability)
        throw std::runtime_error("Validation config mismatch");
    } else
      w = std::make_unique<Physiology>(seed, cfg);
    std::vector<double> times;
    while (w->environment.tick < end) {
      auto t = std::chrono::steady_clock::now();
      w->step(true, true, sunlight);
      if (w->colonies.size() >= w->config.maximumColonies)
        throw std::runtime_error(
            "Ecology gate: population cap reached during segment");
      times.push_back(std::chrono::duration<double, std::milli>(
                          std::chrono::steady_clock::now() - t)
                          .count());
      if (w->environment.tick % 500 == 0)
        w->validate();
    }
    w->validate();
    std::array<unsigned, 3> counts{};
    std::array<double, 3> biomass{};
    for (const auto &c : w->colonies) {
      ++counts[c.guild];
      biomass[c.guild] += w->material(c).c;
    }
    auto text = w->checkpoint();
    auto temp = path;
    temp += ".tmp";
    {
      std::ofstream f(temp);
      f << text;
      if (!f)
        throw std::runtime_error("Checkpoint write failed");
    }
#ifdef _WIN32
    if (!MoveFileExW(temp.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH))
      throw std::runtime_error("Checkpoint atomic replacement failed");
#else
    std::filesystem::rename(temp, path);
#endif
    std::sort(times.begin(), times.end());
    double p95 = times.empty()
                     ? 0
                     : times[std::min(times.size() - 1,
                                      std::size_t(times.size() * .95))];
    std::cout << seed << ',' << cfg.mutationProbability << ',' << end << ','
              << w->colonies.size() << ',' << counts[0] << ',' << counts[1]
              << ',' << counts[2] << ',' << biomass[0] << ',' << biomass[1]
              << ',' << biomass[2] << ',' << w->births << ',' << w->deaths
              << ',' << w->mutations << ',' << p95 << '\n';
    if (sunlight != 0 && (counts[0] == 0 || counts[1] == 0 || counts[2] == 0 ||
                          w->colonies.size() >= cfg.maximumColonies))
      throw std::runtime_error("Ecology gate: extinction or population cap");
  } catch (const std::exception &e) {
    std::cerr << e.what() << '\n';
    return 1;
  }
}
