#include "cybernet/simulation/deterministic_worker_pool.hpp"

#include <algorithm>
#include <utility>

namespace cybernet {

DeterministicWorkerPool::DeterministicWorkerPool(std::size_t workerCount) {
    const std::size_t count = std::max(workerCount, std::size_t{1U});
    workers_.reserve(count);
    for (std::size_t index = 0U; index < count; ++index) {
        workers_.emplace_back(&DeterministicWorkerPool::runWorker, this, index);
    }
}

DeterministicWorkerPool::~DeterministicWorkerPool() {
    {
        std::lock_guard lock{mutex_};
        stopping_ = true;
    }
    workAvailable_.notify_all();

    for (std::thread& worker : workers_) {
        if (worker.joinable()) {
            worker.join();
        }
    }
}

void DeterministicWorkerPool::parallelFor(
    std::size_t itemCount,
    std::function<void(std::size_t, std::size_t)> operation) {

    {
        std::lock_guard lock{mutex_};
        itemCount_ = itemCount;
        operation_ = std::move(operation);
        completedWorkers_ = 0U;
        ++generation_;
    }
    workAvailable_.notify_all();

    std::unique_lock lock{mutex_};
    workCompleted_.wait(lock, [this] {
        return completedWorkers_ == workers_.size();
    });
    operation_ = {};
}

void DeterministicWorkerPool::runWorker(std::size_t workerIndex) {
    std::size_t observedGeneration = 0U;

    for (;;) {
        std::function<void(std::size_t, std::size_t)> operation{};
        std::size_t itemCount = 0U;
        std::size_t generation = 0U;
        {
            std::unique_lock lock{mutex_};
            workAvailable_.wait(lock, [this, observedGeneration] {
                return stopping_ || generation_ != observedGeneration;
            });

            if (stopping_) {
                return;
            }

            operation = operation_;
            itemCount = itemCount_;
            generation = generation_;
        }

        const std::size_t begin = (itemCount * workerIndex) / workers_.size();
        const std::size_t end = (itemCount * (workerIndex + 1U)) / workers_.size();
        operation(begin, end);

        {
            std::lock_guard lock{mutex_};
            observedGeneration = generation;
            ++completedWorkers_;
            if (completedWorkers_ == workers_.size()) {
                workCompleted_.notify_one();
            }
        }
    }
}

} // namespace cybernet