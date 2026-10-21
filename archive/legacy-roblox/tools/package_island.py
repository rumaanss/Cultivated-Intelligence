"""Build a source ZIP and importable Studio model from the checked-in modules."""
from pathlib import Path
import xml.etree.ElementTree as ET
import zipfile
root=Path(__file__).resolve().parents[1]
out=root/'dist';out.mkdir(exist_ok=True)
names=['IslandConfig','IslandField','IslandVegetation','ReferenceIslandGenerator','BasinBackdrop','ResearchCameraConfig']
xml=ET.Element('roblox',version='4')
ET.SubElement(xml,'External').text='null';ET.SubElement(xml,'External').text='nil'
ref=0
def item(parent,kind,name,source=None):
 global ref
 ref+=1
 node=ET.SubElement(parent,'Item',{'class':kind,'referent':f'RBX{ref}'})
 props=ET.SubElement(node,'Properties');ET.SubElement(props,'string',name='Name').text=name
 if source is not None:ET.SubElement(props,'ProtectedString',name='Source').text=source
 return node
package=item(xml,'Folder','ReferenceIslandPackage')
shared=item(package,'Folder','Shared')
for n in names:item(shared,'ModuleScript',n,(root/'src/shared'/f'{n}.lua').read_text())
item(package,'ModuleScript','Install',(root/'tools/IslandPackageInstall.lua').read_text())
readme=item(package,'StringValue','READ_ME')
ET.SubElement(readme.find('Properties'),'string',name='Value').text=(root/'ISLAND_SETUP.md').read_text()
model=out/'ReferenceIslandPackage.rbxmx'
ET.ElementTree(xml).write(model,encoding='utf-8',xml_declaration=True)
with zipfile.ZipFile(out/'ReferenceIslandGenerator.zip','w',zipfile.ZIP_DEFLATED) as z:
 z.write(model,model.name)
 z.write(root/'ISLAND_SETUP.md','START_HERE.md')
 z.write(root/'ISLAND_SETUP.md','ci_rbxl/ISLAND_SETUP.md')
 for n in names:z.write(root/'src/shared'/f'{n}.lua',f'ci_rbxl/src/shared/{n}.lua')
 for p in ['tests/island_generator.py','tools/package_island.py','tools/IslandPackageInstall.lua','docs/IslandHeightfieldPreview.png']:
  z.write(root/p,'ci_rbxl/'+p)
with zipfile.ZipFile(out/'ReferenceIslandGenerator.zip') as z:assert z.testzip() is None
parsed=ET.parse(model)
assert len(parsed.findall('.//Item[@class="ModuleScript"]'))==7
print(out/'ReferenceIslandGenerator.zip')
print(model)
