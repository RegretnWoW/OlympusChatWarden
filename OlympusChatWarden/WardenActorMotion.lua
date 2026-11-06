-- Continuous skeletal poses. Textures stay bound; joints move at elapsed time.
local _,ns=...;local G=ns.WardenSceneGraph;local previous=G.Pose
local pi=math.pi;local rad=pi/180
local function envelope(t,seconds)return math.sin(pi*math.min(1,math.max(0,t)/seconds))^2 end
function G.Pose(kind,state,t,phase,cycleTime,weight)
 t=math.max(0,t or 0);local loop=cycleTime or t;local p={root={}}
 if kind=='cat'then
  local breathing=math.sin(loop*1.15)*.002
  p.body={y=-breathing};p.head={};p.paw={};p.pawFar={};p.tail={angle=math.sin(loop*.48)*2*rad}
  p.ear={angle=math.max(0,math.sin(loop*.57))^18*7*rad};p.earFar={angle=-math.max(0,math.sin(loop*.57+.15))^20*3*rad}
  local blink=(loop%8.6);local alpha=blink>8.18 and math.min(1,(blink-8.18)/.12,(8.6-blink)/.13)or 0
  if state=='sleep'or state=='rest'then alpha=math.min(1,t/.16)end
  p.lids={alpha=math.max(0,alpha),hidden=alpha<=0}
  if state=='alert'or state=='react'then local q=envelope(t,5);p.head={angle=-8*rad*q,y=-.025*q};p.ear.angle=-8*rad*q;p.earFar.angle=4*rad*q;p.lids={alpha=1-math.min(1,t/.10),hidden=t>=.10}
  elseif state=='stretch'then local q=envelope(t,6);p.paw={x=.045*q,y=.004*q,angle=-4*rad*q};p.pawFar={x=.020*q};p.head={x=.018*q,y=-.025*q,angle=-11*rad*q};p.tail.angle=p.tail.angle+6*rad*q
  elseif state=='groom'then local q=envelope(t,7);p.paw={y=-.070*q,angle=-18*rad*q};p.head={angle=(8+math.sin(t*3)*2)*rad*q,y=.009*q};p.lids={alpha=math.min(1,t/.16),hidden=false}end
  return p
 elseif kind=='owl'or kind=='bird'or kind=='moth'then
  local flight=state=='traverse'or state=='flight'or state=='takeoff'or state=='landing'
  if kind=='owl'and not flight then p=previous(kind,state,t,phase,cycleTime,weight);p.root.angle=0;p.flightBody={hidden=true};p.wingNear={hidden=true};p.wingFar={hidden=true};return p end
  local speed=kind=='owl'and 1.35 or kind=='bird'and 3.0 or 4.1
  local q=(loop*speed)%1
  -- Faster power stroke, slower feathered recovery; continuous across states.
  local stroke=q<.38 and G.Ease(q/.38)or 1-G.Ease((q-.38)/.62)
  local angle=(63-105*stroke)*rad
  local fold=.12+.32*(1-stroke)
  if kind=='moth'then angle=math.sin(loop*1.8)*4*rad;fold=.18+(1-stroke)*1.20 end
  p.wingFar={angle=angle*.93,fold=fold+.05};p.wingNear={angle=angle,fold=fold}
  p.root.y=math.sin(loop*speed*pi*2)*.003
  if kind=='owl'then
   p.body={hidden=true};p.head={hidden=true};p.feet={hidden=true};p.lids={hidden=true};p.flightBody={}
  end
  return p
 elseif kind=='fox'or kind=='rabbit'or kind=='stag'then
  local walk=state=='traverse'or state=='move';local amount=walk and math.max(0,math.min(1,weight or 1))or 0
  local q=(loop%1)*pi*2;local near=math.sin(q);local far=math.sin(q+pi)
  for _,entry in ipairs({{'legNear',near},{'legFar',far},{'legNear2',far},{'legFar2',near}})do
   local v=entry[2]*amount;local a=v*(kind=='rabbit'and .32 or .24)
   p[entry[1]]={angle=a,y=.39*(1-math.cos(a))-.025*math.max(0,v)}
  end
  p.head={angle=walk and math.sin(q)*.4*rad or math.sin(t*.4)*1.5*rad};p.tail={angle=math.sin(t*.8)*2*rad}
  -- Ground actors have a fixed contact baseline. Rabbit hops use a bounded
  -- ballistic arc with compression at contact, not a floating sinusoid.
  if kind=='rabbit'and amount>0 then local f=loop%1;p.root.y=-.055*4*f*(1-f)*amount else p.root.y=-math.abs(math.sin(q))*.004*amount end
  return p
 end
 return previous(kind,state,t,phase,cycleTime,weight)
end
