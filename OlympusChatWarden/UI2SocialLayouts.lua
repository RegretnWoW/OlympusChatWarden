-- Presentation preferences only. Canonical profiles/events, consent and the
-- Aether ledger are never written here. No transport or ownership proof is added.
local _,ns=...
local E=ns.UI2LayoutEngine
E.palette={navy={label='Olympus Navy',bg={.082,.149,.251,1},fg={.96,.93,.86,1}},
 aegean={label='Aegean Blue',bg={.141,.271,.408,1},fg={.96,.93,.86,1}},
 purple={label='Royal Purple',bg={.259,.204,.337,1},fg={.96,.93,.86,1}},
 obsidian={label='Obsidian',bg={.125,.137,.173,1},fg={.96,.93,.86,1}},
 bronze={label='Bronze',bg={.349,.271,.20,1},fg={.96,.93,.86,1}},
 marble={label='Marble',bg={.898,.859,.80,1},fg={.055,.078,.104,1}}}
E.paletteOrder={'navy','aegean','purple','obsidian','bronze','marble'}
local function guid(v) return type(v)=='string' and #v<=100 and v:match('^Player%-[%w%-]+$') end
local function plain(v) return type(v)=='table' and not getmetatable(v) end
local function allowed(t,keys) if not plain(t) then return false end;for k in pairs(t) do if not keys[k] then return false end end;return true end
local function social(template) return template=='intel.player' or template=='intel.public' or template=='intel.guild' end
function E.Entitlement(route,template)
 route=route or {};template=template or E.Template(route)
 if template=='intel.player' or template=='intel.public' then
  -- UnitGUID and realm are re-read on every edit/save. Names, model.self,
  -- cached claims and fixture owns() callbacks are deliberately not consulted.
  local owner=ns.Permissions.Owner();local own=owner and owner:match('/(Player%-.+)$')
  if guid(own) and route.key==own and (not route.owner or route.owner==owner) then return {kind='CHARACTER',key=own,owner=owner,source='LOCAL_GUID',scope='PRIVATE_NOT_PUBLISHED'} end
  return nil,'Only this GUID-bound character may edit its private profile design.'
 elseif template=='intel.guild' or route.originGuild then
  return nil,'Guild design editing awaits an approved guild leadership authority. Names, rank labels and cached claims cannot grant it.'
 end
 return {kind='WORKSPACE',source='LOCAL_WORKSPACE'}
end
function E.Scope(route,template)
 route=route or {};template=template or E.Template(route)
 if social(template) then return {kind=template=='intel.guild' and 'GUILD' or 'CHARACTER',key=route.key,template=template} end
 if template=='chronicle.activity' and route.originGuild then return {kind='GUILD',key=route.originGuild,template='chronicle.activity'} end
end
local function records()
 local root=E.Root();if root.subjects==nil then root.subjects={} end
 if not plain(root.subjects) then return nil,'Presentation drafts unavailable; malformed data retained.' end
 local n=0;for _ in pairs(root.subjects) do n=n+1;if n>24 then return nil,'Presentation draft limit exceeded.' end end
 return root.subjects
end
local function valid(row,kind,key)
 if not allowed(row,{schema=true,kind=true,key=true,owner=true,source=true,scope=true,revision=true,templates=true,theme=true}) or row.schema~=1 or row.kind~=kind or row.key~=key or row.scope~='PRIVATE_NOT_PUBLISHED' or row.source~='LOCAL_GUID' or type(row.owner)~='string' or not guid(row.owner:match('/(Player%-.+)$')) or not E.palette[row.theme] or type(row.revision)~='number' or row.revision%1~=0 or row.revision<1 or row.revision>100000 or not plain(row.templates) then return end
 local count=0;for name,value in pairs(row.templates) do count=count+1;if count>3 or not (kind=='CHARACTER' and (name=='intel.player' or name=='intel.public') or kind=='GUILD' and (name=='intel.guild' or name=='chronicle.activity')) or not E.ValidateLayout(name,value,true) then return end end
 return row
end
function E.PrivateDesign(route,template)
 local scope=E.Scope(route,template);local entitlement=E.Entitlement(route,template)
 if not scope or not entitlement or entitlement.kind=='WORKSPACE' or entitlement.key~=scope.key then return end
 local rows=records();local row=rows and rows[scope.kind..'/'..scope.key]
 if valid(row,scope.kind,scope.key) and row.owner==entitlement.owner then return E.Copy(row) end
end
function E.Resolve(name,route,model)
 route=route or ns.UI2 and ns.UI2.route or {};local scope=E.Scope(route,name)
 if not scope then return E.Get(name) end
 -- A foreign viewer never applies account-wide workspace edits to a person's
 -- public design. No authenticated layout record exists in the current native
 -- protocol, so foreign and guild-context views safely use shipped defaults.
 local own=E.PrivateDesign(route,name);local value=own and own.templates[scope.template]
 return value and E.Copy(value) or E.Default(name)
end
function E.SaveScoped(tx)
 if not tx.scope then return E.Commit(tx) end
 local proof,why=E.Entitlement(tx.route,tx.template)
 if not proof or proof.kind~=tx.scope.kind or proof.key~=tx.scope.key or proof.owner~=tx.owner then return false,why or 'Ownership changed; no draft was saved.' end
 local clean,reason=E.ValidateLayout(tx.template,tx.layout,true);if not clean then return false,reason end
 local rows;rows,reason=records();if not rows then return false,reason end
 local key=proof.kind..'/'..proof.key;local old=rows[key]
 if old~=nil and not valid(old,proof.kind,proof.key) then return false,'Existing presentation draft is invalid; retained without overwriting.' end
 local count=0;for _ in pairs(rows) do count=count+1 end;if not old and count>=24 then return false,'Private draft capacity reached.' end
 local row=old and E.Copy(old) or {schema=1,kind=proof.kind,key=proof.key,owner=proof.owner,source='LOCAL_GUID',scope='PRIVATE_NOT_PUBLISHED',revision=0,templates={},theme='navy'}
 if row.revision>=100000 or not E.palette[tx.theme or row.theme] then return false,'Invalid presentation revision or palette.' end
 row.templates[tx.scope.template]=clean;row.theme=tx.theme or row.theme;row.revision=row.revision+1;rows[key]=row;E.Root().revision=E.Root().revision+1
 return true,'Saved privately · Not published · No network action taken.'
end
function E.BeginScoped(name,route,workspace)
 local proof,why=E.Entitlement(route,name);if not proof and not workspace then return nil,why end
 -- Workspace editing is operational UI only. It cannot be a visitor profile
 -- editor, nor may it change somebody else's subject-specific presentation.
 if workspace and (social(name) or route.originGuild) then return nil,'Use the owner profile editor for social designs.' end
 local tx=E.Begin(name);tx.route=E.Copy(route)
 if proof and proof.kind~='WORKSPACE' then local draft=E.PrivateDesign(route,name);tx.scope=E.Scope(route,name);tx.owner=proof.owner;tx.theme=draft and draft.theme or 'navy';tx.originalTheme=tx.theme;tx.layout=E.Resolve(name,route);tx.original=E.Copy(tx.layout) end
 return tx
end
function E.Theme(route)
 local D=ns.UI2LayoutEditor;local theme=D and D.tx and D.tx.scope and D.tx.scope.kind=='CHARACTER' and D.tx.theme
 local row=not theme and E.PrivateDesign(route or ns.UI2.route,'intel.player')
 return E.palette[theme or row and row.theme or 'navy']
end
function E.AcceptPublicDesign() return false,'NATIVE_BLOCKED: authenticated owner layout records are unsupported. Private drafts never publish on reconnect.' end
function E.CreatorLayout(name)
 -- Explicit creator export includes the active owner's saved geometry, stripped
 -- of its subject envelope/theme. Other characters' drafts are never exported.
 if name=='intel.player' or name=='intel.public' then
  local owner=ns.Permissions.Owner();local key=owner and owner:match('/(Player%-.+)$')
  local route={page='intel',kind='player',key=key,owner=owner,projection=name=='intel.public' and 'public' or nil}
  local row=E.PrivateDesign(route,name);if row and row.templates[name] then return E.Copy(row.templates[name]) end
 end
 return E.Get(name)
end
function E.ClearOwned(owner)
 local rows=E.Root().subjects;if plain(rows) then for key,row in pairs(rows) do if plain(row) and row.owner==owner then rows[key]=nil end end end
end
function E.PrivacyPreflight()
 local root=ns.DB and ns.DB.ui2Layouts;if root==nil then return true end
 if not plain(root) or root.schema~=1 and root.schema~=2 then return false end
 if root.subjects~=nil then
  if not plain(root.subjects) then return false end
  local count=0;for key,row in pairs(root.subjects) do count=count+1;if count>24 or not plain(row) or type(row.kind)~='string' or type(row.key)~='string' or key~=row.kind..'/'..row.key or not valid(row,row.kind,row.key) then return false end end
 end
 return true
end
