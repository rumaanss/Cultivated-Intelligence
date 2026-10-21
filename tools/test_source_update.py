"""Transactional updater checks, including both released source baselines."""
import argparse,importlib.util,subprocess,tempfile,tarfile,io,base64,zlib,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('installer',type=Path);a=p.parse_args()
spec=importlib.util.spec_from_file_location('installer',a.installer);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
release=json.loads(zlib.decompress(base64.b64decode(module.PAYLOAD)))
repo=Path(__file__).resolve().parents[1]
def unpack(root,revision):
 data=subprocess.check_output(['git','archive',revision],cwd=repo)
 with tarfile.open(fileobj=io.BytesIO(data))as archive:archive.extractall(root,filter='data')
def snapshot(root):return {f['path']:(root/f['path']).read_bytes()if(root/f['path']).exists()else None for f in release['files']}
for revision in release['baselines']:
 with tempfile.TemporaryDirectory()as d:
  root=Path(d);unpack(root,revision);original=snapshot(root)
  module.apply(root,release,True);assert snapshot(root)==original
  backup=module.apply(root,release)
  for item in release['files']:assert module.digest((root/item['path']).read_bytes())==item['target']
  assert module.apply(root,release) is None
  module.rollback(root,backup);assert snapshot(root)==original
  path=next(root/name for name,data in original.items() if data is not None);path.write_bytes(path.read_bytes()+b'\nlocal edit\n');edited=snapshot(root)
  try:module.apply(root,release)
  except ValueError:pass
  else:raise AssertionError('Conflicting edit accepted')
  assert snapshot(root)==edited
print('PASS original and earlier-patch preflight, apply, idempotency, rollback and conflict rejection')
with tempfile.TemporaryDirectory()as d:
 root=Path(d);unpack(root,release['baselines'][0]);original=snapshot(root)
 put=module.put;counter=[0]
 def failure(path,data):
  if not path.is_relative_to(root/'archives'):
   counter[0]+=1
   if counter[0]==min(3,len(release['files'])):raise OSError('Injected interrupted write')
  put(path,data)
 module.put=failure
 try:module.apply(root,release)
 except OSError:pass
 else:raise AssertionError('Fault not triggered')
 finally:module.put=put
 assert snapshot(root)==original
print('PASS interrupted application restores all prior source bytes')
