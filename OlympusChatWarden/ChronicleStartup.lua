-- Ordinary collectors, full validation, separate local write destination.
local _,ns=...
local C,S,J=ns.Chronicle,ns.ChronicleStore,ns.ChronicleStartupJournal
local B={diagnostics={captured=0,merged=0,overflow=0,discarded=0,deferred=0}};ns.ChronicleStartup=B
local source
local function Eligible(saved)
    return type(saved)=='table' and not getmetatable(saved) and (saved.schema==nil or S.Integer(saved.schema,1,S.VERSION))
        and saved.enabled==true and saved.consentVersion==S.CONSENT and ns.DB
        and ns.Modules.Enabled('history') and ns.Membership and ns.Membership.Allowed()
end
function B.Begin(saved) source=saved;B.notified=nil;J.Reset() end
function B.Cancel() J.Cancel();B.diagnostics.deferred=J.Count() end
function B.Ensure(worldReady)
    local saved=S.loading and source or S.db
    if not worldReady or not Eligible(saved) then return end
    local owner=C.Owner();local at=C.Stamp();if not owner or not at then return end
    if not S.loading and not J.Has(owner) and not J.Writing() then return end
    if not J.Character(owner) then
        if not J.Open(owner,saved,at) then return end
        if not B.notified then
            B.notified=true
            ns.Print(S.loading and 'Enabled Chronicle and Intel collectors are recording while retained history validates. Recovery stays local.'
                or 'Enabled collectors are recording to the local recovery journal while pending observations reconcile.')
        end
    end
    if not C.Active() then C.StartPending() end
end
function B.Merge() source=nil;J.Merge() end
function B.Handle(event) if event=='PLAYER_ENTERING_WORLD' then B.Ensure(true) end end
