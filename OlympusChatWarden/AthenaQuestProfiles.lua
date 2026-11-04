-- Typed, bounded-on-demand projection of every bundled quest's source profile.
-- Static speech is reference material, never an observation of a player's deed.
local _,ns=...
local P={VERSION='quest-story-extractor-6.2'};ns.AthenaQuestProfiles=P
local categories={{'setup',1},{'motivations',2},{'conflict',4},{'stakes',8},{'conclusion',16},{'consequences',32},{'loreConnections',64},{'objectives',128},{'storytellingContext',256}}
local modalities={'SOURCE_STATEMENT','QUESTION','INTENT_OR_FUTURE','QUALIFIED_OR_CONDITIONAL'}
local function Split(s,sep) local out={};for part in ((s or '')..sep):gmatch('(.-)'..sep) do out[#out+1]=part end;return out end
local function Copy(t) return ns.Athena.Copy(t) end
function P.Display(text)
    text=(text or ''):gsub('%$[Bb]',' '):gsub('%$[Nn]','the adventurer'):gsub('%$[Cc]','adventurer'):gsub('%$[Rr]','traveler')
    text=text:gsub('%$[Gg]([^:;]*):([^;]*);',function(a,b) return a==b and a or (a..' / '..b) end)
    text=text:gsub('%$%a[^%s%.!?]*','[native expression unavailable]'):gsub('|','¦')
    return (text:gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$',''))
end
function P.Decode(id,row,hash)
    if type(row)~='string' then return nil end
    local f=Split(row,'\031');local keys=Split(f[3],'\030');local fields=Split(f[4],'\030')
    local out={questID=id,extractorVersion=P.VERSION,category=f[1],missingFields=f[2]~='' and Split(f[2],',') or {},atoms={},characters={},locations={},relationships={},objectiveEntities={},sourceHash=hash,observedByPlayer=false}
    for _,tag in ipairs(Split(f[5],'\030')) do if tag~='' then
        local v=Split(tag,',');local field=keys[tonumber(v[1])];local text=fields[tonumber(v[1])]
        local first,last,flags=tonumber(v[2]),tonumber(v[3]),tonumber(v[5])
        if not field or not text or not first or not last or not flags or first<1 or last>#text then return nil end
        local atom={id=id..':'..field..':'..first..'-'..last,field=field,text=P.Display(text:sub(first,last)),minimumStage=tonumber(v[4]),modality=modalities[tonumber(v[6])],categories={},
            sourceProof={questID=id,sourceHash=hash,field=field,firstByte=first,lastByte=last},speakerNPCID=tonumber(v[7])~=0 and tonumber(v[7]) or nil,
            truthScope='QUEST_SOURCE_ACCOUNT',personalCompletionProven=false}
        for _,c in ipairs(categories) do if math.floor(flags/c[2])%2==1 then atom.categories[#atom.categories+1]=c[1] end end
        out.atoms[#out.atoms+1]=atom
    end end
    for _,tag in ipairs(Split(f[6],'\030')) do if tag~='' then
        local npc,stage,atom,name=tag:match('^(%d+),(%d+),(%d+),(.+)$')
        if npc then out.characters[#out.characters+1]={npcID=tonumber(npc)~=0 and tonumber(npc) or nil,name=name,minimumStage=tonumber(stage),sourceAtom=tonumber(atom),role='MENTIONED',personallyEncountered=false} end
    end end
    for _,tag in ipairs(Split(f[7],'\030')) do if tag~='' then
        local stage,area,map,atom,name=tag:match('^(%d+),(%d+),(%d+),(%d+),(.*)$')
        if stage then out.locations[#out.locations+1]={minimumStage=tonumber(stage),areaID=tonumber(area)~=0 and tonumber(area) or nil,mapID=tonumber(map)~=0 and tonumber(map) or nil,
            sourceAtom=tonumber(atom)~=0 and tonumber(atom) or nil,name=name~='' and name or nil,certainty=tonumber(atom)==0 and 'EXPLICIT_SOURCE_ID' or 'TEXT_CANDIDATE'} end
    end end
    for _,tag in ipairs(Split(f[8],'\030')) do if tag~='' then
        local id,field,signed,status=tag:match('^(%d+),(%d+),(-?%d+),?([%u_]*)$')
        if id then out.relationships[#out.relationships+1]={questID=tonumber(id),sourceField=tonumber(field),signedSourceValue=tonumber(signed),branchCompatibility=status~='' and status or 'UNKNOWN',impliesPlayerCompletion=false} end
    end end
    for _,tag in ipairs(Split(f[9],'\030')) do if tag~='' then
        local kind,id,role,count,field,name=tag:match('^(%u+),(%d+),(%u+),([^,]+),(%d+),(.*)$')
        if kind then out.objectiveEntities[#out.objectiveEntities+1]={kind=kind,id=tonumber(id),role=role,requiredCount=tonumber(count),sourceField=tonumber(field),name=name~='' and name or nil,minimumStage=2,provesPlayerAction=false} end
    end end
    return out
end
function P.ForStage(profile,stage)
    if not profile then return nil end
    local out={questID=profile.questID,extractorVersion=profile.extractorVersion,sourceHash=profile.sourceHash,atoms={},characters={},locations={},relationships=Copy(profile.relationships),objectiveEntities=Copy(profile.objectiveEntities),fields={},observedByPlayer=false}
    for _,atom in ipairs(profile.atoms) do if atom.minimumStage<=stage then
        local a=Copy(atom);out.atoms[#out.atoms+1]=a
        for _,key in ipairs(a.categories) do out.fields[key]=out.fields[key] or {};out.fields[key][#out.fields[key]+1]=a end
    end end
    for _,c in ipairs(profile.characters) do if c.minimumStage<=stage then out.characters[#out.characters+1]=Copy(c) end end
    for _,loc in ipairs(profile.locations) do if loc.minimumStage<=stage then out.locations[#out.locations+1]=Copy(loc) end end
    -- Coverage of future fields is itself withheld until the conclusion opens.
    if stage>=4 then out.category=profile.category;out.missingFields=Copy(profile.missingFields) end
    return out
end
function P.Scene(profile,phase,giverName)
    if not profile then return nil end
    local field=phase=='ending' and 'conclusion' or 'setup';local choices=profile.fields[field] or {}
    local candidates={}
    for index,a in ipairs(choices) do
        local text=a.text
        if giverName then text=text:gsub('%f[%a][Mm]y%s+',giverName..'’s ') end
        local personal=false
        for word in text:lower():gmatch('%a+') do if ({i=true,me=true,my=true,mine=true,we=true,us=true,our=true,ours=true,you=true,your=true,yours=true})[word] then personal=true end end
        local first=text:lower():match('^(%a+)')
        local unresolved=({he=true,she=true,his=true,her=true,it=true,its=true,this=true,that=true,these=true,those=true,they=true,their=true})[first]
        local imperative=({travel=true,go=true,speak=true,talk=true,['return']=true,bring=true,find=true,destroy=true,kill=true,collect=true,use=true,give=true,take=true,search=true,report=true,seek=true,deliver=true,recover=true,obtain=true,retrieve=true,follow=true,help=true,ask=true,visit=true,slay=true,meet=true,enter=true,head=true,locate=true,escort=true,defeat=true,summon=true,place=true})[first]
        if not personal and not unresolved and not imperative and a.modality~='QUESTION' and #text>32 and #text<=360 and not text:find('[<>]') and not text:find('%[native expression unavailable%]') then
            -- Only conservative tense edits; no new motives, rewards, dialogue
            -- or deeds are produced. Conditional words remain untouched.
            text=text:gsub(' is ',' was '):gsub(' are ',' were '):gsub(' has been ',' had been '):gsub(' have been ',' had been ')
            local lower=text:lower()
            if giverName and (lower:find('clearly',1,true) or lower:find('brilliant',1,true) or lower:find('schlep',1,true) or lower:find('for sure',1,true)) then
                text='In '..giverName..'’s telling, '..text:gsub('^%u',string.lower)
            end
            local score=0;for _,key in ipairs(a.categories) do if key=='conflict' or key=='loreConnections' or key=='stakes' then score=score+2 end end
            candidates[#candidates+1]={text=text,index=index,score=score}
        end
    end
    table.sort(candidates,function(a,b) return a.score>b.score or a.score==b.score and a.index<b.index end)
    local picked={};for i=1,math.min(2,#candidates) do picked[#picked+1]=candidates[i] end
    table.sort(picked,function(a,b) return a.index<b.index end)
    local text={};for _,a in ipairs(picked) do text[#text+1]=a.text end
    return #text>0 and table.concat(text,' ') or nil
end
function P.LoreText(profile,phase)
    if not profile then return nil end
    local keys=phase=='ending' and {'conclusion','consequences'} or {'setup','objectives','motivations','conflict','stakes','loreConnections'}
    local blocks,seen={},{}
    for _,key in ipairs(keys) do
        local lines={};for _,a in ipairs(profile.fields[key] or {}) do if not seen[a.id] then
            seen[a.id]=true;lines[#lines+1]='“'..a.text..'”'
        end end
        if #lines>0 then blocks[#blocks+1]=table.concat(lines,'\n\n') end
    end
    if #blocks==0 then return nil end
    return table.concat(blocks,'\n\n')
end
