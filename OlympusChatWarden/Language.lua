-- Local reading preferences. Confidence is heuristic, independent of word scores.
-- Script ranges reference Unicode charts / UAX #24; shared scripts are not languages.
local _,ns=...
local L={};ns.Language=L
L.MINIMUM=4
L.Choices={{'en','English'},{'es','Spanish'},{'fr','French'},{'de','German'},{'pt','Portuguese'},
    {'it','Italian'},{'ru','Russian'},{'uk','Ukrainian'},{'ja','Japanese (kana)'},{'ko','Korean (Hangul)'},
    {'han','Han text (Chinese / Japanese)'},{'cyrl','Unidentified Cyrillic'},
    {'arab','Arabic script (shared)'},{'hebr','Hebrew script'},{'grek','Greek script'},
    {'deva','Devanagari (shared)'},{'thai','Thai script'},{'armn','Armenian script'},{'geor','Georgian script'}}
local titles={};for _,item in ipairs(L.Choices) do titles[item[1]]=item[2] end
L.ScriptChoices={{'han','Han (Chinese / Japanese)'},{'ja','Japanese kana'},{'ko','Hangul (Korean)'},
    {'cyrl','Cyrillic'},{'arab','Arabic script'},{'hebr','Hebrew'},{'grek','Greek'},
    {'deva','Devanagari'},{'thai','Thai'},{'armn','Armenian'},{'geor','Georgian'}}
local scriptTitles={};for _,item in ipairs(L.ScriptChoices) do scriptTitles[item[1]]=item[2] end
local scopes={CHAT_MSG_SAY='public',CHAT_MSG_YELL='public',CHAT_MSG_CHANNEL='public',CHAT_MSG_WHISPER='whispers',
    CHAT_MSG_GUILD='guild',CHAT_MSG_OFFICER='guild',CHAT_MSG_PARTY='group',CHAT_MSG_PARTY_LEADER='group',
    CHAT_MSG_RAID='group',CHAT_MSG_RAID_LEADER='group',CHAT_MSG_RAID_WARNING='group',
    CHAT_MSG_INSTANCE_CHAT='group',CHAT_MSG_INSTANCE_CHAT_LEADER='group'}
local wordLists={
 en='the and this that with from your you are have need looking please hello thanks thank where what why who for group can want join selling buying healer tank dungeon today here there not ready invite quest',
 es='hola gracias quiero quieres necesito necesitamos busco buscamos donde dónde como cómo estas estás estamos alguien puede puedes para pero tengo tienes somos vosotros nosotros mazmorra por favor una los las del que con estoy',
 fr='bonjour merci cherche cherchons besoin pouvez vous nous votre avec pour dans suis êtes est une les des aux pas pourquoi où quelqu’un groupe donjon maintenant',
 de='hallo danke suche suchen brauche brauchen bitte nicht kann kannst wer warum jetzt hier dort ich wir ihr eine einen einer und mit für zum den dem das ist sind',
 pt='olá obrigado obrigada preciso precisamos procuro procuramos você vocês não nao quero alguém alguem pode podemos para estou estamos uma os as pelo pela meu minha hoje aqui mas com que',
 it='ciao grazie cerco cerchiamo bisogno voglio vuoi qualcuno puoi possiamo sono siamo siete perché perche dove adesso qui una gli delle dello nella nel con per non che',
 ru='привет спасибо пожалуйста нужен нужна нужно ищу ищем группа можно сейчас здесь почему куда кто что как для меня тебя нет есть хочу давайте пригласите подземелье',
 uk='привіт дякую будь ласка потрібен потрібна потрібно шукаю шукаємо група можна зараз тут чому куди хто що як для мене тебе немає хочу запросіть підземелля',
}
local words={}
for id,list in pairs(wordLists) do words[id]={};for word in list:gmatch('%S+') do words[id][word]=true end end
local cache,order,bytes={},{},0
function L.Invalidate() cache,order,bytes={},{},0 end
function L.Initialize()
    local db=type(ns.DB.languageFilter)=='table' and ns.DB.languageFilter or {};ns.DB.languageFilter=db
    local allowed={en=true}
    for id,value in pairs(type(db.allowed)=='table' and db.allowed or {}) do if titles[id] and value==true then allowed[id]=true end end
    db.allowed=allowed
    for _,key in ipairs({'public','whispers','group','guild'}) do if type(db[key])~='boolean' then db[key]=true end end
    -- Apply the simpler model once. Keep the master switch and reading/coverage
    -- choices; names no longer change a message's language decision.
    if db.settingsVersion~=3 then
        db.low='cover';db.high='hide';db.maskNames=false;db.settingsVersion=3
    end
    db.minimum=L.MINIMUM;db.confidence=true
    if type(db.maskNames)~='boolean' then db.maskNames=false end
    for _,key in ipairs({'medium','unidentified','mixedWhole','hideNamedSenders','senderAction','strictScripts'}) do db[key]=nil end
    local selected={}
    for id in pairs(scriptTitles) do selected[id]=not allowed[id] end
    -- Cyrillic names cannot distinguish Russian/Ukrainian; allow the script if
    -- either language is readable. Han follows its shared Chinese/Japanese entry.
    selected.cyrl=not (allowed.cyrl or allowed.ru or allowed.uk)
    db.scripts=selected
    for key,default in pairs({low='cover',high='hide'}) do
        if db[key]~='cover' and db[key]~='hide' and db[key]~='mark' and db[key]~='leave' then db[key]=default end
    end
    L.Invalidate()
end
function L.Set(key,value)
    if key=='enabled' then ns.DB.languageEnabled=value==true
    elseif titles[key] then ns.DB.languageFilter.allowed[key]=key=='en' or value==true
    elseif key=='low' or key=='high' or key=='maskNames' or key=='public' or key=='whispers' or key=='group' or key=='guild' then ns.DB.languageFilter[key]=value end
    L.Initialize();L.Invalidate();ns.PolicyChanged()
    if ns.RefreshLanguageOptions then ns.RefreshLanguageOptions() end
    if ns.SyncOptions then ns.SyncOptions() end
end
local function Between(c,a,b) return c>=a and c<=b end
local function Script(c)
    if Between(c,65,90) or Between(c,97,122) or Between(c,0xC0,0xD6) or Between(c,0xD8,0xF6)
        or Between(c,0xF8,0x24F) or Between(c,0x1E00,0x1EFF) then return 'latn' end
    if Between(c,0x400,0x481) or Between(c,0x48A,0x52F) then return 'cyrl' end
    if Between(c,0x3400,0x4DBF) or Between(c,0x4E00,0x9FFF) or Between(c,0xF900,0xFAFF)
        or Between(c,0x20000,0x2FA1F) then return 'east','han' end
    if Between(c,0x3041,0x3096) or Between(c,0x30A1,0x30FA) or Between(c,0x31F0,0x31FF) then return 'east','kana' end
    if Between(c,0xAC00,0xD7A3) or Between(c,0x1100,0x11FF) or Between(c,0x3131,0x318E) then return 'ko' end
    if Between(c,0x620,0x63F) or Between(c,0x641,0x64A) or Between(c,0x66E,0x66F)
        or Between(c,0x671,0x6D3) or Between(c,0x6FA,0x6FC) or Between(c,0x750,0x77F) then return 'arab' end
    if Between(c,0x5D0,0x5EA) or Between(c,0x5EF,0x5F2) then return 'hebr' end
    if Between(c,0x391,0x3A1) or Between(c,0x3A3,0x3CE) or Between(c,0x1F00,0x1FFF) then return 'grek' end
    if Between(c,0x904,0x939) or Between(c,0x958,0x961) then return 'deva' end
    if Between(c,0xE01,0xE30) or Between(c,0xE32,0xE33) or Between(c,0xE40,0xE46) then return 'thai' end
    if Between(c,0x531,0x556) or Between(c,0x561,0x587) then return 'armn' end
    if Between(c,0x10A0,0x10C5) or Between(c,0x10D0,0x10FA) or Between(c,0x1C90,0x1CBA) then return 'geor' end
end
local function Decode(s,i)
    local a,b,c,d=s:byte(i,i+3)
    if a<128 then return a,1 end
    local function Tail(v) return v and v>=128 and v<=191 end
    if a>=194 and a<=223 and Tail(b) then return (a-192)*64+b-128,2 end
    if a>=224 and a<=239 and Tail(b) and Tail(c) and (a~=224 or b>=160) and (a~=237 or b<160) then
        return (a-224)*4096+(b-128)*64+c-128,3 end
    if a>=240 and a<=244 and Tail(b) and Tail(c) and Tail(d) and (a~=240 or b>=144) and (a~=244 or b<144) then
        return (a-240)*262144+(b-128)*4096+(c-128)*64+d-128,4 end
end
local function Encode(c)
    if c<128 then return string.char(c) end
    if c<2048 then return string.char(192+math.floor(c/64),128+c%64) end
    return string.char(224+math.floor(c/4096),128+math.floor(c/64)%64,128+c%64)
end
local function Lower(c,original)
    if Between(c,65,90) or Between(c,0xC0,0xD6) or Between(c,0xD8,0xDE) or Between(c,0x410,0x42F) then return Encode(c+32) end
    if Between(c,0x400,0x40F) then return Encode(c+80) end
    return original
end
-- Name ranges follow the reading list. They neither estimate message language
-- nor require a minimum name length.
function L.ScriptRanges(text,linked)
    if not ns.DB or not ns.DB.languageFilter or not ns.CanRead(text) or #text>ns.Engine.MAX_TEXT then return end
    local ranges,ids,total,covered,offset={}, {},0,0,0
    for _,piece in ipairs(ns.Engine.Segments(text)) do
        if piece.editable then
            local i,run=1,nil
            while i<=#piece.text do
                local c,size=Decode(piece.text,i);if not c then return end
                local script,sub=Script(c)
                local id=script=='east' and (sub=='kana' and 'ja' or 'han') or script
                if script then total=total+1 end
                if id and ns.DB.languageFilter.scripts[id] then
                    covered=covered+1;ids[id]=true
                    if not run then run={first=offset+i,last=offset+i+size-1,score=0,gommage=true,languageMask=true};ranges[#ranges+1]=run end
                    run.last=offset+i+size-1
                elseif run and (Between(c,0x300,0x36F) or Between(c,0x64B,0x65F) or Between(c,0x93A,0x94D)) then
                    run.last=offset+i+size-1
                else run=nil end
                if #ranges>256 then return end
                i=i+size
            end
        elseif linked then
            local open,label=piece.text:match('^(|H[^|]+|h)(.-)|h$')
            if open and not open:match('^|Haddon:') then
                local found,_,_,linkIDs,linkTotal,linkCovered=L.ScriptRanges(label)
                total=total+(linkTotal or 0);covered=covered+(linkCovered or 0)
                for id in pairs(linkIDs or {}) do ids[id]=true end
                for _,range in ipairs(found or {}) do
                    range.first=range.first+offset+#open;range.last=range.last+offset+#open;ranges[#ranges+1]=range
                    if #ranges>256 then return end
                end
            end
        end
        offset=offset+#piece.text
    end
    if #ranges==0 then return nil,nil,nil,ids,total,covered end
    local id,count=nil,0;for key in pairs(ids) do id=key;count=count+1 end
    return ranges,count==1 and id or 'mixed',covered/math.max(total,1),ids,total,covered
end
function L.NamesActive()
    return ns.DB and ns.DB.languageEnabled and ns.DB.languageFilter and ns.DB.languageFilter.maskNames and ns.Active()
end
function L.NameMatches(text,matches)
    if not L.NamesActive() then return matches end
    local ranges,id=L.ScriptRanges(text);if not ranges then return matches end
    local out=L.Display(matches,{action='Redacted',ranges=ranges})
    for _,hit in ipairs(out) do if hit.languageMask then
        hit.pack='language-script';hit.accepted=true;hit.phrase=text:sub(hit.first,hit.last);hit.reason='Name display: non-preferred '..(scriptTitles[id] or 'writing systems')..' script';hit.origin='local preference'
    end end
    return out
end
local function LabelLetters(text)
    local total=0
    for _,piece in ipairs(ns.Engine.Segments(text)) do if piece.editable then
        local i=1
        while i<=#piece.text do
            local c,size=Decode(piece.text,i);if not c then return end
            if Script(c) then total=total+1 end;i=i+size
        end
    end end
    return total
end
local function Blocks(text)
    local blocks,total,tokens,offset={},0,0,0
    for _,piece in ipairs(ns.Engine.Segments(text)) do
        if piece.editable then
            local block,token,i=nil,nil,1
            local urls,pos={},1
            while true do
                local first,last=piece.text:find('[Hh][Tt][Tt][Pp][Ss]?://%S+',pos);if not first then break end
                urls[first]=last;pos=last+1
            end
            local function FlushToken()
                if token then token.text=table.concat(token.parts);token.parts=nil;block.tokens[#block.tokens+1]=token;token=nil end
            end
            local function FlushBlock() FlushToken();block=nil end
            while i<=#piece.text do
                if urls[i] then FlushBlock();i=urls[i]+1
                else
                    local c,size=Decode(piece.text,i);if not c then return nil end
                    local script,sub=Script(c);local raw=piece.text:sub(i,i+size-1)
                    if script then
                        if not block or block.script~=script then
                            FlushBlock();block={script=script,first=offset+i,last=offset+i+size-1,letters=0,kana=0,tokens={}}
                            blocks[#blocks+1]=block;if #blocks>128 then return nil end
                        end
                        block.letters=block.letters+1;block.last=offset+i+size-1;total=total+1
                        if sub=='kana' then block.kana=block.kana+1 end
                        if not token then token={first=offset+i,last=offset+i+size-1,parts={},letters=0};tokens=tokens+1;if tokens>512 then return nil end end
                        token.last=offset+i+size-1;token.parts[#token.parts+1]=Lower(c,raw);token.letters=token.letters+1
                    elseif Between(c,0x300,0x36F) or Between(c,0x64B,0x65F) or Between(c,0x93A,0x94D) then
                        if block then block.last=offset+i+size-1 end
                        if token then token.last=offset+i+size-1;token.parts[#token.parts+1]=raw end
                    else
                        FlushToken()
                        if c==46 or c==33 or c==63 or c==59 or c==10 or c==0x3002 or c==0xFF01 or c==0xFF1F then FlushBlock() end
                    end
                    i=i+size
                end
            end
            FlushToken()
        else
            -- Native link labels stay intact. Count their visible letters so an
            -- English item label cannot make a partly foreign line look wholly
            -- foreign; never inspect the hidden payload or nest reveal links.
            local label=piece.text:match('^|H[^|]+|h(.-)|h$')
            if label then local count=LabelLetters(label);if not count then return nil end;total=total+count end
        end
        offset=offset+#piece.text
    end
    return blocks,total
end
local function Identify(block,minimum)
    if block.letters<minimum then return end
    local script=block.script
    if script=='east' then
        if block.kana>=3 then return 'ja',block.letters>=16 and 'High' or 'Medium' end
        return 'han','Medium'
    elseif script=='ko' then return 'ko',block.letters>=16 and 'High' or 'Medium'
    elseif script~='latn' and script~='cyrl' then return script,'Medium' end
    local votes,distinct,seen={},{},{}
    local ids=script=='latn' and {'en','es','fr','de','pt','it'} or {'ru','uk'}
    for _,id in ipairs(ids) do
        votes[id],distinct[id],seen[id]=0,0,{}
        for _,token in ipairs(block.tokens) do if words[id][token.text] then
            votes[id]=votes[id]+1
            if not seen[id][token.text] then seen[id][token.text]=true;distinct[id]=distinct[id]+1 end
        end end
    end
    local best,top,runner=nil,0,0
    for _,id in ipairs(ids) do
        if votes[id]>top then runner=top;best,top=id,votes[id] else runner=math.max(runner,votes[id]) end
    end
    block.english=votes.en or 0
    if best=='en' then return 'en','High' end
    if best and distinct[best]>=3 and top-runner>=2 and top/#block.tokens>=0.35 then
        local high=distinct[best]>=5 and top-runner>=3 and top/#block.tokens>=0.5 and block.letters>=24 and block.english==0
        return best,high and 'High' or 'Medium'
    end
    if script=='cyrl' then return 'cyrl','Medium' end
end
local function Analyze(text)
    local db=ns.DB.languageFilter;local blocks,total=Blocks(text)
    local minimum=L.MINIMUM
    if not blocks or total<minimum then return end
    local ranges,ids,covered,allHigh={}, {},0,true
    for _,block in ipairs(blocks) do
        local id,confidence=Identify(block,minimum)
        if id and not db.allowed[id] then
                ids[id]=true;allHigh=allHigh and confidence=='High'
                local function Add(first,last,letters)
                    ranges[#ranges+1]={first=first,last=last,score=0,gommage=true,languageMask=true}
                    covered=covered+letters
                end
                -- In a mixed Latin clause, only positively identified foreign tokens are covered.
                if block.english and block.english>0 then
                    for _,token in ipairs(block.tokens) do if words[id] and words[id][token.text] and not words.en[token.text] then Add(token.first,token.last,token.letters) end end
                else Add(block.first,block.last,block.letters) end
        end
    end
    if #ranges==0 then return end
    local id,label,count=nil,nil,0
    for key in pairs(ids) do id=key;count=count+1 end
    if count>1 then id='mixed';label='Multiple languages / writing systems' else label=titles[id] end
    local share=covered/total;local confidence=allHigh and 'High' or 'Low'
    local mostly=share>=0.85
    local actionBand=(allHigh or mostly) and 'high' or 'low'
    local mode=db[actionBand]
    -- Whole-message coverage selects the high action without pretending an
    -- uncertain shared script is a confidently identified language.
    local action=mode=='leave' and 'Unchanged' or mode=='mark' and 'Warning'
        or mode=='hide' and 'Hidden' or 'Redacted'
    local evidence=(id=='han' or id=='cyrl' or id=='arab' or id=='deva' or id=='hebr' or id=='grek' or id=='thai' or id=='armn' or id=='geor') and 'writing-system' or id=='mixed' and 'mixed' or 'language'
    local reason=label..'; '..confidence:lower()..' heuristic confidence; '..math.floor(share*100)..'% of readable letters in detected portions'
    if evidence=='writing-system' then reason=reason..'; writing system identified, language uncertain' end
    reason=reason..'; '..actionBand..' action selected '..(mostly and 'because at least 85% of readable letters are non-preferred' or 'by language confidence')
    return {id=id,label=label,confidence=confidence,action=action,reason=reason,share=share,ranges=ranges,minimum=minimum,
        actionBand=actionBand,basis=mostly and 'mostly-non-preferred' or 'language-confidence',evidence=evidence}
end
function L.Covers(event,source)
    if not ns.DB or not ns.DB.languageEnabled or not ns.Active('chat') or not ns.DB.languageFilter
        or not source or source.kind~='player' or not ns.CanRead(event) or not scopes[event] then return false end
    if ns.Shield and ns.Shield.Key(source.sender)==ns.Shield.Key(ns.Shield.UnitName('player')) then return false end
    return ns.DB.languageFilter[scopes[event]]~=false
end
function L.Check(text,event,source,includeLeave)
    if not L.Covers(event,source) or not ns.CanRead(text) or #text>ns.Engine.MAX_TEXT then return end
    local result
    if cache[text]~=nil then result=cache[text] or nil
    else
        result=Analyze(text)
        if #order>=64 or bytes+#text>262144 then L.Invalidate() end
        cache[text]=result or false;order[#order+1]=text;bytes=bytes+#text
    end
    return result and (includeLeave or result.action~='Unchanged') and result or nil
end
function L.Action(wordAction,result)
    local rank={Unchanged=0,Warning=1,Replaced=2,Redacted=3,Hidden=4}
    return result and rank[result.action]>rank[wordAction] and result.action or wordAction
end
function L.Display(matches,result)
    if not result or result.action=='Warning' or result.action=='Unchanged' then return matches end
    local out={}
    for _,hit in ipairs(matches) do if ns.IsRedacted(hit) then out[#out+1]=hit end end
    for _,range in ipairs(result.ranges) do
        local parts={{range.first,range.last}}
        for _,hit in ipairs(matches) do if ns.IsRedacted(hit) then
            local nextParts={}
            for _,part in ipairs(parts) do
                if hit.last<part[1] or hit.first>part[2] then nextParts[#nextParts+1]=part
                else
                    if hit.first>part[1] then nextParts[#nextParts+1]={part[1],hit.first-1} end
                    if hit.last<part[2] then nextParts[#nextParts+1]={hit.last+1,part[2]} end
                end
            end
            parts=nextParts
        end end
        for _,part in ipairs(parts) do out[#out+1]={first=part[1],last=part[2],score=0,gommage=true,languageMask=true} end
    end
    table.sort(out,function(a,b) return a.first<b.first end);return out
end
function L.Copy(result)
    if type(result)~='table' then return end
    local copy={}
    for _,key in ipairs({'id','label','confidence','action','reason'}) do copy[key]=ns.SafeString(result[key],512) end
    copy.share=ns.SafeNumber(result.share);copy.minimum=ns.SafeNumber(result.minimum)
    if result.actionBand=='low' or result.actionBand=='high' then copy.actionBand=result.actionBand end
    if result.basis=='mostly-non-preferred' or result.basis=='language-confidence' then copy.basis=result.basis end
    if result.evidence=='language' or result.evidence=='writing-system' or result.evidence=='mixed' then copy.evidence=result.evidence end
    if result.kind=='sender-script' or result.kind=='strict-script' or result.kind=='sender-language' then copy.kind=result.kind end
    if scriptTitles[result.nameScript] or result.nameScript=='mixed' then copy.nameScript=result.nameScript end
    if (copy.confidence~='High' and copy.confidence~='Medium' and copy.confidence~='Low')
        or (copy.action~='Hidden' and copy.action~='Redacted' and copy.action~='Warning') then return end
    return (titles[copy.id] or copy.id=='mixed') and copy or nil
end
function L.Allow(result)
    if result and titles[result.id] then L.Set(result.id,true);return true end
end
function L.Context(text,event,source)
    if not ns.DB or not ns.DB.languageFilter then return end
    local db=ns.DB.languageFilter
    local context={enabled=ns.DB.languageEnabled==true,chatEnabled=ns.Active('chat')==true,
        minimum=L.MINIMUM,low=db.low,high=db.high,mostlyMinimum=0.85,
        maskNames=db.maskNames,confidence=true,settingsVersion=db.settingsVersion,allowed={},scripts={},coverage={}}
    for id in pairs(titles) do context.allowed[id]=db.allowed[id]==true end
    for id in pairs(scriptTitles) do context.scripts[id]=db.scripts[id]==true end
    for _,key in ipairs({'public','whispers','group','guild'}) do context.coverage[key]=db[key]==true end
    context.manualExample=event==nil
    context.result=L.Copy(L.Check(text,event or 'CHAT_MSG_SAY',source or {kind='player'}))
    context.status=context.result and 'action-predicted' or 'no-language-action'
    return context
end
function L.CopyContext(value)
    if type(value)~='table' then return end
    local out={allowed={},scripts={},coverage={}}
    local modern=value.settingsVersion==3
    local flags=modern and {'enabled','chatEnabled','maskNames','manualExample'}
        or {'enabled','chatEnabled','mixedWhole','maskNames','hideNamedSenders','manualExample'}
    for _,key in ipairs(flags) do out[key]=value[key]==true end
    out.confidence=value.confidence~=false;out.settingsVersion=ns.SafeNumber(value.settingsVersion)
    if value.low=='cover' or value.low=='hide' or value.low=='mark' or value.low=='leave' then out.low=value.low end
    if value.mostlyMinimum==0.85 then out.mostlyMinimum=0.85 end
    local n=ns.SafeNumber(value.minimum);out.minimum=modern and L.MINIMUM or (n==4 or n==8 or n==12 or n==20) and n or 8
    if not modern then out.senderAction=(value.senderAction=='all' or value.senderAction=='filtered') and value.senderAction
        or value.hideNamedSenders==true and 'all' or 'filtered' end
    for _,key in ipairs(modern and {'low','high'} or {'medium','high','unidentified','strictScripts'}) do
        local mode=value[key];out[key]=(mode=='cover' or mode=='hide' or mode=='mark' or mode=='leave') and mode or 'leave'
    end
    for id in pairs(titles) do out.allowed[id]=type(value.allowed)=='table' and value.allowed[id]==true end
    for id in pairs(scriptTitles) do out.scripts[id]=type(value.scripts)=='table' and value.scripts[id]==true end
    for _,key in ipairs({'public','whispers','group','guild'}) do out.coverage[key]=type(value.coverage)=='table' and value.coverage[key]==true end
    out.result=L.Copy(value.result);out.status=out.result and 'action-predicted' or 'no-language-action'
    return out
end
