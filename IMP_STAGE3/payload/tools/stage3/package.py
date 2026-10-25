"""Create a reviewed overlay against an archived, hash-verified repository baseline."""
import argparse,base64,hashlib,json,shutil,tarfile,zipfile,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def digest(b):
 try:b.decode('utf-8');b=b.replace(b'\r\n',b'\n')
 except UnicodeDecodeError:pass
 return hashlib.sha256(b).hexdigest()
def build(baseline,output):
 output.mkdir(parents=True,exist_ok=True)
 if (output/'payload').exists():shutil.rmtree(output/'payload')
 originals={}
 with tarfile.open(baseline) as t:
  for m in t.getmembers():
   if m.isfile():originals[str(Path(m.name).relative_to('source'))]=t.extractfile(m).read()
 files=[];embedded=[]
 for p in sorted(ROOT.rglob('*')):
  rel=p.relative_to(ROOT)
  if not p.is_file() or any(x in rel.parts for x in ('build','results','dist','archives','__pycache__','.git')):continue
  name=rel.as_posix();data=p.read_bytes();old=originals.get(name)
  if old==data:continue
  if name.startswith('planet/src/server/') and name.endswith('LiveTransportConfig.lua'):continue
  target=digest(data);base=digest(old) if old is not None else None
  dest=output/'payload'/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
  files.append({'path':name,'base':base,'target':target})
  embedded.append({'path':name,'accepted':[base],'target':target,'content':base64.b64encode(data).decode()})
 manifest={'release':'IMP Stage 3 trophic web stage3-1 2026-10-24','baseline':'IMP_PDNARNA behavior update pdnarna-4 with Windows migration fix','files':files}
 (output/'manifest.json').write_text(json.dumps(manifest,indent=2))
 for name in ('Install-Stage3.ps1','Restore-Stage3.ps1'):shutil.copy2(ROOT/'tools/stage3'/name,output/name)
 for name in ('START_HERE.md','MODEL.md','VALIDATION.md','IMPLEMENTATION_PLAN.md'):
  src=ROOT/'docs/stage3'/name
  if src.exists():shutil.copy2(src,output/name)
 release={'release':manifest['release'],'baselines':[manifest['baseline']],'files':embedded}
 payload=base64.b64encode(zlib.compress(json.dumps(release,separators=(',',':')).encode(),9)).decode()
 installer=(ROOT/'tools/stage3/source_update.py').read_text().replace("PAYLOAD = ''",'PAYLOAD = '+repr(payload),1)
 installer=installer.replace('tools/run_planet.py','scripts/Build.ps1').replace('combined lake observation update','IMP Stage 3 trophic web').replace('apply_ci_lake_complete.py','Install-Stage3.py')
 (output/'Install-Stage3.py').write_text(installer)
 print('Packaged',len(files),'changed/new source files')
 return manifest
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--baseline',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();build(a.baseline,a.output)
