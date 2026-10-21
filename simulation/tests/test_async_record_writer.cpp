#include "cybernet/simulation/async_record_writer.hpp"

#ifdef NDEBUG
#undef NDEBUG
#endif

#include <cassert>
#include <filesystem>
#include <fstream>
#include <string>

int main() {
    const std::filesystem::path path{"test_async_record_writer.csv"};
    std::filesystem::remove(path);

    {
        cybernet::AsyncRecordWriter writer{path, 2U};
        for (std::size_t record = 0U; record < 100U; ++record) {
            writer.write(std::to_string(record) + '\n');
        }
    }

    std::ifstream input{path};
    std::string line{};
    for (std::size_t record = 0U; record < 100U; ++record) {
        assert(std::getline(input, line));
        assert(line == std::to_string(record));
    }
    assert(!std::getline(input, line));

    input.close();
    std::filesystem::remove(path);
    return 0;
}