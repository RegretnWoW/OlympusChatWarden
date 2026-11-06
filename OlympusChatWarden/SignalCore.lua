-- Always-available in-process observations, not a network or history service.
local _,ns=...
local R={topics={},count=0,errors=0,depth=0,scratch={}};ns.SignalCore=R
function R.Subscribe(topic,owner,key,fn)
    if type(topic)~='string' or #topic>64 or type(key)~='string' or #key>64 or type(fn)~='function' then return false end
    local list=R.topics[topic]
    if not list then local n=0;for _ in pairs(R.topics) do n=n+1 end;if n>=32 then return false end;list={};R.topics[topic]=list end
    for _,s in ipairs(list) do if s.owner==owner and s.key==key then s.fn=fn;s.active=true;return true end end
    if #list>=16 or R.count>=64 then return false end
    list[#list+1]={owner=owner,key=key,fn=fn,active=true};R.count=R.count+1;return true
end
function R.Unsubscribe(topic,owner,key)
    local list=R.topics[topic];if not list then return end
    for i=#list,1,-1 do if list[i].owner==owner and (not key or list[i].key==key) then list[i].active=false;table.remove(list,i);R.count=R.count-1 end end
    if #list==0 then R.topics[topic]=nil end
end
function R.Has(topic)
    for _,s in ipairs(R.topics[topic] or {}) do if ns.Modules.Capable(s.owner) then return true end end
    return false
end
function R.Publish(topic,payload)
    local list=R.topics[topic];if not list or R.depth>=8 or type(payload)~='table' or payload.version~=1 then return 0 end
    R.depth=R.depth+1;local delivered=0
    -- Subscription slots are stable during delivery. No permanent event queue.
    local calls=R.scratch[R.depth] or {};R.scratch[R.depth]=calls
    local count=#list;for i=1,count do calls[i]=list[i] end
    for i=1,count do local s=calls[i];if s.active and ns.Modules.Capable(s.owner) then
        local ok=pcall(s.fn,payload);if ok then delivered=delivered+1 else R.errors=math.min(1000000,R.errors+1) end
    end;calls[i]=nil end
    R.depth=R.depth-1;return delivered
end
