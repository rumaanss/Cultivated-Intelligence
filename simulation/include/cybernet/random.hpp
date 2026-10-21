#pragma once

#include <cstdint>
#include <random>
#include <sstream>
#include <stdexcept>

namespace cybernet {

class Random {
public:
    explicit Random(std::uint64_t seed)
        : engine_(seed) {
    }

    [[nodiscard]] float uniform_float(float minimum, float maximum) {
        std::uniform_real_distribution<float> distribution(minimum, maximum);
        return distribution(engine_);
    }

    [[nodiscard]] int uniform_int(int minimum, int maximum) {
        std::uniform_int_distribution<int> distribution(minimum, maximum);
        return distribution(engine_);
    }

    [[nodiscard]] bool chance(float probability) {
        return uniform_float(0.0F, 1.0F) < probability;
    }

    [[nodiscard]] bool sameState(const Random& other) const {
        return engine_ == other.engine_;
    }

    std::string saveState() const {std::ostringstream s;s.imbue(std::locale::classic());s<<engine_;return s.str();}
    void loadState(const std::string& value){std::istringstream s(value);s.imbue(std::locale::classic());if(!(s>>engine_))throw std::runtime_error("Invalid RNG checkpoint");}
private:
    std::mt19937_64 engine_;
};

} // namespace cybernet

