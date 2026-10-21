"""Combined transport and skipped-publication delta regression."""
import json,tempfile,sys
from pathlib import Path
from relay import World,atomic,exchange_bundle
from plant_channel import PlantChannel
snapshot=json.loads(Path(sys.argv[1]).read_text())
plants=json.loads(Path(sys.argv[2]).read_text())
with tempfile.TemporaryDirectory() as d:
 root=Path(d);world=World(root);channel=PlantChannel(root)
 snapshot['state']='running';snapshot['session']='bundle-test'
 atomic(root/'snapshot.json',json.dumps(snapshot))
 q={'protocol':1,'run':snapshot['manifest']['runId'],'boot':snapshot['boot'],'session':'bundle-test','batch':1,'ackBatch':0,'poses':[],'actors':[],'events':[],'plants':{'schema':1}}
 r=exchange_bundle(world,channel,q)
 assert 'plantError' in r and r['batch']==1
 atomic(root/'plants.json',json.dumps(plants))
 q['batch']=2;q['ackBatch']=1
 r=exchange_bundle(world,channel,q);first=r['plants']
 assert first['reset']
 original_revision=plants['revision']
 for i in range(1,5):
  plants['revision']=original_revision+i;plants['plants'][0]['resources'][0]+=.01
  atomic(root/'plants.json',json.dumps(plants))
  channel.exchange({'schema':1})
 delta=channel.exchange({'schema':1,'run':plants['run'],'revision':original_revision})
 assert not delta['reset'] and len(delta['upsert'])==1 and 'organs' not in delta['upsert'][0]
 for i in range(5,16):
  plants['revision']=original_revision+i
  atomic(root/'plants.json',json.dumps(plants));channel.exchange({'schema':1})
 assert len(channel.history)==8
 assert channel.exchange({'schema':1,'run':plants['run'],'revision':original_revision})['reset']
 world.ledger.db.close()
 print('PASS combined microbial/plant exchange; missing plants do not block microbes; skipped-revision deltas; bounded history; old-base reset')
