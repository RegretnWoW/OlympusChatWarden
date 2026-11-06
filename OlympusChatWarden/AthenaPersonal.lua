-- Ordinary item receipt, from an exact native localized SELF loot template.
-- Preserve structured facts only. Inventory changes never infer a transaction.
local _,ns=...
local C,S,X=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local T={};ns.AthenaPersonal=T
local seen,order={},{}
local function Escape(s) return (s:gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])','%%%1')) end
local function Pattern(format)
    local pattern,map,at,nextArg='^',{},1,1
    while at<=#format do
        local pos=format:find('%',at,true)
        if not pos then pattern=pattern..Escape(format:sub(at));break end
        pattern=pattern..Escape(format:sub(at,pos-1))
        if format:sub(pos,pos+1)=='%%' then pattern=pattern..'%%';at=pos+2
        else
            local text=format:sub(pos);local arg,kind=text:match('^%%(%d+)%$([sd])');local used
            if arg then used=#arg+3;arg=tonumber(arg)
            else kind=text:match('^%%([sd])');arg=nextArg;nextArg=nextArg+1;used=2 end
            if not kind or arg>2 or #map>=2 then return end
            map[#map+1]=arg;pattern=pattern..(kind=='d' and '(%d+)' or '(.-)');at=pos+used
        end
    end
    if #map==0 then return end
    return pattern..'$',map
end
local formats={'LOOT_ITEM_SELF_MULTIPLE','LOOT_ITEM_PUSHED_SELF_MULTIPLE','LOOT_ITEM_CREATED_SELF_MULTIPLE',
    'LOOT_ITEM_SELF','LOOT_ITEM_PUSHED_SELF','LOOT_ITEM_CREATED_SELF'}
function T.Parse(message)
    local text=ns.SafeString(message,4096);if not text then return end
    for _,key in ipairs(formats) do
        local format=ns.SafeString(_G[key],1024);local pattern,map
        if format then pattern,map=Pattern(format) end
        if pattern then
            local a,b=text:match(pattern);local args={}
            if a then args[map[1]]=a;if b then args[map[2]]=b end end
            local link=args[1];local quantity=args[2] and S.Integer(tonumber(args[2]),1,1000000) or #map==1 and 1
            if link and quantity then
                local plain=link:gsub('^|c%x%x%x%x%x%x%x%x',''):gsub('|r$','')
                -- A singular template must not swallow a plural quantity suffix.
                if plain:match('^|Hitem:[%d:%-]+|h%[[^|]*%]|h$') then
                    local id=S.Integer(tonumber(plain:match('^|Hitem:(%d+)')),1,1000000000)
                    local item=id and ns.ChronicleEvidence.ItemString(link,id)
                    if item then return {recordType='item_received',itemID=id,itemString=item,quantity=quantity,
                        scope='native self loot message',method=key} end
                end
            end
        end
    end
end
function T.Handle(event,...)
    if not C.PersonalEnabled() or not X.Ready() then return end
    local line=S.Integer(select(11,...),1);if line and seen[line] then return end
    local data=T.Parse(select(1,...))
    if not data then return end
    data.lineID=line
    local e=X.Record('native_event',event,data,select(2,C.Owner()),false)
    if e and line then
        if #order>=512 then seen[table.remove(order,1)]=nil end
        seen[line]=true;order[#order+1]=line
    end
end
function T.Start() seen={};order={} end
T.Stop=T.Start
X.Register(T,{'CHAT_MSG_LOOT'},'chronicle')
