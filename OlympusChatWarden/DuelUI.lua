-- Historical duel analysis: all reads use original ledger references.
local _,ns=...
local D,A,S,X,G,V,T=ns.ChronicleDuels,ns.ChronicleActivities,ns.ChronicleStore,ns.ChronicleCapture,ns.WardenDossier,ns.Art,ns.Theme
local U={};ns.DuelUI=U
local function Stamp(at) return at and (ns.SafeCall(date,'%Y-%m-%d %H:%M:%S',at) or tostring(at)) or 'Not observed' end
local function Own(owner) return owner:match('/(Player%-.+)$') end
local function Object(objects,e,key,guid)
    local id=e and e.details[key];local o=id and objects and objects[id]
    if o and o.capture.values.guid==guid then return o end
end
function U.Blocks(st,a)
    local d=a.duel;local out={};local function Put(kind,text) out[#out+1]={kind=kind,text=text} end
    Put('title',ns.ChronicleActivitiesUI.DuelLabel(a))
    Put('body','Opponent: '..(a.opponentGUID and A.Name(st,a.opponentGUID,a.lastAt) or 'Identity unavailable')..'\n'..Stamp(a.startAt)..' • '..(a.context.zone or 'Zone unavailable'))
    Put('body',a.endAt and 'Observed end: '..Stamp(a.endAt) or 'Completion unobserved')
    Put('meta','Accepted countdown is the observed boundary. Exact combat start/duration is unavailable. No damage meter or scoreboard was attributed to this duel.')
    return out
end
function U.Build(parent,host)
    G=ns.WardenDossier -- Dossier UI is loaded later; resolve after startup.
    local p=V.Panel(parent,444,-139,692,468,'dark');p:Hide();p.phase='before';p.sides={}
    p.title=V.Text(p,'Duel Analysis',16,-10,660,20,V.gold);p.title:SetHeight(26)
    p.before=V.Button(p,'Before',16,-44,100,28,function() p.phase='before';p.selectedEvidence=nil;p:Render() end,'neutral')
    p.after=V.Button(p,'After',126,-44,100,28,function() p.phase='after';p.selectedEvidence=nil;p:Render() end,'neutral')
    p.allSlots=V.Button(p,'Show all slots',236,-44,202,28,function() p.showUnknown=not p.showUnknown;p:Render() end,'neutral')
    p.evidence=V.Button(p,'Selected evidence',452,-44,224,28,function()
        local a=p.activity
        local e=p.selectedEvidence or a and (D.Observation(a,a.opponentGUID,p.phase) or D.Observation(a,Own(a.owner),p.phase) or p.state.events[a.anchor])
        if e then ns.RecordingUI.OpenSource(nil,e) end
    end,'neutral')
    for n=1,2 do
        local side={};p.sides[n]=side;local x=16+(n-1)*338
        side.identity=V.Text(p,'',x,-83,320,15,V.gold);side.identity:SetHeight(42)
        side.date=V.Text(p,'',x,-127,320,11,V.muted);side.date:SetHeight(32)
        side.list=V.ScrollingList(p,x,-165,304,172,30,function(parentRow)
            local row=V.Button(parentRow,'',0,0,302,28,function(self,button)
                p.selectedEvidence=self.evidence;G.ItemClick(self,button)
            end,'row')
            row.icon=row:CreateTexture(nil,'ARTWORK');row.icon:SetPoint('LEFT',3,0);row.icon:SetSize(22,22)
            row.title=V.Text(row,'',31,-5,265,12,V.muted);row.title:SetHeight(18);row.title:SetWordWrap(false)
            row:SetScript('OnEnter',function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
                if self.link then ns.SafeCall(GameTooltip.SetHyperlink,GameTooltip,self.link) else GameTooltip:SetText(self.title:GetText()) end
                GameTooltip:AddLine(self.observed or 'Unobserved',.8,.85,.9,true);GameTooltip:Show()
            end)
            row:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
            return row
        end,function(row,item)
            row.link=item.link;row.clickLink=item.clickLink;row.evidence=item.evidence;row.observed=item.observed
            row.icon:SetTexture(item.icon or 'Interface\\Icons\\INV_Misc_QuestionMark');row.title:SetText(item.label)
        end)
        side.summary=V.Text(p,'',x,-348,320,12,V.blue);side.summary:SetHeight(58)
        side.traits=V.Button(p,'Recorded talents',x,-411,304,26,function() p:Talents(n) end,'neutral')
    end
    p.limits=V.Text(p,'Attacker unknown for received totals. Snapshots cannot prove gear used throughout.',16,-442,660,11,V.muted);p.limits:SetHeight(24)
    function p:Talents(n)
        local side=self.sides[n];local object=side.trait
        if not object then return end
        local popup=self.talentPopup
        if not popup then
            popup=V.Panel(UIParent,0,0,640,480,'dark');popup:ClearAllPoints();popup:SetPoint('CENTER');popup:SetFrameStrata('DIALOG');popup:EnableMouse(true);popup:SetClampedToScreen(true)
            V.Button(popup,'Close',520,-12,104,28,function() popup:Hide() end,'neutral')
            popup.title=V.Text(popup,'Historical talents',20,-18,490,18,V.gold)
            popup.doc,popup.scroll=V.Document(popup,20,-66,580,236)
            popup.export=V.Edit(popup,20,-366,600,86,'Native export',nil,true)
            popup.exportButton=V.Button(popup,'Show native export',20,-326,232,28,function()
                popup.showExport=not popup.showExport;popup.export:GetParent():SetShown(popup.showExport)
                popup.exportButton:SetText(popup.showExport and 'Hide native export' or 'Show native export')
            end,'neutral');popup.export:GetParent():Hide()
            self.talentPopup=popup
        end
        local v=object.capture.values;local blocks={{kind='heading',text=G.Specialization(v.specializationID) or 'Specialization name unavailable'},
            {kind='meta',text='Observed '..Stamp(side.event.at)..' • '..(v.choicesComplete and 'All selected nodes read' or 'Partial or export-only evidence')}}
        for _,choice in ipairs(v.choices or {}) do blocks[#blocks+1]={kind='body',text=G.TalentLabel(choice)..' • rank '..choice[4]} end
        if #(v.choices or {})==0 then blocks[#blocks+1]={kind='body',text='Readable talent choices are unavailable. The original native export remains available below; no talent tree was inferred.'} end
        popup.doc:SetBlocks(blocks);popup.export:SetText(v.exportString or 'Native export unavailable');popup.export:ClearFocus();popup:Show();T.FocusWindow(popup)
        T.FitWindow(popup,640,480)
    end
    function p:Render()
        local a=self.activity;if not a then return end
        self.title:SetText(ns.ChronicleActivitiesUI.DuelLabel(a)..' • '..(a.context.zone or 'Zone unavailable'))
        self.before:SetText(self.phase=='before' and 'Before •' or 'Before');self.after:SetText(self.phase=='after' and 'After •' or 'After')
        self.allSlots:SetText(self.showUnknown and 'Hide unknown slots' or 'Show all slots')
        local own=Own(a.owner)
        for n,side in ipairs(self.sides) do
            local guid=n==1 and own or a.opponentGUID
            local e=guid and D.Observation(a,guid,self.phase);side.event=e
            local objects=self.job and self.job.objects or {}
            local gear=Object(objects,e,'gearRef',guid);side.trait=Object(objects,e,'traitRef',guid)
            local identity=e and e.details or {}
            side.identity:SetText((n==1 and 'You' or guid and A.Name(self.state,guid,a.lastAt) or 'Opponent unknown')..'\n'..(identity.class or 'Class unknown')..' • '..(identity.level and 'Level '..identity.level or 'Level unknown'))
            side.date:SetText(e and (self.phase..' • '..Stamp(e.details.observedAt)..'\nPartial fields remain unknown') or (self.phase..' capture unavailable'))
            local rows={};local unknown=0
            for _,slot in ipairs(G.slots) do
                local value=gear and gear.capture.values.slots[slot[1]];local link=value and value[4]~=false and value[4] or nil
                local id=value and value[3]~=false and value[3] or nil
                local name,_,_,_,_,_,_,_,_,icon=ns.WardenBrand.Values(GetItemInfo or C_Item and C_Item.GetItemInfo,link or id)
                name=ns.SafeString(name,144)
                local item={link=link,icon=ns.Readable(icon) and icon or nil,evidence=e,observed=e and Stamp(e.at),label=slot[2]..': '..(name or id and 'Item #'..id or value and value[2]=='empty' and 'Confirmed empty' or 'Unknown')}
                if link and name then item.clickLink='|H'..link..'|h['..name:gsub('[|%[%]]','')..']|h' end
                local unavailable=not value or value[2]=='unavailable'
                if unavailable and not self.showUnknown then unknown=unknown+1 else rows[#rows+1]=item end
            end
            if unknown>0 then rows[#rows+1]={label=unknown..' slots not observed',observed='Choose Show all slots for individual details. Unavailable is not confirmed empty; original evidence is unchanged.'} end
            side.list:SetItems(rows,true);side.traits:SetEnabled(side.trait~=nil)
            local received,healed,casts=0,0,0;local knownReceived,knownHealed=false,false
            for _,event in ipairs(a.duel.combat[guid] or {}) do
                local d=event.details
                if d.scope=='damage received; attacker unknown' then received=received+d.amount;knownReceived=true
                elseif d.scope=='healing received; caster unknown' then healed=healed+d.amount;knownHealed=true
                elseif d.scope=='observed successful casts' then casts=casts+d.count end
            end
            local b=guid and D.Observation(a,guid,'before');local post=guid and D.Observation(a,guid,'after')
            local comparison=self.job and not self.job.done and 'Reading historical snapshot index…' or D.Compare(b,post,'gear',a.owner,objects)
            local talentComparison=D.Compare(b,post,'traits',a.owner,objects)
            T.Tooltip(side.traits,'Historical talent comparison',talentComparison..'. Click to see the selected observation and original export. Matching endpoints do not prove no change during combat.')
            side.summary:SetText('Received: '..(knownReceived and received or 'unknown')..' damage • '..(knownHealed and healed or 'unknown')..' healing\n'..casts..' observed casts\n'..comparison)
        end
    end
    function p:SetActivity(st,a)
        if a~=self.activity then self.selectedEvidence=nil;self.phase='before' end
        self.state=st;self.activity=a;self.job=a and G.Request(a.owner) or nil;self:SetShown(a~=nil);if a then self:Render() end
    end
    p:SetScript('OnUpdate',function(self)
        if self.job and not self.job.done then G.Pump(self.job);if self.job.done then self:Render() end end
    end)
    p:SetScript('OnHide',function(self)
        if self.talentPopup then self.talentPopup:Hide() end
        self.state=nil;self.activity=nil;self.job=nil;self.selectedEvidence=nil
        for _,side in ipairs(self.sides) do side.list:SetItems({});side.event=nil;side.trait=nil end
    end)
    return p
end
