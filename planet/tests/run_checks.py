"""Headless behavioral checks; not a substitute for native Roblox Studio validation."""
from pathlib import Path
import argparse,subprocess,tempfile
p=argparse.ArgumentParser();p.add_argument('--luau',required=True);a=p.parse_args();here=Path(__file__).resolve().parent;planet=here.parent
mock=(here/'mock_runtime.lua').read_text();client=(planet/'src/world/StarterPlayer/StarterPlayerScripts/CI_PlanetPlayer.client.lua').read_text()
start=client.index('local ResearchUI=(function()\n')+len('local ResearchUI=(function()\n');end=client.index('\nend)()',start)
ui=mock+'\nlocal UI=(function()\n'+client[start:end]+'\nend)()\n'+(here/'ui_assertions.lua').read_text()
frame=mock+'\nlocal Frame=(function()\n'+(planet/'src/integration/shared/HabitatFrame.lua').read_text()+'\nend)()\n'+(here/'frame_assertions.lua').read_text()
solar='local Clock=(function()\n'+(planet/'src/biology/shared/SolarClock.lua').read_text()+'\nend)()\n'+(here/'solar_assertions.lua').read_text()
observation=mock
for name in ['ObservationMetrics','LiveInterpolation']:
 variable='Metrics' if name=='ObservationMetrics' else 'Interpolation'
 observation+='\nlocal '+variable+'=(function()\n'+(planet/'src/biology/shared'/(name+'.lua')).read_text()+'\nend)()\n'
observation+=(here/'observation_assertions.lua').read_text()
presentation=mock+'\nlocal designs=(function()\n'+(planet/'src/biology/shared/AgentDesignData.lua').read_text()+'\nend)()\n'
presentation+='local Factory=(function()\n'+(planet/'src/biology/shared/AgentModelFactory.lua').read_text().replace('require(script.Parent.AgentDesignData)','designs')+'\nend)()\n'
presentation+='local Clock=(function()\n'+(planet/'src/biology/shared/SolarClock.lua').read_text()+'\nend)()\n'+(here/'presentation_assertions.lua').read_text()
with tempfile.TemporaryDirectory() as temp:
 for name,code in [('ui',ui),('frame',frame),('solar',solar),('observation',observation),('presentation',presentation)]:
  path=Path(temp)/(name+'.lua');path.write_text(code);subprocess.run([a.luau,str(path)],check=True)
