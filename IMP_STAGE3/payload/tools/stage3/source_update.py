"""Self-contained source updater template. Generated releases embed PAYLOAD below."""
import argparse,base64,hashlib,json,os,sys,tempfile,uuid,zlib
from datetime import datetime,timezone
from pathlib import Path
PAYLOAD = ''

def digest(data):
 try:data.decode('utf-8');data=data.replace(b'\r\n',b'\n')
 except UnicodeDecodeError:pass
 return hashlib.sha256(data).hexdigest()

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
 p=argparse.ArgumentParser(description='Install the combined lake observation update; preserves your ecosystem.')
 p.add_argument('--check',action='store_true');p.add_argument('--root',type=Path,default=Path.cwd());p.add_argument('--rollback',type=Path)
 args=p.parse_args();root=args.root.resolve()
 for name in ['planet/default.project.json','simulation/CMakeLists.txt','tools/run_planet.py']:
  if not(root/name).is_file():p.error('Run this command from the CultivatedIntelligence project root.')
 try:
  if args.rollback:rollback(root,args.rollback if args.rollback.is_absolute() else root/args.rollback)
  else:
   if not PAYLOAD:raise ValueError('Use the generated apply_ci_lake_complete.py release.')
   apply(root,json.loads(zlib.decompress(base64.b64decode(PAYLOAD))),args.check)
 except (ValueError,OSError)as error:print('Update stopped:',error,file=sys.stderr);return 1
 return 0
if __name__=='__main__':sys.exit(main())
