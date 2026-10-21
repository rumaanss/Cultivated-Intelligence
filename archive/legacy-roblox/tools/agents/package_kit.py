from pathlib import Path
import xml.etree.ElementTree as ET
import zipfile
ROOT=Path(__file__).resolve().parents[2];out=ROOT/'dist';out.mkdir(exist_ok=True)
names=['AgentDesignData','AgentModelFactory','AgentPresentationConfig','AgentBodyContract','AgentPoseCodec']
xml=ET.Element('roblox',version='4')
for s in ['null','nil']:ET.SubElement(xml,'External').text=s
ref=0
def item(parent,kind,name,source=None):
 global ref
 ref+=1;n=ET.SubElement(parent,'Item',{'class':kind,'referent':f'RBX{ref}'})
 props=ET.SubElement(n,'Properties');ET.SubElement(props,'string',name='Name').text=name
 if source is not None:ET.SubElement(props,'ProtectedString',name='Source').text=source
 return n
pkg=item(xml,'Folder','AgentModelPackage');shared=item(pkg,'Folder','Shared')
for n in names:item(shared,'ModuleScript',n,(ROOT/'src/shared'/f'{n}.lua').read_text())
item(pkg,'ModuleScript','Install',(ROOT/'tools/agents/AgentKitInstall.lua').read_text())
item(pkg,'LocalScript','AgentDetailController',(ROOT/'src/client/Controllers/AgentDetailController.client.lua').read_text())
r=item(pkg,'StringValue','READ_ME');ET.SubElement(r.find('Properties'),'string',name='Value').text=(ROOT/'AGENT_KIT_SETUP.md').read_text()
model=out/'AgentModelPackage.rbxmx';ET.ElementTree(xml).write(model,encoding='utf-8',xml_declaration=True)
with zipfile.ZipFile(out/'AgentModelKit_Refined.zip','w',zipfile.ZIP_DEFLATED) as z:
 def add(p,dest):z.write(ROOT/p,dest)
 add('dist/AgentModelPackage.rbxmx','AgentModelPackage.rbxmx')
 add('AGENT_KIT_SETUP.md','START_HERE.md');add('docs/agents/BRIDGE_CONTRACT.md','BRIDGE_CONTRACT.md')
 for n in ['FixIslandWarnings.lua','ReferenceIslandPackage.rbxmx']:add('dist/'+n,n)
 add('ISLAND_SETUP.md','ISLAND_SETUP.md')
 for p in (ROOT/'assets/agents').rglob('*'):
  if p.is_file():z.write(p,'models/'+str(p.relative_to(ROOT/'assets/agents')))
 for p in (ROOT/'docs/agents').glob('*'):
  if p.suffix in ['.png','.gif']:z.write(p,'previews/'+p.name)
 for folder in ['tools/agents','tests']:
  for p in (ROOT/folder).glob('*'):
   if p.suffix in ['.py','.lua']:z.write(p,'ci_rbxl/'+str(p.relative_to(ROOT)))
 for n in names:add(f'src/shared/{n}.lua',f'ci_rbxl/src/shared/{n}.lua')
 add('src/client/Controllers/AgentDetailController.client.lua','ci_rbxl/src/client/Controllers/AgentDetailController.client.lua')
 add('AGENT_KIT_SETUP.md','ci_rbxl/AGENT_KIT_SETUP.md')
 # Include the source inputs needed to reproduce the package from its source tree.
 for p in (ROOT/'assets/agents').rglob('*'):
  if p.is_file():z.write(p,'ci_rbxl/'+str(p.relative_to(ROOT)))
 for p in (ROOT/'docs/agents').glob('*'):
  if p.is_file():z.write(p,'ci_rbxl/'+str(p.relative_to(ROOT)))
 for n in ['FixIslandWarnings.lua','ReferenceIslandPackage.rbxmx']:add('dist/'+n,'ci_rbxl/dist/'+n)
 add('ISLAND_SETUP.md','ci_rbxl/ISLAND_SETUP.md')
print(out/'AgentModelKit_Refined.zip')
