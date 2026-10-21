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
colorMock='local cm={};cm.__index=cm\nfunction cm:Lerp(b,t)return setmetatable({R=self.R+(b.R-self.R)*t,G=self.G+(b.G-self.G)*t,B=self.B+(b.B-self.B)*t},cm)end\nColor3.fromRGB=function(r,g,b)return setmetatable({R=r/255,G=g/255,B=b/255},cm)end\n'
colorMock+='Color3.new=function(r,g,b)return Color3.fromRGB(r*255,g*255,b*255)end\n'
background='local Background=(function()\n'+(planet/'src/biology/shared/CelestialBackground.lua').read_text()+'\nend)()\n'
radial=mock+'\n'+colorMock+background+'\nlocal Sky=(function()\n'+(planet/'src/biology/shared/RadialSky.lua').read_text().replace('require(script.Parent.CelestialBackground)','Background')+'\nend)()\n'+(here/'radial_sky_assertions.lua').read_text()
radial+='\nlocal Catalog=(function()\n'+(planet/'src/biology/shared/CelestialCatalog.lua').read_text()+'\nend)()\n'+(here/'celestial_assertions.lua').read_text()
catalog='local Catalog=(function()\n'+(planet/'src/biology/shared/CelestialCatalog.lua').read_text()+'\nend)()\n'
modelSource='(function()\n'+(planet/'src/biology/shared/CelestialModels.lua').read_text().replace('require(script.Parent.CelestialCatalog)','Catalog')+'\nend)()'
models=mock+'\n'+colorMock+catalog+(here/'celestial_models_assertions.lua').read_text().replace('MODEL_SOURCE_PLACEHOLDER',modelSource)
probeSource='(function()\nlocal print=function()end;local warn=function()end\n'+(planet/'src/biology/shared/SkyPerformanceProbe.lua').read_text()+'\nend)()'
probe=mock+'\n'+(here/'sky_probe_assertions.lua').read_text().replace('PROBE_SOURCE_PLACEHOLDER',probeSource)
with tempfile.TemporaryDirectory() as temp:
 for name,code in [('ui',ui),('frame',frame),('solar',solar),('observation',observation),('presentation',presentation),('radial',radial),('models',models),('probe',probe)]:
  path=Path(temp)/(name+'.lua');path.write_text(code);subprocess.run([a.luau,str(path)],check=True)
