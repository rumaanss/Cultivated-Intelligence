import json,tempfile,time,unittest,threading,urllib.request,urllib.error
from pathlib import Path
from planet_channel import PlanetChannel,validate_habitat

# north cross up must equal east, consistent with the planet chart.
def fixture():
 return {'schema':1,'id':'reference-island-lake','dataset':'test-dataset','unit':'stud','coordinates':'east-north-radial-altitude','biologyEnabled':False,
 'frame':{'center':[0,0,0],'radius':4096,'up':[0,1,0],'east':[1,0,0],'north':[0,0,-1]},
 'water':{'grid':4,'cells':[[x,y,-104 if x==0 and y==0 else 4] for y in range(-1,2) for x in range(-1,2)]},
 'land':{'origin':[16,16],'spacing':16,'nx':1,'ny':1,'cells':[[8,.98,True]]}}
class PlanetTests(unittest.TestCase):
 def test_validation(self):
  validate_habitat(fixture())
  cases=[]
  q=fixture();q['water']['cells'][0][2]=-1;cases.append(q)
  q=fixture();q['water']['cells'].append(q['water']['cells'][0]);cases.append(q)
  q=fixture();q['frame']['east']=[0,1,0];cases.append(q)
  q=fixture();q['land']['cells'][0][0]=-1;cases.append(q)
  q=fixture();q['land']['origin']=[500,500];cases.append(q)
  q=fixture();q['water']['cells'][4][2]=float('nan');cases.append(q)
  q=fixture();q['biologyEnabled']=True;cases.append(q)
  for q in cases:
   with self.assertRaises(ValueError):validate_habitat(q)
 def test_immutable_export(self):
  with tempfile.TemporaryDirectory() as d:
   p=PlanetChannel(d);a=p.habitat(fixture());self.assertEqual(a,p.habitat(fixture()))
   q=fixture();q['land']['cells'][0][0]=9
   with self.assertRaises(ValueError):p.habitat(q)
   self.assertFalse((Path(d)/'snapshot.json').exists())
  with tempfile.TemporaryDirectory() as d:
   (Path(d)/'snapshot.json').write_text('{}')
   with self.assertRaises(ValueError):PlanetChannel(d).habitat(fixture())
 def test_telemetry_restart_stale_and_no_owner(self):
  with tempfile.TemporaryDirectory() as d:
   p=PlanetChannel(d);path=Path(d)/'snapshot.json'
   self.assertEqual(p.telemetry({'schema':1})['state'],'No publisher')
   s={'manifest':{'runId':'r'},'boot':'a','tick':10,'state':'running'}
   path.write_text(json.dumps(s));self.assertNotIn('SimulationTicksPerSecond',p.telemetry({'schema':1}))
   p.sample=('r','a'),10,time.monotonic()-2
   s['tick']=30;path.write_text(json.dumps(s));before=path.read_bytes();r=p.telemetry({'schema':1})
   self.assertAlmostEqual(r['SimulationTicksPerSecond'],10,delta=.2);self.assertEqual(before,path.read_bytes())
   s['boot']='b';s['tick']=0;path.write_text(json.dumps(s));self.assertNotIn('SimulationTicksPerSecond',p.telemetry({'schema':1}))
   import os
   os.utime(path,(time.time()-10,time.time()-10));r=p.telemetry({'schema':1})
   self.assertEqual(r['state'],'Stale');self.assertNotIn('SimulationTicksPerSecond',r)
   self.assertFalse((Path(d)/'input.json').exists())
 def test_authenticated_http(self):
  from relay import World,Server
  with tempfile.TemporaryDirectory() as d:
   world=World(d);server=Server(('127.0.0.1',0),world);thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
   try:
    def post(endpoint,body,token):
     request=urllib.request.Request('http://127.0.0.1:'+str(server.server_port)+endpoint,data=json.dumps(body).encode(),headers={'Content-Type':'application/json','X-CI-Token':token})
     with urllib.request.urlopen(request,timeout=3) as result:return json.load(result)
    with self.assertRaises(urllib.error.HTTPError) as e:post('/habitat',fixture(),'wrong')
    self.assertEqual(e.exception.code,401)
    self.assertFalse(post('/habitat',fixture(),world.token)['biologyEnabled'])
    self.assertEqual(post('/telemetry',{'schema':1},world.token)['state'],'No publisher')
    self.assertIsNone(world.session)
   finally:server.shutdown();server.server_close();thread.join();world.ledger.db.close()
if __name__=='__main__':unittest.main()
