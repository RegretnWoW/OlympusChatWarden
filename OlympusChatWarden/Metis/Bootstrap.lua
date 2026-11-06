-- Metis owns literary decisions; accepted history and consent remain in Athena.
local _,ns=...
local M={NAME='Metis',VERSION='1.4.0',SCHEMA=1,capabilities={}}
ns.Metis=M;ns.Athena.Metis=M
function M.Register(name,capability)
    assert(not M.capabilities[name],'Duplicate Metis capability: '..name)
    M.capabilities[name]=capability
end
function M.Voice() return ns.DB and ns.DB.journalNarration=='Observed Record' and 'Observed Record' or 'Natural Fantasy' end
function M.Lore() return not ns.DB or ns.DB.journalLore~=false end
function M.Check(index)
    if index and (not index.provider or not index.provider:Allowed()) then error('DENIED') end
end
function M.Tick(index,n) if n%128==0 then M.Check(index);coroutine.yield() end end
