import sys,pathlib,tempfile,shutil,subprocess,time,json,argparse
parser=argparse.ArgumentParser();parser.add_argument('--executable',type=pathlib.Path,required=True);parser.add_argument('--luau');args=parser.parse_args()
root=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'archive/python-relay'))
from relay import World
from plant_channel import PlantChannel
temporary=tempfile.TemporaryDirectory(prefix='ci-planet-test-');out=pathlib.Path(temporary.name)
shutil.copy(root/'contracts/planet_habitat.json',out/'planet_habitat.json')
log=open(out/'process.log','w')
p=subprocess.Popen([str(args.executable.resolve()),'--headless','--benchmark-ticks','30','--live-dir',str(out),'--island-surface',str(root/'contracts/planet_surface.txt'),'--geometry','lake','--optics','v2','--archive-dir',str(out/'archive')],stdout=log,stderr=subprocess.STDOUT)
world=World(out);plants=PlantChannel(out);deadline=time.monotonic()+45;batch=0;last=None;initial=None
try:
 while time.monotonic()<deadline:
  if (out/'snapshot.json').exists():
   s=world.load();batch+=1
   if initial is None:initial={row[0]:row[2:5] for row in s['agents']}
   q={'protocol':1,'session':'planet-test-owner','run':s['manifest']['runId'],'boot':s['boot'],'batch':batch,'ackBatch':batch-1,'poses':[] if s['manifest'].get('motionAuthority')=='cpp-v1' else [[r[0],*r[2:8]] for r in s['agents']],'actors':[],'events':[]}
   last=world.exchange(q)
  if p.poll() is not None:break
  time.sleep(.18)
 assert p.poll()==0,(p.poll(),(out/'process.log').read_text())
 s=world.load();assert 0<s['tick']<=30 and len(s['agents'])>0
 assert s['manifest'].get('motionAuthority')=='cpp-v1'
 assert any(row[0] in initial and row[2:5]!=initial[row[0]] for row in s['agents']),'C++ native motion did not advance'
 packet=plants.exchange({'schema':1});assert packet['worldTick']==30 and len(packet['upsert'])==96 and packet['run']==s['manifest']['runId']
 assert packet['habitatDigest']==json.loads((root/'contracts/identity.json').read_text())['habitat']['sha256']
 print('PASS real C++ application + relay:',s['tick'],'ticks,',len(s['agents']),'microbes,',len(packet['upsert']),'plants; shared run and habitat')
 # Save native packets for Roblox protocol checks.
 (out/'plant_packet.json').write_text(json.dumps(packet));(out/'validated_snapshot.json').write_text(json.dumps(s))
 if args.luau:subprocess.run([sys.executable,str(root/'tools/verify_planet_packets.py'),'--snapshot',str(out/'validated_snapshot.json'),'--plants',str(out/'plant_packet.json'),'--luau',args.luau],check=True)
finally:
 if p.poll() is None:p.terminate();p.wait()
 world.ledger.db.close();log.close();temporary.cleanup()
