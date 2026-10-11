-- Native tooltips only; preserve item/unit identities and mouse ownership.
-- Ctrl reveals while held, so the player never has to move onto a hover tip.
local _, ns = ...
local tips = {"GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3",
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2"}
local installed = setmetatable({}, {__mode = "k"})
local queued = false
local function Safe(tip)
    return tip and ns.Readable(tip) and not (tip.IsForbidden and tip:IsForbidden())
        and not (tip.IsProtected and tip:IsProtected())
end
local function Owned(tip)
    local owner = type(tip.GetOwner) == "function" and ns.SafeCall(tip.GetOwner, tip)
    for _ = 1, 14 do
        if not Safe(owner) then return false end
        if owner.ChatWardenOwned or owner.ChatWardenRegion or owner == ns.OptionsPanel then return true end
        if owner == UIParent or owner == WorldFrame then return false end
        owner = owner.GetParent and owner:GetParent()
    end
    return false
end
local function Queue()
    if queued then return end
    queued = true
    local function Run() queued = false; ns.ScanTooltips() end
    if C_Timer and C_Timer.After then C_Timer.After(0, Run) else Run() end
end
local function ScanTip(tip, name, state)
    if state.scanning or not ns.DB or InCombatLockdown and InCombatLockdown() then return end
    if not tip:IsVisible() or Owned(tip) then return end
    state.scanning = true
    local ok, err = pcall(function()
        if ns.OlympusMuteSignal then ns.OlympusMuteSignal.UpdateTooltip(tip, name) end
        local unit
        if type(tip.GetUnit)=='function' then
            local ok,_,token=pcall(tip.GetUnit,tip)
            if ok then unit=ns.SafeString(token,64) end
        end
        local player=unit and type(UnitIsPlayer)=='function' and ns.Checked(ns.SafeCall(UnitIsPlayer,unit))
        local guid=player and ns.SafeString(ns.SafeCall(UnitGUID,unit),128)
        local count = ns.SafeNumber(ns.SafeCall(tip.NumLines, tip)) or 0
        for i = 1, math.min(count, 40) do
            for _, side in ipairs({"Left", "Right"}) do
                local region = _G[name .. "Text" .. side .. i]
                if Safe(region) and region.IsVisible and region:IsVisible()
                    and not (ns.OlympusMuteSignal and ns.OlympusMuteSignal.IsTooltipLine(tip, i)) then
                    ns.TrackRegion(region, "tooltips", function() return {kind = "tooltip", panel = name} end, nil,
                        {tooltip = true, keepLabel = true, preserveAlpha = true,languageName=player and i==1 and side=='Left',
                            -- Rebuilding the same hover tip is not a new
                            -- capture. Raw text changes already reset state.
                            identity = name,
                            available = function()
                                if not tip:IsVisible() or Owned(tip) then return false end
                                if player and i==1 and side=='Left' and guid then
                                    local ok,_,token=pcall(tip.GetUnit,tip)
                                    return ok and ns.SafeString(token,64)==unit and ns.SafeString(ns.SafeCall(UnitGUID,unit),128)==guid
                                end
                                return true
                            end})
                end
            end
        end
    end)
    state.scanning = false
    if not ok and geterrorhandler then geterrorhandler()(err) end
end
function ns.ScanTooltips()
    if not ns.DB or InCombatLockdown and InCombatLockdown() then return end
    for _, name in ipairs(tips) do
        local tip = _G[name]
        if Safe(tip) then
            if not installed[tip] then
                local state = {}; installed[tip] = state
                tip:HookScript("OnShow", function() ScanTip(tip, name, state) end)
                tip:HookScript("OnTooltipCleared", function()
                    if ns.OlympusMuteSignal then ns.OlympusMuteSignal.ClearTooltip(tip) end
                end)
                if tip.HasScript and tip:HasScript("OnTooltipSetUnit") then
                    tip:HookScript("OnTooltipSetUnit", function() ScanTip(tip, name, state) end)
                end
                for _, method in ipairs({"SetUnit", "SetHyperlink", "SetItemByID", "SetSpellByID", "SetText", "AddLine", "AddDoubleLine"}) do
                    if type(tip[method]) == "function" then
                        -- Native tooltip setters can rebuild FontStrings in C,
                        -- bypassing Lua SetText hooks. Filter before the next
                        -- paint instead of exposing one unfiltered frame.
                        pcall(hooksecurefunc, tip, method, function() ScanTip(tip, name, state) end)
                    end
                end
            end
            ScanTip(tip, name, installed[tip])
        end
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "MODIFIER_STATE_CHANGED", "PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", Queue)
