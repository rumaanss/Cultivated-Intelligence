"""Author six original faceted models; export shared data and native-compatible geometry.
All dimensions are authoring units. Front is -Z, up is +Y. No imported game assets.
"""
from pathlib import Path
import json, math, numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/agents';OUT.mkdir(parents=True,exist_ok=True)
models=[]
I=np.eye(3)
def rgb(hex):return [int(hex[i:i+2],16) for i in (0,2,4)]
def rot(x=0,y=0,z=0):
 x,y,z=np.radians([x,y,z]);cx,sx,cy,sy,cz,sz=np.cos(x),np.sin(x),np.cos(y),np.sin(y),np.cos(z),np.sin(z)
 return np.array([[1,0,0],[0,cx,-sx],[0,sx,cx]])@np.array([[cy,0,sy],[0,1,0],[-sy,0,cy]])@np.array([[cz,-sz,0],[sz,cz,0],[0,0,1]])
class Design:
 def __init__(self,key,title,kind,palette,description):
  self.d=dict(key=key,title=title,kind=kind,description=description,palette=palette,joints=[dict(name='Root',parent=0,pivot=[0,0,0],axis=[0,1,0],amplitude=0,phase=0)],parts=[])
  self.world=[np.zeros(3)];models.append(self.d)
 def joint(self,name,pos,parent=1,axis=(0,1,0),amp=0,phase=0):
  pos=np.array(pos,dtype=float)
  self.d['joints'].append(dict(name=name,parent=parent,pivot=(pos-self.world[parent-1]).tolist(),axis=list(axis),amplitude=math.radians(amp),phase=phase))
  self.world.append(pos);return len(self.world)
 def part(self,name,size,pos,color='main',joint=1,r=None,shape='Block',lod=1):
  if r is None:r=I
  p=np.array(pos)-self.world[joint-1]
  self.d['parts'].append(dict(name=name,size=list(size),cf=p.tolist()+r.flatten().tolist(),color=self.d['palette'][color],joint=joint,shape=shape,lod=lod))
 def link(self,name,a,b,width,depth,color='main',joint=1,lod=1):
  a,b=np.array(a),np.array(b);up=(b-a)/np.linalg.norm(b-a)
  helper=np.array([0.,0.,1.]) if abs(up[2])<.9 else np.array([1.,0.,0.])
  right=np.cross(up,helper);right/=np.linalg.norm(right);back=np.cross(right,up)
  self.part(name,[width,float(np.linalg.norm(b-a))+.03,depth],(a+b)/2,color,joint,np.column_stack([right,up,back]),lod=lod)
 def eyes(self,pos,width,size=.1,joint=1):
  x,y,z=pos
  for side in [-1,1]:
   self.part('EyeSocket',[.045,size*1.55,size*1.8],[x+side*width,y,z],'dark',joint,lod=2)
   self.part('AmberEye',[.052,size,size*.82],[x+side*(width+.02),y,z-.015],'eye',joint,lod=2)
 def pixels(self,x,y,z,rows,cols,step,side=1,joint=1,seed=1):
  rng=np.random.default_rng(seed)
  for a in range(rows):
   for b in range(cols):
    if rng.random()<.5:
     self.part('Pigment',[.018,step*.85,step*.9],[x*side,y+a*step,z+b*step],'stripe',joint,lod=2)
 def finish(self):
  for p in self.d['parts']:
   p['cf']=[round(float(v),7) for v in p['cf']];p['size']=[round(float(v),7) for v in p['size']]
  path=[]
  for i,j in enumerate(self.d['joints']):path.append(float(np.linalg.norm(j['pivot']))+(path[j['parent']-1] if j['parent'] else 0))
  bound=max(path[p['joint']-1]+np.linalg.norm(p['cf'][:3])+np.linalg.norm(p['size'])/2 for p in self.d['parts'])
  self.d['safeRadius']=round(float(bound),6)+.00001
  self.d['partCount']=len(self.d['parts'])
  self.d['triangleCount']=sum(8 if p['shape']=='Wedge' else 12 for p in self.d['parts'])
# Live biological agent skins: stylized visible markers, not microscope reconstructions.
pal={k:rgb(v) for k,v in dict(main='43886F',light='88BA82',dark='244C49',stripe='B8CF86',eye='000000').items()}
m=Design('Cyanobacteria','Verdant cell','Live',pal,'Faceted cyanobacterial cell with chlorophyll-inspired pigment blocks; no invented eyes or limbs.')
m.part('CellCore',[.92,.72,1.65],[0,0,0]);m.part('FrontCap',[.73,.57,.34],[0,0,-.93],'light')
m.part('RearCap',[.73,.57,.34],[0,0,.93],'main');m.part('DorsalFacet',[.66,.20,1.56],[0,.4,0],'light',r=rot(0,0,0))
m.part('VentralFacet',[.68,.15,1.5],[0,-.39,0],'dark')
for z in [-.48,0,.48]:m.part('PigmentBand',[.94,.12,.16],[0,.18,z],'stripe',lod=2)
m.finish()
pal={k:rgb(v) for k,v in dict(main='B5944C',light='DBC27A',dark='665537',stripe='E8D79A',eye='000000').items()}
m=Design('Bacterivore','Ochre forager','Live',pal,'Generic bacterivore marker; its single stylized appendage is an art convention, not an asserted species diagnosis.')
m.part('CellCore',[.84,.7,1.15],[0,0,-.22]);m.part('BroadPole',[.68,.57,.45],[0,0,-.95],'light')
m.part('TaperedPole',[.62,.53,.51],[0,0,.55],'main',shape='Wedge',r=rot(180,0,0))
m.part('VentralFacet',[.63,.16,1.23],[0,-.38,-.31],'dark')
m.part('PigmentA',[.38,.11,.45],[-.15,.39,-.43],'light',lod=2)
m.part('PigmentB',[.25,.1,.26],[.2,.39,.06],'stripe',lod=2)
parent=1
pts=[[0,0,.65],[.12,.06,1.12],[.02,.1,1.56],[-.18,.06,1.98],[-.25,0,2.35]]
for i in range(len(pts)-1):
 j=m.joint('Flagellum'+str(i),pts[i],parent,amp=12,phase=-i*.7)
 m.link('Flagellum',pts[i],pts[i+1],.09-i*.012,.09-i*.012,'light',j);parent=j
m.finish()
pal={k:rgb(v) for k,v in dict(main='AC6860',light='D49C7C',dark='673F49',stripe='E0B49A',eye='000000').items()}
m=Design('BodoSaltans','Twin-thread Bodo','Live',pal,'Kidney-like faceted cell with unequal anterior and trailing flagella; red is the existing research species color, not natural pigmentation.')
m.part('CellCore',[.72,.65,1.05],[-.08,0,-.2]);m.part('RoundedPole',[.57,.53,.4],[-.11,0,-.88],'light')
m.part('TrailingPole',[.56,.5,.42],[-.06,0,.49],'main');m.part('SideLobe',[.3,.55,.67],[.35,-.02,.01],'main',r=rot(0,-10,0))
m.part('VentralFacet',[.55,.12,1.12],[-.08,-.35,-.15],'dark');m.part('Pigment',[.43,.1,.4],[-.12,.36,-.22],'stripe',lod=2)
paths=[[[.22,0,-.84],[.42,.06,-1.15],[.55,.12,-1.48],[.42,.18,-1.72]],[[.28,-.05,-.8],[.65,-.1,-.25],[.68,-.1,.4],[.52,-.06,1.02],[.62,.02,1.6],[.88,.1,2.1]]]
for n,pts in enumerate(paths):
 parent=1
 for i in range(len(pts)-1):
  j=m.joint(('Anterior' if n==0 else 'Trailing')+str(i),pts[i],parent,amp=9 if n else 14,phase=-i*.7+n*2)
  m.link('Flagellum',pts[i],pts[i+1],.075-i*.007,.075-i*.007,'light',j);parent=j
m.finish()
# Future morphology studies. Never assigned to microbial IDs by default.
pal={k:rgb(v) for k,v in dict(main='465B4B',light='A5A481',dark='253A37',stripe='A67743',eye='D9AC42',claw='D4CCAA').items()}
m=Design('Tideback','Tideback prowler','Study',pal,'Low amphibious quadruped: broad skull, offset armored back, splayed limbs and a tapered swimming tail.')
m.part('Thorax',[1.65,.85,2.5],[0,.12,.1]);m.part('Shoulder',[1.85,.7,1.1],[0,.13,-.8],'main',r=rot(0,0,0))
m.part('Hip',[1.45,.75,1.0],[0,.1,1.18]);m.part('Belly',[1.2,.25,2.4],[0,-.36,.06],'light')
neck=m.joint('Neck',[0,.2,-1.1],amp=3)
m.part('Neck',[1.15,.62,.7],[0,.2,-1.4],'main',neck)
head=m.joint('Head',[0,.18,-1.6],neck,axis=(1,0,0),amp=2)
m.part('Skull',[1.25,.55,1.05],[0,.27,-2.02],'main',head)
m.part('Snout',[1.08,.34,.9],[0,.13,-2.8],'main',head,shape='Wedge',r=rot(0,180,0))
m.part('Jaw',[1.1,.16,1.45],[0,-.12,-2.37],'light',head)
m.part('MouthLine',[1.115,.035,1.35],[0,-.025,-2.4],'dark',head,lod=2)
m.eyes([0,.38,-1.94],.638,.13,head)
for side in [-1,1]:
 for z,offset in [(-.75,0),(1.0,math.pi)]:
  hip=[side*.72,-.05,z];elbow=[side*1.23,-.38,z+.22];foot=[side*1.38,-.85,z-.12]
  joint=m.joint('Leg'+str(side)+str(z),hip,axis=(1,0,0),amp=18,phase=offset+(math.pi if side<0 else 0))
  m.link('UpperLeg',hip,elbow,.45,.53,'main',joint)
  m.link('LowerLeg',elbow,foot,.28,.34,'dark',joint)
  m.part('Foot',[.48,.18,.6],[foot[0],foot[1],foot[2]-.12],'dark',joint)
  for dx in [-.14,.14]:m.part('Claw',[.1,.11,.24],[foot[0]+dx,foot[1]-.03,foot[2]-.48],'claw',joint,lod=2)
parent=1
for i in range(6):
 start=[0,.12-i*.035,1.5+i*.62];end=[0,.12-(i+1)*.035,1.5+(i+1)*.62]
 j=m.joint('Tail'+str(i),start,parent,amp=6,phase=-i*.45)
 m.link('TailSegment',start,end,max(.18,1.12-i*.18),max(.13,.55-i*.08),'main' if i%2==0 else 'stripe',j)
 parent=j
for z in [-.9,-.3,.3,.9,1.45]:
 for side in [-1,1]:m.part('DorsalScute',[.35,.22,.32],[side*.43,.66,z],'dark',r=rot(0,15*side,0),shape='Wedge',lod=2)
for side in [-1,1]:m.pixels(.835,-.1,-.95,3,9,.25,side,seed=41)
m.finish()
pal={k:rgb(v) for k,v in dict(main='464D3C',light='C5BE8F',dark='242E2C',stripe='8C7549',eye='D9AD48',claw='BDB8A1').items()}
m=Design('Reedrunner','Reedrunner scout','Study',pal,'Light biped: cream throat, small narrow head, deep hip, folded forelimbs and counterbalancing tail.')
m.part('Torso',[.96,1.25,1.62],[0,.4,0],r=rot(12,0,0));m.part('Breast',[.74,.9,.65],[0,.4,-.81],'light',r=rot(-15,0,0))
m.part('Hip',[1.18,1.0,1.0],[0,.12,.65]);m.part('Abdomen',[.75,.35,1.3],[0,-.25,.04],'light')
j=m.joint('Neck',[0,.83,-.64],axis=(1,0,0),amp=3)
m.link('LowerNeck',[0,.75,-.6],[0,1.46,-1.08],.52,.58,'main',j)
n=m.joint('UpperNeck',[0,1.42,-1.05],j,axis=(1,0,0),amp=2,phase=1)
m.link('UpperNeck',[0,1.4,-1.03],[0,2.13,-1.52],.38,.43,'light',n)
head=m.joint('Head',[0,2.07,-1.5],n,axis=(0,1,0),amp=3)
m.part('Skull',[.48,.42,.7],[0,2.17,-1.75],'light',head)
m.part('Muzzle',[.39,.25,.52],[0,2.07,-2.26],'light',head,shape='Wedge',r=rot(0,180,0))
m.part('Jaw',[.4,.1,.83],[0,1.98,-1.98],'dark',head)
m.eyes([0,2.24,-1.76],.25,.085,head)
for side in [-1,1]:
 hip=[side*.48,.2,.6];knee=[side*.7,-.55,-.08];ankle=[side*.64,-1.3,.4];toe=[side*.64,-1.85,-.22]
 leg=m.joint('Hindleg'+str(side),hip,axis=(1,0,0),amp=23,phase=0 if side>0 else math.pi)
 m.link('Thigh',hip,knee,.47,.62,'main',leg);m.link('Shin',knee,ankle,.22,.27,'light',leg);m.link('Ankle',ankle,toe,.16,.19,'dark',leg)
 for dx in [-.15,0,.15]:m.link('Toe',[toe[0]+dx,-1.86,-.2],[toe[0]+dx*1.4,-1.91,-.68],.09,.12,'claw',leg,lod=2)
 shoulder=[side*.45,.63,-.61];elbow=[side*.72,.05,-.76];wrist=[side*.58,.24,-1.12]
 arm=m.joint('Forelimb'+str(side),shoulder,axis=(1,0,0),amp=8,phase=side)
 m.link('UpperArm',shoulder,elbow,.19,.25,'main',arm);m.link('Forearm',elbow,wrist,.14,.19,'light',arm)
 m.part('Hand',[.16,.24,.22],[wrist[0],wrist[1]-.05,wrist[2]-.12],'dark',arm)
parent=1
for i in range(6):
 a=[0,.3-i*.04,1.05+i*.53];b=[0,.3-(i+1)*.04,1.05+(i+1)*.53]
 t=m.joint('Tail'+str(i),a,parent,amp=4,phase=-i*.5)
 m.link('TailSegment',a,b,max(.12,.67-i*.105),max(.12,.62-i*.09),'main' if i%2==0 else 'light',t);parent=t
for side in [-1,1]:m.pixels(.49,.05,-.4,4,6,.2,side,seed=6)
m.finish()
pal={k:rgb(v) for k,v in dict(main='776652',light='BEB49A',dark='373F37',stripe='A5966C',eye='DDA54C',claw='C6C2AB').items()}
m=Design('Crestgrazer','Crestgrazer browser','Study',pal,'Stocky browser: deep abdomen, layered brow shield, broad beak and weight-bearing limbs. Original silhouette, not an extracted game model.')
m.part('Ribcage',[1.7,1.38,2.4],[0,.42,.15]);m.part('Shoulder',[1.52,1.2,1.15],[0,.48,-1.05]);m.part('Rump',[1.55,1.05,1.0],[0,.43,1.58])
m.part('Belly',[1.25,.33,2.55],[0,-.27,.22],'light')
neck=m.joint('Neck',[0,.52,-1.4],axis=(1,0,0),amp=4)
m.part('Neck',[1.05,.91,.72],[0,.55,-1.68],'main',neck)
head=m.joint('Head',[0,.56,-1.91],neck,axis=(1,0,0),amp=3,phase=1)
m.part('Skull',[1.0,.83,1.0],[0,.57,-2.2],'main',head)
m.part('Beak',[.77,.38,.73],[0,.34,-2.97],'light',head,shape='Wedge',r=rot(0,180,0))
m.part('LowerJaw',[.77,.22,1.05],[0,.12,-2.55],'dark',head)
m.part('FrillBase',[1.4,.8,.21],[0,1.03,-1.88],'dark',head,r=rot(-25,0,0))
for side in [-1,1]:
 m.part('FrillWing',[.65,1.02,.19],[side*.53,1.22,-1.94],'main',head,r=rot(-25,0,-side*22),shape='Wedge')
 m.part('Brow',[.29,.2,.42],[side*.44,.99,-2.36],'light',head,r=rot(0,0,-side*12))
m.eyes([0,.72,-2.34],.51,.13,head)
for side in [-1,1]:
 for z,back in [(-1.02,False),(1.22,True)]:
  a=[side*.62,.16,z];b=[side*.79,-.62,z+(.26 if back else -.12)];c=[side*.79,-1.34,z-.18]
  j=m.joint('Leg'+str(side)+str(z),a,axis=(1,0,0),amp=15,phase=(math.pi if back else 0)+(math.pi if side<0 else 0))
  m.link('UpperLeg',a,b,.48,.62,'main',j);m.link('Shin',b,c,.29,.35,'dark',j)
  m.part('Foot',[.48,.24,.61],[c[0],c[1],c[2]-.12],'light',j)
parent=1
for i in range(5):
 a=[0,.44-i*.07,1.95+i*.51];b=[0,.44-(i+1)*.07,1.95+(i+1)*.51]
 j=m.joint('Tail'+str(i),a,parent,amp=4,phase=-i*.6);m.link('TailSegment',a,b,max(.13,.9-i*.17),max(.13,.64-i*.12),'main',j);parent=j
for side in [-1,1]:m.pixels(.86,.12,-.8,4,8,.25,side,seed=29)
for z in [-1,-.4,.2,.8,1.4]:m.part('DorsalStripe',[.85,.08,.23],[0,1.13,z],'stripe',lod=2)
m.finish()
# Add true knee/ankle pivots to the macro rigs rather than swinging a rigid leg.
for d in models:
 if d['kind']!='Study':continue
 world=[]
 for j in d['joints']:world.append(np.array(j['pivot'])+(world[j['parent']-1] if j['parent'] else 0))
 original=list(enumerate(d['joints'],1))
 for ji,j in original:
  if not (j['name'].startswith('Leg') or j['name'].startswith('Hindleg')):continue
  upper=next((q for q in d['parts'] if q['joint']==ji and q['name'] in ('UpperLeg','Thigh')),None)
  if upper is None:continue
  center=world[ji-1]+np.array(upper['cf'][:3]);axis=np.array(upper['cf'][3:]).reshape(3,3)[:,1]
  pivot=center+axis*(upper['size'][1]-.03)/2
  knee=len(d['joints'])+1
  d['joints'].append(dict(name=j['name']+'_Knee',parent=ji,pivot=(pivot-world[ji-1]).tolist(),axis=[1,0,0],amplitude=math.radians(16),phase=j['phase']+.8))
  world.append(pivot)
  for q in d['parts']:
   if q['joint']==ji and q['name'] in ('LowerLeg','Shin','Ankle','Foot','Toe','Claw'):
    q['cf'][:3]=(np.array(q['cf'][:3])+world[ji-1]-pivot).tolist();q['joint']=knee
  if d['key']=='Reedrunner':
   shin=next(q for q in d['parts'] if q['joint']==knee and q['name']=='Shin')
   axis=np.array(shin['cf'][3:]).reshape(3,3)[:,1]
   anklePivot=pivot+np.array(shin['cf'][:3])+axis*(shin['size'][1]-.03)/2
   ankle=len(d['joints'])+1
   d['joints'].append(dict(name=j['name']+'_Ankle',parent=knee,pivot=(anklePivot-pivot).tolist(),axis=[1,0,0],amplitude=math.radians(11),phase=j['phase']-.3))
   world.append(anklePivot)
   for q in d['parts']:
    if q['joint']==knee and q['name'] in ('Ankle','Toe'):
     q['cf'][:3]=(np.array(q['cf'][:3])+pivot-anklePivot).tolist();q['joint']=ankle
 path=[]
 for j in d['joints']:path.append(float(np.linalg.norm(j['pivot']))+(path[j['parent']-1] if j['parent'] else 0))
 d['safeRadius']=float(max(path[p['joint']-1]+np.linalg.norm(p['cf'][:3])+np.linalg.norm(p['size'])/2 for p in d['parts']))+.00001
(OUT/'designs.json').write_text(json.dumps(models,indent=2)+'\n')
def lua(v):
 if isinstance(v,dict):return '{'+','.join(k+'='+lua(x) for k,x in v.items())+'}'
 if isinstance(v,list):return '{'+','.join(map(lua,v))+'}'
 if isinstance(v,str):return json.dumps(v)
 return str(v).lower()
(ROOT/'src/shared/AgentDesignData.lua').write_text('--!strict\n-- Generated by tools/agents/build_designs.py. Original models; front=-Z, up=Y.\nreturn '+lua(models)+'\n')
for d in models:print(d['key'],d['partCount'],'parts',d['triangleCount'],'triangles',d['safeRadius'],'safe radius')
