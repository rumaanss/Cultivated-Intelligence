#include "cybernet/simulation/run_options.hpp"

#ifdef NDEBUG
#undef NDEBUG
#endif

#include <cassert>
#include <cstdint>
#include <iostream>

int main() {
    {
        char program[]="sim", option[]="--island-surface", path[]="path with spaces.txt", live[]="--live-dir", dir[]="live/island001";
        char optics[]="--optics=v2",geometry[]="--geometry=lake";
        char* args[]={program,option,path,live,dir,optics,geometry};
        auto result=cybernet::parseRunOptions(7,args);
        assert(result.valid()&&result.options.islandSurface==path&&result.options.liveDirectory==dir);
        assert(!cybernet::parseRunOptions(2,args).valid());
        char equals[]="--island-surface=world.txt",empty[]="--island-surface=";
        args[1]=equals;assert(cybernet::parseRunOptions(2,args).options.islandSurface=="world.txt");
        args[1]=empty;assert(!cybernet::parseRunOptions(2,args).valid());
    }

    {
        char program[] = "sim";
        char option[] = "--recording=trial.jsonl";
        char interval[] = "--recording-interval=20";
        char* args[] = {program, option, interval};
        auto result = cybernet::parseRunOptions(3,args);
        assert(result.valid());
        assert(result.options.recordingPath == "trial.jsonl");
        assert(result.options.recordingIntervalTicks == 20);
        char bad[] = "--recording-interval=0";
        args[2] = bad;
        assert(!cybernet::parseRunOptions(3,args).valid());
        char empty[] = "--recording=";
        args[1] = empty;
        assert(!cybernet::parseRunOptions(2,args).valid());
        char split[] = "--recording";
        char value[] = "path with spaces.jsonl";
        char* separated[] = {program,split,value};
        assert(cybernet::parseRunOptions(3,separated).options.recordingPath == value);
    }

    {
        char program[] = "cybernet_sim";
        char* arguments[] = {program};
        const cybernet::RunOptionsParseResult result =
            cybernet::parseRunOptions(1, arguments);

        assert(result.valid());
        assert(result.options.seed == cybernet::config::DEFAULT_RANDOM_SEED);
    }

    {
        char program[] = "cybernet_sim";
        char option[] = "--seed";
        char seed[] = "12345";
        char* arguments[] = {program, option, seed};
        const cybernet::RunOptionsParseResult result =
            cybernet::parseRunOptions(3, arguments);

        assert(result.valid());
        assert(result.options.seed == 12345U);
    }

    {
        char program[] = "cybernet_sim";
        char option[] = "--seed=67890";
        char* arguments[] = {program, option};
        const cybernet::RunOptionsParseResult result =
            cybernet::parseRunOptions(2, arguments);

        assert(result.valid());
        assert(result.options.seed == 67890U);
    }

    {
        char program[] = "cybernet_sim";
        char frameOption[] = "--frame-interval=250";
        char maximumOption[] = "--max-world-frames";
        char maximumValue[] = "50";
        char* arguments[] = {
            program,
            frameOption,
            maximumOption,
            maximumValue
        };
        const cybernet::RunOptionsParseResult result =
            cybernet::parseRunOptions(4, arguments);

        assert(result.valid());
        assert(result.options.worldFrameIntervalTicks == 250U);
        assert(result.options.maximumWorldFrames == 50U);
    }

    {
        char program[] = "cybernet_sim";
        char option[] = "--max-lineage-events=750";
        char* arguments[] = {program, option};
        const cybernet::RunOptionsParseResult result =
            cybernet::parseRunOptions(2, arguments);

        assert(result.valid());
        assert(result.options.maximumLineageEvents == 750U);
    }

    {
        char program[] = "cybernet_sim";
        char benchmarkOption[] = "--benchmark-ticks=1000";
        char traceOption[] = "--trace";
        char* arguments[] = {program, benchmarkOption, traceOption};
        const cybernet::RunOptionsParseResult result =
            cybernet::parseRunOptions(3, arguments);

        assert(result.valid());
        assert(result.options.headless);
        assert(result.options.trace);
        assert(result.options.benchmarkTicks == 1000U);
    }

    {
        char program[] = "cybernet_sim";
        char archiveOption[] = "--archive-dir=E:\\CyberNetArchive";
        char* arguments[] = {program, archiveOption};
        const cybernet::RunOptionsParseResult result =
            cybernet::parseRunOptions(2, arguments);

        assert(result.valid());
        assert(result.options.archiveDirectory == "E:\\CyberNetArchive");
    }

    {
        char program[] = "cybernet_sim";
        char workersOption[] = "--workers=2";
        char* arguments[] = {program, workersOption};
        const cybernet::RunOptionsParseResult result =
            cybernet::parseRunOptions(2, arguments);

        assert(result.valid());
        assert(result.options.workerCount == 2U);
    }

    {
        char program[] = "cybernet_sim";
        char option[] = "--seed";
        char* arguments[] = {program, option};
        const cybernet::RunOptionsParseResult result =
            cybernet::parseRunOptions(2, arguments);

        assert(!result.valid());
    }

    {
        char program[] = "cybernet_sim";
        char traceOption[] = "--trace";
        char* arguments[] = {program, traceOption};
        const cybernet::RunOptionsParseResult result =
            cybernet::parseRunOptions(2, arguments);

        assert(!result.valid());
    }

    {
        char program[] = "cybernet_sim";
        char headlessOption[] = "--headless";
        char* arguments[] = {program, headlessOption};
        const cybernet::RunOptionsParseResult result =
            cybernet::parseRunOptions(2, arguments);

        assert(!result.valid());
    }

    {
        char program[] = "cybernet_sim";
        char option[] = "--frame-interval=0";
        char* arguments[] = {program, option};
        const cybernet::RunOptionsParseResult result =
            cybernet::parseRunOptions(2, arguments);

        assert(!result.valid());
    }

    {
        char program[] = "cybernet_sim";
        char option[] = "--seed=not-a-number";
        char* arguments[] = {program, option};
        const cybernet::RunOptionsParseResult result =
            cybernet::parseRunOptions(2, arguments);

        assert(!result.valid());
    }

    std::cout << "Run options tests passed.\n";
    return 0;
}

