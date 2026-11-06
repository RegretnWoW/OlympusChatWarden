-- Bundled, read-only reference knowledge. It never writes player history.
local _,ns=...
local W={VERSION='world-12.0',CACHE_LIMIT=128,lookups=0,decoded=0};ns.AthenaWorldKnowledge=W
local cache,order={},{}
local function Clean(v,max)
    if type(v)~='string' or #v>(max or 1200) or v:find('[|%z\001-\008\011-\031\127]') then return end
    v=v:gsub('%$B',' '):gsub('%$N','the adventurer'):gsub('%$C','adventurer'):gsub('%$R','adventurer')
    if v:find('%$') then return end -- gender/world-state expressions require native context
    return (v:gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$',''))
end
local function Copy(t) if type(t)~='table' then return t end;local o={};for k,v in pairs(t) do o[k]=Copy(v) end;return o end
local sources={
    war1='https://worldofwarcraft.blizzard.com/en-us/story/timeline/chapter-1',
    war2='https://worldofwarcraft.blizzard.com/en-gb/story/timeline/chapter-2',
    war3='https://worldofwarcraft.blizzard.com/en-us/story/timeline/chapter-4',
    throne='https://worldofwarcraft.blizzard.com/en-gb/story/timeline/chapter-5',
    forsaken='https://news.blizzard.com/en-us/article/24301511/wage-war-once-more-with-warcraft-iii-reforged-forsaken-kingdom',
    peoples='https://news.blizzard.com/en-us/article/24304075/create-the-hero-you-want-to-be-in-world-of-warcraft-forever',
    skyborne='https://news.blizzard.com/en-us/article/24302071/wow-forever-meet-the-new-skyborne',
}
local history={
    {'war1','The First War','Long before this life began, the Dark Portal joined Draenor to Azeroth. The orcish Horde entered a human kingdom unprepared for the war that followed. Stormwind fell, King Llane was murdered, and Anduin Lothar led its survivors north. The loss of one kingdom became the burden of many.'},
    {'war2','The Second War','The kingdoms of the Alliance stood together against the Horde in the Second War. Victory did not restore the old world: Lothar fell, the orcs faced captivity, and the struggle reached back through the Dark Portal. On Draenor, Ner’zhul’s reckless gateways shattered the land, leaving Outland among the war’s enduring wounds.'},
    {'war3','The world before this life','The Third War left Azeroth divided by wounds that no single victory could heal. The Scourge swept through Lordaeron, and Prince Arthas fell into the service of the Lich King. Across the sea, Thrall led liberated orcs toward a different future. The Burning Legion threatened them all.'},
    {'war3','The stand at Hyjal','At Mount Hyjal, humans, orcs and night elves set aside old enmities against the Legion. Their costly victory preserved a future for Azeroth. It did not erase the ruined kingdoms, displaced peoples or distrust that would shape the lives to come.'},
    {'throne','The Frozen Throne and its aftermath','The struggle continued after the Legion’s defeat. Arthas served the Scourge while Illidan’s forces threatened the Lich King in Northrend. Sylvanas broke from that dominion, and the Forsaken emerged as a people seeking a future of their own. The wars of famous heroes became the unsettled world inherited by ordinary adventurers.'},
    {'forsaken','At the threshold of Forever','In the aftermath of Lordaeron’s fall, Sylvanas and the Forsaken established a foothold in the Undercity. The age of Forever begins in the wake of that struggle, in a world still finding its shape after the fall of kingdoms.'},
}
-- Original brief historical framing, separately sourced from personal events.
local races={
    ['Human/Alliance']='Humanity looked toward renewal after generations of war. Stormwind offered a surviving center for that uncertain future.',
    ['Dwarf/Alliance']='Dwarven curiosity reached beyond Khaz Modan, following ancient artifacts and the mysteries of their origins.',
    ['Gnome/Alliance']='The loss of Gnomeregan left its inventive people displaced among their dwarven allies.',
    ['NightElf/Alliance']='The Legion’s return ended night-elven seclusion, leaving their ancient people to find a place in a changed world.',
    ['Orc/Horde']='Freed from demonic bondage, the orcs sought honor and a lasting home under Thrall’s Horde.',
    ['Tauren/Horde']='The tauren’s survival against the centaur bound their future to the orcs and the Horde.',
    ['Troll/Horde']='The displaced Darkspear followed Thrall toward Kalimdor, carrying their traditions into a new alliance.',
    ['Undead/Horde']='Sylvanas led the Forsaken beyond Scourge domination toward an uncertain existence beneath fallen Lordaeron.',
    ['Skyborne/Alliance']='The High Order traced its lineage to exiled Highborne scholars. On Zephras Isle, dependence upon wind spirits had sustained a secluded civilization. Their disappearance exposed its fragility. The Alliance-aligned High Order turned toward lost arcane knowledge and greater self-reliance.',
    ['Skyborne/Horde']='The Windshapers inherited an elemental tradition sustained by the wind spirits of Zephras Isle. With those mentors missing, their way of life stood in jeopardy. Their Horde-aligned path sought answers to the spirits’ disappearance and the restoration of that threatened bond.',
}
function W.Signature() return W.VERSION..'/'..tostring(ns.AthenaQuestData and ns.AthenaQuestData.version or 'missing')..'/'..tostring(ns.AthenaQuestData and ns.AthenaQuestData.sha256 or '') end
function W.Reset() cache={};order={};W.lookups=0;W.decoded=0 end
function W.Environment()
    -- SafeCall intentionally returns one readable value. GetBuildInfo is a
    -- multi-return API: dropping its build/interface disabled native Codex
    -- lookups even though injected Lab environments passed the same gates.
    local ok,version,build,buildDate,interface
    if type(GetBuildInfo)=='function' then ok,version,build,buildDate,interface=pcall(GetBuildInfo) end
    local function Number(value) return ns.SafeNumber(value) or tonumber(ns.SafeString(value,32)) end
    return {interface=ok and Number(interface) or nil,build=ok and Number(build) or nil,
        version=ok and ns.SafeString(version,32) or nil,locale=ns.SafeCall(GetLocale) or 'enUS'}
end
function W.ReferenceCompatibility(env)
    -- Client numbers describe provenance, not permission to open the book.
    -- Per-record readability, native quest identity and stage checks decide
    -- which text can be used. A newer/unknown client never blocks the reader.
    local data=ns.AthenaQuestData
    return data and env and env.build==data.build and env.interface==data.interface and 'SOURCE_BUILD' or 'UNVERIFIED_CLIENT_REFERENCE'
end
function W.Prologue(identity)
    local out={};local race=identity and identity.race;local faction=identity and identity.faction
    if race=='Scourge' or race=='Forsaken' then race='Undead' end
    for i,h in ipairs(history) do out[#out+1]={kind='WORLD_HISTORY',title=h[2],text=h[3],worldRef='world:'..W.VERSION..'/era/'..i,sourceURL=sources[h[1]],confidence='REVIEWED',sourceVersion=W.VERSION,era='FOREVER_START',licensing='Original brief historical paraphrase; Warcraft setting Blizzard',evidenceRefs={}} end
    local key=tostring(race)..'/'..tostring(faction);local text=races[key]
    out[#out+1]={kind='WORLD_HISTORY',title=text and ('A '..(race=='Undead' and 'Forsaken' or race)..' inheritance') or 'Azeroth awaits',
        text=text or 'The great struggles belonged to the history of Azeroth. Beyond their shadow lay the smaller beginnings of countless lives, each with its own part still to unfold.',
        worldRef='world:'..W.VERSION..'/race/'..(text and key or 'unknown'),sourceURL=sources[race=='Skyborne' and 'skyborne' or 'peoples'],confidence=text and 'REVIEWED' or 'UNKNOWN',
        sourceVersion=W.VERSION,era='FOREVER_START',licensing='Original brief historical paraphrase; Warcraft setting Blizzard',evidenceRefs={}}
    return out
end
function W.GetQuest(id,env)
    W.lookups=W.lookups+1;local data=ns.AthenaQuestData;env=env or W.Environment()
    if type(id)~='number' or id%1~=0 or not data then return nil,'UNKNOWN' end
    local compatibility=W.ReferenceCompatibility(env)
    local row=data.quests[id];if not row then return nil,'UNKNOWN' end
    if W.cacheSignature~=W.Signature() then W.Reset();W.cacheSignature=W.Signature() end
    local card=cache[id]
    if not card then
        local f={};for v in (row..'\031'):gmatch('(.-)\031') do f[#f+1]=v end
        card={kind='QUEST',id=id,title=Clean(f[1],256),premise=Clean(f[2]),giverIDs={},finisherIDs={},previousIDs={},nextIDs={},
            sourceVersion=data.version,sourceURL=data.sourceURL,worldRef='world:'..data.version..'/quest/'..id,referenceBuild=data.build,
            era='FOREVER_START',locale=data.locale,confidence=f[8]=='native' and 'PARTIAL_NATIVE_REFERENCE' or 'PARTIAL_CLASSIC_REFERENCE',
            licensing='QuestDB MIT / upstream game-content notices',coverage='Reference objective and metadata; no observed player result',nativeHarvest=f[8]=='native'}
        for key,at in pairs({giverIDs=3,finisherIDs=4,previousIDs=5,nextIDs=6}) do
            for n in (f[at] or ''):gmatch('%d+') do card[key][#card[key]+1]=tonumber(n) end
        end
        local reference=data.referenceMetadata and data.referenceMetadata[id]
        if reference then
            card.sourceVersion=reference.sourceVersion;card.sourceURL=reference.sourceURL
            card.sourceHash=reference.sourceHash;card.sourceBuild=reference.sourceBuild
            card.premiseMinimumStage=reference.premiseMinimumStage
            card.referenceBuild=reference.referenceBuild;card.confidence=reference.confidence
            card.licensing=reference.licensing;card.referenceQualification=reference.qualification
            card.worldRef='world:'..reference.sourceVersion..'/quest/'..id
            card.coverage='Original authored source account; current availability and unobserved player outcomes remain unproven'
        end
        card.giverName=card.giverIDs[1] and Clean(data.npcs[card.giverIDs[1]],144)
        card.finisherName=card.finisherIDs[1] and Clean(data.npcs[card.finisherIDs[1]],144)
        if reference then
            card.giverName=reference.giverName or card.giverName
            card.finisherName=reference.finisherName or card.finisherName
        end
        if not card.title then return nil,'UNKNOWN' end
        if #order>=W.CACHE_LIMIT then cache[table.remove(order,1)]=nil end
        order[#order+1]=id;cache[id]=card;W.decoded=W.decoded+1
    end
    local result=Copy(card);result.clientBuild=env.build;result.referenceCompatibility=compatibility
    if data.referenceMetadata and data.referenceMetadata[id] then
        result.referenceCompatibility='QUALIFIED_COMMUNITY_BETA_ACCOUNT'
    elseif compatibility~='SOURCE_BUILD' then result.referenceQualification='Bundled historical reference; agreement with this client is not certified. Personal context requires a matching native quest identity and observed stage.' end
    return result
end
function W.Get(kind,id,env)
    if kind=='QUEST' then return W.GetQuest(id,env) end
    if kind=='ERA' then local i=tonumber(id);local h=i and history[i];if h then return {kind='ERA',id=i,text=h[3],title=h[2],worldRef='world:'..W.VERSION..'/era/'..i,sourceURL=sources[h[1]],sourceVersion=W.VERSION,confidence='REVIEWED',era='FOREVER_START'} end
    elseif kind=='NPC' then
        env=env or W.Environment();local d=ns.AthenaQuestData
        if d and type(id)=='number' and d.npcs[id] then
            return {kind='NPC',id=id,name=Clean(d.npcs[id],144),worldRef='world:'..d.version..'/npc/'..id,sourceVersion=d.version,sourceURL=d.sourceURL,confidence='PARTIAL_CLASSIC_REFERENCE',era='FOREVER_START',qualification='Static quest-associated NPC identity; no personal meeting implied'}
        end
    end
    return nil,'UNKNOWN'
end
function W.ChainLink(beforeID,afterID,env)
    if ns.AthenaQuestChains then return ns.AthenaQuestChains.Link(beforeID,afterID,env) end
    local blocked=ns.AthenaQuestData and ns.AthenaQuestData.conflictingQuestEdges
    if blocked and blocked[tostring(beforeID)..'/'..tostring(afterID)] then return nil,'SOURCE_BRANCH_CONFLICT' end
    local before=W.GetQuest(beforeID,env);local after=W.GetQuest(afterID,env)
    if not before or not after then return nil,'UNKNOWN' end
    for _,id in ipairs(before.nextIDs or {}) do if id==afterID then
        return {before=before,after=after,worldRefs={before.worldRef,after.worldRef},confidence='QUALIFIED_REFERENCE_LINK'}
    end end
    return nil,'NO_VERIFIED_REFERENCE_LINK'
end
function W.QuestMeaning(claim,env,lookup)
    if type(claim)~='table' or type(claim.value)~='table' or not claim.evidenceRefs or #claim.evidenceRefs==0 then return nil,'NO_PLAYER_EVIDENCE' end
    local stages={owner_quest_accepted='BEGAN',owner_quest_observed='OBSERVED',owner_quest_objective='CONTINUED',owner_quest_turnin='COMPLETED',owner_quest_removed='UNRESOLVED'}
    local stage=stages[claim.claimType];if not stage then return nil,'NO_PLAYER_STAGE' end
    local card,why=(lookup or W.GetQuest)(claim.value.questID,env)
    if not card then return nil,why end
    if not card.worldRef or not card.title then return nil,'UNKNOWN' end
    if not claim.value.name then return nil,'QUEST_IDENTITY_UNCONFIRMED' end
    if claim.value.name and claim.value.name~=card.title then return nil,'TITLE_CONFLICT' end
    return {questID=claim.value.questID,stage=stage,reference=card,evidenceRefs=Copy(claim.evidenceRefs),worldRefs={card.worldRef},
        qualification='Quest context is reference material. Only the separately recorded stage belongs to this character.'}
end
