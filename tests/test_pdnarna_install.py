"""Exercise actual Python and PowerShell installers against isolated baseline copies."""
import argparse,hashlib,json,subprocess,tarfile,tempfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--package',type=Path,required=True);p.add_argument('--baseline',type=Path,required=True);p.add_argument('--pwsh',type=Path,required=True);a=p.parse_args();a.package=a.package.resolve();a.pwsh=a.pwsh.resolve()
def sha(b):return hashlib.sha256(b.replace(b'\r\n',b'\n')).hexdigest()
manifest=json.loads((a.package/'manifest.json').read_text())
def run(args,ok=True):
 r=subprocess.run(args,capture_output=True,text=True,timeout=60);assert (r.returncode==0)==ok,r.stdout+r.stderr;return r.stdout
def state(root):return {str(p.relative_to(root)):sha(p.read_bytes()) for p in root.rglob('*') if p.is_file() and 'archives' not in p.relative_to(root).parts}
with tempfile.TemporaryDirectory() as tmp:
 for mode in ('python','powershell'):
  dest=Path(tmp)/mode;dest.mkdir()
  with tarfile.open(a.baseline) as t:t.extractall(dest,filter='data')
  root=dest/'source';original=state(root)
  if mode=='powershell':install=[str(a.pwsh),'-NoProfile','-File',str(a.package/'Install-PDNARNA.ps1'),'-Root',str(root)];check=['-Check']
  else:install=['python3',str(a.package/'Install-PDNARNA.py'),'--root',str(root)];check=['--check']
  run(install+check);assert state(root)==original,'preflight wrote files'
  # A conflicting existing edit must prevent every payload change.
  item=next(x for x in manifest['files'] if x['base']);conflict=root/item['path'];saved=conflict.read_bytes();conflict.write_bytes(saved+b'\nconflict\n');before=state(root)
  run(install,False);assert state(root)==before,'conflict caused partial installation';conflict.write_bytes(saved)
  # Validate line-ending normalization on a real edited payload file.
  conflict.write_bytes(saved.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'))
  run(install)
  for item in manifest['files']:assert sha((root/item['path']).read_bytes())==item['target']
  installed=state(root);backup=next((root/'archives'/('pdnarna' if mode=='powershell' else 'source-updates')).iterdir());run(install);assert state(root)==installed
  if mode=='powershell':restore=[str(a.pwsh),'-NoProfile','-File',str(a.package/'Restore-PDNARNA.ps1'),'-Root',str(root),'-Backup',str(backup)]
  else:restore=install+['--rollback',str(backup)]
  saved=conflict.read_bytes();conflict.write_bytes(saved+b'\npost-install edit\n');before=state(root);run(restore,False);assert state(root)==before;conflict.write_bytes(saved)
  run(restore);assert state(root)==original,'rollback differed from baseline'
  run(restore);assert state(root)==original,'repeated rollback altered baseline'
  print('PASS',mode,'preflight, atomic conflict refusal, CRLF acceptance, installation, repeat, edited-file rollback refusal and complete rollback')
