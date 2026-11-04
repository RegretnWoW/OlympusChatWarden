-- Semantic, finite template registry. These IDs never contain subject identities.
local _,ns=...
local E=ns.UI2LayoutEngine
local function card(id,label,span,region,protected)
 return {id=id,label=label,span=span or 6,region=region or 'main',minSpan=3,minWidth=span==12 and 280 or 300,canHide=not protected,canCollapse=not protected}
end
local function identity(label) local s=card('identity',label,12,'header',true);s.canResize=false;s.canMove=false;s.minSpan=12;return s end
local function register(name,items)
 if name=='intel.player'then items[#items+1]=card('artifacts','Athena artifacts',8,'left')end
 local status=card('status','Loading / unavailable state',12,'header',true);status.canResize=false;status.canMove=false;status.minSpan=12;status.system=true;items[#items+1]=status
 for n,s in ipairs(items) do s.order=n end;E.Register(name,items)
end
register('overview',{card('hero','Continue your journey',9,'left'),card('quick','Quick actions',3,'right'),card('character','Character overview',6),card('recent','Recent adventure',6),card('signals','Recent signals',4),card('people','People & shared history',4),card('fellowship','Fellowship opportunities',4),card('aether','Aether activity',4),card('resources','Resources & support',4),card('protection','Protection summary',6),card('health','Database health',6)})
register('overview.search',{card('results','Search results',12)})
register('intel.player',{identity('Player identity, rating & date'),card('about','About Me',4,'right'),card('activities','Adventures',8,'left'),card('companions','Companions',4,'right'),card('progression','Progression',4),card('posts','Agora posts',8,'left'),card('story','Character story',4),card('notes','Private notes & watchlist',4),card('fellowship','Fellowship',4,'right'),card('pvp','PvP history',4,'right'),card('claims','Additional shared information',4),card('coverage','About this history',12),card('presence','Activity & current group',4),card('talents','Talents',8),card('equipment','Equipment',8),card('history','Captured history',4),card('combat','Combat evidence',8),card('advisory','Local protection advisory',4),card('extensions','Approved extensions',4,'right')})
register('intel.extension',{card('extensions','Installed extension page',12,'main',true)})
register('intel.public',{card('profile','Public profile preview',12,'header',true)})
register('intel.guild',{identity('Guild Profile'),card('members','Known members',3),card('events','Shared events',3),card('posts','Agora posts',6)})
register('intel.group',{card('group','Group intelligence',12,'header',true)})
for _,name in ipairs({'intel.browse','chronicle.browse'}) do register(name,{card('filters','Filters & actions',3,'left'),card('results','Retained subjects',6,'center'),card('selection','Selected observation',3,'right')}) end
register('chronicle.activity',{identity('Activity identity & date'),card('encounters','Encounters & progression',8,'left'),card('scoreboard','Match scoreboard',12),card('quests','Quests & objectives',4),card('loot','Loot & rewards',4),card('participants','Participants',4,'right'),card('combat','Combat highlights',4,'right'),card('timeline','Significant moments',8,'left'),card('recollections','Your perspective',4),card('coverage','Sources & coverage',12),card('share','Share this event',6),card('discussion','Event discussion',6),card('feedback','Event feedback',6),card('duel','Duel observations',12),card('duel-self','Your duel observations',6),card('duel-opponent','Opponent observations',6),card('grouping','Run grouping',6)})
register('messages',{card('tools','Chat tools',3,'left'),card('content','Conversation, review & administration',6,'center'),card('selection','Selected entry & actions',3,'right')})
register('shield',{card('tools','Shield actions',3,'left'),card('contacts','Contacts',6,'center'),card('selection','Selected contact',3,'right'),card('alerts','Recent protection alerts',3,'left')})
register('mentions',{card('filters','Signal filters',3,'left'),card('history','Notification history',6,'center'),card('selection','Selected notification',3,'right'),card('phrases','Watched phrases',3,'right')})
register('relay',{card('tools','Relay actions',3,'left'),card('content','Reports, Direct Share & inbox',6,'center'),card('selection','Details & actions',3,'right')})
register('settings',{card('categories','Settings categories',3,'left',true),card('controls','Selected category controls',6,'center',true),card('state','State & feedback',3,'right')})
register('settings.help',{card('content','Guide content',9,'left'),card('topics','Topics & navigation',3,'right',true)})
register('settings.inspector',{card('source','Developer source inspector',12)})
-- Specialized adapters customize only Warden-owned surrounding regions.
register('journey.chrome',{card('owner','Character selector',6,'left',true),card('source','Synthetic source notice',6,'right',true),card('library','Library drawer side',4,'left')})
register('olympus.panel',{card('features','Fireside module shortcuts',12,'header'),card('activity','Fireside activity stream',12,'main',true)})
for _,pair in ipairs({{'intel.player','activities',620},{'intel.player','talents',650},{'chronicle.activity','scoreboard',660},{'intel.player','posts',400}}) do E.templates[pair[1]].cards[pair[2]].minWidth=pair[3] end
-- Host chrome uses fixed full-width child regions; only order/hide is meaningful.
for _,s in pairs(E.templates['olympus.panel'].cards) do s.canResize=false;s.minSpan=12;s.maxSpan=12;s.canCollapse=false end
E.templates['journey.chrome'].cards.library.canCollapse=false

-- Stable lane defaults. Width is a lane property; cards never cross a gutter.
local lanes={
 ['overview']={hero='center',quick='right',character='left',recent='center',signals='left',people='left',fellowship='center',aether='right',resources='right',protection='left',health='right'},
 ['intel.player']={about='left',activities='center',companions='right',posts='center',progression='left',story='right',notes='left',fellowship='right',pvp='right',claims='left',coverage='left',presence='left',talents='center',equipment='center',history='left',combat='center',advisory='right'},
 ['intel.guild']={members='left',posts='center',events='right'},
 ['chronicle.activity']={encounters='center',scoreboard='center',quests='left',loot='left',participants='right',combat='right',timeline='center',recollections='right',coverage='left',share='left',discussion='center',feedback='right'}
}
for name,t in pairs(E.templates) do for id,s in pairs(t.cards) do
 if s.region=='header' and name~='olympus.panel' then s.canMove=false;s.canResize=false;s.minSpan=12;s.span=12 end
 if lanes[name] and lanes[name][id] then s.region=lanes[name][id] elseif s.region=='main' then s.region='center' end
end end

register('agora',{identity('The Agora'),card('nav','Rooms & feeds',3,'left',true),card('feed','Posts',6,'center',true),card('pulse','World Pulse',3,'right'),card('community','Aether community status',3,'right'),card('aether-tools','Aether tools',3,'right')})
