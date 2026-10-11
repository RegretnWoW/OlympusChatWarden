-- One local export pipeline for reports, Shield and chat capture.
local _,ns=...
local E={};ns.Export=E
local function Copy(value)
    if type(value)~='table' then return value end
    local out={};for key,item in pairs(value) do out[key]=Copy(item) end;return out
end
function E.Batch(kind,mode,records)
    local items={}
    if records then for _,record in ipairs(records) do items[#items+1]=Copy(record) end
    elseif kind=='reports' then
        for _,record in ipairs(ns.Personal.reports) do
            if mode~='misses' or record.feedback=='Missed match' then items[#items+1]=ns.Reports.Normalize(record) end
        end
    elseif kind=='shield' then
        for _,item in ipairs(ns.Shield.List()) do
            items[#items+1]={name=item.name,expires=item.expires,session=item.session==true,reason=item.reason}
        end
    elseif kind=='capture' or kind=='bookmarks' then items=Copy(ns.ChatCapture.Records(kind=='bookmarks')) end
    return {kind=kind,items=items,selected={},hideNames=true,includeNotes=false,extraNames=''}
end
local function Plain(text)
    return text:gsub('|H.-|h(.-)|h','%1'):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('|T.-|t',''):gsub('|A.-|a','')
end
local function Names(batch)
    local names,phrases={},{}
    local function Add(name)
        if not ns.CanRead(name) or name=='' then return end
        name=Plain(name);local lower=ns.Engine.Lower(name)
        if lower=='' or names[lower] then return end
        names[lower]=true
        if lower:find('[^%w_\128-\255%-]') then phrases[#phrases+1]=lower end
        local base=name:match('^([^%-]+)%-')
        if base then Add(base) end
    end
    local function Walk(value)
        if type(value)~='table' then return end
        if value.nameDisplay==true and ns.CanRead(value.original) then
            Add(value.original:match('^%[(.-)%]$') or value.original)
        end
        for key,item in pairs(value) do
            if key=='name' or key=='sender' or key=='player' or key=='recipient' then Add(item)
            elseif type(item)=='table' then Walk(item) end
        end
    end
    Walk(batch.items)
    for _,entry in ipairs(ns.Review.entries) do Add(entry.sender) end
    if ns.ChatCapture and ns.ChatCapture.db then Walk(ns.ChatCapture.db.entries) end
    for _,entry in ipairs(ns.Shield.List()) do Add(entry.name) end
    for _,name in pairs(ns.DB.shield.allowed) do Add(name) end
    Add(ns.Shield.UnitName('player'))
    for name in batch.extraNames:gmatch('[^,\r\n]+') do Add(name:match('^%s*(.-)%s*$')) end
    table.sort(phrases,function(a,b) return #a>#b end);return {tokens=names,phrases=phrases}
end
local function Word(c) return c and (c>=128 or c>=48 and c<=57 or c>=97 and c<=122 or c==95) end
local function Scrub(text,names)
    text=Plain(text)
    for _,name in ipairs(names.phrases) do
        local lower=ns.Engine.Lower(text);local pos=1;local parts={}
        while true do
            local first,last=lower:find(name,pos,true)
            if not first then parts[#parts+1]=text:sub(pos);break end
            if not Word(lower:byte(first-1)) and not Word(lower:byte(last+1)) then
                parts[#parts+1]=text:sub(pos,first-1);parts[#parts+1]='[player]';pos=last+1
            else parts[#parts+1]=text:sub(pos,last);pos=last+1 end
        end
        text=table.concat(parts)
    end
    return (text:gsub('[%w_\128-\255%-]+',function(token)
        local lower=ns.Engine.Lower(token)
        local base=lower:match('^([^%-]+)%-')
        if names.tokens[lower] or base and names.tokens[base] then return '[player]' end
        return token
    end))
end
function E.Build(batch)
    local names=batch.hideNames and Names(batch) or nil
    local function Sanitize(value,key,nameDisplay)
        if not batch.includeNotes and (key=='note' or key=='notes' or key=='shieldReason' or batch.kind=='shield' and key=='reason') then return nil end
        if batch.hideNames and (key=='guid' or key=='key' or key=='realm' or key=='server' or key=='surname') then return nil end
        if type(value)=='string' then
            if batch.hideNames and nameDisplay and key=='phrase' then return '[name portion]' end
            if batch.hideNames and (key=='name' or key=='sender' or key=='player' or key=='recipient') then return '[player]' end
            return batch.hideNames and Scrub(value,names) or value
        end
        if type(value)~='table' then return value end
        local out={};for k,v in pairs(value) do out[k]=Sanitize(v,k,nameDisplay) end;return out
    end
    local records={}
    for i,item in ipairs(batch.items) do if batch.selected[i]~=false then records[#records+1]=Sanitize(item,nil,item.nameDisplay==true) end end
    return ns.Reports.JSON({schema=batch.kind=='reports' and 3 or 1,addon='OlympusChatWarden',displayName=ns.NAME,
        exportVersion=ns.VERSION,scope=batch.kind,recordCount=#records,records=records,
        privacy={knownNamesHidden=batch.hideNames,notesIncluded=batch.includeNotes,
            reminder='Review the text before sharing. Other identifying details may remain.'},
        description=batch.kind=='shield' and 'Personal local shields. This list is not proof of misconduct.' or nil},false,0),#records
end
function E.Label(item)
    return item.title or item.name or ((item.sender or item.feedback or 'Message')..(item.recipient and ' -> '..item.recipient or '')..'  '..(item.original or ''):gsub('[\r\n]',' '))
end
