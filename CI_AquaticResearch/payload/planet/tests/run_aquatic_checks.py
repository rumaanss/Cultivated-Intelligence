"""Optional developer checks; Python is not needed to run the ecosystem."""
import argparse,subprocess,tempfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--luau',required=True);a=p.parse_args()
here=Path(__file__).resolve().parent;shared=here.parent/'src/biology/shared'
subprocess.run([a.luau,str(here/'aquatic_assertions.lua')],check=True)
protocol='local Protocol=(function()\n'+(shared/'AquaticProtocol.lua').read_text()+'\nend)()\n'
client=(here.parent/'src/biology/client/Aquatic.client.lua').read_text()
for name,module in [('Space','SimulationSpace'),('Protocol','AquaticProtocol'),('Models','AquaticModels')]:
 client=client.replace('require(RS.CI_Biology.'+module+')',name)
designs='local designs=(function()\n'+(shared/'AgentDesignData.lua').read_text()+'\nend)()\n'
factory='local Factory=(function()\n'+(shared/'AgentModelFactory.lua').read_text().replace('require(script.Parent.AgentDesignData)','designs')+'\nend)()\n'
model=(shared/'AquaticModels.lua').read_text()
for name,module in [('Factory','AgentModelFactory'),('Space','SimulationSpace'),('Contract','PlanetContract')]:
 model=model.replace('require(script.Parent.'+module+')',name)
models=designs+factory+'local Models=(function()\n'+model+'\nend)()\n'
assertions=(here/'aquatic_render_assertions.lua').read_text().replace('CLIENT_SOURCE_PLACEHOLDER',models+'do\n'+client+'\nend')
code=(here/'mock_runtime.lua').read_text()+'\n'+protocol+assertions
with tempfile.TemporaryDirectory() as tmp:
 path=Path(tmp)/'aquatic-render.lua';path.write_text(code)
 subprocess.run([a.luau,str(path)],check=True)
