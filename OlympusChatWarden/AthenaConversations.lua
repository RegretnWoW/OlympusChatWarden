-- Explicitly opted-in, owner-private selected conversation preservation.
-- Separate from ChatCapture, canonical gameplay history, lore and peer APIs.
local _,ns=...
local C={VERSION=1,RULE_VERSION='event-linked-3',MAX_MOMENTS=5000,MAX_ARCHIVE_BYTES=20971520,MAX_STAGING=64,MAX_STAGING_BYTES=131072,
    MAX_CANDIDATES=40,MAX_CANDIDATE_BYTES=131072,MAX_TEXT=2048,STAGING_SECONDS=600,CANDIDATE_SECONDS=900,MAX_MESSAGES=8}
ns.AthenaConversations=C;ns.WardenDB=ns.WardenDB or {};ns.WardenDB.Conversations=C
local scopes={partyRaid=true,guild=true,sayEmote=true,publicChannels=true,whispers=true,officer=true,instance=true,npcDialogue=true}
local events={CHAT_MSG_PARTY='partyRaid',CHAT_MSG_PARTY_LEADER='partyRaid',CHAT_MSG_RAID='partyRaid',CHAT_MSG_RAID_LEADER='partyRaid',CHAT_MSG_RAID_WARNING='partyRaid',
    CHAT_MSG_GUILD='guild',CHAT_MSG_OFFICER='officer',CHAT_MSG_SAY='sayEmote',CHAT_MSG_YELL='sayEmote',CHAT_MSG_EMOTE='sayEmote',CHAT_MSG_TEXT_EMOTE='sayEmote',
    CHAT_MSG_CHANNEL='publicChannels',CHAT_MSG_WHISPER='whispers',CHAT_MSG_WHISPER_INFORM='whispers',CHAT_MSG_INSTANCE_CHAT='instance',CHAT_MSG_INSTANCE_CHAT_LEADER='instance'}
for _,event in ipairs({'CHAT_MSG_MONSTER_SAY','CHAT_MSG_MONSTER_YELL','CHAT_MSG_MONSTER_EMOTE','CHAT_MSG_MONSTER_WHISPER','CHAT_MSG_RAID_BOSS_EMOTE','CHAT_MSG_RAID_BOSS_WHISPER','GOSSIP_SHOW','QUEST_DETAIL','QUEST_PROGRESS','QUEST_COMPLETE','TALKINGHEAD_REQUESTED'})do events[event]='npcDialogue'end
function C.EventScope(event)return events[event]end
function C.DisplayEligible(state)return state=='Unchanged'or state=='Warning'or state=='FILTER_MODULE_DISABLED'or state=='VISIBLE_REGION_VERIFIED'end
-- Narrative cues reuse the existing ASCII normalizer and bounded spelling
-- distance. They never change a quotation or signed filtering vocabulary.
function C.Classify(text,linked)
 if not ns.CanRead(text)then return end
 local lower=ns.Engine.Lower(text);if lower:find('http',1,true)or lower:find('www.',1,true)or lower:match('%f[%a]wts%f[%A]')then return end
 local words={};for word in lower:gmatch('[a-z]+')do if #words>=48 then break end;words[#words+1]=word end
 local groups={{'celebration',{'gg','yes','win','finally','congratulations','congrats'}},{'urgency',{'run','heal','wipe'}},{'relief',{'phew','relief'}},{'encouragement',{'thanks','thank','great','nice','good'}},{'humor',{'lol','haha'}},{'frustration',{'frustrated','again'}},{'preparation',{'ready','prepare','wait','pull'}},{'farewell',{'farewell','goodbye','bye'}}}
 for _,group in ipairs(groups)do for _,target in ipairs(group[2])do for _,word in ipairs(words)do
  local exact=word==target;local close=not exact and linked and #target>=3 and #word>=3 and math.abs(#word-#target)<=1 and ns.SpellingMatch.Distance(word,target,1,true)<=1
  if exact or close then return group[1],lower,close and'SHARED_SPELLING_DISTANCE'or'EXACT_NORMALIZED_CUE'end
 end end end
 if linked and (lower:find('did it',1,true)or lower:find('get out',1,true)or lower:find('meet at',1,true))then return 'coordination',lower,'EXACT_NORMALIZED_PHRASE'end
end
local function Copy(v) return ns.Athena.Copy(v) end
local function Text(v,n) return ns.CanRead(v) and #v<=(n or 8192) and v or nil end
local function Positive(v) v=ns.SafeNumber(v);return v and v>0 and v%1==0 and v or nil end
local function Bytes(v) return #ns.Reports.JSON(v) end
local function Now() return ns.SafeNumber(ns.SafeCall(GetServerTime)) or ns.SafeNumber(ns.SafeCall(time)) or 0 end
local function GUID(v) return Text(v,128) and v:match('^Player%-.+') and v or nil end
local function Clip(text,n) local at=math.min(#text,n);while at>0 and text:byte(at+1) and text:byte(at+1)>=128 and text:byte(at+1)<=191 do at=at-1 end;return text:sub(1,at) end
-- Version 2 accounting excludes cached .bytes fields and charges each stored
-- message once, each moment once, and each retained revision/log once.
local function Charge(value,padding)
    local out={};for k,v in pairs(value)do if k~='bytes'then out[k]=v end end
    return Bytes(out)+(padding or 0)
end
function C.Recount(db,checkpoint)
    if type(db)~='table'or type(db.owners)~='table'then return nil,'INVALID_ARCHIVE'end
    local total,n=0,0
    for _,r in pairs(db.owners)do
        if type(r)~='table'or type(r.policy)~='table'or type(r.messages)~='table'or type(r.moments)~='table'or type(r.order)~='table'or type(r.revisions)~='table'or r.revisionLog and type(r.revisionLog)~='table'then return nil,'INVALID_OWNER'end
        total=total+Bytes(r.policy)+256;if checkpoint then checkpoint()end
        for _,e in pairs(r.messages)do if type(e)~='table'then return nil,'INVALID_MESSAGE'end;total=total+Charge(e)if checkpoint then checkpoint()end end
        for _,m in pairs(r.moments)do if type(m)~='table'then return nil,'INVALID_MOMENT'end;total=total+Charge(m,256);n=n+1 if checkpoint then checkpoint()end end
        for _,v in pairs(r.revisions)do total=total+Bytes(v)if checkpoint then checkpoint()end end
        for _,v in pairs(r.revisionLog or{})do total=total+Bytes(v)if checkpoint then checkpoint()end end
    end
    return total,n
end
local function Selection(ids)
    local out={};for _,id in ipairs(ids)do out[#out+1]=#id..':'..id end;return table.concat(out)
end
local function SupportedRoot(db)
    return type(db)=='table' and not getmetatable(db) and db.version==1 and type(db.owners)=='table'
        and ns.SafeNumber(db.bytes) and db.bytes>=0 and ns.SafeNumber(db.moments) and db.moments>=0
        and ns.SafeNumber(db.nextMoment) and db.nextMoment>=0 and db.nextMoment%1==0
        and ns.SafeNumber(db.sessionSequence) and db.sessionSequence>=0
end
function C.NewStore(options)
    local o=options or {};local S={root=o.root,staging={},stagingBytes=0,candidates={},candidateBytes=0,seen={},seenOrder={},sequence=0,epoch=0,contexts=setmetatable({},{__mode='k'}),warnings={},revision=0,metrics={seen=0,displayVerified=0,staged=0,candidates=0,preserved=0,expired=0,rejected=0,linked=0},deliveries={},deliveryOrder={}}
    local checked=setmetatable({},{__mode='k'});local indexes=setmetatable({},{__mode='k'});local accounted
    S.linkQueue={};S.linkKeys={}
    local function owner() return o.owner and o.owner() or ns.Chronicle.Owner() end
    local function clock() return o.clock and o.clock() or Now() end
    local function permitted() return o.recording and o.recording() or (not o.recording and ns.Permissions.Decide('ConversationCollect') and ns.Modules.Enabled('chronicle') and ns.Chronicle.Active()) end
    local function access() return o.access and o.access() or (not o.access and ns.Permissions.Decide('UIAccess') and ns.Athena.Enabled('chronicle') and ns.Membership.LocalHistoryAllowed()) end
    local function qualify(r,key,db,checkpoint)
        do
            -- Validate once per loaded owner; never repair, prune or replace an
            -- unrecognized archive. Steady-state chat ingestion is bounded RAM.
            local valid=r.revisionLog==nil or type(r.revisionLog)=='table';local seen={};local count=0
            for i,ref in pairs(r.order) do checkpoint()
                count=count+1;local m=type(ref)=='string' and r.moments[ref];local suffix=type(ref)=='string' and tonumber(ref:match('/(%d+)$'))
                if type(i)~='number' or i%1~=0 or i<1 or i>#r.order or seen[ref] or not m or type(m)~='table' or m.owner~=key or m.momentRef~=ref
                    or not suffix or suffix>db.nextMoment or type(m.messageEvidenceRefs)~='table' or #m.messageEvidenceRefs<1 or #m.messageEvidenceRefs>C.MAX_MESSAGES
                    or type(m.sourceRefs)~='table' or type(m.activityRelationRefs)~='table' or not ns.SafeNumber(m.observedFrom) or not ns.SafeNumber(m.observedTo) then valid=false;break end
                seen[ref]=true
                for _,id in ipairs(m.messageEvidenceRefs) do local e=r.messages[id];local session=type(id)=='string' and tonumber(id:match('/(%d+)/%d+$'))
                    if type(e)~='table' or e.owner~=key or e.observationUID~=id or not session or session>db.sessionSequence or not Text(e.text,C.MAX_TEXT)
                        or type(e.speaker)~='table' or type(e.context)~='table' or not scopes[e.channelKind] or not ns.SafeNumber(e.observedAt) then valid=false;break end
                end
                if not valid then break end
            end
            if count~=#r.order then valid=false end
            if not valid then S.warnings.storage='INVALID_OWNER_ARCHIVE_PRESERVED';return false end
            local ix={selection={},byUID={},sources={},activities={}}
            for _,ref in ipairs(r.order)do checkpoint() local m=r.moments[ref];local key=Selection(m.messageEvidenceRefs)
                if ix.selection[key]then S.warnings.storage='DUPLICATE_SELECTION_ARCHIVE_PRESERVED';return false end
                ix.selection[key]=ref;ix.sources[ref]={};ix.activities[ref]={}
                for _,source in ipairs(m.sourceRefs)do ix.sources[ref][source]=true end
                for _,source in ipairs(m.activityRelationRefs)do ix.activities[ref][source]=true end
                for _,uid in ipairs(m.messageEvidenceRefs)do local refs=ix.byUID[uid]or{};ix.byUID[uid]=refs;refs[#refs+1]=ref end
            end
            indexes[r]=ix;checked[r]=true
        end
        return true
    end
    local function monotonic()return type(debugprofilestop)=='function'and debugprofilestop()or os and os.clock and os.clock()*1000 or 0 end
    function S.RecoveryStep()
        local job=S.recovery;if not job or job.state~='RECOVERING'then return true end
        local begin=monotonic();job.deadline=begin+2
        local ok,why=coroutine.resume(job.thread);local elapsed=monotonic()-begin;job.maxSliceMS=math.max(job.maxSliceMS,elapsed);job.cpuMS=job.cpuMS+elapsed
        if not ok then job.state='RECOVERY_REQUIRED';S.warnings.storage='INVALID_ACCOUNTING_ARCHIVE_PRESERVED';job.reason=tostring(why):sub(1,160);return true end
        if coroutine.status(job.thread)=='dead'then job.state='READY';S.warnings.storage=nil;return true end
        return false
    end
    function S.BeginRecovery(db)
        local job={state='RECOVERING',processed=0,maxSliceMS=0,cpuMS=0};S.recovery=job;S.warnings.storage='ARCHIVE_RECOVERING'
        local function checkpoint()job.processed=job.processed+1;if job.processed%8==0 and monotonic()>=job.deadline then coroutine.yield()end end
        job.thread=coroutine.create(function()
            local bytes,moments=C.Recount(db,checkpoint);if not bytes then error(moments)end
            for key,r in pairs(db.owners)do
                if type(r.policy.scopes)~='table'or type(r.revision)~='number'or #r.order>C.MAX_MOMENTS then error('INVALID_OWNER')end
                if not qualify(r,key,db,checkpoint)then error('INVALID_OWNER')end
                checkpoint()
            end
            if db.accountingVersion~=2 or db.bytes~=bytes or db.moments~=moments then db.bytes=bytes;db.moments=moments;db.accountingVersion=2;S.dirty=true end
            accounted=true
        end)
        if not S.RecoveryStep()and not o.recoveryValidation and ns.WardenScheduler then job.scheduled=ns.WardenScheduler.Submit('conversation-recovery/'..tostring(S),'low',S.RecoveryStep)end
    end
    local function root(create)
        local db=S.root
        if not db and create then db={version=1,owners={},sessionSequence=0,nextMoment=0,nextMessage=0,bytes=0,moments=0};S.root=db;if o.saveRoot then o.saveRoot(db) end end
        if db and not SupportedRoot(db) then S.warnings.storage='UNSUPPORTED_ARCHIVE_PRESERVED';return end
        if not db then return end
        if not accounted then
            if not S.recovery then S.BeginRecovery(db)elseif S.recovery.state=='RECOVERING'and not S.recovery.scheduled and ns.WardenScheduler then S.recovery.scheduled=ns.WardenScheduler.Submit('conversation-recovery/'..tostring(S),'low',S.RecoveryStep)end
            if not accounted then return end
        end
        return db
    end
    local function row(key,create)
        local db=root(create);if not db then return end
        local r=db.owners[key]
        if not r and create then r={policy={enabled=false,scopes={},autoCandidates=false,autoPreserve=false,showDirectQuotes=false},moments={},messages={},order={},revisions={},revision=0};db.owners[key]=r;db.bytes=db.bytes+Bytes(r.policy)+256;indexes[r]={selection={},byUID={},sources={},activities={}};checked[r]=true end
        if r and (type(r)~='table' or type(r.policy)~='table' or type(r.policy.scopes)~='table' or type(r.moments)~='table' or type(r.messages)~='table' or type(r.order)~='table' or type(r.revisions)~='table' or type(r.revision)~='number' or #r.order>C.MAX_MOMENTS) then S.warnings.storage='UNSUPPORTED_OWNER_ARCHIVE_PRESERVED';return nil,db end

        return r,db
    end
    function S.Status(key)
        key=key or owner();if key~=owner() then return {state='OTHER_OWNER'} end
        local r,db=row(key);local state=not r and 'OFF' or not r.policy.enabled and 'OFF' or not permitted() and 'NO_HISTORY_CONSENT' or 'RECORDING'
        if S.warnings.storage then state=S.warnings.storage elseif S.warnings.capacity then state='CAPACITY_REACHED' end
        return {state=state,recovery=S.recovery and{state=S.recovery.state,processed=S.recovery.processed,maxSliceMS=S.recovery.maxSliceMS,cpuMS=S.recovery.cpuMS}or nil,policy=r and Copy(r.policy) or {enabled=false,scopes={},autoCandidates=false,autoPreserve=false,showDirectQuotes=false},
            archiveBytes=db and db.bytes or 0,capacityBytes=C.MAX_ARCHIVE_BYTES,moments=r and #r.order or 0,staging=#S.staging,candidates=#S.candidates,
            saveState=S.dirty and 'ACCEPTED_IN_MEMORY_PENDING_NORMAL_WOW_SAVE' or 'READ_FROM_SAVEDVARIABLES; DISK_DURABILITY_NOT_VERIFIED',
            metrics=Copy(S.metrics),warning=S.warnings.capacity or S.warnings.storage or S.warnings.preservation or S.warnings.native,ruleVersion=C.RULE_VERSION,epoch=S.epoch,revision=r and r.revision or 0,
            lastAccepted=r and r.order[#r.order] and r.moments[r.order[#r.order]] and r.moments[r.order[#r.order]].selectedAt}
    end
    function S.SetConsent(key,policy,confirmed)
        if not Text(key,256) or not key:match('/Player%-.+') or key~=owner() or not access() or confirmed~=true or type(policy)~='table' then return false,'EXPLICIT_OWNER_CONFIRMATION_REQUIRED' end
        local r=row(key,true);if not r then return false,'ARCHIVE_UNAVAILABLE' end
        local p={enabled=policy.enabled==true,scopes={},autoCandidates=policy.autoCandidates==true,autoPreserve=policy.autoPreserve==true,showDirectQuotes=policy.showDirectQuotes==true,
            version=1,at=clock(),source='EXPLICIT_OWNER_UI',owner=key}
        for scope in pairs(scopes) do p.scopes[scope]=type(policy.scopes)=='table' and policy.scopes[scope]==true or false end
        if p.enabled and not o.access and not o.recording then
            local ok,why=ns.Permissions.Resume('conversations',true);if not ok then return false,why end
        end
        local db=root();db.bytes=db.bytes+Bytes(p)-Bytes(r.policy)
        r.policy=p;r.revision=r.revision+1;S.epoch=S.epoch+1;S.staging={};S.stagingBytes=0;S.candidates={};S.candidateBytes=0;S.dirty=true;return true
    end
    function S.Context(consumer,key,options)
        if consumer~='chronicle' and consumer~='chat' and consumer~='command' then return nil,'CONSUMER_DENIED' end
        if key~=owner() or not access() then return nil,'OTHER_OWNER_OR_PERMISSION_DENIED' end
        local r=row(key);if not r then return nil,'OFF' end
        local ctx={};S.contexts[ctx]={owner=key,consumer=consumer,epoch=S.epoch,reveal=options and options.reveal==true};return ctx
    end
    local function context(ctx,text,scope)
        local c=S.contexts[ctx];if not c or c.owner~=owner() or c.epoch~=S.epoch or not (c.automatic and permitted()or access()) then return nil,'DENIED' end
        local r=row(c.owner);if not r then return nil,'DENIED' end
        if text and (c.consumer=='command' or not c.reveal or not r.policy.enabled or scope and not r.policy.scopes[scope]) then return nil,'REVEAL_AND_CHANNEL_CONSENT_REQUIRED' end
        return c,r
    end
    local function autoContext()
        local ctx={};S.contexts[ctx]={owner=owner(),consumer='chronicle',epoch=S.epoch,reveal=true,automatic=true};return ctx
    end
    local function candidate(e,reason)
        local r=row(owner());if not r or(not r.policy.autoCandidates and not r.policy.autoPreserve)or not C.DisplayEligible(e.displayState)then return end
        if e.channelKind=='publicChannels'then return end
        local item;for _,old in ipairs(S.candidates)do if old.messages[1].observationUID==e.observationUID then item=old;break end end
        if not item then
            item={ref='conversation-candidate/1/'..e.observationUID,owner=e.owner,selectedAt=clock(),messages={e},reason=reason,state='NEEDS_REVIEW',ruleVersion=C.RULE_VERSION}
            item.bytes=Bytes(item);if r.policy.autoCandidates then S.candidates[#S.candidates+1]=item;S.candidateBytes=S.candidateBytes+item.bytes end;S.metrics.candidates=S.metrics.candidates+1
        end
        local linked=e.context.eventAt and e.context.eventCategory and math.abs(e.observedAt-e.context.eventAt)<=90
        local direct=e.channelKind=='npcDialogue'and e.context.nativeSourceRef==e.observationUID
        if r.policy.autoPreserve and e.context.sourceRef and(linked or direct)then
            local ref,why=S.Pin({e.observationUID},autoContext(),'AUTO_PRESERVE')
            if ref then item.state='PRESERVED';item.momentRef=ref else S.warnings.preservation=why end
        end
        if r.policy.autoCandidates then local before=item.bytes;item.bytes=Bytes(item);S.candidateBytes=S.candidateBytes+item.bytes-before end
        return item
    end
    local function trim()
        local now=clock()
        while S.staging[1] and (now-S.staging[1].observedAt>C.STAGING_SECONDS or #S.staging>C.MAX_STAGING or S.stagingBytes>C.MAX_STAGING_BYTES) do local e=table.remove(S.staging,1);S.stagingBytes=S.stagingBytes-e.bytes;S.metrics.expired=S.metrics.expired+1 end
        while S.candidates[1] and (now-S.candidates[1].selectedAt>C.CANDIDATE_SECONDS or #S.candidates>C.MAX_CANDIDATES or S.candidateBytes>C.MAX_CANDIDATE_BYTES) do local e=table.remove(S.candidates,1);S.candidateBytes=S.candidateBytes-e.bytes;S.metrics.expired=S.metrics.expired+1 end
    end
    function S.Observe(input)
        S.metrics.seen=S.metrics.seen+1
        local key=owner();local r=row(key)
        if not r or not r.policy.enabled or not permitted() then return nil,'OFF_OR_NO_HISTORY_CONSENT' end
        if type(input)~='table' or not ns.Readable(input) then return nil,'RESTRICTED' end
        local event=Text(input.event,80);local scope=event and events[event]
        if not scope or not r.policy.scopes[scope] then return nil,'CHANNEL_NOT_AUTHORIZED' end
        local text=Text(input.text,8192);if not text or text=='' then return nil,'RESTRICTED_OR_EMPTY' end
        local displayState=Text(input.displayState,40)
        if not C.DisplayEligible(displayState)then S.metrics.rejected=S.metrics.rejected+1;return nil,'FILTERED_OR_DISPLAY_UNPROVEN'end;S.metrics.displayVerified=S.metrics.displayVerified+1
        if Text(input.importedFrom,40) then return nil,'BACKFILL_REQUIRES_SEPARATE_IMPORT_CONTRACT' end
        local replay=Text(input.observationUID,512)
        if replay then
            local original=r.messages[replay]
            if original and original.owner==key and original.deliveredEvent==event and original.text==Clip(text,C.MAX_TEXT) then return replay,'DUPLICATE_PRESERVED_OBSERVATION' end
            return nil,'UNRESOLVED_REPLAY_ID; ORIGINAL_NOT_REPLACED'
        end
        trim();local db=root(true)
        if not S.session then db.sessionSequence=(db.sessionSequence or 0)+1;S.session=db.sessionSequence end
        local line=Positive(input.lineID);local delivery=Text(input.deliveryUID,160)
        local duplicate=line and (S.session..'/'..event..'/'..line) or delivery and (S.session..'/'..event..'/'..delivery)
        if duplicate and S.seen[duplicate] then return S.seen[duplicate],'DUPLICATE' end
        S.sequence=S.sequence+1;local uid='conversation-observation/1/'..key..'/'..S.session..'/'..S.sequence
        local sender=Text(input.sender,128);local senderGUID=GUID(input.senderGUID)
        if not senderGUID and scope=='npcDialogue'then senderGUID=Text(input.senderGUID,128)end
        local outgoing=event=='CHAT_MSG_WHISPER_INFORM'
        local e={version=1,observationUID=uid,owner=key,observedAt=ns.SafeNumber(input.observedAt) or clock(),deliveredEvent=event,channelKind=scope,channelName=Text(input.channel,128),direction=outgoing and 'OUT' or 'IN',
            speaker={name=outgoing and Text(input.selfName,128) or sender,guid=outgoing and GUID(key:match('/(Player%-.+)$')) or senderGUID,confidence='NATIVE_DELIVERED; NAME_IS_NOT_GUID'},
            recipient=outgoing and {name=sender,guid=nil,confidence='NATIVE_RECIPIENT_NAME; GUID_UNKNOWN'} or nil,
            text=Clip(text,C.MAX_TEXT),textState=#text>C.MAX_TEXT and 'TRUNCATED' or 'AVAILABLE',originalByteLength=#text,eventLineID=line,deliveryUID=delivery,classification=input.classification,
            nativeReadability='READABLE',displayState=displayState,sourceModule='ATHENA_CONVERSATION_CHRONICLE',acquisitionConsent=Copy(r.policy),accessScope='OWNER_PRIVATE',
            context={activityRef=Text(input.activityRef,512),sourceRef=Text(input.sourceRef,512),sessionRef=Text(input.sessionRef,256),mapID=Positive(input.mapID),instanceID=Positive(input.instanceID),zone=Text(input.zone,128),questID=Positive(input.questID),eventCategory=Text(input.eventCategory,40),eventAt=ns.SafeNumber(input.eventAt),nativeSourceRef=Text(input.nativeSourceRef,512),contextStrength='EVENT_TIME_NATIVE; NO_ATTENDANCE_OR_OUTCOME_INFERENCE'}}
        e.bytes=Bytes(e);S.staging[#S.staging+1]=e;S.stagingBytes=S.stagingBytes+e.bytes
        if duplicate then S.seen[duplicate]=uid;S.seenOrder[#S.seenOrder+1]=duplicate;if #S.seenOrder>256 then S.seen[table.remove(S.seenOrder,1)]=nil end end
        trim()
        S.metrics.staged=S.metrics.staged+1
        if delivery then S.deliveries[delivery]=uid;S.deliveryOrder[#S.deliveryOrder+1]=delivery;if #S.deliveryOrder>256 then S.deliveries[table.remove(S.deliveryOrder,1)]=nil end end
        local linked=e.context.sourceRef~=nil and e.context.eventAt and math.abs(e.observedAt-e.context.eventAt)<=90
        local reason,normalized,method=C.Classify(e.text,linked)
        e.classification=reason;e.classificationMethod=method
        if scope=='npcDialogue'and input.directDialogue then reason='INTERACTED_NATIVE_DIALOGUE';e.context.sourceRef=e.context.sourceRef or uid;e.context.nativeSourceRef=uid end
        local oldBytes=e.bytes;e.bytes=Bytes(e);S.stagingBytes=S.stagingBytes+e.bytes-oldBytes
        if reason then candidate(e,reason)end
        trim()
        return uid,'STAGED_PRIVATE_NOT_PRESERVED'
    end
    function S.Pin(handles,ctx,selection)
        local c,r=context(ctx,true);if not c then return nil,r end
        if type(handles)=='string' then handles={handles} end
        if type(handles)~='table' or #handles<1 or #handles>C.MAX_MESSAGES then return nil,'SELECT_ONE_TO_EIGHT_ELIGIBLE_MESSAGES' end
        trim();local messages={};local seen={}
        for _,id in ipairs(handles) do
            if type(id)~='string' or seen[id] then return nil,'INVALID_OR_DUPLICATE_HANDLE' end;seen[id]=true
            local found=r.messages[id]
            for _,e in ipairs(S.staging) do if e.observationUID==id then found=e;break end end
            if not found then for _,candidate in ipairs(S.candidates) do for _,e in ipairs(candidate.messages) do if e.observationUID==id then found=e end end end end
            if not found or found.owner~=c.owner or not r.policy.scopes[found.channelKind]or not C.DisplayEligible(found.displayState) then return nil,'MESSAGE_EXPIRED_OR_NOT_AUTHORIZED' end
            messages[#messages+1]=found
        end
        table.sort(messages,function(a,b) return a.observedAt<b.observedAt or a.observedAt==b.observedAt and a.observationUID<b.observationUID end)
        local db=root();local ids={};for _,e in ipairs(messages) do ids[#ids+1]=e.observationUID end
        local ix=indexes[r];local selectionKey=Selection(ids);if ix.selection[selectionKey]then return ix.selection[selectionKey],'EXISTING_PRESERVED_SELECTION'end
        local ref='conversation-moment/1/'..c.owner..'/'..(db.nextMoment+1)
        local m={version=1,momentRef=ref,owner=c.owner,selectedAt=clock(),observedFrom=messages[1].observedAt,observedTo=messages[#messages].observedAt,
            selectedBy=selection=='AUTO_PRESERVE' and 'AUTO_PRESERVE' or 'USER_PIN',selectionRuleVersion=C.RULE_VERSION,selectionReasons={selection=='AUTO_PRESERVE'and'EVENT_LINKED_AUTHORIZED_TEXT'or'EXPLICIT_USER_PIN'},
            messageEvidenceRefs=ids,activityRelationRefs={},sourceRefs={},relationStrength='CONTEXTUAL',memoryState=selection=='AUTO_PRESERVE' and 'AUTO_SAVED' or 'PINNED',
            exportPolicy='OWNER_ONLY',protectedFromRoutineRingEviction=true,sourceCompleteness='ONLY_SELECTED_DELIVERED_LINES',private=true}
        local seenRefs={};local newBytes=0
        for _,e in ipairs(messages) do
            if not r.messages[e.observationUID] then newBytes=newBytes+Charge(e) end
            for _,field in ipairs({'activityRef','sourceRef'}) do local id=e.context[field];if id and not seenRefs[id] then seenRefs[id]=true;local list=field=='sourceRef' and m.sourceRefs or m.activityRelationRefs;list[#list+1]=id end end
        end
        newBytes=newBytes+Charge(m,256)
        if db.moments>=C.MAX_MOMENTS or db.bytes+newBytes>C.MAX_ARCHIVE_BYTES then S.warnings.capacity='ARCHIVE_LIMIT_REACHED; NO_NEW_MEMORY_SAVED';return nil,'CAPACITY_REACHED' end
        for _,e in ipairs(messages) do if not r.messages[e.observationUID] then r.messages[e.observationUID]=Copy(e) end end
        m.bytes=Charge(m,256);ix.selection[selectionKey]=ref;ix.sources[ref]={};ix.activities[ref]={}
        for _,id in ipairs(m.sourceRefs)do ix.sources[ref][id]=true end;for _,id in ipairs(m.activityRelationRefs)do ix.activities[ref][id]=true end
        for _,id in ipairs(ids)do local refs=ix.byUID[id]or{};ix.byUID[id]=refs;refs[#refs+1]=ref end
        r.moments[ref]=m;r.order[#r.order+1]=ref;db.nextMoment=db.nextMoment+1;db.moments=db.moments+1;db.bytes=db.bytes+newBytes
        r.revision=r.revision+1;S.revision=S.revision+1;S.dirty=true;S.warnings.capacity=nil;S.metrics.preserved=S.metrics.preserved+1;if #m.activityRelationRefs>0 or #m.sourceRefs>0 then S.metrics.linked=S.metrics.linked+1 end;return ref,'PRESERVED_IN_MEMORY_PENDING_NORMAL_WOW_SAVE'
    end
    function S.ResolveMoment(ref,ctx)
        local c,r=context(ctx,false);if not c then return nil,r end
        local m=r.moments[ref];if not m then return nil,'UNKNOWN' end
        local out=Copy(m);out.revision=Copy(r.revisions[ref] or {});out.texts=nil
        if c.consumer~='command' and c.reveal then
            local entries={};for _,id in ipairs(m.messageEvidenceRefs) do local e=r.messages[id];local valid=context(ctx,true,e and e.channelKind)
                if not valid or not e or not C.DisplayEligible(e.displayState)then return nil,'TEXT_NOT_AUTHORIZED_OR_UNAVAILABLE' end;entries[#entries+1]=Copy(e)
            end;out.texts=entries
        end
        return out
    end
    function S.ListMoments(key,window,cursor,options)
        local ctx=options and options.context;local c,r=context(ctx,false);if not c or c.owner~=key then return nil,'DENIED' end
        local first=type(cursor)=='number' and math.max(1,math.floor(cursor)) or 1;local out={};local last=math.min(#r.order,first+19)
        for i=first,last do local m=r.moments[r.order[i]];if m and (not window or m.observedTo>=window.firstAt and m.observedFrom<=window.lastAt) then out[#out+1]=S.ResolveMoment(m.momentRef,ctx) end end
        return out,last<#r.order and last+1 or nil
    end
    function S.Revise(ref,changes,ctx)
        local c,r=context(ctx,false);if not c or c.consumer=='command' or not r.moments[ref] or type(changes)~='table' then return false,'DENIED' end
        local old=r.revisions[ref] or {};local new={hideFromStory=old.hideFromStory==true,title=old.title,note=old.note,at=clock(),kind='OWNER_PRESENTATION_REVISION'}
        if changes.hideFromStory~=nil then new.hideFromStory=changes.hideFromStory==true end
        if changes.title~=nil then new.title=Text(changes.title,120) end
        if changes.note~=nil then new.note=Text(changes.note,1000) end
        local db=root();local priorLog=r.revisionLog and r.revisionLog[ref]or{};local log=Copy(priorLog)
        if #log==0 and r.revisions[ref]then log[#log+1]=Copy(r.revisions[ref])end
        log[#log+1]=Copy(new)
        local delta=Bytes(new)-(r.revisions[ref]and Bytes(r.revisions[ref])or 0)+Bytes(log)-(#priorLog>0 and Bytes(priorLog)or 0)
        if db.bytes+delta>C.MAX_ARCHIVE_BYTES then return false,'CAPACITY_REACHED'end
        r.revisionLog=r.revisionLog or{};r.revisionLog[ref]=log;r.revisions[ref]=new;db.bytes=db.bytes+delta
        r.revision=r.revision+1;S.epoch=S.epoch+1;S.dirty=true;return true
    end
    function S.Delete(ref,ctx,confirmed)
        local c,r=context(ctx,false);if not c or c.consumer=='command' or not confirmed or not r.moments[ref] then return false,'EXPLICIT_OWNER_CONFIRMATION_REQUIRED' end
        if ns.FiresideSavedData then ns.FiresideSavedData.PurgeRecovery()end
        local db=root();local m=r.moments[ref];r.moments[ref]=nil;r.revisions[ref]=nil;if r.revisionLog then r.revisionLog[ref]=nil end
        for i,id in ipairs(r.order) do if id==ref then table.remove(r.order,i);break end end
        local used={};for _,id in ipairs(r.order) do for _,e in ipairs(r.moments[id].messageEvidenceRefs) do used[e]=true end end
        for id in pairs(r.messages) do if not used[id] then r.messages[id]=nil end end
        -- Explicit deletion may recount the bounded private archive. Never
        -- undercount shared message bodies when two moments reference one line.
        accounted=nil;S.recovery=nil;checked[r]=nil;indexes[r]=nil;S.BeginRecovery(db)
        r.revision=r.revision+1;S.epoch=S.epoch+1;S.dirty=true;S.warnings.capacity=nil;return true
    end
    function S.Staged(ctx)
        local c,r=context(ctx,true);if not c then return nil,r end;trim();local out={}
        for i=#S.staging,1,-1 do local e=S.staging[i];if e.owner==c.owner and r.policy.scopes[e.channelKind]and C.DisplayEligible(e.displayState)then out[#out+1]=Copy(e) end end;return out
    end
    function S.Candidates(ctx)
        local c,r=context(ctx,true);if not c then return nil,r end;trim();local out={}
        for _,v in ipairs(S.candidates) do if v.owner==c.owner then out[#out+1]={ref=v.ref,state=v.state,reason=v.reason,selectedAt=v.selectedAt,messageEvidenceRefs={v.messages[1].observationUID}} end end;return out
    end
    function S.ResolveCandidate(ref,ctx)
        local c,r=context(ctx,true);if not c then return nil,r end;trim()
        for _,candidate in ipairs(S.candidates) do if candidate.ref==ref and candidate.owner==c.owner then
            local out=Copy(candidate)
            for _,e in ipairs(out.messages) do if not r.policy.scopes[e.channelKind]or not C.DisplayEligible(e.displayState)then return nil,'CHANNEL_OR_DISPLAY_NOT_AUTHORIZED' end end
            return out
        end end
        return nil,'SOURCE_EXPIRED'
    end
    function S.DiscardCandidate(ref,ctx)
        local c=context(ctx,false);if not c then return false end
        for i,v in ipairs(S.candidates) do if v.ref==ref and v.owner==c.owner then S.candidateBytes=S.candidateBytes-v.bytes;table.remove(S.candidates,i);return true end end
        return false
    end
    function S.PumpLinks()
        if not permitted()then S.linkQueue={};S.linkKeys={};return true end
        local r,db=row(owner());if not r or not r.policy.enabled then S.linkQueue={};S.linkKeys={};return true end
        local ix=indexes[r]
        for _=1,64 do local task=table.remove(S.linkQueue,1);if not task then break end;S.linkKeys[task.key]=nil
            local m=r.moments[task.ref]
            if m and not ix.sources[task.ref][task.source]and #m.sourceRefs<16 then
                local changed=Copy(m);changed.sourceRefs[#changed.sourceRefs+1]=task.source
                if task.activity and not ix.activities[task.ref][task.activity]then changed.activityRelationRefs[#changed.activityRelationRefs+1]=task.activity end
                local delta=Charge(changed,256)-Charge(m,256)
                if db.bytes+delta<=C.MAX_ARCHIVE_BYTES then
                    m.sourceRefs=changed.sourceRefs;m.activityRelationRefs=changed.activityRelationRefs;m.bytes=Charge(m,256)
                    ix.sources[task.ref][task.source]=true;if task.activity then ix.activities[task.ref][task.activity]=true end
                    db.bytes=db.bytes+delta;r.revision=r.revision+1;S.dirty=true
                else S.warnings.capacity='ARCHIVE_LIMIT_REACHED; DERIVED_LINK_HELD; ORIGINALS_RETAINED'end
            end
        end
        return #S.linkQueue==0
    end
    function S.Trigger(event,link)
        if not permitted()then return end;local r=row(owner());if not r or not r.policy.enabled then return end
        local ix=indexes[r];trim()
        for _,e in ipairs(S.staging)do local c=e.context;local loc=event.location or{}
            local compatible=e.owner==owner()and c.sessionRef==event.session and math.abs(event.at-e.observedAt)<=30
                and(not c.instanceID or not loc.instanceID or c.instanceID==loc.instanceID)
                and(not c.zone or not loc.zone or c.zone==loc.zone)
                and(not c.questID or c.questID==(event.details or{}).questID)
            if compatible and C.DisplayEligible(e.displayState)then
                c.sourceRef=link.sourceRef;c.activityRef=link.activityRef;c.eventAt=event.at;c.eventCategory=link.eventCategory
                local priorBytes=e.bytes;e.bytes=Bytes(e);S.stagingBytes=S.stagingBytes+e.bytes-priorBytes
                for _,ref in ipairs(ix.byUID[e.observationUID]or{})do
                    local key=ref..'/'..tostring(link.sourceRef)
                    if link.sourceRef and not ix.sources[ref][link.sourceRef]and not S.linkKeys[key]then
                        if #S.linkQueue<C.MAX_MOMENTS then S.linkKeys[key]=true;S.linkQueue[#S.linkQueue+1]={ref=ref,source=link.sourceRef,activity=link.activityRef,key=key}
                        else S.warnings.preservation='DERIVED_LINK_QUEUE_FULL; ORIGINALS_RETAINED'end
                    end
                end
                local reason,_,method=C.Classify(e.text,true);if reason then e.classification=reason;e.classificationMethod=method;candidate(e,reason)end
            end
        end
        if not S.PumpLinks()and ns.WardenScheduler then
            ns.WardenScheduler.Submit('conversation-links/'..tostring(owner():match('Player%-.+')or'owner'),'low',S.PumpLinks)
        end
        trim()
    end
    function S.DisplayChanged(delivery,action)
        if C.DisplayEligible(action)then return end
        local uid=S.deliveries[delivery];if not uid then return end;local r=row(owner());local changed=false
        for _,e in ipairs(S.staging)do if e.observationUID==uid then e.displayState=action;changed=true end end
        if r and r.messages[uid]then local message=r.messages[uid];local before=Charge(message);message.displayState=action;local db=root();db.bytes=db.bytes+Charge(message)-before;r.revision=r.revision+1;S.dirty=true;changed=true end
        if changed then S.warnings.native='DISPLAY_OUTCOME_RESTRICTED; MEMORY_EXCLUDED_FROM_STORY';S.epoch=S.epoch+1 end
    end
    function S.Boundary()
        -- Qualified candidates were promoted synchronously on the source event.
        -- Never auto-save unrelated temporary chat at a zone/logout boundary.
        S.epoch=S.epoch+1;S.staging={};S.stagingBytes=0;S.candidates={};S.candidateBytes=0;S.seen={};S.seenOrder={};S.session=nil end
    function S.ForStory(story,ctx,options)
        local c,r=context(ctx,false);if not c or c.owner~=story.observerOwner or not r.policy.enabled then return {} end
        local refs={};for _,ref in ipairs(story.sourceEvidenceRefs or {}) do refs[ref]=true end
        local activities={};for _,ref in ipairs(story.sourceActivityRefs or {}) do activities[ref]=true end
        local out={}
        for i,ref in ipairs(r.order) do
            local m=r.moments[ref];local revision=r.revisions[ref];local matched=false;local eligible=true
            for _,id in ipairs(m.messageEvidenceRefs) do local e=r.messages[id];if not e or not r.policy.scopes[e.channelKind]or not C.DisplayEligible(e.displayState)then eligible=false end end
            if eligible and not (revision and revision.hideFromStory) and m.observedTo>=story.firstObservedAt-30 and m.observedFrom<=story.lastObservedAt+45 then
                for _,source in ipairs(m.sourceRefs) do if refs[source] or options and options.evidenceRefs and options.evidenceRefs[source] then matched=true end end
                for _,activity in ipairs(m.activityRelationRefs) do if activities[activity] then matched=true end end
            end
            if matched then
                local entry={momentRef=m.momentRef,owner=m.owner,sessionRef=r.messages[m.messageEvidenceRefs[1]].context.sessionRef,observedAt=m.observedFrom,observedFrom=m.observedFrom,observedTo=m.observedTo,activityRelationRefs=Copy(m.activityRelationRefs),sourceRefs=Copy(m.sourceRefs),relationStrength=m.relationStrength,
                    selectedBy=m.selectedBy,channelKind=r.messages[m.messageEvidenceRefs[1]].channelKind,private=true}
                if r.policy.showDirectQuotes then local revealed=S.ResolveMoment(m.momentRef,S.Context('chronicle',c.owner,{reveal=true}));entry.inlineTexts=revealed and revealed.texts end
                out[#out+1]=entry
            end
            if #out>=8 then break end
            if i%128==0 and coroutine.running() then coroutine.yield() end
        end
        return out
    end
    function S.Signature(key)
        if key~=owner() then return 'DENIED_OWNER' end
        local r=row(key);return tostring(S.epoch)..'/'..tostring(r and r.revision or 0)..'/'..tostring(access())
    end
    function S.ExportOwner(ctx,confirmed)
        local c,r=context(ctx,true);if not c or c.consumer=='command' or not confirmed then return nil,'EXPLICIT_OWNER_LOCAL_EXPORT_CONFIRMATION_REQUIRED' end
        local out={format='ATHENA_PRIVATE_CONVERSATIONS',version=1,owner=c.owner,moments={},messages={},revisions={},revisionLog={},privacy='OWNER_PRIVATE; NEVER_SEND_VIA_RELAY_OR_GUILD'}
        for _,ref in ipairs(r.order) do local m=S.ResolveMoment(ref,ctx)
            if not m or not m.texts then return nil,'RETAINED_SCOPE_NOT_AUTHORIZED_FOR_EXPORT' end
            m.texts=nil;out.moments[#out.moments+1]=m
            for _,id in ipairs(m.messageEvidenceRefs) do out.messages[id]=Copy(r.messages[id]) end
            out.revisions[ref]=Copy(r.revisions[ref])
            out.revisionLog[ref]=Copy(r.revisionLog and r.revisionLog[ref])
        end
        return out
    end
    return S
end
-- Exercise the normal owner/message/selection validator on a private header.
-- Its accounting migration must not alter the checkpoint or the live store,
-- and a recovery dry-run must never enqueue work in the live scheduler.
function C.ValidateSaved(db)
    assert(SupportedRoot(db),'Unsupported conversation checkpoint')
    local header={};for k,v in pairs(db)do header[k]=v end
    local private=C.NewStore({root=header,recoveryValidation=true})
    private.BeginRecovery(header)
    while private.recovery.state=='RECOVERING'do private.RecoveryStep()end
    assert(private.recovery.state=='READY','Invalid conversation checkpoint: '..tostring(private.recovery.reason))
    return true
end
local store
function C.ResetRuntime()if store then store.Boundary('privacy');if ns.WardenScheduler then ns.WardenScheduler.Cancel('conversation-recovery/'..tostring(store))end;if store.recovery then store.recovery.state='PRIVACY_ERASED';store.recovery.thread=nil end;store=nil end end
function C.Store()
    if not store then store=C.NewStore({root=ns.Storage.OlympusWardenConversationDB,saveRoot=function(db) ns.Storage.OlympusWardenConversationDB=db end}) end
    return store
end
for _,name in ipairs({'Status','SetConsent','Context','Observe','Pin','ResolveMoment','ListMoments','Revise','Delete','Staged','Candidates','ResolveCandidate','DiscardCandidate','Boundary','Trigger','PumpLinks','DisplayChanged','ForStory','Signature','ExportOwner'}) do local method=name;C[method]=function(...) return C.Store()[method](...) end end
