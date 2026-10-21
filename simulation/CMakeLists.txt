cmake_minimum_required(VERSION 3.20)
# Simulation sources and regression targets. Applications are defined at the root.
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
 message(FATAL_ERROR "Configure the new project root: cmake -S .. -B ../build/native")
endif()
# Unit tests.
enable_testing()

add_executable(test_brain
    tests/test_brain.cpp
    src/brain/rnn_brain.cpp
    src/world/physics.cpp
)

target_include_directories(test_brain
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

add_test(
    NAME RnnBrainTests
    COMMAND test_brain
)

add_executable(test_chemistry
    tests/test_chemistry.cpp
    src/world/chemistry.cpp
)

target_include_directories(test_chemistry
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

add_test(
    NAME ChemistryTests
    COMMAND test_chemistry
)

add_executable(test_physics
    tests/test_physics.cpp
    src/world/physics.cpp
)

target_include_directories(test_physics
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

add_test(
    NAME PhysicsTests
    COMMAND test_physics
)

add_executable(test_ecology
    tests/test_ecology.cpp
    src/brain/rnn_brain.cpp
    src/world/celestial.cpp
    src/world/chemistry.cpp
    src/world/ecology.cpp
)

target_include_directories(test_ecology
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

add_test(
    NAME EcologyTests
    COMMAND test_ecology
)

add_executable(test_lifecycle
    tests/test_lifecycle.cpp
    src/brain/rnn_brain.cpp
    src/simulation/lifecycle.cpp
    src/world/celestial.cpp
    src/world/chemistry.cpp
    src/world/ecology.cpp
    src/world/physics.cpp
)

target_include_directories(test_lifecycle
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

add_test(
    NAME LifecycleTests
    COMMAND test_lifecycle
)

add_executable(test_run_options
    tests/test_run_options.cpp
)

target_include_directories(test_run_options
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

add_test(
    NAME RunOptionsTests
    COMMAND test_run_options
)

add_executable(test_metrics
    tests/test_metrics.cpp
    src/brain/rnn_brain.cpp
    src/simulation/async_record_writer.cpp
    src/simulation/metrics.cpp
)

target_include_directories(test_metrics
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

add_test(
    NAME MetricsTests
    COMMAND test_metrics
)

add_executable(test_async_record_writer
    tests/test_async_record_writer.cpp
    src/simulation/async_record_writer.cpp
)

target_include_directories(test_async_record_writer
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

add_test(
    NAME AsyncRecordWriterTests
    COMMAND test_async_record_writer
)

add_executable(test_selection
    tests/test_selection.cpp
)

target_include_directories(test_selection
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

add_test(
    NAME SelectionTests
    COMMAND test_selection
)

add_executable(test_spawning
    tests/test_spawning.cpp
    src/brain/rnn_brain.cpp
)

target_include_directories(test_spawning
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

add_test(
    NAME SpawningTests
    COMMAND test_spawning
)

add_executable(test_simulation
    tests/test_simulation.cpp
    src/brain/rnn_brain.cpp
    src/simulation/deterministic_worker_pool.cpp
    src/simulation/lifecycle.cpp
    src/world/celestial.cpp
    src/world/chemistry.cpp
    src/world/ecology.cpp
    src/world/physics.cpp
)

target_include_directories(test_simulation
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

add_test(
    NAME SimulationTests
    COMMAND test_simulation
)

add_executable(test_spatial_grid
    tests/test_spatial_grid.cpp
)

target_include_directories(test_spatial_grid
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

add_test(
    NAME SpatialGridTests
    COMMAND test_spatial_grid
)

option(CI_BUILD_PLANTS "Build isolated plant tests and experimental publisher" ON)
if(CI_BUILD_PLANTS)
 add_subdirectory(tools/plants)
endif()

add_executable(test_island_world src/simulation/plant_publisher_lock.cpp tests/test_island_world.cpp src/plants/plant_world.cpp src/world/chemistry.cpp src/world/celestial.cpp)
target_include_directories(test_island_world PRIVATE include)
add_test(NAME IslandWorld COMMAND test_island_world)

add_executable(test_live_bridge tests/test_live_bridge.cpp src/simulation/live_bridge.cpp src/plants/plant_world.cpp src/world/chemistry.cpp src/brain/rnn_brain.cpp)
target_include_directories(test_live_bridge PRIVATE include)
add_test(NAME LiveBridge COMMAND test_live_bridge)

add_executable(test_optics tests/test_optics.cpp)
target_include_directories(test_optics PRIVATE include)
add_test(NAME Optics COMMAND test_optics)
add_executable(test_live_checkpoint tests/test_live_checkpoint.cpp src/simulation/live_bridge.cpp src/plants/plant_world.cpp src/world/chemistry.cpp src/brain/rnn_brain.cpp)
target_include_directories(test_live_checkpoint PRIVATE include)
add_test(NAME LiveCheckpoint COMMAND test_live_checkpoint)

add_executable(test_producer_cycles tests/test_producer_cycles.cpp src/plants/plant_world.cpp src/world/chemistry.cpp src/world/celestial.cpp)
target_include_directories(test_producer_cycles PRIVATE include)
add_test(NAME ProducerCycles COMMAND test_producer_cycles)

add_executable(test_full_pond tests/test_full_pond.cpp)
target_include_directories(test_full_pond PRIVATE include)
target_compile_definitions(test_full_pond PRIVATE CI_FULL_POND=1)
add_test(NAME FullPond COMMAND test_full_pond)

add_executable(test_planet_habitat tests/test_planet_habitat.cpp src/plants/plant_world.cpp src/world/chemistry.cpp src/world/celestial.cpp)
target_include_directories(test_planet_habitat PRIVATE include)
target_compile_definitions(test_planet_habitat PRIVATE CI_FULL_POND=1 CI_PLANET_LAKE=1)
add_test(NAME PlanetHabitat COMMAND test_planet_habitat ${CMAKE_CURRENT_SOURCE_DIR}/../contracts/planet_surface.txt)

add_executable(test_planet_founders tests/test_planet_founders.cpp)
target_include_directories(test_planet_founders PRIVATE include)
target_compile_definitions(test_planet_founders PRIVATE CI_FULL_POND=1 CI_PLANET_LAKE=1)
add_test(NAME PlanetFounders COMMAND test_planet_founders)

add_executable(test_planet_collision tests/test_planet_collision.cpp)
target_include_directories(test_planet_collision PRIVATE include)
target_compile_definitions(test_planet_collision PRIVATE CI_FULL_POND=1 CI_PLANET_LAKE=1)
add_test(NAME PlanetCollision COMMAND test_planet_collision)

# Exact geometry and diagnostic-export checks for the planetary integration.
add_executable(test_heightfield_exact tests/test_heightfield_exact.cpp)
target_include_directories(test_heightfield_exact PRIVATE include)
add_test(NAME HeightfieldExact COMMAND test_heightfield_exact)
add_executable(test_plant_diagnostics tests/test_plant_diagnostics.cpp src/plants/plant_world.cpp src/world/chemistry.cpp src/world/celestial.cpp)
target_include_directories(test_plant_diagnostics PRIVATE include)
target_compile_definitions(test_plant_diagnostics PRIVATE CI_FULL_POND=1 CI_PLANET_LAKE=1)
add_test(NAME PlantDiagnostics COMMAND test_plant_diagnostics ${CMAKE_CURRENT_SOURCE_DIR}/../contracts/planet_surface.txt ${CMAKE_CURRENT_BINARY_DIR}/plant_diagnostics.json)
