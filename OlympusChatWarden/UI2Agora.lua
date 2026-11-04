-- Agora is a destination inside the existing Aether shell. Cards point to one
-- room post ID; My Posts and room feeds never create profile-bound copies.
local _,ns=...
local A,R=ns.AetherPosts,ns.AetherPostRooms;local U,F=ns.UI2,ns.UI2Forms
local function row(t,d,fn,extra)local r=extra or{};r.title=t;r.detail=d;r.activate=fn;return r end
local function caption(t)return row(t,nil,nil,{kind='caption',height=64,wrap=true})end
local function open(q)q=q or{};q.page='intel';q.subsection='agora';return U.Open(q)end
A.Open=open
local function cache()return ns.AetherNet.Cached()end
local function refresh()U.Refresh(true)end
local function feedback(ok,why)return F.Feedback(ok,why)end
local function stamp(at)return at and at>0 and(ns.SafeCall(date,'%Y-%m-%d',at)or'Date unknown')or'Date unknown'end
local function now()return math.floor(ns.SafeCall(GetServerTime)or 0)end
local function allowed()return ns.Permissions.Decide('UIAccess')end
function A.Composer(value,id)
 if not allowed()then return false,'OWNER_UI_REQUIRED'end
 local draft;if id then for _,d in ipairs(A.Drafts())do if d.id==id then draft=d end end;if not draft then return false,'DRAFT_NOT_FOUND'end end
 value=draft or value or{};return ns.WardenStudio.Open(value,id)
end
function A.LegacyTextComposer(value,id)
 local room=R.Valid(value.room)and value.room or'world';local choices={}
 for _,r in ipairs(R.List())do choices[#choices+1]={r.id,r.category..' · '..r.title}end
 return F.Form({title=value.parent and'Reply in the Agora'or value.editing and'Edit my post'or'New Agora post',help='One room, one authored post. Plain text up to 800 characters / 2,400 bytes. Optional drawing and one reviewed Athena card. Save first, then preview and explicitly Publish. No private quotes, routes, party identities or screenshots are included.',
  fields={{key='body',label='Your post · may be empty with a drawing or event card',value=value.body or'',limit=800,multiline=true,height=150},
   {key='room',label='Destination room',value=room,choices=choices,enabled=not value.parent and not value.editing},
   {key='spoiler',label='Contains spoilers',value=value.spoiler==true,choices={{false,'No'},{true,'Hide behind a spoiler preview'}}}},
  paragraphs=value.event and{'Owner-shared Athena observation: '..value.event.title,'Place: '..value.event.place..' · '..stamp(value.event.date),'Outcome: '..value.event.outcome,'Signed owner report, not independently corroborated gameplay. Remote copies cannot be guaranteed erased.'}or{},
  submitLabel='Save private draft',submit=function(v)
   local d,why=A.SaveDraft({room=(value.parent or value.editing)and room or v.room,body=v.body,spoiler=v.spoiler==true,tags=value.tags or{},parent=value.parent,editing=value.editing,doodle=value.doodle,event=value.event,privateSource=value.privateSource},id)
   if not d then return false,why end;open({view='drafts',draft=d.id});return true,'Private draft saved. Nothing has been published.'
  end})
end
function A.DrawDraft(draft)
 return A.Composer(nil,draft.id)
end
function A.LegacyDrawDraft(draft)
 return ns.WardenDrawing.Open({limits=ns.WardenDrawing.PUBLIC,title='Post doodle · private until Publish',wire=draft.doodle,save=function(wire)
  local d=ns.Athena.Copy(draft);d.id=nil;d.at=nil;d.doodle=wire~='WD1:'and wire or nil;local saved,why=A.SaveDraft(d,draft.id);if saved then refresh()end;return saved~=nil,why
 end})
end
function A.ReviewDraft(draft)
 -- The existing composed page is the preview; publication still has a separate
 -- immutable-snapshot confirmation. Closing it leaves the private draft intact.
 open({view='drafts',draft=draft.id,preview=true})
 return F.Confirm('Publish this Agora post?',(draft.body~=''and draft.body or'(Attachment-only post)')..'\n\nRoom: '..R.Get(draft.room).title..(draft.doodle and'\nIncludes a drawing. Text filters cannot moderate drawn content.'or'')..(draft.event and'\nIncludes the reviewed, limited Athena event card.'or'')..'\n\nThis creates an authorized community post. P2P reach is partial; remote copies cannot be guaranteed erased. No automatic profile injection or global delivery is implied.',function()
  local post,why=A.Publish(draft.id,true,draft);if not post then return false,why end;open({room=post.room,post=post.postID});return true,'Post committed for eligible P2P synchronization.'
 end,'Publish')
end
local function entry(rows,p,detail)
 local room=R.Get(p.room);local author=p.authorGUID and function()U.OpenPlayer(p.authorGUID,ns.Chronicle.Owner())end or nil
 rows[#rows+1]=row(p.authorName,(room and room.title or'Unknown room')..' · '..stamp(p.createdAt)..' · '..(p.authentication=='AUTHENTICATED'and'Author verified'or p.authentication=='PENDING_ENROLLMENT'and'Enrollment pending'or'Cached author proof'),author,{stacked=true,height=64})
 local revealed=not p.spoiler or detail and U.route.revealSpoiler==true
 if not revealed then rows[#rows+1]=row('Spoiler · open deliberately','Content and attachments are hidden',function()open({room=p.room,post=p.postID,revealSpoiler=true})end,{height=48})
 else
  if #p.body>0 then rows[#rows+1]=row(p.body,nil,nil,{wrap=true,height=math.max(64,math.ceil(#p.body/65)*18+12)})end
  if p.composition then rows[#rows+1]={composition=p.composition,height=p.composition.base=='cover'and 350 or 250}end
  if p.doodle then rows[#rows+1]={doodle=p.doodle,height=190}end
  if p.event then rows[#rows+1]=row(p.event.title,p.event.place..' · '..stamp(p.event.date)..' · '..p.event.outcome,function()open({room=p.room,post=p.postID,publicEvent=true})end,{stacked=true,height=76});rows[#rows+1]=caption('Owner-shared Athena observation · signed client report, not server-verified evidence.')end
 end
 local c=cache();local own=c and p.author==c.principal
 local vote=own and(tostring(p.upvotes)..' known upvotes · Your post')or(p.myUpvote and'Remove my upvote · 'or'Upvote · ')..p.upvotes
 rows[#rows+1]=row(vote,p.scope..(p.pendingVotes>0 and' · Enrollment-pending votes are not counted'or'')..(p.revision>1 and' · Votes reset by content edit'or''),not own and function()local ok,why=A.Toggle(p.postID);feedback(ok~=nil,why);refresh()end or nil,{height=62,stacked=true})
 if own then local labels={QUEUED_TO_KNOWN_PEER='Queued for peer synchronization',TRANSFERRED_TO_KNOWN_PEER='Transferred to a known peer',ENVELOPE_ACKNOWLEDGED_BY_KNOWN_PEER='Known peer acknowledged the packet'};rows[#rows+1]=caption('Post retained · '..(labels[p.delivery and p.delivery.state]or'Peer reach unknown')..'. This does not certify global distribution.')end
 local actions={{title='Open thread',activate=function()open({room=p.room,post=p.postID})end},{title='Reply',activate=function()A.Composer({room=p.room,parent=p.postID,body='',tags={},spoiler=false})end},
  {title='Bookmark',activate=function()local prefs=A.Preferences(true);A.SetPreference('bookmarks',p.postID,not prefs.bookmarks[p.postID]);refresh()end},
  {title='Hide',activate=function()A.SetPreference('hidden',p.postID,true);refresh()end},
  {title='Report',activate=function()ns.UI2Operations.CommunityConcern('ROOM',p.room,{id=p.postID,author=p.author,authorName=p.authorName,text=p.body..(p.doodle and'\n[Drawing attached]'or'')},'Agora post')end}}
 local c=cache()
 if c and c.principal==p.author then
  actions[#actions+1]={title='Edit',activate=function()A.Composer({room=p.room,body=p.body,doodle=p.doodle,event=p.event,composition=p.composition,parent=p.parent,spoiler=p.spoiler,tags=p.tags,editing=p.postID})end}
  actions[#actions+1]={title='Remove',activate=function()F.Confirm('Remove my post?','A signed removal supersedes this post. Replies become unavailable with a removed parent. Already received copies cannot be forcibly recalled.',function()local ok,why=A.Remove(p.postID,true);if ok then open({room=p.room})end;return ok,why end)end}
 else actions[#actions+1]={title='Block author',activate=function()A.SetPreference('blocked',p.author,true);refresh()end}end
 rows[#rows+1]={actions=actions,height=74}
end
function A.ProfileRows(guid)
 local rows={};local c=cache();local own=guid==ns.PlayerCard.Own()
 if own then rows[#rows+1]=row('Create a post','Choose one Agora room',function()A.Composer()end,{height=44});rows[#rows+1]=row('Share an Athena adventure','Review a limited card first',function()A.ActivityChooser()end,{height=44})end
 local feed=c and A.Query(c,{guid=guid,limit=3});for _,p in ipairs(feed and feed.items or{})do rows[#rows+1]=row(p.body~=''and p.body:sub(1,90)or p.doodle and'A shared drawing'or'An Athena observation',(R.Get(p.room)and R.Get(p.room).title or'')..' · '..stamp(p.createdAt),function()open({room=p.room,post=p.postID})end,{stacked=true,height=68})end
 if not feed or #feed.items==0 then rows[#rows+1]=caption('No known Agora posts for this character. Profiles do not have public Walls.')end
 rows[#rows+1]=row(own and'My Posts in the Agora'or'Explore the Agora','The same canonical room records',function()open({view='author',authorGUID=guid})end,{height=44});return rows
end
function A.Blocks(route)
 R.Ensure();local c=cache();local room=R.Valid(route.room)and route.room or'world';local prefs,preferenceError=A.Preferences(true)
 if not prefs then return{{id='feed',title='Agora preferences need recovery',x=0,y=0,w=1,rows={caption(preferenceError or'Original local state was preserved; posting is disabled until it can be recovered.')}}}end
 if c and(route.room or route.view==nil)then local previous=c.agoraOpen;if not previous or previous.room~=room or previous.expires<now()then A.OpenRoom(c,room)end end
 local navigation={row('The World Hall','One shared room · reach depends on participating peers',function()open({room='world'})end,{stacked=true,height=64})}
 for _,category in ipairs({'Zones','Cities','PvP','PvE'})do local category=category;navigation[#navigation+1]=row(category,'Browse predefined rooms',function()open({view='rooms',roomCategory=category})end,{height=42})end
 for _,v in ipairs({{'recent','Recent'},{'following','Following'},{'popular','Popular'},{'mine','My Posts'},{'drafts','Private drafts'},{'bookmarks','Bookmarks'},{'controls','Posting & content controls'}})do local view=v[1];navigation[#navigation+1]=row(v[2],nil,function()open({view=view})end,{height=38})end
 local source=ns.SafeCall(GetRealZoneText);local suggestion=R.Suggest(source);navigation[#navigation+1]=row('Suggested room',R.Get(suggestion).title,function()open({room=suggestion})end,{height=48});navigation[#navigation+1]=caption('Room suggestions stay on this client. They never announce your location or join chat channels.')
 local rows={};if c and c.recovery and c.recovery.state~='READY'then rows[#rows+1]=caption(A.Status(c))end;local title=route.view=='drafts'and'Private post drafts'or route.post and'Agora thread'or R.Get(room).title
 if route.view=='rooms'then
  for _,r in ipairs(R.List(route.roomCategory))do local id=r.id;rows[#rows+1]=row(r.title,r.category,function()open({room=id})end,{height=40})end;title=route.roomCategory or'Rooms'
 elseif route.view=='controls'then
  rows={row('Community posting',prefs and prefs.posting and'On · click to stop posts/upvotes'or'Off · click to allow',function()A.SetPreference('posting',nil,not prefs.posting);refresh()end,{height=48}),
   row('World Pulse · my recorded counts',prefs and prefs.pulse and'Opted in · this client only'or'Off · no activity counts shown',function()A.SetPreference('pulse',nil,not prefs.pulse);refresh()end,{height=50}),
   row('Aether participation & privacy','Existing opt-out, independent of Athena recording',function()U.Open({page='relay',subsection='aether'})end,{height=44})}
  for id in pairs(prefs and prefs.hidden or{})do local key=id;rows[#rows+1]=row('Restore a hidden post',key,function()A.SetPreference('hidden',key,false);refresh()end,{height=42})end
  for id in pairs(prefs and prefs.blocked or{})do local key=id;rows[#rows+1]=row('Unblock author',key,function()A.SetPreference('blocked',key,false);refresh()end,{height=42})end
  for id in pairs(prefs and prefs.muted or{})do local key=id;rows[#rows+1]=row('Unmute room',R.Get(key).title,function()A.SetPreference('muted',key,false);refresh()end,{height=42})end
  if ns.WardenSimLab and ns.WardenSimLab.Enabled()then rows[#rows+1]=row('Export prelaunch Wall test data','Developer-only archive; no migration or automatic deletion',function()local kept={};for _,r in pairs(c and c.records or{})do if r.record.kind=='WALL'or r.record.kind=='COMMUNITY_WALL'then kept[#kept+1]=r.pair end end;F.Copy('Prelaunch test archive',ns.ChronicleBackup.Encode(kept))end,{height=56})end
 elseif route.view=='drafts'then
  local drafts=A.Drafts();if route.draft then for _,d in ipairs(drafts)do if d.id==route.draft then drafts={d};break end end end;local offset=tonumber(route.cursor)or 0;if offset<0 or offset%1~=0 or offset>32 then offset=0 end
  for i=offset+1,math.min(#drafts,offset+5)do local d=drafts[i];if not route.draft or route.draft==d.id then
   local draft=d;rows[#rows+1]=row(R.Get(d.room).title..' · Draft',d.body~=''and d.body or'Attachment-only draft',nil,{stacked=true,height=80})
   if d.composition then rows[#rows+1]={composition=d.composition,height=250}end
   if d.doodle then rows[#rows+1]={doodle=d.doodle,height=190}end
   if d.event then rows[#rows+1]=row(d.event.title,d.event.place..' · '..stamp(d.event.date)..' · '..d.event.outcome,nil,{stacked=true,height=70})end
   rows[#rows+1]={actions={{title='Edit',activate=function()A.Composer(nil,draft.id)end},{title='Draw / preview',activate=function()A.DrawDraft(draft)end},{title='Publish',activate=function()A.ReviewDraft(draft)end},{title='Delete draft',activate=function()A.DeleteDraft(draft.id);refresh()end}},height=74}
  end end;if not route.draft and #drafts>offset+5 then rows[#rows+1]=row('More drafts',nil,function()open({view='drafts',cursor=tostring(offset+5)})end)end;if #rows==0 then rows[1]=caption('No private drafts. Drafts do not synchronize or publish automatically.')end
 elseif route.post then
  local p,why=A.Get(c,route.post)
  if p then
   title='Post · '..R.Get(p.room).title
   if route.publicEvent then
    local e=p.event;rows[1]=row('Approved public event snapshot',e and e.title or'No shared event is available',nil,{kind='hero',height=60})
    if e then rows[#rows+1]=row(e.place,stamp(e.date)..' · '..e.outcome,nil,{height=48});rows[#rows+1]=caption('Owner-shared client observation. No private Chronicle, other player roster, quotes, precise route or independent server proof is available here.');rows[#rows+1]=row('Source provenance',e.sourceID,nil,{kind='caption',height=58})end
    rows[#rows+1]=row('Back to the post',nil,function()open({post=p.postID,room=p.room})end)
   else entry(rows,p,true);local replies=A.Query(c,{room=p.room,parent=p.postID,cursor=route.cursor,limit=10});if replies then for _,reply in ipairs(replies.items)do entry(rows,reply,true)end;if replies.next then rows[#rows+1]=row('More replies',nil,function()open({post=p.postID,room=p.room,cursor=replies.next})end)end end end
  else rows[1]=caption(why or'The post is expired, hidden, removed or not yet available from a peer.')end
 else
  rows[#rows+1]={actions={{title='Create post',activate=function()A.Composer({room=room,body='',spoiler=false,tags={}})end},
   {title=prefs and prefs.followed[room]and'Unfollow room'or'Follow room',activate=function()A.SetPreference('followed',room,not prefs.followed[room]);refresh()end},
   {title='Mute room',activate=function()A.SetPreference('muted',room,true);refresh()end}},height=74}
  local q={room=not route.view and room or nil,following=route.view=='following',bookmarks=route.view=='bookmarks',guid=route.view=='mine'and ns.PlayerCard.Own()or route.view=='author'and route.authorGUID or nil,sort=route.view=='popular'and'popular'or'recent',cursor=route.cursor,limit=8}
  local feed,why=A.Query(c,q)
  for _,p in ipairs(feed and feed.items or{})do entry(rows,p,false)end
  if not feed or #feed.items==0 then rows[#rows+1]=caption('No eligible posts are known in this view. No global activity has been invented to fill it.')end
  if feed and feed.next then rows[#rows+1]=row('More posts','Stable paged cursor',function()local q=ns.Athena.Copy(route);q.cursor=feed.next;q.scroll=0;open(q)end,{height=42})end
  if route.view=='mine'then rows[#rows+1]=row('Owner publication archive','Finite retained snapshots, including expired posts',function()open({view='archive'})end)end
 end
 if route.view=='archive'then rows={};local history={};for id,v in pairs(prefs.history)do history[#history+1]={id=id,value=v}end;table.sort(history,function(a,b)return a.value.at==b.value.at and a.id<b.id or a.value.at>b.value.at end)
  local offset=tonumber(route.cursor)or 0;if offset<0 or offset%1~=0 or offset>128 then offset=0 end
  for i=offset+1,math.min(#history,offset+10)do local v=history[i].value;local raw=ns.ChronicleBackup.DecodeChunk(v.pair.wire);raw=raw and raw[1];local text=raw and raw.data and raw.data.body;local id=history[i].id;rows[#rows+1]=row(text and text~=''and text or'Attachment/removal snapshot',v.room..' · Retained owner publication history',nil,{stacked=true,height=80});rows[#rows+1]={actions={{title='Export archive copy',activate=function()F.Copy('My retained public post',ns.ChronicleBackup.Encode({v.pair}))end},{title='Remove archive copy',activate=function()F.Confirm('Remove my archive copy?','Only this retained copy is removed. This does not remove the public post or recall copies held by peers.',function()local ok,why=A.ForgetHistory(id,true);if ok then refresh()end;return ok,why end)end}},height=74}end
  if #history>offset+10 then rows[#rows+1]=row('More retained posts',nil,function()open({view='archive',cursor=tostring(offset+10)})end)end;title='My retained publication history'end
 if not prefs then rows[#rows+1]=caption('Local Agora preferences need recovery; originals were retained.')end
 local pulse=A.Pulse and A.Pulse(room)or{status='Unavailable',scope='Recorded by participating Fireside clients · no supported projection available'}
 local pulseRows={caption(pulse.scope),row('Coverage',pulse.status,nil,{height=42})};for _,kind in ipairs({'dungeon','raid','battleground','arena','duel','boss'})do if pulse.counts then pulseRows[#pulseRows+1]=row(kind,tostring(pulse.counts[kind]or 0),nil,{height=34})end end
 pulseRows[#pulseRows+1]=caption('Freshness: '..stamp(pulse.at)..'. Counts do not describe the server population. P2P aggregate totals are unavailable.')
 local tools={};for _,choice in ipairs(U.aetherToolChoices)do local id=choice[1];tools[#tools+1]=row(choice[2],nil,function()return U.OpenAetherTool(id)end,{height=52,wrap=true})end
 return{{id='nav',title='The Agora',x=0,y=0,w=.25,rows=navigation},{id='feed',title=title,x=.25,y=0,w=.5,rows=rows},{id='pulse',title='World Pulse',x=.75,y=0,w=.25,rows=pulseRows},{id='community',title='Aether community status',x=.75,y=540,w=.25,rows={caption(A.Status(c)),row('My player profile','Same canonical Aether profile',function()U.OpenAetherProfile()end)}},{id='aether-tools',title='Aether tools',x=.75,y=700,w=.25,rows=tools}}
end
-- Private owner-approved projections: no raw Chronicle links in public cards.
local labels={dungeon='Dungeon expedition',raid='Raid expedition',battleground='Battleground',arena='Arena match',duel='Duel',boss='World encounter',guild='Guild event',world='Adventure',group='Shared adventure'}
function A.Source(owner,id)
 if not allowed()or owner~=ns.Chronicle.Owner()then return nil,'CURRENT_OWNER_REQUIRED'end
 local st,why=ns.ChronicleActivities.Request(owner);local a=st and ns.ChronicleActivities.View(st,id);if not a or not labels[a.kind]then return nil,why or'SOURCE_UNAVAILABLE'end
 local event=st.events[a.anchor];if not event or event.character~=owner then return nil,'LOCAL_FIRSTHAND_SOURCE_REQUIRED'end
 for _,eid in ipairs(a.evidence or{})do local e=st.events[eid];local origin=e and e.details and e.details.origin;if not e or e.restored or origin=='aether'or origin=='direct_share'or origin=='imported'or origin=='replay'or origin=='synthetic'and not WARDEN_SIMULATOR_ISOLATED then return nil,'IMPORTED_OR_PRIVATE_SOURCE_NOT_SHAREABLE'end end
 local place=a.context or a.place or{};local broad=R.Get(R.Suggest(place.zone));local name=place.instanceName or place.zone;local L=ns.AthenaLoreCodex;local lore=L and L.byTitle[name or''];lore=lore and L.byID[lore]
 local title=lore and(lore.kind=='instance'or lore.zoneCatalog)and lore.title or labels[a.kind]
 local at=a.firstObservedAt or a.startAt or a.firstAt or event.at or 0;at=math.floor(at/86400)*86400
 local run=a.run;local outcome=a.duel and({win='win',loss='loss'})[a.duel.result]or run and run.state=='COMPLETED'and(run.completionBasis=='finishing_encounter'and'final_encounter_won'or'concluded')or a.kind~='dungeon'and a.kind~='raid'and a.endAt and'concluded'or'partial'
 local data={version=1,ownerGUID=ns.PlayerCard.Own(),sourceType=a.kind,sourceID=ns.PackCrypto.Hex(ns.PackCrypto.SHA256(owner..'/'..a.anchor)),title=title,place=broad and broad.id~='world'and broad.title or title,date=at,outcome=outcome,proofClass='OWNER_SHARED_CLIENT_REPORT'}
 return data,{owner=owner,activity=id,sourceID=data.sourceID},R.Suggest(place.zone)
end
function A.CheckSource(d)local e,source=A.Source(d.privateSource.owner,d.privateSource.activity);return e and source.sourceID==d.privateSource.sourceID and ns.ChronicleBackup.Encode(e)==ns.ChronicleBackup.Encode(d.event)end
function A.ShareActivity(owner,id)
 local e,source,room=A.Source(owner,id);if not e then return feedback(false,source)end
 return F.Confirm('Share an Athena observation as a post?',e.title..' · '..e.place..' · '..stamp(e.date)..' · '..e.outcome..'\n\nOnly this limited owner-approved snapshot is included. No roster, raw conversation, loot recipient, precise route or private Chronicle link is shared. This is a client observation, not a server-verified achievement.',function()A.Composer({room=room,body='',event=e,privateSource=source,spoiler=false,tags={'adventure'}});return true end,'Open composer')
end
function A.ActivityChooser()
 local st,why=ns.ChronicleActivities.Request(ns.Chronicle.Owner());if not st then return feedback(false,why)end;local choices,seen={},{}
 for _,a in ipairs(ns.ChronicleActivities.Query(st,{groupReloads=true,limit=40}))do if a and labels[a.kind]and not seen[a.id]then seen[a.id]=true;choices[#choices+1]={a.id,labels[a.kind]..' · '..(a.context and a.context.zone or'Unknown place')};if #choices>=40 then break end end end
 if #choices==0 then return feedback(false,'No eligible owner-recorded activity is available yet.')end
 return F.Form({title='Choose my Athena observation',fields={{key='activity',label='Recorded activity',choices=choices,value=choices[1][1]}},submitLabel='Review safe snapshot',submit=function(v)A.ShareActivity(ns.Chronicle.Owner(),v.activity);return true end})
end
function A.Pulse(room)
 local p=A.Preferences(false);local out={status='Unavailable · opt-in recorded counts off',scope='Recorded by participating Fireside clients · this client only, latest 200 activities; no network-wide totals'}
 if not p or not p.pulse or not ns.AetherNet.Preference()then return out end
 local st=ns.ChronicleActivities.Peek(ns.Chronicle.Owner());if not st then out.status='Unavailable · local activity index is preparing';return out end
 local seen={};out.counts={};out.status='Partial · one participating client';out.at=0
 for _,a in ipairs(ns.ChronicleActivities.Query(st,{groupReloads=true,limit=200}))do local ctx=a and(a.context or a.place)or{};local rid=R.Suggest(ctx.zone)
  if a and labels[a.kind]and not seen[a.id]and(room=='world'or room==rid or room=='pvp'and({battleground=true,arena=true,duel=true})[a.kind]or room=='pve'and({dungeon=true,raid=true,boss=true})[a.kind])then seen[a.id]=true;out.counts[a.kind]=(out.counts[a.kind]or 0)+1;out.at=math.max(out.at,a.lastObservedAt or a.endAt or a.lastAt or 0)end
 end;return out
end
-- Existing extension handles may only open a draft. No publish/upvote API.
local api=OlympusWarden and OlympusWarden.API
if api then function api:OpenComposer(handle,value)
 local ext,why=ns.WardenExtensions.Check(handle,'profile.local_page');if not ext then return false,why end
 if not ns.AetherExtensionContracts.Keys(value,ns.AetherExtensionContracts.Set('room body spoiler'))then return false,'EXTENSION_COMPOSER_SCHEMA'end
 if not R.Valid(value.room)or not A.SafeText(value.body or'')or value.spoiler~=nil and type(value.spoiler)~='boolean'then return false,'EXTENSION_DRAFT_REJECTED'end
 local at=now();local budget=ext.agoraComposerBudget;if not budget or budget.at+60<=at then budget={at=at,count=0};ext.agoraComposerBudget=budget end
 if budget.count>=4 then return false,'EXTENSION_COMPOSER_QUOTA'end;budget.count=budget.count+1
 return F.Confirm('Open an extension-suggested draft?',ext.manifest.title..' suggests a post. Nothing is published or upvoted automatically.',function()A.Composer({room=value.room,body=value.body or'',spoiler=value.spoiler==true,tags={}});return true end,'Open composer')
end end
