-- Explicit, staged capture choices. Opening or deferring never grants consent.
local _,ns=...;local O=ns.UI2Onboarding
O.VERSION=4;O.RECORDING_REVIEW=1
function O.NeedsRecordingReview()
 if not ns.DB then return false end
 local r=ns.DB.firesideRecordingReview;local owner=ns.Chronicle.Owner()
 return not(type(r)=='table'and r.version==1 and type(r.owners)=='table'and owner and r.owners[owner]==O.RECORDING_REVIEW)
end
function O.MarkRecordingReview()
 local owner=ns.Chronicle.Owner();if not owner then return false,'Your character identity is still loading. Please try again.'end
 local r=ns.DB.firesideRecordingReview
 if r~=nil and(type(r)~='table'or r.version~=1 or type(r.owners)~='table')then return false,'The setup review preference needs recovery; its original value has been kept.'end
 r=r or{version=1,owners={}};r.owners[owner]=O.RECORDING_REVIEW;ns.DB.firesideRecordingReview=r;return true
end
local home,adventures,tools,final=unpack(O.steps)
adventures.title='Choose what you want to remember'
adventures.help='These choices affect what Fireside can save from now on. Events missed while recording is off cannot be reconstructed later. Existing history is kept when you turn a choice off. Nothing here automatically shares your history.'
local function add(step,key,title,help,get,set,risk,requires,group)
 local v={key=key,title=title,help=help,get=get,set=set,risk=risk,requires=requires,group=group}
 step.options[#step.options+1]=v;return v
end
local function page(title,help)return{title=title,help=help,options={}}end
local recording=O.byKey.recording
recording.title='Record my adventures'
recording.help='Keep supported quests, encounters, routes and character history for Atlas and Athena’s Journal. Other history options below also need this on.'
recording.risk='Adventures played while this is off will be missing from your history. Turning it on later cannot fill those gaps.'
add(adventures,'merchantHistory','Keep merchant history','Save readable details of your own auction listings, seller invoices and completed trades. Local to this character; no mail bodies or inferred profit.',ns.ChronicleMerchant.Selected,ns.ChronicleMerchant.SetEnabled,
 'Missed trades and auction changes cannot be recovered later. Some current listings may still be visible, but earlier states are gone.',{'recording'})
add(adventures,'duelHistory','Keep duel history','Save supported accepted duels, available before/after gear and talents, and observed combat details. Unavailable results remain unknown.',function()local p=ns.ChronicleStore.PreferenceRoot();return p and p.duels==true and p.duelConsent==1 end,ns.ChronicleDuels.SetEnabled,
 'Duels played while this is off cannot be added retrospectively.',{'recording'})
local people=page('Remember the people you meet','These are private observations available to your client, not proof of what another player did. Main adventure recording is also required. These choices do not publish a profile or enable Aether sharing.')
add(people,'playerObservations','Keep visible player observations','Save available player identities, sightings and dated states, plus supported observations of Important players. Hidden or unreadable information remains unknown.',ns.IntelWitness.Selected,ns.IntelWitness.SetEnabled,
 'Missed sightings and player states cannot be reconstructed after those players leave or change equipment.',{'recording'})
add(people,'contactInspect','Aether inspection snapshots after direct contact','Try one normal inspection for a verified small-party companion or direct duel opponent. Save only available dated gear and talents; no scans of passing strangers.',ns.AthenaFirstContact.Selected,ns.AthenaFirstContact.SetEnabled,
 'You may miss the gear and talents a player used at that encounter. Inspecting them later cannot recover an earlier setup.',{'recording','playerObservations'})
add(people,'protectionLog','Keep Vigil and Aegis activity history','Keep a recent local review log. Older entries you have not bookmarked may be replaced when it fills.',function()return ns.DB.history~=false and ns.DB.persistHistory~=false end,function(v)
 if v then local ok,why=ns.History.SetEnabled(true);if ok==false then return false,why end end
 -- Pausing the log must not invoke the legacy erase-on-disable persistence
 -- switch. Keep existing records and recovery copies when this choice is off.
 ns.DB.history=v;ns.PolicyChanged();return true
end,'New review entries will be missed while this is off. Turning it back on cannot recreate those entries.')
add(people,'incidentHistory','Keep minimal protection history','Keep small private summaries of repeated filter decisions and Aegis actions. No message bodies or allegations.',ns.AthenaIncidents.Selected,function(v)
 if v then local ok,why=ns.Permissions.Resume('incidents',true);if not ok then return false,why end end
 return ns.AthenaIncidents.SetEnabled(v)
end,'Protection can still work, but missed historical summaries cannot be recreated later.',{'recording','protectionLog'})
local moments=page('Athena’s Moments · screenshots','Fireside can request screenshots of selected recorded milestones. Images stay in WoW’s screenshot folder. This is separate from adventure history and saved conversations; unavailable screenshot APIs cannot capture an image.')
add(moments,'momentsEnabled','Take automatic milestone screenshots','Capture supported moments as they happen. You can still take screenshots yourself when this is off.',function()return ns.AthenaMoments.Status().enabled end,function(v)return ns.AthenaMoments.Set('enabled',v)end,
 'An automatic screenshot that was not taken cannot be recreated after the scene has passed.',{'recording'})
for _,row in ipairs({{'level','Level gains'},{'quest','Quest milestones'},{'boss','Boss encounters'},{'instance','Dungeon and instance moments'},{'loot','Loot moments'},{'pvp','Battleground and PvP moments'},{'duel','Duel moments'},{'exploration','Exploration moments'}})do
 local key,title=row[1],row[2]
 add(moments,'moment_'..key,title,'Include these supported milestones in automatic screenshots.',function()return ns.AthenaMoments.Status().categories[key]~=false end,function(v)return ns.AthenaMoments.Set(key,v)end,
  'Automatic screenshots for this category will be missed. Adventure records have their own recording choice.',{'recording','momentsEnabled'})
end
local conversations=page('Moments · meaningful conversations','Selected delivered text can become a private memory. Adventure recording, conversation preservation and each chosen channel must be on. Whispers, officer chat and exact Journal quotations are separate choices. Nothing is enabled by browsing this page.')
local function policy()
 local store=ns.AthenaConversations.Store();local root=store.root;local owner=ns.Chronicle.Owner()
 local row=type(root)=='table'and root.owners and root.owners[owner]
 return row and row.policy or{enabled=false,scopes={}}
end
local function conversation(key,title,help,risk,requires,scope)
 return add(conversations,'conversation_'..key,title,help,function()local p=policy();return(scope and p.scopes or p)[key]==true end,nil,risk,requires,'conversations')
end
conversation('enabled','Preserve meaningful conversations','Allow private conversation memories from the channels you select below. Temporary suggestions are not a permanent archive.',
 'Text missed while this is off cannot be recovered by turning it on later.',{'recording'})
conversation('autoCandidates','Suggest meaningful exchanges','Offer eligible recent exchanges for you to review and pin. Suggestions expire; they are not automatically kept.',
 'You will not receive these suggestions. An unpinned temporary exchange can expire.',{'recording','conversation_enabled'})
conversation('autoPreserve','Keep meaningful moments automatically','Keep eligible, event-linked exchanges from your selected channels without having to pin each one.',
 'You must pin exchanges yourself before temporary text expires, or those memories may be lost.',{'recording','conversation_enabled'})
conversation('showDirectQuotes','Allow exact quotes in my private Journal','Show preserved text as quotations in your own Journal. Turning this off hides quotations; it does not erase preserved memories.',nil,{'recording','conversation_enabled'})
for _,row in ipairs({{'partyRaid','Party and raid chat'},{'guild','Guild chat'},{'sayEmote','Say, yell and emotes'},{'instance','Instance chat'},{'publicChannels','Public and Trade channels'},{'whispers','Private whispers'},{'officer','Officer chat'},{'npcDialogue','Observed NPC and quest dialogue'}})do
 local key,title=row[1],row[2]
 conversation(key,title,'Allow eligible delivered text from this channel to be preserved as a private memory.',
  'Missed text from this channel cannot be retrieved later. Only future eligible exchanges can be preserved.',{'recording','conversation_enabled'},true)
end
local chat=page('Optional local chat log','The Logos chat log is separate from conversation memories. It keeps recent chat; older lines you have not bookmarked may be replaced when it fills. Nothing is automatically reported or shared.')
for _,row in ipairs({{'whispers','Include whispers','Include private whispers in the local chat log.'},{'guild','Include guild and officer chat','Include these private channels in the local chat log.'},{'enabled','Retain a local chat log','Keep recent chat that WoW delivers to you in the Logos log.'}})do
 local key,title,help=row[1],row[2],row[3]
 add(chat,'chat_'..key,title,help,function()return ns.ChatCapture.db and ns.ChatCapture.db[key]==true end,function(v)local ok=ns.ChatCapture.SetOption(key,v);return ok~=false end,
  'Messages not retained while this is off cannot be fetched from WoW later.',key~='enabled'and{'chat_enabled'}or nil)
end
local live=page('Aether Live','Welcome to the future of Fireside.')
live.tips={{'Aether Live is our real-time multiplayer system,','designed to bring Olympus members together inside the living world of Aetheria, no matter where their adventures take them in Azeroth.',96},
 {'Our vision is simple:','a shared world where players can meet, explore, interact, and form friendships that carry beyond Fireside and into World of Warcraft itself.',96},
 {'Imagine meeting someone in the streets of Pyragore,','sharing a drink at the tavern, and setting off together on an adventure in Azeroth.',82},
 {"That’s the world we’re building.",'Aether Live is still experimental and will continue evolving as more players join, new locations open, and multiplayer features expand.',96},
 {'Participation is optional, and your personal adventure history remains protected.','One Aetheria. One Olympus. Keep the Fire Alive.',82},
 {'When you are ready','Choose Enter Aether Live at the top of Fireside and review the consent screen. Your key is prepared automatically; historical enrollment is not required to enter Aetheria.',96},
 {'Find your company','Connected adventurers can see one another move when they explore the same place. Click a player’s name to open their Aether profile, or choose Players in Aether Live to find company in another place.',110},
 {'Your private world is kept','Recorded characters wait in your private world and return when you leave Live. Discovery may take a little time, and some appearances are still approximate. Relay and recording choices stay separate.',110}}
O.steps={live,home,adventures,people,moments,conversations,chat,tools,final}
O.options={};O.byKey={}
for _,s in ipairs(O.steps)do for _,v in ipairs(s.options)do O.options[#O.options+1]=v;O.byKey[v.key]=v end end
function O.OptionWarning(v)
 local missing={}
 for _,key in ipairs(v.requires or{})do if not O.draft[key]then missing[#missing+1]=O.byKey[key].title end end
 if #missing>0 then return 'Paused until you enable: '..table.concat(missing,', ')..'. '..(v.risk or'') end
 if not O.draft[v.key]then return v.risk end
end
function O.RecordingSummary()
 local off={}
 for _,v in ipairs(O.options)do if v.risk and(not O.draft[v.key]or O.OptionWarning(v))then off[#off+1]=v.title end end
 return #off==0 and'Your selected recording choices are ready. Saving does not publish your history.'or
  'Off or paused: '..table.concat(off,', ')..'. These choices are optional. Missed events, text and automatic screenshots cannot be recovered later; turn choices on now if you want to keep them.'
end
function O.ApplyRecordingGroups()
 local changed=false;for _,v in ipairs(conversations.options)do changed=changed or O.dirty[v.key]end
 if not changed then return true end
 local p=ns.Athena.Copy(policy());p.scopes=p.scopes or{}
 for _,v in ipairs(conversations.options)do if O.dirty[v.key]then
  local key=v.key:sub(#'conversation_'+1)
  if key=='enabled'or key=='autoCandidates'or key=='autoPreserve'or key=='showDirectQuotes'then p[key]=O.draft[v.key]else p.scopes[key]=O.draft[v.key]end
 end end
 local ok,why=ns.AthenaConversations.SetConsent(ns.Chronicle.Owner(),p,true)
 if ok==false then return false,'Conversation choices: '..tostring(why or'Please try again.')end
 for _,v in ipairs(conversations.options)do O.dirty[v.key]=nil;O.original[v.key]=O.draft[v.key]end
 return true
end
