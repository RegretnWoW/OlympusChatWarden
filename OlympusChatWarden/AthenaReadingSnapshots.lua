-- Completed presentation copies only. Canonical evidence remains in Chronicle.
local _,ns=...
local R={VERSION=1,MAX_BYTES=2097152,PAGE_BYTES=262144,MAX_PAGES=32};ns.AthenaReadingSnapshots=R
local function Root()
    if ns.Storage.OlympusWardenJournalDB==nil then ns.Storage.OlympusWardenJournalDB={version=R.VERSION,pages={},clock=0} end
    local r=ns.Storage.OlympusWardenJournalDB
    if type(r)~='table' or getmetatable(r) or r.version~=R.VERSION or type(r.pages)~='table' or type(r.clock)~='number' then R.error='Unsupported saved book retained';return end
    return r
end
local function Hash(text)
    local n=5381;for i=1,#text do n=(n*33+text:byte(i))%2147483647 end;return tostring(n)
end
local function Text(s,max) return type(s)=='string' and #s<=(max or 4096) and s or nil end
local packedFirst=setmetatable({},{__mode='k'})
function R.Lineage(owner,history)
    local S=ns.ChronicleStore
    local root=history or S.db or ns.DB and ns.DB.chronicle
    local c=root and root.characters and root.characters[owner]
    if type(c)~='table' then return end
    local first=c.events and c.events[1]
    if not first and c.storageFormat==1 and c.eventChunks and c.eventChunks[1] then
        -- Read only one bounded chunk, not the archive, before validation.
        local cached=packedFirst[c]
        if cached and cached.chunk==c.eventChunks[1] then first=cached.first
        else local rows=ns.ChronicleBackup.DecodeChunk(c.eventChunks[1]);first=rows and rows[1];packedFirst[c]={chunk=c.eventChunks[1],first=first} end
    end
    if type(first)~='table' or not Text(first.id) or first.character~=owner or type(first.at)~='number' then return end
    return owner..'/'..Hash(first.id..'/'..tostring(first.at)..'/'..tostring(first.kind))
end
function R.Scope(owner)
    local d=ns.DB or {};local service=ns.AthenaConversations
    -- Private incident clauses never enter this cache. Use stable permission
    -- flags; the runtime incident replay counter is not a login identity.
    local status=service and service.Status and service.Status(owner)
    local memory=status and (tostring(status.revision)..'/'..ns.Reports.JSON(status.policy or {})) or 'NO_CONVERSATIONS'
    local env=ns.AthenaWorldKnowledge.Environment()
    local permission=ns.AthenaStoryContributions.PermissionSignature():gsub('/[^/]*$','')
    return table.concat({permission,memory,tostring(env.locale),tostring(env.build),
        tostring(d.journalNarration or 'Natural Fantasy'),tostring(d.journalLore~=false),tostring(d.journalPrologueHidden==true)},'|')
end
local function Blocks(input)
    if type(input)~='table' or #input==0 or #input>600 or getmetatable(input) then return end
    local out,bytes={},0
    for i,b in ipairs(input) do
        if type(b)~='table' or getmetatable(b) or not Text(b.text,32768) then return end
        -- Explicitly revealed text is never copied into a presentation cache.
        if not b.recollection and (b.literal or b.ownerPrivate and not Text(b.snapshotText,32768)) then return end
        local kind=b.kind or 'body'
        if not ({body=true,title=true,heading=true,meta=true,quote=true})[kind] then return end
        local row={id=Text(b.id),text=b.recollection and 'A private recollection accompanies this moment. Open the updated book to read it.' or b.privateMemory and 'A private memory accompanies this chapter. Its folio is available in the updated book.' or b.ownerPrivate and b.snapshotText or b.text,kind=kind,tone=b.tone=='meta' and 'meta' or nil}
        bytes=bytes+#row.text+#(row.id or '')+64;if bytes>R.PAGE_BYTES then return end
        out[i]=row
    end
    return out,bytes
end
local function Seal(blocks)
    local out={};for _,b in ipairs(blocks) do out[#out+1]=(b.id or '')..'\030'..b.kind..'\030'..b.text end
    return Hash(table.concat(out,'\031'))
end
-- Recovery qualification uses the same block cleaner and seal as reading.
-- It does not consult or alter the live book, cache, permissions or history.
function R.ValidateSaved(root,history)
    local S=ns.ChronicleStore
    assert(type(root)=='table' and not getmetatable(root) and root.version==R.VERSION and type(root.pages)=='table' and not getmetatable(root.pages),'Invalid saved reading root')
    assert(S.Integer(root.clock,0,1000000000),'Invalid saved reading clock')
    for k in pairs(root)do assert(k=='version'or k=='pages'or k=='clock'or k=='editions','Unsupported saved reading field')end
    local E=ns.AthenaLibraryEditions;assert(E,'Saved-edition validator unavailable')
    local valid,reserved=E.Validate(root.editions);assert(valid,'Saved editions did not validate')
    local total,count=reserved,0
    for key,row in pairs(root.pages)do
        assert(type(key)=='string' and #key<=4096 and type(row)=='table' and not getmetatable(row),'Invalid saved reading page')
        local lineage=R.Lineage(row.owner,history);local c=history and history.characters[row.owner]
        assert(lineage and row.lineage==lineage and c,'Saved reading lineage needs recovery')
        assert(Text(row.scope,32768)and Text(row.threadId,4096)and Text(row.volumeId,4096)and Text(row.collection,144),'Invalid saved reading identity')
        assert(key==lineage..'/'..tostring(row.threadId)..'/'..tostring(row.volumeId)..'/'..tostring(row.length),'Saved reading key mismatch')
        assert(S.Integer(row.used,0,root.clock)and(row.sequence==nil or S.Integer(row.sequence,0,c.sequence)),'Saved reading sequence needs recovery')
        assert(S.Array(row.blocks,600),'Invalid saved reading block array')
        local blocks,bytes=Blocks(row.blocks)
        assert(blocks and S.Preserved(row.blocks,blocks)and row.bytes==bytes and row.seal==Seal(blocks),'Saved reading content checksum failed')
        total=total+bytes;count=count+1
    end
    assert(total<=R.MAX_BYTES and count<=R.MAX_PAGES,'Saved reading archive exceeds supported bounds')
    return true
end
function R.Clear(owner)
    local r=Root();if not r then return false,R.error end;if not owner then r.pages={};return end
    for k,p in pairs(r.pages) do if type(p)~='table' or p.owner==owner then r.pages[k]=nil end end
end
function R.Save(p,blocks)
    if p.preservedEdition then return end
    if not p.provider or p.provider.demo or not p.provider:Allowed() or not p.job or not p.job.done or p.job.status~='READY' or not p.rendered then return end
    local lineage,scope=R.Lineage(p.owner),R.Scope(p.owner)
    local clean,bytes=Blocks(blocks);if not lineage or not scope or not clean then return end
    local key=lineage..'/'..tostring(p.threadId)..'/'..tostring(p.volumeId)..'/'..tostring(p.length)
    local r=Root();if not r then return false,R.error end
    local reserved=ns.AthenaLibraryEditions and ns.AthenaLibraryEditions.ReservedBytes() or 0
    if not reserved or reserved+bytes>R.MAX_BYTES then return false,'Private saved editions retain their reserved space.' end
    r.clock=r.clock+1
    -- Publish only after the complete candidate passes every bound. No pending
    -- page is written to SavedVariables; interruption leaves the old copy intact.
    r.pages[key]={owner=p.owner,lineage=lineage,scope=scope,blocks=clean,bytes=bytes,seal=Seal(clean),used=r.clock,
        threadId=p.threadId,volumeId=p.volumeId,collection=p.collection,length=p.length,revision=p.identity and p.identity.revision,
        narrator=ns.AthenaLiteraryAuthor.VERSION,edition=ns.DB.journalEditions and ns.DB.journalEditions[p.owner] or 0,sequence=ns.ChronicleStore.db and ns.ChronicleStore.db.characters[p.owner] and ns.ChronicleStore.db.characters[p.owner].sequence}
    local total,count=reserved,0
    for k,row in pairs(r.pages) do
        if type(row)~='table' or type(row.bytes)~='number' then r.pages[k]=nil
        else total=total+row.bytes;count=count+1 end
    end
    while total>R.MAX_BYTES or count>R.MAX_PAGES do
        local oldest,age
        for k,row in pairs(r.pages) do if not age or (tonumber(row.used) or 0)<age then oldest=k;age=tonumber(row.used) or 0 end end
        if not oldest then break end
        total=total-r.pages[oldest].bytes;count=count-1;r.pages[oldest]=nil
    end
    return true
end
function R.Restore(p,collection)
    if not p.provider or p.provider.demo or not p.provider:Allowed() or p.shelf=='lore' or p.shelf=='memories' then return end
    collection=collection or p.collection or 'life'
    local lineage,scope=R.Lineage(p.owner),R.Scope(p.owner);if not lineage or not scope then return end
    local r=Root();if not r then return end;local best
    local root=ns.ChronicleStore.db or ns.DB.chronicle;local character=root and root.characters and root.characters[p.owner]
    local saved=ns.DB.journalReadingPlaces and ns.DB.journalReadingPlaces[p.owner]
    for k,row in pairs(r.pages) do if type(row)=='table' and row.owner==p.owner and row.lineage==lineage and row.scope==scope and row.collection==collection then
        local blocks=Blocks(row.blocks)
        if not blocks or row.seal~=Seal(blocks) then r.pages[k]=nil
        elseif type(row.sequence)=='number' and (not character or (tonumber(character.sequence) or 0)<row.sequence) then -- Restored older archive: do not resurrect its future pages.
        elseif not best or saved and saved.volumeId==row.volumeId and saved.volumeId~=best.volumeId or (not saved or saved.volumeId~=best.volumeId) and (tonumber(row.used) or 0)>(tonumber(best.used) or 0) then best=row end
    end end
    if not best then return end
    p.savedReading={lineage=lineage,scope=scope,threadId=best.threadId,volumeId=best.volumeId,collection=best.collection}
    p.collectionState=p.collectionState or {};p.collectionState[collection]={threadId=best.threadId,volumeId=best.volumeId,offset=0}
    p.document:SetBlocks(best.blocks);p.scroll:Show();p.sourceRail:Hide();p.evidence:SetEnabled(false);p.previous:SetEnabled(false);p.next:SetEnabled(false)
    if saved then p.document:RestoreReadingAnchor(saved.anchor);p.scroll:SetVerticalScroll(saved.offset or 0) end
    p.pageProgress:SetText('Saved reading copy • preparing an update')
    return true
end
function R.Valid(p)
    return p.savedReading and p.provider and p.provider:Allowed() and p.savedReading.scope==R.Scope(p.owner) and p.savedReading.lineage==R.Lineage(p.owner)
end
-- Installing new prose recipes alone must not rewrite a completed telling.
-- New evidence or the existing explicit Regenerate action permits an update.
function R.EditionBlocks(p,candidate)
    p.preservedEdition=nil
    if not p.provider or p.provider.demo or not p.provider:Allowed() then return candidate end
    local lineage,scope=R.Lineage(p.owner),R.Scope(p.owner)
    local c=ns.ChronicleStore.db and ns.ChronicleStore.db.characters[p.owner]
    local edition=ns.DB.journalEditions and ns.DB.journalEditions[p.owner] or 0
    for _,row in pairs((Root() or {}).pages or {}) do
        if type(row)=='table' and row.owner==p.owner and row.lineage==lineage and row.scope==scope
            and row.threadId==p.threadId and row.volumeId==p.volumeId and row.length==p.length
            and row.narrator~=ns.AthenaLiteraryAuthor.VERSION and c and type(row.sequence)=='number' and row.sequence==c.sequence then
            if row.edition==nil then row.edition=edition end -- one-time legacy presentation metadata
            local clean=Blocks(row.blocks)
            if row.edition==edition and clean and row.seal==Seal(clean) then p.preservedEdition=true;return clean end
        end
    end
    return candidate
end

-- Existing saved manuscripts remain accessible as individually selected folios.
function R.ListCopies(p)
 local out={};if not p.provider or p.provider.demo or not p.provider:Allowed() then return out end
 local r=Root();local lineage,scope=R.Lineage(p.owner),R.Scope(p.owner)
 local character=ns.ChronicleStore.db and ns.ChronicleStore.db.characters[p.owner]
 for key,row in pairs(r and r.pages or {}) do
  local covered=type(row)=='table' and (type(row.sequence)~='number' or character and (character.sequence or 0)>=row.sequence)
  if covered and row.owner==p.owner and row.lineage==lineage and row.scope==scope then out[#out+1]={key=key,title=(row.collection or 'Journey')..' · '..(row.volumeId or 'saved manuscript'),used=row.used or 0} end
 end
 table.sort(out,function(a,b) return a.used>b.used end);return out
end
function R.CopyBlocks(p,key)
 if not p.provider or p.provider.demo or not p.provider:Allowed() then return end
 local r=Root();local row=r and r.pages[key]
 if not row or row.owner~=p.owner or row.lineage~=R.Lineage(p.owner) or row.scope~=R.Scope(p.owner) then return end
 local character=ns.ChronicleStore.db and ns.ChronicleStore.db.characters[p.owner]
 if type(row.sequence)=='number' and (not character or (character.sequence or 0)<row.sequence) then return end
 local clean=Blocks(row.blocks);if clean and Seal(clean)==row.seal then return clean end
end
