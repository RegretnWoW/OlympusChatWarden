-- Keep fully covered native chat lines at the chat window's configured font.
-- Visible multilingual originals retain the client's glyph fallback.
local _,ns=...
local F={};ns.ChatFonts=F
local frames=setmetatable({},{__mode='k'})
local styled=setmetatable({},{__mode='k'})
local marker='|TInterface\\AddOns\\OlympusChatWarden\\Media\\Bar:'
local function Safe(object)
    return object and ns.Readable(object)
        and not (object.IsForbidden and object:IsForbidden())
        and not (object.IsProtected and object:IsProtected())
end
local function Font(object)
    if not Safe(object) or not object.GetFont then return end
    local ok,path,size,flags=pcall(object.GetFont,object)
    if ok and ns.CanRead(path) and ns.SafeNumber(size) and size>0 and ns.Readable(flags) then
        return path,size,ns.CanRead(flags) and flags or ''
    end
end
local function CoveredRoman(text)
    if not ns.CanRead(text) or not text:find(marker,1,true) then return false end
    -- Ignore nonprinting native link payloads. Preserve them byte for byte.
    local visible=text:gsub('|H.-|h(.-)|h','%1'):gsub('|T.-|t',''):gsub('|A.-|a','')
        :gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')
    return not visible:find('[\128-\255]')
end
local function Restore(region,state)
    if not Safe(region) then styled[region]=nil;return end
    local path,size,flags=Font(region)
    -- Do not undo a newer style applied by the client or another addon.
    if path==state.appliedPath and size==state.appliedSize and flags==state.appliedFlags then
        if state.object and region.SetFontObject then pcall(region.SetFontObject,region,state.object)
        elseif state.path then pcall(region.SetFont,region,state.path,state.size,state.flags) end
    end
    styled[region]=nil
end
function F.Watch(frame,text)
    if Safe(frame) and ns.CanRead(text) and text:find(marker,1,true) then frames[frame]=true end
end
function F.Prepare(frame)
    -- Restore the native font family before the chat display receives revealed
    -- Unicode. SetFont's single-font override can otherwise outlive the rewrite
    -- and leave the client's normal glyph fallback unavailable for that update.
    for region,state in pairs(styled) do
        if state.frame==frame then Restore(region,state) end
    end
end
function F.Refresh()
    if not ns.Active('chat') then
        for region,state in pairs(styled) do Restore(region,state) end
        return
    end
    for frame in pairs(frames) do
        local path,size,flags=Font(frame)
        if path and (not frame.IsShown or frame:IsShown()) then
            local visited=0
            local function Scan(object,depth)
                if visited>=256 or depth>3 or not Safe(object) then return end
                visited=visited+1
                if object.GetObjectType and object:GetObjectType()=='FontString' and object.GetText and object.SetFont then
                    local text=ns.SafeCall(object.GetText,object);local state=styled[object]
                    if CoveredRoman(text) then
                        local current,height,outline=Font(object)
                        if current and (current~=path or height~=size or outline~=flags) then
                            if not state then
                                local fontObject=object.GetFontObject and ns.SafeCall(object.GetFontObject,object)
                                state={path=current,size=height,flags=outline,object=ns.Readable(fontObject) and fontObject or nil,frame=frame}
                            end
                            local ok,result=pcall(object.SetFont,object,path,size,flags)
                            if ok and result~=false then
                                state.appliedPath,state.appliedSize,state.appliedFlags=path,size,flags;styled[object]=state
                            end
                        end
                    elseif state then Restore(object,state) end
                    return
                end
                for _,method in ipairs({'GetRegions','GetChildren'}) do
                    if object[method] then
                        local values={pcall(object[method],object)}
                        if values[1] then for i=2,#values do Scan(values[i],depth+1) end end
                    end
                end
            end
            Scan(frame,0)
        end
    end
end
local elapsed=0
local update=CreateFrame('Frame')
update:SetScript('OnUpdate',function(_,dt)
    elapsed=elapsed+dt;if elapsed<0.25 then return end;elapsed=0
    if next(frames) or next(styled) then F.Refresh() end
end)
