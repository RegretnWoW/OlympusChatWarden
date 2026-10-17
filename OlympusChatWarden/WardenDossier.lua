-- Read-only equipment projection and a GUID-bound native model. No inspect requests.
local _,ns=...
local G={BUDGET=128,caches=setmetatable({},{__mode='kv'})};ns.WardenDossier=G
local V,S,X=ns.Art,ns.ChronicleStore,ns.ChronicleCapture
local Safe=ns.WardenBrand.Text
local function Stamp(at) return at and (ns.SafeCall(date,'%Y-%m-%d %H:%M',at) or tostring(at)) or 'Date not recorded' end
local function Call(object,name,...) local fn=object and object[name];if type(fn)=='function' then return pcall(fn,object,...) end;return false end
local function Guid(unit) return S.GUID(ns.SafeCall(UnitGUID,unit)) end
local function Visible(unit,guid) return Guid(unit)==guid and ns.Checked(ns.SafeCall(UnitIsVisible,unit)) and ns.Checked(ns.SafeCall(UnitIsPlayer,unit)) end
local function Icon(value)
    if not ns.Readable(value) then return end
    if type(value)=='number' and value>0 or type(value)=='string' and value~='' then return value end
end
local slotStates={empty='Confirmed empty',pending='Item observed; full item link unavailable',unavailable='Not inspected'}
function G.ItemClick(slot,button)
    if button and button~='LeftButton' or not ns.Membership.Allowed() then return end
    local link=slot.clickLink
    if not link then return end
    -- Let the client apply its configured chat-link/dress-up modifier bindings.
    -- This does not post chat, equip an item or alter the historical snapshot.
    ns.SafeCall(HandleModifiedItemClick,link)
end
local function SlotTooltip(slot)
    if not GameTooltip then return end
    GameTooltip:SetOwner(slot,'ANCHOR_RIGHT');GameTooltip:SetText(slot.label)
    if slot.link then ns.SafeCall(GameTooltip.SetHyperlink,GameTooltip,slot.link) end
    GameTooltip:AddLine(slot.itemName or slotStates[slot.state] or 'Item details not cached',.88,.9,.93,true)
    if slot.itemID and not slot.itemName then GameTooltip:AddLine('Item #'..slot.itemID..' • waiting for client item data',.88,.9,.93,true) end
    GameTooltip:AddLine(slot.observed or 'No recorded equipment evidence',.75,.8,.85,true)
    if slot.clickLink then GameTooltip:AddLine('Shift-click: link to chat • Ctrl-click: dressing room (default bindings)',.65,.8,1,true)
    elseif slot.itemID then GameTooltip:AddLine('A full recorded item link is unavailable; linking is disabled.',.75,.8,.85,true) end
    GameTooltip:Show()
end
function G.Resolve(guid)
    if not S.GUID(guid) then return end
    for _,unit in ipairs({'player','target','focus','mouseover'}) do if Visible(unit,guid) then return unit end end
    for _,spec in ipairs({{'party',4},{'raid',40},{'arena',5}}) do
        for n=1,spec[2] do local unit=spec[1]..n;if Visible(unit,guid) then return unit end end
    end
end
function G.Request(owner)
    local c=S.Character(owner,false);if not c then return end
    local j=G.caches[c]
    if not j or j.events~=c.events or j.length>#c.events or (j.length>0 and (c.events[j.length] or {}).id~=j.lastID) then
        j={owner=owner,own=owner:match('/(Player%-.+)$'),character=c,events=c.events,length=0,objects={},refs={},players={},talentPlayers={},configurations={gear={},traits={}},phase='events',cursor=1,refCursor=1};G.caches[c]=j
    end
    if #c.events>j.length and j.done then j.done=nil;j.phase='events';j.cursor=j.length+1 end
    return j
end
local function Add(j,guid,row,family)
    local players=family=='traits' and j.talentPlayers or j.players
    local p=players[guid];if not p then p={};players[guid]=p end
    p[#p+1]=row
    local catalog=j.configurations[family];local byGUID=catalog[guid] or {};catalog[guid]=byGUID
    local config=byGUID[row.hash]
    if not config then config={object=row.object,hash=row.hash,observations={},at=row.at,event=row.event,firstAt=row.at};byGUID[row.hash]=config end
    if not row.standalone then
        config.observations[#config.observations+1]=row
        config.firstAt=math.min(config.firstAt,row.at)
        if row.at>=config.at then config.at=row.at;config.event=row.event end
    end
end
function G.Pump(j,budget)
    if not j or j.done or InCombatLockdown and InCombatLockdown() then return end
    if S.Character(j.owner,false)~=j.character or j.character.events~=j.events or (j.length>0 and (j.events[j.length] or {}).id~=j.lastID) then j.stale=true;j.done=true;return end
    local P=ns.WardenPerformance;local deadline,start=P.Begin();local used=0
    for _=1,math.min(budget or G.BUDGET,G.BUDGET) do
        if P.Expired(deadline) then break end;used=used+1
        if j.phase=='events' then
            local e=j.events[j.cursor]
            if not e then j.phase='refs' else
                local d=e.details or {};local cap=e.capture
                local own=j.own
                if cap and (cap.family=='gear' or cap.family=='traits') and S.GUID(cap.values.guid) then
                    j.objects[d.contentID]=e
                    if cap.values.guid~=own then Add(j,cap.values.guid,{object=e,event=e,at=e.at,hash=d.contentID,standalone=true},cap.family) end
                elseif (e.kind=='important_player' or d.recordType=='duel_capture') and (d.gearRef or d.traitRef) and S.GUID(e.subject) and e.subject~=own then j.refs[#j.refs+1]=e end
                j.length=j.cursor;j.lastID=e.id;j.cursor=j.cursor+1
            end
        else
            local e=j.refs[j.refCursor]
            if not e then j.done=true;j.revision=(j.revision or 0)+1;break end
            local d=e.details
            -- Some player observations carry the recorder's own loadout reference.
            -- The snapshot's GUID is authoritative, never the surrounding subject.
            for key,family in pairs({gear='gear',trait='traits'}) do
                local hash=d[key..'Ref'];local o=hash and j.objects[hash]
                if o and o.capture.family==family and e.subject==o.capture.values.guid then
                    Add(j,o.capture.values.guid,{object=o,event=e,at=d[key..'ObservedAt'] or e.at,hash=hash},family)
                end
            end
            j.refCursor=j.refCursor+1
        end
    end
    P.End('dossier index',start,used)
end
function G.Rows(j,guid,family)
    if not j or not j.done then return {} end
    local players=family=='traits' and j.talentPlayers or j.players
    local rows,referenced={},{}
    for _,r in ipairs(players[guid] or {}) do if not r.standalone then referenced[r.hash]=true end end
    for _,r in ipairs(players[guid] or {}) do if not r.standalone or not referenced[r.hash] then rows[#rows+1]=r end end
    table.sort(rows,function(a,b) return a.at>b.at or a.at==b.at and a.event.id<b.event.id end)
    -- Unchanged checkpoints share one content object. Keep the latest observation
    -- of each consecutive loadout; returning to a previous set remains a change.
    local changes={};for _,r in ipairs(rows) do if not changes[#changes] or changes[#changes].hash~=r.hash then changes[#changes+1]=r end end
    return changes
end
function G.Configurations(j,guid,family)
    if not j or not j.done then return {} end
    local rows={}
    for _,r in pairs(j.configurations[family or 'gear'][guid] or {}) do
        rows[#rows+1]=r
    end
    table.sort(rows,function(a,b) return a.at>b.at or a.at==b.at and a.hash<b.hash end)
    return rows
end
G.slots={{1,'Head'},{2,'Neck'},{3,'Shoulders'},{15,'Back'},{5,'Chest'},{4,'Shirt'},{19,'Tabard'},{9,'Wrists'},
    {10,'Hands'},{6,'Waist'},{7,'Legs'},{8,'Feet'},{11,'Finger 1'},{12,'Finger 2'},{13,'Trinket 1'},{14,'Trinket 2'},
    {16,'Main hand'},{17,'Off hand'},{18,'Ranged'}}
function G.Slot(row,slot)
    local v=row and row.object.capture.values
    if not v then return {slot,'unavailable',false,false} end
    for _,r in ipairs(v.slots or {}) do if r[1]==slot then return r end end
    return {slot,'unavailable',false,false}
end
function G.Specialization(id)
    id=S.Integer(id,1,1000000);if not id then return end
    -- Display metadata only, resolved by the saved ID. No own-player spec or
    -- assumed retail ID table is used when this client cannot resolve it.
    local found,name,description,icon=ns.WardenBrand.Values(GetSpecializationInfoByID,id)
    name=S.Text(name,144)
    if S.Integer(found,1)~=id or not name then return end
    return name,Icon(icon)
end
function G.TalentLabel(row)
    -- Selection and rank come from the dated snapshot. Names/icons are current
    -- client metadata for those saved IDs, not a new inspection or tree guess.
    local spell=row[6]~=false and row[6] or nil
    local definition=row[5]~=false and X.Table(X.Call('C_Traits.GetDefinitionInfo',row[5])) or nil
    if definition and S.Integer(definition.spellID,1)~=spell then definition=nil end
    local info=spell and X.Table(X.Call('C_Spell.GetSpellInfo',spell))
    if info and info.spellID and S.Integer(info.spellID)~=spell then info=nil end
    local name=definition and S.Text(definition.overrideName,144) or info and S.Text(info.name,144)
    local icon=definition and Icon(definition.overrideIcon) or info and Icon(info.iconID)
    if spell and not name then
        local label,_,texture=ns.WardenBrand.Values(GetSpellInfo,spell)
        name=S.Text(label,144);icon=icon or Icon(texture)
    end
    return name or 'Talent name unavailable',icon,spell
end
function G.BuildTalents(parent)
    local p=V.Panel(parent,0,-96,1136,560,'dark');p:Hide();p.rows={};p.index=1
    p.identity=V.Text(p,'Recorded talents',20,-18,1096,21,V.gold);p.identity:SetHeight(30)
    p.status=V.Text(p,'',20,-59,1096,13,V.muted);p.status:SetHeight(44)
    p.previous=V.Button(p,'Older build',20,-111,170,30,function() p.index=p.index+1;p.observationIndex=1;p:Render() end,'neutral')
    p.next=V.Button(p,'Newer build',202,-111,170,30,function() p.index=math.max(1,p.index-1);p.observationIndex=1;p:Render() end,'neutral')
    p.source=V.Button(p,'Original evidence',384,-111,190,30,function()
        local r=p.rows[p.index];local c=S.Character(p.owner,false)
        if r and p.job and not p.job.stale and c==p.job.character and c.events==p.job.events then ns.RecordingUI.OpenSource(nil,r.event) end
    end,'neutral')
    p.select=V.Button(p,'Select export text',586,-111,200,30,function() p.export:SetFocus();p.export:HighlightText() end,'neutral')
    p.specIcon=p:CreateTexture(nil,'ARTWORK');p.specIcon:SetPoint('TOPLEFT',20,-163);p.specIcon:SetSize(48,48);p.specIcon:Hide()
    p.detail=V.Text(p,'',80,-161,1036,14,V.gold);p.detail:SetHeight(60)
    p.choicesTitle=V.Text(p,'Recorded selected talents',20,-229,1096,15,V.blue)
    p.choicesScroll=CreateFrame('ScrollFrame',nil,p);p.choicesScroll:SetPoint('TOPLEFT',20,-255);p.choicesScroll:SetSize(1068,174);V.SkinScroll(p.choicesScroll)
    p.choicesContent=CreateFrame('Frame',nil,p.choicesScroll);p.choicesContent:SetSize(1068,174);p.choicesScroll:SetScrollChild(p.choicesContent)
    p.choicesEmpty=V.Text(p.choicesContent,'',12,-14,1020,15,V.muted);p.choicesEmpty:SetHeight(130);p.choiceCards={}
    V.Text(p,'Original native export • Ctrl+C to copy',20,-443,1096,13,V.blue)
    p.export=V.Edit(p,20,-465,1096,42,'No talent export was recorded.',nil,true);p.export.ChatWardenNoSpelling=true
    p.export:HookScript('OnTextChanged',function(self,user) if user then self:SetText(p.exportValue or '') end end)
    local help=V.Text(p,'Historical selections and ranks; names and icons use current client data. No new inspection is requested here. Unavailable choices and talent-tree connections are not guessed.',20,-519,1096,13,V.muted);help:SetHeight(32)
    function p:RenderChoices(values)
        local choices=values and values.choices or {};local count=#choices
        self.choicesTitle:SetText('Recorded selected talents'..(values and values.choices and (' • '..count..' entries'..(not values.choicesComplete and ' • partial coverage' or '')) or ''))
        for _,card in ipairs(self.choiceCards) do card:Hide() end
        self.choicesEmpty:SetShown(count==0)
        self.choicesEmpty:SetText(values and values.choices and (values.choicesComplete and 'The native inspection reported no selected talents.' or 'No readable choices were returned. The original export is retained below.')
            or values and 'This older inspection saved an export or specialization only. Inspect the player again with this build to record readable choices when the client provides them.'
            or 'No talent choices have been recorded for this player.')
        for n,row in ipairs(choices) do
            local card=self.choiceCards[n]
            if not card then
                card=V.Panel(self.choicesContent,((n-1)%2)*534,-math.floor((n-1)/2)*60,526,54,'dark')
                card.icon=card:CreateTexture(nil,'ARTWORK');card.icon:SetPoint('LEFT',8,0);card.icon:SetSize(32,32)
                card.name=V.Text(card,'',49,-6,464,14,V.gold);card.name:SetHeight(22);card.name:SetWordWrap(false)
                card.rank=V.Text(card,'',49,-30,464,12,V.muted);card.rank:SetHeight(20);card.rank:SetWordWrap(false)
                card:EnableMouse(true);card:SetScript('OnEnter',function(self)
                    if not GameTooltip then return end
                    GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText(self.label)
                    if self.spell then ns.SafeCall(GameTooltip.SetSpellByID,GameTooltip,self.spell) end
                    GameTooltip:AddLine('Recorded rank '..self.recordedRank..' • '..self.observed,.65,.8,1,true);GameTooltip:Show()
                end);card:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
                self.choiceCards[n]=card
            end
            local name,icon,spell=G.TalentLabel(row);card.label=name;card.spell=spell;card.recordedRank=row[4];card.observed=Stamp(self.rows[self.index].at)
            card.icon:SetTexture(icon or 'Interface\\Icons\\INV_Misc_QuestionMark');card.name:SetText(Safe(name))
            card.rank:SetText('Rank '..row[4]);card:Show()
        end
        local height=math.max(174,math.ceil(count/2)*60);self.choicesContent:SetHeight(height)
        self.choicesScroll:SetVerticalScroll(0);self.choicesScroll.ChatWardenUpdateScrollRange(height-174)
    end
    function p:Render()
        self.index=math.max(1,math.min(self.index,math.max(1,#self.rows)))
        local r=self.rows[self.index];local values=r and r.object.capture.values
        self.previous:SetEnabled(self.index<#self.rows);self.next:SetEnabled(self.index>1);self.source:SetEnabled(r~=nil)
        self.exportValue=values and values.exportString or '';self.export:SetText(self.exportValue);self.select:SetEnabled(self.exportValue~='')
        self:RenderChoices(values)
        if values then
            self.status:SetText('Historical inspection • Observed '..Stamp(r.at)..' • Build '..self.index..' of '..#self.rows)
            local info=values.exportString and 'Native inspected talent export saved.' or 'Partial inspection: native export unavailable.'
            local name,icon=G.Specialization(values.specializationID)
            self.specIcon:SetTexture(icon or 'Interface\\Icons\\INV_Misc_QuestionMark');self.specIcon:Show()
            self.detail:SetText('Specialization: '..(name or 'Name unavailable')..'\n'..info..'\nOriginal evidence contains the inspection details.')
        else
            self.specIcon:Hide()
            self.status:SetText('No recorded talent build for this player.')
            self.detail:SetText(ns.Chronicle.Active() and 'Inspect this player normally while they are available. Supported native talent data will be saved after the matching response.' or 'Recording is paused. Enable it in Data & Backups before inspecting a player to retain supported talents.')
        end
    end
    function p:SetProfile(owner,row)
        local guid=row and row.id
        if guid~=self.guid or owner~=self.owner then self.rows={};self.index=1;self.jobRevision=nil end
        self.owner=owner;self.guid=guid;self.job=guid and G.Request(owner)
        self.identity:SetText(Safe(row and row.title or 'Select a recorded player')..' • Talents & specialization');self:Render()
    end
    p:SetScript('OnUpdate',function(self)
        if not self.job then return end
        G.Pump(self.job)
        if self.job.stale then self.rows={};self:Render();self.status:SetText('Saved history changed. Reopen this dossier to refresh its talents.')
        elseif self.job.done and self.jobRevision~=self.job.revision then self.rows=G.Rows(self.job,self.guid,'traits');self.jobRevision=self.job.revision;self:Render()
        elseif not self.job.done then self.status:SetText('Reading saved inspection evidence... '..self.job.length..' records checked.') end
    end)
    return p
end
function G.Build(parent,host)
    local p=V.Panel(parent,0,-96,1136,560,'dark');p:Hide()
    p.identity=V.Text(p,'Select a recorded player',20,-13,1090,21,V.gold);p.identity:SetHeight(28);p.identity:SetWordWrap(false)
    p.context=V.Text(p,'',20,-46,1090,13,V.muted);p.context:SetHeight(24);p.context:SetWordWrap(false)
    p.live=V.Button(p,'Live model',20,-78,174,30,function() p.view='live';p:Bind(true);p:Render() end,'neutral')
    p.recorded=V.Button(p,'Last Recorded Gear',204,-78,202,30,function() p.view='history';p.index=1;p.observationIndex=1;p:Bind();p:Render() end,'neutral')
    p.previous=V.Button(p,'Older gear',640,-78,144,30,function() p.index=p.index+1;p.observationIndex=1;p:Render() end,'neutral')
    p.next=V.Button(p,'Newer gear',794,-78,144,30,function() p.index=math.max(1,p.index-1);p.observationIndex=1;p:Render() end,'neutral')
    p.observation=V.Button(p,'Observation',416,-78,214,30,function()
        local r=p.rows and p.rows[p.index];local count=r and #r.observations or 0
        p.observationIndex=count>0 and (p.observationIndex or 1)%count+1 or 1;p:Render()
    end,'neutral')
    p.source=V.Button(p,'Original evidence',948,-78,168,30,function()
        local r=p:Observation();local c=S.Character(p.owner,false)
        if not r then return end
        if not p.job or p.job.stale or c~=p.job.character or c.events~=p.job.events then p.status:SetText('Saved history changed. Reopen this dossier to refresh its equipment.');return end
        ns.RecordingUI.OpenSource(nil,r.event)
    end,'neutral')
    local stage=V.Panel(p,304,-120,528,374,'minimal')
    local crest=V.Icon(stage,'intel',100,214,-48);crest:SetAlpha(.8)
    p.classIcon=stage:CreateTexture(nil,'ARTWORK');p.classIcon:SetPoint('TOPLEFT',232,-66);p.classIcon:SetSize(64,64);p.classIcon:Hide()
    p.placeholder=V.Text(stage,'Recorded identity',20,-245,488,13,V.muted);p.placeholder:SetJustifyH('CENTER');p.placeholder:SetHeight(70)
    p.identityCard=V.Text(stage,'',20,-158,488,18,V.gold);p.identityCard:SetHeight(82);p.identityCard:SetJustifyH('CENTER')
    p.modelStatus=V.Text(stage,'',12,-6,504,12,V.muted);p.modelStatus:SetJustifyH('CENTER');p.modelStatus:SetHeight(38)
    local ok,model=pcall(CreateFrame,'PlayerModel',nil,stage)
    if ok and model and type(model.SetUnit)=='function' then
        p.model=model;model:SetPoint('TOPLEFT',20,-40);model:SetSize(488,244)
        Call(model,'SetKeepModelOnHide',true);model:Hide();model:EnableMouse(true);model:EnableMouseWheel(true)
        model:SetScript('OnMouseDown',function(_,button) if button=='LeftButton' then p.dragX=ns.SafeNumber(ns.SafeCall(GetCursorPosition)) end end)
        model:SetScript('OnMouseUp',function() p.dragX=nil end)
        model:SetScript('OnMouseWheel',function(_,delta) p:Zoom(delta) end)
        model:SetScript('OnModelLoaded',function() if p.unit and not Visible(p.unit,p.guid) then p:ClearModel('Player is no longer available.') end end)
    elseif model and model.Hide then model:Hide() end
    p.reset=V.Button(p,'Reset model',486,-412,164,28,function() p:Reset() end,'neutral')
    p.zoomOut=V.Button(p,'−',446,-412,32,28,function() p:Zoom(-1) end,'neutral')
    p.zoomIn=V.Button(p,'+',658,-412,32,28,function() p:Zoom(1) end,'neutral')
    p.status=V.Text(p,'',20,-507,1096,13,V.muted);p.status:SetHeight(44)
    p.slots={}
    for n,spec in ipairs(G.slots) do
        local x,y,w
        if n<=8 then x,y,w=18,-122-(n-1)*45,276
        elseif n<=16 then x,y,w=842,-122-(n-9)*45,276
        else x,y,w=310+(n-17)*174,-454,166 end
        local b=V.Button(p,'',x,y,w,42,G.ItemClick,'row');b.slot=spec[1];b.label=spec[2]
        b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetPoint('TOPLEFT',5,-5);b.icon:SetSize(32,32)
        b.quality=b:CreateTexture(nil,'BORDER');b.quality:SetPoint('TOPLEFT',3,-3);b.quality:SetSize(36,36)
        b.title=V.Text(b,spec[2],45,-3,w-50,12,V.blue);b.title:SetHeight(17);b.title:SetWordWrap(false)
        b.name=V.Text(b,'Not observed',45,-21,w-50,12,V.muted);b.name:SetHeight(18);b.name:SetWordWrap(false)
        b:SetScript('OnEnter',function(self) p.hoveredSlot=self;SlotTooltip(self) end)
        b:SetScript('OnLeave',function(self) if p.hoveredSlot==self then p.hoveredSlot=nil end;if GameTooltip then GameTooltip:Hide() end end)
        p.slots[n]=b
    end
    function p:ClearModel(message)
        self.unit=nil;self.dragX=nil
        if self.model then self.model:Hide();Call(self.model,'ClearModel') end
        self.placeholder:SetText(message or 'No live character available');self.placeholder:Show();self.identityCard:Show();self.modelStatus:SetText('Recorded identity • exact offline model unavailable')
        self.reset:SetEnabled(false);self.zoomIn:SetEnabled(false);self.zoomOut:SetEnabled(false)
        if self.status then self.status:SetText((self.observationText or '')..'\nRecorded identity and equipment. A live model requires this exact player to be available.') end
    end
    function p:Reset()
        self.rotation=0;self.zoom=1
        if self.unit and Visible(self.unit,self.guid) then
            Call(self.model,'SetPortraitZoom',0);Call(self.model,'SetCamDistanceScale',1);Call(self.model,'SetPosition',0,0,0);Call(self.model,'SetRotation',0)
        end
    end
    function p:Zoom(delta)
        if not self.unit or not Visible(self.unit,self.guid) then self:ClearModel();return end
        self.zoom=math.max(.55,math.min(1.8,(self.zoom or 1)-delta*.1));Call(self.model,'SetCamDistanceScale',self.zoom)
    end
    function p:Bind(force)
        if not ns.Membership.Allowed() then self:ClearModel('Olympus membership access is required.');return end
        if self.view=='history' then self:ClearModel('Historical gear only\nExact offline appearance is unavailable.');return end
        if InCombatLockdown and InCombatLockdown() then self:ClearModel('Live models refresh after combat.');return end
        local unit=G.Resolve(self.guid)
        if not unit or not self.model then self:ClearModel();return end
        if not force and self.unit==unit then return end
        self:ClearModel();Call(self.model,'SetKeepModelOnHide',true)
        -- Forever can reject SetUnit on a hidden PlayerModel. Show this owned
        -- widget first; failure still clears it instead of displaying a substitute.
        self.unit=unit;self.model:Show();local success,value=Call(self.model,'SetUnit',unit,false,true)
        if not success or value~=true or self.unit~=unit or not Visible(unit,self.guid) then self:ClearModel('Native model could not be loaded.');return end
        self.placeholder:Hide();self.identityCard:Hide();self.modelStatus:SetText('Live Appearance • currently visible player');self:Reset()
        self.reset:SetEnabled(true);self.zoomIn:SetEnabled(true);self.zoomOut:SetEnabled(true)
        if self.status then self.status:SetText((self.observationText or '')..'\nLive appearance can differ from saved gear. Drag to rotate; wheel to zoom.') end
    end
    function p:Observation()
        local r=self.rows and self.rows[self.index]
        if r and not r.observations then return r end
        return r and (r.observations[math.max(1,#r.observations-(self.observationIndex or 1)+1)] or r)
    end
    function p:Render()
        if self.rendering then self.itemDirty=true;return end
        self.rendering=true
        self.index=math.max(1,math.min(self.index or 1,math.max(1,#(self.rows or {}))))
        local configuration=self.rows and self.rows[self.index];local r=self:Observation();local observed=r and ('Historical gear • observed '..Stamp(r.at)) or 'No recorded equipment snapshot'
        local times=configuration and configuration.observations and #configuration.observations or 0
        self.observationIndex=math.max(1,math.min(self.observationIndex or 1,math.max(1,times)))
        self.observation:SetText('Observation '..(times>0 and (self.observationIndex or 1)..' / '..times or 'unavailable'));self.observation:SetEnabled(times>1)
        local identity
        local facts=self.identityFacts or {}
        for n=#facts,math.max(1,#facts-127),-1 do local e=facts[n];if not r or e.at<=r.at then identity=e;break end end
        local d=identity and identity.details or {}
        self.identityCard:SetText(Safe(d.name or self.identity:GetText())..'\n'..Safe(table.concat({d.race or 'Race unknown',d.class or 'Class unknown',d.level and 'Level '..d.level or 'Level unknown'},' • '))..'\n'..Safe(d.guild or 'Guild not observed'))
        local coords=CLASS_ICON_TCOORDS and d.class and CLASS_ICON_TCOORDS[d.class]
        if X.Table(coords) and S.Number(coords[1],0,1) and S.Number(coords[2],0,1) and S.Number(coords[3],0,1) and S.Number(coords[4],0,1) then
            self.classIcon:SetTexture('Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes');self.classIcon:SetTexCoord(unpack(coords));self.classIcon:SetShown(self.unit==nil)
        else self.classIcon:Hide() end
        self.previous:SetEnabled(r~=nil and self.index<#self.rows);self.next:SetEnabled(r~=nil and self.index>1);self.source:SetEnabled(r~=nil)
        self.live:SetText(self.view=='live' and 'Live model • selected' or 'Live model');self.recorded:SetText(self.view=='history' and 'Recorded Gear • selected' or 'Last Recorded Gear')
        local help=self.unit and Visible(self.unit,self.guid) and 'Live appearance can differ from saved gear. Drag to rotate; wheel to zoom.'
            or r and 'Recorded gear and identity. Exact offline appearance is unavailable.'
            or ns.Chronicle.Active() and 'Inspect this player normally to save a GUID-matched equipment observation.'
            or 'Chronicle recording is paused. Enable it in Data & Backups, then inspect to save gear.'
        self.observationText=observed..(r and (' • Gear set '..self.index..' of '..#self.rows..' • '..times..' observations') or '')
        self.status:SetText(self.observationText..'\n'..help)
        local requests=self.itemRequests or {};local currentRequests={}
        self.itemRequests=requests -- synchronous client cache callbacks can now mark these IDs dirty
        for _,b in ipairs(self.slots) do
            local s=G.Slot(r,b.slot);b.state=s[2];b.link=s[4]~=false and s[4] or nil;b.observed=observed;b.itemName=nil;b.clickLink=nil
            b.itemID=s[3]~=false and s[3] or nil
            local name,link,quality,_,_,_,_,_,_,icon
            local info=GetItemInfo or C_Item and C_Item.GetItemInfo
            if s[3] and s[3]~=false then name,link,quality,_,_,_,_,_,_,icon=ns.WardenBrand.Values(info,b.link or s[3]) end
            name=ns.SafeString(name,256);quality=ns.SafeNumber(quality);icon=Icon(icon)
            if b.itemID and not icon then
                local _,_,_,_,instant=ns.WardenBrand.Values(GetItemInfoInstant or C_Item and C_Item.GetItemInfoInstant,b.link or b.itemID)
                icon=Icon(instant) or Icon(ns.SafeCall(GetItemIcon or C_Item and C_Item.GetItemIconByID,b.itemID))
            end
            b.itemName=name;b.name:SetText(Safe(name or (s[3] and s[3]~=false and ('Item #'..s[3]) or s[2]=='empty' and 'Confirmed empty' or 'Not inspected')))
            b.icon:SetTexture(icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
            if b.link and name then
                -- Keep the exact recorded payload, including enchants and suffixes.
                -- Only the cached display label comes from the current client.
                local label=name:gsub('[|%[%]\r\n]','')
                b.clickLink='|H'..b.link..'|h['..label..']|h'
            end
            if b.itemID and (not name or not icon) then
                currentRequests[b.itemID]=true
                local request=C_Item and C_Item.RequestLoadItemDataByID
                if not requests[b.itemID] and type(request)=='function' then
                    requests[b.itemID]=true;ns.SafeCall(request,b.itemID)
                end
            end
            local r,g,blue=.28,.32,.37
            if quality then local qr,qg,qb=ns.WardenBrand.Values(GetItemQualityColor or C_Item and C_Item.GetItemQualityColor,quality);if ns.SafeNumber(qr) and ns.SafeNumber(qg) and ns.SafeNumber(qb) then r,g,blue=qr,qg,qb end end
            b.quality:SetColorTexture(r,g,blue,1)
        end
        self.itemRequests=currentRequests;self.rendering=nil
        if self.hoveredSlot then SlotTooltip(self.hoveredSlot) end
    end
    function p:SetProfile(owner,row,st)
        local guid=row and row.id
        if guid~=self.guid or owner~=self.owner then self:ClearModel();self.rows={};self.index=1;self.guid=guid;self.owner=owner;self.job=nil;self.jobRevision=nil end
        local pr=row and ns.ChronicleIntelligence.Player(st,guid);local facts=pr and pr.facts;local e=facts and facts[#facts];local d=e and e.details or {}
        self.identity:SetText(Safe(row and row.title or 'Select a recorded player'))
        local parts={};for _,v in ipairs({d.class or '',d.level and ('Level '..d.level) or '',d.guild or ''}) do if v~='' then parts[#parts+1]=v end end
        self.context:SetText(Safe(table.concat(parts,' • '))..(e and ' • Identity observed '..Stamp(e.at) or ''))
        self.identityFacts=facts;self.job=guid and G.Request(owner);self:Bind();self:Render()
    end
    p.view='live';p.rows={};p.index=1;p:ClearModel()
    p:SetScript('OnUpdate',function(self,elapsed)
        if self.itemDirty then self.itemDirty=nil;self:Render() end
        if self.job then
            G.Pump(self.job)
            if self.job.stale then self.rows={};self:Render();self.status:SetText('Saved history changed. Reopen this dossier to refresh its equipment.')
            elseif self.job.done and self.jobRevision~=self.job.revision then self.rows=G.Configurations(self.job,self.guid);self.jobRevision=self.job.revision;self:Render()
            elseif not self.job.done then self.status:SetText('Reading saved equipment evidence... '..self.job.length..' records checked. No inspection requested.') end
        end
        if self.unit and not Visible(self.unit,self.guid) then self:ClearModel('Player moved out of range or is no longer selected.') end
        if self.dragX and self.unit then
            local x=ns.SafeNumber(ns.SafeCall(GetCursorPosition));if x then self.rotation=(self.rotation or 0)+(x-self.dragX)*.01/math.max(.1,self:GetEffectiveScale());self.dragX=x;Call(self.model,'SetRotation',self.rotation) end
        end
    end)
    p:SetScript('OnHide',function(self) self:ClearModel();self.hoveredSlot=nil;if GameTooltip then GameTooltip:Hide() end end)
    for _,event in ipairs({'PLAYER_TARGET_CHANGED','PLAYER_FOCUS_CHANGED','UPDATE_MOUSEOVER_UNIT','GROUP_ROSTER_UPDATE','UNIT_MODEL_CHANGED','UNIT_INVENTORY_CHANGED','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED','GET_ITEM_INFO_RECEIVED','ITEM_DATA_LOAD_RESULT'}) do pcall(p.RegisterEvent,p,event) end
    p:SetScript('OnEvent',function(self,event,unit)
        if not self:IsShown() or not host:IsShown() then return end
        if event=='GET_ITEM_INFO_RECEIVED' or event=='ITEM_DATA_LOAD_RESULT' then
            local id=ns.SafeNumber(unit);if id and self.itemRequests and self.itemRequests[id] then self.itemDirty=true end;return
        end
        if event=='UNIT_MODEL_CHANGED' or event=='UNIT_INVENTORY_CHANGED' then
            if not ns.CanRead(unit) or unit~=self.unit then return end
        end
        self:Bind(true)
    end)
    return p
end
