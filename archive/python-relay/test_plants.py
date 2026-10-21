import json,tempfile,threading,urllib.request,urllib.error,sys
from pathlib import Path
from relay import World,Server
from relay import atomic
sample=json.loads(Path(sys.argv[1]).read_text())
with tempfile.TemporaryDirectory() as tmp:
 world=World(tmp);world.token='test-only-token-with-no-user-credentials'
 atomic(Path(tmp)/'plants.json',json.dumps(sample))
 server=Server(('127.0.0.1',0),world);thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
 def request(path,payload,token=world.token):
  req=urllib.request.Request(f'http://127.0.0.1:{server.server_port}'+path,data=json.dumps(payload).encode(),headers={'Content-Type':'application/json','X-CI-Token':token})
  with urllib.request.urlopen(req,timeout=3) as response:return json.load(response)
 try:
  try:request('/plants',{'schema':1},'incorrect');raise AssertionError('Unauthorized accepted')
  except urllib.error.HTTPError as e:assert e.code==401
  first=request('/plants',{'schema':1});assert first['reset'] and len(first['upsert'])==len(sample['plants'])
  unchanged=request('/plants',{'schema':1,'run':first['run'],'revision':first['revision']});assert not unchanged['reset'] and unchanged['upsert']==[]
  changed=json.loads(json.dumps(sample));changed['revision']+=1;removed=changed['plants'].pop()['id'];changed['plants'][0]['resources'][0]+=.1
  atomic(Path(tmp)/'plants.json',json.dumps(changed))
  delta=request('/plants',{'schema':1,'run':first['run'],'revision':first['revision']});assert delta['removed']==[removed] and len(delta['upsert'])==1 and 'organs' not in delta['upsert'][0]
  reset=request('/plants',{'schema':1,'run':'old-run','revision':0});assert reset['reset']
  surface='CIPLANTSURFACE1 test-export 2 2 0 0 8\n'+('12 8 20 8 1\n'*4)
  assert request('/plant-surface',{'text':surface})['saved']
  assert (Path(tmp)/'plant_surface.txt').read_text()==surface
  try:request('/plant-surface',{'text':surface.replace('12 8','nan 8')});raise AssertionError('NaN accepted')
  except urllib.error.HTTPError as e:assert e.code==409
  print('PASS actual HTTP: authentication, full sync, delta/removal, unchanged response, run reset, surface ingestion and invalid data rejection')
 finally:server.shutdown();server.server_close();world.ledger.db.close();thread.join()
