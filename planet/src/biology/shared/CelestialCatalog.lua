--!nonstrict
-- Visual-only, versioned fictional system. Never consumes the biological RNG.
local C={Version="celestial-1",Seed=271828,DisplayDistance=12000}
C.Bodies={
 {id="Moon",kind="moon",radius=.85,distance=60,period=11,phase=math.pi,inclination=.08,spin=.12,color=Color3.fromRGB(190,193,204)},
 {id="Aureole",kind="gas",radius=10,distance=420,period=37,phase=1.1,inclination=.22,spin=.45,color=Color3.fromRGB(194,158,112)},
 {id="Pelagic",kind="rock",radius=3,distance=280,period=23,phase=4.2,inclination=-.18,spin=.27,color=Color3.fromRGB(83,144,168)},
 {id="Cinder",kind="moon",radius=.26,distance=44,period=7,phase=5.3,inclination=-.31,spin=.19,color=Color3.fromRGB(172,140,124)},
 {id="FragmentA",kind="asteroid",radius=.045,distance=19,period=5,phase=2.3,inclination=.13,spin=.8,color=Color3.fromRGB(135,124,113)},
 {id="FragmentB",kind="asteroid",radius=.035,distance=23,period=6,phase=2.42,inclination=.16,spin=-.6,color=Color3.fromRGB(151,141,127)},
}
function C.position(body,cycles,east,up)
 local north=east:Cross(up).Unit
 -- One rotation per planetary day plus slower relative orbital motion.
 local a=cycles*2*math.pi*(1-1/body.period)+body.phase
 local direction=east*math.cos(a)+(up*math.cos(body.inclination)+north*math.sin(body.inclination))*math.sin(a)
 return direction*body.distance
end
function C.apparent(body,cycles,east,up,observerInRadii)
 local delta=C.position(body,cycles,east,up)-observerInRadii
 return delta.Unit,math.asin(math.clamp(body.radius/delta.Magnitude,0,.08))
end
function C.surface(body,n)
 local noise=math.noise(n.X*7+body.phase,n.Y*7,n.Z*7)
 local shade=.85+noise*.25
 if body.kind=="gas" then shade=.8+.18*math.sin(n.Y*38+noise*4)
 elseif body.kind=="rock" then shade=.65+.4*math.clamp(noise*3+.5,0,1)
 else shade=.72+.3*math.clamp(noise*2+.5,0,1)end
 return Color3.new(body.color.R*shade,body.color.G*shade,body.color.B*shade)
end
return C
