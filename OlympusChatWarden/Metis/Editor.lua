-- Final source and repetition checks apply to every Metis manuscript.
local _,ns=...
local E={VERSION=3};ns.Metis.Editor=E
local function Signature(row)
    local refs={};for _,id in ipairs(row.claimIds or {}) do refs[#refs+1]=id end;table.sort(refs)
    local worlds={};for _,id in ipairs(row.worldRefs or {}) do worlds[#worlds+1]=id end;table.sort(worlds)
    return table.concat(refs,'/')..'|'..table.concat(worlds,'/')..'|'..(row.text or '')
end
function E.Review(plan,blocks)
    ns.Metis.Check(plan.index)
    local known,refs,worlds={},{},{};local report={version=E.VERSION,checked=0,duplicatesRemoved=0,semanticDuplicatesRemoved=0,omittedClauses={},primary={},status='READY'}
    for _,s in ipairs(plan.episodes or {}) do for _,c in ipairs(s.factualClaims or {}) do
        known[c.claimId]=c;for _,r in ipairs(c.evidenceRefs or {}) do refs[r]=true end
        for _,r in ipairs(c.worldRefs or {}) do worlds[r]=true end
    end end
    local identity=plan.index and plan.index.ownerIdentity;if identity and identity.evidenceRef then refs[identity.evidenceRef]=true end
    for _,scene in ipairs(plan.novelScenes or {}) do local c=scene.placeClaim
        if c then local valid=#c.evidenceRefs>0
            for _,r in ipairs(c.evidenceRefs) do if not refs[r] then valid=false end end
            if valid then known[c.claimId]=true end
        end
    end
    local out,seen,meanings={},{},{}
    local contextSeen={};report.languageNotes={};report.repeatedContextRemoved=0;report.storycraftVersion=ns.Metis.Calliope.VERSION
    for _,b in ipairs(blocks) do
        assert(type(b.text)=='string' and type(b.evidenceRefs)=='table','METIS_INVALID_BLOCK')
        if ns.Metis.Voice()=='Natural Fantasy' then assert(type(b.clauses)=='table' and #b.clauses>0,'METIS_UNSUPPORTED_SENTENCE')
        else assert(#b.evidenceRefs+#(b.worldRefs or {})>0,'METIS_UNSUPPORTED_SENTENCE') end
        for _,r in ipairs(b.evidenceRefs) do assert(refs[r],'METIS_UNSUPPORTED_SOURCE') end
        for _,id in ipairs(b.claimIds or {}) do assert(known[id],'METIS_UNSUPPORTED_CLAIM') end
        for _,fact in ipairs(b.worldFacts or {}) do if fact.worldRef then worlds[fact.worldRef]=true end;if fact.questWorldRef then worlds[fact.questWorldRef]=true end end
        for _,c in ipairs(b.clauses or {}) do
            assert(#c.sourceRefs+#c.worldRefs>0,'METIS_UNSUPPORTED_SENTENCE')
            for _,r in ipairs(c.sourceRefs) do assert(refs[r],'METIS_UNSUPPORTED_SOURCE') end
            for _,r in ipairs(c.worldRefs) do assert(worlds[r],'METIS_UNSUPPORTED_LORE') end
        end
        -- Compare the meaning of generic objective-status clauses, independent
        -- of their words and evidence IDs. Distinct outcomes, accepted work,
        -- combat, quoted memories and other concrete deeds never share this key.
        if ns.Metis.Voice()=='Natural Fantasy' then
            local kept,texts={},{}
            for _,c in ipairs(b.clauses) do
                local subject,progress,other=nil,false,false
                for _,id in ipairs(c.claimIds) do local claim=known[id]
                    if type(claim)=='table' and claim.claimType=='owner_quest_objective' then
                        local row=plan.index and plan.index.narrative and plan.index.narrative.byRef[claim.evidenceRefs[1]]
                        local key=row and row.occurrenceId or tostring(claim.value.questID)
                        if subject and subject~=key then other=true end;subject=key;progress=true
                    else other=true end
                end
                local key=progress and not other and 'quest-progress/'..subject
                local contextOnly=#c.claimIds==0 and #c.worldRefs>0
                local contextKey=contextOnly and c.text
                if contextKey and contextSeen[contextKey] then
                    report.repeatedContextRemoved=report.repeatedContextRemoved+1
                    report.omittedClauses[#report.omittedClauses+1]={reason='REPEATED_SOURCE_CONTEXT',worldRefs=c.worldRefs}
                elseif key and meanings[key] then
                    report.semanticDuplicatesRemoved=report.semanticDuplicatesRemoved+1
                    report.omittedClauses[#report.omittedClauses+1]={reason='REPEATED_QUEST_STATUS',claimIds=c.claimIds,sourceRefs=c.sourceRefs}
                else
                    if key then meanings[key]=true end;if contextKey then contextSeen[contextKey]=true end
                    if c.recipeId then assert(#ns.Metis.Calliope.Language(c.text)==0,'CALLIOPE_INVALID_PROSE') end
                    for _,note in ipairs(ns.Metis.Calliope.Language(c.text)) do report.languageNotes[#report.languageNotes+1]={reason=note,blockId=b.blockId} end
                    kept[#kept+1]=c;texts[#texts+1]=c.text
                end
            end
            b.clauses=kept;b.text=table.concat(texts,' ')
        end
        local key=Signature(b)
        if b.text~='' and not seen[key] then
            seen[key]=true;out[#out+1]=b
            for _,id in ipairs(b.developmentIds or {}) do assert(not report.primary[id] or report.primary[id]==b.sceneId,'METIS_DUPLICATE_DEVELOPMENT');report.primary[id]=b.sceneId end
        else report.duplicatesRemoved=report.duplicatesRemoved+1 end
        report.checked=report.checked+1
    end
    plan.metisEditorial=report;return out
end
