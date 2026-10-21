#pragma once

#include <condition_variable>
#include <cstddef>
#include <functional>
#include <mutex>
#include <thread>
#include <vector>

namespace cybernet {

class DeterministicWorkerPool {
public:
    explicit DeterministicWorkerPool(std::size_t workerCount = 1U);
    ~DeterministicWorkerPool();

    DeterministicWorkerPool(const DeterministicWorkerPool&) = delete;
    DeterministicWorkerPool& operator=(const DeterministicWorkerPool&) = delete;

    void parallelFor(
        std::size_t itemCount,
        std::function<void(std::size_t, std::size_t)> operation);

private:
    void runWorker(std::size_t workerIndex);

    std::vector<std::thread> workers_{};
    std::function<void(std::size_t, std::size_t)> operation_{};
    std::size_t itemCount_{0U};
    std::size_t completedWorkers_{0U};
    std::size_t generation_{0U};
    bool stopping_{false};
    std::mutex mutex_{};
    std::condition_variable workAvailable_{};
    std::condition_variable workCompleted_{};
};

} // namespace cybernet