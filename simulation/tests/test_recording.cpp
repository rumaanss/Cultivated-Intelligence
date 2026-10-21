#include "cybernet/simulation/snapshot_recorder.hpp"
#ifdef NDEBUG
#undef NDEBUG
#endif
#include <cassert>
#include <filesystem>
#include <fstream>
#include <limits>
#include <string>
#include <vector>

std::string read(const std::filesystem::path& path) {
    std::ifstream file(path);
    return {std::istreambuf_iterator<char>(file),std::istreambuf_iterator<char>()};
}
int main() {
    using namespace cybernet;
    const auto directory = std::filesystem::path{"recording_test_output"};
    std::filesystem::create_directories(directory);
    auto path = [&](const char* name) { auto p=directory/name; std::filesystem::remove(p); return p; };
    CelestialCycle cycle;
    std::vector<Organism> population(2);
    population[0].id=2; population[1].id=1;
    population[0].position={0,0,0}; population[1].position={100,100,60};
    population[1].energy=0; // Alive starving organisms must still be recorded.
    const auto complete=path("complete.jsonl");
    {
        SnapshotRecorder writer(complete,42,10);
        cycle.update(1); writer.capture(1,cycle.state(),population);
        cycle.update(2); writer.capture(2,cycle.state(),population); // Interval suppresses this frame.
        population.clear();
        cycle.update(11); writer.capture(11,cycle.state(),population); // Explicit empty frame.
        writer.finish(); writer.finish();
    }
    const auto content=read(complete);
    assert(content.find("\"count\":0,\"light\"")!=std::string::npos);
    assert(content.find("\"agents\":[[1,")!=std::string::npos);
    assert(content.find("\"frames\":2")!=std::string::npos);
    bool refused=false;
    try { SnapshotRecorder duplicate(complete,42); } catch (const std::exception&) { refused=true; }
    assert(refused);
    const auto limited=path("frame_limit.jsonl");
    {
        SnapshotRecorder writer(limited,42,1);
        for(int i=1;i<=130;++i) {cycle.update(i);writer.capture(i,cycle.state(),population);}
    }
    assert(read(limited).find("\"frames\":120,\"reason\":\"frame-limit\"")!=std::string::npos);
    const auto invalid=path("invalid.jsonl");
    {
        SnapshotRecorder writer(invalid,42);
        population.resize(1); population[0].id=1;
        population[0].position.x=std::numeric_limits<float>::quiet_NaN();
        cycle.update(1); writer.capture(1,cycle.state(),population);
    }
    assert(read(invalid).find("\"reason\":\"error\"")!=std::string::npos);
    const auto duplicates=path("duplicates.jsonl");
    {
        SnapshotRecorder writer(duplicates,42);
        population=std::vector<Organism>(2); population[0].id=1; population[1].id=1;
        writer.capture(1,cycle.state(),population);
    }
    assert(read(duplicates).find("\"reason\":\"error\"")!=std::string::npos);
    const auto bytes=path("byte_limit.jsonl");
    {
        SnapshotRecorder writer(bytes,42,1);
        population=std::vector<Organism>(3000);
        for(std::size_t i=0;i<population.size();++i) population[i].id=static_cast<std::uint32_t>(i+1);
        for(int i=1;i<=120;++i) {cycle.update(i);writer.capture(i,cycle.state(),population);}
    }
    assert(std::filesystem::file_size(bytes)<=SnapshotRecorder::MaximumBytes);
    assert(read(bytes).find("\"reason\":\"byte-limit\"")!=std::string::npos);

}
