"""Reproducibly patch only reviewed sources into the exact saved planet baseline.
Usage: python tools/build_planet.py --baseline /path/planet0bc4_glass.rbxl
Requires: pip install -r tools/requirements.txt
"""
from pathlib import Path
import argparse,hashlib,json,struct,re
import zstandard
ROOT=Path(__file__).resolve().parents[1]
def string(d,o):
 n=struct.unpack_from('<I',d,o)[0];return d[o+4:o+4+n].decode(),o+4+n
def ids(d,n):
 values=[];previous=0
 for i in range(n):
  v=int.from_bytes(bytes(d[i+j*n] for j in range(4)),'big');previous+=(v>>1)^-(v&1);values.append(previous)
 return values
def chunks(p):
 off=32
 while off<len(p):
  tag,cs,us,res=struct.unpack_from('<4sIII',p,off);raw=p[off:off+16+(cs or us)];data=p[off+16:off+16+(cs or us)];off+=len(raw)
  if cs:data=zstandard.ZstdDecompressor().decompress(data,max_output_size=us)
  yield tag,data,raw
 assert off==len(p)
def clean_directives(source):
 lines=source.splitlines(keepends=True)
 for i in range(1,len(lines)):
  if re.match(r'^\s*--!(?:strict|nonstrict|nocheck)\s*$',lines[i]):
   lines[i]=lines[i].replace('--!','-- ',1)
 return ''.join(lines)
def compose():
 planet=ROOT/'planet';integration=(planet/'components/Integration.lua').read_text()
 a=integration.index('local Frame=(function()');b=integration.index('\nend)()',a)+len('\nend)()')
 integration=integration[:a]+'local Frame=(function()\n'+(planet/'src/integration/shared/HabitatFrame.lua').read_text()+'\nend)()'+integration[b:]
 bootstrap=(planet/'components/PlayerBootstrapBase.lua').read_text()+'\n-- Generated integration block; see planet/components.\ndo\n'+integration+'\nend\n'
 target=planet/'src/world/ServerScriptService/CI_PlanetPlayer/Bootstrap.server.lua';target.write_text(clean_directives(bootstrap))
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--baseline',type=Path,required=True);parser.add_argument('--output',type=Path,default=ROOT/'dist/planet0bc5_integration_preflight.rbxl');args=parser.parse_args()
 baseline=json.loads((ROOT/'worlds/baseline.json').read_text());p=args.baseline.read_bytes()
 assert hashlib.sha256(p).hexdigest()==baseline['sha256'],'Wrong baseline: refusing to patch'
 compose();source_map=json.loads((ROOT/'planet/source-map.json').read_text());mapped={x['id']:x for x in source_map}
 original=list(chunks(p));classes={};changes={}
 for tag,data,raw in original:
  if tag==b'INST':
   cid=struct.unpack_from('<I',data)[0];name,o=string(data,4);n=struct.unpack_from('<I',data,o+1)[0];classes[cid]=ids(data[o+5:o+5+4*n],n)
 for tag,data,raw in original:
  if tag!=b'PROP':continue
  cid=struct.unpack_from('<I',data)[0];name,o=string(data,4);typ=data[o];o+=1
  if name!='Source' or typ!=1:continue
  for i in classes[cid]:
   old,o=string(data,o)
   if i in mapped:
    assert hashlib.sha256(old.encode()).hexdigest()==mapped[i]['sha256'],'Baseline script mismatch'
    new=(ROOT/'planet'/mapped[i]['source']).read_text()
    if new!=old:changes[i]=new
 assert set(changes)=={26,85,92},'Unexpected source change: explicitly review before packaging'
 result=bytearray(p[:32]);changed_chunks=0
 for tag,data,raw in original:
  if tag==b'PROP':
   cid=struct.unpack_from('<I',data)[0];name,o=string(data,4);typ=data[o];o+=1
   if name=='Source' and typ==1 and any(i in changes for i in classes[cid]):
    body=data[:o]
    for i in classes[cid]:
     old,o=string(data,o);new=changes.get(i,old).encode();body+=struct.pack('<I',len(new))+new
    compressed=zstandard.ZstdCompressor(level=3).compress(body);result+=struct.pack('<4sIII',tag,len(compressed),len(body),0)+compressed;changed_chunks+=1;continue
  result+=raw
 rebuilt=list(chunks(bytes(result)));assert len(rebuilt)==len(original)
 for (a,da,ra),(b,db,rb) in zip(original,rebuilt):
  assert a==b
  if da==db:assert ra==rb
  else:
   assert a==b'PROP';cid=struct.unpack_from('<I',da)[0];na,oa=string(da,4);nb,ob=string(db,4);assert na==nb=='Source';oa+=1;ob+=1
   for i in classes[cid]:
    before,oa=string(da,oa);after,ob=string(db,ob);assert after==changes.get(i,before)
 args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_bytes(result)
 report={'baselineSha256':baseline['sha256'],'outputSha256':hashlib.sha256(result).hexdigest(),'changedInstances':[mapped[i]['instance'] for i in sorted(changes)],'unchangedChunks':len(original)-changed_chunks,'totalChunks':len(original),'terrainAndOtherPropertiesUnchanged':True,'biologyEnabled':False,'nativeStudioVerified':False}
 args.output.with_suffix('.verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
if __name__=='__main__':main()
