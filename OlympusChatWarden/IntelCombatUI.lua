-- Bounded visible pages over existing source references, not a saved incident DB.
local _,ns=...
local V,I,A=ns.Art,ns.ChronicleIntelligence,ns.ChronicleActivities
local U={};ns.IntelCombatUI=U
local function Time(at)
    local ok,value=pcall(date or os.date,'%Y-%m-%d %H:%M:%S',at);return ok and value or tostring(at)
end
function U.Category(e)
    local d=e.details;local r=d.recordType
    local observed=ns.AthenaObservedHistory and ns.AthenaObservedHistory.Category(e)
    if observed then return observed=='effects' and 'effects' or observed end
    if r=='native_kill_credit' then
        if d.entityKind=='Player' then return ns.ChronicleStore.GUID(d.attackerGUID) and 'pvp' or 'states' end
        return (d.entityKind=='Creature' or d.entityKind=='Vehicle') and 'pve' or 'states'
    end
    if r and r:find('duel_',1,true)==1 then return 'pvp' end
    if r=='witness_ability' then return 'abilities' end
    if r=='aura_effect' then return 'effects' end
    if r=='witness_death' or r=='witness_recovery' or r=='witness_state' then return 'states' end
end
function U.Title(e,guid)
    local d=e.details
    local title=ns.AthenaHistorySchema.Title(e) or ns.AthenaObservationSchema.Title(e);if title then return title end
    if d.recordType=='aura_effect' then return ns.AthenaCombatQueries.Title(e) end
    if d.recordType=='native_kill_credit' then
        local kind=d.entityKind=='Player' and (ns.ChronicleStore.GUID(d.attackerGUID) and 'Player' or 'Non-player actor')
            or (d.entityKind=='Creature' or d.entityKind=='Vehicle') and 'Creature' or 'Other'
        return kind..' native credit • '..(d.attackerGUID==guid and 'actor' or 'victim')
    end
    if d.recordType=='witness_death' then return d.method=='native death' and 'Native death notice • cause unknown' or 'Observed alive → dead/ghost • cause unknown' end
    if d.recordType=='witness_recovery' then return 'Observed dead/ghost → alive' end
    if d.recordType=='duel_session_result' then return 'Duel result • '..(d.result=='win' and 'your victory' or d.result=='loss' and 'your defeat' or 'unknown') end
    if d.recordType=='witness_state' then return d.baseline and (d.dead and 'First observed dead/ghost • state only' or 'Player state observed') or 'Player state changed' end
    if d.recordType=='witness_ability' then
        local name=ns.ChronicleStore.Text(ns.ChronicleCapture.Call('GetSpellInfo',d.spellID),144)
        if not name then local info=ns.ChronicleCapture.Table(ns.ChronicleCapture.Call('C_Spell.GetSpellInfo',d.spellID));name=info and ns.ChronicleStore.Text(info.name,144) end
        return (d.classification=='resurrection' and 'Resurrection cast' or 'Notable cast')..' • '..(name or 'Spell '..d.spellID)
    end
    return ns.RecordingUI.Title(e)
end
function U.Build(parent,host)
    local p=V.Panel(parent,0,-96,1136,550,'dark');p:Hide();p.page=0;p.filter='all'
    V.Text(p,'Observed Combat',18,-15,1080,22,V.gold)
    local note=V.Text(p,'Effects observed on this player do not prove they cast them. Coverage is intermittent; gaps and uptime are unknown.',18,-48,1080,13,V.muted);note:SetHeight(24)
    local pvp=V.Panel(p,18,-80,542,110,'minimal');V.Text(pvp,'PvP',12,-8,510,17,V.blue)
    p.pvp=V.Text(pvp,'',12,-34,510,13,V.muted);p.pvp:SetHeight(68)
    local pve=V.Panel(p,574,-80,542,110,'minimal');V.Text(pve,'PvE & other observations',12,-8,510,17,V.blue)
    p.pve=V.Text(pve,'',12,-34,510,13,V.muted);p.pve:SetHeight(68)
    p.menu=V.Dropdown(p,18,-204,266,{{'all','All combat evidence'},{'pvp','PvP credits & duels'},{'pve','Creature credits'},
        {'abilities','Verified selected casts'},{'casts','Cast notifications'},{'effects','Effects on this player'},{'pets','Pets & companions'},
        {'groups','Roster roles & leadership'},{'targeting','Contextual targeting'},{'identity','Visible identity & use'},{'gear','Gear & talent evidence'},
        {'public','Public milestones'},{'guild','Guild associations'},{'states','States & other evidence'}},function() return p.filter end,function(value) p.filter=value;p.page=0;p:StartPage() end)
    p.newer=V.Button(p,'Newer',296,-204,118,30,function() p.page=math.max(0,p.page-1);p:StartPage() end,'neutral')
    p.older=V.Button(p,'Older',426,-204,118,30,function() p.page=p.page+1;p:StartPage() end,'neutral')
    p.group=V.Button(p,'Shared activities & boss evidence',574,-204,346,30,function()
        if p.guid then ns.WardenUI.Navigate('history',p.owner,p.guid,nil,{kind='player',owner=p.owner,id=p.guid}) end
    end,'neutral')
    p.source=V.Button(p,'Original evidence',934,-204,182,30,function() if p.selected then ns.RecordingUI.OpenSource(nil,p.selected) end end,'neutral')
    p.list=V.ScrollingList(p,18,-250,1072,246,56,function(list)
        local row=V.Button(list,'',0,0,1068,52,function(self) p.selected=self.item;p.source:SetEnabled(true);p.list:Render() end,'row')
        row.icon=V.Icon(row,'event:shield',30,10,-10)
        row.title=V.Text(row,'',52,-6,990,14,V.gold);row.title:SetHeight(20);row.title:SetWordWrap(false)
        row.sub=V.Text(row,'',52,-29,990,12,V.muted);row.sub:SetHeight(18);row.sub:SetWordWrap(false)
        row.active=V.Nine(row,'selected');return row
    end,function(row,e)
        row.item=e;row.title:SetText(U.Title(e,p.guid));row.sub:SetText(Time(e.at)..' • '..(e.details.evidenceState=='PROVISIONAL_OBSERVATION' and 'PROVISIONAL • ' or '')..e.source)
        V.SetIcon(row.icon,ns.EventIcons.Record(e));row.active:SetShown(p.selected==e)
    end)
    p.status=V.Text(p,'Choose a recorded player.',18,-512,1098,13,V.muted);p.status:SetHeight(28)
    p.status:SetWidth(896);V.HistoryUpdateButton(p,934,-512,182)
    function p:Layout(detailed)
        pvp:SetShown(detailed);pve:SetShown(detailed)
        local y=detailed and -204 or -90
        for _,v in ipairs({{self.menu,18,266},{self.newer,296,118},{self.older,426,118},{self.group,574,346},{self.source,934,182}}) do
            ns.Workspace.Place(v[1],v[2],y,v[3],30)
        end
        self.list.scroll:ClearAllPoints();self.list.scroll:SetPoint('TOPLEFT',18,y-46);self.list:Resize(1072,detailed and 246 or 360)
    end
    function p:Clear()
        self.historyView=nil;self.job=nil;self.state=nil;self.guid=nil;self.selected=nil;self.list:SetItems({});self.source:SetEnabled(false)
    end
    function p:StartPage()
        local c=ns.ChronicleStore.Character(self.owner,false);self.readRevision=c and c.revision
        self.job=nil;self.selected=nil;self.source:SetEnabled(false);self.list:SetItems({});self.newer:SetEnabled(self.page>0);self.older:SetEnabled(false)
        self:Layout(false)
        if not self.state or not self.guid then self.pvp:SetText('No selected player.');self.pve:SetText('');self.status:SetText('Choose a recorded player.');return end
        local st,guid=self.state,self.guid;local intel=I.Player(st,guid);local combat=intel.combat or {}
        local counts=st.intelligence.players[guid];local refs=counts and counts.evidence or {}
        self.pvp:SetText('Native player credit: '..(combat.playerCredits or 0)..' actor; '..(combat.victimCredits or 0)..' victim.\nConfirmed PvP kills/deaths: unknown.\nObserved K/D: not enough confirmed data.')
        self.pve:SetText('Creature native credits: '..(combat.creatureCredits or 0)..'. Counting roster associations…')
        self.status:SetText('Reading this player’s original evidence…')
        self.job=coroutine.create(function()
            local group=st.players[guid];local attempts,successes,duels,wins,losses=0,0,0,0,0;local work=0
            for _,id in ipairs(group and group.activities or {}) do
                local a=st.byID[id]
                if a then
                    if a.kind=='duel' and a.duel and a.duel.accepted then
                        duels=duels+1
                        if a.duel.resultEvidence then if a.duel.result=='loss' then wins=wins+1 elseif a.duel.result=='win' then losses=losses+1 end end
                    end
                    for _,t in ipairs(a.attempts) do
                        if t.members[guid] then attempts=attempts+1;if t.status=='ended' and (t.outcome=='success' or t.outcome=='native boss kill') then successes=successes+1 end end
                        work=work+1;if work%128==0 then coroutine.yield() end
                    end
                end
                work=work+1;if work%128==0 then coroutine.yield() end
            end
            self.pvp:SetText('Native player credit: '..(combat.playerCredits or 0)..' actor; '..(combat.victimCredits or 0)..' victim.\nAgainst you: '..wins..' duel wins; '..losses..' losses; '..(duels-wins-losses)..' unknown.\nConfirmed PvP kills/deaths: unknown.\nObserved K/D: not enough confirmed data.')
            self.pve:SetText('Creature native credits: '..(combat.creatureCredits or 0)..'. Roster-listed boss attempts: '..attempts..'; successful results: '..successes..'.\nUnknown-cause death notices: '..(combat.nativeDeaths or 0)..'; dead-state transitions: '..(combat.deadTransitions or 0)..'. Separate evidence, not added together.')
            self:Layout(attempts>0 or duels>0 or combat.playerCredits~=nil or combat.victimCredits~=nil or combat.otherVictimCredits~=nil or combat.creatureCredits~=nil or combat.nativeDeaths~=nil or combat.deadTransitions~=nil or combat.abilities~=nil)
            local rows={};local matched=0;local skip=self.page*50
            for n=#refs,1,-1 do
                local e=st.intelligence.events[refs[n]] or st.events[refs[n]];local category=e and U.Category(e)
                if category and (self.filter=='all' or self.filter==category) then
                    matched=matched+1
                    if matched>skip then rows[#rows+1]=e;if #rows==51 then break end end
                end
                if n%128==0 then coroutine.yield() end
            end
            local more=#rows>50;if more then rows[51]=nil end
            self.list:SetItems(rows);self.older:SetEnabled(more)
            self.status:SetText(#rows==0 and 'No matching combat evidence recorded. Missing observations do not establish zero activity.' or 'Page '..(self.page+1)..' • '..#rows..' source records. Select one to open its original evidence.')
            V.CommitHistoryView(self,self.owner,self.guid..'/'..self.filter..'/'..self.page)
            if self.historyView then self.historyView.revision=self.readRevision end
            self.dirty=nil
        end)
    end
    function p:SetProfile(owner,row,st,force)
        local guid=row and row.id
        if self.owner==owner and self.guid==guid and not force and not self.dirty then
            if self.job or V.HoldHistoryView(self,owner,(guid or '')..'/'..self.filter..'/'..self.page,false) then return end
            if self.state==st and self.revision==(st and st.revision) then return end
        end
        if self.owner~=owner or self.guid~=guid then self.page=0 end
        self.owner=owner;self.guid=guid;self.profileRow=row;self.state=st;self.revision=st and st.revision;self:StartPage()
    end
    function p:Refresh(force)
        local st=A.Request(self.owner);if st then self:SetProfile(self.owner,self.profileRow,st,force) end
    end
    p:SetScript('OnUpdate',function(self) if self.job then
        local ok=coroutine.resume(self.job)
        if not ok then self.job=nil;self.status:SetText('Evidence view could not finish. Reopen the dossier to retry.')
        elseif coroutine.status(self.job)=='dead' then self.job=nil end
    end end)
    p:HookScript('OnHide',function(self) self:Clear() end)
    return p
end
