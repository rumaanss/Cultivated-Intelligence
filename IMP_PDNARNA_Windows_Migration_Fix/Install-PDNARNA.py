"""Self-contained source updater template. Generated releases embed PAYLOAD below."""
import argparse,base64,hashlib,json,os,sys,tempfile,uuid,zlib
from datetime import datetime,timezone
from pathlib import Path
PAYLOAD = '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'

def digest(data):
 return hashlib.sha256(data.replace(b'\r\n',b'\n')).hexdigest()

def safe(root,name):
 p=Path(name)
 if p.is_absolute() or '..' in p.parts or not p.parts:raise ValueError('Unsafe update path: '+name)
 result=(root/p).resolve()
 if not result.is_relative_to(root):raise ValueError('Path escapes project: '+name)
 return result

def put(path,data):
 path.parent.mkdir(parents=True,exist_ok=True)
 fd,name=tempfile.mkstemp(prefix='.ci-source-',dir=path.parent)
 try:
  with os.fdopen(fd,'wb')as stream:stream.write(data);stream.flush();os.fsync(stream.fileno())
  os.replace(name,path)
 finally:
  if os.path.exists(name):os.unlink(name)

def apply(root,release,check=False):
 changes=[];conflicts=[]
 for item in release['files']:
  path=safe(root,item['path']);old=path.read_bytes() if path.exists() else None
  actual=digest(old) if old is not None else None
  new=base64.b64decode(item['content'],validate=True)
  if digest(new)!=item['target']:raise ValueError('Corrupt update: '+item['path'])
  if actual==item['target']:continue
  if actual not in item['accepted']:conflicts.append(item['path']);continue
  changes.append((item,path,old,new))
 if conflicts:raise ValueError('No files changed. Conflicting local edits:\n  '+'\n  '.join(conflicts))
 if not changes:print('Already up to date.');return None
 if check:print('Preflight passed:',len(changes),'source files ready. No files changed.');return None
 stamp=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'-'+uuid.uuid4().hex[:8]
 backup=root/'archives/source-updates'/stamp;backup.mkdir(parents=True)
 manifest={'release':release['release'],'files':[]}
 for item,path,old,new in changes:
  if old is not None:put(backup/'original'/item['path'],old)
  manifest['files'].append({'path':item['path'],'existed':old is not None,'original':digest(old) if old is not None else None,'target':item['target']})
 put(backup/'manifest.json',json.dumps(manifest,indent=2).encode())
 written=[]
 try:
  for item,path,old,new in changes:put(path,new);written.append((path,old))
 except BaseException:
  for path,old in reversed(written):
   if old is None:path.unlink(missing_ok=True)
   else:put(path,old)
  raise
 print('Applied',release['release'],'to',len(changes),'source files.')
 print('Backup:',backup.relative_to(root))
 print('Runtime, credentials, checkpoints and Roblox place files were not modified.')
 return backup

def rollback(root,backup):
 backup=backup.resolve()
 if not backup.is_relative_to(root/'archives/source-updates'):raise ValueError('Choose a backup inside archives/source-updates')
 manifest=json.loads((backup/'manifest.json').read_text());changes=[]
 for item in manifest['files']:
  path=safe(root,item['path']);old=path.read_bytes() if path.exists() else None
  actual=digest(old) if old is not None else None
  if actual==item['original']:continue
  if actual!=item['target']:raise ValueError('No files changed. Edited since update: '+item['path'])
  data=(safe(backup/'original',item['path'])).read_bytes() if item['existed'] else None
  if (digest(data) if data is not None else None)!=item['original']:raise ValueError('Backup integrity failed: '+item['path'])
  changes.append((path,old,data))
 done=[]
 try:
  for path,old,data in changes:
   if data is None:path.unlink(missing_ok=True)
   else:put(path,data)
   done.append((path,old))
 except BaseException:
  for path,old in reversed(done):
   if old is None:path.unlink(missing_ok=True)
   else:put(path,old)
  raise
 print('Restored',len(changes),'source files. Rebuild and restart the services.')

def main():
 p=argparse.ArgumentParser(description='Install the PDNARNA Windows migration fixture fix; preserves your ecosystem.')
 p.add_argument('--check',action='store_true');p.add_argument('--root',type=Path,default=Path.cwd());p.add_argument('--rollback',type=Path)
 args=p.parse_args();root=args.root.resolve()
 for name in ['planet/default.project.json','simulation/CMakeLists.txt','scripts/Build.ps1']:
  if not(root/name).is_file():p.error('Run this command from the CultivatedIntelligence project root.')
 try:
  if args.rollback:rollback(root,args.rollback if args.rollback.is_absolute() else root/args.rollback)
  else:
   if not PAYLOAD:raise ValueError('Use the generated Install-PDNARNA.py release.')
   apply(root,json.loads(zlib.decompress(base64.b64decode(PAYLOAD))),args.check)
 except (ValueError,OSError)as error:print('Update stopped:',error,file=sys.stderr);return 1
 return 0
if __name__=='__main__':sys.exit(main())
