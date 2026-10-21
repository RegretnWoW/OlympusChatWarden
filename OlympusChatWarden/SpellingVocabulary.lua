-- Curated offline spelling supplements. These are known spellings, never
-- filtering targets, exceptions, confidence scores or signed-pack overrides.
-- Keep community entries to established project names and existing aliases.
local _,ns=...
local V={VERSION=1,words={},game={},community={},buckets={},counts={}}
ns.SpellingVocabulary=V
V.categories={
    {id='zones',label='Zones and cities',data=[=[
azeroth kalimdor lordaeron khaz dun morogh durotar mulgore teldrassil elwynn westfall redridge duskwood
loch modan wetlands silverpine tirisfal hillsbrad alterac arathi hinterlands stranglethorn badlands searing
steppes barrens darkshore ashenvale stonetalon desolace thousand needles feralas tanaris azshara
felwood winterspring moonglade ungoro un'goro silithus plaguelands deadwind swamp blasted
stormwind ironforge darnassus orgrimmar undercity thunder bluff booty ratchet gadgetzan everlook menethil
theramore lakeshire goldshire sentinel hill darkshire auberdine astranaar crossroads brill razor hill
sen'jin senjin shadowglen dolanaar coldridge kharanos thelsamar hammerfall tarren southshore refuge nijel
feathermoon bloodhoof camp narache valley trials northshire gilneas dalaran silvermoon exodar shattrath
outland northrend eversong ghostlands azuremyst bloodmyst hellfire zangarmarsh terokkar nagrand netherstorm
shadowmoon blade's blades borean howling dragonblight grizzly zul'drak zuldrak sholazar icecrown stormpeaks
hyjal vashj'ir vashjir deepholm uldum tol barad pandaria draenor stormheim suramar val'sharah valsharah
]=]},
    {id='lore',label='Characters and lore',data=[=[
thrall arthas sylvanas jaina illidan malfurion tyrande anduin varian magni muradin brann bolvar tirion
uther khadgar medivh gul'dan guldan grom garrosh vol'jin voljin baine cairne rexxar saurfang valeera
alleria turalyon maiev velen yrel akama kael'thas kaelthas lor'themar lorthemar alexstrasza ysera
nozdormu malygos kalecgos deathwing onyxia nefarian ragnaros kel'thuzad kelthuzad anub'arak anubarak
ner'zhul nerzhul sargeras kil'jaeden kiljaeden archimonde mannoroth cenarius azshara elune magni
cenarion argent kirin tor scarlet scourge forsaken sindorei sin'dorei kaldorei quel'dorei quel'danas
quel'thalas sunwell frostwolf warsong stormpike silverwing bloodsail darkmoon thorium timbermaw hydraxian
zandalari gurubashi amani defias blackrock darkspear earthen naaru lich demigod dragonflight bronze
]=]},
    {id='classes',label='Classes races and professions',data=[=[
warrior paladin hunter rogue priest shaman mage warlock druid deathknight monk demonhunter evoker
tauren orc orcs troll trolls gnome gnomes dwarf dwarves nightelf nightelves bloodelf bloodelves
draenei undead worgen goblin goblins pandaren dracthyr nightborne lightforged vulpera mechagnome
arms fury prot protection holy ret retribution disc discipline shadow assassination combat subtlety
enhancement enhance elemental resto restoration feral balance boomkin bearcat beastmastery
marksmanship survival arcane fire frost affliction demonology destro destruction unholy brewmaster
mistweaver windwalker vengeance havoc devastation preservation augmentation
alchemy alchemist blacksmithing blacksmith enchanting enchanter engineering engineer herbalism herbalist
leatherworking leatherworker mining miner skinning skinner tailoring tailor inscription scribe jewelcrafting
jewelcrafter firstaid fishing cooking disenchant disenchanting disenchanter prospecting smelting transmute
]=]},
    {id='abilities',label='Abilities buffs and resources',data=[=[
rejuvenation moonfire innervate shadowmeld regrowth lifebloom wildgrowth tranquility barkskin starsurge
starfall hurricane wrath roots entangling mangle maul swipe shred rip rake ravage pounce ferocious
faerie mark wild thorns nature natures swiftness lifebloom lifeblooms moonkin treants cat form travel
earthshock frostshock flameshock windfury flametongue rockbiter stormstrike windshear chainheal riptide
earthshield watershield lightning lava bloodlust heroism reincarnation earthbind tremor grounding totem
totems cleanse purify dispel dispels dispelling interrupt interrupts interrupted kick kicks silenced
fireball frostbolt pyroblast arcane missiles arcaneintellect evocation polymorph polymorphed polymorphing
counterspell iceblock icebarrier blink blizzard frostnova manashield combustion flamestrike cone cold
renew flashheal greaterheal prayer fortitude shadowform mindflay mindblast mindcontrol psychic scream
powerword shield shields shadowword pain vampiric embrace resurrection resurrect resurrections penance
backstab sinister eviscerate mutilate rupture garrote gouge sap sapped sapping cheapshot kidneyshot
vanish stealth stealthed ambush pickpocket sprint evasion feint adrenaline bladeflurry preparation
charge intercept hamstring rend overpower whirlwind execute bloodthirst mortalstrike shieldslam taunt
taunts taunted taunting sunder devastate disarm thunderclap retaliation recklessness laststand shieldwall
judgement judgment consecration seal seals blessing blessings beacon divine favor lay hands bubble
bubbled bubbling crusaderstrike hammer wrath avengers holyshock redemption salvation sanctuary kings
multishot aimedshot arcaneshot steadyshot serpent sting scorpid viper aspect cheetah trueshot misdirect
misdirection feign death scattershot silencing deterrence disengage mend pet wingclip wyvern bestial
corruption immolate conflagrate shadowbolt haunt unstable affliction soulstone soulstones healthstone
healthstones soulshard soulshards lifetap fear feared fearing deathcoil seduction banish banished enslave
felhunter felguard succubus voidwalker imp infernal doomguard summon summoned summoning soulfire incinerate
rune runes runic runepower deathgrip deathstrike froststrike obliterate howlingblast antimagic diseases
energy rage mana focus combo combopoints holypower astral maelstrom chi essence
]=]},
    {id='instances',label='Dungeons raids and battlegrounds',data=[=[
deadmines ragefire chasm wailing caverns shadowfang keep blackfathom deeps stockades gnomeregan
razorfen kraul downs scarlet monastery uldaman zul'farrak zulfarrak maraudon sunken temple dire maul
blackrock depths spire stratholme scholomance molten core onyxia blackwing lair zul'gurub zulgurub
ahn'qiraj ahnqiraj naxxramas karazhan gruul magtheridon serpentshrine tempest hyjal zul'aman zulaman
hellfire ramparts blood furnace shattered halls slave pens underbog steamvault mana tombs auchenai
crypts sethekk shadow labyrinth mechanar botanica arcatraz culling violet hold nexus azjol
nerub ahn'kahet ahnkahet utgarde pinnacle drak'tharon draktharon gundrak oculus lightning stone halls
ulduar obsidian sanctum eye eternity trial crusader icecrown citadel ruby sanctum vault archavon
warsong gulch arathi basin alterac valley eye storm strand ancients isle conquest wintergrasp
brd lbrs ubrs dm vc sfk bfd rfk rfd sm ulda zf mara st scholo strat mc bwl zg aq aq20 aq40
naxx ony kara ssc tk bt swp mh toc togc icc voa os eoe rfc wc av ab wsg eots ioc
]=]},
    {id='gameplay',label='Gameplay slang and chat abbreviations',data=[=[
wow dps tanking aggro cooldown cooldowns raid raids raiding guild guilds pvp pve aoe afk brb btw pst
lfg lfm lf lf1m lf2m lf3m lf4m wts wtb wtt bis bop boe boa bfa hps hot hots dot dots cc ccw
soulbound hearthstone hearth hearthing ench enchanting enchanter enchants disenchant transmog respec rez
rezzing buff buffs debuff debuffs nerf nerfs addon addons ui npc npcs dk dkp gcd mana mp5 str int agi
stam hp xp exp inv msg whisper whispers lol lmao rofl ty thx gg gl hf gz grats congrats discord
proc procs procced proccing pug pugs pugging parse parses parsing parsed log logs logging combatlog
cleave cleaving kite kiting kited los oom oomkin fps ms latency lag laggy dc
dced disconnected relog relogging logout logoff wipe wipes wiped wiping pull pulls pulling tank tanked
healer healers overheal overhealing dispeller offtank maintank mt ot mob mobs trash boss bosses adds
add spawned spawns respawn respawns respawning despawn despawns respawned spawncamp corpse corpserun
corpsewalk graveyard ganked ganking gank twink twinks alt alts main mains bankalt mule multibox
multiboxing aoeing dotting hotted rejuv trinket trinkets gearscore ilvl stat stats statweights
hitcap softcap hardcap crit crits critting critted haste stamina intellect agility strength spirit
armor armour resilience mastery expertise parry dodge block dodgecap weapon weap weapons weps offhand
mainhand dualwield twohand twohanded onehand onehanded enchant gem gems gemmed gemming reforging
loot looting looted ninja ninjaloot masterloot group loot need greed pass roll rolls rolled rolling
dkp epgp gdkp sr hr msos softres hardres softreserve hardreserve lc lootcouncil boes bops consumes
consumables elixir elixirs flask flasks pot pots potion potions foodbuff worldbuff worldbuffs wb wbuff
wbuffs onyhead rendbuff songflower wcb dmf dmt ony head zg buff dragonslayer chronoboon chronoboons
lockout lockouts attune attuned attunement attunements prebis prepatch prepot prepotting potting
speedrun speedruns speedrunning sweats sweaty casuals minmax minmaxing faceroll facerolling zug zugzug
ggs inc bio irl idk imo imho tbh fwiw afaik iirc rn np nvm omw otw brt rdy rdycheck readycheck
summ sum summons inv pls plz tyvm yw cya cu g2g gtg bbl bbs wp ffa stv tb uc sw if
]=]},
    {id='community',label='Established Olympus names',community=true,data=[=[
olympus asmongold asmon zackrawrr asmontv asmonfresh asmongler chatwarden olympuschatwarden olympusmute
]=]},
}
for _,category in ipairs(V.categories) do
    local group=category.community and V.community or V.game
    local count=0;local seen={}
    for word in category.data:gmatch('%S+') do
        if not seen[word] then count=count+1;seen[word]=true end
        V.words[word]=true;group[word]=true
    end
    V.counts[category.id]=count
end
local sorted={};for word in pairs(V.words) do sorted[#sorted+1]=word end;table.sort(sorted)
V.count=#sorted
for _,word in ipairs(sorted) do
    -- Digit abbreviations are known spellings, but are not prose correction
    -- candidates. The typing tokenizer already skips digit-containing tokens.
    if not word:find('%d') then
        local key=word:sub(1,1)..#word
        V.buckets[key]=V.buckets[key] or {};V.buckets[key][#V.buckets[key]+1]=word
    end
end
