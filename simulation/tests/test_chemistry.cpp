#include "cybernet/world/chemistry.hpp"

#ifdef NDEBUG
#undef NDEBUG
#endif

#include <cassert>
#include <cmath>
#include <iostream>

namespace {

bool approximatelyEqual(float left, float right, float tolerance = 0.0001F) {
    return std::fabs(left - right) <= tolerance;
}

} // namespace

int main() {
    cybernet::ChemistryField field{};

    const cybernet::ChemistryCell initial = field.cellAt({50.0F, 50.0F, 30.0F});
    assert(approximatelyEqual(initial.oxygen, 0.50F));
    assert(approximatelyEqual(initial.nitrate, 1.00F));

    field.diffuse(0.02F);

    const cybernet::ChemistryCell after = field.cellAt({50.0F, 50.0F, 30.0F});
    assert(after.oxygen >= 0.0F);
    assert(after.nitrate >= 0.0F);
    assert(after.phosphate >= 0.0F);

    const cybernet::Vec3 position{50.0F, 50.0F, 30.0F};
    field.processPrimaryProducer(position, 10000.0F);
    assert(approximatelyEqual(field.nutrientSupport(position), 0.0F));

    field.diffuse();
    assert(field.nutrientSupport(position) > 0.0F);

    std::cout << "Chemistry tests passed.\n";
    return 0;
}
