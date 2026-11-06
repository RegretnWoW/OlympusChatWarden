-- One first-class room-post service on Aether's signed ledger. No profile Walls,
-- private evidence replication, network replacement or automatic publication.
local _,ns=...
local K,R=ns.AetherExtensionContracts,ns.AetherPostRooms
local A={VERSION=1,MAX_POSTS=1024,MAX_VOTES=4096,MAX_ROOM=768,MAX_ROOM_POSTS=128,MAX_AUTHOR=128,MAX_THREADS=64,MAX_DEPTH=4,MAX_BODY=800,MAX_POST_BYTES=3072,MAX_CACHE_BYTES=8388608};ns.AetherPosts=A
A.postFields=K.Set('version postID createdAt body doodle event composition spoiler tags parent contentHash')
A.voteFields=K.Set('version postID targetRevision contentHash on')
A.eventFields=K.Set('version ownerGUID sourceType sourceID title place date outcome proofClass')
local copy=ns.Athena.Copy
local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local function now()return math.floor(ns.SafeCall(GetServerTime)or 0)end
local function hash(v)return ns.PackCrypto.Hex(ns.PackCrypto.SHA256(v))end
local function enc(v)return ns.ChronicleBackup.Encode({v})end
local function hex(s,n)return type(s)=='string'and #s==n and s:match('^[a-f0-9]+$')~=nil end
function A.IsKind(k)return k=='POST'or k=='POST_UPVOTE'end
function A.ID(origin,room,slot)return'p-'..hash(origin..'/'..room..'/'..slot):sub(1,40)end
function A.ValidID(id)return type(id)=='string'and id:match('^p%-%x+$')and #id==42 end
function A.Hash(d)return hash(enc({body=d.body,doodle=d.doodle,event=d.event,composition=d.composition,spoiler=d.spoiler,tags=d.tags,parent=d.parent}))end
function A.EventValid(e,owner)
 return K.Keys(e,A.eventFields)and e.version==1 and ns.ChronicleStore.GUID(e.ownerGUID)and(not owner or e.ownerGUID==owner)
  and({dungeon=true,raid=true,battleground=true,arena=true,duel=true,boss=true,guild=true,world=true,group=true})[e.sourceType]
  and hex(e.sourceID,64)and ns.AetherNet.Text(e.title,100)and #e.title>0 and ns.AetherNet.Text(e.place,80)
  and K.Int(e.date,0,2147483647)and e.date%86400==0 and({partial=true,final_encounter_won=true,concluded=true,unknown=true,win=true,loss=true})[e.outcome]
  and e.proofClass=='OWNER_SHARED_CLIENT_REPORT'
end
function A.Validate(r,archived,owns)
 if r.subjectType~='ROOM'or not R.Valid(r.subjectKey)then return false,'PREDEFINED_ROOM_REQUIRED'end
 local d=r.data
 if r.kind=='POST'then
  if not K.Keys(d,A.postFields)or d.version~=1 or not A.ValidID(d.postID)or d.postID~=A.ID(r.origin,r.subjectKey,r.slot)
   or not K.Int(d.createdAt,1,r.issuedAt)or not ns.AetherNet.Text(d.body,A.MAX_BODY)or #d.body>2400 or type(d.spoiler)~='boolean'
   or not K.Array(d.tags,3)or not hex(d.contentHash,64)or d.parent~=nil and not A.ValidID(d.parent)then return false,'POST_SCHEMA'end
  for _,tag in ipairs(d.tags)do if not({adventure=true,question=true,lore=true,social=true,art=true})[tag]then return false,'POST_TAG'end end
  if d.doodle~=nil and not ns.WardenDrawing.Decode(d.doodle,ns.WardenDrawing.PUBLIC)then return false,'POST_DRAWING'end
  if d.composition~=nil and not ns.WardenComposition.Validate(d.composition)then return false,'POST_ART'end
  if d.composition and not archived then for _,layer in ipairs(d.composition.layers)do if layer.text and not A.SafeText(layer.text)then return false,'ART_CONTENT_POLICY'end end end
  if d.event~=nil and(not A.EventValid(d.event)or not owns(r.origin,'CHARACTER',d.event.ownerGUID))then return false,'POST_EVENT_OWNER_SCOPE'end
  if not r.removed and #d.body==0 and(not d.doodle or d.doodle=='WD1:')and not d.event and not d.composition then return false,'EMPTY_POST'end
  if not archived and not A.SafeText(d.body)then return false,'POST_CONTENT_POLICY'end
  if A.Hash(d)~=d.contentHash then return false,'POST_CONTENT_HASH'end
  if #enc(d)>A.MAX_POST_BYTES then return false,'POST_BYTE_LIMIT'end
 elseif r.kind=='POST_UPVOTE'then
  if not K.Keys(d,A.voteFields)or d.version~=1 or not A.ValidID(d.postID)or r.slot~=ns.AetherNet.HideSlot(d.postID)
   or not K.Int(d.targetRevision,1,1000000000)or not hex(d.contentHash,64)or type(d.on)~='boolean'or(d.on==true)==(r.removed==true)then return false,'UPVOTE_SCHEMA'end
 else return false,'ROOM_KIND'end
 return true
end
local indexes=setmetatable({},{__mode='k'})
function A.Index(c)
 local previous=indexes[c];if previous and previous.revision==c.revision then return previous end
 local ix={revision=c.revision,byID={},rows={},votes={},rooms={},authors={},posts=0,voteCount=0,bytes=0,positions={}}
 for _,row in pairs(c.records)do local r=row.record
  if A.IsKind(r.kind)then ix.bytes=ix.bytes+row.bytes;local room=ix.rooms[r.subjectKey]or{records=0,posts=0};ix.rooms[r.subjectKey]=room;room.records=room.records+1
   if r.kind=='POST'then ix.byID[r.data.postID]=row;ix.rows[#ix.rows+1]=row;ix.positions[r.data.postID]=#ix.rows;ix.posts=ix.posts+1;room.posts=room.posts+1;ix.authors[r.origin]=(ix.authors[r.origin]or 0)+1
   else ix.votes[r.data.postID]=ix.votes[r.data.postID]or{};ix.votes[r.data.postID][r.origin]=row;ix.voteCount=ix.voteCount+1 end
  end
 end
 indexes[c]=ix;return ix
end
-- Rebuildable indexes follow accepted ledger revisions; they are never persisted.
function A.LedgerChanged(c,row,old)
 local ix=indexes[c];if not ix or ix.revision~=c.revision-1 then indexes[c]=nil;return end
 local r=row.record;local room=ix.rooms[r.subjectKey]or{records=0,posts=0};ix.rooms[r.subjectKey]=room
 ix.bytes=ix.bytes-(old and old.bytes or 0)+row.bytes
 if not old then room.records=room.records+1 end
 if r.kind=='POST'then
  ix.byID[r.data.postID]=row
  if old then ix.rows[ix.positions[r.data.postID]]=row
  else ix.rows[#ix.rows+1]=row;ix.positions[r.data.postID]=#ix.rows;ix.posts=ix.posts+1;room.posts=room.posts+1;ix.authors[r.origin]=(ix.authors[r.origin]or 0)+1 end
 else ix.votes[r.data.postID]=ix.votes[r.data.postID]or{};ix.votes[r.data.postID][r.origin]=row;if not old then ix.voteCount=ix.voteCount+1 end end
 ix.revision=c.revision
end
local function localRoot(create)
 if not ns.DB then return end
 if not ns.DB.agora and create then ns.DB.agora={version=1,owners={}}end
 local root=ns.DB.agora;if not K.Keys(root,K.Set('version owners'))or root.version~=1 or not K.Plain(root.owners)then return nil,'AGORA_PREFERENCES_PRESERVED_UNSUPPORTED'end
 local guid=ns.PlayerCard.Own();if not guid then return nil,'EXACT_OWNER_REQUIRED'end
 local p=root.owners[guid]
 if not p and create then p={owner=ns.Chronicle.Owner(),serial=0,posting=true,followed={world=true},muted={},blocked={},hidden={},bookmarks={},drafts={},history={},pulse=false};root.owners[guid]=p end
 if not p then return end
 if not K.Keys(p,K.Set('owner serial posting followed muted blocked hidden bookmarks drafts history pulse'))or p.owner~=ns.Chronicle.Owner()or not K.Int(p.serial,0,1000000000)
  or type(p.posting)~='boolean'or type(p.pulse)~='boolean'then return nil,'AGORA_LOCAL_STATE_PRESERVED_UNSUPPORTED'end
 for _,key in ipairs({'followed','muted','blocked','hidden','bookmarks','drafts','history'})do if not K.Plain(p[key])or count(p[key])>((({drafts=32,history=128,blocked=128,hidden=256,bookmarks=128})[key])or 64) then return nil,'AGORA_LOCAL_STATE_BOUND'end end
 for _,kind in ipairs({'followed','muted','blocked','hidden','bookmarks'})do for key,v in pairs(p[kind])do
  local valid=(kind=='followed'or kind=='muted')and R.Valid(key)or kind=='blocked'and K.Token(key,128)or(kind=='hidden'or kind=='bookmarks')and A.ValidID(key)
  if not valid or v~=true then return nil,'AGORA_LOCAL_PREFERENCES_PRESERVED_INVALID'end
 end end
 for id,d in pairs(p.drafts)do
  if not K.Keys(d,K.Set('id at room body doodle event composition parent spoiler tags editing privateSource'))or d.id~=id or type(id)~='string'or not id:match('^draft%-%d+$')or not K.Int(d.at,0,2147483647)
   or not R.Valid(d.room)or not ns.AetherNet.Text(d.body or'',A.MAX_BODY)or type(d.spoiler)~='boolean'or not K.Array(d.tags,3)
   or d.composition and not ns.WardenComposition.Validate(d.composition)or d.doodle and not ns.WardenDrawing.Decode(d.doodle,ns.WardenDrawing.PUBLIC)or d.event and not A.EventValid(d.event,guid)or d.parent and not A.ValidID(d.parent)or d.editing and not A.ValidID(d.editing)
   or d.privateSource and(not K.Keys(d.privateSource,K.Set('owner activity sourceID'))or d.privateSource.owner~=p.owner or not K.Token(d.privateSource.sourceID,128)or not K.Text(d.privateSource.activity,512)or #d.privateSource.activity>512)then return nil,'AGORA_DRAFTS_PRESERVED_INVALID'end
 end
 for id,h in pairs(p.history)do if not A.ValidID(id)or not K.Keys(h,K.Set('pair room at'))or not R.Valid(h.room)or not K.Int(h.at,0,2147483647)or not K.Keys(h.pair,K.Set('wire signature'))or type(h.pair.wire)~='string'or #h.pair.wire>16384 or type(h.pair.signature)~='string'or #h.pair.signature>16384 then return nil,'AGORA_HISTORY_PRESERVED_INVALID'end end
 if count(p.followed)>16 or count(p.muted)>64 or #enc(p)>2097152 then return nil,'AGORA_LOCAL_STATE_BOUND'end
 return p
end
function A.Preferences(create)return localRoot(create)end
function A.SetPreference(kind,key,value)
 if not ns.Permissions.Decide('UIAccess')or type(value)~='boolean'then return false,'EXPLICIT_OWNER_REQUIRED'end
 local p,why=localRoot(true);if not p then return false,why end
 if kind=='posting'or kind=='pulse'then p[kind]=value
 elseif kind=='followed'or kind=='muted'then if not R.Valid(key)then return false,'ROOM_REQUIRED'end;if value and not p[kind][key]and count(p[kind])>=(kind=='followed'and 16 or 64)then return false,'PREFERENCE_BOUND'end;p[kind][key]=value or nil
 elseif kind=='hidden'or kind=='bookmarks'then if not A.ValidID(key)then return false,'POST_REQUIRED'end;if value and not p[kind][key]and count(p[kind])>=(kind=='hidden'and 256 or 128)then return false,'PREFERENCE_BOUND'end;p[kind][key]=value or nil
 elseif kind=='blocked'then if not K.Token(key,128)then return false,'AUTHOR_REQUIRED'end;if value and not p.blocked[key]and count(p.blocked)>=128 then return false,'PREFERENCE_BOUND'end;p.blocked[key]=value or nil
 else return false,'UNKNOWN_PREFERENCE'end
 local c=ns.AetherNet.Cached and ns.AetherNet.Cached();if c then c.inventoryCache=nil end;return true
end
function A.Wanted(c,room)
 if c.options.roomWanted then return c.options.roomWanted(room)==true end
 local p=localRoot(false);if not p and ns.DB.agora then return false end;if p and p.muted[room]then return false end
 -- An explicit publication remains an outbound interest after closing a room
 -- or reloading. Otherwise a later encounter could never carry that update.
 local bucket=math.floor(now()/30);local own=c.agoraOwnRooms
 if not own or own.revision~=c.revision or own.bucket~=bucket then
  own={revision=c.revision,bucket=bucket,rooms={}}
  for _,entries in ipairs({c.records,c.floors})do for _,row in pairs(entries)do local r=row.record
   if r and A.IsKind(r.kind)and r.origin==c.principal and r.issuedAt+ns.AetherNet.TTL+ns.AetherNet.TOMBSTONE_TTL>now()then own.rooms[r.subjectKey]=true end
  end end;c.agoraOwnRooms=own
 end
 local open=c.agoraOpen;return(not p and room=='world')or p and p.followed[room]==true or open and open.room==room and open.expires>now()or own.rooms[room]==true or false
end

function A.OpenRoom(c,room)
 if not R.Valid(room)then return false,'PREDEFINED_ROOM_REQUIRED'end;c.agoraOpen={room=room,expires=now()+180};c.inventoryCache=nil
 if c:Joined()then c:Refresh('ROOM',room)end;return true
end
local function visible(c,row,ix,at,ignoreLocal)
 if not row or row.conflict or row.record.removed or row.record.expiresAt<=at then return false end
 local p=not ignoreLocal and localRoot(false);local r=row.record
 if p and(p.hidden[r.data.postID]or p.blocked[r.origin]or p.muted[r.subjectKey])then return false end
 local muted=not ignoreLocal and ns.AetherNet.MutedAuthors and ns.AetherNet.MutedAuthors();if muted and muted[r.origin]then return false end
 local parent=r.data.parent;local depth=0
 while parent do depth=depth+1;if depth>A.MAX_DEPTH then return false end;local v=ix.byID[parent]
  if not v or v.record.subjectKey~=r.subjectKey or v.record.removed or v.conflict or v.record.expiresAt<=at or p and(p.hidden[parent]or p.blocked[v.record.origin])then return false end;parent=v.record.data.parent
 end
 return true
end
function A.BeforeAccept(c,r,archived,old,pairBytes)
 if old and old.record.revision==r.revision then return true end
 local ix=A.Index(c);local d=r.data;local at=c.options.clock and c.options.clock()or now()
 if r.kind=='POST'then
  local same=ix.byID[d.postID];if same and same.record.subjectKey~=r.subjectKey then return false,'POST_ROOM_IMMUTABLE'end
  if old and(old.record.data.createdAt~=d.createdAt or old.record.data.parent~=d.parent)then return false,'POST_IDENTITY_IMMUTABLE'end
  if old and old.record.removed and not r.removed then return false,'POST_REMOVED'end
  if d.parent==d.postID then return false,'THREAD_LOOP'end
  if d.parent and not archived and not r.removed then
   local parent=ix.byID[d.parent];if not parent then return false,'POST_DEPENDENCY_MISSING'end
   if not visible(c,parent,ix,at)or parent.record.subjectKey~=r.subjectKey then return false,'REPLY_PARENT_UNAVAILABLE'end
   local depth=1;local x=parent;while x.record.data.parent do depth=depth+1;x=ix.byID[x.record.data.parent];if not x or depth>A.MAX_DEPTH then return false,'THREAD_DEPTH'end end
   local root=x.record.data.postID;local children=0;for _,row in ipairs(ix.rows)do local cur=row;local n=0;while cur and cur.record.data.parent and n<A.MAX_DEPTH do n=n+1;cur=ix.byID[cur.record.data.parent]end;if cur and cur.record.data.postID==root then children=children+1 end end
   if not old and children>=A.MAX_THREADS then return false,'THREAD_CAPACITY'end
  end
  if not old and(ix.posts>=A.MAX_POSTS or(ix.rooms[r.subjectKey]and ix.rooms[r.subjectKey].posts or 0)>=A.MAX_ROOM_POSTS or(ix.authors[r.origin]or 0)>=A.MAX_AUTHOR)then return false,'POST_CACHE_CAPACITY'end
 elseif r.kind=='POST_UPVOTE'then
  local target=ix.byID[d.postID];if not target then if archived then return true end;return false,'POST_DEPENDENCY_MISSING'end
  if not archived and d.targetRevision>target.record.revision then return false,'POST_DEPENDENCY_MISSING'end
  local targetGUID=c.options.authorGUID and c.options.authorGUID(target.record.origin);local voterGUID=c.options.authorGUID and c.options.authorGUID(r.origin)
  if target.record.subjectKey~=r.subjectKey or target.record.origin==r.origin or targetGUID and voterGUID and targetGUID==voterGUID then return false,'UPVOTE_ROOM_OR_SELF'end
  if not archived and(not visible(c,target,ix,at)or target.record.revision~=d.targetRevision or target.record.data.contentHash~=d.contentHash)then return false,'UPVOTE_REVISION_OR_VISIBILITY'end
  if not old and ix.voteCount>=A.MAX_VOTES then return false,'VOTE_CACHE_CAPACITY'end
 end
 local size=pairBytes or #enc(r);if ix.bytes-(old and old.bytes or 0)+size>A.MAX_CACHE_BYTES then return false,'POST_CACHE_BYTES'end
 if not archived and old and r.kind=='POST_UPVOTE'and r.issuedAt<old.record.issuedAt+2 then return false,'UPVOTE_COOLDOWN'end
 if not archived and at-r.issuedAt<60 then
  c.agoraRates=c.agoraRates or{};local key=r.origin..'/'..math.floor(r.issuedAt/60)..'/'..r.kind;local rate=c.agoraRates[key]or 0
  local minute=math.floor(r.issuedAt/60);if(c.agoraRates['room/'..r.subjectKey..'/'..minute..'/POST']or 0)>=120 or(c.agoraRates['global/'..minute..'/POST']or 0)>=240 then return false,'AGORA_ROOM_RATE'end
  local limit=r.kind=='POST_UPVOTE'and 30 or d.parent and 12 or 6;if rate>=limit then return false,'AGORA_AUTHOR_RATE'end
 end
 return true
end
function A.Accepted(c,r)
 if not A.IsKind(r.kind)then return end
 c.agoraRates=c.agoraRates or{};local clock=c.options.clock and c.options.clock()or now();for key in pairs(c.agoraRates)do local minute=tonumber(key:match('/(%d+)/[^/]+$'));if not minute or minute<math.floor(clock/60)-1 then c.agoraRates[key]=nil end end
 local minute=math.floor(r.issuedAt/60);for _,key in ipairs({'room/'..r.subjectKey..'/'..minute..'/POST','global/'..minute..'/POST'})do c.agoraRates[key]=(c.agoraRates[key]or 0)+1 end
 local key=r.origin..'/'..minute..'/'..r.kind;if count(c.agoraRates)<512 or c.agoraRates[key]then c.agoraRates[key]=(c.agoraRates[key]or 0)+1 end
end
function A.Projection(c,row,ix,at)
 local r=row.record;local d=r.data;local auth=c.options.authority(r.origin);local status=c.options.recordStatus and c.options.recordStatus(row)or'FIXTURE_AUTHENTICATED'
 local n,pending,my=0,0,false;local voters={};local ownGUID=c.options.authorGUID and c.options.authorGUID(c.principal)
 for voter,v in pairs(ix.votes[d.postID]or{})do local x=v.record;local guid=c.options.authorGUID and c.options.authorGUID(voter);local authorGUID=c.options.authorGUID and c.options.authorGUID(r.origin)
  local identity=guid or voter;local epoch=c.options.authorEpoch and c.options.authorEpoch(voter)or 0
  if voter~=r.origin and(not guid or guid~=authorGUID)and not v.conflict and x.expiresAt>at and x.data.targetRevision==r.revision and x.data.contentHash==d.contentHash then
   local previous=voters[identity];if not previous or epoch>previous.epoch or epoch==previous.epoch and(x.revision>previous.row.record.revision or x.revision==previous.row.record.revision and x.issuedAt>previous.row.record.issuedAt)then voters[identity]={row=v,epoch=epoch,guid=guid,voter=voter}end
  end
 end
 for _,v in pairs(voters)do local x=v.row.record;if not x.removed and x.data.on then
  local proof=c.options.recordStatus and c.options.recordStatus(v.row)or'FIXTURE_AUTHENTICATED';if proof=='AUTHENTICATED'or proof=='FIXTURE_AUTHENTICATED'then n=n+1 else pending=pending+1 end
  if v.voter==c.principal or v.guid and v.guid==ownGUID then my=true end
 end end
 local guid=c.options.authorGUID and c.options.authorGUID(r.origin)or auth and auth.guid
 return{postID=d.postID,room=r.subjectKey,author=r.origin,authorName=auth and auth.name or'Author identity unavailable',authorGUID=guid,createdAt=d.createdAt,updatedAt=r.issuedAt,revision=r.revision,body=d.body,doodle=d.doodle,event=copy(d.event),composition=copy(d.composition),spoiler=d.spoiler,tags=copy(d.tags),parent=d.parent,contentHash=d.contentHash,upvotes=n,pendingVotes=pending,myUpvote=my,authentication=status,delivery=c.nativeController and c.nativeController.PostStatus and c.nativeController:PostStatus(d.postID)or{state='RECIPIENT_OR_ROOM_AVAILABILITY_UNKNOWN'},scope='Known validated character votes · partial network coverage',provenance='Authored social content; not server-verified gameplay evidence',removed=r.removed or false}
end
function A.Get(c,id,includeRemoved)
 if not c then return nil,'AETHER_CACHE_UNAVAILABLE'end;local ix=A.Index(c);local row=ix.byID[id];local at=c.options.clock and c.options.clock()or now()
 if not row then return nil,'POST_EXPIRED_OR_UNKNOWN'end
 if not includeRemoved and not visible(c,row,ix,at)then return nil,row.record.removed and'POST_REMOVED'or'POST_HIDDEN_EXPIRED_OR_UNAVAILABLE'end
 return A.Projection(c,row,ix,at),row
end
function A.Query(c,q)
 q=q or{};if q.room and ns.AetherUnified then ns.AetherUnified.Freshness('ROOM',q.room)end;if not c then return{items={},scope='No peer cache available',partial=true}end
 local ix=A.Index(c);local at=c.options.clock and c.options.clock()or now();local rows={};local p=localRoot(false);local asof=at
 local sort=q.sort=='popular'and'popular'or'recent';local boundary
 if q.cursor and type(q.cursor)~='string'then return nil,'CURSOR_INVALID'end
 if q.cursor then local s,t,weight,created,id=q.cursor:match('^(%a+)/(%d+)/(%d+)/(%d+)/(p%-%x+)$');if s~=sort or not A.ValidID(id)then return nil,'CURSOR_INVALID'end;asof=tonumber(t);if asof>at+5 or asof<at-86400 then return nil,'CURSOR_EXPIRED'end;boundary={tonumber(weight),tonumber(created),id}end
 for _,row in ipairs(ix.rows)do local r=row.record
  if visible(c,row,ix,at)and r.data.createdAt<=asof and(not q.room or r.subjectKey==q.room)and(not q.author or r.origin==q.author)and(not q.guid or c.options.authorGUID and c.options.authorGUID(r.origin)==q.guid)
   and(not q.following or p and p.followed[r.subjectKey])and(not q.bookmarks or p and p.bookmarks[r.data.postID])and(not q.parent and not r.data.parent or q.parent and r.data.parent==q.parent)then
   local v=A.Projection(c,row,ix,at);local weight=sort=='popular'and math.floor(v.upvotes*100000/(1+math.max(0,asof-v.createdAt)/3600)^1.2)or 0;v.weight=weight
   if not boundary or weight<boundary[1]or weight==boundary[1]and(v.createdAt<boundary[2]or v.createdAt==boundary[2]and v.postID>boundary[3])then rows[#rows+1]=v end
  end
 end
 table.sort(rows,function(a,b)if a.weight~=b.weight then return a.weight>b.weight end;if a.createdAt~=b.createdAt then return a.createdAt>b.createdAt end;return a.postID<b.postID end)
 local out={items={},partial=true,scope='Known cached posts · incomplete P2P coverage'};local limit=math.max(1,math.min(12,q.limit or 10))
 for i=1,math.min(limit,#rows)do out.items[i]=rows[i]end;if #rows>limit then local last=out.items[#out.items];out.next=sort..'/'..asof..'/'..last.weight..'/'..last.createdAt..'/'..last.postID end;return out
end
function A.SafeText(text)
 if not ns.AetherNet.Text(text,A.MAX_BODY)or #text>2400 then return false,'PLAIN_UTF8_TEXT_REQUIRED'end
 if ns.Active and ns.Active('chat')and ns.Find and ns.MatchAction then local ok,m=pcall(ns.Find,text,false,{kind='player'});if not ok then return false,'CHAT_POLICY_UNAVAILABLE'end;local good,action=pcall(ns.MatchAction,m);if not good or action=='Hidden'or action=='Redacted'or action=='Replaced'then return false,'CHAT_POLICY_REJECTED'end end
 return true
end
function A.SaveDraft(value,id)
 if not ns.Permissions.Decide('UIAccess')or not K.Keys(value,K.Set('room body doodle event composition parent spoiler tags editing privateSource'))then return nil,'EXPLICIT_OWNER_DRAFT_REQUIRED'end
 local p,why=localRoot(true);if not p then return nil,why end
 if not R.Valid(value.room)or not A.SafeText(value.body or'')or type(value.spoiler)~='boolean'or not K.Array(value.tags or{},3)
  or value.composition and not ns.WardenComposition.Validate(value.composition)or value.doodle and not ns.WardenDrawing.Decode(value.doodle,ns.WardenDrawing.PUBLIC)or value.event and not A.EventValid(value.event,ns.PlayerCard.Own())or value.parent and not A.ValidID(value.parent)or value.editing and not A.ValidID(value.editing)then return nil,'DRAFT_FIELDS'end
 for _,tag in ipairs(value.tags or{})do if not({adventure=true,question=true,lore=true,social=true,art=true})[tag]then return nil,'DRAFT_TAG'end end
 if value.privateSource and(not K.Keys(value.privateSource,K.Set('owner activity sourceID'))or value.privateSource.owner~=ns.Chronicle.Owner()or not K.Token(value.privateSource.sourceID,128)or not K.Text(value.privateSource.activity,512)or #value.privateSource.activity>512)then return nil,'PRIVATE_EVENT_CONTEXT'end
 local row=id and p.drafts[id];if id and not row then return nil,'DRAFT_NOT_FOUND'end
 if not id then if count(p.drafts)>=32 then return nil,'DRAFT_CAPACITY'end;p.serial=p.serial+1;id='draft-'..p.serial end
 local out=copy(value);out.id=id;out.at=now();local staged=copy(p);staged.drafts[id]=out;if #enc(staged)>2097152 then return nil,'DRAFT_BYTES'end;p.drafts[id]=out;return copy(out)
end
function A.Drafts()local p=localRoot(false);local out={};for _,d in pairs(p and p.drafts or{})do out[#out+1]=copy(d)end;table.sort(out,function(a,b)return a.at==b.at and a.id<b.id or a.at>b.at end);return out end
function A.DeleteDraft(id)local p=localRoot(false);if not p or not p.drafts[id]then return false,'DRAFT_NOT_FOUND'end;p.drafts[id]=nil;return true end
local function client()if not ns.Permissions.Decide('UIAccess')then return nil,'OWNER_UI_REQUIRED'end;local p,why=localRoot(true);if not p then return nil,why end;if not p.posting then return nil,'COMMUNITY_POSTING_DISABLED'end;return ns.AetherNet.PublicationClient()end
function A.Publish(id,explicit,reviewed)
 if explicit~=true then return nil,'EXPLICIT_PUBLICATION_REQUIRED'end
 local p,why=localRoot(false);local d=p and p.drafts[id];if not d then return nil,'DRAFT_NOT_FOUND'end
 if reviewed and enc(reviewed)~=enc(d)then return nil,'DRAFT_CHANGED_REVIEW_AGAIN'end
 local c,why=client();if not c then return nil,why end
 if count(p.history)>=128 and not d.editing then return nil,'OWNER_POST_HISTORY_CAPACITY'end
 if #enc(p)+12288>2097152 then return nil,'OWNER_POST_HISTORY_BYTES'end
 if d.privateSource and not A.CheckSource(d)then return nil,'SOURCE_CHANGED_OR_UNAVAILABLE'end
 local slot;local revision=1;local created=now()
 if d.editing then local post,row=A.Get(c,d.editing);if not post or post.author~=c.principal then return nil,'SIGNED_AUTHOR_ONLY'end;slot=row.record.slot;revision=post.revision+1;created=post.createdAt;if post.room~=d.room then return nil,'POST_ROOM_IMMUTABLE'end
 else p.serial=p.serial+1;slot='post-'..hash(c.principal..'/'..c.session..'/'..p.serial..'/'..now()):sub(1,28)end
 local data={version=1,postID=A.ID(c.principal,d.room,slot),createdAt=created,body=d.body or'',doodle=d.doodle,event=copy(d.event),composition=copy(d.composition),spoiler=d.spoiler,tags=copy(d.tags or{}),parent=d.parent};data.contentHash=A.Hash(data)
 local pair,id=c:Publish('ROOM',d.room,'POST',slot,data,revision,false,true);if not pair then return nil,id end
 p.history[data.postID]={pair=copy(pair),room=d.room,at=now()};p.drafts[d.id]=nil;A.OpenRoom(c,d.room)
 return A.Get(c,data.postID)
end
function A.Remove(postID,explicit)
 if not explicit then return false,'EXPLICIT_AUTHOR_REMOVAL_REQUIRED'end;local c,why=client();if not c then return false,why end
 local post,row=A.Get(c,postID);if not post or post.author~=c.principal then return false,'SIGNED_AUTHOR_ONLY'end
 local d=copy(row.record.data);d.body='';d.doodle=nil;d.event=nil;d.composition=nil;d.contentHash=A.Hash(d)
 local pair,err=c:Publish('ROOM',post.room,'POST',row.record.slot,d,post.revision+1,true,true);if not pair then return false,err end
 local p=localRoot(false);if p and p.history[postID]then p.history[postID]={pair=copy(pair),room=post.room,at=now()}end;return true,'Removal committed; already received copies cannot be recalled.'
end
function A.Toggle(postID)
 local c,why=client();if not c then return nil,why end;local post=A.Get(c,postID);if not post or post.author==c.principal then return nil,'VISIBLE_OTHER_AUTHOR_POST_REQUIRED'end
 c.agoraVoteTimes=c.agoraVoteTimes or{};local at=now();if c.agoraVoteTimes[postID]and at-c.agoraVoteTimes[postID]<2 then return nil,'UPVOTE_COOLDOWN'end
 if count(c.agoraVoteTimes)>256 then c.agoraVoteTimes={}end;c.agoraVoteTimes[postID]=at
 local data={version=1,postID=postID,targetRevision=post.revision,contentHash=post.contentHash,on=not post.myUpvote};local slot=ns.AetherNet.HideSlot(postID)
 local pair,err=c:Publish('ROOM',post.room,'POST_UPVOTE',slot,data,ns.AetherNet.NextRevision(c,'ROOM',post.room,'POST_UPVOTE',slot),not data.on,true)
 if not pair then return nil,err end;return A.Get(c,postID)
end
function A.Hold(c,pair)
 c.agoraHold=c.agoraHold or{};for k,v in pairs(c.agoraHold)do if v.expires<=now()then c.agoraHold[k]=nil end end;local key=hash(pair.wire..pair.signature);if count(c.agoraHold)>=32 and not c.agoraHold[key]then return false end;c.agoraHold[key]={pair=copy(pair),expires=now()+120};return true
end
function A.Drain(c)
 if c.agoraDraining then return end;c.agoraDraining=true;local n=0
 for key,v in pairs(c.agoraHold or{})do if n>=8 then break end;n=n+1;c.agoraHold[key]=nil;if v.expires>now()then c:Accept(v.pair,'live')end end;c.agoraDraining=false
end
function A.ForgetHistory(id,explicit)
 if explicit~=true or not ns.Permissions.Decide('UIAccess')then return false,'EXPLICIT_OWNER_REQUIRED'end;local p,why=localRoot(false);if not p or not p.history[id]then return false,why or'OWNER_ARCHIVE_COPY_NOT_FOUND'end;p.history[id]=nil;return true,'Your retained archive copy was removed; the public record and other peers are unchanged.'
end
function A.Status(c)
 if c and c.recovery and c.recovery.state~='READY'then return c.recovery.state=='RECOVERY_REQUIRED'and'Community history needs recovery · original saved data retained'or'Restoring community history · private drafts remain available'end
 local p=localRoot(false);if not p or not p.posting then return'Community posting disabled'end
 if not ns.AetherNet.Preference()then return'Aether participation off · drafts remain private'end
 local native=c and c.nativeController;return native and next(native.peers)and'Partial peer connectivity · no global delivery guarantee'or'Peers unavailable · accepted posts are retained for eligible synchronization'
end
