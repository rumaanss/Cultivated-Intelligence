#pragma once

#include <condition_variable>
#include <cstddef>
#include <deque>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <string>
#include <thread>

namespace cybernet {

class AsyncRecordWriter {
public:
    explicit AsyncRecordWriter(
        std::filesystem::path path,
        std::size_t maximumQueuedRecords = 4096U);
    ~AsyncRecordWriter();

    AsyncRecordWriter(const AsyncRecordWriter&) = delete;
    AsyncRecordWriter& operator=(const AsyncRecordWriter&) = delete;

    void write(std::string record);
    void close();

private:
    void writeRecords();

    std::ofstream file_{};
    std::deque<std::string> records_{};
    std::size_t maximumQueuedRecords_{1U};
    std::mutex mutex_{};
    std::condition_variable recordsAvailable_{};
    std::condition_variable spaceAvailable_{};
    bool closing_{false};
    std::thread writer_{};
};

} // namespace cybernet