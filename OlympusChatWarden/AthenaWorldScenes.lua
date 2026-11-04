-- Small original lore compositions over dated references, not new collectors.
local _,ns=...
local W={VERSION='world-scenes-9.1'};ns.AthenaWorldScenes=W
local manual='https://assets.blz-contentstack.com/v3/assets/blt3452e3b114fab0cd/blt2e9295db02a222fc/6025bcbb6968b53d529edb2a/media_manual_classic_enUS.pdf'
local war3='https://worldofwarcraft.blizzard.com/en-us/story/timeline/chapter-4'
local forsaken='https://news.blizzard.com/en-us/article/24301511/wage-war-once-more-with-warcraft-iii-reforged-forsaken-kingdom'
local deadmines='https://news.blizzard.com/en-us/article/24095666/unveiling-cataclysm-classic-zones-dungeons-and-pvp-season-9'
local peace='https://worldofwarcraft.blizzard.com/en-gb/news/9979107/the-library-cycle-of-hatred'
local elune='https://worldofwarcraft.blizzard.com/en-gb/news/10034190/new-lore-tyrande-and-malfurion-story-available'
local questSource=ns.AthenaQuestData and ns.AthenaQuestData.sourceURL
local function Copy(v) return ns.AthenaJournal.Copy(v) end
local function Card(title,source,body,variants,extra)
 local c=extra or {};c.title=title;c.sourceURL=source;c.body=body;c.variants=variants;c.era='FOREVER_START';return c
end
W.places={
 ['Westfall']=Card('Westfall',questSource,
  'Westfall’s farms belonged to the kingdom of Stormwind, yet its fields and settlements had become the setting of hunger and the Defias rebellion.',{
   'Westfall spread beneath an open sky, its farms carrying a quieter part of Stormwind’s troubled history. The kingdom’s great wars had left ordinary lives to reckon with their aftermath.',
   'Beyond Stormwind’s walls lay Westfall: farm country where the work of feeding a kingdom met the unrest of the Defias. Here, the struggles of Azeroth had names smaller than those of kings.'}, {}),
 ['Duskwood']=Card('Duskwood',questSource,
  'Duskwood’s people kept their settlements amid a darkened forest threatened by the undead. Darkshire and its Night Watch stood within that shadow.',{
   'Duskwood wore its darkness like an old inheritance. Around Darkshire, the Night Watch held to the living world while the forest and its dead pressed close.',
   'The story turned beneath Duskwood’s shadowed boughs. The troubles of Darkshire belonged to the living; beyond the settlement, the restless dead made another claim upon the forest.'}, {}),
 ['Darkshore']=Card('Darkshore',questSource,
  'Along Darkshore, the kaldorei lived beside an ancient coast of forests and ruins. Auberdine joined the settlements of the shore to the wider world.',{
   'Darkshore lay between old forest and open sea. Around Auberdine, the daily concerns of its people unfolded beside ruins whose histories reached far beyond a single lifetime.',
   'The coast of Darkshore carried the marks of an elder world. The sea and the forest framed a country where an ordinary errand could lead toward the remains of an ancient age.'}, {}),
 ['The Barrens']=Card('The Barrens',manual,
  'The Barrens stretched across central Kalimdor, a broad land of scattered settlements and long distances between them.',{
   'The Barrens opened wide across Kalimdor. Beyond the shelter of its settlements lay a country of distance and exposure, where each small outpost held its own place in the Horde’s new world.',
   'In the Barrens, the tale found a wider horizon. Its scattered settlements belonged to the daily labor of building a future on Kalimdor, far from the lands the orcs had left behind.'}),
 ['Silverpine Forest']=Card('Silverpine Forest',questSource,
  'Silverpine belonged to the wounded lands of Lordaeron. Its settlements and old keeps stood in the long aftermath of the Scourge.',{
   'Silverpine’s forest stood in the shadow of fallen Lordaeron. The wars of princes had passed through that kingdom; their aftermath remained among its settlements, ruins, and graves.',
   'Beneath Silverpine’s trees, the broken history of Lordaeron drew close. Here, the consequences of the Scourge belonged to the land itself, rather than to a distant chronicle.'}, {}),
 ['Teldrassil']=Card('Teldrassil',manual,
  'Teldrassil was a new World Tree, a home for the night elves amid the upheaval that followed the Third War.',{
   'Teldrassil raised a new home above the sea. For the kaldorei, its boughs belonged to the uncertain years after the Third War, when ancient lives had to find a place in a changed world.',
   'Beneath Teldrassil’s branches, a younger beginning grew from the history of an ancient people. The war at Hyjal lay behind the kaldorei; the shape of what followed was still unfolding.'}),
 ['Dun Morogh']=Card('Dun Morogh',manual,
  'The snowy mountains of Dun Morogh surrounded Ironforge, the dwarven stronghold beneath the mountain.',{
   'Dun Morogh’s mountain country gave the tale a harder outline. Within those heights lay Ironforge; beyond its shelter, the snowy reaches had their own demands upon the people who called them home.',
   'The mountains of Dun Morogh stood around Ironforge’s deep halls. Out in that white country, the affairs of one adventurer belonged to the life of a kingdom rooted in stone.'}),
 ['Redridge Mountains']=Card('Redridge Mountains',questSource,
  'Lakeshire stood among the Redridge Mountains, where the settlement’s defenders faced gnolls and Blackrock orcs.',{
   'Redridge’s mountain country held Lakeshire and its uncertain peace. Beyond the settlement, the threats of gnolls and Blackrock orcs gave the land’s troubles a nearer face.',
   'Around Lakeshire, the Redridge Mountains formed the setting for another part of Stormwind’s unfinished struggle. The protection of a settlement was work far from the songs of great victories.'}, {}),
}
W.instances={
 ['The Deadmines']=Card('The Deadmines',deadmines,
  'The Deadmines were old gold workings beneath Westfall, abandoned during the First War and later made a base by the Defias Brotherhood.',{
   'Beneath Westfall’s fields, the old workings opened into darkness. Once, the Deadmines had fed Stormwind’s wealth; abandonment and the Defias had given those depths another history.',
   'The Deadmines carried the memory of gold and labor beneath a country troubled by rebellion. Above lay Westfall’s farms. Below, the abandoned workings had become a refuge for the Defias.',
   'Stormwind’s old hunger for gold had driven these passages beneath Westfall. War had emptied them, and the Defias had claimed what the kingdom left behind. The Deadmines belonged to that darker inheritance.'}, {aliases={'Deadmines'}}),
 ['Wailing Caverns']=Card('Wailing Caverns',questSource,
  'The caverns beneath the Barrens were bound to the druid Naralex and a dream of restoring the land, a purpose overtaken by nightmare.',{
   'Beneath the Barrens lay a dream turned inward upon itself. The Wailing Caverns had become bound to Naralex’s troubled sleep, where the hope of renewal had drawn close to nightmare.',
   'The Wailing Caverns opened beneath the Barrens, carrying a stranger trouble than the open country above. A druid’s dream of renewal lay at the heart of their story, tangled in nightmare.'}, {requiredQuestMention=true}),
 ['Shadowfang Keep']=Card('Shadowfang Keep',questSource,
  'Shadowfang Keep stood over Silverpine as a stronghold bound to Arugal and the worgen.',{
   'Shadowfang Keep rose above Silverpine’s wounded country, its stone walls caught in the history of Arugal and the worgen. Within that old stronghold, Lordaeron’s ruin took another shape.',
   'Silverpine’s shadow gathered around Shadowfang Keep. The old walls offered no simple refuge: Arugal and the worgen belonged to the keep’s darker story.'}, {requiredQuestMention=true}),
 ['Blackfathom Deeps']=Card('Blackfathom Deeps',questSource,
  'Blackfathom Deeps occupied ancient ruins beneath the coast of Ashenvale, a sacred place overtaken by darker powers.',{
   'Under Ashenvale’s coast, Blackfathom Deeps held the remains of an older, sacred world. The broken sanctuary had become the dwelling of powers far removed from its first purpose.',
   'Blackfathom Deeps lay where ancient ruins met the sea. Here, the night elves’ long history descended into a drowned sanctuary whose old holiness offered little assurance.'}, {}),
 ['Scarlet Monastery']=Card('Scarlet Monastery',questSource,
  'The Scarlet Monastery was a stronghold of the Scarlet Crusade, whose war against the undead had hardened into fanaticism.',{
   'The Scarlet Monastery gave Lordaeron’s struggle a different face. Within its walls, the crusade against the undead had become a faith sharpened into fanaticism.',
   'Beyond the monastery’s walls lay a kingdom broken by the Scourge. Within them stood the Scarlet Crusade, clinging to a merciless answer to that ruin.'}, {}),
 ['Uldaman']=Card('Uldaman',questSource,
  'Uldaman’s ancient halls were bound to the titans and the search for the dwarves’ origins.',{
   'Uldaman carried a history older than the kingdoms above it. In those buried halls, the dwarves’ search for their origins reached toward the works of the titans.',
   'The halls of Uldaman belonged to the deep history of Azeroth. Beneath their stone lay questions of the titans and the beginnings of the dwarven people.'}, {}),
 ['Blackrock Depths']=Card('Blackrock Depths',questSource,
  'Blackrock Depths lay within Blackrock Mountain, a vast stronghold of the Dark Iron dwarves.',{
   'Within Blackrock Mountain, the depths became a realm of stone and fire. The Dark Iron stronghold carried its own long history beneath the conflicts of the surface.',
   'Blackrock Depths drew the tale below the mountain’s scarred heights. Here lay the Dark Iron stronghold, a kingdom in the deep places of Azeroth.'}, {}),
 ['Molten Core']=Card('Molten Core','https://news.blizzard.com/en-gb/article/24165121/20th-anniversary-realms-molten-core-and-onyxia-s-lair-now-live',
  'Deep within Blackrock Mountain, the legacy of a dwarven civil war led to Ragnaros and his elemental servants.',{
   'At the mountain’s molten heart, an older calamity still burned. Thaurissan’s summoning had bound Blackrock’s history to Ragnaros; the Molten Core was the realm left within that wound.',
   'The Molten Core lay beneath the struggles of kings and clans, in a dominion of fire. The consequences of Thaurissan’s summoning had outlasted the war that called it forth.'}),
}
W.figures={
 Card('Thrall',war3,'Thrall was the shaman who freed the captive orcs and led the renewed Horde to Kalimdor.',{
  'Thrall’s name carried the passage from captivity toward a new homeland. The shaman had led the orcs to Kalimdor, where their future became entangled with the fate of Azeroth.',
  'Behind the name of Thrall lay the liberation of the orcs and the long crossing to Kalimdor. The Horde’s new beginning had been forged in the shadow of the Third War.'},{key='thrall',aliases={'Thrall'}}),
 Card('Jaina Proudmoore',peace,'Jaina Proudmoore was a human mage whose history included the alliance with Thrall against the Burning Legion.',{
  'Jaina Proudmoore’s history crossed the old divide between human and orc. She and Thrall had stood against the Legion, leaving a difficult hope for peace amid the hatred that survived the war.',
  'The name of Jaina Proudmoore belonged to a world that had briefly set old enmities aside. Her part in the struggle against the Legion linked her history with Thrall’s, though the peace between their peoples remained fragile.'},{key='jaina',aliases={'Jaina Proudmoore','Lady Jaina Proudmoore'}}),
 Card('Sylvanas Windrunner',forsaken,'Sylvanas Windrunner led the Forsaken as they broke from the Scourge and established a foothold in the Undercity.',{
  'Sylvanas Windrunner’s name belonged to Lordaeron’s broken aftermath. Beneath the ruins of the old kingdom, the Forsaken had begun to claim an existence beyond the Scourge’s dominion.',
  'The history surrounding Sylvanas Windrunner was one of fallen Lordaeron and a people struggling free of the Scourge. The Undercity became a foothold for that uncertain future.'},{key='sylvanas',aliases={'Sylvanas Windrunner','Lady Sylvanas'}}),
 Card('Tyrande Whisperwind',elune,'Tyrande Whisperwind was the high priestess of Elune and a leader of the kaldorei, shaped by millennia of struggle against the Legion.',{
  'Tyrande Whisperwind’s name reached into the long memory of the kaldorei. As Elune’s high priestess, she had led her people through struggles far older than the lives of Azeroth’s younger kingdoms.',
  'The high priestess Tyrande Whisperwind belonged to the ancient history of the night elves. Elune’s faith and the long war against the Legion framed the world from which her people now emerged.'},{key='tyrande',aliases={'Tyrande Whisperwind'}}),
 Card('Arthas Menethil',war3,'Arthas Menethil was the prince of Lordaeron whose struggle against the Scourge ended in his service to the Lich King.',{
  'Arthas Menethil had gone to war against the Scourge as Lordaeron’s prince. The path of that struggle had instead bound him to the Lich King, and his kingdom had borne the terrible consequence.',
  'The name of Arthas Menethil lay over the ruin of Lordaeron. Once its defending prince, he had become a servant of the power he sought to destroy.'},{key='arthas',aliases={'Arthas Menethil','Prince Arthas'}}),
 Card('Edwin VanCleef',questSource,'Edwin VanCleef was bound to the Defias Brotherhood and the unrest facing Stormwind and Westfall.',{
  'Edwin VanCleef’s name bound the troubles of Westfall to the Defias Brotherhood. The rebellion reached beyond scattered banditry, into the unfinished quarrel between Stormwind and those who had labored for it.',
  'Behind the name of Edwin VanCleef stood the Defias Brotherhood. The unrest of Westfall was part of a larger grievance, one whose shadow reached back toward Stormwind itself.'},{key='vancleef',aliases={'Edwin VanCleef','VanCleef'}}),
}
local function Hash(seed) local n=0;for i=1,#seed do n=(n*33+seed:byte(i))%2147483647 end;return n end
function W.Variant(card,seed,used)
 local variants=card.variants or {card.body};local first=Hash(tostring(seed)..'/'..card.title)%#variants+1;local pick=first
 for step=0,#variants-1 do local n=(first+step-1)%#variants+1;if not used or not used[card.title..'/'..n] then pick=n;break end end
 if used then used[card.title..'/'..pick]=true end
 local out=Copy(card);out.body=variants[pick];out.variant=pick;out.variants=nil
 out.worldRef='world:'..W.VERSION..'/'..(card.key or card.title)..'/'..pick;out.sourceVersion=W.VERSION
 out.kind='WORLD_HISTORY';out.confidence='SOURCE_SUPPORTED_SETTING';out.personalExperienceProven=false;out.observedWeather=false;return out
end
function W.Setting(place,seed,used)
 if type(place)~='table' then return end
 local card
 if place.inInstance==true and (place.instanceType=='party' or place.instanceType=='raid') then
  local name=place.instanceName or place.zone;card=W.instances[name]
  if not card then for _,row in pairs(W.instances) do for _,alias in ipairs(row.aliases or {}) do if name==alias then card=row end end end end
 else card=W.places[place.zone] end
 if card and card.requiredQuestMention then
  card=Copy(card)
  if card.title=='Wailing Caverns' then card.variants={
   'Beneath the Barrens, the wide country gave way to the Wailing Caverns. Their deep passages belonged to another part of the land’s story, beyond the open horizon above.',
   'The Wailing Caverns lay below the Barrens, a deep world within the land. The horizon of the open country yielded to passages enclosed by stone.'}
  else card.variants={
   'Shadowfang Keep stood above Silverpine, its old walls set against a country haunted by Lordaeron’s fall. The stronghold carried that history within its stone.',
   'Above Silverpine’s wounded country stood Shadowfang Keep. Its old halls belonged to a kingdom whose ruin had left little untouched.'} end
 end
 return card and W.Variant(card,seed,used)
end
function W.NamedFigure(name)
 for _,card in ipairs(W.figures) do for _,alias in ipairs(card.aliases) do if name==alias then return Copy(card) end end end
end
local function Mention(text,alias)
 if not ns.CanRead(text) then return false end
 local lower=text:lower();alias=alias:lower();local at=1
 while true do local a,b=lower:find(alias,at,true);if not a then return false end
  if not lower:sub(a-1,a-1):match('%a') and not lower:sub(b+1,b+1):match('%a') then return true end;at=b+1
 end
end
function W.Figure(ref,seed,used)
 if not ref or not ref.narrative then return end
 for _,card in ipairs(W.figures) do if not used or not used[card.key] then
  local found=false
  for _,alias in ipairs(card.aliases) do
   if ref.giverName==alias then found=true end
   for _,atom in ipairs(ref.narrative.atoms or {}) do if Mention(atom.text,alias) then found=true end end
  end
  if found then
   if used then used[card.key]=true end;local out=W.Variant(card,seed);out.questWorldRef=ref.worldRef;out.questID=ref.questID or ref.id;return out
  end
 end end
end
function W.OwnerKill(f,owner)
 local d=f.details or {};local own=owner:match('/(Player%-.+)$')
 if f.family~='native_kill_credit' or f.source~='PARTY_KILL' or d.entityKind~='Creature' or type(d.targetGUID)~='string' or not d.targetGUID:match('^Creature%-') then return false end
 if d.credit=='self native credit' and d.attackerGUID==own then return true,'self' end
 if d.credit=='current pet native credit' and type(d.attackerGUID)=='string' and d.attackerGUID:match('^Pet%-') then return true,'pet' end
 return false
end
function W.Catalogue()
 local rows={};for kind,source in pairs({place=W.places,instance=W.instances}) do for key,card in pairs(source) do rows[#rows+1]={id=kind..':'..key,title=card.title,variants=#card.variants,sourceURL=card.sourceURL} end end
 for _,card in ipairs(W.figures) do rows[#rows+1]={id='figure:'..card.key,title=card.title,variants=#card.variants,sourceURL=card.sourceURL} end
 table.sort(rows,function(a,b) return a.id<b.id end);return rows
end
