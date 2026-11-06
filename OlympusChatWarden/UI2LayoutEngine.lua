-- Local presentation data only. Never contains player IDs, card content or consent.
local _,ns=...
local E={schema=2,maxBytes=65536,maxCards=240,maxUndo=40,templates={}};ns.UI2LayoutEngine=E
local function clone(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=clone(x) end;return t end
E.Copy=clone
local function integer(n,a,b) return type(n)=='number' and n==n and n%1==0 and n>=a and n<=b end
local function plain(v) return type(v)=='table' and not getmetatable(v) end
local function fields(v,allowed) if not plain(v) then return false end;for k in pairs(v) do if not allowed[k] then return false end end;return true end
local function array(t,limit) if not plain(t) or #t>limit then return false end;local n=0;for k in pairs(t) do if not integer(k,1,#t) then return false end;n=n+1 end;return n==#t end
local regions={header=true,left=true,center=true,right=true,main=true}
function E.Register(name,specs)
 assert(not E.templates[name],'Duplicate layout template');local t={cards={},order={}};E.templates[name]=t
 for index,s in ipairs(specs) do
  assert(type(s.id)=='string' and not t.cards[s.id]);s.template=name;s.span=s.span or 6;s.minSpan=s.minSpan or 3;s.maxSpan=s.maxSpan or 12
  s.canMove=s.canMove~=false;s.canResize=s.canResize~=false;s.canHide=s.canHide~=false;s.canCollapse=s.canCollapse~=false
  s.order=index;t.cards[s.id]=s;t.order[#t.order+1]=s.id
 end
end
function E.Template(route)
 route=route or {};local page=route.page or 'overview'
 if page=='intel'and route.subsection=='live-players'then return'intel.live-players'end
 if page=='intel'and route.subsection=='agora'then return'agora'end
 if page=='intel'and route.kind=='player'and route.extension then return 'intel.extension'end
 if page=='intel' then return route.kind=='player' and (route.projection=='public' and 'intel.public' or 'intel.player') or route.kind=='guild' and 'intel.guild' or route.kind=='group' and 'intel.group' or 'intel.browse' end
 if page=='chronicle' then return route.kind=='activity' and 'chronicle.activity' or 'chronicle.browse' end
 if page=='journey' then return 'journey.chrome' end
 if page=='overview' and route.subsection=='search' then return 'overview.search' end
 if page=='settings' and route.sourceEvent then return 'settings.inspector' end
 if page=='settings' and (route.subsection=='help' or route.subsection=='updates' or route.subsection=='collection-help') then return 'settings.help' end
 return E.templates[page] and page or 'overview'
end
function E.Default(name)
 local spec=assert(E.templates[name]);local out={columns={3,6,3},cards={}}
 for n,id in ipairs(spec.order) do local s=spec.cards[id];out.cards[n]={id=id,region=s.region or 'main',order=n,span=s.span,hidden=false,collapsed=false} end
 local authored=ns.UI2DefaultLayouts and ns.UI2DefaultLayouts.templates[name]
 if authored then local checked=E.ValidateLayout(name,authored,true);if checked then out=checked end end
 return out
end
function E.Migrate(name,value)
 local v=clone(value);if not plain(v) or not plain(v.cards) then return v end
 for _,c in ipairs(v.cards) do local cs=plain(c) and E.templates[name].cards[c.id];if cs and cs.region=='header' and not cs.canMove then c.region='header';c.order=cs.order;c.span=12 end end
 return v
end
function E.ValidateLayout(name,value,complete)
 local spec=E.templates[name];if not spec or not fields(value,{columns=true,cards=true}) or not array(value.columns,3) or #value.columns<1 or not array(value.cards,E.maxCards) then return nil,'Invalid layout structure' end
 local total=0;for _,span in ipairs(value.columns) do if not integer(span,1,12) then return nil,'Invalid columns' end;total=total+span end;if total~=12 then return nil,'Columns must total 12' end
 local out={columns=clone(value.columns),cards={}};local seen={}
 for _,card in ipairs(value.cards) do
  if not fields(card,{id=true,region=true,order=true,span=true,hidden=true,collapsed=true}) then return nil,'Unexpected card field' end
  local s=spec.cards[card.id];if not s or seen[card.id] then return nil,'Unknown or duplicate card ID' end;seen[card.id]=true
  if not regions[card.region] or not integer(card.order,1,E.maxCards) or not integer(card.span,s.minSpan,s.maxSpan) or type(card.hidden)~='boolean' or card.collapsed~=nil and type(card.collapsed)~='boolean' then return nil,'Invalid card placement' end
  if not s.canHide and card.hidden or not s.canCollapse and card.collapsed then return nil,'Protected card cannot be hidden or collapsed' end
  if not s.canResize and card.span~=s.span or not s.canMove and (card.region~=(s.region or 'main') or card.order~=s.order) then return nil,'Protected card placement' end
  out.cards[#out.cards+1]={id=card.id,region=card.region,order=card.order,span=card.span,hidden=card.hidden,collapsed=card.collapsed==true}
 end
 if complete then for n,id in ipairs(spec.order) do if not seen[id] then local s=spec.cards[id];out.cards[#out.cards+1]={id=id,region=s.region or 'main',order=n,span=s.span,hidden=false,collapsed=false} end end end
 return out
end
local function root()
 assert(type(ns.DB)=='table','Settings not initialized')
 local v=ns.DB.ui2Layouts
 if plain(v) and v.schema==1 and plain(v.templates) then v.schema=2;v.subjects={};v.recovery={'Layout1 preferences retained; main cards now stack in the center lane.'} end
 if not fields(v,{schema=true,revision=true,templates=true,recovery=true,subjects=true}) or v.schema~=E.schema or not plain(v.templates) or not integer(v.revision,1,100000) then
  -- Bounded recovery metadata, never retain arbitrary malformed/user content.
  local had=v~=nil;v={schema=E.schema,revision=1,templates={},recovery=had and {'Invalid layout preferences replaced; recording and other settings retained.'} or {}};ns.DB.ui2Layouts=v
 end
 return v
end
E.Root=root
-- Navigation is a local presentation preference in the existing layout store.
-- Stable route IDs are retained; unknown/duplicate entries cannot remove tabs.
E.navigationDefaults={'overview','journey','intel','wiki','chronicle','messages','shield','mentions','settings'}
function E.TabOrder(value)
 local allowed,seen,out={},{},{}
 for _,id in ipairs(E.navigationDefaults) do allowed[id]=true end
 if plain(value) then for n=1,math.min(#value,40) do local id=value[n];if allowed[id] and not seen[id] then out[#out+1]=id;seen[id]=true end end end
 for _,id in ipairs(E.navigationDefaults) do if not seen[id] then out[#out+1]=id end end
 return out
end
local function navOwner() return ns.Chronicle and ns.Chronicle.Owner() or 'account' end
function E.NavigationOrder()
 local db=root();local prefs=plain(db.templates.__navigation) and db.templates.__navigation or {}
 return E.TabOrder(prefs[navOwner()])
end
function E.SaveNavigation(value)
 local db=root();if not plain(db.templates.__navigation) then db.templates.__navigation={} end
 db.templates.__navigation[navOwner()]=E.TabOrder(value);db.revision=db.revision%99999+1;return true
end
function E.ResetNavigation()
 local db=root();if plain(db.templates.__navigation) then db.templates.__navigation[navOwner()]=nil end
 db.revision=db.revision%99999+1;return true
end
function E.Get(name)
 local db=root();local value=db.templates[name];if not value then return E.Default(name),false end
 -- Saved old layouts can contain retired IDs. Drop only those IDs and merge new cards.
 if not fields(value,{columns=true,cards=true}) or not array(value.cards,E.maxCards) then db.templates[name]=nil;db.recovery={'Invalid saved template reset: '..name};return E.Default(name),false end
 local filtered=clone(value);filtered.cards={};local spec=E.templates[name]
 for _,c in ipairs(value.cards) do if plain(c) and spec.cards[c.id] then filtered.cards[#filtered.cards+1]=c end end
 filtered=E.Migrate(name,filtered);local clean,why=E.ValidateLayout(name,filtered,true)
 if not clean then db.templates[name]=nil;db.recovery={'Invalid saved template reset: '..name..' ('..why..')'};return E.Default(name),false end
 return clean,true
end
function E.Save(name,value)
 local clean,why=E.ValidateLayout(name,value,true);if not clean then return false,why end
 local db=root();db.templates[name]=clean;db.revision=db.revision+1;return true
end
function E.Reset(name) local db=root();if name then db.templates[name]=nil else db.templates={} end;db.revision=db.revision+1;return true end
function E.Begin(name)
 local layout=E.Get(name);return {template=name,layout=clone(layout),original=clone(layout),undo={},dirty=false}
end
function E.Push(tx) tx.undo[#tx.undo+1]={layout=clone(tx.layout),theme=tx.theme};while #tx.undo>E.maxUndo do table.remove(tx.undo,1) end end
function E.Change(tx,id,changes)
 if not tx or not plain(changes) then return false,'No editor transaction' end
 local nextLayout=clone(tx.layout);local found
 for _,card in ipairs(nextLayout.cards) do if card.id==id then for k,v in pairs(changes) do card[k]=v end;found=true;break end end
 if not found then return false,'Card not registered' end
 local checked,why=E.ValidateLayout(tx.template,nextLayout,true);if not checked then return false,why end
 E.Push(tx);tx.layout=checked;tx.dirty=true;return true
end
function E.Undo(tx) if not tx or #tx.undo==0 then return false end;local v=table.remove(tx.undo);tx.layout=v.layout or v;if v.layout then tx.theme=v.theme end;tx.dirty=E.JSON(tx.layout)~=E.JSON(tx.original) or tx.theme~=tx.originalTheme;return true end
function E.Commit(tx) return E.Save(tx.template,tx.layout) end
function E.Columns(tx,columns)
 local v=clone(tx.layout);v.columns=columns
 local widths={left=columns[1],center=columns[2] or columns[1],right=columns[3] or columns[2] or columns[1]}
 for _,c in ipairs(v.cards) do local s=E.templates[tx.template].cards[c.id];if s.canResize and c.span<12 and widths[c.region] then c.span=math.max(s.minSpan,math.min(s.maxSpan,widths[c.region])) end end
 local clean,why=E.ValidateLayout(tx.template,v,true);if not clean then return false,why end
 E.Push(tx);tx.layout=clean;tx.dirty=true;return true
end
function E.Order(layout)
 local out=clone(layout.cards);table.sort(out,function(a,b) if a.region=='header' and b.region~='header' then return true elseif b.region=='header' and a.region~='header' then return false end;return a.order<b.order or a.order==b.order and a.id<b.id end);return out
end
-- Named vertical lanes. Responsive views project the saved arrangement only.
function E.Lane(c) return c.region=='main' and 'center' or c.region end
function E.Lanes(layout,width,viewport)
 local n=math.min(#layout.columns,3)
 local out={};local names=n==3 and {'left','center','right'} or n==2 and {'left','center'} or {'center'}
 local spans=n==3 and layout.columns or n==2 and (#layout.columns==2 and layout.columns or {4,8}) or {12};local x=0
 for i,name in ipairs(names) do local w=width*spans[i]/12;out[#out+1]={name=name,x=x,w=w-12};x=x+w end
 return out,n
end
function E.ProjectLane(region,n)
 region=region=='main' and 'center' or region
 return n==1 and 'center' or n==2 and region=='right' and 'left' or region
end
function E.Solve(name,blocks,width,measure,override,editing,viewportWidth)
 width=math.max(280,width or 1000);local layout=override or (E.Resolve and E.Resolve(name) or E.Get(name));local spec=assert(E.templates[name]);local byID={}
 for _,b in ipairs(blocks) do assert(b.id and spec.cards[b.id],'Unregistered UI2 card: '..tostring(name)..'/'..tostring(b.id));assert(not byID[b.id],'Duplicate UI2 card: '..b.id);byID[b.id]=b end
 local lanes,n=E.Lanes(layout,width,viewportWidth);local laneBy={};for _,l in ipairs(lanes) do l.y=0;laneBy[l.name]=l end
 local out={};local headerY=0
 local function place(c,b,x,y,w,lane)
  local h=c.collapsed and not editing and 40 or measure(b,w);h=math.max(44,h)
  local placed={};for k,v in pairs(b) do placed[k]=v end
  placed.grid={x=x,y=y,w=w,h=h,lane=lane};placed.layout=clone(c);placed.collapsed=not editing and c.collapsed;out[#out+1]=placed
  return y+h+12
 end
 for _,c in ipairs(E.Order(layout)) do local b=byID[c.id];local cs=spec.cards[c.id]
  if editing and not b and not cs.system then b={id=c.id,title=cs.label,rows={{title='No content yet. This section keeps its position when content arrives.',wrap=true,height=65}},placeholder=true} end
  if b and (editing or not c.hidden) then
   if E.Lane(c)=='header' then headerY=place(c,b,0,headerY,width-12,'header')
   else local lane=laneBy[E.ProjectLane(E.Lane(c),n)];lane.y=place(c,b,lane.x,math.max(lane.y,headerY+(editing and 22 or 0)),lane.w,lane.name) end
  end
 end
 -- Guides stay available even for completely empty lanes.
 for _,l in ipairs(lanes) do l.top=headerY;l.y=math.max(headerY,l.y) end
 return out,n,lanes
end
-- Strict JSON codec: bounded depth, duplicate rejection and no executable input.
local function quote(s) return '"'..s:gsub('[%z\1-\31\\"]',function(c) return string.format('\\u%04x',c:byte()) end)..'"' end
function E.JSON(v)
 if type(v)=='string' then return quote(v) elseif type(v)=='boolean' then return v and 'true' or 'false' elseif type(v)=='number' then assert(integer(v,0,100000));return tostring(v) end
 assert(plain(v));local out={};if #v>0 then for _,x in ipairs(v) do out[#out+1]=E.JSON(x) end;return '['..table.concat(out,',')..']' end
 local keys={};for k in pairs(v) do assert(type(k)=='string');keys[#keys+1]=k end;table.sort(keys);for _,k in ipairs(keys) do out[#out+1]=quote(k)..':'..E.JSON(v[k]) end;return '{'..table.concat(out,',')..'}'
end
function E.Parse(text)
 assert(type(text)=='string' and #text<=E.maxBytes,'Layout pack exceeds 64 KiB');local p,nodes=1,0
 local function space() local _,last=text:find('^[ \r\n\t]*',p);p=(last or p-1)+1 end
 local function str()
  assert(text:sub(p,p)=='"');p=p+1;local out={};local size=0
  while p<=#text do local c=text:sub(p,p);p=p+1;if c=='"' then return table.concat(out) end
   if c=='\\' then c=text:sub(p,p);p=p+1;local map={['"']='"',['\\']='\\',['/']='/',b='\8',f='\12',n='\n',r='\r',t='\t'}
    if c=='u' then local hex=text:sub(p,p+3);assert(hex:match('^%x%x%x%x$'));local code=tonumber(hex,16);assert(code<128,'Only ASCII layout identifiers are accepted');c=string.char(code);p=p+4 else c=assert(map[c],'Invalid JSON escape') end
   else assert(c:byte()>=32) end
   size=size+#c;assert(size<=180);out[#out+1]=c
  end;error('Unterminated string')
 end
 local value
 value=function(depth)
  nodes=nodes+1;assert(depth<9 and nodes<6000,'Layout nesting/item limit');space();local c=text:sub(p,p)
  if c=='"' then return str() elseif c=='{' or c=='[' then
   p=p+1;space();local close=c=='{' and '}' or ']';local out={};if text:sub(p,p)==close then p=p+1;return out end
   repeat local key;if c=='{' then key=str();assert(out[key]==nil,'Duplicate JSON key');space();assert(text:sub(p,p)==':');p=p+1 else key=#out+1 end
    out[key]=value(depth+1);space();local token=text:sub(p,p);p=p+1;if token==close then return out end;assert(token==',');space()
   until false
  elseif text:sub(p,p+3)=='true' then p=p+4;return true elseif text:sub(p,p+4)=='false' then p=p+5;return false end
  local number=text:match('^%d+',p);assert(number and #number<7,'Unsupported JSON value');p=p+#number;return tonumber(number)
 end
 local out=value(0);space();assert(p==#text+1,'Trailing layout text');return out
end
function E.Checksum(text) local a,b=1,0;for n=1,#text do a=(a+text:byte(n))%65521;b=(b+a)%65521 end;return string.format('%08x',b*65536+a) end
function E.Export(name,override)
 local templates={};if name then templates[name]=override or (E.CreatorLayout and E.CreatorLayout(name) or E.Get(name)) else for key in pairs(E.templates) do templates[key]=E.CreatorLayout and E.CreatorLayout(key) or E.Get(key) end end
 local body={schema=2,addon='OlympusWarden',type='LOCAL_LAYOUT_ONLY',defaultRevision=ns.UI2DefaultLayouts.revision,templates=templates}
 local canonical=E.JSON(body);body.checksum=E.Checksum(canonical);local wire=E.JSON(body);assert(#wire<=E.maxBytes);return wire
end
function E.Import(text)
 local ok,pack=pcall(E.Parse,text);if not ok then return nil,'Invalid layout JSON: '..tostring(pack) end
 if not fields(pack,{schema=true,addon=true,type=true,defaultRevision=true,templates=true,checksum=true}) or (pack.schema~=1 and pack.schema~=2) or pack.addon~='OlympusWarden' or pack.type~='LOCAL_LAYOUT_ONLY' or type(pack.defaultRevision)~='string' or #pack.defaultRevision>80 or not plain(pack.templates) or type(pack.checksum)~='string' then return nil,'Not a supported layout pack' end
 local checksum=pack.checksum;pack.checksum=nil;if E.Checksum(E.JSON(pack))~=checksum then return nil,'Layout checksum mismatch' end
 local clean,count={},0;for name,value in pairs(pack.templates) do if not E.templates[name] then return nil,'Unknown template: '..tostring(name) end;local v,why=E.ValidateLayout(name,pack.schema==1 and E.Migrate(name,value) or value,true);if not v then return nil,why..' ('..name..')' end;clean[name]=v;count=count+1 end
 if count==0 or count>24 then return nil,'Invalid template count' end
 return {templates=clean,count=count,revision=pack.defaultRevision}
end
function E.ApplyImport(pack)
 if not plain(pack) or not plain(pack.templates) then return false,'No reviewed layout pack' end
 local checked={};for name,v in pairs(pack.templates) do local c,why=E.ValidateLayout(name,v,true);if not c then return false,why end;checked[name]=c end
 local db=root();local nextTemplates=clone(db.templates);for name,v in pairs(checked) do nextTemplates[name]=v end;db.templates=nextTemplates;db.revision=db.revision+1;return true
end
