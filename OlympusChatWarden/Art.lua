-- The supplied artwork is used as atlases. Labels and counts are native UI text.
local _,ns=...
local V={};ns.Art=V
local base='Interface\\AddOns\\OlympusChatWarden\\Media\\V5\\'
local factors={Icons=1/1254,Panels=1/1254,Controls=1/1254,Ornament=1/1254,Logo=1/512,Guardian=1/1024,Status=1/1254,Tabs=1/1254}
local icons={overview={18,90,142,217},messages={162,108,282,216},mentions={294,101,423,220},
    shield={438,96,546,221},capture={551,96,698,221},rules={700,98,831,221},packs={842,101,971,221},
    reports={978,96,1105,222},settings={1109,97,1243,222},updates={978,96,1105,222},
    enabled={49,509,153,611},shieldActive={189,495,311,612},olympus={347,500,478,612},help={522,507,633,614},
    star={802,496,918,613},whisper={25,716,141,822},trade={149,715,269,820},guild={272,716,384,821},
    party={395,709,519,821},general={532,710,650,821},export={680,709,788,821},copy={811,709,929,821},
    create={968,709,1090,821},delete={1115,710,1217,821}}
local status={enabled={37,199,282,438},enabledOff={36,512,290,753},
    shieldActive={354,179,585,442},shieldOff={354,489,593,753},
    capture={636,221,941,440},captureOff={662,512,923,751},
    mentions={973,196,1220,441},mentionsOff={973,509,1234,753},
    reports={25,799,296,1081},updates={336,804,587,1077},
    olympus={655,825,917,1082},olympusOff={969,825,1227,1080}}
for name,rect in pairs(status) do icons[name]=rect end
V.IconRects=icons
function V.SetIcon(texture,name)
    V.Region(texture,status[name] and 'Status' or 'Icons',icons[name] or icons.messages)
end
local frames={dark={'Panels',{677,47,1018,420},18},paper={'Panels',{21,46,367,420},28},
    row={'Panels',{28,463,535,530},12},selected={'Panels',{28,613,535,680},14},
    header={'Ornament',{271,690,1235,804},28},sidebar={'Ornament',{213,177,371,645},24},
    button={'Controls',{23,59,289,155},16},danger={'Controls',{23,217,290,313},16},
    hover={'Controls',{303,58,567,156},16},pressed={'Controls',{579,60,832,156},16},
    dangerHover={'Controls',{303,216,567,313},16},dangerPressed={'Controls',{579,217,831,314},16},
    neutral={'Controls',{31,375,284,462},16},neutralHover={'Controls',{303,375,567,462},16},neutralPressed={'Controls',{579,375,831,462},16},disabled={'Controls',{845,59,1097,156},16},
    tab={'Tabs',{69,76,1185,239},38},tabOff={'Tabs',{69,267,1185,431},38},
    tabHover={'Tabs',{69,459,1185,623},38},tabPressed={'Tabs',{69,651,1185,815},38},tabDisabled={'Tabs',{69,843,1185,1008},38},
    search={'Controls',{47,799,574,881},16},searchFocus={'Controls',{595,799,1070,881},16}}
local cleanCenters={neutralHover={334,403,374,440},neutralPressed={614,403,654,440},button={60,88,100,128},danger={60,247,100,290},neutral={60,403,100,440},disabled={876,88,914,132},
    hover={334,88,374,128},pressed={614,88,654,128},dangerHover={334,247,374,290},dangerPressed={614,247,654,290},
    tab={240,125,400,195},tabOff={240,315,400,385},tabHover={240,505,400,575},tabPressed={240,700,400,770},tabDisabled={240,895,400,965},search={480,828,524,855},searchFocus={990,828,1035,855},
    row={318,509,392,518},selected={318,659,392,666},dark={750,120,950,330},header={600,720,960,770},sidebar={250,250,330,530}}
-- Sample the metal rim separately from the larger ornamental corner crops.
-- Stretching the whole corner depth along an edge also stretches its black
-- interior recess into a continuous band; exterior alpha edits cannot fix it.
local rimWidths={dark=8,paper=28,row=8,selected=10,header=28,sidebar=10,
    button=10,danger=10,hover=10,pressed=10,dangerHover=10,dangerPressed=10,
    neutral=10,neutralHover=10,neutralPressed=10,disabled=10,search=9,searchFocus=9,
    tab=18,tabOff=18,tabHover=18,tabPressed=18,tabDisabled=18}
function V.Texture(parent,atlas,rect,layer,sublevel)
    local t=parent:CreateTexture(nil,layer or 'ARTWORK',nil,sublevel or 0)
    V.Region(t,atlas,rect);return t
end
function V.Region(texture,atlas,rect)
    texture:SetTexture(base..atlas..'.tga')
    local f=factors[atlas];texture:SetTexCoord(rect[1]*f,rect[3]*f,rect[2]*f,rect[4]*f)
    texture.ChatWardenArt={atlas=atlas,rect=rect}
    if texture.ChatWardenIconBox then V.FitIcon(texture,rect) end
end
function V.FitIcon(texture,rect)
    local box=texture.ChatWardenIconBox;rect=rect or texture.ChatWardenArt.rect
    local width,height=rect[3]-rect[1],rect[4]-rect[2]
    local scale=box.size/math.max(width,height)
    texture:SetSize(width*scale,height*scale)
    texture:ClearAllPoints();texture:SetPoint('TOPLEFT',box.x+(box.size-width*scale)/2,box.y-(box.size-height*scale)/2)
end
function V.Icon(parent,name,size,x,y)
    local t=parent:CreateTexture(nil,'ARTWORK');V.SetIcon(t,name)
    t.ChatWardenIconBox={size=size,x=x or 0,y=y or 0};V.FitIcon(t);return t
end
function V.Nine(parent,kind)
    local spec=frames[kind] or frames.dark;local atlas,r,b=spec[1],spec[2],spec[3]
    local group={};local w,h=r[3]-r[1],r[4]-r[2]
    local rim=rimWidths[kind] or b
    local edge=kind=='paper' and 14 or kind=='header' and 18 or (kind=='button' or kind=='danger' or kind=='neutral' or kind=='disabled' or kind=='hover' or kind=='pressed' or kind=='dangerHover' or kind=='dangerPressed' or kind=='search' or kind=='searchFocus') and 7 or 10
    if kind:find('^tab') or kind=='neutralHover' or kind=='neutralPressed' then edge=7 end
    if edge==7 and parent:GetHeight()<30 and not kind:find('^tab') then edge=5 end
    -- Button center strips exclude the baked example text in the source sheet.
    local centerY=(kind=='button' or kind=='danger' or kind=='neutral' or kind=='disabled' or kind=='tab' or kind=='tabOff' or kind=='search' or kind=='searchFocus') and r[2]+b+2 or (r[2]+r[4])/2
    local positions={
        {'TOPLEFT',0,0,edge,edge,{r[1],r[2],r[1]+b,r[2]+b}},
        {'TOPRIGHT',0,0,edge,edge,{r[3]-b,r[2],r[3],r[2]+b}},
        {'BOTTOMLEFT',0,0,edge,edge,{r[1],r[4]-b,r[1]+b,r[4]}},
        {'BOTTOMRIGHT',0,0,edge,edge,{r[3]-b,r[4]-b,r[3],r[4]}},
    }
    for _,p in ipairs(positions) do local t=V.Texture(parent,atlas,p[6],'BORDER');t:SetSize(p[4],p[5]);t:SetPoint(p[1],p[2],p[3]);group[#group+1]=t end
    local center=V.Texture(parent,atlas,cleanCenters[kind] or {r[1]+b,r[2]+b,r[3]-b,r[4]-b},'BACKGROUND',1)
    center:SetPoint('TOPLEFT',edge,-edge);center:SetPoint('BOTTOMRIGHT',-edge,edge);group[#group+1]=center
    local strips={
        {{r[1]+b,r[2],r[3]-b,r[2]+rim},'TOPLEFT',edge,0,'TOPRIGHT',-edge,0,'height'},
        {{r[1]+b,r[4]-rim,r[3]-b,r[4]},'BOTTOMLEFT',edge,0,'BOTTOMRIGHT',-edge,0,'height'},
        {{r[1],r[2]+b,r[1]+rim,r[4]-b},'TOPLEFT',0,-edge,'BOTTOMLEFT',0,edge,'width'},
        {{r[3]-rim,r[2]+b,r[3],r[4]-b},'TOPRIGHT',0,-edge,'BOTTOMRIGHT',0,edge,'width'},
    }
    for _,p in ipairs(strips) do local t=V.Texture(parent,atlas,p[1],'BORDER');t:SetPoint(p[2],p[3],p[4]);t:SetPoint(p[5],p[6],p[7]);if p[8]=='height' then t:SetHeight(edge) else t:SetWidth(edge) end;group[#group+1]=t end
    function group:SetShown(value) for _,t in ipairs(self) do t:SetShown(value) end end
    return group
end
function V.Panel(parent,x,y,w,h,kind)
    local f=CreateFrame('Frame',nil,parent);f:SetPoint('TOPLEFT',x,y);f:SetSize(w,h)
    -- Keep the backing inside the trim; the atlas corners are transparent.
    local fill=f:CreateTexture(nil,'BACKGROUND',nil,-1)
    local inset=kind=='header' and 18 or kind=='paper' and 14 or kind=='search' and 7 or 10
    fill:SetPoint('TOPLEFT',inset,-inset);fill:SetPoint('BOTTOMRIGHT',-inset,inset);fill:SetColorTexture(.16,.17,.18,1);f.ArtBacking=fill
    if kind=='paper' then fill:SetColorTexture(.79,.66,.43,1) end
    f.ArtFrame=V.Nine(f,kind or 'dark');f.ChatWardenPaper=kind=='paper';return f
end
function V.Text(parent,text,x,y,width,size,color)
    local t=parent:CreateFontString(nil,'OVERLAY','GameFontHighlight')
    t.ChatWardenFontSize=size or 13
    local path=GameFontHighlight and GameFontHighlight.GetFont and GameFontHighlight:GetFont()
    if not ns.Theme.DocumentFont(t,size or 13) then t:SetFont(path or 'Fonts\\FRIZQT__.TTF',size or 13,'') end;t:SetShadowOffset(0,0)
    t:SetPoint('TOPLEFT',x,y);t:SetWidth(width);t:SetJustifyH('LEFT');t:SetWordWrap(true);t:SetText(text or '')
    local c=color or { .91,.88,.80 };t:SetTextColor(unpack(c));return t
end
V.gold={.91,.77,.58};V.ink={.15,.10,.055};V.muted={.68,.68,.68};V.blue={.27,.70,1}
-- Blue commits an action or selects a view; gray navigates/copies; red removes.
function V.ButtonKind(text)
    local label=(text or ''):lower()
    for _,word in ipairs({'delete','remove','clear','dismiss','confirm delete','stop allowing'}) do if label:find('^'..word) then return 'danger' end end
    for _,word in ipairs({'open','back','cancel','close','copy','export','help','guide','window','settings','shield settings','capture settings','mention settings','notifications'}) do if label:find('^'..word) then return 'neutral' end end
    for _,word in ipairs({'save','apply','add','create','verify','install','import','enable','disable','toggle','allow','shield','report','send','bookmark'}) do if label:find('^'..word) then return 'button' end end
    return 'neutral'
end
function V.Button(parent,text,x,y,w,h,click,kind)
    kind=kind or V.ButtonKind(text)
    local b=CreateFrame('Button',nil,parent);b:SetPoint('TOPLEFT',x,y);b:SetSize(w,h or 32)
    -- The atlas supplies an opaque interior. A full rectangular backing leaks
    -- through the transparent bevel corners, especially over parchment headers.
    b.ChatWardenRole=kind;b.ArtNormal=V.Nine(b,kind);b.ArtDisabled=V.Nine(b,(kind=='tab' or kind=='tabOff') and 'tabDisabled' or 'disabled');b.ArtDisabled:SetShown(false)
    b.ArtHover=V.Nine(b,kind=='danger' and 'dangerHover' or kind=='row' and 'selected' or (kind=='tab' or kind=='tabOff') and 'tabHover' or kind=='neutral' and 'neutralHover' or 'hover');b.ArtHover:SetShown(false)
    b.ArtPressed=V.Nine(b,kind=='danger' and 'dangerPressed' or (kind=='tab' or kind=='tabOff') and 'tabPressed' or kind=='neutral' and 'neutralPressed' or 'pressed');b.ArtPressed:SetShown(false)
    b.Caption=V.Text(b,text,12,-9,w-24,13,V.gold);b.Caption:ClearAllPoints();b.Caption:SetPoint('CENTER');b.Caption:SetWidth(w-18);b.Caption:SetJustifyH('CENTER');b.Caption:SetJustifyV('MIDDLE');b.Caption:SetWordWrap(false);b.Caption:SetHeight((h or 32)-8)
    b:SetScript('OnClick',click)
    b:SetScript('OnEnter',function(self) if self:IsEnabled() then self.ArtHover:SetShown(true);self.Caption:SetTextColor(1,.95,.76) end end)
    b:SetScript('OnLeave',function(self) self.ArtHover:SetShown(false);self.ArtPressed:SetShown(false);self.Caption:SetTextColor(unpack(V.gold)) end)
    b:SetScript('OnMouseDown',function(self) if self:IsEnabled() then self.ArtHover:SetShown(false);self.ArtPressed:SetShown(true) end end)
    b:SetScript('OnMouseUp',function(self) self.ArtPressed:SetShown(false) end)
    local oldText=b.SetText;b.SetText=function(self,value) self.Caption:SetText(value) end
    b.GetText=function(self) return self.Caption:GetText() end
    local enable=b.SetEnabled;b.SetEnabled=function(self,value) enable(self,value);self.ArtNormal:SetShown(value);self.ArtDisabled:SetShown(not value);self.ArtHover:SetShown(false);self.ArtPressed:SetShown(false);self.Caption:SetAlpha(value and 1 or .5) end
    return b
end
function V.Edit(parent,x,y,w,h,placeholder,changed,multiline)
    local box=V.Panel(parent,x,y,w,h or 34,'search')
    local e=CreateFrame('EditBox',nil,box);e:SetPoint('TOPLEFT',14,-7);e:SetPoint('BOTTOMRIGHT',-12,7)
    e.ChatWardenArtStyled=true -- the surrounding panel already owns this field's trim
    e:SetAutoFocus(false);e:SetFontObject(GameFontHighlight);e:SetMaxLetters(multiline and 8192 or 128);e:SetMultiLine(multiline==true)
    local hint=V.Text(box,placeholder or '',15,-9,w-30,13,V.muted)
    e:SetScript('OnTextChanged',function(self,user) hint:SetShown((self:GetText() or '')=='');if changed then changed(self:GetText() or '',user) end end)
    e:SetScript('OnEscapePressed',function(self) self:ClearFocus() end);return e,box
end
local menus={}
function V.CloseMenus() for _,menu in ipairs(menus) do menu:Hide() end end
function V.Dropdown(parent,x,y,w,choices,get,set)
    local b=V.Button(parent,'',x,y,w,34,function(self)
        local shown=self.Menu and self.Menu:IsShown();V.CloseMenus();if shown then return end
        local width=self:GetWidth()
        if not self.Menu then
            self.Menu=V.Panel(UIParent,0,0,width,#choices*30+12,'dark');self.Menu:SetFrameStrata('TOOLTIP');self.Menu:SetFrameLevel(200)
            self.MenuRows={}
            menus[#menus+1]=self.Menu
            ns.Theme.RegisterPopup(self,function() self.Menu:Hide() end)
        end
        self.Menu:SetSize(width,#choices*30+12)
        for i,choice in ipairs(choices) do
            local row=self.MenuRows[i]
            if not row then row=V.Button(self.Menu,'',6,-6-(i-1)*30,width-12,29,function(button) self.Menu:Hide();set(button.choice[1]);self:Refresh() end,'neutral');self.MenuRows[i]=row end
            row.choice=choice;row:SetWidth(width-12);row.Caption:SetWidth(width-36);row:SetText(choice[2]);row:Show()
        end
        for i=#choices+1,#self.MenuRows do self.MenuRows[i]:Hide() end
        self.Menu:ClearAllPoints();self.Menu:SetScale(self:GetEffectiveScale()/UIParent:GetEffectiveScale())
        local bottom=self.GetBottom and self:GetBottom()
        if bottom and bottom<(#choices*30+12)*self:GetEffectiveScale() then self.Menu:SetPoint('BOTTOMLEFT',self,'TOPLEFT',0,2)
        else self.Menu:SetPoint('TOPLEFT',self,'BOTTOMLEFT',0,-2) end
        self.Menu:Show()
    end,'neutral')
    function b:Refresh() local value=get();self.value=value;for _,c in ipairs(choices) do if c[1]==value then self:SetText(c[2]..'  v');return end end;self:SetText(tostring(value)) end
    b:Refresh();return b
end
function V.Badge(parent,x,y)
    local f=CreateFrame('Frame',nil,parent);f:SetSize(25,25);f:SetPoint('TOPRIGHT',x or -6,y or -12)
    local t=V.Texture(f,'Icons',{94,339,145,393});t:SetAllPoints()
    local label=V.Text(f,'',0,0,25,13,{1,1,1});label:ClearAllPoints();label:SetAllPoints();label:SetJustifyH('CENTER');label:SetJustifyV('MIDDLE')
    function f:SetCount(count) label:SetText(count>99 and '99+' or tostring(count));self:SetShown(count>0) end
    f:SetCount(0);return f
end
function V.Check(parent,text,x,y,value,click,width)
    local b=CreateFrame('CheckButton',nil,parent);b:SetPoint('TOPLEFT',x,y);b:SetSize(width or 240,28)
    local empty=V.Texture(b,'Controls',{934,533,1009,614});empty:SetSize(26,26);empty:SetPoint('TOPLEFT')
    local checked=V.Texture(b,'Controls',{807,533,890,614});checked:SetSize(26,26);checked:SetPoint('TOPLEFT')
    b.Caption=V.Text(b,text,35,-6,(width or 240)-35,13)
    local setChecked=b.SetChecked;b.SetChecked=function(self,v) setChecked(self,v);checked:SetShown(ns.Checked(v)) end
    b:SetChecked(value);b:SetScript('OnClick',function(self) self:SetChecked(self:GetChecked());click(ns.Checked(self:GetChecked())) end);return b
end
function V.Row(parent,y,click)
    local row=CreateFrame('Button',nil,parent);row:SetPoint('TOPLEFT',8,y);row:SetSize(284,72)
    row.ArtNormal=V.Nine(row,'row');row.ArtSelected=V.Nine(row,'selected');row.ArtSelected:SetShown(false)
    row.icon=V.Icon(row,'messages',34,12,-19)
    row.title=V.Text(row,'',56,-11,212,14);row.title:SetWordWrap(false);row.title:SetHeight(18);row.title:SetJustifyV('MIDDLE')
    row.preview=V.Text(row,'',56,-31,212,12,V.muted);row.preview:SetWordWrap(false);row.preview:SetHeight(16);row.preview:SetJustifyV('MIDDLE')
    row.meta=V.Text(row,'',56,-48,212,11,V.gold);row.meta:SetWordWrap(false);row.meta:SetHeight(14);row.meta:SetJustifyV('MIDDLE')
    row.unread=CreateFrame('Frame',nil,row);row.unread:SetAllPoints();row.unread:EnableMouse(false)
    row.unread:SetFrameLevel(row:GetFrameLevel())
    local wash=row.unread:CreateTexture(nil,'BACKGROUND',nil,2);wash:SetColorTexture(.08,.35,.62,.24)
    wash:SetPoint('TOPLEFT',10,-9);wash:SetPoint('BOTTOMRIGHT',-10,9)
    row.unread.Wash=wash
    local gem=V.Texture(row.unread,'Logo',{236,22,278,72},'OVERLAY');gem:SetSize(14,17);gem:SetPoint('TOPRIGHT',-12,-10)
    row.unread.Gem=gem
    row:SetScript('OnClick',function(self) click(self.entry) end)
    row:SetScript('OnEnter',function(self) if not self.selected then self:SetAlpha(.8) end end)
    row:SetScript('OnLeave',function(self) self:SetAlpha(1) end)
    function row:Select(value) self.selected=value;self.ArtSelected:SetShown(value);self.ArtNormal:SetShown(not value) end
    return row
end
function V.IconButton(parent,name,size,x,y,click,title,help)
    local b=CreateFrame('Button',nil,parent);b:SetSize(size,size);b:SetPoint('TOPLEFT',x,y)
    b.Icon=V.Icon(b,name,size,0,0);b:SetScript('OnClick',click)
    b:SetScript('OnEnter',function(self) self.Icon:SetAlpha(.75) end)
    b:SetScript('OnLeave',function(self) self.Icon:SetAlpha(1) end)
    ns.Theme.Tooltip(b,title,help);return b
end
function V.Divider(parent,y)
    local t=V.Texture(parent,'Tabs',{69,1043,1186,1163},'ARTWORK')
    t:SetPoint('TOPLEFT',5,y);t:SetPoint('TOPRIGHT',-5,y);t:SetHeight(28);return t
end
function V.Document(parent,x,y,w,h)
    local scroll=CreateFrame('ScrollFrame',nil,parent);scroll:SetPoint('TOPLEFT',x,y);scroll:SetSize(w,h)
    V.SkinScroll(scroll)
    local doc=ns.Theme.ReadOnlyDocument(scroll)
    doc:SetStyle(parent.ChatWardenPaper and 'paper' or 'dark')
    return doc,scroll
end
function V.SkinScroll(scroll)
    if scroll.ChatWardenGoldScroll then return end
    if scroll.ScrollBar then
        scroll.ScrollBar:Hide();scroll.ScrollBar:HookScript('OnShow',function(self) self:Hide() end)
        -- Replace this owned frame's native scrollbar, rather than retaining
        -- two independent value->offset controllers on the same ScrollFrame.
        if not (scroll.ScrollBar.IsProtected and scroll.ScrollBar:IsProtected()) then scroll.ScrollBar:SetScript('OnValueChanged',nil) end
    end
    local parent=scroll:GetParent()
    local slider=CreateFrame('Slider',nil,parent);slider:SetPoint('TOPLEFT',scroll,'TOPRIGHT',5,-21);slider:SetPoint('BOTTOMRIGHT',scroll,'BOTTOMRIGHT',23,21)
    slider:SetOrientation('VERTICAL');slider:SetMinMaxValues(0,0);slider:SetValueStep(16);slider:SetValue(0)
    local track=V.Texture(slider,'Controls',{1122,155,1173,554},'BACKGROUND');track:SetAllPoints()
    slider:SetThumbTexture(base..'Controls.tga');local thumb=slider:GetThumbTexture();V.Region(thumb,'Controls',{1125,564,1171,742});thumb:SetSize(18,44)
    -- Native scroll templates maintain their own hidden scrollbar. Receiving a
    -- native offset must never write it back through our slider: float rounding
    -- (for example 672 versus 672.000061) otherwise creates a C callback loop.
    local synchronizing=false
    local epsilon=.01
    local function SliderValue(value)
        synchronizing=true;slider:SetValue(value);synchronizing=false
    end
    local function Move(amount) slider:SetValue((scroll:GetVerticalScroll() or 0)+amount) end
    local up=CreateFrame('Button',nil,parent);up:SetSize(20,20);up:SetPoint('TOPLEFT',scroll,'TOPRIGHT',4,0)
    local art=V.Texture(up,'Controls',{1119,94,1176,154});art:SetAllPoints();up:SetScript('OnClick',function() Move(-50) end)
    local down=CreateFrame('Button',nil,parent);down:SetSize(20,20);down:SetPoint('BOTTOMLEFT',scroll,'BOTTOMRIGHT',4,0)
    art=V.Texture(down,'Controls',{1121,750,1176,809});art:SetAllPoints();down:SetScript('OnClick',function() Move(50) end)
    slider:SetScript('OnValueChanged',function(_,value)
        if synchronizing then return end
        if math.abs((scroll:GetVerticalScroll() or 0)-value)>epsilon then scroll:SetVerticalScroll(value) end
    end)
    scroll:EnableMouseWheel(true);scroll:HookScript('OnMouseWheel',function(_,delta) Move(-delta*36) end)
    scroll:HookScript('OnVerticalScroll',function(_,offset)
        if math.abs((slider:GetValue() or 0)-offset)>epsilon then SliderValue(offset) end
    end)
    local maximum=0
    local function Range(vertical)
        vertical=math.max(0,vertical or 0)
        synchronizing=true;slider:SetMinMaxValues(0,vertical);synchronizing=false
        local offset=scroll:GetVerticalScroll() or 0
        local clamped=math.max(0,math.min(vertical,offset))
        SliderValue(clamped)
        if math.abs(offset-clamped)>epsilon then scroll:SetVerticalScroll(clamped) end
        maximum=vertical
        local h=math.max(1,scroll:GetHeight());thumb:SetHeight(math.max(24,math.min(h-42,(h-42)*h/(h+vertical))))
        local visible=scroll:IsShown();local enabled=vertical>epsilon
        slider:SetShown(visible);up:SetShown(visible);down:SetShown(visible)
        slider:SetEnabled(enabled);up:SetEnabled(enabled);down:SetEnabled(enabled)
        slider:SetAlpha(enabled and 1 or .45);up:SetAlpha(enabled and 1 or .45);down:SetAlpha(enabled and 1 or .45)
    end
    scroll.ChatWardenUpdateScrollRange=Range
    local function CurrentRange()
        Range(scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange() or maximum)
    end
    scroll:HookScript('OnScrollRangeChanged',function(_,_,vertical) Range(vertical) end)
    scroll:HookScript('OnShow',CurrentRange)
    scroll:HookScript('OnSizeChanged',CurrentRange)
    scroll:HookScript('OnHide',function() slider:Hide();up:Hide();down:Hide() end)
    scroll.ChatWardenGoldScroll=slider;CurrentRange();return slider
end
