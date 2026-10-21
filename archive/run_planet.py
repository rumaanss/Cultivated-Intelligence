"""Launch only the newly built planetary simulation against its matching survey."""
from pathlib import Path
import argparse,hashlib,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'simulation/tools/live_bridge'))
from planet_channel import validate_habitat

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--executable',type=Path)
 p.add_argument('--runtime',type=Path,default=ROOT/'runtime/planet-native-v1')
 p.add_argument('--ticks',type=int,default=4294967295,help='Absolute stop tick; default runs until interrupted')
 a=p.parse_args();runtime=a.runtime.resolve()
 contract=json.loads((ROOT/'contracts/identity.json').read_text())
 survey=runtime/'planet_habitat.json'
 if not survey.exists():p.error(f'Run the relay for {runtime} and Play the existing planet once to export {survey}, or copy the matching survey from your previous runtime.')
 data=json.loads(survey.read_text(encoding='utf-8'));validate_habitat(data)
 digest=hashlib.sha256(json.dumps(data,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()
 if digest!=contract['habitat']['sha256']:p.error('The native habitat differs from this build. Regenerate the contracts and rebuild before launching.')
 paths=[ROOT/'simulation/build-planet/Release/cybernet_sim.exe',ROOT/'simulation/build-planet/cybernet_sim.exe',ROOT/'simulation/build-planet/cybernet_sim']
 exe=a.executable.resolve() if a.executable else next((v for v in paths if v.is_file()),None)
 if exe is None or not exe.is_file():p.error('Build simulation/build-planet first; see START_HERE.md. An old build-pgo executable is not compatible.')
 if not 1<=a.ticks<=4294967295:p.error('--ticks must be between 1 and 4294967295')
 command=[str(exe),'--headless','--benchmark-ticks',str(a.ticks),'--live-dir',str(runtime),'--island-surface',str(ROOT/'contracts/planet_surface.txt'),'--geometry','lake','--optics','v2','--archive-dir',str(ROOT/'runtime/planet-archives')]
 print('Planet habitat:',digest,flush=True)
 try:return subprocess.call(command,cwd=ROOT)
 except KeyboardInterrupt:return 130
if __name__=='__main__':sys.exit(main())
