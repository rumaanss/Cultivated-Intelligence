"""Offline installer acceptance against the reviewed Git baseline."""
import argparse,hashlib,io,json,subprocess,tarfile,tempfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--package',type=Path,required=True);p.add_argument('--powershell',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1];package=a.package.resolve();ps=a.powershell.resolve()
manifest=json.loads((package/'manifest.json').read_text());baseline=manifest['baseline']
archive=subprocess.check_output(['git','archive',baseline],cwd=root)
def contents(path):
 return {str(p.relative_to(path)):hashlib.sha256(p.read_bytes()).hexdigest() for p in path.rglob('*') if p.is_file() and 'archives' not in p.relative_to(path).parts}
def invoke(script,dest,*extra,ok=True):
 r=subprocess.run([str(ps),'-NoProfile','-File',str(package/script),'-Root',str(dest),*map(str,extra)],capture_output=True,text=True)
 assert (r.returncode==0)==ok,r.stdout+r.stderr
 return r.stdout
with tempfile.TemporaryDirectory(prefix='ci-inspection-install-') as tmp:
 for variant in ['baseline','grounded','conflict']:
  dest=Path(tmp)/variant;dest.mkdir()
  with tarfile.open(fileobj=io.BytesIO(archive)) as t:t.extractall(dest,filter='data')
  if variant=='grounded':
   patch=root.parent/'Stage3_Algae_Grounding.patch'
   subprocess.run(['git','apply',str(patch)],cwd=dest,check=True)
  if variant=='conflict':
   with (dest/'CMakeLists.txt').open('a')as f:f.write('\n# local edit to preserve\n')
   before=contents(dest);invoke('Install-Inspection.ps1',dest,ok=False);assert contents(dest)==before
   print('PASS conflict refusal without mutation');continue
  before=contents(dest);invoke('Install-Inspection.ps1',dest,'-Check');assert contents(dest)==before
  invoke('Install-Inspection.ps1',dest)
  installed=contents(dest);assert installed!=before
  backups=list((dest/'archives/inspection').iterdir());assert len(backups)==1
  invoke('Install-Inspection.ps1',dest);assert contents(dest)==installed and len(list((dest/'archives/inspection').iterdir()))==1
  invoke('Restore-Inspection.ps1',dest,'-Backup',backups[0]);assert contents(dest)==before
  print('PASS',variant,'preflight, install, repeat install, exact rollback')
