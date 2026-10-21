"""Build a self-contained updater from versioned source, accepting known baselines."""
import base64,json,subprocess,zlib,argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--base',action='append',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
from source_update import digest
paths=set(git('diff','--name-only',a.base[0]).decode().splitlines())
paths.update(git('ls-files','--others','--exclude-standard').decode().splitlines())
files=[]
for name in sorted(paths):
 path=ROOT/name
 if not path.is_file():raise ValueError('Deletion unsupported: '+name)
 accepted=[]
 for revision in a.base:
  result=subprocess.run(['git','show',revision+':'+name],cwd=ROOT,capture_output=True)
  accepted.append(digest(result.stdout) if result.returncode==0 else None)
 content=path.read_bytes();target=digest(content)
 if all(value==target for value in accepted):continue
 files.append({'path':name,'accepted':list(dict.fromkeys(accepted)),'target':target,'content':base64.b64encode(content).decode()})
release={'release':'CI lake integrated observation 2026-10-20','files':files,'baselines':a.base}
payload=base64.b64encode(zlib.compress(json.dumps(release,separators=(',',':')).encode(),9)).decode()
template=(ROOT/'tools/source_update.py').read_text().replace("PAYLOAD = ''",'PAYLOAD = '+repr(payload),1)
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(template,encoding='utf-8')
print('Packaged',len(files),'files;',a.output.stat().st_size,'bytes:',a.output)
