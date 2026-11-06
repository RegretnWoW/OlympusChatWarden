-- Display branding only. Keep the addon identity and saved-variable contract stable.
local _,ns=...
local B={path='Interface\\AddOns\\OlympusChatWarden\\Media\\Warden\\'};ns.WardenBrand=B
B.sections={
    overview={name='Home',icon='CommandWarden'},journey={name='Journey',icon='ChronicleWarden'},messages={name='Chat',icon='ChatWarden'},
    mentions={name='Signal',icon='SignalWarden'},shield={name='Shield',icon='ShieldWarden'},
    intel={name='Intel',icon='IntelWarden'},chronicle={name='Chronicle',icon='ChronicleWarden'},
    relay={name='Relay',icon='RelayWarden'},settings={name='Settings',icon='CommandWarden'},
}
B.parents={capture='messages',rules='messages',packs='messages',reports='messages',activity='overview',modules='settings',performance='settings',recording='settings',updates='settings'}
-- The six original crests include a 1/16 transparent margin on every side.
-- Relay's source fills its canvas, so give it the same visible footprint in UI.
B.iconScale={RelayWarden=.875,RelayWardenSmall=.875}
-- Status aliases always keep their module's crest, including paused states.
B.statusModules={enabled='messages',enabledOff='messages',filtering='messages',shieldActive='shield',shieldOff='shield',captureOff='capture',mentionsOff='mentions'}
function B.Parent(id) return B.parents[id] or id end
function B.Icon(id) local s=B.sections[B.Parent(B.statusModules[id] or id)];return s and s.icon end
function B.Path(icon)
 local key=icon:gsub('Small$','');local art=ns.WardenArt;local alias=art and art.legacy[key]
 return alias and art.Path(alias)or B.path..icon..'.tga'
end
function B.Text(value)
    return type(value)=='string' and value:gsub('|','||') or tostring(value or 'Not recorded')
end
-- UI-only multi-return reader. The older ns.SafeCall intentionally returns one value.
function B.Values(fn,...)
    if type(fn)~='function' then return end
    local values={pcall(fn,...)};if not values[1] then return end
    for n=2,11 do if not ns.Readable(values[n]) then values[n]=nil end end
    return unpack(values,2,11)
end
-- Blizzard's performance tooltip displays the first GetAddOnInfo return (the
-- folder ID), ignoring the already rebranded TOC title. Change its visible name
-- after native rendering, never the identity APIs or measured usage values.
function B.UsageTooltip()
    if InCombatLockdown and InCombatLockdown() then return end
    local tip=GameTooltip
    if not tip or tip.IsForbidden and tip:IsForbidden() or tip.IsProtected and tip:IsProtected() then return end
    local count=ns.SafeNumber(ns.SafeCall(tip.NumLines,tip)) or 0
    for n=1,math.min(count,80) do
        for _,side in ipairs({'Left','Right'}) do
            local line=_G['GameTooltipText'..side..n]
            if line and not (line.IsForbidden and line:IsForbidden()) and not (line.IsProtected and line:IsProtected()) then
                local text=ns.SafeCall(line.GetText,line)
                if ns.CanRead(text) then
                    local renamed,changed=text:gsub('%f[%w_]OlympusChatWarden%f[^%w_]','Fireside')
                    if changed>0 then line:SetText(renamed) end
                end
            end
        end
    end
end
function B.InstallUsageTooltip()
    if B.usageTooltipHooked then return true end
    if type(hooksecurefunc)~='function' or type(MainMenuBarPerformanceBarFrame_OnEnter)~='function' then return false end
    B.usageTooltipHooked=pcall(hooksecurefunc,'MainMenuBarPerformanceBarFrame_OnEnter',B.UsageTooltip)
    return B.usageTooltipHooked
end
local usageEvents=CreateFrame('Frame')
local function InstallUsage()
    if B.InstallUsageTooltip() then usageEvents:UnregisterEvent('ADDON_LOADED');usageEvents:UnregisterEvent('PLAYER_LOGIN') end
end
usageEvents:RegisterEvent('ADDON_LOADED');usageEvents:RegisterEvent('PLAYER_LOGIN');usageEvents:SetScript('OnEvent',InstallUsage)
