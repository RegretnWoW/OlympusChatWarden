-- Shared subject projection of the existing, stage-qualified Quest Codex.
-- Source text remains authoritative; missing fields never acquire a story.
local _,ns=...
local Q={VERSION='quest-subjects-1.3'};ns.AthenaQuestSubjects=Q
local function Clean(v)
    if not ns.CanRead(v) then return end
    v=v:gsub('%s+',' '):match('^%s*(.-)%s*$')
    if v=='' or v:find('[<>|]') then return end
    return v
end
function Q.Build(ref)
    local p=Clean(ref and ref.premise);if not p then return end
    -- Several source objectives name the petitioner before the instruction.
    -- Preserve that explicit instruction without inferring a motive or deed.
    p=p:match('^.- wants you to (.+)$') or p:match('^.- asks you to (.+)$') or p
    p=p:gsub('^%l',string.upper)
    local remainder=p:match('^.-[%.!?]%s+(.+)$')
    p=(p:match('^(.-[%.!?])%s') or p):gsub('[%.%s]+$','')
    local verb,body=p:match('^(%a+)%s+(.+)$');if not verb then return end
    local q={version=Q.VERSION,questID=ref.questID or ref.id,sourceRef=ref.worldRef,sourceURL=ref.sourceURL,
        giver=Clean(ref.giverName),objective=p,kind='UNKNOWN',subject='UNKNOWN',recipient='UNKNOWN',location='UNKNOWN',
        role='Quest-source context; never proof of personal action',minimumStage=2}
    if ({Bring=true,Deliver=true,Take=true})[verb] then
        q.subject,q.recipient=body:match('^(.-) to (.+)$');q.kind=q.subject and 'DELIVERY' or 'UNKNOWN'
    elseif verb=='Find' then
        -- Finding a named contact is not recovering an object. Only an exact
        -- source finisher identifies a person; ambiguous Find stays an inquiry.
        local finisher=Clean(ref.finisherName)
        local tail=finisher and body:sub(#finisher+1) or '';local where=tail:match('^%s+(%a+)')
        if finisher and body:sub(1,#finisher)==finisher and (tail=='' or ({at=true,['in']=true,near=true,on=true,outside=true,inside=true})[where]) then
            q.recipient=body;q.subject=body;q.kind='CONTACT'
        else q.subject=body;q.kind='INVESTIGATION' end
    elseif ({Retrieve=true,Recover=true,Collect=true,Gather=true,Obtain=true,Acquire=true})[verb] then
        -- A recovery followed by another action is not one noun phrase.
        -- Leave it to the source-backed compound/mandate renderer rather than
        -- producing "recovered the bauble and take it ..." as a completed deed.
        for _,action in ipairs({'bring','take','give','show','deliver','use','speak','report'}) do
            if body:lower():find(' and '..action..'%f[%A]') then return end
        end
        local objective,recipient=body:match('^(.-) and [Rr]eturn .- to (.+)$')
        if not objective then objective,recipient=body:match('^(.-) for (.+)$') end
        objective=objective or body;q.recipient=recipient or q.giver or 'UNKNOWN'
        q.subject,q.origin=objective:match('^(.-) from (.+)$');q.subject=q.subject or objective;q.kind='RECOVERY'
        -- An explicit follow-up delivery can identify the intended recipient.
        -- It does not identify a quest giver or prove a completed delivery.
        local destination=remainder and remainder:match('^[Bb]ring .- to (.+)')
        if destination then q.recipient=destination:gsub('[%.%s]+$','') end
    elseif ({Kill=true,Slay=true,Defeat=true,Destroy=true})[verb] then
        q.subject=(body:match('^(.-),?%s+then%s+') or body):gsub('[,%s]+$','');q.kind='CONFLICT'
        -- Compound objectives remain intact; do not guess which action a
        -- conjunction describes or turn quest credit into a killing blow.
        if q.subject:find(' and ',1,true) then
            q.kind='COMPOUND'
            q.target,q.delivery,q.destination=q.subject:match('^(.-) and [Bb]ring (.-) to (.+)$')
            if q.target and q.delivery=='his head' then q.delivery=q.target..'’s head' end
        end
    elseif ({Speak=true,Talk=true,Report=true,Meet=true})[verb] then
        q.recipient=body:gsub('^with ',''):gsub('^to ',''):gsub('^back to ','');q.subject=q.recipient;q.kind='CONTACT'
    elseif ({Investigate=true,Explore=true,Search=true,Escort=true,Use=true,Travel=true})[verb] then
        q.subject=body;q.kind='INVESTIGATION'
    end
    q.subject=Clean(q.subject) or 'UNKNOWN';q.recipient=Clean(q.recipient) or 'UNKNOWN'
    -- Locale-specific prose is never fabricated from an unknown verb.
    if q.kind=='UNKNOWN' or q.subject=='UNKNOWN' then return end
    return q
end
