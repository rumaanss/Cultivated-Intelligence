"""Reject legacy/mismatched publishers before granting relay ownership."""
import copy,json,tempfile,unittest
from unittest.mock import patch
import planet_channel
from pathlib import Path
from relay import World
ROOT=Path(__file__).resolve().parents[3]
class Binding(unittest.TestCase):
 def test_identity_gate(self):
  with tempfile.TemporaryDirectory() as directory:
   path=Path(directory)
   habitat=json.loads((ROOT/'contracts/planet_habitat.json').read_text())
   (path/'planet_habitat.json').write_text(json.dumps(habitat))
   geometry=json.loads((ROOT/'contracts/planet_geometry.json').read_text())
   snapshot=dict(protocol=1,state='running',manifest=dict(runId='binding-test',schemaVersion=3,geometry=geometry),sequence=1,tick=1,ack=0,session='',boot='test',agents=[])
   world=World(path)
   try:
    (path/'snapshot.json').write_text(json.dumps(snapshot))
    with patch('planet_channel.validate_habitat',wraps=planet_channel.validate_habitat) as validate:
     for _ in range(5):world.stamp=None;self.assertEqual(world.load()['tick'],1)
     self.assertEqual(validate.call_count,1,'Immutable habitat must not be revalidated per snapshot')
     changed=copy.deepcopy(habitat);changed['id']='different-habitat';(path/'planet_habitat.json').write_text(json.dumps(changed));world.stamp=None
     with self.assertRaises(ValueError):world.load()
     self.assertEqual(validate.call_count,2,'Changed habitat must invalidate validation cache')
    (path/'planet_habitat.json').write_text(json.dumps(habitat))
    for version,digest in [(3,geometry['sha256']),(4,'0'*64)]:
     bad=copy.deepcopy(snapshot);bad['manifest']['geometry']['version']=version;bad['manifest']['geometry']['sha256']=digest
     (path/'snapshot.json').write_text(json.dumps(bad));world.stamp=None
     with self.assertRaises(ValueError):world.load()
    self.assertIsNone(world.session)
   finally:world.ledger.db.close()
 def test_native_observer_only(self):
  with tempfile.TemporaryDirectory() as directory:
   path=Path(directory)
   (path/'planet_habitat.json').write_bytes((ROOT/'contracts/planet_habitat.json').read_bytes())
   geometry=json.loads((ROOT/'contracts/planet_geometry.json').read_text())
   snapshot=dict(protocol=1,state='running',manifest=dict(runId='observer-test',schemaVersion=3,geometry=geometry,motionAuthority='cpp-v1'),sequence=1,tick=1,ack=0,session='',boot='test',agents=[],light=[0,.08,.08])
   (path/'snapshot.json').write_text(json.dumps(snapshot));world=World(path)
   q=dict(protocol=1,run='observer-test',session='observer',boot='test',batch=1,ackBatch=0,poses=[],actors=[],events=[])
   try:
    for lane in ['poses','actors','events']:
     bad=copy.deepcopy(q);bad[lane]=[[1]]
     with self.assertRaisesRegex(ValueError,'observer heartbeats only'):world.exchange(bad)
    result=world.exchange(q);self.assertEqual(result['motions'],[])
    self.assertIn(' 0 0 0\n',(path/'input.txt').read_text())
   finally:world.ledger.db.close()
if __name__=='__main__':unittest.main()
