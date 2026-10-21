"""Generate C++ and Roblox contracts from the validated native Studio survey."""
from pathlib import Path
import sys,json,hashlib,math
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'archive/python-relay'))
from planet_channel import validate_habitat

def generate():
 raw=(ROOT/'contracts/planet_habitat.json').read_bytes();q=json.loads(raw);validate_habitat(q)
 digest=hashlib.sha256(json.dumps(q,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()
 cells={(x,y):h for x,y,h in q['water']['cells']};grid=q['water']['grid']
 x0=(min(x for x,y in cells)-1)*grid;y0=(min(y for x,y in cells)-1)*grid
 nx=max(x for x,y in cells)-min(x for x,y in cells)+3;ny=max(y for x,y in cells)-min(y for x,y in cells)+3
 depth=math.ceil((-min(cells.values())+2)/4)*4;bounds=[(nx-1)*grid,(ny-1)*grid,depth]
 # Conservative 3x3 upper envelope; 1 stud clearance over sampled native floor.
 # Dry/outside vertices stay above water. No unobserved region becomes habitat.
 heights=[]
 for y in range(ny):
  for x in range(nx):
   ix,iy=x+x0//grid,y+y0//grid
   h=max(cells.get((ix+dx,iy+dy),8) for dx in (-1,0,1) for dy in (-1,0,1))+1
   heights.append(round(h+depth,6))
 habitat={'id':q['id'],'sha256':digest,'dataset':q['dataset'],'frame':q['frame'],'origin':[x0,y0],'depth':depth,'units':'stud','land':{k:v for k,v in q['land'].items() if k!='cells'}}
 geometry={'version':4,'revision':'planet-lake-1','sha256':digest,'bodyRadius':.25,'bounds':bounds,'objects':[], 'terrain':{'planes':[],'heightfield':{'nx':nx,'ny':ny,'cell':grid,'heights':heights}},'habitat':habitat}
 out=ROOT/'simulation/include/cybernet/world';out.mkdir(parents=True,exist_ok=True)
 land=q['land'];surface_id='planet-'+digest[:32]
 constants=f'''#pragma once
namespace cybernet::planet_contract {{
inline constexpr float Width={bounds[0]}.0F,Length={bounds[1]}.0F,Depth={depth}.0F;
inline constexpr float OriginEast={x0}.0F,OriginNorth={y0}.0F;
inline constexpr unsigned LandWidth={land['nx']},LandHeight={land['ny']};
inline constexpr double LandX={land['origin'][0]},LandZ={land['origin'][1]},LandCell={land['spacing']};
inline constexpr const char* Digest="{digest}";
inline constexpr const char* Surface="{surface_id}";
}}
'''
 (out/'planet_contract_generated.hpp').write_text(constants)
 f=lambda v:format(float(v),'.9f')+'F'
 header='#pragma once\n#include "cybernet/world/geometry.hpp"\n#include "cybernet/world/planet_contract_generated.hpp"\nnamespace cybernet::planet_geometry {\ninline constexpr const char* Digest=planet_contract::Digest;\n'
 header+='inline constexpr Vec3 Bounds{'+','.join(f(v) for v in bounds)+'};\n'
 header+=f'inline constexpr std::array<float,{len(heights)}> Heights{{{{'+','.join(f(v) for v in heights)+'}};\n'
 header+=f'inline const Heightfield Field{{{nx},{ny},{grid},Heights}};\ninline constexpr std::array<GeometryObject,0> Objects{{}};\n'
 header+='inline constexpr const char* Json=R"PLANET('+json.dumps(geometry,separators=(',',':'))+')PLANET";\n}\n'
 (out/'planet_geometry_generated.hpp').write_text(header)
 (ROOT/'contracts/planet_geometry.json').write_text(json.dumps(geometry,separators=(',',':')))
 text=f"CIPLANTSURFACE1 {surface_id} {land['nx']} {land['ny']} {land['origin'][0]} {land['origin'][1]} {land['spacing']}\n"
 text+=''.join(f'{h:.8f} 8 20 8 {int(valid)}\n' for h,slope,valid in land['cells'])
 (ROOT/'contracts/planet_surface.txt').write_text(text)
 info={'habitat':habitat,'bounds':bounds,'nx':nx,'ny':ny,'surface':surface_id}
 folder=ROOT/'planet/src/biology/shared';folder.mkdir(parents=True,exist_ok=True)
 (folder/'PlanetContract.lua').write_text('--!nonstrict\n-- Generated from native Studio terrain. Run tools/generate_planet_contract.py to rebuild.\nreturn game:GetService("HttpService"):JSONDecode([==['+json.dumps(info,separators=(',',':'))+']==])\n')
 (ROOT/'contracts/identity.json').write_text(json.dumps(info,indent=2))
 print(json.dumps({'digest':digest,'bounds':bounds,'field':[nx,ny],'nativePlantSites':sum(c[2] for c in land['cells']),'safetyEnvelopeStuds':1},indent=2))
if __name__=='__main__':generate()
