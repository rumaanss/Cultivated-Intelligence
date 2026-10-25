"""Benchmark isolated native kernels from copies of validated checkpoints.

Run only after the ecology jobs finish. HTTP, encoding, validation, persistence,
and Roblox rendering are outside the C++ per-step timer. This does not measure FPS.
"""
import argparse
import csv
import hashlib
import json
import platform
import statistics
import subprocess
import tempfile
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--executable', type=Path, required=True)
p.add_argument('--results', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--ticks', type=int, default=2000)
p.add_argument('--repeats', type=int, default=3)
a = p.parse_args()
if a.ticks < 1 or a.repeats < 1:
    p.error('ticks and repeats must be positive')

cases = []
for name in ('42-fixed', '42-mutating'):
    source = a.results / (name + '.json')
    data = source.read_bytes()
    state = json.loads(json.loads(data)['payload'])
    timings = []
    populations = []
    with tempfile.TemporaryDirectory(prefix='pdnarna-benchmark-') as temporary:
        checkpoint = Path(temporary) / 'benchmark.json'
        for _ in range(a.repeats):
            checkpoint.write_bytes(data)
            command = [str(a.executable.resolve()), str(state['seed']),
                       str(state['tick'] + a.ticks), str(checkpoint),
                       str(state['config']['mutationProbability']), '-1']
            result = subprocess.run(command, check=True, capture_output=True, text=True)
            row = next(csv.reader([result.stdout.strip()]))
            assert len(row) == 14 and int(row[2]) == state['tick'] + a.ticks
            timings.append(float(row[13]))
            populations.append(int(row[3]))
    assert source.read_bytes() == data, 'Benchmark changed its source checkpoint'
    cases.append({'name': name, 'sourceSha256': hashlib.sha256(data).hexdigest(),
                  'startTick': state['tick'], 'startPopulation': len(state['colonies']),
                  'endPopulations': populations, 'p95StepMilliseconds': timings,
                  'medianOfRepeatedP95Milliseconds': statistics.median(timings)})

report = {'platform': platform.platform(), 'ticksPerRepeat': a.ticks,
          'repeats': a.repeats, 'executableSha256': hashlib.sha256(a.executable.read_bytes()).hexdigest(),
          'scope': 'Physiology::step wall time including environment; excludes checkpoint, validation, HTTP, serialization and Roblox. Sequential repeats; no application warm-up ticks. Shared-host scheduling can still affect timings.',
          'cases': cases}
a.output.parent.mkdir(parents=True, exist_ok=True)
a.output.write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
