#!/usr/bin/env python3
"""Validate a bounded CI JSONL recording and create Rojo ModuleScripts. Python 3.10+."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import tempfile
import importlib.util
_spec = importlib.util.spec_from_file_location('ci_geometry_contract', Path(__file__).with_name('generate_geometry.py'))
_geometry_module = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_geometry_module)
validate_geometry = _geometry_module.validate

MAX_BYTES = 8 * 1024 * 1024
MAX_FRAME_BYTES = 2 * 1024 * 1024
MAX_INDEX_BYTES = 64 * 1024
MAX_FRAMES = 120
MAX_AGENTS = 10000
COLUMNS = ['id','species','x','y','z','vx','vy','vz','energy','ageTicks','parentId','generation','birthTick']
MODEL = 'legacy-linear-depth40-global-vision-v1'

def need(condition, message):
    if not condition:
        raise ValueError(message)

def number(value):
    return type(value) in (int, float) and math.isfinite(value)

def integer(value, minimum=0, maximum=4294967295):
    return number(value) and minimum <= value <= maximum and value == int(value)

def no_duplicates(pairs):
    result = {}
    for key, value in pairs:
        need(key not in result, 'Duplicate JSON key: ' + key)
        result[key] = value
    return result

def validate(path):
    need(path.stat().st_size <= MAX_BYTES, 'Recording exceeds 8 MiB budget')
    raw = path.read_bytes()
    lines = raw.decode('utf-8').splitlines()
    need(3 <= len(lines) <= MAX_FRAMES + 2, 'Expected header, 1-120 complete frames, and footer')
    need(all(len(line.encode()) <= MAX_FRAME_BYTES for line in lines), 'Oversized line')
    records = [json.loads(line, object_pairs_hook=no_duplicates) for line in lines]
    header, *frames, footer = records
    need(isinstance(header, dict) and header.get('type') == 'header' and integer(header.get('schemaVersion'),1,3), 'Unsupported schema')
    need(isinstance(header.get('runId'), str) and re.fullmatch(r'[A-Za-z0-9_-]{1,100}', header['runId']), 'Invalid run ID')
    need(isinstance(header.get('seed'), str) and re.fullmatch(r'[0-9]{1,20}', header['seed']) and int(header['seed']) <= 2**64-1, 'Invalid seed')
    need(header.get('bounds') == [100,100,60], 'This viewer supports the 100 x 100 x 60 basin only')
    for key, expected in dict(coordinates='xyz-z-up',positionUnit='simulation-unit',velocityUnit='simulation-unit/tick',energyUnit='model-energy',timeUnit='tick',sampleStage='end-of-tick').items():
        need(header.get(key) == expected, 'Unsupported ' + key)
    v2 = header['schemaVersion'] >= 2
    geometry = header.get('geometry')
    if header['schemaVersion'] == 3:
        validate_geometry(geometry,with_hash=True)
    else: need(geometry is None, 'Unexpected geometry on old schema')
    columns = COLUMNS + (['opticalTick','sensorLight','photosyntheticLight','photosyntheticEnergy'] if v2 else [])
    need(header.get('opticalModel') == ('normalized-flat-water-geometry-v3' if geometry is not None else 'normalized-flat-water-v2' if v2 else MODEL), 'Unsupported optical model')
    need(header.get('agentColumns') == columns, 'Wrong row layout')
    if v2:
        need(header.get('opticalStages') == ['pre-movement','post-movement','actual-gain'], 'Wrong optical phases')
        p = header.get('opticalParameters')
        need(isinstance(p,list) and len(p)==7 and all(number(x) for x in p), 'Invalid optical parameters')
        need(all(0<=x<=10 for x in p[:3]) and all(0<=x<=1 for x in p[3:5]) and 1<p[5]<=2 and 0<p[6]<=1, 'Optical parameters outside bounds')
    need(isinstance(header.get('modelVersion'), str) and 0 < len(header['modelVersion']) <= 100, 'Missing model version')
    need(integer(header.get('cycleTicks'), 1) and integer(header.get('intervalTicks'), 1), 'Invalid tick settings')
    need(number(header.get('moonlight')) and 0 <= header['moonlight'] <= 1, 'Invalid moonlight')
    need(isinstance(footer, dict) and footer.get('type') == 'end' and footer.get('runId') == header['runId'], 'Missing completion footer')
    need(integer(footer.get('frames'),1,MAX_FRAMES) and footer.get('frames') == len(frames), 'Frame count mismatch')
    need(footer.get('reason') in ['completed','population-limit','byte-limit','frame-limit','frame-byte-limit'], 'Recording failed; do not import it')
    last_tick = -1
    last_ids, identities, retired = set(), {}, set()
    for sequence, frame in enumerate(frames):
        need(isinstance(frame, dict) and frame.get('type') == 'frame', 'Invalid frame')
        need(frame.get('runId') == header['runId'] and integer(frame.get('sequence'),0,MAX_FRAMES-1) and frame.get('sequence') == sequence and frame.get('complete') is True, 'Incomplete or out-of-order frame')
        tick = frame.get('tick')
        need(integer(tick) and tick > last_tick, 'Ticks must increase')
        if sequence:
            need(tick - last_tick == header['intervalTicks'], 'Unexpected frame interval')
        last_tick = tick
        light = frame.get('light')
        need(isinstance(light, list) and len(light) == 3 and all(number(x) and 0 <= x <= 1 for x in light), 'Invalid light')
        expected = max(0, math.sin(2 * math.pi * (tick % header['cycleTicks']) / header['cycleTicks']))
        need(abs(light[0]-expected) < 2e-5 and abs(light[1]-header['moonlight']) < 2e-5 and abs(light[2]-(light[1]+(1-light[1])*light[0])) < 2e-5, 'Legacy celestial values disagree with tick')
        agents = frame.get('agents')
        need(isinstance(agents, list) and len(agents) <= MAX_AGENTS and integer(frame.get('count'),0,MAX_AGENTS) and frame.get('count') == len(agents), 'Invalid agent count')
        previous_id = 0
        ids = set()
        for row in agents:
            need(isinstance(row, list) and len(row) == len(columns) and all(number(x) for x in row), 'Invalid agent row')
            need(integer(row[0], 1) and row[0] > previous_id, 'IDs must be unique and sorted')
            previous_id = row[0]
            need(integer(row[1], 0, 2), 'Unknown species')
            need(all(0 <= row[2+i] <= header['bounds'][i] for i in range(3)), 'Position outside basin')
            need(row[8] >= 0 and all(integer(row[i]) for i in [9,10,11,12]) and row[12] <= tick, 'Invalid agent energy/age/lineage')
            if v2:
                need(integer(row[13],-1) and row[13] in [-1,tick], 'Stale optical sample')
                need(0<=row[14]<=1 and 0<=row[15]<=1 and row[16]>=0, 'Invalid optical sample')
                need(row[13]!=-1 or row[14:17]==[0,0,0], 'Unsampled agent has optical data')
                need(row[1]==0 or row[16]==0, 'Non-producer gained photosynthetic energy')
            if geometry is not None:
                radius = geometry['bodyRadius']
                need(all(radius-0.00001<=row[2+i]<=header['bounds'][i]-radius+0.00001 for i in range(3)), 'Body outside basin')
                if geometry['version']==2:
                    need(all(row[4]>=a*row[2]+b*row[3]+c+(radius-1e-5)*math.sqrt(1+a*a+b*b) for a,b,c in geometry['terrain']['planes']),'Recorded body intersects terrain')
                for obj in geometry['objects']:
                    if not obj['solid']:continue
                    delta=[row[2+i]-obj['center'][i] for i in range(3)]
                    # Recording decimal round-trip tolerance, below collision skin.
                    inside = sum(x*x for x in delta)<(obj['halfSize'][0]+radius-0.00001)**2 if obj['shape']=='sphere' else all(abs(delta[i])<obj['halfSize'][i]+radius-0.00001 for i in range(3))
                    need(not inside,'Recorded body intersects shared geometry')
            identity = (row[1],row[10],row[11],row[12])
            need(row[0] not in retired and identities.get(row[0], identity) == identity, 'Reused or changed identity')
            identities[row[0]] = identity
            ids.add(row[0])
        retired.update(last_ids - ids)
        last_ids = ids
    return header, frames, footer, hashlib.sha256(raw).hexdigest()

def lua_string(value):
    equals = '='
    while ']' + equals + ']' in value:
        equals += '='
    return '[' + equals + '[' + value + ']' + equals + ']'

def convert(source, destination, replace=False):
    header, frames, footer, digest = validate(source)
    marker = '.ci-recording-generated'
    if destination.exists():
        need(replace, 'Output exists; use --replace only for a generated Recording folder')
        need(not destination.is_symlink() and (destination / marker).is_file(), 'Refusing to replace an unowned directory')
        need(all(p.is_file() and not p.is_symlink() and (p.name in [marker,'Index.lua'] or re.fullmatch(r'Frame_\d{4}\.lua',p.name)) for p in destination.iterdir()), 'Output contains unrelated files')
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix='.ci-recording-', dir=destination.parent))
    try:
        metadata = dict(header, frameTicks=[f['tick'] for f in frames], frameCount=len(frames), sourceSha256=digest, stopReason=footer['reason'])
        need(len(json.dumps(metadata,separators=(',',':')).encode()) <= MAX_INDEX_BYTES, 'Recording index exceeds 64 KiB budget')
        encoded_frames = [json.dumps(frame,separators=(',',':')) for frame in frames]
        need(len(json.dumps(metadata,separators=(',',':')).encode()) + sum(len(x.encode()) for x in encoded_frames) <= MAX_BYTES, 'Converted data exceeds 8 MiB; export a shorter recording')
        (temporary / 'Index.lua').write_text('--!strict\n-- Generated; JSON keeps data separate from executable Lua.\nreturn ' + lua_string(json.dumps(metadata,separators=(',',':'))) + '\n', encoding='utf-8')
        for i, frame in enumerate(encoded_frames):
            (temporary / f'Frame_{i:04}.lua').write_text('--!strict\nreturn ' + lua_string(frame) + '\n', encoding='utf-8')
        (temporary / marker).write_text('CI recording schema 1/2/3\n', encoding='utf-8')
        if destination.exists():
            shutil.rmtree(destination)
        temporary.rename(destination)
    finally:
        if temporary.exists():
            shutil.rmtree(temporary)
    print(f'Converted {len(frames)} complete frames, ticks {frames[0]["tick"]}–{frames[-1]["tick"]}; stop={footer["reason"]}')
    print(f'Output: {destination.resolve()}')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('recording', type=Path)
    parser.add_argument('output', type=Path, help='ci_rbxl/src/shared/Recording')
    parser.add_argument('--replace', action='store_true')
    args = parser.parse_args()
    try:
        convert(args.recording, args.output, args.replace)
    except (ValueError, OSError, UnicodeError, TypeError) as error:
        parser.exit(1, f'Recording rejected: {error}\n')
