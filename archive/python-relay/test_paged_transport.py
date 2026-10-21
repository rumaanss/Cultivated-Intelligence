"""Large producer revisions remain atomic while bounded pages cross exchanges."""
import json,tempfile,threading,http.client,sys
from pathlib import Path
from http.server import ThreadingHTTPServer
from plant_channel import PlantChannel
from relay import Handler
sample=json.loads(Path(sys.argv[1]).read_text())
with tempfile.TemporaryDirectory() as d:
 root=Path(d);channel=PlantChannel(root)
 sample['plants'][0]['testPadding']='x'*900000
 (root/'plants.json').write_text(json.dumps(sample))
 first=channel.exchange_paged({'schema':1});assert first['chunked'] and first['count']==4
 original=sample['revision'];sample['revision']+=1
 (root/'plants.json').write_text(json.dumps(sample))
 pages=[first['data']]
 for i in range(2,first['count']+1):
  q={'schema':1,'transfer':first['transfer'],'chunk':i}
  p=channel.exchange_paged(q);assert len(p['data'])<=256*1024 and p==channel.exchange_paged(q)|{'age':p['age']}
  pages.append(p['data'])
 assembled=json.loads(''.join(pages));assert assembled['revision']==original
 try:channel.exchange_paged({'schema':1,'transfer':first['transfer'],'chunk':999});assert False
 except ValueError:pass
 assert channel.exchange_paged({'schema':1})['transfer']!=first['transfer']
 for i in range(5):
  sample['revision']+=1;(root/'plants.json').write_text(json.dumps(sample));channel.exchange_paged({'schema':1})
 assert len(channel.transfers)==3
 class FakeWorld:token='k'*32
 server=ThreadingHTTPServer(('127.0.0.1',0),Handler);server.world=FakeWorld();server.plants=channel
 thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
 try:
  conn=http.client.HTTPConnection('127.0.0.1',server.server_port)
  body=json.dumps({'schema':1,'run':sample['run'],'revision':sample['revision']})
  for i in range(3):
   conn.request('POST','/plants',body,{'X-CI-Token':FakeWorld.token,'Content-Type':'application/json'})
   response=conn.getresponse();assert response.status==200 and not response.will_close;response.read()
   if i==0:socket=conn.sock
   else:assert conn.sock is socket
  conn.request('POST','/plants',body,{'X-CI-Token':'invalid'});response=conn.getresponse()
  assert response.status==401 and response.will_close;response.read();conn.close()
 finally:server.shutdown();server.server_close();thread.join()
 print('PASS frozen plant revisions, bounded 256 KiB pages, retransmission, bounds, cache eviction, HTTP connection reuse, unauthorized connection closure')
