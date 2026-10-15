-- Inline bars and readable subdued text share the exact same match ranges.
local _, ns = ...
-- Same opaque bronze for inline bars and native cover overlays.
-- Media/Bar.tga stores these RGB bytes so inline textures need no tint API.
ns.RedactionColor={166/255,108/255,59/255,1}
local measure, wrapMeasure
-- Labels refresh often; cache only ephemeral display strings, never decisions.
local barCache,barOrder,barBytes={}, {},0
local function Remember(key,value)
    local bytes=#key+#value
    if bytes>131072 then return value end
    while #barOrder>=128 or barBytes+bytes>131072 do
        local oldest=table.remove(barOrder,1)
        barBytes=barBytes-#oldest-#barCache[oldest];barCache[oldest]=nil
    end
    barCache[key]=value;barOrder[#barOrder+1]=key;barBytes=barBytes+bytes
    return value
end
local function Font(owner)
    local fontOwner = owner and owner.GetFont and owner or ChatFontNormal
    local path, size, flags
    if fontOwner and fontOwner.GetFont then path, size, flags = fontOwner:GetFont() end
    size = owner and ns.SafeNumber(owner.ChatWardenFontSize) or ns.SafeNumber(size) or 14
    return path,size,flags
end
local function Configure(label,path,size,flags,owner)
    if owner and owner.ChatWardenFontFamily then label:SetFontObject(owner.ChatWardenFontFamily)
    elseif ns.CanRead(path) then label:SetFont(path,size,ns.CanRead(flags) and flags or '')
    elseif ChatFontNormal then label:SetFontObject(ChatFontNormal) end
    if label.SetTextScale and owner and owner.GetTextScale then
        label:SetTextScale(ns.SafeNumber(ns.SafeCall(owner.GetTextScale,owner)) or 1)
    elseif label.SetTextScale then label:SetTextScale(1)
    end
end
function ns.BarText(original, owner, prefix)
    local path,size,flags=Font(owner)
    local available=owner and owner.GetWidth and ns.SafeNumber(ns.SafeCall(owner.GetWidth,owner)) or 0
    local wraps=available and available>0 and not (owner and owner.CanWordWrap and ns.SafeCall(owner.CanWordWrap,owner)==false)
    local context=ns.CanRead(prefix) and prefix or ''
    local scale=owner and owner.GetTextScale and ns.SafeNumber(ns.SafeCall(owner.GetTextScale,owner)) or 1
    local nonSpace=owner and owner.CanNonSpaceWrap and ns.Checked(ns.SafeCall(owner.CanNonSpaceWrap,owner)) or false
    local spacing=owner and owner.GetSpacing and ns.SafeNumber(ns.SafeCall(owner.GetSpacing,owner)) or 0
    local indent=owner and owner.GetIndentedWordWrap and ns.Checked(ns.SafeCall(owner.GetIndentedWordWrap,owner)) or false
    local key=table.concat({tostring(path),tostring(size),tostring(flags),tostring(available),tostring(wraps),
        tostring(scale),tostring(nonSpace),tostring(spacing),tostring(indent),tostring(owner and owner.ChatWardenFontFamily),tostring(#context),context,original},'\001')
    if barCache[key] then return barCache[key] end
    local height=math.max(6,math.floor(size*0.8+0.5))
    if not measure and UIParent and UIParent.CreateFontString then
        measure = UIParent:CreateFontString(nil, "OVERLAY"); measure:Hide()
    end
    if measure then
        Configure(measure,path,size,flags,owner)
        measure:SetWordWrap(false);measure:SetWidth(0)
    end
    local function Width(text)
        if measure then measure:SetText(text);return ns.SafeNumber(measure:GetStringWidth()) or #text*size*0.55 end
        return #text*size*0.55
    end
    local function Texture(text)
        local target=Width(text)
        if target<=0 then return text end
        local function Tag(width)return '|TInterface\\AddOns\\OlympusChatWarden\\Media\\Bar:'..height..':'..width..':0:0|t' end
        local width=math.max(1,math.floor(target+0.5))
        -- Inline textures may add native padding. Measure their actual advance
        -- instead of assuming their declared width equals their text footprint.
        local advance=Width(Tag(width))
        local slope=Width(Tag(width+1))-advance
        if slope>0 then width=math.max(1,math.floor(width+(target-advance)/slope+0.5)) end
        local best,bestError=width,math.abs(Width(Tag(width))-target)
        for _,candidate in ipairs({math.max(1,width-1),width+1}) do
            local delta=math.abs(Width(Tag(candidate))-target)
            if delta<bestError then best,bestError=candidate,delta end
        end
        return Tag(best)
    end
    if wraps and UIParent and UIParent.CreateFontString then
        if not wrapMeasure then wrapMeasure=UIParent:CreateFontString(nil,'OVERLAY');wrapMeasure:Hide() end
        Configure(wrapMeasure,path,size,flags,owner);wrapMeasure:SetWidth(available);wrapMeasure:SetWordWrap(true)
        if wrapMeasure.SetNonSpaceWrap then wrapMeasure:SetNonSpaceWrap(nonSpace) end
        if wrapMeasure.SetSpacing then wrapMeasure:SetSpacing(spacing) end
        if wrapMeasure.SetIndentedWordWrap then wrapMeasure:SetIndentedWordWrap(indent) end
    end
    local function Lines(text)
        if not wraps or not wrapMeasure then return 1 end
        wrapMeasure:SetText(text)
        return ns.SafeNumber(ns.SafeCall(wrapMeasure.GetNumLines,wrapMeasure))
            or ns.SafeNumber(ns.SafeCall(wrapMeasure.GetStringHeight,wrapMeasure)) or 1
    end
    -- Preserve explicit line breaks and the native word-wrap points. Adjacent
    -- covered words on the same line become a single rectangular texture.
    local result,chunk,at,line={},'',1,nil
    local function Flush()if chunk~='' then result[#result+1]=Texture(chunk);chunk='' end end
    while at<=#original do
        local first,last=original:find('%S+',at)
        if not first then Flush();result[#result+1]=original:sub(at);break end
        local gap=original:sub(at,first-1);local word=original:sub(first,last)
        local nextLine=Lines(context..original:sub(1,last))
        if gap:find('[\r\n]') or line and nextLine~=line then
            Flush();result[#result+1]=gap;chunk=word
        elseif chunk=='' then result[#result+1]=gap;chunk=word
        else chunk=chunk..gap..word end
        line=nextLine;at=last+1
    end
    Flush();return Remember(key,table.concat(result))
end

function ns.DisplayMatches(text,matches)
    local grouped={}
    for _,match in ipairs(matches) do
        local previous=grouped[#grouped]
        local gap=previous and text:sub(previous.last+1,match.first-1)
        if previous and ns.IsRedacted(previous) and ns.IsRedacted(match) and not previous.replacement and not match.replacement
            and gap:match('^[ \t]*$') then
            previous.last=match.last;previous.score=math.max(previous.score,match.score)
        else
            local copy={};for key,value in pairs(match) do copy[key]=value end
            grouped[#grouped+1]=copy
        end
    end
    return grouped
end
local function ColorTracker(text)
    local pieces, offsets, offset, index, color = ns.Engine.Segments(text), {}, 0, 1, ""
    for i, piece in ipairs(pieces) do offsets[i] = offset; offset = offset + #piece.text end
    return function(first)
        while pieces[index] and offsets[index] < first - 1 do
            local piece = pieces[index]
            if not piece.editable then
                if piece.text:match("^|c%x%x%x%x%x%x%x%x$") then color = piece.text
                elseif piece.text == "|r" then color = "" end
            end
            index = index + 1
        end
        return color
    end
end
function ns.GrayText(original, owner, restoreColor)
    local gray = "|cffb0b5bb"
    if owner and owner.GetTextColor then
        local ok, r, g, b = pcall(owner.GetTextColor, owner)
        r, g, b = ns.SafeNumber(r), ns.SafeNumber(g), ns.SafeNumber(b)
        if ok and r and g and b and (r + g + b) / 3 < 0.5 then gray = "|cff535960" end
    end
    return gray .. original .. "|r" .. (restoreColor or "")
end
function ns.RenderRedacted(text, matches, owner, links, key)
    local colorAt = ColorTracker(text)
    return ns.Engine.Render(text, ns.DisplayMatches(text,matches), function(original, match)
        local color = colorAt(match.first)
        if match.replacement then return ns.GrayText(match.replacement, owner, color) end
        if not ns.IsRedacted(match) then return original end
        local prefix=text:sub(1,match.first-1)
        if links then return ns.Marker(original, match, owner, key, color, prefix) end
        return ns.BarText(original, owner, prefix)
    end)
end
function ns.RenderRevealed(text, matches, owner)
    local colorAt = ColorTracker(text)
    return ns.Engine.Render(text, ns.DisplayMatches(text,matches), function(original, match)
        local color = colorAt(match.first)
        return match.replacement and ns.GrayText(match.replacement, owner, color)
            or ns.IsRedacted(match) and ns.GrayText(original, owner, color) or original
    end)
end
function ns.RenderSelective(text, matches, owner, revealed, link)
    local colorAt = ColorTracker(text)
    return ns.Engine.Render(text, ns.DisplayMatches(text,matches), function(original, match)
        local color = colorAt(match.first)
        if match.replacement then return ns.GrayText(match.replacement, owner, color) end
        if not ns.IsRedacted(match) then return original end
        if link then return link(original, match, color) end
        local key = tostring(match.first) .. ":" .. tostring(match.last)
        return revealed and revealed[key] and ns.GrayText(original, owner, color) or ns.BarText(original, owner,text:sub(1,match.first-1))
    end)
end
function ns.RenderWarning(text) return "|cffffbb22[!]|r " .. text end
