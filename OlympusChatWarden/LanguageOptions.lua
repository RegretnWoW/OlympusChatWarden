local _,ns=...
local T,L=ns.Theme,ns.Language
local category,controls,status
function ns.RefreshLanguageOptions()
    if not controls or not ns.DB.languageFilter then return end
    local db=ns.DB.languageFilter
    for key,c in pairs(controls) do
        if c.Refresh then c:Refresh()
        else c:SetChecked(key=='enabled' and ns.DB.languageEnabled or db.allowed[key]==true or db[key]==true) end
    end
    status:SetText(ns.DB.languageEnabled and 'On. Checked languages stay visible. Originals are kept in Messages.'
        or 'Off. Enable above to apply the preferences below.')
end
function ns.BuildLanguageOptions(parentCategory)
    if category or (not ns.Workspace and not Settings.RegisterCanvasLayoutSubcategory) then return end
    local f=CreateFrame('Frame',nil,nil,'BackdropTemplate');f:SetSize(640,620);T.SkinWindow(f)
    local function Text(parent,x,y,width,value,heading)
        local t=parent:CreateFontString(nil,'OVERLAY',heading and 'GameFontNormal' or 'GameFontHighlightSmall')
        t:SetPoint('TOPLEFT',x,y);t:SetWidth(width);t:SetJustifyH('LEFT');t:SetText(value)
        if heading then T.Gold(t) else T.Light(t) end;return t
    end
    local function Check(parent,key,label,x,y,width,help)
        local c=CreateFrame('CheckButton',nil,parent,'UICheckButtonTemplate');c:SetSize(26,26);c:SetPoint('TOPLEFT',x,y)
        c.caption=Text(c,30,-6,width,label);c:SetScript('OnClick',function(self) L.Set(key,ns.Checked(self:GetChecked())) end)
        T.Tooltip(c,label,help);controls[key]=c;return c
    end
    controls={};T.Crest(f,16,-8,56);Text(f,84,-16,520,'Language preferences',true)
    T.Muted(Text(f,84,-44,520,'Choose the languages you read, then how to show other text.'))
    Check(f,'enabled','Enable language filtering',14,-80,550,'Off by default. Enables the message and name preferences on this page. Wording rules and Shield remain separate.')
    status=T.Muted(Text(f,20,-116,600,''))
    local panel=T.Panel(f,20,-145,600,392)
    local scroll=CreateFrame('ScrollFrame',nil,panel,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',6,-6);scroll:SetPoint('BOTTOMRIGHT',-30,6)
    local content=CreateFrame('Frame',nil,scroll);content:SetSize(560,750);scroll:SetScrollChild(content)
    local function Choice(key,label,x,y,width,choices,help)
        local caption=Text(content,x,y,width,label)
        local d=T.Dropdown(content,x,y-20,width,choices,function() return ns.DB.languageFilter[key] end,function(v) L.Set(key,v) end)
        d.caption=caption;controls[key]=d;T.Tooltip(d,label,help)
    end
    local messageHeading=Text(content,6,-8,540,'Message filtering',true)
    local actions={{'cover','Redact detected text'},{'hide','Hide message'},{'mark','Label only'},{'leave','Leave visible'}}
    Choice('low','Low confidence',6,-34,260,actions,'Default: redact detected non-preferred portions. Hide removes the whole qualifying message, including mixed text. Label only keeps it readable with a language label. Leave visible makes no language change.')
    Choice('high','High confidence',284,-34,260,actions,'Default: hide the whole qualifying message, including its name. This action also applies when at least 85% of readable letters are detected as non-preferred, even if only the writing system is known. Reports explain which condition matched.')
    Check(content,'maskNames','Filter player names too',0,-99,510,'Off by default. Uses the same language list. Redacted message text can also have its matching name covered. Hidden messages already include their names. Label-only and Leave visible results keep their names readable. English or preferred-language replies stay visible with matching names covered; a name alone never hides a message. Also covers supported labels and system notices. Ctrl + left-click a covered chat name to reveal it.')
    local confidence=T.Muted(Text(content,6,-141,540,'Confidence runs whenever filtering is on. Minimum: 4 letters.\nMostly non-preferred text uses the High confidence action.'))
    local languagesHeading=Text(content,6,-206,540,'Languages you read',true)
    local languageHint=T.Muted(Text(content,6,-234,540,'Check languages to keep. The same list applies to names when enabled.'))
    for i,item in ipairs(L.Choices) do
        local id,label=item[1],item[2]
        local c=Check(content,id,label,math.floor((i-1)/10)*280,-274-((i-1)%10)*28,240,
            id=='en' and 'English stays allowed. Personal wording rules and Shield can still apply.'
                or 'Keep detected text in this language or writing system. This also allows its writing system in names. Cyrillic names cannot distinguish Russian from Ukrainian; allowing either keeps Cyrillic names. Han text has a shared Chinese/Japanese entry. Latin names cannot reliably identify a language; use My rules for a specific name.')
        if id=='en' then c:SetEnabled(false) end
    end
    local incomingHeading=Text(content,6,-578,540,'Incoming chat',true)
    for i,item in ipairs({{'public','Public chat'},{'whispers','Whispers'},{'group','Party / raid / instance'},{'guild','Guild / officer'}}) do
        local id,label=item[1],item[2]
        Check(content,id,label,((i-1)%2)*280,-607-math.floor((i-1)/2)*30,240,'Apply language filtering to this incoming chat type. Requires Player chat coverage. Your own messages, NPC chat, emotes and Battle.net are excluded. Personal wording rules and Shield have separate settings.')
    end
    local note=T.Muted(Text(content,6,-686,540,'Names indicate a writing system, not nationality. Review and chat capture keep originals.'))
    local b=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');b:SetSize(286,26);b:SetPoint('TOPLEFT',20,-546);b:SetText('Language guide')
    b:SetScript('OnClick',function() ns.OpenTutorial('languages') end);T.Tooltip(b,'Language guide','Defaults, examples, name covering and reports.')
    if ns.Workspace then
        local W,V=ns.Workspace,ns.Art;b:Hide()
        local messages=V.Panel(f,18,-98,544,282,'dark')
        local incoming=V.Panel(f,18,-396,544,222,'dark')
        function f:ChatWardenLayout(w,h)
            local half=(w-52)/2;local inner=(half-60)/2
            W.Place(controls.enabled,18,-16,w-70);controls.enabled.caption:SetWidth(w-100);W.Place(status,24,-58,w-48)
            W.Place(messages,18,-98,half,282);W.Place(incoming,18,-396,half,h-454)
            W.Place(panel,34+half,-98,half,h-156)
            W.Place(messageHeading,18,-18,half-36,nil,messages)
            for i,key in ipairs({'low','high'}) do local d=controls[key];local x=22+(i-1)*(inner+16);W.Place(d.caption,x,-64,inner,nil,messages);W.Place(d,x,-90,inner,34,messages) end
            W.Place(controls.maskNames,16,-148,nil,nil,messages);controls.maskNames.caption:SetWidth(half-70)
            W.Place(confidence,22,-198,half-44,64,messages)
            W.Place(incomingHeading,18,-18,half-36,nil,incoming)
            for i,key in ipairs({'public','whispers','group','guild'}) do
                local c=controls[key];W.Place(c,16+((i-1)%2)*(inner+16),-60-math.floor((i-1)/2)*52,nil,nil,incoming);c.caption:SetWidth(inner-40)
            end
            W.Place(languagesHeading,18,-18,half-36,nil,panel);W.Place(languageHint,22,-49,half-44,36,panel)
            scroll:ClearAllPoints();scroll:SetPoint('TOPLEFT',14,-98);scroll:SetPoint('BOTTOMRIGHT',-34,16)
            content:SetWidth(half-48)
            for i,item in ipairs(L.Choices) do local c=controls[item[1]];W.Place(c,((i-1)%2)*(inner+8),-math.floor((i-1)/2)*36);c.caption:SetWidth(inner-38) end
            content:SetHeight(math.ceil(#L.Choices/2)*36)
            W.Place(note,24,-(h-32),w-48,nil,f)
        end
    end
    f:SetScript('OnShow',ns.RefreshLanguageOptions);T.BindSettings(f)
    category=ns.Workspace and parentCategory or Settings.RegisterCanvasLayoutSubcategory(parentCategory,f,'Languages');ns.LanguageOptionsPanel=f
    ns.LanguageOptionControls=controls;ns.RefreshLanguageOptions()
end
function ns.OpenLanguageOptions()
    ns.BuildOptions('languages')
    if category and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID())
    else ns.Print('Language settings are unavailable in this client.') end
end
