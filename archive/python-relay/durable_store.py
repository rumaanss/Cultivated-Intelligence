"""Crash-safe relay ledger. Keys are run/session/event sequence, never sequence alone."""
import sqlite3,json,hashlib,time
class Ledger:
 def __init__(self,path):
  self.db=sqlite3.connect(path,timeout=2,check_same_thread=False)
  self.db.execute('PRAGMA journal_mode=WAL');self.db.execute('PRAGMA synchronous=FULL');self.db.execute('PRAGMA max_page_count=32768');self.db.execute('PRAGMA journal_size_limit=16777216')
  self.db.execute('CREATE TABLE IF NOT EXISTS events(run TEXT,session TEXT,seq INTEGER,payload TEXT,PRIMARY KEY(run,session,seq))')
  self.db.execute('CREATE TABLE IF NOT EXISTS leases(run TEXT PRIMARY KEY,session TEXT,epoch INTEGER,seen REAL)')
  self.db.execute('CREATE TABLE IF NOT EXISTS requests(run TEXT,session TEXT,batch INTEGER,hash TEXT,PRIMARY KEY(run,session,batch))')
  self.db.commit()
 def lease(self,run,session):
  now=time.time()
  with self.db:
   old=self.db.execute('SELECT session,epoch,seen FROM leases WHERE run=?',(run,)).fetchone()
   if old and old[0]!=session:raise ValueError('owner conflict: explicit takeover required; stop old Roblox server first')
   if old and now-old[2]<10:return old[1]
   epoch=old[1] if old else 1
   self.db.execute('INSERT OR REPLACE INTO leases VALUES(?,?,?,?)',(run,session,epoch,now))
  return epoch
 def takeover(self,run):
  with self.db:
   old=self.db.execute('SELECT epoch FROM leases WHERE run=?',(run,)).fetchone()
   epoch=(old[0] if old else 0)+1
   self.db.execute('INSERT OR REPLACE INTO leases VALUES(?,?,?,?)',(run,'',epoch,time.time()))
  return epoch
 def bind(self,run,session):
  old=self.db.execute('SELECT session,epoch FROM leases WHERE run=?',(run,)).fetchone()
  if old and old[0]=='':
   with self.db:self.db.execute('UPDATE leases SET session=?,seen=? WHERE run=?',(session,time.time(),run))
  return self.lease(run,session)
 def check_request(self,run,session,batch,q):
  digest=hashlib.sha256(json.dumps(q,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()
  old=self.db.execute('SELECT hash FROM requests WHERE run=? AND session=? AND batch=?',(run,session,batch)).fetchone()
  if old and old[0]!=digest:raise ValueError('batch identity reused with different payload')
  return digest
 def record(self,run,session,batch,q,events,fingerprint=None):
  if fingerprint is None:fingerprint=hashlib.sha256(json.dumps(q,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()
  with self.db:
   old=self.db.execute('SELECT hash FROM requests WHERE run=? AND session=? AND batch=?',(run,session,batch)).fetchone()
   if old and old[0]!=fingerprint:raise ValueError('batch identity reused with different payload')
   for event in events:
    payload=json.dumps(event,separators=(',',':'))
    old=self.db.execute('SELECT payload FROM events WHERE run=? AND session=? AND seq=?',(run,session,event[0])).fetchone()
    if old and old[0]!=payload:raise ValueError('event identity reused with different payload')
    self.db.execute('INSERT OR IGNORE INTO events VALUES(?,?,?,?)',(run,session,event[0],payload))
   self.db.execute('INSERT OR IGNORE INTO requests VALUES(?,?,?,?)',(run,session,batch,fingerprint))
   # Event fingerprints retained; request retry window bounded. Older batches rejected by relay.
   self.db.execute('DELETE FROM requests WHERE run=? AND session=? AND batch<?',(run,session,max(0,batch-1024)))
 def pending(self,run,session,ack):
  return {r[0]:json.loads(r[1]) for r in self.db.execute('SELECT seq,payload FROM events WHERE run=? AND session=? AND seq>? ORDER BY seq',(run,session,ack))}
