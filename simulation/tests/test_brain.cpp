#include "cybernet/brain/rnn_brain.hpp"
#include "cybernet/simulation/organism.hpp"
#include "cybernet/simulation/simulation.hpp"

#ifdef NDEBUG
#undef NDEBUG
#endif

#include <cassert>
#include <cmath>
#include <iostream>

namespace {

bool approximatelyEqual(float left, float right, float tolerance = 0.00001F) {
    return std::fabs(left - right) <= tolerance;
}

} // namespace

int main() {
    using cybernet::RnnBrain;

    static_assert(RnnBrain::GenomeSize == 1110U);
    static_assert(cybernet::GenomeSize == RnnBrain::GenomeSize + 1U);
    static_assert(cybernet::config::GENOME_SIZE == RnnBrain::GenomeSize);

    // Test 1:
    // A zero genome produces zero hidden activations and sigmoid(0) outputs.
    {
        RnnBrain brain{};
        RnnBrain::Genome genome{};
        RnnBrain::Inputs inputs{};

        brain.decodeGenome(genome);

        const RnnBrain::Outputs outputs = brain.step(inputs);

        for (float output : outputs) {
            assert(approximatelyEqual(output, 0.5F));
        }

        for (float input : brain.inputState()) {
            assert(approximatelyEqual(input, 0.0F));
        }
    }

    // Test 2:
    // Verify the exact Python genome ordering:
    //
    // gene 0   = input[0] -> hidden[0] weight
    // gene 980 = hidden[0] -> output[0] weight
    //
    // With input[0] = 1:
    // hidden[0] = tanh(1)
    // output[0] = sigmoid(tanh(1))
    {
        RnnBrain brain{};
        RnnBrain::Genome genome{};
        RnnBrain::Inputs inputs{};

        genome[0] = 1.0F;
        genome[980] = 1.0F;
        inputs[0] = 1.0F;

        brain.decodeGenome(genome);

        const RnnBrain::Outputs outputs = brain.step(inputs);

        const float expectedHidden = std::tanh(1.0F);
        const float expectedOutput =
            1.0F / (1.0F + std::exp(-expectedHidden));

        assert(approximatelyEqual(outputs[0], expectedOutput));

        assert(approximatelyEqual(brain.inputState()[0], 1.0F));

        for (std::size_t output = 1; output < RnnBrain::OutputCount; ++output) {
            assert(approximatelyEqual(outputs[output], 0.5F));
        }
    }

    // Test 3:
    // Inspection snapshots expose lifetime-only plasticity state without
    // changing the recurrent update.
    {
        constexpr std::size_t ModulatorBiasIndex =
            RnnBrain::InputWeightsSize
            + RnnBrain::RecurrentWeightsSize
            + RnnBrain::HiddenBiasesSize
            + RnnBrain::OutputWeightsSize
            + RnnBrain::OutputBiasesSize
            + RnnBrain::ModulatorWeightsSize;
        constexpr std::size_t PlasticityRateIndex = ModulatorBiasIndex + 1U;

        RnnBrain brain{};
        RnnBrain::Genome genome{};
        RnnBrain::Inputs inputs{};
        genome[0] = 1.0F;
        genome[ModulatorBiasIndex] = 60.0F;
        genome[PlasticityRateIndex] = 60.0F;
        inputs[0] = 1.0F;

        brain.decodeGenome(genome);
        brain.step(inputs);
        brain.step(inputs);

        const RnnBrain::InspectionSnapshot snapshot = brain.inspectionSnapshot();
        assert(snapshot.modulatorSignal > 0.99F);
        assert(snapshot.eligibilityTraces[0] > 0.0F);
        assert(snapshot.lastPlasticWeightUpdates[0] > 0.0F);
        assert(snapshot.plasticWeights[0] > 0.0F);
        assert(snapshot.plasticityRate > 0.009F);

        brain.reset();
        const RnnBrain::InspectionSnapshot resetSnapshot =
            brain.inspectionSnapshot();
        assert(approximatelyEqual(resetSnapshot.modulatorSignal, 0.0F));
        assert(approximatelyEqual(resetSnapshot.plasticWeights[0], 0.0F));
        assert(approximatelyEqual(resetSnapshot.eligibilityTraces[0], 0.0F));
        assert(approximatelyEqual(
            resetSnapshot.lastPlasticWeightUpdates[0],
            0.0F));
    }

    std::cout << "RnnBrain tests passed.\n";
    return 0;
}
