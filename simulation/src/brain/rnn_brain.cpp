#include "cybernet/brain/rnn_brain.hpp"

#include <algorithm>
#include <cmath>

namespace cybernet {
namespace {

constexpr float SigmoidLimit = 60.0F;
constexpr float PlasticWeightLimit = 1.0F;

} // namespace

float RnnBrain::sigmoid(float value) noexcept {
    const float clipped = std::clamp(value, -SigmoidLimit, SigmoidLimit);
    return 1.0F / (1.0F + std::exp(-clipped));
}

void RnnBrain::decodeGenome(const Genome& genome) {
    std::size_t index = 0;

    for (float& weight : inputToHidden_) {
        weight = genome[index++];
    }

    for (float& weight : geneticRecurrent_) {
        weight = genome[index++];
    }

    for (float& bias : hiddenBias_) {
        bias = genome[index++];
    }

    for (float& weight : hiddenToOutput_) {
        weight = genome[index++];
    }

    for (float& bias : outputBias_) {
        bias = genome[index++];
    }

    for (float& weight : modulatorWeights_) {
        weight = genome[index++];
    }

    modulatorBias_ = genome[index++];

    const float rateGene = genome[index++];
    const float traceGene = genome[index++];
    const float forgettingGene = genome[index++];
    const float scaleGene = genome[index++];

    // Exact Python trait transformations.
    plasticityRate_ = sigmoid(rateGene) * 0.01F;
    traceDecay_ = 0.70F + (sigmoid(traceGene) * 0.29F);
    plasticityForgetting_ = sigmoid(forgettingGene) * 0.005F;
    plasticityScale_ = sigmoid(scaleGene);

    reset();
}

void RnnBrain::reset() {
    // Python starts learned changes and eligibility traces at zero.
    plasticWeights_.fill(0.0F);
    eligibilityTrace_.fill(0.0F);
    lastPlasticWeightUpdates_.fill(0.0F);
    modulatorSignal_ = 0.0F;

    inputState_.fill(0.0F);
    hiddenState_.fill(0.0F);
    outputState_.fill(0.0F);
}

RnnBrain::Outputs RnnBrain::step(const Inputs& inputs) {
    inputState_ = inputs;
    const auto previousHidden = hiddenState_;
    const float plasticityScale = plasticityScale_;
    const float traceDecay = traceDecay_;

    // hidden_state = tanh(
    //     input_to_hidden @ observation
    //     + active_recurrent @ previous_hidden
    //     + hidden_bias
    // )
    for (std::size_t target = 0; target < HiddenCount; ++target) {
        float activation = hiddenBias_[target];

        const std::size_t inputRow = target * InputCount;
        for (std::size_t input = 0; input < InputCount; ++input) {
            activation += inputToHidden_[inputRow + input] * inputs[input];
        }

        const std::size_t recurrentRow = target * HiddenCount;
        for (std::size_t source = 0; source < HiddenCount; ++source) {
            const std::size_t index = recurrentRow + source;

            const float activeWeight =
                geneticRecurrent_[index]
                + (plasticityScale * plasticWeights_[index]);

            activation += activeWeight * previousHidden[source];
        }

        hiddenState_[target] = std::tanh(activation);
    }

    // plasticity_signal = tanh(w_modulator @ hidden_state + b_modulator)
    float modulatorActivation = modulatorBias_;

    for (std::size_t hidden = 0; hidden < HiddenCount; ++hidden) {
        modulatorActivation += modulatorWeights_[hidden] * hiddenState_[hidden];
    }

    modulatorSignal_ = std::tanh(modulatorActivation);
    const float plasticityUpdate = plasticityRate_ * modulatorSignal_;
    const float forgettingMultiplier = 1.0F - plasticityForgetting_;

    // eligibility_trace =
    //     trace_decay * eligibility_trace
    //     + outer(hidden_state, previous_hidden)
    for (std::size_t target = 0; target < HiddenCount; ++target) {
        const std::size_t recurrentRow = target * HiddenCount;
        for (std::size_t source = 0; source < HiddenCount; ++source) {
            const std::size_t index = recurrentRow + source;

            eligibilityTrace_[index] =
                (traceDecay * eligibilityTrace_[index])
                + (hiddenState_[target] * previousHidden[source]);
        }
    }

    // plastic_weights += plasticity_rate * plasticity_signal * trace
    // plastic_weights *= (1 - forgetting)
    // plastic_weights = clip(plastic_weights, -1, 1)
    for (std::size_t index = 0; index < RecurrentWeightsSize; ++index) {
        const float previousWeight = plasticWeights_[index];
        plasticWeights_[index] +=
            plasticityUpdate * eligibilityTrace_[index];

        plasticWeights_[index] *= forgettingMultiplier;

        plasticWeights_[index] = std::clamp(
            plasticWeights_[index],
            -PlasticWeightLimit,
            PlasticWeightLimit);
        lastPlasticWeightUpdates_[index] = plasticWeights_[index] - previousWeight;
    }

    // output = sigmoid(hidden_to_output @ hidden_state + output_bias)
    for (std::size_t output = 0; output < OutputCount; ++output) {
        float activation = outputBias_[output];

        const std::size_t outputRow = output * HiddenCount;
        for (std::size_t hidden = 0; hidden < HiddenCount; ++hidden) {
            activation += hiddenToOutput_[outputRow + hidden] * hiddenState_[hidden];
        }

        outputState_[output] = sigmoid(activation);
    }

    return outputState_;
}

const std::array<float, RnnBrain::InputWeightsSize>&
RnnBrain::inputToHiddenWeights() const noexcept {
    return inputToHidden_;
}

const std::array<float, RnnBrain::RecurrentWeightsSize>&
RnnBrain::geneticRecurrentWeights() const noexcept {
    return geneticRecurrent_;
}

const std::array<float, RnnBrain::RecurrentWeightsSize>&
RnnBrain::plasticRecurrentWeights() const noexcept {
    return plasticWeights_;
}

const std::array<float, RnnBrain::OutputWeightsSize>&
RnnBrain::hiddenToOutputWeights() const noexcept {
    return hiddenToOutput_;
}

const std::array<float, RnnBrain::HiddenBiasesSize>&
RnnBrain::hiddenBiases() const noexcept {
    return hiddenBias_;
}

const std::array<float, RnnBrain::OutputBiasesSize>&
RnnBrain::outputBiases() const noexcept {
    return outputBias_;
}

float RnnBrain::plasticityScale() const noexcept {
    return plasticityScale_;
}

RnnBrain::InspectionSnapshot RnnBrain::inspectionSnapshot() const noexcept {
    return {
        .inputs = inputState_,
        .hidden = hiddenState_,
        .outputs = outputState_,
        .plasticWeights = plasticWeights_,
        .eligibilityTraces = eligibilityTrace_,
        .lastPlasticWeightUpdates = lastPlasticWeightUpdates_,
        .modulatorSignal = modulatorSignal_,
        .plasticityRate = plasticityRate_,
        .traceDecay = traceDecay_,
        .plasticityForgetting = plasticityForgetting_,
        .plasticityScale = plasticityScale_
    };
}

const RnnBrain::Inputs& RnnBrain::inputState() const noexcept {
    return inputState_;
}

const std::array<float, RnnBrain::HiddenCount>&
RnnBrain::hiddenState() const noexcept {
    return hiddenState_;
}

const RnnBrain::Outputs&
RnnBrain::outputState() const noexcept {
    return outputState_;
}

} // namespace cybernet
