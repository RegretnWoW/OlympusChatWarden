-- One-time recovery for retired floating-name visibility changes. This module
-- never enables nameplates, hides names, conceals plates or creates world labels.
local _, ns = ...
local function OwnedFrame(...) return ns.Modules and ns.Modules.Frame('core',...) or CreateFrame(...) end
local R = {}
ns.NameplateRecovery = R
local legacy = {}
for _, name in ipairs({"nameplateShowAll", "nameplateShowEnemies", "nameplateShowFriends", "nameplateShowFriendlyPlayers",
    "nameplateShowFriendlyNpcs", "UnitNameFriendlyPlayerName", "UnitNameEnemyPlayerName", "UnitNamePlayerGuild",
    "UnitNamePlayerPVPTitle", "UnitNameNPC", "UnitNameFriendlySpecialNPCName", "UnitNameHostleNPC", "UnitNameInteractiveNPC"}) do
    legacy[name] = true
end
local function Get(name)
    local fn = C_CVar and C_CVar.GetCVar or GetCVar
    return type(fn) == "function" and ns.SafeString(ns.SafeCall(fn, name), 32) or nil
end
local function Restore()
    if not ns.DB or type(ns.DB.worldNameBackup) ~= "table" then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local setter = C_CVar and C_CVar.SetCVar or SetCVar
    for name, entry in pairs(ns.DB.worldNameBackup) do
        if type(name) ~= "string" or not legacy[name] or type(entry) ~= "table"
            or not ns.CanRead(entry.original) or not ns.CanRead(entry.applied)
            or #entry.original > 32 or #entry.applied > 32 then
            ns.DB.worldNameBackup[name] = nil
        else
            local current = Get(name)
            -- Another addon/player changed this preference: do not overwrite it.
            if current and current ~= entry.applied then ns.DB.worldNameBackup[name] = nil
            elseif current and type(setter) == "function" then
                local ok = pcall(setter, name, entry.original)
                if ok and Get(name) == entry.original then ns.DB.worldNameBackup[name] = nil end
            end
        end
    end
    if not next(ns.DB.worldNameBackup) then ns.DB.worldNameBackup = nil end
end
function R.Refresh()
    Restore()
    if ns.SyncOptions then ns.SyncOptions() end
end
function R.Status()
    if ns.DB and type(ns.DB.worldNameBackup) == "table" and next(ns.DB.worldNameBackup) then
        return "Previous visibility settings still need recovery. Wait until combat ends or reload with ChatWarden enabled."
    end
    return "Enable nameplates yourself in WoW. ChatWarden keeps your visibility choices and native health bars."
end
local events = OwnedFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "PLAYER_LOGOUT"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, addon)
    if event ~= "ADDON_LOADED" or addon == "OlympusChatWarden" then R.Refresh() end
end)
