-- Shared read-only combat composition for existing Chronicle/person/activity
-- pages. Evidence inspection remains a separate optional detail on that page.
local _,ns=...
local Q,C,F=ns.AthenaCombatQueries,ns.UI2Components,ns.UI2Forms
local V={};ns.UI2Combat=V
local function row(title,detail,more) local r=more or {};r.title=title;r.detail=detail;r.height=r.height or 40;return r end
local function cap(s) return {title=s,kind='caption',wrap=true,height=54} end
function V.Rows(consumer,owner,guid,scope,sort,page)
    local out,state=Q.GetSummary(consumer,owner,guid,scope)
    if not out or state~='READY' then return {cap(state=='DENIED' and 'Combat history unavailable for this scope.' or 'Preparing recorded combat statistics…')},state=='INDEXING' end
    local rows={cap((out.scope or 'Recorded combat')..' · '..out.coverage)}
    rows[#rows+1]=row('Confirmed successful casts',out.castCount>0 and C.Number(out.castCount) or 'Not recorded')
    rows[#rows+1]=row('Different spells',out.distinctSpells>0 and C.Number(out.distinctSpells) or 'Not recorded')
    rows[#rows+1]=row('Measured combat',out.pairedWindows>0 and string.format('%.1f seconds · %d paired fights',out.measuredSeconds,out.pairedWindows) or 'Not recorded · unmatched boundaries excluded')
    rows[#rows+1]=row('Deaths observed',out.deaths>0 and tostring(out.deaths) or 'Not recorded')
    for _,pair in ipairs({{'duelDamageReceived','Damage received · captured duel windows'},{'duelHealingReceived','Healing received · captured duel windows'}})do
        local key,title=pair[1],pair[2]
        if out[key]~=nil then rows[#rows+1]=row(title,C.Number(out[key])..' · actor unknown',{activate=function()F.Copy(title,table.concat(out[key..'Refs'],'\n'),'Details recorded from the encounter. These partial observations are kept separate from WoW’s combat totals.')end,height=48,wrap=true}) end
    end
    local meters=Q.Meters(out);local names={};for name in pairs(meters) do names[#names+1]=name end;table.sort(names)
    if #names==0 then rows[#rows+1]=row('Damage / healing meter','Not recorded for this scope') end
    for _,name in ipairs(names) do local meter=meters[name]
        rows[#rows+1]=row(name:gsub('(%l)(%u)','%1 %2'),C.Number(meter.amount)..(meter.measured and ' · '..C.Number(meter.amount/meter.seconds)..' per second' or ' · rate unavailable'))
    end
    if #names>0 then rows[#rows+1]=cap('The latest combat totals for each session. Refreshes and overlapping sessions are not added together. A session may include more than this activity.') end
    local spells=Q.Spells(out,sort);local start=(page or 0)*30+1
    rows[#rows+1]={kind='columns',cells={'Successful spell','Casts','Share','Latest'},widths={.48,.13,.14,.25},height=34}
    for i=start,math.min(#spells,start+29) do local r=spells[i];local spell=r.spellID
        local icon=ns.ChronicleCapture.Call('C_Spell.GetSpellTexture',spell) or ns.ChronicleCapture.Call('GetSpellTexture',spell)
        rows[#rows+1]={title=Q.SpellName(spell),icon=icon,cells={Q.SpellName(spell),tostring(r.count),string.format('%.1f%%',r.count*100/out.castCount),C.Stamp(r.lastAt)},widths={.48,.13,.14,.25},height=38,
            activate=function() F.Copy(Q.SpellName(spell)..' · recorded sources','First observed: '..C.Stamp(r.firstAt)..'\nLast observed: '..C.Stamp(r.lastAt)..'\n'..table.concat(r.sourceIDs,'\n')..(r.moreSources and '\nMore sources available in Evidence Details.' or ''),'Source references for this selected scope. Observations do not establish a complete cast log.') end}
    end
    if #spells==0 then rows[#rows+1]=cap('No confirmed successful spells retained. Cast starts, stops and effects on a recipient are not counted as successful casts.') end
    rows[#rows+1]=row('Effect applications observed',Q.Top(out.effects,5))
    if out.baselineEffects then rows[#rows+1]=row('Effects present at first observation',tostring(out.baselineEffects)..' · not applications or casts') end
    if out.firstAt then rows[#rows+1]=cap('Observed '..C.Stamp(out.firstAt)..' through '..C.Stamp(out.lastAt)..'. Missing time, opponent attribution, interrupts and defensive use remain unknown unless explicitly recorded.') end
    return rows,false,#spells
end
function V.History(route)
    local U=ns.UI2;local owner=route.owner or ns.Chronicle.Owner()
    local function change(key,value) local r={};for k,v in pairs(route) do r[k]=v end;r[key]=value;r.combatSpellPage=0;U.Open(r,true);return true end
    local scope={label='All recorded history'};local selected=route.combatScope or 'all';local choices={{'all','All recorded history'},{'session','Latest recording session'},{'day','Past 24 hours'},{'week','Past seven days'}}
    local c=ns.ChronicleStore.Character(owner,false)
    if selected=='session' and c and #c.events>0 then scope.session=c.events[#c.events].session;scope.label='Latest recording session'
    elseif selected=='day' or selected=='week' then
        -- Pin the chosen window for this route. A moving per-frame cutoff
        -- would invalidate the archive query cache every server second.
        route.combatAsOf=route.combatAsOf or ns.Chronicle.Stamp()
        scope.to=route.combatAsOf;scope.from=(scope.to or 0)-(selected=='day' and 86400 or 604800);scope.label=selected=='day' and 'Past 24 hours at selection' or 'Past seven days at selection'
    elseif selected:sub(1,9)=='activity:' then scope.activity=selected:sub(10);scope.label='Selected adventure' end
    local st=ns.ChronicleActivities.Peek(owner)
    if st then local adventures=ns.ChronicleActivities.Query(st,{groupReloads=true});for i=1,math.min(20,#adventures)do local a=adventures[i];choices[#choices+1]={'activity:'..a.id,ns.UI2Models.Title(a)}end end
    local rows={F.Row('CHR.COMBAT.SCOPE','Combat scope',function() return selected end,function(v) return change('combatScope',v) end,{choices=choices}),
        F.Row('CHR.COMBAT.SORT','Spell order',function() return route.combatSort or 'count' end,function(v) return change('combatSort',v) end,{choices={{'count','Most casts'},{'name','Spell name'},{'latest','Most recent'}}})}
    local detail,pending,count=V.Rows('chronicle',owner,nil,scope,route.combatSort,route.combatSpellPage or 0)
    for _,d in ipairs(detail) do rows[#rows+1]=d end
    local page=route.combatSpellPage or 0
    for _,delta in ipairs({-1,1}) do if page+delta>=0 and (page+delta)*30<(count or 0) then local n=page+delta
        rows[#rows+1]=row(delta<0 and 'Previous spells' or 'More spells','Same combat scope',{activate=function() local r={};for k,v in pairs(route) do r[k]=v end;r.combatSpellPage=n;U.Open(r,true) end}) end end
    rows[#rows+1]=row('Evidence Details','Inspect original source records · same combat scope',{activate=function()
        local r={};for k,v in pairs(route)do r[k]=v end;r.combatEvidence=true;r.combatEvidenceScope=scope;r.historyCursor=nil;r.historyCursors={};U.Open(r,true)
    end})
    return rows,{},pending
end
