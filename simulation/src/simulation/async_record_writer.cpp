#include "cybernet/simulation/async_record_writer.hpp"

#include <algorithm>
#include <stdexcept>
#include <utility>

namespace cybernet {

AsyncRecordWriter::AsyncRecordWriter(
    std::filesystem::path path,
    std::size_t maximumQueuedRecords)
    : maximumQueuedRecords_(std::max(maximumQueuedRecords, std::size_t{1U})) {

    if (!path.parent_path().empty()) {
        std::filesystem::create_directories(path.parent_path());
    }
    file_.open(std::move(path), std::ios::out | std::ios::trunc);
    if (!file_.is_open()) {
        throw std::runtime_error("Unable to create asynchronous record output.");
    }

    writer_ = std::thread(&AsyncRecordWriter::writeRecords, this);
}

AsyncRecordWriter::~AsyncRecordWriter() {
    close();
}

void AsyncRecordWriter::write(std::string record) {
    std::unique_lock lock{mutex_};
    spaceAvailable_.wait(lock, [this] {
        return closing_ || records_.size() < maximumQueuedRecords_;
    });

    if (closing_) {
        throw std::runtime_error("Cannot write to a closed asynchronous record output.");
    }

    records_.push_back(std::move(record));
    recordsAvailable_.notify_one();
}

void AsyncRecordWriter::close() {
    {
        std::lock_guard lock{mutex_};
        if (closing_) {
            return;
        }
        closing_ = true;
    }

    recordsAvailable_.notify_one();
    spaceAvailable_.notify_all();
    if (writer_.joinable()) {
        writer_.join();
    }
}

void AsyncRecordWriter::writeRecords() {
    for (;;) {
        std::string record{};
        {
            std::unique_lock lock{mutex_};
            recordsAvailable_.wait(lock, [this] {
                return closing_ || !records_.empty();
            });

            if (records_.empty()) {
                if (closing_) {
                    break;
                }
                continue;
            }

            record = std::move(records_.front());
            records_.pop_front();
            spaceAvailable_.notify_one();
        }

        file_ << record;
    }

    file_.flush();
}

} // namespace cybernet