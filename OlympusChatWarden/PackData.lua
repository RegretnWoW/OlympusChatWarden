-- Bounded, data-only JSON. No loadstring/loadfile/evaluation. Duplicate keys,
-- nonintegral numbers, unknown fields and non-ASCII model strings are rejected.
local _, ns = ...
local D = {LIMIT = 98304, ARRAY = {}, NULL = {}}; ns.PackData = D
function D.Decode(text)
    if type(text) ~= 'string' or #text > D.LIMIT or text:find('[\128-\255]') then return nil, 'Unsupported or oversized pack data.' end
    local position, nodes = 1, 0
    local function fail() error('Invalid pack JSON.',0) end
    local function skip() local _,last=text:find('^[ \t\r\n]*',position); position=(last or position-1)+1 end
    local function str()
        if text:sub(position,position)~='"' then fail() end
        position=position+1; local output={}; local length=0
        while position<=#text do
            local c=text:sub(position,position); position=position+1
            if c=='"' then return table.concat(output) end
            if c=='\\' then
                c=text:sub(position,position); position=position+1
                local escapes={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
                if c=='u' then
                    local hex=text:sub(position,position+3)
                    if #hex~=4 or hex:find('[^0-9a-fA-F]') then fail() end
                    local code=tonumber(hex,16); if code>127 then fail() end
                    c=string.char(code); position=position+4
                else c=escapes[c]; if not c then fail() end end
            elseif c:byte()<32 then fail() end
            length=length+1; if length>2048 then fail() end
            output[#output+1]=c
        end
        fail()
    end
    local value
    value=function(depth)
        nodes=nodes+1; if nodes>30000 or depth>8 then fail() end
        skip(); local c=text:sub(position,position)
        if c=='"' then return str() end
        if c=='{' then
            position=position+1; skip(); local object,seen={},{}
            if text:sub(position,position)=='}' then position=position+1; return object end
            while true do
                skip(); local key=str(); if seen[key] then fail() end; seen[key]=true
                skip(); if text:sub(position,position)~=':' then fail() end; position=position+1
                object[key]=value(depth+1); skip(); c=text:sub(position,position); position=position+1
                if c=='}' then return object end; if c~=',' then fail() end
            end
        elseif c=='[' then
            position=position+1; skip(); local array=setmetatable({},D.ARRAY)
            if text:sub(position,position)==']' then position=position+1; return array end
            while true do
                if #array>=6000 then fail() end
                array[#array+1]=value(depth+1); skip(); c=text:sub(position,position); position=position+1
                if c==']' then return array end; if c~=',' then fail() end
            end
        elseif c=='-' or c:match('%d') then
            local token=text:match('^-?%d+',position); if not token then fail() end
            if token:match('^-?0%d') or #token>11 then fail() end
            position=position+#token; local number=tonumber(token)
            if not number or math.abs(number)>2147483647 then fail() end
            return number
        elseif text:sub(position,position+3)=='true' then position=position+4; return true
        elseif text:sub(position,position+4)=='false' then position=position+5; return false
        elseif text:sub(position,position+3)=='null' then position=position+4; return D.NULL end
        fail()
    end
    -- Parsing is intentionally synchronous inside pcall in Lua 5.1. Checkpoints
    -- cannot yield through its C boundary; signature/SHA work is sliced instead.
    local ok,result=pcall(function() local parsed=value(1); skip(); if position~=#text+1 then fail() end; return parsed end)
    if not ok then return nil,'Invalid pack JSON.' end
    return result
end
local fields={schema=true,id=true,title=true,author=true,version=true,description=true,rules=true,literal=true,replacements=true}
local fields2={schema=true,id=true,title=true,author=true,version=true,description=true,rules=true,gommage=true,replacements=true}
local fields3={schema=true,id=true,title=true,author=true,version=true,description=true,rules=true,gommage=true,replacements=true,purpose=true,statements=true,stance=true}
local fields5={schema=true,id=true,title=true,author=true,version=true,description=true,rules=true,gommage=true,replacements=true,purpose=true,statements=true,stance=true,policy=true}
local optional={gender=true,labels=true,reproductive=true,language=true,institutional=true,slogans=true,broad=true,america=true}
D.Optional=optional
local function exact(t,keys)
    if type(t)~='table' or getmetatable(t) then return false end
    for key in pairs(t) do if not keys[key] then return false end end
    for key in pairs(keys) do if t[key]==nil then return false end end
    return true
end
local function clean(s,limit,phrase)
    return type(s)=='string' and #s>=1 and #s<=limit and not s:find('[^ -~]') and not s:find('|',1,true)
        and (not phrase or s==s:lower() and not s:match('^%s') and not s:match('%s$'))
end
local function array(t) return type(t)=='table' and getmetatable(t)==D.ARRAY and #t<=2000 end
function D.Validate(model)
    local contract=type(model)=='table' and model.schema==5
    local policy = type(model)=='table' and (model.schema==3 or model.schema==4 or contract)
    local contextual = type(model)=='table' and (model.schema==4 or contract)
    local modern = type(model)=='table' and (model.schema==2 or policy)
    local vocabulary = type(model)=='table' and (modern and model.gommage or model.literal)
    if not exact(model,contract and fields5 or policy and fields3 or modern and fields2 or fields) or (model.schema~=1 and model.schema~=2 and model.schema~=3 and model.schema~=4 and model.schema~=5) or not optional[model.id] or model.author~='Regretn'
        or type(model.version)~='number' or model.version%1~=0 or model.version<1 or model.version>2147483647
        or not clean(model.title,80) or not clean(model.author,80) or not clean(model.description,1500)
        or not array(model.rules) or not array(vocabulary) or not array(model.replacements) then
        return nil,'Unsupported or invalid rule-pack model.'
    end
    if policy and ((model.purpose~='topic' and model.purpose~='subject' and model.purpose~='replacement')
        or (model.stance~='literal' and model.stance~='avoid-support' and model.stance~='protect') or not array(model.statements)
        or #model.statements>256 or model.purpose~='subject' and #model.statements>0) then return nil,'Invalid pack policy.' end
    if contextual and (model.purpose=='topic' and model.stance~='avoid-support'
        or model.purpose=='subject' and model.stance~='protect') then return nil,'Invalid contextual pack direction.' end
    if contract then
        local p=model.policy
        if not exact(p,{contract=true,mode=true,declaration=true,profile=true}) or p.contract~=1
            or (p.mode~='support' and p.mode~='usage' and p.mode~='protection')
            or (p.declaration~='none' and p.declaration~='pronouns' and p.declaration~='affiliation')
            or (model.purpose=='subject' and (p.mode~='protection' or p.profile~='country' or p.declaration~='none'))
            or (model.purpose=='topic' and (p.mode=='protection' or p.profile~='terminology'))
            or model.purpose=='replacement' or #model.statements>0 or #model.replacements>0 then
            return nil,'Invalid signed context contract.'
        end
    end
    local seen={}; local bytes=0
    for _,rule in ipairs(model.rules) do
        if not exact(rule,policy and {phrase=true,score=true,origin=true,role=true} or {phrase=true,score=true,origin=true}) or not clean(rule.phrase,120,true) or #rule.phrase<3
            or not clean(rule.origin,200) or type(rule.score)~='number' or rule.score%1~=0 or rule.score<0 or rule.score>100
            or seen[rule.phrase] then return nil,'Invalid or duplicated scored rule.' end
        seen[rule.phrase]=true; bytes=bytes+#rule.phrase
        if policy then
            local roles=contract and (model.purpose=='topic' and {topic=true,declaration=true} or {reference=true,groupReference=true})
                or model.purpose=='topic' and {topic=true,topicBroad=true,viewpoint=true,advocacy=contextual,advocacyBroad=contextual} or model.purpose=='subject' and {reference=true,preference=true,statement=true,threat=true} or {}
            local reference=contract or rule.role=='reference' or contextual and (rule.role=='topic' or rule.role=='topicBroad' or rule.role=='viewpoint')
            if not roles[rule.role] or reference and rule.score~=0 or not reference and rule.score==0 then return nil,'Invalid rule role.' end
            if contract and rule.role=='declaration' and model.policy.declaration~='pronouns' then return nil,'Declaration rule requires a signed declaration policy.' end
        end
    end
    seen={}
    for _,rule in ipairs(policy and model.statements or {}) do
        if not exact(rule,{phrase=true,score=true,origin=true,position=true}) or not clean(rule.phrase,120,true) or #rule.phrase<3
            or not clean(rule.origin,200) or (rule.score~=55 and rule.score~=82 and rule.score~=90 and rule.score~=95)
            or (rule.position~='predicate' and rule.position~='after' and rule.position~='before') then return nil,'Invalid subject statement.' end
        local key=rule.position..':'..rule.phrase
        if seen[key] then return nil,'Duplicate subject statement.' end
        seen[key]=true;bytes=bytes+#rule.phrase
    end
    seen={}
    for _,phrase in ipairs(vocabulary) do
        if not clean(phrase,120,true) or seen[phrase] then return nil,'Invalid or duplicated display rule.' end
        seen[phrase]=true; bytes=bytes+#phrase
    end
    seen={}
    for _,rule in ipairs(model.replacements) do
        if model.id~='labels' or not exact(rule,{phrase=true,text=true}) or not clean(rule.phrase,120,true) or #rule.phrase<3
            or not clean(rule.text,120) or seen[rule.phrase] then return nil,'Invalid or duplicated replacement.' end
        seen[rule.phrase]=true; bytes=bytes+#rule.phrase
    end
    if #model.rules+#vocabulary+#model.replacements==0 then return nil,'Empty pack.' end
    if bytes>60000 then return nil,'Pack rule budget exceeded.' end
    return model
end
