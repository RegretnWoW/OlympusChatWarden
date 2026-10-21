local _, ns = ...
local T = {}
ns.Theme = T
local uiSounds={open='IG_CHARACTER_INFO_OPEN',close='IG_CHARACTER_INFO_CLOSE',tab='IG_CHARACTER_INFO_TAB',button='IG_MAINMENU_OPTION_CHECKBOX_ON'}
local soundSerial=0
function T.UISound(kind)
    local kit=type(SOUNDKIT)=='table' and SOUNDKIT[uiSounds[kind] or '']
    -- Use the client's own kits and normal sound settings. Unsupported clients
    -- remain silent; no guessed sound IDs or forced audio channels.
    if type(PlaySound)~='function' or type(kit)~='number' then return end
    local ok=pcall(PlaySound,kit);if ok then soundSerial=soundSerial+1 end
end
function T.ClickSound(button,kind)
    if button.WardenClickSoundBound then return end
    button.WardenClickSoundBound=true;button.WardenClickSound=kind or 'button'
    local set=button.SetScript
    button.SetScript=function(self,event,fn)
        if event=='OnClick' and type(fn)=='function' then
            local handler=fn
            fn=function(...)
                local serial=soundSerial
                local a,b,c,d=handler(...)
                -- Opening/closing a window already supplies the correct sound.
                if serial==soundSerial and (not self.IsEnabled or self:IsEnabled()) then T.UISound(self.WardenClickSound) end
                return a,b,c,d
            end
        end
        return set(self,event,fn)
    end
    local click=button:GetScript('OnClick');if click then button:SetScript('OnClick',click) end
end
function T.WindowScale(width,height)
    local parentScale=UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if type(parentScale)~='number' or parentScale~=parentScale or parentScale<=0 then parentScale=1 end
    local fit=math.min((UIParent:GetWidth()-26)/width,(UIParent:GetHeight()-26)/height)
    return math.max(.1,math.min(1.5,1/parentScale,fit)),math.max(.1,fit)
end
function T.FitWindow(frame,width,height)
    local scale=T.WindowScale(width,height)
    local current=frame.GetScale and frame:GetScale() or frame.ChatWardenWindowScale
    if not current or math.abs(current-scale)>.0001 then frame:SetScale(scale);frame.ChatWardenWindowScale=scale end
    return scale
end
function T.CaptureBadge(host)
    local badge = CreateFrame("Frame", nil, host)
    badge:SetSize(14, 14); badge:EnableMouse(false)
    local ring = badge:CreateTexture(nil, "ARTWORK")
    ring:SetAllPoints(badge); ring:SetTexture("Interface\\Buttons\\WHITE8X8")
    ring:SetVertexColor(0.90, 0.68, 0.28, 1)
    local center = badge:CreateTexture(nil, "OVERLAY")
    center:SetPoint("TOPLEFT", 2, -2); center:SetPoint("BOTTOMRIGHT", -2, 2)
    center:SetColorTexture(0.75, 0.06, 0.035, 1)
    local mark = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mark:SetAllPoints(badge); mark:SetText("!"); mark:SetTextColor(1, 0.93, 0.65, 1)
    return badge
end
T.Icon = "Interface\\AddOns\\OlympusChatWarden\\Media\\IconScroll.tga"
function T.DocumentFont(text,size)
    text.ChatWardenFontSize=size or 14
    local family=_G['ChatWardenFont'..tostring(size or 14)]
    text.ChatWardenFontFamily=family
    if family then text:SetFontObject(family);return true end
    return false
end
-- Addon documents and inputs use Blizzard's regular UI font, not the user's
-- independently styled chat font. Native chat and world labels keep their fonts.
function T.Body(text)
    if not T.DocumentFont(text,14) then
    text:SetFontObject(GameFontHighlight or 'GameFontHighlight')
    -- EditBoxes can retain an inherited outline/font override after SetFontObject.
    -- Copy the regular label's actual font and explicitly clear all outline flags.
    local font=GameFontHighlightSmall or GameFontHighlight
    local path=font and font.GetFont and font:GetFont()
    if text.SetFont then text:SetFont(path or 'Fonts\\FRIZQT__.TTF',14,'') end
    end
    if text.SetShadowOffset then text:SetShadowOffset(0,0) end
    if text.SetSpacing then text:SetSpacing(3) end
    return text
end
-- Keep each original/name separate from explanatory UI text. On some clients
-- Unicode changes the font fallback for an entire EditBox, including Latin
-- text. Independent sections keep that fallback local to the original.
local readerColors={
    paper={body={.20,.14,.09},quote={.15,.11,.07},title={.31,.15,.055},heading={.37,.20,.08},meta={.39,.32,.25},accent={.10,.29,.40},warning={.48,.25,.025},danger={.58,.12,.09},success={.17,.34,.13}},
    dark={body={.93,.92,.88},quote={.96,.93,.85},title={.96,.82,.62},heading={.96,.82,.62},meta={.77,.80,.83},accent={.4,.75,1},warning={1,.72,.28},danger={1,.4,.34},success={.42,.82,.39}},
}
local function DocumentPlain(value)
    return (value or ''):gsub('|H.-|h(.-)|h','%1'):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('|T.-|t',''):gsub('|A.-|a',''):gsub('|','||')
end
function T.ParagraphBlocks(text)
    local blocks={};local paragraph={}
    local function Flush()
        if #paragraph>0 then blocks[#blocks+1]={text=table.concat(paragraph,'\n'),kind='body'};paragraph={} end
    end
    for line in ((text or '')..'\n'):gmatch('(.-)\n') do
        if line:match('^%s*$') then Flush()
        elseif line:match('^[A-Z][A-Z /&:0-9%-]+$') then
            Flush();local heading=line:lower():gsub('^%l',string.upper)
            if line=='OLYMPUS CHATWARDEN' then heading='Welcome to ChatWarden' end
            blocks[#blocks+1]={text=heading,kind='heading'}
        elseif line:match('^%d+%. ') then Flush();blocks[#blocks+1]={text=line,kind='body'}
        elseif line:match('^(Messages):') or line:match('^(Shield):') or line:match('^(Mentions):') or line:match('^(Chat capture):') then
            Flush();local label,body=line:match('^([^:]+):%s*(.*)$')
            blocks[#blocks+1]={text=label,kind='accent'};blocks[#blocks+1]={text=body,kind='body',gap=12}
        else paragraph[#paragraph+1]=line end
    end
    Flush();return blocks
end
function T.ReadOnlyDocument(scroll)
    local doc=CreateFrame('Frame',nil,scroll);doc.boxes={};doc.parts={};doc.blocks={};doc.style='dark'
    doc:SetSize(math.max(1,scroll:GetWidth()),math.max(1,scroll:GetHeight()));scroll:SetScrollChild(doc)
    local fitting=false
    local function Apply(box)
        T.Body(box);local path=box:GetFont()
        local kind=box.blockKind or 'body';local size=kind=='title' and 24 or kind=='heading' and 20 or kind=='quote' and 17 or kind=='meta' and 14 or 16
        if not T.DocumentFont(box,size) then box:SetFont(path,size,'') end;if box.SetSpacing then box:SetSpacing(3) end
        box:SetTextColor(unpack((readerColors[doc.style] or readerColors.dark)[box.blockTone or kind] or readerColors.dark.body))
    end
    local function Fit()
        if fitting then return end;fitting=true
        local width=math.max(1,scroll:GetWidth()-8);local y=0;doc:SetWidth(width)
        for i,block in ipairs(doc.blocks) do
            local box=doc.boxes[i];local text=box.original or ''
            box:ClearAllPoints();box:SetPoint('TOPLEFT',0,-y);box:SetWidth(width)
            local path,size,flags=box:GetFont();if not T.DocumentFont(box.measure,size) and path then box.measure:SetFont(path,size,flags) end
            if box.measure.SetSpacing then box.measure:SetSpacing(3) end
            box.measure:SetWidth(width);box.measure:SetText(text)
            local _,newlines=text:gsub('\n','')
            -- Native EditBox layout can differ slightly from its FontString
            -- measurer. Allow a line of slack instead of clipping the last wrap.
            local height=math.max((newlines+1)*(size+3),(box.measure:GetStringHeight() or 0)+size+8)
            box:SetHeight(height);y=y+height+(block.gap or (block.kind=='heading' and 9 or 14))
        end
        doc:SetHeight(math.max(scroll:GetHeight(),y))
        if scroll.ChatWardenUpdateScrollRange then scroll.ChatWardenUpdateScrollRange(math.max(0,doc:GetHeight()-scroll:GetHeight())) end
        local offset=scroll:GetVerticalScroll() or 0
        if offset>math.max(0,doc:GetHeight()-scroll:GetHeight()) then scroll:SetVerticalScroll(math.max(0,doc:GetHeight()-scroll:GetHeight())) end
        fitting=false
    end
    function doc:SetStyle(style)
        self.style=readerColors[style] and style or 'dark'
        for _,box in ipairs(self.boxes) do Apply(box) end;Fit()
    end
    function doc:SetBlocks(blocks,sourceText)
        local same=#blocks==#self.blocks
        if same then for i,block in ipairs(blocks) do
            if type(block)=='string' then block={text=block} end
            local old=self.blocks[i]
            local text=block.literal and (block.text or ''):gsub('|','||') or DocumentPlain(block.text)
            if old.text~=text or old.kind~=(block.kind or 'body') or old.gap~=block.gap or old.tone~=block.tone
                or old.tooltip~=block.tooltip or old.tooltipTitle~=block.tooltipTitle then same=false;break end
        end end
        if same then self.sourceText=sourceText and DocumentPlain(sourceText);return end
        self.blocks={};self.parts={};self.sourceText=sourceText and DocumentPlain(sourceText)
        for i,block in ipairs(blocks) do
            if type(block)=='string' then block={text=block} end
            local text=block.literal and (block.text or ''):gsub('|','||') or DocumentPlain(block.text)
            self.blocks[i]={text=text,kind=block.kind or 'body',gap=block.gap,tone=block.tone,tooltip=block.tooltip,tooltipTitle=block.tooltipTitle}
            local box=self.boxes[i]
            if not box then
                box=CreateFrame('EditBox',nil,self);self.boxes[i]=box;box.ChatWardenNoSpelling=true;box.ChatWardenArtStyled=true
                box:SetMultiLine(true);box:SetAutoFocus(false);T.TextField(box)
                box.measure=box:CreateFontString(nil,'OVERLAY');box.measure:SetWordWrap(true);if box.measure.SetNonSpaceWrap then box.measure:SetNonSpaceWrap(true) end;box.measure:Hide()
                box:SetScript('OnEscapePressed',function(b) b:ClearFocus() end)
                box:HookScript('OnTextChanged',function(b,user) if user then b:SetText(b.original or '');Apply(b) end end)
            end
            self.parts[i]=text;box.original=text;box.blockKind=block.kind or 'body';box.blockTone=block.tone
            if block.tooltip then T.Tooltip(box,block.tooltipTitle or text,block.tooltip)
            else box:SetScript('OnEnter',nil);box:SetScript('OnLeave',nil) end
            if box:GetText()~=text then box:SetText(text);box:ClearFocus() end
            Apply(box);box:Show()
        end
        for i=#blocks+1,#self.boxes do self.boxes[i]:Hide();self.boxes[i]:ClearFocus() end
        Fit()
    end
    function doc:SetSections(parts)
        local blocks={};for _,text in ipairs(parts) do
            local trimmed=text:match('^%s*(.-)%s*$')
            local kind=text:match('^\n.+\n$') and 'heading' or 'body'
            blocks[#blocks+1]={text=kind=='heading' and trimmed or text,kind=kind}
        end
        self:SetBlocks(blocks,table.concat(parts,'\n'))
    end
    function doc:SetMarkup(index,markup)
        local box=self.boxes[index];if box then box.original=markup;box:SetText(markup);Apply(box);Fit() end
    end
    function doc:GetText() return self.sourceText or table.concat(self.parts,'\n') end
    function doc:ClearFocus() for _,box in ipairs(self.boxes) do box:ClearFocus() end end
    scroll:HookScript('OnSizeChanged',Fit);scroll:HookScript('OnShow',Fit)
    return doc
end
-- Cover the whole editor/viewport with its own native click surface. Never
-- overlay the scrollbar or another field, or replace caret/selection handling.
function T.TextField(edit, scroll)
    T.Body(edit)
    if edit.ChatWardenTextField then return end
    edit.ChatWardenTextField = true
    local function Focus(_, button)
        if button ~= "LeftButton" or not edit:IsVisible()
            or edit.IsEnabled and not ns.Checked(edit:IsEnabled()) then return end
        edit:SetFocus()
    end
    edit:EnableMouse(true)
    edit:HookScript("OnMouseDown", Focus)
    if not scroll then
        if edit.SetHitRectInsets then edit:SetHitRectInsets(-4, -4, -3, -3) end
        return
    end
    scroll:EnableMouse(true); scroll:HookScript("OnMouseDown", Focus)
    local measure = edit:CreateFontString(nil, "OVERLAY")
    measure:Hide(); measure:SetWordWrap(true)
    if measure.SetNonSpaceWrap then measure:SetNonSpaceWrap(true) end
    local fitting = false
    local function Fit()
        if fitting then return end
        local width, height = scroll:GetWidth(), scroll:GetHeight()
        if not width or width <= 0 or not height or height <= 0 then return end
        fitting = true
        local font, size, flags = edit:GetFont()
        if font then measure:SetFont(font, size, flags) else T.Body(measure) end
        if measure.SetSpacing and edit.GetSpacing then measure:SetSpacing(edit:GetSpacing()) end
        measure:SetWidth(math.max(1, width - 10)); measure:SetText(edit:GetText() or "")
        edit:SetWidth(width)
        local content = math.max(height, (measure:GetStringHeight() or 0) + 12)
        edit:SetHeight(content)
        local offset = scroll:GetVerticalScroll() or 0
        if offset > math.max(0, content - height) then scroll:SetVerticalScroll(math.max(0, content - height)) end
        fitting = false
    end
    edit:HookScript("OnTextChanged", Fit)
    edit:HookScript("OnShow", Fit)
    scroll:HookScript("OnSizeChanged", Fit)
    scroll:HookScript("OnShow", Fit)
    edit.ChatWardenFitText = Fit
    Fit()
end
local windows, registered, focusHooks = {}, {}, setmetatable({}, {__mode = "k"})
local restacking, focusRevision = false, 0
local pendingFocus, deferred = {}, {}
local focused, switching = nil, false
local popups = setmetatable({}, {__mode = 'k'})
local function Owner(frame)
    for _=1,32 do
        if not frame then return end
        if registered[frame] then return frame end
        frame=frame.GetParent and frame:GetParent()
        if frame==UIParent then return end
    end
end
function T.RegisterPopup(control,close) popups[control]=close end
local function ClosePopups(except)
    for control,close in pairs(popups) do
        if not except or Owner(control)~=except then close() end
    end
end
local deferFrame
local function AfterClick(callback)
    if C_Timer and C_Timer.After then C_Timer.After(0, callback); return end
    deferred[#deferred + 1] = callback
    if not deferFrame then deferFrame = CreateFrame("Frame") end
    deferFrame:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        local callbacks = deferred; deferred = {}
        for _, fn in ipairs(callbacks) do fn() end
    end)
end
local function QueueFocus(root)
    if pendingFocus[root] then return end
    local revision = focusRevision
    pendingFocus[root] = true
    AfterClick(function()
        pendingFocus[root] = nil
        -- An OnClick may open a different window or close this one. Do not
        -- steal focus back from that action when the deferred callback runs.
        if revision == focusRevision and root:IsShown() then T.FocusWindow(root) end
    end)
end

local function WindowFrames(root)
    local frames = {}
    local function Collect(frame, offset)
        frames[#frames + 1] = {frame = frame, offset = offset}
        if frame.IsMouseEnabled and frame:IsMouseEnabled() and not focusHooks[frame] then
            focusHooks[frame] = true
            -- Only hook existing input surfaces. Mouse hooks on decorative frames
            -- can enable their hit tests; the full-window NineSlice would then
            -- swallow clicks above our controls. Keep passive layers passive.
            -- Changing frame levels while a button is pressed can invalidate
            -- its native click target. Wait until OnMouseUp/OnClick finish.
            frame:HookScript("OnMouseUp", function() QueueFocus(root) end)
            frame:HookScript("OnDragStop", function() QueueFocus(root) end)
        end
        for _, child in ipairs({frame:GetChildren()}) do
            if child:GetFrameStrata() ~= "TOOLTIP" and not (child.IsForbidden and child:IsForbidden())
                and not (child.IsProtected and child:IsProtected()) then
                local relative = math.max(1, child:GetFrameLevel() - frame:GetFrameLevel())
                Collect(child, offset + relative)
            end
        end
    end
    Collect(root, 0)
    -- Native portrait/border templates reserve offsets of 400–510. Preserve
    -- their ordering without carrying those large gaps into every window.
    local levels, seen, ranks = {}, {}, {}
    for _, item in ipairs(frames) do
        if not seen[item.offset] then seen[item.offset] = true; levels[#levels + 1] = item.offset end
    end
    table.sort(levels)
    for i, level in ipairs(levels) do ranks[level] = i - 1 end
    for _, item in ipairs(frames) do item.offset = ranks[item.offset] end
    return frames, #levels - 1
end

-- Keep complete window trees in separate, bounded level ranges. Raising only
-- the root lets an older window's nested controls draw through the new window.
function T.FocusWindow(root)
    if restacking or switching or not registered[root] or not root:IsShown() then return end
    focusRevision = focusRevision + 1
    restacking = true
    if focused~=root then ClosePopups(root);focused=root end
    for i, frame in ipairs(windows) do
        if frame == root then table.remove(windows, i); break end
    end
    windows[#windows + 1] = root
    local ok, errorMessage = pcall(function()
        local level = 20
        for _, window in ipairs(windows) do
          if window:IsShown() then
            local frames, highest = WindowFrames(window)
            -- A complete focused window belongs to a higher strata than every
            -- background window, including native decoration and nested text.
            -- This prevents lower controls from piercing its opaque backing.
            local strata = window == root and "DIALOG" or "HIGH"
            for _, item in ipairs(frames) do
                -- Fixed layers reject reassignment on native frames. Unlock
                -- BEFORE moving them, then lock the completed ordering. Locking
                -- first left old parchment/controls above the new window while
                -- its title and border appeared to have moved correctly.
                if item.frame.SetFixedFrameStrata then item.frame:SetFixedFrameStrata(false) end
                if item.frame.SetFixedFrameLevel then item.frame:SetFixedFrameLevel(false) end
                if item.frame:GetFrameStrata() ~= strata then item.frame:SetFrameStrata(strata) end
                if item.frame:GetFrameLevel() ~= level + item.offset then item.frame:SetFrameLevel(level + item.offset) end
                if item.frame.SetFixedFrameStrata then item.frame:SetFixedFrameStrata(true) end
                if item.frame.SetFixedFrameLevel then item.frame:SetFixedFrameLevel(true) end
            end
            level = level + highest + 4
          end
        end
    end)
    restacking = false
    if not ok and geterrorhandler then geterrorhandler()(errorMessage) end
end
function T.RegisterWindow(frame,external)
    if registered[frame] then return end
    if frame.IsProtected and frame:IsProtected() or frame.IsForbidden and frame:IsForbidden() then return end
    if not external then frame:Hide();frame:SetFrameStrata("DIALOG") end
    -- Explicit focus management keeps the full tree together. Native automatic
    -- raising on mouse-down would bypass the safe, deferred click lifecycle.
    if frame.SetToplevel then frame:SetToplevel(false) end
    registered[frame] = external and 'external' or true; windows[#windows + 1] = frame
    local soundShown=frame:IsShown()
    -- Method hooks survive later SetScript calls in individual windows.
    -- OnShow/OnHide hooks do not: Review and Personal install their scripts
    -- after this constructor, wiping the former navigation handlers.
    hooksecurefunc(frame, "Show", function()
        local shown=frame:IsShown()
        if not external and shown and not soundShown and not switching then T.UISound('open') end
        soundShown=shown
        if switching then return end
        T.FocusWindow(frame)
    end)
    hooksecurefunc(frame, "Hide", function()
        local shown=frame:IsShown()
        if not external and not shown and soundShown and not switching then T.UISound('close') end
        soundShown=shown
        if switching then return end
        for control,close in pairs(popups) do if Owner(control)==frame then close() end end
        if focused~=frame then return end
        focused=nil
        for i = #windows - 1, 1, -1 do
            if windows[i]:IsShown() then T.FocusWindow(windows[i]); break end
        end
    end)
end
function T.ShowWindow(frame)
    if not frame.ChatWardenPlaced then
        local count=0;for _,other in ipairs(windows) do if other~=frame and other:IsShown() then count=count+1 end end
        if count>0 then frame:ClearAllPoints();frame:SetPoint('CENTER',UIParent,'CENTER',math.min(count,4)*24,-math.min(count,4)*24) end
        frame.ChatWardenPlaced=true
    end
    if frame:IsShown() then T.FocusWindow(frame) else frame:Show() end
end
function T.HideAll()
    switching = true
    focused = nil;ClosePopups()
    focusRevision = focusRevision + 1
    for _, frame in ipairs(windows) do if registered[frame]~='external' then frame:Hide() end end
    switching = false
end
-- Settings uses Blizzard's own root rather than our portrait-frame stack.
-- Keep accessible Settings windows in the same stack without closing them.
function T.BindSettings(panel)
    if ns.Membership and ns.Membership.RegisterSettings then ns.Membership.RegisterSettings(panel) end
    panel:HookScript("OnShow", function()
        local root = SettingsPanel or SettingsFrame
        if not root or not root.HookScript then return end
        if not root.ChatWardenNavigation then
            root.ChatWardenNavigation = true
            T.RegisterWindow(root,true)
        end
        T.FocusWindow(root)
    end)
end
T.Sources = {{"all", "All sources"}, {"player", "Player chat"}, {"npc", "NPC chat"},
    {"bubble", "Chat bubbles"}, {"quest", "Quests"}, {"gossip", "NPC dialogue"},
    {"vendor", "Vendor text"}, {"playerName", "Player names"}, {"npcName", "NPC names"}, {"targetName", "Target-frame names"}, {"barber", "Barber shop"}, {"talkingHead", "Talking heads"}, {"demo", "Preview test"},
    {"tooltip", "Tooltips"}, {"manual", "Other / pasted text"}}
T.Actions = {{"Unchanged", "Keep visible"}, {"Warning", "Show with a warning"},
    {"Redacted", "Redact matched words"}, {"Hidden", "Hide the message"}}
T.RuleActions = {{"Unchanged", "Keep visible"}, {"Warning", "Show with a warning"},
    {"Redacted", "Redact matched words"}, {"Hidden", "Hide the message"}, {"Replaced", "Replace with text"}}
local function Parchment(texture)
    if C_Texture and C_Texture.GetAtlasInfo and texture.SetAtlas
        and C_Texture.GetAtlasInfo("QuestBG-Parchment") then
        texture:SetAtlas("QuestBG-Parchment")
    elseif not texture:SetTexture("Interface\\QuestFrame\\QuestBG") then
        texture:SetTexture("Interface\\LFGFrame\\UI-LFG-BACKGROUND-QUESTPAPER")
    end
end
function T.Ink(text)
    text:SetTextColor(0.18, 0.12, 0.065, 1)
    if text.SetShadowColor then text:SetShadowColor(0, 0, 0, 0) end
    return text
end
function T.Gold(text) text:SetTextColor(1, 0.82, 0.39, 1); return text end
function T.Light(text) text:SetTextColor(0.89, 0.86, 0.78, 1); return text end
function T.Muted(text) text:SetTextColor(0.64, 0.65, 0.61, 1); return text end
function T.Heading(text) T.Ink(text); text:SetTextColor(0.37, 0.20, 0.075, 1); return text end
function T.Label(choices, value)
    if value == "Replaced" then return "Replace with text" end
    for _, choice in ipairs(choices) do if choice[1] == value then return choice[2] end end
    return value and tostring(value) or ""
end

-- The same Blizzard metal/portrait frame used by the official Olympus window.
function T.Window(name, parent, width, height)
    local ok, frame = pcall(CreateFrame, "Frame", name, parent, "PortraitFrameTemplate")
    if not ok or not frame then frame = CreateFrame("Frame", name .. "Basic", parent, "BasicFrameTemplateWithInset") end
    frame.ChatWardenOwned = true
    frame:SetSize(width, height); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true); frame:SetMovable(true); frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving); frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if frame.CloseButton then frame.CloseButton:SetScript("OnClick", function() frame:Hide() end) end
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = frame:GetName() end
    T.SkinWindow(frame); T.RegisterWindow(frame); return frame
end
function T.Title(frame, text)
    if frame.SetTitle then frame:SetTitle(text)
    elseif frame.TitleText then frame.TitleText:SetText(text)
    elseif frame.TitleContainer and frame.TitleContainer.TitleText then frame.TitleContainer.TitleText:SetText(text) end
end
function T.SkinWindow(frame, top, bottom)
    -- Classic PortraitFrameTemplate also inherits the newer NineSlice border.
    -- Keep one border system: the legacy textures already match the guild UI.
    if frame.RightBorder and frame.LeftBorder and frame.TopBorder and frame.NineSlice then
        frame.NineSlice:Hide()
    end
    -- Native dialog textures include transparency. Fill their interior so a
    -- lower window cannot show through header/footer gaps or dark panels.
    local backing = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    backing:SetPoint("TOPLEFT", 6, -6); backing:SetPoint("BOTTOMRIGHT", -6, 6)
    backing:SetColorTexture(0.055, 0.05, 0.04, 1); frame.OlympusBacking = backing
    if frame.SetBackdrop then
        frame:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true,
            tileSize = 32, edgeSize = 16, insets = {left = 4, right = 4, top = 4, bottom = 4}})
        frame:SetBackdropColor(0.48, 0.48, 0.48, 1); frame:SetBackdropBorderColor(0.62, 0.62, 0.62, 1)
    end
    if frame.Inset then frame.Inset:Hide() end
    local dark = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    dark:SetPoint("TOPLEFT", 6, -60); dark:SetPoint("BOTTOMRIGHT", -6, 26)
    dark:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
    dark:SetVertexColor(0.34, 0.34, 0.34, 1); frame.OlympusDark = dark
    if top then
        local paper = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
        paper:SetPoint("TOPLEFT", 8, -top); paper:SetPoint("BOTTOMRIGHT", -8, bottom or 46)
        Parchment(paper); frame.OlympusPaper = paper
    end
end
function T.Crest(frame, x, y, size)
    local portrait = frame.portrait or frame.Portrait
        or (frame.PortraitContainer and frame.PortraitContainer.portrait)
    if portrait then
        portrait:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        portrait:SetTexCoord(0, 1, 0, 1)
        local portraitParent = portrait:GetParent() or frame
        local crest = frame.OlympusCrest or portraitParent:CreateTexture(nil, "OVERLAY", nil, 1)
        frame.OlympusCrest = crest
        crest:ClearAllPoints(); crest:SetPoint("CENTER", portrait, "CENTER")
        crest:SetSize(portrait:GetWidth() * 0.80, portrait:GetHeight() * 0.80)
        crest:SetTexture(T.Icon); crest:SetTexCoord(0, 1, 0, 1)
        return crest
    end
    local badge = CreateFrame("Frame", nil, frame)
    badge:SetSize(size or 44, size or 44); badge:SetPoint("TOPLEFT", x or 18, y or -10)
    local scale = (size or 44) / 31
    local background = badge:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20 * scale, 20 * scale); background:SetPoint("TOPLEFT", 7 * scale, -5 * scale)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local crest = badge:CreateTexture(nil, "ARTWORK")
    crest:SetAllPoints(background); crest:SetTexture(T.Icon); crest:SetTexCoord(0, 1, 0, 1)
    local border = badge:CreateTexture(nil, "OVERLAY")
    border:SetSize(53 * scale, 53 * scale); border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    frame.OlympusCrest, frame.OlympusCrestBorder = crest, border
    return crest
end
function T.MinimapCrest(button)
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20); background:SetPoint("TOPLEFT", 7, -5)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    button:SetNormalTexture(T.Icon)
    local icon = button:GetNormalTexture()
    icon:ClearAllPoints(); icon:SetSize(20, 20); icon:SetPoint("TOPLEFT", 7, -5)
    icon:SetTexCoord(0, 1, 0, 1)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53); border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.OlympusCrestBorder = border
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
end
function T.Panel(parent, x, y, width, height, paper)
    local panel = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    panel:SetFrameLevel(parent:GetFrameLevel() + 1)
    panel:SetPoint("TOPLEFT", x, y); panel:SetSize(width, height)
    if paper then
        local texture = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
        texture:SetPoint("TOPLEFT", 3, -3); texture:SetPoint("BOTTOMRIGHT", -3, 3)
        Parchment(texture); panel.OlympusPaper = texture
    end
    return panel
end
-- Shared styling for preview and report windows.
function T.Inset(parent, region)
    local fill = parent:CreateTexture(nil, "BACKGROUND", nil, 2)
    fill:SetPoint("TOPLEFT", region, "TOPLEFT", -8, 8)
    fill:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 8, -8)
    Parchment(fill); return fill
end
local actionHelp = {
    ['Settings']='Choose your filters and text areas. Open the Shield section for contact protection.',
    ['Messages']='Read the original text of messages caught by the filter. Selecting a message clears its unread badge.',
    ['Shield']='See contact alerts and manage shielded or allowed players.',
    ['Why filtered?']='See which words matched and why ChatWarden chose this result.',
    ['My rules']='Add or change phrase rules that work just for you.',
    ['My reports']='Review the examples you saved. Reports stay saved until you delete them.',
    ['Saved reports']='Review the examples you saved. Reports stay saved until you delete them.',
    ['Report a missed message']='Choose a recent message or paste the one the filter missed.',
    ['Report a miss']='Choose a recent message or paste the one the filter missed.',
    ['Report a problem']='Tell us what should have happened to this message. Saving a report alone does not change your filter.',
    ['New rule']='Choose an exact phrase and what you want ChatWarden to do when it appears.',
    ['Save personal rule']='Save this phrase and action. The rule will apply to future matching text.',
    ['Delete report']='Delete the selected saved item. Any phrase rule made from a report stays separate. Click again to confirm.',
    ['Save report']='Keep this example on your account. Nothing is sent. A phrase rule is added only if you checked that option.',
    ['Export reports']='Open your saved reports as text you can copy. Check for names or personal details before sharing.',
    ['Send feedback']='Show the GitHub issue-page link for you to copy. Nothing is posted for you.',
    ['Rule packs']='See your installed categories, change their settings, or paste a new pack.',
    ['Sensitivity']='Choose how much wording gets caught in each category. Default follows your main setting.',
    ['Manage / import packs']='See your installed categories or paste a new pack.',
    ['Verify pack']='Check the publisher and make sure the pasted pack has not been changed. Click again to cancel a running check.',
    ['Install pack']='Install the pack shown in the preview. It starts filtering only if Enable pack after install is checked.',
    ['Remove pack']='Remove this optional pack. Your reports and personal rules stay saved. Click again to confirm.',
    ['Export signed pack']='Copy this installed pack so someone else can import the same publisher-issued text.',
    ['Get packs link']='Show the pack download-page link to copy into your browser. Packs are not downloaded automatically.',
    ['Paste import']='Paste the full text from one pack file, then verify it before installing.',
    ['Try preview']='Try a few sample messages using your current filter settings.',
    ['Preview test']='Try a few sample messages using your current filter settings.',
    ['Review messages']='Open Messages to read captured originals. Use its Shield tab to manage players.',
}
function T.ActionHelp(owner,label)
    if actionHelp[label] then T.Tooltip(owner,label,actionHelp[label]) end
end
function T.Tooltip(owner, title, description)
    owner:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(title)
        GameTooltip:AddLine(description, 0.9, 0.9, 0.85, true); GameTooltip:Show()
    end)
    owner:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end
function T.StatTooltip(region,title,description,onClick)
    local hover=CreateFrame(onClick and 'Button' or 'Frame',nil,region:GetParent());hover:SetAllPoints(region);hover:EnableMouse(true)
    if hover.SetFrameLevel then hover:SetFrameLevel(region:GetParent():GetFrameLevel()+1) end
    if hover.SetMouseMotionEnabled then hover:SetMouseMotionEnabled(true) end
    if onClick then hover:SetScript('OnClick',onClick)
    elseif hover.SetMouseClickEnabled then hover:SetMouseClickEnabled(false) end
    T.Tooltip(hover,title,description);return hover
end

-- Native radio dropdown, with a list fallback for clients lacking DropdownButton.
function T.Dropdown(parent, x, y, width, choices, getValue, setValue)
    local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    local native = ok and dropdown and dropdown.SetupMenu
    if not native then
        if ok and dropdown then dropdown:Hide() end
        dropdown = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    end
    dropdown:SetSize(width, 26); dropdown:SetPoint("TOPLEFT", x, y)
    local popup
    function dropdown:Refresh()
        local label = T.Label(choices, getValue())
        if native then self:SetDefaultText(label); self:GenerateMenu()
        else self:SetText(label .. "  v"); if popup then popup:Hide() end end
    end
    local function Choose(value) setValue(value); dropdown:Refresh() end
    local function Generate(_, root)
        for _, choice in ipairs(choices) do
            root:CreateRadio(choice[2], function(value) return getValue() == value end, Choose, choice[1])
        end
    end
    if native then dropdown:SetupMenu(Generate)
    else
        dropdown:SetScript("OnClick", function(self)
            if MenuUtil and MenuUtil.CreateContextMenu then MenuUtil.CreateContextMenu(self, Generate); return end
            if not popup then
                popup = CreateFrame("Frame", nil, self, "BackdropTemplate")
                popup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
                popup:SetFrameStrata("TOOLTIP")
                popup:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 32, edgeSize = 12,
                    insets = {left = 3, right = 3, top = 3, bottom = 3}})
                popup.items = {}
                self:HookScript("OnHide", function() popup:Hide() end); popup:Hide()
            end
            if popup:IsShown() then popup:Hide(); return end
            popup:SetSize(width, #choices * 24 + 8)
            -- Report actions and recent-message choices can change while the
            -- form is reused. Reuse controls, but refresh their current values.
            for i, choice in ipairs(choices) do
                local item = popup.items[i]
                if not item then
                    item = CreateFrame("Button", nil, popup); popup.items[i] = item
                    item:SetSize(width - 8, 24); item:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 24)
                    item:SetNormalFontObject(GameFontHighlightSmall)
                    item:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                    item:SetScript("OnClick", function(control) Choose(control.value); popup:Hide() end)
                end
                item.value = choice[1]; item:SetText(choice[2]); item:Show()
            end
            for i = #choices + 1, #popup.items do popup.items[i]:Hide() end
            popup:Show()
        end)
    end
    T.RegisterPopup(dropdown,function()
        if popup then popup:Hide() end
        if dropdown.CloseMenu then ns.SafeCall(dropdown.CloseMenu,dropdown) end
    end)
    dropdown:Refresh(); return dropdown
end
function T.SkinRow(row)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    local highlight = row:GetHighlightTexture(); if highlight then highlight:SetAlpha(0.25) end
    row.stripe = row:CreateTexture(nil, "ARTWORK")
    row.stripe:SetWidth(3); row.stripe:SetPoint("TOPLEFT", 0, -2); row.stripe:SetPoint("BOTTOMLEFT", 0, 2)
end
function T.RowState(row, selected, action)
    row.background:SetColorTexture(selected and 0.26 or 0.09, selected and 0.22 or 0.09,
        selected and 0.12 or 0.09, selected and 0.95 or 0.48)
    T.Light(row.label)
    if action == "Hidden" then row.stripe:SetColorTexture(0.78, 0.22, 0.17, 1)
    elseif action == "Redacted" then row.stripe:SetColorTexture(0.88, 0.57, 0.19, 1)
    else row.stripe:SetColorTexture(0.69, 0.64, 0.31, 1) end
end
