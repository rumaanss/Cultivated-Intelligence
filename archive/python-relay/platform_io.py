"""Shared local filesystem primitives, including Windows replacement semantics."""
import os,time,ctypes
from pathlib import Path

def replace(temp,path):
 if os.name!='nt':
  os.replace(temp,path)
  fd=os.open(path.parent,os.O_RDONLY)
  try:os.fsync(fd)
  finally:os.close(fd)
  return
 api=ctypes.WinDLL('kernel32',use_last_error=True)
 api.ReplaceFileW.argtypes=[ctypes.c_wchar_p,ctypes.c_wchar_p,ctypes.c_wchar_p,ctypes.c_uint32,ctypes.c_void_p,ctypes.c_void_p]
 api.ReplaceFileW.restype=ctypes.c_int
 api.MoveFileExW.argtypes=[ctypes.c_wchar_p,ctypes.c_wchar_p,ctypes.c_uint32];api.MoveFileExW.restype=ctypes.c_int
 end=time.monotonic()+2;attempt=0
 while True:
  if api.ReplaceFileW(str(path),str(temp),None,0,None,None):return
  error=ctypes.get_last_error()
  if error==2:
   if api.MoveFileExW(str(temp),str(path),8):return
   error=ctypes.get_last_error()
  if error not in (5,32,33) or time.monotonic()>=end:raise OSError(error,'Windows atomic replacement denied: '+str(path))
  time.sleep(min(.005+attempt*.001,.02));attempt+=1

class ProcessLock:
 def __init__(self,path):
  self.file=open(path,'a+b');self.file.seek(0)
  if os.name=='nt':
   import msvcrt
   if os.fstat(self.file.fileno()).st_size==0:self.file.write(b'0');self.file.flush()
   self.file.seek(0)
   try:msvcrt.locking(self.file.fileno(),msvcrt.LK_NBLCK,1)
   except OSError:self.file.close();raise RuntimeError('Another relay owns this world directory')
  else:
   import fcntl
   try:fcntl.flock(self.file.fileno(),fcntl.LOCK_EX|fcntl.LOCK_NB)
   except OSError:self.file.close();raise RuntimeError('Another relay owns this world directory')
 def close(self):self.file.close()
