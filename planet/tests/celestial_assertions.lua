local field=Background.build(Sky.FaceSize,Sky.direction)
local fieldAgain=Background.build(Sky.FaceSize,Sky.direction)
local function index(side,i)
 local size=Sky.FaceSize
 if side=="top"then return i+1 end
 if side=="bottom"then return (size-1)*size+i+1 end
 if side=="left"then return i*size+1 end
 return (i+1)*size
end
for _,j in joins do for i=0,Sky.FaceSize-1 do
 local a=field[j[1]][index(j[2],i)]
 local b=field[j[3]][index(j[4],if j[5]then Sky.FaceSize-1-i else i)]
 for _,key in {"r","g","b"}do assert(math.abs(a[key]-b[key])<1e-7,"Background seam on "..j[1].." "..j[2])end
end end
for f=1,6 do for i,p in field[f]do
 close(p.r,fieldAgain[f][i].r);close(p.g,fieldAgain[f][i].g);close(p.b,fieldAgain[f][i].b)
 local u,v=Background.project(f,p.direction)
 local expected=Sky.direction(f,u,v)
 assert((expected-p.direction).Magnitude<1e-8)
end end
for _,body in Catalog.Bodies do for _,cycles in {0,.25,1,100,100000}do
 local d,a=Catalog.apparent(body,cycles,Vector3.xAxis,Vector3.yAxis,Vector3.yAxis)
 close(d.Magnitude,1);assert(a>0 and a<.08)
 local other,b=Catalog.apparent(body,cycles,Vector3.xAxis,Vector3.yAxis,-Vector3.yAxis)
 assert((d-other).Magnitude>0 and b>0)
 local again=Catalog.position(body,cycles,Vector3.xAxis,Vector3.yAxis)
 close(again.Magnitude,body.distance)
 local color=Catalog.surface(body,Vector3.yAxis)
 assert(color.R>=0 and color.R<=1 and color.G>=0 and color.G<=1 and color.B>=0 and color.B<=1)
end end
print("PASS celestial cached background: deterministic, all baked face borders continuous; body angular sizes, checkpoint-time repeatability and observer parallax")
