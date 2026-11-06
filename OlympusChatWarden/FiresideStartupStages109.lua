local _,ns=...
local T=ns.FiresideStartupTiming
T.Finish('static Lua and data',T.static);T.static=nil
if ns.AetherLive then ns.AetherLive.New=T.Wrap(ns.AetherLive.New,'Aether runtime construction',true)end
local frame=CreateFrame('Frame');local elapsed=0
frame:SetScript('OnUpdate',function(_,dt)
 elapsed=elapsed+(dt or 0);if elapsed<.25 then return end;elapsed=0
 -- Observe the real gate; never replace, weaken or manufacture readiness.
 if ns.DB and not ns.MainStorageBlocked and not ns.Initializing and ns.ChronicleStore and not ns.ChronicleStore.loading and ns.UI2 and ns.UI2.StartupReady and ns.UI2.StartupReady()then
  T.ready=GetTime();T.active=false;frame:SetScript('OnUpdate',nil)
 end
end)
