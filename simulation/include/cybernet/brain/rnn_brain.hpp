#pragma once

#include <array>
#include <cstddef>

namespace cybernet {

enum class BrainAction : std::size_t {
    Forward = 0,
    Strafe = 1,
    Vertical = 2,
    Reserved = 3, // legacy-v1: ignored by ecology
    ReproduceIntentV2 = 3, // only active under explicit intent-v2 semantics
    Feed = 4
};

[[nodiscard]] constexpr std::size_t actionIndex(BrainAction action) noexcept {
    return static_cast<std::size_t>(action);
}

enum class BrainInput : std::size_t {
    PreyX = 0,
    PreyY = 1,
    PreyZ = 2,
    PreyDistance = 3,
    Energy = 4,
    VelocityX = 5,
    VelocityY = 6,
    VelocityZ = 7,
    Depth = 8,
    Age = 9,
    Noise = 10,
    NoiseSecondary = 11,
    Light = 12,
    PreyVisible = 13,
    BoundaryInwardX = 14,
    BoundaryInwardY = 15,
    BoundaryInwardZ = 16,
    BoundaryProximity = 17,
    ThreatX = 18,
    ThreatY = 19,
    ThreatZ = 20,
    ThreatDistance = 21,
    Crowding = 22,
    FoodLocal = 23,
    ReproductionReadiness = 24,
    ReproductionCooldown = 25,
    ThreatDensity = 26,
    Bias = 27
};

[[nodiscard]] constexpr std::size_t inputIndex(BrainInput input) noexcept {
    return static_cast<std::size_t>(input);
}

class RnnBrain {
public:

    static constexpr std::size_t InputCount = 28;
    static constexpr std::size_t HiddenCount = 20;
    static constexpr std::size_t OutputCount = 5;

    static constexpr std::size_t InputWeightsSize =
        HiddenCount * InputCount; // 560

    static constexpr std::size_t RecurrentWeightsSize =
        HiddenCount * HiddenCount; // 400

    static constexpr std::size_t HiddenBiasesSize =
        HiddenCount; // 20

    static constexpr std::size_t OutputWeightsSize =
        OutputCount * HiddenCount; // 100

    static constexpr std::size_t OutputBiasesSize =
        OutputCount; // 5

    static constexpr std::size_t ModulatorWeightsSize =
        HiddenCount; // 20

    static constexpr std::size_t ModulatorBiasSize = 1;
    static constexpr std::size_t PlasticityTraitsSize = 4;

    static constexpr std::size_t GenomeSize =
        InputWeightsSize
        + RecurrentWeightsSize
        + HiddenBiasesSize
        + OutputWeightsSize
        + OutputBiasesSize
        + ModulatorWeightsSize
        + ModulatorBiasSize
        + PlasticityTraitsSize; // 1,110

    using Inputs = std::array<float, InputCount>;
    using Outputs = std::array<float, OutputCount>;
    using Genome = std::array<float, GenomeSize>;

    struct InspectionSnapshot {
        Inputs inputs{};
        std::array<float, HiddenCount> hidden{};
        Outputs outputs{};
        std::array<float, RecurrentWeightsSize> plasticWeights{};
        std::array<float, RecurrentWeightsSize> eligibilityTraces{};
        std::array<float, RecurrentWeightsSize> lastPlasticWeightUpdates{};
        float modulatorSignal{0.0F};
        float plasticityRate{0.0F};
        float traceDecay{0.0F};
        float plasticityForgetting{0.0F};
        float plasticityScale{0.0F};
    };

    void decodeGenome(const Genome& genome);
    void reset();

    [[nodiscard]] Outputs step(const Inputs& inputs);
    [[nodiscard]] const std::array<float, InputWeightsSize>&
    inputToHiddenWeights() const noexcept;

    [[nodiscard]] const std::array<float, RecurrentWeightsSize>&
    geneticRecurrentWeights() const noexcept;

    [[nodiscard]] const std::array<float, RecurrentWeightsSize>&
    plasticRecurrentWeights() const noexcept;

    [[nodiscard]] const std::array<float, OutputWeightsSize>&
    hiddenToOutputWeights() const noexcept;

    [[nodiscard]] const std::array<float, HiddenBiasesSize>&
    hiddenBiases() const noexcept;

    [[nodiscard]] const std::array<float, OutputBiasesSize>&
    outputBiases() const noexcept;

    [[nodiscard]] float plasticityScale() const noexcept;
    [[nodiscard]] InspectionSnapshot inspectionSnapshot() const noexcept;

    [[nodiscard]] const Inputs& inputState() const noexcept;
    [[nodiscard]] const std::array<float, HiddenCount>& hiddenState() const noexcept;
    [[nodiscard]] const Outputs& outputState() const noexcept;

private:
    [[nodiscard]] static float sigmoid(float value) noexcept;

    // Inherited genetic neural anatomy.
    std::array<float, InputWeightsSize> inputToHidden_{};
    std::array<float, RecurrentWeightsSize> geneticRecurrent_{};
    std::array<float, HiddenBiasesSize> hiddenBias_{};
    std::array<float, OutputWeightsSize> hiddenToOutput_{};
    std::array<float, OutputBiasesSize> outputBias_{};

    // Inherited neuromodulator pathway.
    std::array<float, ModulatorWeightsSize> modulatorWeights_{};
    float modulatorBias_{0.0F};

    // Inherited capacity-to-learn traits.
    float plasticityRate_{0.0F};
    float traceDecay_{0.70F};
    float plasticityForgetting_{0.0F};
    float plasticityScale_{0.0F};

    // Lifetime-only state. It must begin at zero for every newborn.
    std::array<float, RecurrentWeightsSize> plasticWeights_{};
    std::array<float, RecurrentWeightsSize> eligibilityTrace_{};
    std::array<float, RecurrentWeightsSize> lastPlasticWeightUpdates_{};
    float modulatorSignal_{0.0F};

    Inputs inputState_{};
    std::array<float, HiddenCount> hiddenState_{};
    Outputs outputState_{};

    static_assert(InputCount == 28);
    static_assert(HiddenCount == 20);
    static_assert(OutputCount == 5);
    static_assert(
        GenomeSize ==
        (HiddenCount * InputCount)
        + (HiddenCount * HiddenCount)
        + HiddenCount
        + (OutputCount * HiddenCount)
        + OutputCount
        + HiddenCount
        + 1
        + PlasticityTraitsSize);

};

} // namespace cybernet
