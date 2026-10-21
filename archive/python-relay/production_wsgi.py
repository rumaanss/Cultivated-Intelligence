"""Run with Waitress on loopback behind a TLS reverse proxy. One world per process."""
import os,json,secrets,threading,time,sqlite3
from pathlib import Path
from relay import World,MAX_BYTES,unique_object,exchange_bundle
from platform_io import ProcessLock
from plant_channel import PlantChannel
from planet_channel import PlanetChannel
directory=Path(os.environ.get('CI_LIVE_DIRECTORY','live/state'));directory.mkdir(parents=True,exist_ok=True)
relay_lock=ProcessLock(directory/'relay.lock')
world=World(directory)
plants=PlantChannel(directory)
planet=PlanetChannel(directory)
secret=os.environ.get('CI_BRIDGE_TOKEN','')
if len(secret)<32:raise RuntimeError('Set a world-specific CI_BRIDGE_TOKEN of at least 32 characters')
world.token=secret
slots=threading.BoundedSemaphore(4)
def application(environ,start_response):
 status='200 OK';value={}
 try:
  if environ.get('REQUEST_METHOD')!='POST' or environ.get('PATH_INFO') not in ('/exchange','/plants','/plant-surface','/habitat','/telemetry'):status='404 Not Found';value={'error':'not found'}
  elif not secrets.compare_digest(environ.get('HTTP_X_CI_TOKEN',''),secret):status='401 Unauthorized';value={'error':'unauthorized'}
  elif not slots.acquire(False):status='503 Service Unavailable';value={'error':'busy'}
  else:
   try:
    n=int(environ.get('CONTENT_LENGTH','0'))
    if not 0<n<=MAX_BYTES:raise ValueError('body limit')
    raw=environ['wsgi.input'].read(n)
    if len(raw)!=n:raise ValueError('incomplete body')
    q=json.loads(raw,object_pairs_hook=unique_object,parse_constant=lambda _:(_ for _ in ()).throw(ValueError('non-finite JSON')))
    value=exchange_bundle(world,plants,q) if environ['PATH_INFO']=='/exchange' else plants.exchange(q) if environ['PATH_INFO']=='/plants' else planet.habitat(q) if environ['PATH_INFO']=='/habitat' else planet.telemetry(q) if environ['PATH_INFO']=='/telemetry' else plants.surface(q)
   finally:slots.release()
 except (ValueError,TypeError,KeyError,RecursionError):status='409 Conflict';value={'error':'invalid request or ownership conflict'}
 except (OSError,sqlite3.Error):status='503 Service Unavailable';value={'error':'storage unavailable'}
 data=json.dumps(value,separators=(',',':'),allow_nan=False).encode()
 start_response(status,[('Content-Type','application/json'),('Content-Length',str(len(data))),('Cache-Control','no-store'),('X-Content-Type-Options','nosniff')]);return [data]
