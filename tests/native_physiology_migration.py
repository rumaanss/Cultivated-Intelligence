"""Executable-level migration must not write into the original aquatic runtime."""
import argparse,hashlib,json,socket,subprocess,tempfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--executable',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1]

def replace_rng(checkpoint, rng):
 """Change only the RNG field in a temporary fixture; keep its checksum valid."""
 envelope=json.loads(checkpoint);payload=envelope['payload']
 old=json.dumps(json.loads(payload)['rng']);new=json.dumps(rng)
 assert payload.count(old)==1
 envelope['payload']=payload.replace(old,new,1)
 checksum=1469598103934665603
 for byte in envelope['payload'].encode('utf-8'):
  checksum=((checksum^byte)*1099511628211)&((1<<64)-1)
 envelope['checksum']=str(checksum)
 return json.dumps(envelope,separators=(',',':')).encode('utf-8')

with tempfile.TemporaryDirectory() as tmp:
 tmp=Path(tmp);old=tmp/'legacy';new=tmp/'physiology';rb=tmp/'roblox';(rb/'src/server').mkdir(parents=True);(rb/'default.project.json').write_text('{}')
 for directory in (old,new):directory.mkdir();(directory/'planet_habitat.json').write_bytes((root/'contracts/planet_habitat.json').read_bytes())
 def run(runtime,*args,ok=True):
  with socket.socket() as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
  r=subprocess.run([str(a.executable.resolve()),'--project-root',str(root),'--roblox-root',str(rb),'--live-dir',str(runtime),'--port',str(port),'--seed','42','--unpaced',*args],capture_output=True,text=True,timeout=20)
  assert (r.returncode==0)==ok,r.stdout+r.stderr
  return r
 def hashes(directory):return {str(p.relative_to(directory)):hashlib.sha256(p.read_bytes()).hexdigest() for p in directory.rglob('*') if p.is_file()}
 run(old,'--new-world','--ticks','80');before=hashes(old)
 run(new,'--physiology','--migrate-aquatic',str(old/'aquatic.checkpoint.json'),'--ticks','100')
 assert hashes(old)==before,'migration changed source runtime'
 checkpoint=new/'physiology.checkpoint.json';payload=json.loads(json.loads(checkpoint.read_text())['payload']);assert payload['tick']==100 and payload['model']=='pdnarna-4'
 durable=checkpoint.read_bytes();run(new,'--physiology','--migrate-aquatic',str(old/'aquatic.checkpoint.json'),'--ticks','120',ok=False);assert checkpoint.read_bytes()==durable
 run(old,'--physiology','--new-world','--ticks','100',ok=False);assert hashes(old)==before
 run(new,'--ticks','120',ok=False);assert checkpoint.read_bytes()==durable
 print('PASS explicit migration, untouched original runtime, no repeat migration, bidirectional runtime isolation')

 # Upgrade an actual checkpoint emitted by the previous released executable.
 upgrade=tmp/'upgrade';upgrade.mkdir()
 (upgrade/'planet_habitat.json').write_bytes((root/'contracts/planet_habitat.json').read_bytes())
 original=(root/'tests/fixtures/pdnarna-3-founders.json').read_bytes()
 assert hashlib.sha256(original).hexdigest()==(root/'tests/fixtures/pdnarna-3-founders.json.sha256').read_text().strip()
 # The released fixture was written by libstdc++ (312 MT words + cursor).
 # MSVC serializes 312 words without a cursor. Only this proven unadvanced
 # seed-42 fixture may use the native spelling of the same initial RNG state.
 # Never reseed a running world or relax the production trailing-data check.
 fixture=json.loads(json.loads(original)['payload'])
 assert (fixture['model'],fixture['seed'],fixture['tick'])==('pdnarna-3',42,0)
 words=[42]
 for index in range(1,312):
  previous=words[-1]
  words.append((6364136223846793005*(previous^(previous>>62))+index)&((1<<64)-1))
 assert [int(word) for word in fixture['rng'].split()]==words+[312], 'Fixture RNG has advanced; do not reseed it'
 probe=tmp/'native-initial';probe.mkdir()
 (probe/'planet_habitat.json').write_bytes((root/'contracts/planet_habitat.json').read_bytes())
 run(probe,'--physiology','--new-world','--ticks','0')
 native=json.loads(json.loads((probe/'physiology.checkpoint.json').read_bytes())['payload'])
 assert (native['seed'],native['tick'])==(42,0)
 assert [int(word) for word in native['rng'].split()] in (words,words+[312]), 'Native founders RNG is not the expected unadvanced state'
 # Exercise both platform spellings even when this test runs only on Linux.
 msvc=replace_rng(original,' '.join(map(str,words)))
 assert json.loads(replace_rng(msvc,fixture['rng']))['payload']==json.loads(original)['payload']
 if native['rng']!=fixture['rng']:
  original=replace_rng(original,native['rng'])
  print('Normalized the temporary founders fixture to the native RNG stream format')
 # With a correct envelope checksum, an extra RNG token must still fail.
 bad=tmp/'bad-rng';bad.mkdir()
 (bad/'planet_habitat.json').write_bytes((root/'contracts/planet_habitat.json').read_bytes())
 invalid=replace_rng(original,native['rng']+' 7')
 bad_cp=bad/'physiology.checkpoint.json';bad_cp.write_bytes(invalid)
 rejected=run(bad,'--physiology','--ticks','0',ok=False)
 assert 'Trailing RNG data' in rejected.stdout+rejected.stderr
 assert bad_cp.read_bytes()==invalid
 assert not list(bad.glob('*.backup')), 'Rejected checkpoint must not be migrated'
 cp=upgrade/'physiology.checkpoint.json';cp.write_bytes(original)
 run(upgrade,'--physiology','--ticks','0')
 assert (upgrade/'physiology.checkpoint.json.pdnarna-3.backup').read_bytes()==original
 before=json.loads(json.loads(original)['payload']);after=json.loads(json.loads(cp.read_bytes())['payload'])
 assert after['model']=='pdnarna-4' and after['tick']==before['tick']
 for key in ('rng','cells','air','initial','flux','ancestry','events','detritus'):assert after[key]==before[key],key
 assert len(before['colonies'])==len(after['colonies']) and len(before['genomes'])==len(after['genomes'])
 for oldrow,newrow in zip(before['colonies'],after['colonies']):
  assert oldrow[:11]==newrow[:11] and oldrow[13:15]==newrow[13:15]
  assert newrow[11]==oldrow[11]+[0,0] and newrow[12]==oldrow[12]+[0,0]
 for oldrow,newrow in zip(before['genomes'],after['genomes']):
  assert oldrow[:3]==newrow[:3] and newrow[3]==[copy+[1,1] for copy in oldrow[3]]
 run(upgrade,'--physiology','--ticks','100')
 assert json.loads(json.loads(cp.read_bytes())['payload'])['tick']==100
 assert (upgrade/'physiology.checkpoint.json.pdnarna-3.backup').read_bytes()==original
 # A different existing backup must never be overwritten by a later migration.
 cp.write_bytes(original)
 first=upgrade/'physiology.checkpoint.json.pdnarna-3.backup';first.write_bytes(b'keep different backup')
 run(upgrade,'--physiology','--ticks','0')
 assert first.read_bytes()==b'keep different backup'
 assert (upgrade/'physiology.checkpoint.json.pdnarna-3.1.backup').read_bytes()==original
 print('PASS previous-release checkpoint upgrade: exact pools, genomes, lineage and RNG retained; new machinery starts unpaid; original backup untouched')
