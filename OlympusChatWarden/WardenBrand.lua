-- Display branding only. Keep the addon identity and saved-variable contract stable.
local _,ns=...
local B={path='Interface\\AddOns\\OlympusChatWarden\\Media\\Warden\\'};ns.WardenBrand=B
B.sections={
    overview={name='Warden',icon='Warden'},messages={name='ChatWarden',icon='ChatWarden'},
    mentions={name='SignalWarden',icon='SignalWarden'},shield={name='ShieldWarden',icon='ShieldWarden'},
    intel={name='IntelWarden',icon='IntelWarden'},chronicle={name='ChronicleWarden',icon='ChronicleWarden'},
}
B.parents={capture='messages',rules='messages',packs='messages',reports='messages',activity='overview'}
-- Status aliases always keep their module's crest, including paused states.
B.statusModules={enabled='messages',enabledOff='messages',filtering='messages',shieldActive='shield',shieldOff='shield',captureOff='capture',mentionsOff='mentions'}
function B.Parent(id) return B.parents[id] or id end
function B.Icon(id) local s=B.sections[B.Parent(B.statusModules[id] or id)];return s and s.icon end
function B.Path(icon) return B.path..icon..'.tga' end
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
