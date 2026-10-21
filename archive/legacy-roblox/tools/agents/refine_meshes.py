"""Refine the production mesh variant with tapered, beveled anatomy.
Native Part models remain the lightweight editable fallback; meshes are imported via glTF.
"""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'assets/agents/designs.json';models=json.loads(p.read_text())
organic={'Thorax','Shoulder','Hip','Belly','Neck','Skull','Jaw','Ribcage','Rump','Torso','Breast','Abdomen','LowerJaw','CellCore','FrontCap','RearCap','BroadPole','TrailingPole','SideLobe','RoundedPole','VentralFacet','DorsalFacet'}
links={'UpperLeg','LowerLeg','Thigh','Shin','Ankle','UpperArm','Forearm','LowerNeck','UpperNeck','TailSegment'}
for d in models:
 for part in d['parts']:
  name=part['name']
  if name in organic:
   part['meshProfile']={'axis':2,'rings':[[-.5,.72],[-.29,1],[.28,1],[.5,.76]],'bevel':.29}
   if name in {'Skull','FrontCap','BroadPole','RoundedPole'}:part['meshProfile']['rings']=[[-.5,.68],[-.28,.9],[.25,1],[.5,.76]]
   if name in {'Belly','Abdomen','VentralFacet','DorsalFacet'}:part['meshProfile']['bevel']=.4
  elif name in links:
   part['meshProfile']={'axis':1,'rings':[[-.5,.94],[-.12,1],[.5,.68]],'bevel':.28}
  elif name=='Flagellum':
   part['meshProfile']={'axis':1,'rings':[[-.5,1],[.5,.84]],'bevel':.1}
  elif name in {'Foot','Hand','Beak','Snout','Muzzle'}:
   part['meshProfile']={'axis':2,'rings':[[-.5,.57],[-.15,.85],[.5,1]],'bevel':.22}
  part['meshPigment']=name in organic or name in {'UpperLeg','Thigh','TailSegment','LowerNeck','UpperNeck'}
 pcounts={}
 for part in d['parts']:pcounts[part['name']]=pcounts.get(part['name'],0)+1
p.write_text(json.dumps(models,indent=2)+'\n')
print('Refined mesh profiles for all six designs; native fallback data intentionally unchanged')
