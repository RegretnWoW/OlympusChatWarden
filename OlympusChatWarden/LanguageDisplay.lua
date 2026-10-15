-- Display labels only. Native player/item link payloads and sender identities survive.
local _,ns=...
local D={};ns.LanguageDisplay=D
local frames=setmetatable({},{__mode='k'})
local originals,order,bytes={}, {},0
local labels,labelOrder,labelBytes={}, {},0
local Rewrite
function D.CoveredMarkup(text)
    return type(text)=='string' and text:lower():find('|tinterface\\addons\\olympuschatwarden\\media\\bar:',1,true)~=nil
end
function D.Identity(text)
    if not ns.CanRead(text) then return end
    text=text:match('|Hplayer:([^:|]+)') or text
    if D.CoveredMarkup(text) or text:find('|T',1,true) or text:find('|A',1,true) then return end
    text=text:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('^%[([^%[%]]+)%]$','%1'):match('^%s*(.-)%s*$')
    if text=='' or text=='[]' or text=='[ ]' or text=='[redacted]' or text:find('|',1,true) then return end
    return text
end
function D.OriginalLabel(link,label,cached)
    if D.Identity(cached) then return cached end
    if not D.CoveredMarkup(label) and D.Identity(label) then return label end
    local name=D.Identity(link and ('|H'..link..'|h|h'))
    if not name then return end
    return label and label:match('^%[') and ('['..name..']') or name
end
local function Safe(frame)
    return frame and ns.Readable(frame) and frame~=UIParent
        and not (frame.IsForbidden and frame:IsForbidden()) and not (frame.IsProtected and frame:IsProtected())
end
local function Cover(text,owner)
    local ranges=ns.Language.ScriptRanges(text);if not ranges then return text end
    return ns.Engine.Render(text,ranges,function(original) return ns.BarText(original,owner) end)
end
local function Hash(text)
    local n=5381;for i=1,#text do n=(n*33+text:byte(i))%4294967296 end;return tostring(n)
end
local function NameMatches(link,raw,matches)
    local L,C=ns.Language,ns.ChatReports
    if not L.NamesActive() then return matches end
    local sender,id
    if C then sender,id=C.ParseLink(link) end
    local captured=sender and id and C.Find(sender,id)
    if not captured and sender and id and ns.Shield then
        -- Native links may omit the local realm. Compare canonical identities,
        -- never a similar name from another realm.
        local key=ns.Shield.Key(sender)
        for i=#C.entries,1,-1 do
            local item=C.entries[i]
            if item.lineID==id and ns.Shield.Key(item.sender)==key then captured=item;break end
        end
    end
    local event=captured and captured.event or link:match('^player:[^:]+:[^:]*:([A-Z_]+)')
    if event and not event:match('^CHAT_MSG_') then event='CHAT_MSG_'..event end
    local source={kind='player',sender=captured and captured.sender or sender}
    if event and not L.Covers(event,source) then return matches end
    if captured then
        local result=L.Check(captured.original,captured.event,source,true)
        -- A message's Label/Leave choice also leaves its name readable. For an
        -- English/preferred reply there is no language action; cover only the name.
        if result and (result.action=='Warning' or result.action=='Unchanged') then return matches end
    end
    return L.NameMatches(raw,matches)
end
local function NameLabel(link,label,owner)
    if #link>512 or #label>512 then return label end
    local state=labels[link]
    local ours=label:find('|TInterface\\AddOns\\OlympusChatWarden\\Media\\Bar:',1,true)
    local raw=D.OriginalLabel(link,label,state and (label==state.display or label==state.raw or ours) and state.raw)
    if not raw then return label end
    local matches=ns.Active('chat') and ns.Find(raw) or {}
    matches=NameMatches(link,raw,matches)
    local masks={};for _,hit in ipairs(matches) do if ns.IsRedacted(hit) then masks[#masks+1]=hit end end
    if #masks==0 then if state then state.active=false end;return raw end
    if not state or state.raw~=raw then
        if state then
            labelBytes=labelBytes-state.cost;labels[link]=nil
            for i,key in ipairs(labelOrder) do if key==link then table.remove(labelOrder,i);break end end
        end
        local cost=#link+#raw+2048
        while #labelOrder>=512 or labelBytes+cost>1048576 do
            local key=table.remove(labelOrder,1);if not key then break end
            local old=labels[key];labelBytes=labelBytes-old.cost;labels[key]=nil
        end
        state={raw=raw,cost=cost};labels[link]=state;labelOrder[#labelOrder+1]=link;labelBytes=labelBytes+cost
    end
    if state.revision~=ns.PolicyRevision then state.shown=false end
    state.revision=ns.PolicyRevision;state.active=true
    state.display=ns.Engine.Render(raw,masks,function(original,hit)
        if hit.replacement then return hit.replacement end
        return state.shown and ns.GrayText(original,owner) or ns.BarText(original,owner)
    end)
    if not state.recorded and ns.Review then
        -- A covered name is a display result, never a hidden-message alert.
        ns.Review.Add(raw,masks,{kind='playerName',panel='Chat name',displayOnly=true,nameDisplay=true,nameOriginal=raw,sender=link:match('^player:([^:]+)')},
            'chat-name:'..Hash(link)..':'..Hash(raw),state.display)
        state.recorded=true
    end
    return state.display
end
function D.CanReveal(link)
    local state=ns.CanRead(link) and labels[link]
    return state and state.active and state.revision==ns.PolicyRevision
end
function D.Toggle(link,frame)
    if not D.CanReveal(link) then return false end
    local state=labels[link];state.shown=not state.shown
    local changed=0
    for host in pairs(frames) do
        if ns.ChatFonts then ns.ChatFonts.Prepare(host) end
        changed=changed+Rewrite(host)
    end
    if ns.ChatFonts then ns.ChatFonts.Refresh() end
    if changed==0 then
        state.shown=not state.shown
        ns.Print('This chat display could not update the name. Its original is in Messages.')
    end
    return true
end
function D.Text(text,owner,strict)
    if not ns.CanRead(text) or #text>ns.Engine.MAX_TEXT or not ns.DB or not ns.DB.languageFilter then return text end
    local names=ns.Language.NamesActive()
    -- Strict message labels are handled inside the chat adapter, where event
    -- coverage and own-message exclusions are known. The formatter only masks names.
    if not names and not strict and not ns.Active('chat') then return text end
    local output={}
    for _,piece in ipairs(ns.Engine.Segments(text)) do
        local open,label,close=piece.text:match('^(|H[^|]+|h)(.-)(|h)$')
        if open and open:match('^|Hplayer:') and not strict then
            output[#output+1]=open..NameLabel(open:sub(3,-3),label,owner)..close
        elseif open and not open:match('^|Haddon:') and strict then output[#output+1]=open..Cover(label,owner)..close
        else output[#output+1]=piece.text end
    end
    return table.concat(output)
end
function D.MessageLinks(text,owner) return D.Text(text,owner,true) end
function D.SystemFilter(frame,_,message,...)
    if not ns.Language.NamesActive() or not ns.CanRead(message) then return false end
    local matches=ns.Language.NameMatches(message,{})
    if #matches==0 then return false end
    local key=ns.ChatFallbackKey('CHAT_MSG_SYSTEM',message,{})
    local rendered=ns.RenderRedacted(message,matches,frame,true,key)
    ns.Review.Add(message,matches,{kind='playerName',panel='System notice',displayOnly=true},key,rendered)
    return false,rendered,...
end
local function Remember(rendered,raw)
    if rendered==raw or originals[rendered] then return end
    local cost=#rendered+#raw;if cost>262144 then return end
    while #order>=128 or bytes+cost>262144 do
        local key=table.remove(order,1);if not key then break end
        local old=originals[key];bytes=bytes-#key-#old;originals[key]=nil
    end
    originals[rendered]=raw;order[#order+1]=rendered;bytes=bytes+cost
end
Rewrite=function(frame)
    if not Safe(frame) then return 0 end
    local changed=0
    local function Update(message)
        local raw=originals[message] or message
        local updated=D.Text(raw,frame);Remember(updated,raw)
        if updated~=message then changed=changed+1 end
        return updated
    end
    if type(frame.ForEachMessage)=='function' then
    pcall(frame.ForEachMessage,frame,function(entry)
        if ns.Readable(entry) and type(entry)=='table' and ns.CanRead(entry.message) then
            entry.message=Update(entry.message)
        end
        return false
    end)
    elseif type(frame.TransformMessages)=='function' then
        pcall(frame.TransformMessages,frame,function(message) return ns.CanRead(message) and message:find('|Hplayer:',1,true)~=nil end,
            function(message,...) return Update(message),... end)
    end
    if changed>0 then
        if frame.MarkDisplayDirty then pcall(frame.MarkDisplayDirty,frame) end
        if frame.RefreshIfNecessary then pcall(frame.RefreshIfNecessary,frame) end
    end
    return changed
end
function D.Install()
    for i=1,math.min(tonumber(NUM_CHAT_WINDOWS) or 10,20) do
        local frame=_G['ChatFrame'..i]
        if Safe(frame) and type(frame.AddMessage)=='function' and not frames[frame] then
            frames[frame]=true
            -- The formatter adds player links after chat-event filters. A local
            -- frame wrapper is required to change the label before it is stored.
            local add=frame.AddMessage
            frame.AddMessage=function(self,message,...)
                local updated=Safe(self) and D.Text(message,self) or message
                if ns.CanRead(message) and ns.CanRead(updated) then Remember(updated,message) end
                if ns.ChatFonts then ns.ChatFonts.Watch(self,updated) end
                return add(self,updated,...)
            end
            -- Consume only our Ctrl-left reveal gesture. Ordinary native player
            -- clicks and right-click menus retain their existing handler/payload.
            local click=frame.GetScript and frame:GetScript('OnHyperlinkClick')
            if click and frame.SetScript then
                frame:SetScript('OnHyperlinkClick',function(self,link,text,button,...)
                    if button=='LeftButton' and ns.RevealModifier() and D.CanReveal(link) then
                        ns.OnLink(link,self,button);return
                    end
                    return click(self,link,text,button,...)
                end)
            end
        end
        if frames[frame] then Rewrite(frame) end
    end
end
function D.Refresh() D.Install() end
local events=CreateFrame('Frame')
for _,event in ipairs({'PLAYER_LOGIN','UPDATE_CHAT_WINDOWS','UPDATE_FLOATING_CHAT_WINDOWS'}) do pcall(events.RegisterEvent,events,event) end
events:SetScript('OnEvent',function() if ns.DB then D.Install() end end)
