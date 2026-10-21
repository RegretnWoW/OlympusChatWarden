-- Opt-in local recording. No network traffic, automatic reports or age expiry.
local _,ns=...
local function OwnedFrame(...) return ns.Modules and ns.Modules.Frame('chat',...) or CreateFrame(...) end
local C={MAX_ENTRIES=5000,MAX_BYTES=4194304,MAX_BOOKMARKS=50,MAX_BOOKMARK_BYTES=1048576,MAX_TEXT=8192}
ns.ChatCapture=C
local function Copy(entry)
    return {id=entry.id,original=entry.original,sender=entry.sender,event=entry.event,
        recipient=entry.recipient,channel=entry.channel,timestamp=entry.timestamp,truncated=entry.truncated==true}
end
local function Size(entry) return #entry.original+#entry.sender+#entry.event+#(entry.recipient or '')+#(entry.channel or '')+128 end
local function Clean(entry)
    if type(entry)~='table' or not ns.CanRead(entry.original) or not ns.CanRead(entry.sender)
        or not ns.CanRead(entry.event) then return end
    return {id=ns.SafeNumber(entry.id),original=ns.Reports.Clip(entry.original,C.MAX_TEXT),
        sender=ns.Reports.Clip(entry.sender,128),event=ns.Reports.Clip(entry.event,128),
        recipient=ns.SafeString(entry.recipient,128),channel=ns.SafeString(entry.channel,128),
        timestamp=ns.SafeNumber(entry.timestamp),truncated=entry.truncated==true or #entry.original>C.MAX_TEXT}
end
function C.Initialize()
    local db=type(ns.DB.chatCapture)=='table' and ns.DB.chatCapture or {}
    ns.DB.chatCapture=db;C.db=db
    for _,key in ipairs({'enabled','whispers','guild'}) do
        if type(db[key])~='boolean' then db[key]=key~='enabled' end
    end
    local saved=db.entries;db.entries={};C.bytes=0;C.nextID=0
    -- Keep the newest bounded records even if SavedVariables was edited.
    for i=math.max(1,#(type(saved)=='table' and saved or {})-C.MAX_ENTRIES+1),#(type(saved)=='table' and saved or {}) do
        local entry=Clean(saved[i])
        if entry then
            C.nextID=C.nextID+1;entry.id=C.nextID;db.entries[#db.entries+1]=entry;C.bytes=C.bytes+Size(entry)
            while C.bytes>C.MAX_BYTES do C.bytes=C.bytes-Size(table.remove(db.entries,1)) end
        end
    end
    saved=db.bookmarks;db.bookmarks={};C.bookmarkBytes=0;C.nextBookmark=0
    for _,item in ipairs(type(saved)=='table' and saved or {}) do
        if #db.bookmarks>=C.MAX_BOOKMARKS then break end
        if type(item)=='table' and type(item.records)=='table' then
            local bookmark={title=ns.Reports.Clip(item.title,120),note=ns.Reports.Clip(item.note,1000),records={},timestamp=ns.SafeNumber(item.timestamp)}
            for i=1,math.min(21,#item.records) do
                local entry=Clean(item.records[i]);if entry then bookmark.records[#bookmark.records+1]=entry end
            end
            bookmark.id=C.nextBookmark+1
            local bytes=#ns.Reports.JSON(bookmark)
            if #bookmark.records>0 and C.bookmarkBytes+bytes<=C.MAX_BOOKMARK_BYTES then
                C.nextBookmark=C.nextBookmark+1;bookmark.id=C.nextBookmark
                db.bookmarks[#db.bookmarks+1]=bookmark;C.bookmarkBytes=C.bookmarkBytes+bytes
            end
        end
    end
    C.seen={};C.seenOrder={};C.live={};C.liveReverse={}
end
function C.Changed() if ns.RefreshCapture then ns.RefreshCapture() end end
function C.SetOption(key,value)
    if key~='enabled' and key~='whispers' and key~='guild' then return end
    C.db[key]=value==true;C.Changed()
end
function C.Record(event,message,sender,lineID,channel)
    if not C.db or not C.db.enabled or not ns.CanRead(event) or not ns.CanRead(message) or not ns.CanRead(sender) then return end
    if (event=='CHAT_MSG_WHISPER' or event=='CHAT_MSG_WHISPER_INFORM') and not C.db.whispers then return end
    if (event=='CHAT_MSG_GUILD' or event=='CHAT_MSG_OFFICER') and not C.db.guild then return end
    local id=ns.SafeNumber(lineID)
    if id and id>0 then
        local key=event..':'..id
        if C.seen[key] or C.live[key] then return end
        C.seen[key]=true;C.seenOrder[#C.seenOrder+1]=key
        if #C.seenOrder>512 then C.seen[table.remove(C.seenOrder,1)]=nil end
    end
    C.nextID=C.nextID+1
    local entry={id=C.nextID,original=ns.Reports.Clip(message,C.MAX_TEXT),sender=ns.Reports.Clip(sender,128),event=ns.Reports.Clip(event,128),
        channel=ns.SafeString(channel,128),timestamp=ns.SafeNumber(ns.SafeCall(time)) or ns.SafeNumber(ns.SafeCall(GetServerTime)),truncated=#message>C.MAX_TEXT}
    if event=='CHAT_MSG_WHISPER_INFORM' then
        entry.recipient=entry.sender;entry.sender=ns.Shield.UnitName('player') or '[you]'
    end
    local bytes=Size(entry)
    while #C.db.entries>=C.MAX_ENTRIES or C.bytes+bytes>C.MAX_BYTES do
        local old=table.remove(C.db.entries,1);C.bytes=C.bytes-Size(old)
        local key=C.liveReverse[old];if key then C.live[key]=nil;C.liveReverse[old]=nil end
    end
    C.db.entries[#C.db.entries+1]=entry;C.bytes=C.bytes+bytes
    if id and id>0 then
        local key=event..':'..id;C.live[key]={entry=entry,lineID=id,clickedName=sender};C.liveReverse[entry]=key
    end
    C.Changed();return entry
end
function C.Find(sender,lineID)
    lineID=ns.SafeNumber(lineID)
    local wanted=ns.Shield.Key(sender);if not wanted or not lineID or lineID<=0 then return end
    for _,item in pairs(C.live) do
        if item.lineID==lineID and ns.Shield.Key(item.clickedName)==wanted then
            for _,entry in ipairs(C.db.entries) do if entry==item.entry then return entry end end
        end
    end
end
function C.Bookmark(id,title,note)
    local index
    for i,entry in ipairs(C.db.entries) do if entry.id==id then index=i;break end end
    if not index then return false,'That line has left the capture. Pick another line.' end
    if #C.db.bookmarks>=C.MAX_BOOKMARKS then return false,'You have 50 bookmarks. Remove one before saving another.' end
    local bookmark={title=ns.Reports.Clip(title,120),note=ns.Reports.Clip(note,1000),records={},timestamp=C.db.entries[index].timestamp}
    if bookmark.title=='' then bookmark.title='Incident '..(C.nextBookmark+1) end
    for i=math.max(1,index-10),math.min(#C.db.entries,index+10) do bookmark.records[#bookmark.records+1]=Copy(C.db.entries[i]) end
    bookmark.id=C.nextBookmark+1
    local bytes=#ns.Reports.JSON(bookmark)
    if C.bookmarkBytes+bytes>C.MAX_BOOKMARK_BYTES then return false,'Bookmark storage is full. Remove a bookmark first.' end
    C.nextBookmark=C.nextBookmark+1;bookmark.id=C.nextBookmark
    C.db.bookmarks[#C.db.bookmarks+1]=bookmark;C.bookmarkBytes=C.bookmarkBytes+bytes;C.Changed();return true,'Bookmark saved locally.'
end
function C.UpdateBookmark(id,title,note)
    for _,item in ipairs(C.db.bookmarks) do if item.id==id then
        local old=#ns.Reports.JSON(item);local t,n=item.title,item.note
        item.title=ns.Reports.Clip(title,120);item.note=ns.Reports.Clip(note,1000)
        local bytes=#ns.Reports.JSON(item)
        if C.bookmarkBytes-old+bytes>C.MAX_BOOKMARK_BYTES then item.title,item.note=t,n;return false,'Bookmark storage is full.' end
        C.bookmarkBytes=C.bookmarkBytes-old+bytes;C.Changed();return true,'Bookmark updated.'
    end end
    return false,'Select a saved bookmark first.'
end
function C.RemoveBookmark(id)
    for i,item in ipairs(C.db.bookmarks) do if item.id==id then
        -- Recount because old records may not have included the assigned id.
        table.remove(C.db.bookmarks,i);C.bookmarkBytes=0
        for _,other in ipairs(C.db.bookmarks) do C.bookmarkBytes=C.bookmarkBytes+#ns.Reports.JSON(other) end
        C.Changed();return
    end end
end
function C.Clear() C.db.entries={};C.bytes=0;C.live={};C.liveReverse={};C.Changed() end
function C.RemoveRecords(records)
    local ids={};for _,entry in ipairs(records or {}) do if type(entry)=='table' and ns.SafeNumber(entry.id) then ids[entry.id]=true end end
    local removed=0
    for i=#C.db.entries,1,-1 do
        local entry=C.db.entries[i]
        if ids[entry.id] then
            local key=C.liveReverse[entry];if key then C.live[key]=nil;C.liveReverse[entry]=nil end
            C.bytes=C.bytes-Size(entry);table.remove(C.db.entries,i);removed=removed+1
        end
    end
    if removed>0 then C.Changed() end;return removed
end
function C.Records(bookmarks)
    local result={}
    for _,item in ipairs(bookmarks and C.db.bookmarks or C.db.entries) do result[#result+1]=item end
    return result
end
function C.Line(entry)
    return ns.Review.TimeLabel(entry)..'  '..entry.event:gsub('CHAT_MSG_','')..(entry.channel and ' ('..entry.channel..')' or '')..'  '..entry.sender
        ..(entry.recipient and ' -> '..entry.recipient or '')..'\n'..entry.original
        ..(entry.truncated and '\n[Long message shortened]' or '')
end
