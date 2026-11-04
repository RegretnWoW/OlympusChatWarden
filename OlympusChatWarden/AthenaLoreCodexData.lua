-- Original, concise reference atoms. Era: Warcraft III / Classic starting world.
-- UNKNOWN is a missing field, never a license to invent a connecting fact.
local _,ns=...
local D={version='lore-10.1',era='WC3_CLASSIC_FOREVER',entries={},sources={
 first='https://worldofwarcraft.blizzard.com/en-us/story/timeline/chapter-1',
 second='https://worldofwarcraft.blizzard.com/en-gb/story/timeline/chapter-2',
 portal='https://worldofwarcraft.blizzard.com/en-gb/story/timeline/chapter-03',
 third='https://worldofwarcraft.blizzard.com/en-us/story/timeline/chapter-4',
 throne='https://worldofwarcraft.blizzard.com/en-gb/story/timeline/chapter-5',
 origins='https://news.blizzard.com/en-us/article/23229617/warcraft-iii-the-story-so-far',
 illidan='https://worldofwarcraft.blizzard.com/en-us/news/23679744',
 malfurion='https://news.blizzard.com/en-us/article/24164437/plant-the-seeds-of-protection-with-malfurion-stormrage',
 jaina='https://news.blizzard.com/en-gb/article/16887806/jaina-hero-week',
 cairne='https://worldofwarcraft.blizzard.com/en-us/news/3077998/leaders-of-the-alliance-and-horde-baine-bloodhoof',
 voljin='https://worldofwarcraft.blizzard.com/en-gb/media/short-story/voljin-the-judgment',
 stormwind='https://news.blizzard.com/en-gb/article/23149291/wow-classic-city-tour-stormwind',
 darnassus='https://news.blizzard.com/en-us/article/23149531/wow-classic-city-tour-darnassus',
 orgrimmar='https://news.blizzard.com/en-gb/article/23156369/wow-classic-city-tour-orgrimmar',
 thunderbluff='https://news.blizzard.com/en-us/article/23178672/wow-classic-city-tour-thunder-bluff',
 blackwing='https://news.blizzard.com/en-us/article/23302788/wow-classic-descend-into-the-depths-of-blackwing-lair',
 zulgurub='https://news.blizzard.com/en-gb/article/23780549/wow-classic-season-of-mastery-zul-gurub-now-live',
 aq='https://news.blizzard.com/en-gb/article/23785119/season-of-mastery-the-ahnqiraj-war-effort-is-now-live',
 naxx='https://news.blizzard.com/en-gb/article/24229248/wow-weekly-legion-remix-naxxramas-looms-in-wow-classic-anniversary-edition-and-more',
 molten='https://news.blizzard.com/en-gb/article/24165121/20th-anniversary-realms-molten-core-and-onyxia-s-lair-now-live',
 fire='https://news.blizzard.com/en-gb/article/24182544/take-on-the-challenge-of-normal-and-heroic-molten-core',
 diremaul='https://worldofwarcraft.blizzard.com/en-us/news/23185723/wow-classic-dire-maul-now-available',
 ancients='https://worldofwarcraft.blizzard.com/en-gb/news/9992814',
 ravencrest='https://worldofwarcraft.blizzard.com/en-gb/news/20243191/',
 ironforge='https://news.blizzard.com/en-us/article/24182547/claim-epic-rewards-in-normal-and-heroic-ironforge-siege',
 magni='https://news.blizzard.com/en-gb/article/24145860/get-ready-to-lay-siege-to-ironforge',
 gnomes='https://worldofwarcraft.blizzard.com/en-gb/news/10004614/new-tinkertown-and-the-fight-for-gnomeregan',
 harvest='https://news.blizzard.com/en-us/article/22483126/in-remembrance-the-harvest-festival-has-begun',
 uther='https://news.blizzard.com/en-us/article/20861967/songs-of-the-storm-supports',
 utherhistory='https://warcraft.wiki.gg/wiki/Uther_the_Lightbringer',
 terenas='https://warcraft.wiki.gg/wiki/King_Terenas_Menithil',
 muradin='https://warcraft.wiki.gg/wiki/Muradin',
 archimonde='https://warcraft.wiki.gg/wiki/Archimonde',
 anubarak='https://warcraft.wiki.gg/wiki/Anub%27arak_%28Warcraft_III%29',
 durotarhistory='https://warcraft.wiki.gg/wiki/The_Founding_of_Durotar',
 antonidas='https://warcraft.wiki.gg/wiki/Antonidas',
 durotarinvasion='https://warcraft.wiki.gg/wiki/Invasion_of_Durotar',
 wc3manual='https://warcraft.wiki.gg/wiki/Warcraft_III%3A_Reign_of_Chaos_manual',
 frostmournemission='https://warcraft.wiki.gg/wiki/Frostmourne_%28WC3_Human%29',
}}
ns.AthenaLoreCodexInput=D
local function E(id,title,kind,source,fields,related,aliases,category,gate)
 D.entries[#D.entries+1]={id=id,title=title,kind=kind,source=source,fields=fields,related=related or {},aliases=aliases or {title},category=category,gate=gate or 'HISTORICAL'}
end
E('illidan','Illidan Stormrage','figure','illidan',{
 role='Illidan Stormrage was a night elf demon hunter, brother to Malfurion.',
 appearance='The Skull of Gul’dan’s power left Illidan with curved horns, cloven hooves and leathery wings.',
 history='Tyrande released Illidan from ancient imprisonment to oppose the Legion; Malfurion later exiled him after his transformation.',
 relationships='Lady Vashj and her naga joined Illidan; Maiev pursued him.',
 conflict='Illidan used the Eye of Sargeras against Icecrown, until his ritual was interrupted.'},
 {'malfurion','tyrande','maiev','vashj','skull-guldan','eye-sargeras','frozen-throne'},{'Illidan Stormrage','Illidan'},'nightelves')
E('malfurion','Malfurion Stormrage','figure','malfurion',{
 role='Malfurion Stormrage was an archdruid and a pupil of Cenarius.',
 relationships='Malfurion was Tyrande’s beloved and Illidan’s brother.',
 context='His druidic tradition joined healing and protection to the living world.'},
 {'illidan','tyrande','cenarius','hyjal'},{'Malfurion Stormrage','Malfurion'},'nightelves')
E('cenarius','Cenarius','figure','malfurion',{role='Cenarius was Malfurion’s teacher in druidism.',relationships='Malfurion’s training connected Cenarius with the night elves’ druidic inheritance.'},{'malfurion'},nil,'ancientpowers')
E('maiev','Maiev Shadowsong','figure','illidan',{role='Maiev Shadowsong pursued Illidan after his release.',conflict='Alongside Malfurion and Kael’thas, Maiev interrupted Illidan’s Icecrown ritual.'},{'illidan','malfurion','kaelthas'},nil,'nightelves')
E('vashj','Lady Vashj','figure','illidan',{role='Lady Vashj led naga who joined Illidan.',history='Her followers helped obtain the Eye of Sargeras.'},{'illidan','eye-sargeras'},{'Lady Vashj','Vashj'},'ancientpowers')
E('kaelthas','Kael’thas Sunstrider','figure','illidan',{role='Kael’thas was Silvermoon’s prince.',history='He helped interrupt Illidan’s ritual against Icecrown.'},{'illidan','maiev'},{'Kael’thas Sunstrider',"Kael'thas Sunstrider",'Prince Kael’thas',"Prince Kael'thas"},'alliance')
E('skull-guldan','The Skull of Gul’dan','artifact','illidan',{history='Illidan consumed the fel power within the Skull of Gul’dan.',outcome='Its power transformed Illidan into a demonic form.'},{'illidan'},{'Skull of Gul’dan',"Skull of Gul'dan"},'artifacts')
E('eye-sargeras','The Eye of Sargeras','artifact','illidan',{role='The Eye of Sargeras was the artifact used in Illidan’s interrupted ritual against Icecrown.'},{'illidan','vashj'},nil,'artifacts')
E('medivh','Medivh','figure','first',{role='Medivh was the mage through whom Sargeras worked.',history='His pact with Gul’dan brought the Dark Portal into being.'},{'guldan','sargeras','dark-portal','khadgar'},nil,'alliance')
E('guldan','Gul’dan','figure','first',{role='Gul’dan was the orc warlock who bargained with Medivh.',history='Their pact opened a way from Draenor to Azeroth for the Horde.'},{'medivh','dark-portal'},{'Gul’dan',"Gul'dan"},'fallenpowers')
E('sargeras','Sargeras','figure','first',{role='Sargeras was the demonic power behind Medivh’s corruption.',conflict='Through Medivh and Gul’dan, the Legion’s influence reached the war between orcs and humans.'},{'medivh','guldan','burning-legion'},nil,'ancientpowers')
E('dark-portal','The Dark Portal','place','first',{role='The Dark Portal linked Draenor and Azeroth.',history='Medivh and Gul’dan’s bargain enabled the Horde’s invasion.'},{'medivh','guldan','draenor','first-war'},{'Dark Portal'},'landmarks')
E('first-war','The First War','event','first',{conflict='The invading Horde fought Stormwind’s defenders.',outcome='Stormwind fell, and King Llane was killed.'},{'stormwind','llane','lothar','dark-portal'},nil,'wars')
E('khadgar','Khadgar','figure','origins',{role='Khadgar was Medivh’s apprentice.',history='He warned Llane and Lothar of his master’s corruption and helped Lothar confront Medivh.'},{'medivh','llane','lothar'},nil,'alliance')
E('llane','King Llane Wrynn','figure','origins',{role='Llane Wrynn ruled Stormwind during the First War.',outcome='Garona assassinated Llane as the Horde besieged his city.'},{'garona','stormwind','first-war'},{'King Llane Wrynn','King Llane','Llane Wrynn'},'alliance')
E('garona','Garona Halforcen','figure','origins',{role='Garona had been an ally of the humans while bound to the Shadow Council’s will.',history='Under the Council’s orders, she killed King Llane.'},{'llane','shadow-council'},nil,'fallenpowers')
E('blackhand','Blackhand','figure','origins',{role='Blackhand was the Horde warchief supported by Gul’dan.',outcome='Orgrim Doomhammer defeated Blackhand and took leadership of the Horde.'},{'guldan','orgrim'},nil,'horde')
E('shadow-council','The Shadow Council','faction','origins',{role='Gul’dan’s Shadow Council manipulated the Horde from behind its leaders.',history='Its orders compelled Garona’s assassination of Llane.'},{'guldan','garona','llane'},{'Shadow Council'},'factions')
E('lothar','Anduin Lothar','figure','second',{role='Anduin Lothar led Stormwind’s refugees north and helped form the Alliance.',outcome='Orgrim Doomhammer killed Lothar; Turalyon continued the Alliance’s struggle.'},{'stormwind','alliance','orgrim','turalyon'},{'Anduin Lothar','Lothar'},'alliance')
E('orgrim','Orgrim Doomhammer','figure','second',{role='Orgrim Doomhammer led the Horde during the Second War.',history='He killed Lothar, but Turalyon’s forces ultimately defeated the Horde.'},{'lothar','turalyon','second-war'},nil,'horde')
E('turalyon','Turalyon','figure','second',{role='Turalyon was Lothar’s lieutenant.',history='After Lothar’s death, he led the Alliance to victory over the Horde.'},{'lothar','second-war'},nil,'alliance')
E('alliance','The Alliance','faction','second',{history='Human nations joined elves, dwarves and gnomes in an alliance against the invading Horde.'},{'lothar','second-war','stormwind'},{'Alliance'},'factions')
E('second-war','The Second War','event','second',{conflict='The Alliance resisted Doomhammer’s invading Horde.',outcome='Gul’dan’s departure weakened the Horde; the Alliance prevailed under Turalyon.'},{'alliance','orgrim','lothar','turalyon'},nil,'wars')
E('nerzhul','Ner’zhul','figure','portal',{role='Ner’zhul led the remaining Horde on Draenor after its defeat.',motivation='He sought other worlds through a network of portals.',outcome='The stress of those portals shattered Draenor.'},{'draenor','outland','shattering-draenor'},{'Ner’zhul',"Ner'zhul"},'fallenpowers')
E('draenor','Draenor','place','portal',{history='Draenor was the world from which the Horde invaded Azeroth.',outcome='Ner’zhul’s portals tore the world apart.'},{'outland','nerzhul','dark-portal'},nil,'worlds')
E('outland','Outland','place','portal',{role='Outland was the shattered remnant of Draenor.',history='Alliance heroes were stranded there when the world broke.'},{'draenor','shattering-draenor'},nil,'worlds')
E('shattering-draenor','The Shattering of Draenor','event','portal',{conflict='Alliance forces pursued the Horde into Draenor as Ner’zhul opened new portals.',outcome='The world broke under the magical strain, leaving Outland.'},{'draenor','outland','nerzhul'},nil,'wars')
E('third-war','The Third War','event','third',{conflict='The Scourge and Burning Legion threatened Azeroth.',outcome='Humans, orcs and night elves united against the Legion at Hyjal.'},{'hyjal','burning-legion','scourge','thrall','arthas'},nil,'wars')
E('hyjal','The Battle of Mount Hyjal','event','third',{location='Mount Hyjal was the site of the allied stand against the Burning Legion.',outcome='The defenders’ costly victory preserved Azeroth’s future.'},{'third-war','thrall','tyrande'},{'Battle of Mount Hyjal','Mount Hyjal'},'wars')
E('burning-legion','The Burning Legion','faction','third',{role='The Burning Legion was the demonic army that returned to threaten Azeroth during the Third War.'},{'third-war','hyjal','sargeras'},{'Burning Legion'},'factions')
E('scourge','The Scourge','faction','third',{role='The Scourge was the undead force that devastated Lordaeron.',history='Arthas became a servant of the power he had opposed.'},{'arthas','lordaeron','third-war'},{'Scourge'},'factions')
E('frozen-throne','The Struggle for the Frozen Throne','event','throne',{conflict='Illidan’s forces threatened the Lich King in Northrend; Arthas returned to defend his master.',outcome='Arthas defeated Illidan and merged with the Lich King.'},{'illidan','arthas','northrend','lich-king'},nil,'wars')
E('lich-king','The Lich King','figure','throne',{role='The Lich King was the master of the Scourge.',history='At the Frozen Throne, Arthas joined his spirit with the Lich King’s.'},{'arthas','scourge','frozen-throne'},{'Lich King'},'fallenpowers')
E('northrend','Northrend','place','throne',{location='Northrend was the icy northern continent containing the Frozen Throne.',history='Illidan and Arthas fought over the fate of the Lich King there.'},{'frozen-throne','lich-king'},nil,'worlds')
E('forsaken','The Forsaken','faction','throne',{history='Sylvanas’s rebellion created the Forsaken, undead who broke from the Scourge.'},{'sylvanas','scourge','lordaeron'},{'Forsaken'},'factions')
E('cairne','Cairne Bloodhoof','figure','cairne',{role='Cairne Bloodhoof united the tauren and established their permanent capital.',conflict='An alliance with Thrall helped his people survive the centaur threat.'},{'thrall','thunder-bluff','tauren'},nil,'horde')
E('tauren','The Tauren','faction','cairne',{history='Cairne brought formerly nomadic tauren together and secured an alliance against the centaur.'},{'cairne','thunder-bluff'},{'Tauren'},'peoples')
E('grom','Grom Hellscream','figure','jaina',{history='Jaina and Thrall helped cleanse Grom of the Legion’s influence.',outcome='His defeat of Mannoroth freed the Horde from demonic bondage.'},{'thrall','jaina','mannoroth'},nil,'horde')
E('mannoroth','Mannoroth','figure','jaina',{role='Mannoroth was the pit lord bound to the Horde’s demonic corruption.',outcome='Grom Hellscream’s victory ended that bondage.'},{'grom','thrall'},nil,'fallenpowers')
E('theramore','Theramore','place','jaina',{role='Jaina founded Theramore after the Third War.',context='Her alliance with Thrall against the Legion left a fragile hope for peace.'},{'jaina','thrall'},nil,'cities')
E('horde','Thrall’s Horde','faction','jaina',{history='Thrall established a new Horde homeland in Kalimdor after the struggle against the Legion.'},{'thrall','grom','orgrimmar'},{'Horde'},'factions')
E('voljin','Vol’jin','figure','voljin',{relationships='Vol’jin was Sen’jin’s son.',history='His youth was shaped by the Darkspear tradition of the shadow hunters.'},{'senjin'},{'Vol’jin',"Vol'jin"},'horde')
E('senjin','Sen’jin','figure','voljin',{role='Sen’jin was Vol’jin’s father, remembered in the Darkspear’s traditions.'},{'voljin'},{'Sen’jin',"Sen'jin"},'horde')
E('stormwind','Stormwind','place','stormwind',{location='Stormwind’s districts were linked by canals and streets.',appearance='The Mage Quarter, Cathedral Square and Old Town gave the city distinct faces.'},{'first-war','llane','lothar'},{'Stormwind','Stormwind City'},'cities')
E('darnassus','Darnassus','place','darnassus',{role='Darnassus was the night elf capital.',appearance='Its terraces led toward the Temple of the Moon and the Cenarion Enclave.'},{'tyrande','teldrassil','malfurion'},nil,'cities')
E('orgrimmar','Orgrimmar','place','orgrimmar',{role='Orgrimmar was the Horde’s capital.',location='Its valleys included Honor, Wisdom and Spirits, with the Cleft of Shadow below.'},{'thrall','horde','durotar'},nil,'cities')
E('thunder-bluff','Thunder Bluff','place','thunderbluff',{role='Thunder Bluff was the tauren capital.',appearance='Bridges and stairways connected its rises, including the Hunter’s, Spirit and Elder rises.'},{'cairne','tauren'},nil,'cities')
E('blackwing-lair','Blackwing Lair','instance','blackwing',{location='Blackwing Lair occupied the heights of Blackrock Spire.',conflict='Nefarian experimented on dragon eggs within the mountain.'},{'nefarian','blackrock-mountain'},nil,'dungeons','DISCOVERY')
E('nefarian','Nefarian','figure','blackwing',{role='Nefarian was Deathwing’s eldest son and a black dragon.',conflict='His experiments combined the eggs of different dragonflights.'},{'blackwing-lair','blackrock-mountain'},nil,'fallenpowers','DISCOVERY')
E('blackrock-mountain','Blackrock Mountain','place','blackwing',{location='Blackrock Mountain lay between the Burning Steppes and Searing Gorge.',context='Blackwing Lair occupied the mountain’s upper reaches.'},{'blackwing-lair','molten-core','blackrock-depths'},nil,'landmarks')
E('zul-gurub','Zul’Gurub','instance','zulgurub',{location='Zul’Gurub was an ancient troll city in Stranglethorn Vale.',appearance='Tree-lined avenues and ruined temples stretched through its jungle.',conflict='The Blood God Hakkar was the focus of the city’s rituals.'},{'hakkar','stranglethorn'},{'Zul’Gurub',"Zul'Gurub"},'dungeons','DISCOVERY')
E('hakkar','Hakkar','figure','zulgurub',{role='Hakkar was the Blood God invoked in Zul’Gurub.'},{'zul-gurub'},nil,'ancientpowers','DISCOVERY')
E('stranglethorn','Stranglethorn Vale','place','zulgurub',{appearance='Stranglethorn’s jungle enclosed the ancient troll city of Zul’Gurub.'},{'zul-gurub'},nil,'kalimdor-east')
E('ahnqiraj','Ahn’Qiraj','instance','aq',{location='Ahn’Qiraj was a desert fortress long sealed behind the Scarab Wall.',conflict='Its qiraji threatened Kalimdor; C’Thun lurked within.'},{'cthun','qiraji','war-effort'},{'Ahn’Qiraj',"Ahn'Qiraj"},'dungeons','DISCOVERY')
E('cthun','C’Thun','figure','aq',{role='C’Thun was an ancient Old God within Ahn’Qiraj.'},{'ahnqiraj'},{'C’Thun',"C'Thun"},'ancientpowers','DISCOVERY')
E('qiraji','The Qiraji','faction','aq',{role='The qiraji were the insectoid people of Ahn’Qiraj.'},{'ahnqiraj'},{'Qiraji'},'factions','DISCOVERY')
E('war-effort','The Ahn’Qiraj War Effort','event','aq',{role='The war effort gathered supplies from both factions for the assault on Ahn’Qiraj.'},{'ahnqiraj'},nil,'wars','DISCOVERY')
E('naxxramas','Naxxramas','instance','naxx',{role='Naxxramas was a Scourge necropolis associated with Kel’Thuzad.'},{'kelthuzad','scourge-invasion','scourge'},nil,'dungeons','DISCOVERY')
E('kelthuzad','Kel’Thuzad','figure','naxx',{role='Kel’Thuzad commanded horrors within Naxxramas.'},{'naxxramas','scourge'},{'Kel’Thuzad',"Kel'Thuzad"},'fallenpowers','DISCOVERY')
E('scourge-invasion','The Scourge Invasion','event','naxx',{conflict='Scourge forces attacked Azeroth with floating necropolises and undead armies.'},{'naxxramas','scourge'},nil,'wars','DISCOVERY')
E('lordaeron','Lordaeron','place','third',{history='Lordaeron was the human kingdom devastated by the Scourge in the Third War.'},{'arthas','scourge','sylvanas'},nil,'landmarks')
E('ragnaros','Ragnaros','figure','molten',{role='Ragnaros was the elemental Firelord summoned by Thaurissan.',location='He lay within the burning depths of Molten Core.'},{'molten-core','thaurissan'},nil,'ancientpowers','DISCOVERY')
E('thaurissan','Emperor Thaurissan','figure','molten',{history='Thaurissan summoned Ragnaros in a desperate attempt to turn the dwarven civil war.'},{'ragnaros','three-hammers','blackrock-mountain'},nil,'fallenpowers')
E('three-hammers','The War of the Three Hammers','event','molten',{conflict='The dwarven civil war drove Thaurissan to summon the Firelord.'},{'thaurissan','ragnaros'},nil,'wars')
E('onyxia','Onyxia','figure','molten',{role='Onyxia was a black dragon.',relationships='She was Nefarian’s younger sister and Deathwing’s daughter.',location='Her lair lay in Dustwallow Marsh.'},{'onyxias-lair','nefarian','deathwing'},nil,'fallenpowers','DISCOVERY')
E('onyxias-lair','Onyxia’s Lair','instance','molten',{location='Onyxia’s Lair lay in Dustwallow Marsh.',context='The black dragon’s brood of eggs lay within.'},{'onyxia','dustwallow'},{'Onyxia’s Lair',"Onyxia's Lair"},'dungeons','DISCOVERY')
E('dustwallow','Dustwallow Marsh','place','molten',{location='Dustwallow Marsh held Onyxia’s Lair.'},{'onyxias-lair','theramore'},nil,'places')
E('deathwing','Deathwing','figure','blackwing',{context='Deathwing’s legacy lay behind the black dragonflight’s designs on Azeroth.'},{'nefarian','onyxia'},nil,'ancientpowers')
E('lucifron','Lucifron','figure','fire',{role='Lucifron was a flamewaker competing for Ragnaros’s favor.'},{'ragnaros','molten-core'},nil,'fallenpowers','DISCOVERY')
E('magmadar','Magmadar','figure','fire',{role='Magmadar led the core hounds serving Ragnaros.'},{'ragnaros','molten-core'},nil,'fallenpowers','DISCOVERY')
E('garr','Garr','figure','fire',{role='Garr was an earth elemental lieutenant of Ragnaros.',history='With Baron Geddon, he helped imprison Thunderaan’s essence.'},{'ragnaros','baron-geddon','thunderaan','bindings'},nil,'fallenpowers','DISCOVERY')
E('baron-geddon','Baron Geddon','figure','fire',{role='Baron Geddon was an ancient fire elemental who had lost favor to Majordomo Executus.'},{'ragnaros','majordomo','garr'},nil,'fallenpowers','DISCOVERY')
E('gehennas','Gehennas','figure','fire',{motivation='Gehennas sought higher station among the Firelord’s flamewakers.'},{'ragnaros','molten-core'},nil,'fallenpowers','DISCOVERY')
E('shazzrah','Shazzrah','figure','fire',{role='Shazzrah was a flamewaker with a talent for arcane magic.'},{'ragnaros','molten-core'},nil,'fallenpowers','DISCOVERY')
E('golemagg','Golemagg the Incinerator','figure','fire',{appearance='Golemagg was a molten giant accompanied by two powerful core ragers.'},{'magmadar','molten-core'},nil,'fallenpowers','DISCOVERY')
E('majordomo','Majordomo Executus','figure','molten',{role='Majordomo Executus was the agent able to call Ragnaros from slumber.'},{'ragnaros','molten-core'},nil,'fallenpowers','DISCOVERY')
E('thunderaan','Thunderaan','figure','fire',{history='Garr and Baron Geddon sealed Thunderaan’s essence within a talisman.'},{'garr','baron-geddon','bindings'},nil,'ancientpowers','DISCOVERY')
E('bindings','The Bindings of the Windseeker','artifact','fire',{role='The broken talisman held Thunderaan’s imprisoned essence.'},{'thunderaan','garr','baron-geddon'},{'Bindings of the Windseeker'},'artifacts','DISCOVERY')
E('dire-maul','Dire Maul','instance','diremaul',{history='Dire Maul occupied the ruins of Eldre’Thalas.',conflict='The Shen’dralar sustained themselves by drawing power from an imprisoned demon.'},{'tortheldrin','immolthar','shendralar','feralas'},nil,'dungeons','DISCOVERY')
E('tortheldrin','Prince Tortheldrin','figure','diremaul',{role='Tortheldrin ruled the surviving Shen’dralar.',history='He preserved his power by siphoning Immol’thar’s energy.'},{'dire-maul','immolthar','shendralar'},nil,'fallenpowers','DISCOVERY')
E('immolthar','Immol’thar','figure','diremaul',{role='Immol’thar was the demon imprisoned beneath Dire Maul.',conflict='His captors drained his power for their own spells.'},{'dire-maul','tortheldrin'},{'Immol’thar',"Immol'thar"},'fallenpowers','DISCOVERY')
E('shendralar','The Shen’dralar','faction','diremaul',{history='The Shen’dralar survived in Eldre’Thalas under Tortheldrin, dependent on stolen demonic power.'},{'dire-maul','tortheldrin'},{'Shen’dralar',"Shen'dralar"},'factions','DISCOVERY')
E('feralas','Feralas','place','diremaul',{appearance='Feralas was forest country whose ancient ruins held Dire Maul.'},{'dire-maul'},nil,'places')
E('well-eternity','The Well of Eternity','place','ancients',{location='The Well of Eternity lay beside the ancient night elf capital of Zin-Azshari.',history='The Highborne used its power to open the Legion’s gateway.'},{'zin-azshari','azshara','war-ancients'},{'Well of Eternity'},'landmarks')
E('zin-azshari','Zin-Azshari','place','ancients',{appearance='Zin-Azshari was a magnificent night elf metropolis beside the Well of Eternity.'},{'well-eternity','azshara'},nil,'cities')
E('azshara','Queen Azshara','figure','ancients',{role='Azshara ruled the ancient night elves.',motivation='Her ambition drew the Highborne toward Sargeras and the Legion.'},{'highborne','war-ancients','sargeras'},{'Queen Azshara'},'nightelves')
E('highborne','The Highborne','faction','ancients',{role='The Highborne were the aristocratic night elven spellcasters.',history='Under Azshara, they channeled their power into a gateway for the Burning Legion.'},{'azshara','well-eternity','war-ancients'},{'Highborne'},'peoples')
E('war-ancients','The War of the Ancients','event','ancients',{conflict='The Legion invaded through the Highborne’s portal at the Well of Eternity.',outcome='The catastrophe ended in the Great Sundering.'},{'azshara','well-eternity','sundering'},nil,'wars')
E('sundering','The Great Sundering','event','ancients',{outcome='The Well of Eternity’s catastrophe shattered the old world and left the Maelstrom.'},{'well-eternity','maelstrom','war-ancients'},{'Great Sundering','Sundering'},'wars')
E('maelstrom','The Maelstrom','place','ancients',{history='The Maelstrom remained where the catastrophe of the Sundering had broken the world.'},{'sundering','well-eternity'},nil,'landmarks')
E('ravencrest','Kur’talos Ravencrest','figure','ravencrest',{role='Ravencrest commanded the kaldorei resistance during the War of the Ancients.',relationships='He was an early mentor to Illidan.',outcome='Varo’then assassinated him on Azshara’s orders.'},{'illidan','azshara','war-ancients'},{'Kur’talos Ravencrest',"Kur'talos Ravencrest",'Lord Ravencrest'},'nightelves')
E('xavius','Xavius','figure','ravencrest',{role='Xavius was a powerful mage and an adviser to Azshara.',history='His pact with Sargeras helped bring the Legion’s first invasion.'},{'azshara','sargeras','war-ancients'},nil,'fallenpowers')
E('ironforge','Ironforge','place','ironforge',{location='Ironforge was carved into the mountains of Dun Morogh.',appearance='Deep stone passageways surrounded the Great Forge.',context='The Deeprun Tram linked its Tinker Town to Stormwind’s Dwarven District.'},{'dun-morogh','magni','stormwind','deeprun-tram'},nil,'cities')
E('deeprun-tram','The Deeprun Tram','place','ironforge',{location='The underground Deeprun Tram connected Ironforge and Stormwind.'},{'ironforge','stormwind'},{'Deeprun Tram'},'landmarks')
E('magni','Magni Bronzebeard','figure','magni',{role='Magni Bronzebeard was king of the dwarves in Ironforge.'},{'ironforge'},nil,'alliance')
E('mekkatorque','Gelbin Mekkatorque','figure','gnomes',{role='High Tinker Gelbin Mekkatorque led the gnomes.',motivation='His people sought to reclaim their lost capital, Gnomeregan.'},{'gnomeregan','thermaplugg','ironforge'},{'Gelbin Mekkatorque','High Tinker Mekkatorque','Mekkatorque'},'alliance')
E('gnomeregan','Gnomeregan','instance','gnomes',{role='Gnomeregan was the gnomes’ lost technological capital.',conflict='Mekgineer Thermaplugg held the captured city.'},{'mekkatorque','thermaplugg','ironforge'},nil,'dungeons','DISCOVERY')
E('thermaplugg','Mekgineer Thermaplugg','figure','gnomes',{role='Thermaplugg was the traitor holding Gnomeregan.'},{'gnomeregan','mekkatorque'},nil,'fallenpowers','DISCOVERY')
E('uther','Uther the Lightbringer','figure','utherhistory',{role='Uther was a paladin of the Silver Hand and Arthas’s mentor.',conflict='He refused Arthas’s order to kill Stratholme’s infected citizens.',outcome='Arthas later killed his former mentor at Andorhal.'},{'arthas','terenas','stratholme'},nil,'alliance')
E('uthers-tomb','Uther’s Tomb','place','harvest',{location='Uther’s tomb stood in the Western Plaguelands.',context='The Alliance honored the fallen Lightbringer there during the Harvest Festival.'},{'uther'},nil,'landmarks')
E('hellscream-memorial','The Hellscream Memorial','place','harvest',{location='Grom’s memorial stood in Demon Fall Canyon in Ashenvale.',context='The Horde honored Hellscream’s sacrifice there during the Harvest Festival.'},{'grom','ashenvale'},nil,'landmarks')
E('terenas','Terenas Menethil II','figure','terenas',{role='Terenas ruled Lordaeron and helped bring its allies together against the Horde.',relationships='He was Arthas’s father.',outcome='His returning son killed him with Frostmourne, ending his reign.'},{'arthas','lordaeron','frostmourne'},{'Terenas Menethil II','King Terenas','Terenas Menethil'},'alliance')
E('frostmourne','Frostmourne','artifact','terenas',{history='Frostmourne was the runeblade Arthas wielded when he murdered King Terenas.'},{'arthas','terenas','muradin'},nil,'artifacts')
E('muradin','Muradin Bronzebeard','figure','muradin',{role='Muradin was a dwarven adventurer and Ironforge’s former ambassador to Lordaeron.',relationships='He trained Arthas in combat and was brother to Magni and Brann.',history='Muradin was believed lost in Northrend when Arthas claimed Frostmourne.'},{'magni','arthas','frostmourne','northrend'},nil,'alliance')
E('archimonde','Archimonde','figure','archimonde',{role='Archimonde was an eredar commander of the Burning Legion.',motivation='His allegiance to Sargeras promised greater power.',outcome='The mortal defenders defeated him in the Third War.'},{'sargeras','burning-legion','third-war','hyjal'},nil,'fallenpowers')
E('anubarak','Anub’arak','figure','anubarak',{role='Anub’arak had ruled Azjol-Nerub before the Scourge raised him into undeath.',history='He guided Arthas toward Icecrown against Illidan’s forces.'},{'arthas','lich-king','frozen-throne','azjol-nerub'},{'Anub’arak',"Anub'arak"},'fallenpowers')
E('azjol-nerub','Azjol-Nerub','place','anubarak',{history='Azjol-Nerub was Anub’arak’s kingdom before its conquest by the Scourge.'},{'anubarak','scourge'},nil,'landmarks')
E('founding-durotar','The Founding of Durotar','event','durotarhistory',{history='After Hyjal, Thrall founded Durotar in southern Kalimdor.',conflict='Beasts and human forces threatened the new homeland.'},{'thrall','durotar','rexxar','rokhan','misha'},nil,'wars')
E('rexxar','Rexxar','figure','durotarhistory',{role='Rexxar was the beastmaster who helped defend the new Horde in Durotar.',relationships='His bear companion Misha and the Darkspear scout Rokhan shared that undertaking.'},{'founding-durotar','misha','rokhan'},nil,'horde')
E('rokhan','Rokhan','figure','durotarhistory',{role='Rokhan was a Darkspear shadow hunter and one of Thrall’s scouts.'},{'rexxar','founding-durotar'},nil,'horde')
E('misha','Misha','figure','durotarhistory',{role='Misha was Rexxar’s bear companion during the defense of Durotar.'},{'rexxar','founding-durotar'},nil,'horde')
E('stratholme','Stratholme','place','utherhistory',{history='Stratholme’s plague-stricken citizens became the victims of Arthas’s purge.',conflict='Uther refused to join the killing.'},{'arthas','uther','scourge'},nil,'cities')
E('antonidas','Antonidas','figure','antonidas',{role='Antonidas was the archmage who led Dalaran.',relationships='Jaina Proudmoore was his apprentice.',conflict='He opposed Kel’Thuzad’s experiments in necromancy.'},{'jaina','kelthuzad'},nil,'alliance')
E('daelin','Daelin Proudmoore','figure','durotarinvasion',{role='Daelin Proudmoore was Kul Tiras’s admiral and Jaina’s father.',conflict='His fleet attacked the new Horde in Kalimdor, threatening the peace Jaina had made.',outcome='He died in the fighting at Theramore.'},{'jaina','theramore','rexxar','founding-durotar'},{'Daelin Proudmoore','Admiral Proudmoore'},'alliance')
E('kiljaeden','Kil’jaeden','figure','wc3manual',{role='Kil’jaeden was a powerful commander of the Burning Legion.',history='He remade Ner’zhul into the Lich King and set dreadlords to watch over him.',motivation='He intended the undead plague to destroy human resistance before the Legion’s invasion.'},{'nerzhul','lich-king','burning-legion','scourge'},{'Kil’jaeden',"Kil'jaeden"},'fallenpowers')
E('malganis','Mal’Ganis','figure','frostmournemission',{role='Mal’Ganis was the dreadlord whom Arthas pursued to Northrend.',outcome='Arthas struck him down with Frostmourne, following the Lich King’s whispered command.'},{'arthas','northrend','frostmourne','lich-king'},{'Mal’Ganis',"Mal'Ganis"},'fallenpowers')
