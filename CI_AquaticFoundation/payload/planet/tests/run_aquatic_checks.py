"""Optional developer checks; Python is not needed to run the ecosystem."""
import argparse,subprocess,tempfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--luau',required=True);a=p.parse_args()
here=Path(__file__).resolve().parent;shared=here.parent/'src/biology/shared'
subprocess.run([a.luau,str(here/'aquatic_assertions.lua')],check=True)
protocol='local Protocol=(function()\n'+(shared/'AquaticProtocol.lua').read_text()+'\nend)()\n'
client=(here.parent/'src/biology/client/Aquatic.client.lua').read_text()
for name in ('Space','Protocol','Contract'):
 module={'Space':'SimulationSpace','Protocol':'AquaticProtocol','Contract':'PlanetContract'}[name]
 client=client.replace(f'require(RS.CI_Biology.{module})',name)
code=(here/'mock_runtime.lua').read_text()+'\n'+protocol+(here/'aquatic_render_assertions.lua').read_text().replace('CLIENT_SOURCE_PLACEHOLDER','do\n'+client+'\nend')
with tempfile.TemporaryDirectory() as tmp:
 path=Path(tmp)/'aquatic-render.lua';path.write_text(code)
 subprocess.run([a.luau,str(path)],check=True)
