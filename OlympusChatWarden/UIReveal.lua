-- Wrapped labels use a FontString hyperlink copy during Ctrl. Single-line unit
-- labels use measured span buttons outside secure parents; ordinary clicks
-- remain native. Original text and per-phrase state are shared across routes.
local _, ns = ...
local U = {}; ns.LabelReveal = U
local function Active(state)
    return ns.Active(state.scope) or state.languageName and ns.Language and ns.Language.NamesActive()
end
local serial = 0
local function Key(m) return tostring(m.first) .. ':' .. tostring(m.last) end
local ConfigureInput
local function KeepNativeHover(view)
    -- Ctrl click surfaces must not take mouse-over ownership from an item
    -- button (which would fire its OnLeave and dismiss its tooltip).
    if type(view.SetMouseMotionEnabled)=='function' then
        pcall(view.SetMouseMotionEnabled,view,false)
    elseif type(view.SetPropagateMouseMotion)=='function' then
        pcall(view.SetPropagateMouseMotion,view,true)
    end
end
local function ClickEnabled(view)
    if type(view.IsMouseClickEnabled)=='function' then return ns.Checked(ns.SafeCall(view.IsMouseClickEnabled,view)) end
    return view:IsMouseEnabled()
end
local function SetClicks(view,enabled)
    if type(view.SetMouseClickEnabled)=='function' and pcall(view.SetMouseClickEnabled,view,enabled) then
        KeepNativeHover(view);return
    end
    if type(view.SetPropagateMouseMotion)=='function' then pcall(view.SetPropagateMouseMotion,view,true) end
    view:EnableMouse(enabled);KeepNativeHover(view)
end
local unitMeasure
local function Measure(region, text)
    if not unitMeasure then unitMeasure=UIParent:CreateFontString(nil,'OVERLAY'); unitMeasure:Hide() end
    local font,size,flags=region:GetFont()
    unitMeasure:SetFont(font,size,flags); unitMeasure:SetText(text)
    return ns.SafeNumber(unitMeasure:GetStringWidth())
end
local function HideUnitButtons(state)
    state.unitButtonsReady = false
    for _, button in ipairs(state.unitButtons or {}) do
        SetClicks(button,false); button:Hide(); button.pressed=nil
    end
end
local function SyncUnitButtons(region,state,active)
    if not active or not ns.RevealModifier() or not state.toggleSpan then HideUnitButtons(state); return false end
    local function Unavailable() HideUnitButtons(state); return false end
    if not state.nativeNameplate and not state.unitButtonsReady and type(IsMouseButtonDown)=='function'
        and ns.Checked(ns.SafeCall(IsMouseButtonDown,'LeftButton')) then return Unavailable() end
    -- Keep active hit targets alive between geometry refreshes. Hiding them
    -- clears the press before mouse-up, especially on moving nameplates.
    state.unitButtonsReady = false
    local ok,left,bottom,width,height=pcall(region.GetRect,region)
    left,bottom,width,height=ns.SafeNumber(left),ns.SafeNumber(bottom),ns.SafeNumber(width),ns.SafeNumber(height)
    local scale=ns.SafeNumber(ns.SafeCall(region.GetEffectiveScale,region))
    local rootScale=ns.SafeNumber(ns.SafeCall(UIParent.GetEffectiveScale,UIParent))
    local _,size=region:GetFont(); size=ns.SafeNumber(size)
    if not ok or not left or not bottom or not width or not height or not scale or not rootScale or rootScale<=0 or not size then return Unavailable() end
    local rendered=ns.RenderSelective(state.raw,state.matches,region,state.revealedSpans)
    local full=Measure(region,rendered)
    if not full or (region:GetStringHeight() or 0)>size*1.8 then return Unavailable() end
    local align=region:GetJustifyH()
    if width<=0 then
        left=left+(align=='RIGHT' and -full or align=='CENTER' and -full/2 or 0);width=full
    end
    if height<=0 then height=math.max(size,region:GetStringHeight() or 0) end
    local ratio=scale/rootScale
    local inset=align=='RIGHT' and width-full or align=='CENTER' and (width-full)/2 or 0
    local vertical=region.GetJustifyV and region:GetJustifyV() or 'MIDDLE'
    local y=vertical=='TOP' and height-size or vertical=='BOTTOM' and 0 or (height-size)/2
    local prior,index={},0
    state.unitButtons=state.unitButtons or {}
    for _,match in ipairs(state.matches) do
        if ns.IsRedacted(match) and not match.replacement then
            index=index+1
            local key=Key(match)
            local prefix=ns.RenderSelective(state.raw:sub(1,match.first-1),prior,region,state.revealedSpans)
            local original=state.raw:sub(match.first,match.last)
            local content=state.revealedSpans[key] and ns.GrayText(original,region) or ns.BarText(original,region)
            local x,w=Measure(region,prefix),Measure(region,content)
            local button=state.unitButtons[index]
            if not button then
                button=CreateFrame('Button',nil,UIParent); state.unitButtons[index]=button
                button:EnableMouse(false);KeepNativeHover(button)
                button.ChatWardenUnitSpan=true; button.ChatWardenRegion=region
                button:RegisterForClicks('LeftButtonUp')
                button.inputState={}; ConfigureInput(button,button.inputState)
                button:HookScript('OnMouseDown',function(self,mouse)
                    self.pressed=mouse=='LeftButton' and ns.RevealModifier() and ClickEnabled(self)
                        and {key=self.span,raw=state.raw,identity=state.identity,epoch=state.linkEpoch} or nil
                end)
                local function Click(self,mouse)
                    local press=self.pressed; self.pressed=nil
                    if mouse~='LeftButton' or not press or not ns.RevealModifier() or not ClickEnabled(self)
                        or press.raw~=state.raw or press.identity~=state.identity or press.epoch~=state.linkEpoch then return end
                    -- Mouse motion is intentionally disabled for native hover.
                    -- Check cursor geometry instead of IsMouseOver's hover state.
                    local cx,cy=GetCursorPosition()
                    local s=self:GetEffectiveScale()
                    local l,b,w,h=self:GetRect()
                    if not l or not b or not s or s<=0 or cx/s<l-3 or cx/s>l+w+3
                        or cy/s<b-4 or cy/s>b+h+4 then return end
                    state.toggleSpan(self,press.key,mouse,true)
                end
                button:SetScript('OnClick',Click)
                if state.nativeNameplate then button:SetScript('OnMouseUp',Click) end
                button:SetScript('OnHide',function(self) self.pressed=nil end)
            end
            if x and w then
                local right=math.min(width,inset+x+w)
                x=math.max(0,inset+x); w=right-x
            end
            if x and w and w>0 then
                button.span=key
                button:SetScale(1); button:ClearAllPoints()
                button:SetPoint('BOTTOMLEFT',UIParent,'BOTTOMLEFT',(left+x)*ratio,(bottom+y)*ratio)
                button:SetSize(w*ratio,math.max(size,8)*ratio)
                button:SetHitRectInsets(-3,-3,-4,-4)
                -- Above native unit controls, below dialog/tooltip windows.
                if button:GetFrameStrata()~='HIGH' then button:SetFrameStrata('HIGH') end
                local level=math.max(40,region:GetParent():GetFrameLevel()+3)
                if button:GetFrameLevel()~=level then button:SetFrameLevel(level) end
                button:Show()
                ConfigureInput(button,button.inputState)
                SetClicks(button,not state.nativeNameplate and button.inputState.revealReady==true)
                KeepNativeHover(button)
                state.unitButtonsReady = true
            else
                SetClicks(button,false); button:Hide(); button.pressed=nil
            end
        end
        prior[#prior+1]=match
    end
    for i=index+1,#state.unitButtons do
        local button=state.unitButtons[i]
        SetClicks(button,false); button:Hide(); button.pressed=nil
    end
    return state.unitButtonsReady
end
local function Public(region)
    return region and ns.Readable(region) and not (region.IsForbidden and region:IsForbidden())
end
ConfigureInput = function(view, state)
    if state.revealReady then return end
    if type(view.SetPassThroughButtons) == "function"
        and pcall(view.SetPassThroughButtons, view, "RightButton", "MiddleButton", "Button4", "Button5") then
        state.revealReady = true
    elseif type(view.SetPropagateMouseClicks) == "function"
        and pcall(view.SetPropagateMouseClicks, view, true) then
        state.revealReady = true
        view:SetScript("OnMouseDown", function(self, button)
            local consume = button == "LeftButton" and ns.RevealModifier()
            local ok = pcall(self.SetPropagateMouseClicks, self, not consume)
            if not ok then state.revealReady = false; self:EnableMouse(false) end
        end)
    end
end
function U.Hide(region, state)
    HideUnitButtons(state)
    state.unitButtonsReady = false
    state.linkActive = false
    state.hoverLink, state.pressedLink, state.mouseUpLink = nil, nil, nil
    if state.linkView then SetClicks(state.linkView,false); state.linkView:Hide() end
    if state.linkHidden then
        state.writingAlpha = true; region:SetAlpha(state.alpha); state.writingAlpha = false
        state.linkHidden = false
    end
end
-- Native floating plates can receive clicks ahead of ordinary UIParent
-- buttons. Observe the global gesture instead; keep native targeting intact.
local globalPress,observedDown
function U.CancelGlobalMouse() globalPress=nil end
local function PlateUnderMouse(state)
    if not state.unit or type(UnitIsUnit) ~= 'function' then return false end
    local ok, same = pcall(UnitIsUnit,"mouseover",state.unit)
    if not ok or not ns.Readable(same) then return false end
    if not ns.Checked(same) then
        -- Names-only floating plates can have a visible label without an
        -- engine mouseover unit. Geometry still identifies the covered span.
        -- Never use this fallback over a different existing mouseover unit.
        if type(UnitExists) ~= 'function' then return false end
        local existsOK, mouseover = pcall(UnitExists,"mouseover")
        if not existsOK or not ns.Readable(mouseover) or ns.Checked(mouseover)
            or not ns.Checked(ns.SafeCall(UnitExists,state.unit)) then return false end
    end
    local foci = type(GetMouseFoci)=="function" and ns.SafeCall(GetMouseFoci)
    if not foci and type(GetMouseFocus)=="function" then foci={ns.SafeCall(GetMouseFocus)} end
    local knownFocus = false
    for _, focus in ipairs(type(foci)=="table" and foci or {}) do
        local object, allowed = focus, false
        for _=1,12 do
            if not object or not ns.Readable(object) or object.IsForbidden and object:IsForbidden() then break end
            if object==state.controlHost or object==WorldFrame or object==UIParent
                or object.ChatWardenUnitSpan then allowed=true; break end
            -- Unrelated UI windows must not reveal a plate behind them.
            local parent = object.GetParent and ns.SafeCall(object.GetParent,object)
            if parent==UIParent then break end
            object=parent
        end
        if not allowed then return false end
        knownFocus = true
    end
    -- Without a mouseover unit, require a public world/nameplate focus as
    -- well as unique span geometry; an absent focus is not evidence.
    return ns.Checked(same) or knownFocus
end
local function Contains(button)
    if not button:IsShown() then return false end
    local ok,l,b,w,h=pcall(button.GetRect,button)
    l,b,w,h=ns.SafeNumber(l),ns.SafeNumber(b),ns.SafeNumber(w),ns.SafeNumber(h)
    local scale=ns.SafeNumber(ns.SafeCall(button.GetEffectiveScale,button))
    local got,x,y=pcall(GetCursorPosition);x,y=ns.SafeNumber(x),ns.SafeNumber(y)
    return ok and got and l and b and w and h and scale and scale>0 and x and y
        and x/scale>=l-3 and x/scale<=l+w+3 and y/scale>=b-4 and y/scale<=b+h+4
end
function U.GlobalMouse(event,mouse,targets,canChange)
    if mouse~="LeftButton" then return end
    if event=="GLOBAL_MOUSE_DOWN" then
        if observedDown then return end
        observedDown=true
        globalPress=nil
        if not ns.RevealModifier() then return end
        for region,state in pairs(targets) do
            if state.nativeNameplate and state.linkActive and Active(state)
                and canChange(region,state) and PlateUnderMouse(state) then
                U.Sync(region,state,canChange)
                for _,button in ipairs(state.unitButtons or {}) do
                    if Contains(button) then
                        if globalPress then globalPress=nil; return end
                        globalPress={region=region,state=state,button=button,span=button.span,
                            raw=state.raw,identity=state.identity,epoch=state.linkEpoch}
                    end
                end
            end
        end
    else
        observedDown=false
        local press=globalPress; globalPress=nil
        if not press or not ns.RevealModifier() then return end
        local state=press.state
        U.Sync(press.region,state,canChange)
        if state.linkActive and state.raw==press.raw and state.identity==press.identity
            and state.linkEpoch==press.epoch and press.button.span==press.span
            and Contains(press.button) and PlateUnderMouse(state) then
            state.toggleSpan(press.button,press.span,mouse,true,true)
        end
    end
end
function U.PollMouse(targets,canChange)
    -- Some native floating plates consume the global mouse events. Observe
    -- physical button edges as a fallback; never intercept targeting input.
    if type(IsMouseButtonDown)~='function' then return end
    local value=ns.SafeCall(IsMouseButtonDown,'LeftButton')
    if not ns.Readable(value) then return end
    local down=ns.Checked(value)
    if observedDown==nil then observedDown=down;return end
    if down~=observedDown then
        U.GlobalMouse(down and 'GLOBAL_MOUSE_DOWN' or 'GLOBAL_MOUSE_UP','LeftButton',targets,canChange)
    end
end
local function Place(region, state, view)
    if not Public(region) or not Public(region:GetParent()) then return false end
    local width = ns.SafeNumber(ns.SafeCall(region.GetWidth, region)) or 0
    if width <= 0 then width = ns.SafeNumber(ns.SafeCall(region.GetStringWidth, region)) or 0 end
    local _, size = region:GetFont()
    local height = math.max(ns.SafeNumber(ns.SafeCall(region.GetHeight, region)) or 0,
        ns.SafeNumber(ns.SafeCall(region.GetStringHeight, region)) or 0, ns.SafeNumber(size) or 12)
    if width <= 0 or height <= 0 then return false end
    if state.nativeNameplate or state.targetName then
        -- Independent root, screen coordinates: no secure parent/anchor or
        -- alteration of unit-frame input scripts. Defer protected combat text.
        if type(region.GetRect) ~= "function" then return false end
        local ok, left, bottom, nativeWidth, nativeHeight = pcall(region.GetRect, region)
        left, bottom, nativeHeight = ns.SafeNumber(left), ns.SafeNumber(bottom), ns.SafeNumber(nativeHeight)
        local scale = ns.SafeNumber(ns.SafeCall(region.GetEffectiveScale, region))
        local rootScale = ns.SafeNumber(ns.SafeCall(UIParent.GetEffectiveScale, UIParent))
        if not ok or not left or not bottom or not nativeHeight or not scale or not rootScale or rootScale <= 0 then return false end
        if (ns.SafeNumber(nativeWidth) or 0)<=0 then
            local align=region:GetJustifyH()
            left=left+(align=='RIGHT' and -width or align=='CENTER' and -width/2 or 0)
        end
        if nativeHeight<=0 then nativeHeight=height end
        -- Anchor offsets are in UIParent units, not the label's scale.
        view:SetScale(1)
        view:ClearAllPoints(); view:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * scale / rootScale, (bottom + nativeHeight) * scale / rootScale)
        if view:GetFrameStrata() ~= "HIGH" then view:SetFrameStrata("HIGH") end
    else
        view:ClearAllPoints(); view:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
    end
    if state.nativeNameplate or state.targetName then
        local ratio=region:GetEffectiveScale()/UIParent:GetEffectiveScale()
        view:SetSize(width*ratio,height*ratio)
    else view:SetSize(width, height) end
    local level = math.max((state.nativeNameplate or state.targetName) and 40 or 1, region:GetParent():GetFrameLevel() + 3)
    if view:GetFrameLevel() ~= level then view:SetFrameLevel(level) end
    return true
end
function U.Sync(region, state, canChange)
    local view = state.linkView
    if not view then return end
    local active = state.linkActive and Active(state) and canChange(region, state)
        and (not state.available or ns.SafeCall(state.available) == true)
        and (not region.IsVisible or region:IsVisible()) and state.alpha > 0
    local parentAlpha = ns.SafeNumber(ns.SafeCall(region:GetParent().GetEffectiveAlpha, region:GetParent()))
    if parentAlpha and parentAlpha <= 0 then active = false end
    if active then state.geometryReady = Place(region, state, view); active = state.geometryReady end
    view:SetShown(active == true)
    if active and ns.RevealModifier() then ConfigureInput(view, state) end
    local enabled = active and state.revealReady and ns.RevealModifier() or false
    if state.nativeNameplate or state.targetName then
        if SyncUnitButtons(region,state,active) or state.nativeNameplate then enabled=false end
    end
    if enabled and not ClickEnabled(view) and type(IsMouseButtonDown) == "function"
        and ns.Checked(ns.SafeCall(IsMouseButtonDown, "LeftButton")) then enabled = false end
    if ClickEnabled(view) ~= enabled then SetClicks(view,enabled) end
    if enabled then KeepNativeHover(view) end
    -- Keep native mutable text visible, including quest fades and wrapping.
    -- Only display-only labels need a visible replacement. Alpha on the
    -- glyphs does not disable the owned frame's hyperlink hit testing.
    state.linkFont:SetAlpha(state.displayOnly and 1 or 0)
    if not state.displayOnly and state.linkHidden then
        state.writingAlpha=true; region:SetAlpha(state.alpha); state.writingAlpha=false
        state.linkHidden=false
    end
    view:SetAlpha(state.alpha)
end
function U.Update(region, state, canChange, apply)
    state.matches=ns.DisplayMatches(state.raw,state.matches)
    if state.revealRaw ~= state.raw or state.revealIdentity ~= state.identity or state.revealRevision ~= ns.PolicyRevision
        or not state.revealedSpans or not state.revealed and next(state.revealedSpans) ~= nil then
        state.revealedSpans = {}; state.revealed = false
        state.linkEpoch = (state.linkEpoch or 0) + 1
    end
    state.revealRaw, state.revealIdentity, state.revealRevision = state.raw, state.identity, ns.PolicyRevision
    if not state.linkView then
        local parent = (state.nativeNameplate or state.targetName) and UIParent or region:GetParent()
        local ok, view = pcall(CreateFrame, "Frame", nil, parent)
        if not ok or not view then return false end
        serial = serial + 1; state.linkSerial = serial
        state.linkView = view; view.ChatWardenRegion = region; view.ChatWardenDisplayOnly = state.displayOnly
        view.ChatWardenLabelView = true
        local text = view:CreateFontString(nil, "OVERLAY")
        text:SetAllPoints(view); state.linkFont = text; view.ChatWardenText = text
        view:EnableMouse(false); view:EnableMouseWheel(false)
        view:SetHyperlinksEnabled(true)
        if type(view.SetHyperlinkPropagateToParent)=="function" then view:SetHyperlinkPropagateToParent(false) end
        ConfigureInput(view, state)
        local function Toggle(self, link, button, direct, global)
            if button ~= "LeftButton" or not ns.RevealModifier() or (not global and not ClickEnabled(self))
                or not Active(state) or not canChange(region, state)
                or state.available and ns.SafeCall(state.available) ~= true then return end
            local span = direct and link or state.linkSpans and state.linkSpans[link]
            if not span then return end
            state.revealedSpans[span] = not state.revealedSpans[span]
            state.revealed = next(state.revealedSpans) ~= nil
            -- False entries are removed so the aggregate state reflects an
            -- actual reveal, while every other link retains its own state.
            if not state.revealedSpans[span] then state.revealedSpans[span] = nil end
            state.revealed = next(state.revealedSpans) ~= nil
            apply(region, state)
        end
        state.toggleSpan=Toggle
        view:SetScript("OnHyperlinkClick", function(self, link, _, button)
            if state.mouseUpLink == link then return end
            Toggle(self, link, button)
        end)
        if state.targetName or state.nativeNameplate then
            -- Some native unit surfaces deliver raw mouse-up without the
            -- message-frame click event. Use the hovered link, never the label.
            view:SetScript("OnHyperlinkEnter", function(_, link)
                state.hoverLink = state.linkSpans and state.linkSpans[link] and link or nil
            end)
            view:SetScript("OnHyperlinkLeave", function() state.hoverLink = nil end)
            view:HookScript("OnMouseDown", function(self, button)
                state.mouseUpLink = nil
                state.pressedLink = button == "LeftButton" and ns.RevealModifier()
                    and ClickEnabled(self) and state.hoverLink or nil
            end)
            view:HookScript("OnMouseUp", function(self, button)
                local link = state.pressedLink; state.pressedLink = nil
                if link and link == state.hoverLink and button == "LeftButton" then
                    state.mouseUpLink = link
                    Toggle(self, link, button)
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0, function() if state.mouseUpLink == link then state.mouseUpLink = nil end end)
                    end
                end
            end)
        end
    end
    local view, text = state.linkView, state.linkFont
    if not Place(region, state, view) then view:Hide(); return false end
    local font, size, flags = region:GetFont()
    local fontRatio = (state.nativeNameplate or state.targetName)
        and region:GetEffectiveScale()/UIParent:GetEffectiveScale() or 1
    if font then text:SetFont(font, size * fontRatio, flags) end
    text:SetJustifyH(type(region.GetJustifyH) == "function" and region:GetJustifyH() or "LEFT")
    text:SetJustifyV(type(region.GetJustifyV) == "function" and region:GetJustifyV() or "TOP")
    if region.CanWordWrap then text:SetWordWrap(region:CanWordWrap()) else text:SetWordWrap(true) end
    if region.CanNonSpaceWrap and text.SetNonSpaceWrap then text:SetNonSpaceWrap(region:CanNonSpaceWrap()) end
    if region.GetIndentedWordWrap and text.SetIndentedWordWrap then text:SetIndentedWordWrap(region:GetIndentedWordWrap()) end
    if region.GetSpacing and text.SetSpacing then text:SetSpacing(region:GetSpacing() * fontRatio) end
    if region.GetTextScale and text.SetTextScale then text:SetTextScale(region:GetTextScale()) end
    if region.GetShadowOffset and text.SetShadowOffset then text:SetShadowOffset(region:GetShadowOffset()) end
    if region.GetShadowColor and text.SetShadowColor then text:SetShadowColor(region:GetShadowColor()) end
    local r, g, b = region:GetTextColor()
    text:SetTextColor(r, g, b, 1)
    state.linkSpans = {}
    local rendered = ns.RenderSelective(state.raw, state.matches, text, state.revealedSpans, function(original, m, color)
        local key = Key(m)
        local link = "ocwui:" .. state.linkSerial .. ":" .. state.linkEpoch .. ":" .. key
        state.linkSpans[link] = key
        local content = state.revealedSpans[key] and ns.GrayText(original, text, color) or ns.BarText(original, text,state.raw:sub(1,m.first-1))
        return "|H" .. link .. "|h" .. content .. "|h"
    end)
    if state.linkText ~= rendered or state.linkColorR ~= r or state.linkColorG ~= g or state.linkColorB ~= b then
        -- Native SetAlpha also affects GetTextColor's alpha. The owned copy
        -- follows state.alpha at the frame, so its glyphs always use alpha 1.
        text:SetText(rendered); text:SetTextColor(r, g, b, 1)
        state.linkText, state.linkColorR, state.linkColorG, state.linkColorB = rendered, r, g, b
    end
    if state.displayOnly then
        state.writingAlpha = true; region:SetAlpha(0); state.writingAlpha = false
        state.linkHidden = true
    end
    state.linkActive = true
    state.action = state.revealed and "Revealed" or "Redacted"
    U.Sync(region, state, canChange)
    return true
end
