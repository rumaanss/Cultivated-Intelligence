"""Package reviewable source patches, Studio modules, native model examples and docs."""
from pathlib import Path
import xml.etree.ElementTree as ET
import zipfile,json,subprocess,hashlib
ROOT=Path(__file__).resolve().parents[2];CPP=ROOT.parent/'civ-current';OUT=ROOT/'dist';OUT.mkdir(exist_ok=True)
NAMES=['PlantConfig','PlantProtocol','PlantAssetLibrary','PlantRenderer','PlantSurfaceExport','PlantShowcaseData']
ref=0
def rootxml():
 x=ET.Element('roblox',version='4')
 for v in ['null','nil']:ET.SubElement(x,'External').text=v
 return x
def item(parent,kind,name,source=None):
 global ref
 ref+=1;n=ET.SubElement(parent,'Item',{'class':kind,'referent':f'RBXPLANT{ref}'})
 props=ET.SubElement(n,'Properties');ET.SubElement(props,'string',name='Name').text=name
 if source is not None:ET.SubElement(props,'ProtectedString',name='Source').text=source
 return n
x=rootxml();package=item(x,'Folder','PlantLifePackage');shared=item(package,'Folder','Shared')
for name in NAMES:item(shared,'ModuleScript',name,(ROOT/'src/shared'/f'{name}.lua').read_text())
item(package,'ModuleScript','Install',(ROOT/'tools/plants/PlantInstall.lua').read_text())
item(package,'Script','Plants',(ROOT/'src/server/Plants.server.lua').read_text())
item(package,'LocalScript','PlantController',(ROOT/'src/client/Controllers/PlantController.client.lua').read_text())
r=item(package,'StringValue','READ_ME');ET.SubElement(r.find('Properties'),'string',name='Value').text=(ROOT/'docs/plants/START_HERE.md').read_text()
ET.ElementTree(x).write(OUT/'PlantLifePackage.rbxmx',encoding='utf-8',xml_declaration=True)
x=rootxml();models=item(x,'Folder','PlantModels');species=[item(models,'Model',n) for n in ['PioneerShrub','CanopyTree','DrylandPlant']]
for i,p in enumerate(json.loads((ROOT/'assets/plants/showcase_geometry.json').read_text())):
 a=p['values'];kind='WedgePart' if p['shape']=='Wedge' else 'Part';part=item(species[int(a[0])],kind,'Organ_'+str(int(a[1]))+'_'+str(i));props=part.find('Properties')
 for name,value in [('Anchored','true'),('CanCollide','false'),('CanTouch','false'),('CanQuery','false')]:ET.SubElement(props,'bool',name=name).text=value
 size=ET.SubElement(props,'Vector3',name='size')
 for name,value in zip(['X','Y','Z'],a[2:5]):ET.SubElement(size,name).text=str(value)
 cf=ET.SubElement(props,'CoordinateFrame',name='CFrame')
 # Static display at Y=220, same convention as module showroom.
 for name,value in zip(['X','Y','Z'],[a[5],a[6]+220,a[7]]):ET.SubElement(cf,name).text=str(value)
 for name,value in zip(['R00','R01','R02','R10','R11','R12','R20','R21','R22'],a[8:17]):ET.SubElement(cf,name).text=str(value)
 color=ET.SubElement(props,'Color3',name='Color')
 for name,value in zip(['R','G','B'],a[17:20]):ET.SubElement(color,name).text=str(value)
 ET.SubElement(props,'token',name='Material').text='272' # SmoothPlastic
 if kind=='Part':ET.SubElement(props,'token',name='shape').text='0' if p['shape']=='Ball' else '1'
ET.ElementTree(x).write(OUT/'PlantModels.rbxmx',encoding='utf-8',xml_declaration=True)
cppfiles=['CMakeLists.txt','include/cybernet/brain/rnn_brain.hpp','include/cybernet/simulation/run_options.hpp','include/cybernet/world/ecology.hpp','src/main.cpp','src/world/ecology.cpp']
for directory in ['include/cybernet/plants','src/plants','tests/plants','tools/plants']:
 cppfiles += [str(p.relative_to(CPP)) for p in (CPP/directory).glob('*') if p.is_file() and p.suffix in ['.hpp','.cpp','.py','.txt']]
cppfiles += [str(p.relative_to(CPP)) for p in (CPP/'tools/live_bridge').glob('*.py')]
rbfiles=[f'src/shared/{n}.lua' for n in NAMES]+['src/server/Plants.server.lua','src/client/Controllers/PlantController.client.lua']
rbfiles += [str(p.relative_to(ROOT)) for p in (ROOT/'tools/plants').glob('*') if p.suffix in ['.py','.lua']]
rbfiles += [str(p.relative_to(ROOT)) for p in (ROOT/'assets/plants').glob('*.json')]
rbfiles += [str(p.relative_to(ROOT)) for p in (ROOT/'docs/plants').glob('*') if p.is_file()]
patches={}
for name,repo,files in [('civ0.77',CPP,cppfiles),('ci_rbxl',ROOT,rbfiles)]:
 patches[name]=subprocess.check_output(['git','diff','--cached','--binary','--',*files],cwd=repo)
 if not patches[name]:raise RuntimeError('Stage source changes before packaging: '+name)
info={'package':'Intelligent Plant Life v1','bases':{n:subprocess.check_output(['git','rev-parse','HEAD'],cwd=p,text=True).strip() for n,p in [('civ0.77',CPP),('ci_rbxl',ROOT)]},'studioTested':False,'compiler':'Linux g++ C++20','note':'Source patches were generated from these base commits; preserve newer user edits.'}
with zipfile.ZipFile(OUT/'IntelligentPlantLife_v1.zip','w',zipfile.ZIP_DEFLATED) as z:
 for name in ['PlantLifePackage.rbxmx','PlantModels.rbxmx','FixIslandWarnings.lua','ReferenceIslandPackage.rbxmx']:z.write(OUT/name,name)
 z.write(ROOT/'ISLAND_SETUP.md','ISLAND_SETUP.md')
 for p in (ROOT/'docs/plants').glob('*'):
  if p.is_file():z.write(p,p.name)
 z.write(ROOT/'docs/agents/INTELLIGENT_PLANT_IMPLEMENTATION_PLAN.md','ORIGINAL_PLAN.md')
 z.writestr('BUILD_INFO.json',json.dumps(info,indent=2)+'\n')
 for name,patch in patches.items():z.writestr('patches/'+name+'.patch',patch)
 for repo,prefix,files in [(CPP,'civ0.77',cppfiles),(ROOT,'ci_rbxl',rbfiles)]:
  for relative in sorted(set(files)):z.write(repo/relative,'source/'+prefix+'/'+relative)
print(OUT/'IntelligentPlantLife_v1.zip')
