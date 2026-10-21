#pragma once

#include "cybernet/simulation/organism.hpp"
#include "raylib.h"

#include <algorithm>
#include <cmath>
#include <cstddef>

namespace cybernet::ui {

inline Color ActivationColor(float value) {
    value = std::clamp(value, -1.0F, 1.0F);

    if (value >= 0.0F) {
        return Color{
            static_cast<unsigned char>(50 + value * 205.0F),
            static_cast<unsigned char>(110 + value * 145.0F),
            255,
            255
        };
    }

    const float magnitude = -value;

    return Color{
        255,
        static_cast<unsigned char>(100 - magnitude * 70.0F),
        static_cast<unsigned char>(100 - magnitude * 70.0F),
        255
    };
}

inline const char* InspectorSpeciesName(OrganismType species) {
    switch (species) {
    case OrganismType::Cyanobacteria:
        return "Cyanobacteria";
    case OrganismType::Bacterivore:
        return "Bacterivore";
    case OrganismType::BodoSaltans:
        return "Bodo-Saltans";
    default:
        return "Unknown";
    }
}

enum class InspectorLayer : std::uint8_t {
    Input,
    Hidden,
    Output
};

struct BrainInspectorState {
    InspectorLayer selectedLayer{InspectorLayer::Hidden};
    int selectedIndex{0};
    float zoom{1.0F};
    Vector2 pan{};
};

struct BrainInspectorLayout {
    float top{0.0F};
    float bottom{0.0F};
    float inputX{0.0F};
    float hiddenX{0.0F};
    float outputX{0.0F};
    Vector2 center{};
};

inline BrainInspectorLayout MakeBrainInspectorLayout(const Rectangle& panel) {
    return {
        .top = panel.y + 158.0F,
        .bottom = panel.y + panel.height - 28.0F,
        .inputX = panel.x + 100.0F,
        .hiddenX = panel.x + panel.width * 0.50F,
        .outputX = panel.x + panel.width - 100.0F,
        .center = {panel.x + panel.width * 0.50F, panel.y + panel.height * 0.60F}
    };
}

inline Vector2 InspectorNeuronPosition(
    const BrainInspectorLayout& layout,
    const BrainInspectorState& state,
    InspectorLayer layer,
    int index) {

    const int count = layer == InspectorLayer::Input
        ? static_cast<int>(RnnBrain::InputCount)
        : layer == InspectorLayer::Hidden
            ? static_cast<int>(RnnBrain::HiddenCount)
            : static_cast<int>(RnnBrain::OutputCount);
    const float x = layer == InspectorLayer::Input
        ? layout.inputX
        : layer == InspectorLayer::Hidden
            ? layout.hiddenX
            : layout.outputX;
    const float spacing = (layout.bottom - layout.top)
        / static_cast<float>(count + 1);
    const float y = layout.top + spacing * static_cast<float>(index + 1);

    return {
        layout.center.x + ((x - layout.center.x) * state.zoom) + state.pan.x,
        layout.center.y + ((y - layout.center.y) * state.zoom) + state.pan.y
    };
}

inline void UpdateBrainInspectorInteraction(
    BrainInspectorState& state,
    const Rectangle& panel) {

    const Vector2 mouse = GetMousePosition();
    if (!CheckCollisionPointRec(mouse, panel)) {
        return;
    }

    state.zoom = std::clamp(
        state.zoom + (GetMouseWheelMove() * 0.10F),
        0.60F,
        2.50F);

    if (IsMouseButtonDown(MOUSE_BUTTON_MIDDLE)) {
        const Vector2 delta = GetMouseDelta();
        state.pan.x += delta.x;
        state.pan.y += delta.y;
    }

    if (!IsMouseButtonPressed(MOUSE_BUTTON_LEFT)) {
        return;
    }

    const BrainInspectorLayout layout = MakeBrainInspectorLayout(panel);
    constexpr InspectorLayer layers[] = {
        InspectorLayer::Input,
        InspectorLayer::Hidden,
        InspectorLayer::Output
    };
    const float hitRadius = 14.0F * state.zoom;

    for (const InspectorLayer layer : layers) {
        const int count = layer == InspectorLayer::Input
            ? static_cast<int>(RnnBrain::InputCount)
            : layer == InspectorLayer::Hidden
                ? static_cast<int>(RnnBrain::HiddenCount)
                : static_cast<int>(RnnBrain::OutputCount);
        for (int index = 0; index < count; ++index) {
            if (CheckCollisionPointCircle(
                    mouse,
                    InspectorNeuronPosition(layout, state, layer, index),
                    hitRadius)) {
                state.selectedLayer = layer;
                state.selectedIndex = index;
                return;
            }
        }
    }
}

inline void DrawBrainInspector(
    const Organism& organism,
    const Rectangle& panel,
    const BrainInspectorState& state) {

    constexpr int InputCount = RnnBrain::InputCount;
    constexpr int HiddenCount = RnnBrain::HiddenCount;
    constexpr int OutputCount = RnnBrain::OutputCount;
    constexpr float MinimumDisplayedWeight = 0.05F;

    const float neuronRadius = 10.0F * state.zoom;
    const RnnBrain& brain = organism.brain;
    const RnnBrain::InspectionSnapshot snapshot = brain.inspectionSnapshot();
    const auto& inputToHiddenWeights = brain.inputToHiddenWeights();
    const auto& hiddenToOutputWeights = brain.hiddenToOutputWeights();
    const BrainInspectorLayout layout = MakeBrainInspectorLayout(panel);

    const char* inputLabels[InputCount] = {
        "Prey X", "Prey Y", "Prey Z", "Prey Dist",
        "Energy", "Vel X", "Vel Y", "Vel Z",
        "Depth", "Age", "Noise", "Noise2",
        "Light", "Prey Visible",
        "Boundary X", "Boundary Y", "Boundary Z", "Boundary Near",
        "Threat X", "Threat Y", "Threat Z", "Threat Dist",
        "Crowding", "Food Local", "Readiness", "Cooldown",
        "Threat Density", "Bias"
    };

    const char* outputLabels[OutputCount] = {
        "Forward", "Strafe", "Vertical",
        "Reserved", "Feed"
    };

    DrawRectangleRec(panel, Color{7, 18, 38, 245});
    DrawRectangleLinesEx(panel, 2.0F, Color{90, 180, 255, 255});

    DrawText(
        TextFormat(
            "NEURAL INSPECTOR  |  Organism %u  |  %s  |  Energy %.1f  |  Health %.1f  |  Age %u",
            organism.id,
            InspectorSpeciesName(organism.species),
            organism.energy,
            organism.health,
            organism.ageTicks),
        static_cast<int>(panel.x + 16),
        static_cast<int>(panel.y + 12),
        19,
        RAYWHITE);

    DrawText(
        "Click a neuron for detail  |  Wheel zoom  |  Middle drag pan",
        static_cast<int>(panel.x + 16),
        static_cast<int>(panel.y + 34),
        13,
        Color{145, 180, 215, 255});

    DrawText(
        TextFormat(
            "Mod %.3f  Rate %.4f  Trace %.3f  Forget %.4f  Scale %.3f",
            snapshot.modulatorSignal,
            snapshot.plasticityRate,
            snapshot.traceDecay,
            snapshot.plasticityForgetting,
            snapshot.plasticityScale),
        static_cast<int>(panel.x + 16),
        static_cast<int>(panel.y + 58),
        13,
        Color{145, 180, 215, 255});

    const int selectedIndex = state.selectedIndex;
    if (state.selectedLayer == InspectorLayer::Input
        && selectedIndex >= 0 && selectedIndex < InputCount) {
        DrawText(
            TextFormat(
                "Input %d: %s  |  Activation %.3f",
                selectedIndex,
                inputLabels[selectedIndex],
                snapshot.inputs[static_cast<std::size_t>(selectedIndex)]),
            static_cast<int>(panel.x + 16),
            static_cast<int>(panel.y + 82),
            15,
            RAYWHITE);
    } else if (state.selectedLayer == InspectorLayer::Hidden
        && selectedIndex >= 0 && selectedIndex < HiddenCount) {
        float incomingPlastic = 0.0F;
        float outgoingPlastic = 0.0F;
        float incomingTrace = 0.0F;
        float outgoingTrace = 0.0F;
        float incomingPlasticUpdate = 0.0F;
        float strongestInputInfluence = -1.0F;
        int strongestInput = 0;
        float strongestOutputInfluence = -1.0F;
        int strongestOutput = 0;
        float strongestIncomingRecurrent = -1.0F;
        int strongestIncomingSource = 0;
        float strongestOutgoingRecurrent = -1.0F;
        int strongestOutgoingTarget = 0;
        const auto& geneticRecurrent = brain.geneticRecurrentWeights();

        for (int input = 0; input < InputCount; ++input) {
            const float influence = std::abs(
                inputToHiddenWeights[
                    static_cast<std::size_t>(selectedIndex * InputCount + input)]
                * snapshot.inputs[static_cast<std::size_t>(input)]);
            if (influence > strongestInputInfluence) {
                strongestInputInfluence = influence;
                strongestInput = input;
            }
        }

        for (int output = 0; output < OutputCount; ++output) {
            const float influence = std::abs(
                hiddenToOutputWeights[
                    static_cast<std::size_t>(output * HiddenCount + selectedIndex)]
                * snapshot.hidden[static_cast<std::size_t>(selectedIndex)]);
            if (influence > strongestOutputInfluence) {
                strongestOutputInfluence = influence;
                strongestOutput = output;
            }
        }

        for (int index = 0; index < HiddenCount; ++index) {
            const std::size_t incomingIndex = static_cast<std::size_t>(
                selectedIndex * HiddenCount + index);
            const std::size_t outgoingIndex = static_cast<std::size_t>(
                index * HiddenCount + selectedIndex);
            incomingPlastic += std::abs(snapshot.plasticWeights[incomingIndex]);
            outgoingPlastic += std::abs(snapshot.plasticWeights[outgoingIndex]);
            incomingTrace += std::abs(snapshot.eligibilityTraces[incomingIndex]);
            outgoingTrace += std::abs(snapshot.eligibilityTraces[outgoingIndex]);
            incomingPlasticUpdate += std::abs(
                snapshot.lastPlasticWeightUpdates[incomingIndex]);

            const float incomingEffective = geneticRecurrent[incomingIndex]
                + (snapshot.plasticityScale * snapshot.plasticWeights[incomingIndex]);
            if (std::abs(incomingEffective) > strongestIncomingRecurrent) {
                strongestIncomingRecurrent = std::abs(incomingEffective);
                strongestIncomingSource = index;
            }

            const float outgoingEffective = geneticRecurrent[outgoingIndex]
                + (snapshot.plasticityScale * snapshot.plasticWeights[outgoingIndex]);
            if (std::abs(outgoingEffective) > strongestOutgoingRecurrent) {
                strongestOutgoingRecurrent = std::abs(outgoingEffective);
                strongestOutgoingTarget = index;
            }
        }
        const float divisor = static_cast<float>(HiddenCount);
        const float activation = snapshot.hidden[static_cast<std::size_t>(selectedIndex)];
        const float meanPlasticUpdate = incomingPlasticUpdate / divisor;
        const char* activityMode = std::abs(activation) < 0.05F
            ? "Inactive"
            : std::abs(activation) > 0.95F
                ? "Saturated"
                : meanPlasticUpdate > 0.00001F
                    ? "Plasticity-Active"
                    : "Active";
        DrawText(
            TextFormat(
                "H%02d  |  %s  |  Activation %.3f  |  Strongest Input %s %.3f  |  Output %s %.3f",
                selectedIndex,
                activityMode,
                activation,
                inputLabels[strongestInput],
                strongestInputInfluence,
                outputLabels[strongestOutput],
                strongestOutputInfluence),
            static_cast<int>(panel.x + 16),
            static_cast<int>(panel.y + 82),
            15,
            RAYWHITE);
        DrawText(
            TextFormat(
                "Recurrent H%02d -> H%02d %.3f  |  H%02d -> H%02d %.3f  |  Plastic in/out %.3f / %.3f  |  Trace in/out %.3f / %.3f",
                strongestIncomingSource,
                selectedIndex,
                strongestIncomingRecurrent,
                selectedIndex,
                strongestOutgoingTarget,
                strongestOutgoingRecurrent,
                incomingPlastic / divisor,
                outgoingPlastic / divisor,
                incomingTrace / divisor,
                outgoingTrace / divisor),
            static_cast<int>(panel.x + 16),
            static_cast<int>(panel.y + 104),
            13,
            Color{145, 180, 215, 255});
    } else if (state.selectedLayer == InspectorLayer::Output
        && selectedIndex >= 0 && selectedIndex < OutputCount) {
        DrawText(
            TextFormat(
                "Output %d: %s  |  Activation %.3f",
                selectedIndex,
                outputLabels[selectedIndex],
                snapshot.outputs[static_cast<std::size_t>(selectedIndex)]),
            static_cast<int>(panel.x + 16),
            static_cast<int>(panel.y + 82),
            15,
            RAYWHITE);
    }

    // Input -> hidden connections.
    for (int input = 0; input < InputCount; ++input) {
        const Vector2 from = InspectorNeuronPosition(
            layout,
            state,
            InspectorLayer::Input,
            input);

        for (int hidden = 0; hidden < HiddenCount; ++hidden) {
            const Vector2 to = InspectorNeuronPosition(
                layout,
                state,
                InspectorLayer::Hidden,
                hidden);

            const std::size_t weightIndex =
                (static_cast<std::size_t>(hidden) * InputCount)
                + static_cast<std::size_t>(input);

            const float weight = inputToHiddenWeights[weightIndex];
            const float strength = std::fabs(weight);

            if (strength < MinimumDisplayedWeight) {
                continue;
            }

            Color lineColor = weight >= 0.0F
                ? Color{60, 150, 255, static_cast<unsigned char>(25 + strength * 180.0F)}
                : Color{255, 80, 80, static_cast<unsigned char>(25 + strength * 180.0F)};

            DrawLineEx(
                from,
                to,
                (0.5F + strength * 2.0F) * state.zoom,
                lineColor);
        }
    }

    // Hidden -> output connections.
    for (int hidden = 0; hidden < HiddenCount; ++hidden) {
        const Vector2 from = InspectorNeuronPosition(
            layout,
            state,
            InspectorLayer::Hidden,
            hidden);

        for (int output = 0; output < OutputCount; ++output) {
            const Vector2 to = InspectorNeuronPosition(
                layout,
                state,
                InspectorLayer::Output,
                output);

            const std::size_t weightIndex =
                (static_cast<std::size_t>(output) * HiddenCount)
                + static_cast<std::size_t>(hidden);

            const float weight = hiddenToOutputWeights[weightIndex];
            const float strength = std::fabs(weight);

            if (strength < MinimumDisplayedWeight) {
                continue;
            }

            Color lineColor = weight >= 0.0F
                ? Color{60, 150, 255, static_cast<unsigned char>(25 + strength * 180.0F)}
                : Color{255, 80, 80, static_cast<unsigned char>(25 + strength * 180.0F)};

            DrawLineEx(
                from,
                to,
                (0.5F + strength * 2.0F) * state.zoom,
                lineColor);
        }
    }

    // Input neurons.
    for (int i = 0; i < InputCount; ++i) {
        const Vector2 point = InspectorNeuronPosition(
            layout,
            state,
            InspectorLayer::Input,
            i);
        const float activation = snapshot.inputs[static_cast<std::size_t>(i)];

        DrawCircleV(point, neuronRadius, ActivationColor(activation));
        DrawCircleLinesV(point, neuronRadius, RAYWHITE);
        if (state.selectedLayer == InspectorLayer::Input
            && state.selectedIndex == i) {
            DrawCircleLinesV(point, neuronRadius + 4.0F, YELLOW);
        }

    }

    // Hidden neurons.
    for (int i = 0; i < HiddenCount; ++i) {
        const Vector2 point = InspectorNeuronPosition(
            layout,
            state,
            InspectorLayer::Hidden,
            i);

        const float activation = snapshot.hidden[static_cast<std::size_t>(i)];

        DrawCircleV(point, neuronRadius, ActivationColor(activation));
        DrawCircleLinesV(point, neuronRadius, RAYWHITE);
        if (state.selectedLayer == InspectorLayer::Hidden
            && state.selectedIndex == i) {
            DrawCircleLinesV(point, neuronRadius + 4.0F, YELLOW);
        }
    }

    // Output neurons.
    for (int i = 0; i < OutputCount; ++i) {
        const Vector2 point = InspectorNeuronPosition(
            layout,
            state,
            InspectorLayer::Output,
            i);

        const float activation = snapshot.outputs[static_cast<std::size_t>(i)];

        DrawCircleV(point, neuronRadius, ActivationColor(activation));
        DrawCircleLinesV(point, neuronRadius, RAYWHITE);
        if (state.selectedLayer == InspectorLayer::Output
            && state.selectedIndex == i) {
            DrawCircleLinesV(point, neuronRadius + 4.0F, YELLOW);
        }

    }

    DrawText(
        "INPUTS",
        static_cast<int>(layout.inputX - 26.0F),
        static_cast<int>(panel.y + panel.height - 19.0F),
        13,
        Color{110, 180, 255, 255});

    DrawText(
        "HIDDEN",
        static_cast<int>(layout.hiddenX - 25.0F),
        static_cast<int>(panel.y + panel.height - 19.0F),
        13,
        Color{110, 180, 255, 255});

    DrawText(
        "OUTPUTS",
        static_cast<int>(layout.outputX - 29.0F),
        static_cast<int>(panel.y + panel.height - 19.0F),
        13,
        Color{110, 180, 255, 255});
}

} // namespace cybernet::ui
