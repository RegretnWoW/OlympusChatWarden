-- Local spelling settings; Review keeps its three existing tabs.
local _,ns=...
local T,S=ns.Theme,ns.Spelling
local spellingCategory,spellOn,autoCorrect,spellCount,typoOn,typoMode
local spellInput,spellRows,spellPage= nil,nil,1
local spellPrevious,spellNext
local spellList
local function Text(parent,x,y,width,value)
    local t=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
    t:SetPoint('TOPLEFT',x,y);t:SetWidth(width);t:SetJustifyH('LEFT');t:SetWordWrap(true)
    t:SetText(value or '');T.Light(t);return t
end
local function Button(parent,label,x,y,width,fn,help)
    local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetSize(width,24);b:SetPoint('TOPLEFT',x,y)
    b:SetText(label);b:SetScript('OnClick',fn);T.Tooltip(b,label,help);return b
end
local function Check(parent,label,y,fn,help)
    local c=CreateFrame('CheckButton',nil,parent,'UICheckButtonTemplate');c:SetSize(26,26);c:SetPoint('TOPLEFT',14,y)
    c.caption=Text(c,30,-6,560,label);c:SetScript('OnClick',function(self) fn(ns.Checked(self:GetChecked())) end)
    T.Tooltip(c,label,help);return c
end
local function Input(parent,y,help)
    local e=CreateFrame('EditBox',nil,parent,'InputBoxTemplate');e:SetSize(324,24);e:SetPoint('TOPLEFT',26,y)
    e:SetAutoFocus(false);e:SetMaxLetters(128);T.TextField(e);e.ChatWardenNoSpelling=true
    e:SetScript('OnEscapePressed',function(self) self:ClearFocus() end);T.Tooltip(e,'Add or remove an entry',help);return e
end
local function Page(parent,title,summary)
    local f=CreateFrame('Frame',nil,nil,'BackdropTemplate');f:SetSize(640,620);T.SkinWindow(f)
    T.Crest(f,16,-8,56);T.Gold(Text(f,84,-16,520,title));T.Muted(Text(f,84,-44,510,summary))
    return f
end
local function Rows(parent,y,onClick,count)
    local rows={}
    for i=1,count or 8 do
        local row=CreateFrame('Button',nil,parent);row:SetSize(570,23);row:SetPoint('TOPLEFT',22,y-(i-1)*24)
        row:SetNormalFontObject(GameFontHighlightSmall);row:SetHighlightTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight','ADD')
        row:SetScript('OnClick',function(self) onClick(self.value) end);rows[i]=row
    end
    return rows
end
local function Fill(rows,list,page,text,prev,nextButton)
    local pages=math.max(1,math.ceil(#list/#rows));page=math.max(1,math.min(page,pages))
    for i,row in ipairs(rows) do
        local item=list[(page-1)*#rows+i];row.value=type(item)=='table' and item.name or item
        row:SetText(row.value or '');row:SetShown(item~=nil)
    end
    text:SetText(#list..' saved  |  Page '..page..' / '..pages)
    prev:SetEnabled(page>1);nextButton:SetEnabled(page<pages);return page
end
function ns.RefreshSpellingOptions()
    if not spellOn or not ns.DB or not ns.DB.spelling then return end
    spellOn:SetChecked(ns.DB.spelling.enabled)
    autoCorrect:SetChecked(ns.DB.spelling.autoCorrect)
    if typoOn then typoOn:SetChecked(ns.DB.typoFiltering) end
    if typoMode then typoMode:Refresh() end
    if spellList then local words=S.PersonalWords();spellCount:SetText(#words..' saved words  |  Select a word to edit it');spellList:SetItems(words,true)
    else spellPage=Fill(spellRows,S.PersonalWords(),spellPage,spellCount,spellPrevious,spellNext) end
end
function ns.BuildSpellingOptions(parent)
    if spellingCategory or (not ns.Workspace and not Settings.RegisterCanvasLayoutSubcategory) then return end
    local f=Page(parent,'Spelling','Local English spelling suggestions for accessible text inputs.')
    spellOn=Check(f,'Enable spelling highlights',-88,S.SetEnabled,'Starts off. Marks possible English spelling mistakes in accessible one-line text inputs across WoW and addons. Password, protected, numeric, IME, code/import and read-only fields are excluded. No text leaves your game.')
    autoCorrect=Check(f,'Automatically correct high-confidence typos',-120,function(v) S.SetOption('autoCorrect',v) end,'Starts off. Ranks common-word, repeated-letter and adjacent-letter repairs after you finish the word. Ambiguous text stays unchanged. It never sends the text.')
    local typingHelp=Text(f,20,-160,600,'Possible mistakes receive an orange highlight. Right-click a highlighted word to choose a suggestion, add it to your dictionary, or ignore it until reload.')
    local scope=T.Muted(Text(f,20,-210,600,'Offline English, WoW and Olympus vocabulary plus your personal words. Links, commands and known player names are skipped. Automatic correction changes only a clear best result.'))
    typoOn=Check(f,'Typo-aware incoming filtering',-248,ns.TypoFilter.Set,'Enabled in Balanced mode by default. Other players only; independent of typing assistance. Balanced protects known words and names and skips ambiguous guesses. Aggressive retains the earlier prototype. Originals, guesses and the selected mode remain in review/report evidence. Signed packs are unchanged.')
    ns.TypoFilteringCheckbox=typoOn
    typoMode=T.Dropdown(f,356,-245,238,{{'balanced','Balanced matching'},{'aggressive','Aggressive prototype'}},function() return ns.TypoFilter.Mode() end,ns.TypoFilter.SetMode)
    ns.TypoModeDropdown=typoMode
    local dictionaryHeading=T.Gold(Text(f,20,-278,600,'Personal dictionary'))
    spellInput=Input(f,-310,'Enter a word, or select one below. Saved words are shared across your characters on this account.')
    local add=Button(f,'Add word',370,-310,102,function() local _,err=S.AddWord(spellInput:GetText());if err then ns.Print(err) end end,'Accept this spelling on this account. Maximum 512 words.')
    local remove=Button(f,'Remove',482,-310,112,function() S.RemoveWord(spellInput:GetText()) end,'Remove the selected word from your personal dictionary.')
    spellCount=T.Muted(Text(f,22,-346,570));spellRows=Rows(f,-368,function(word) spellInput:SetText(word);spellInput:ClearFocus() end,7)
    spellPrevious=Button(f,'Previous',22,-548,110,function() spellPage=spellPage-1;ns.RefreshSpellingOptions() end,'Previous page of saved words.')
    spellNext=Button(f,'Next',146,-548,110,function() spellPage=spellPage+1;ns.RefreshSpellingOptions() end,'Next page of saved words.')
    local help=Button(f,'Help',482,-548,112,function() ns.OpenTutorial('spelling') end,'Read spelling instructions and supported inputs.')
    if ns.Workspace then
        local W,V=ns.Workspace,ns.Art;help:Hide();spellPrevious:Hide();spellNext:Hide()
        for _,row in ipairs(spellRows) do row:Hide() end
        local typing=V.Panel(f,18,-18,544,282,'dark');V.Text(typing,'Typing assistance',18,-18,490,18,V.gold)
        local incoming=V.Panel(f,18,-316,544,342,'dark');V.Text(incoming,'Incoming typo matching',18,-18,490,18,V.gold)
        local dictionary=V.Panel(f,578,-18,544,640,'dark')
        local incomingHelp=V.Text(incoming,'Balanced matching protects known English, WoW and Olympus words and player names, and skips ambiguous guesses. Aggressive uses the earlier prototype.\n\nChecks other players against your existing rules. Originals stay intact in review and report evidence. Typing assistance is independent.',22,-174,500,14,V.muted)
        spellList=V.ScrollingList(dictionary,14,-184,496,438,42,function(parent)
            local row=V.Button(parent,'',0,0,496,38,function() end,'neutral');row.ActiveArt=V.Nine(row,'selected')
            row:SetScript('OnClick',function(self) spellInput:SetText(self.word);spellInput:ClearFocus();spellList:Render() end);return row
        end,function(row,word) row.word=word;row:SetText(word);row.ActiveArt:SetShown(spellInput:GetText()==word);row.Caption:SetWidth(row:GetWidth()-24) end)
        ns.SpellingDictionaryList=spellList;ns.SpellingDictionaryInput=spellInput
        function f:ChatWardenLayout(w,h)
            local half=(w-52)/2
            W.Place(typing,18,-18,half,282);W.Place(incoming,18,-316,half,h-334);W.Place(dictionary,34+half,-18,half,h-36)
            for i,c in ipairs({spellOn,autoCorrect}) do W.Place(c,16,-56-(i-1)*42,nil,nil,typing);c.caption:SetWidth(half-70) end
            W.Place(typingHelp,22,-154,half-44,60,typing);W.Place(scope,22,-221,half-44,44,typing)
            scope:SetText('Offline English, WoW and Olympus vocabulary plus personal words. Links, commands and known names are skipped.')
            W.Place(typoOn,16,-58,nil,nil,incoming);typoOn.caption:SetWidth(half-70);typoOn.caption:SetText('Enable typo-aware incoming filtering')
            W.Place(typoMode,22,-112,half-44,34,incoming);W.Place(incomingHelp,22,-174,half-44,h-526)
            W.Place(dictionaryHeading,18,-18,half-36,nil,dictionary)
            W.Place(spellInput,22,-58,half-44,32,dictionary)
            W.Place(add,22,-102,(half-60)/2,32,dictionary);W.Place(remove,38+(half-60)/2,-102,(half-60)/2,32,dictionary)
            W.Place(spellCount,22,-152,half-44,nil,dictionary);spellList:Resize(half-48,h-238)
            ns.RefreshSpellingOptions()
        end
    end
    f:SetScript('OnShow',ns.RefreshSpellingOptions);ns.SpellingOptionsPanel=f
    T.BindSettings(f)
    spellingCategory=ns.Workspace and parent or Settings.RegisterCanvasLayoutSubcategory(parent,f,'Spelling')
    ns.RefreshSpellingOptions()
end
function ns.OpenSpellingOptions()
    ns.BuildOptions();if spellingCategory and Settings.OpenToCategory then Settings.OpenToCategory(spellingCategory:GetID()) end
end
