"""Patch four reviewed script sources in the supplied saved place. Preserve all other bytes."""
import argparse,hashlib,json,struct,sys
from pathlib import Path
import zstandard
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from build_planet import chunks,string,ids
TARGETS={
 26:'planet/src/world/StarterPlayer/StarterPlayerScripts/CI_PlanetPlayer.client.lua',
 32:'planet/src/biology/client/Aquatic.client.lua',
 121:'planet/src/biology/shared/AquaticProtocol.lua',
 122:'planet/src/biology/shared/AquaticModels.lua',
}
def patch(world,output,expected):
 original=world.read_bytes()
 assert hashlib.sha256(original).hexdigest()==expected['worldSha256'],'Unexpected world: refusing to patch'
 blocks=list(chunks(original));classes={};changes={}
 for tag,d,raw in blocks:
  if tag==b'INST':
   cid=struct.unpack_from('<I',d)[0];_,o=string(d,4);n=struct.unpack_from('<I',d,o+1)[0];classes[cid]=ids(d[o+5:o+5+4*n],n)
 for tag,d,raw in blocks:
  if tag!=b'PROP':continue
  cid=struct.unpack_from('<I',d)[0];name,o=string(d,4);typ=d[o];o+=1
  if name!='Source' or typ!=1:continue
  for rid in classes[cid]:
   text,o=string(d,o)
   if rid in TARGETS:
    assert hashlib.sha256(text.encode()).hexdigest()==expected['scripts'][str(rid)],'Source baseline mismatch'
    changes[rid]=(ROOT/TARGETS[rid]).read_text()
 assert set(changes)==set(TARGETS),'Missing target script'
 result=bytearray(original[:32]);modified=0
 for tag,d,raw in blocks:
  if tag!=b'PROP':result+=raw;continue
  cid=struct.unpack_from('<I',d)[0];name,o=string(d,4);typ=d[o];o+=1
  if name!='Source' or typ!=1 or not any(i in changes for i in classes[cid]):result+=raw;continue
  body=bytearray(d[:o])
  for rid in classes[cid]:
   old,o=string(d,o);new=changes.get(rid,old).encode();body+=struct.pack('<I',len(new))+new
  assert o==len(d)
  compressed=zstandard.ZstdCompressor(level=3).compress(body);result+=struct.pack('<4sIII',tag,len(compressed),len(body),0)+compressed;modified+=1
 rebuilt=list(chunks(bytes(result)));assert len(blocks)==len(rebuilt)
 for (ta,da,ra),(tb,db,rb) in zip(blocks,rebuilt):
  assert ta==tb
  if ra==rb:continue
  assert ta==b'PROP';cid=struct.unpack_from('<I',da)[0];na,oa=string(da,4);nb,ob=string(db,4);assert na==nb=='Source';oa+=1;ob+=1
  for rid in classes[cid]:
   before,oa=string(da,oa);after,ob=string(db,ob);assert after==changes.get(rid,before),'Unintended script change'
 output.parent.mkdir(parents=True,exist_ok=True);output.write_bytes(result)
 report={'inputSha256':hashlib.sha256(original).hexdigest(),'outputSha256':hashlib.sha256(result).hexdigest(),'changedSources':TARGETS,'changedChunks':modified,'totalChunks':len(blocks),'allOtherChunksByteIdentical':True,'studioVisualValidation':False}
 output.with_suffix('.verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--world',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 patch(a.world,a.output,json.loads((ROOT/'docs/pdnarna/world-baseline.json').read_text()))
