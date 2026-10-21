-- Local-only command tester. No chat delivery, history, captures, alerts or
-- contact detector calls. Production analysis and saved settings are reused.
local _,ns=...
local T={};ns.PhraseTester=T
local function Safe(text) return tostring(text or ''):gsub('|','||') end
function T.Analyze(text)
    if not ns.DB or not ns.CanRead(text) or text:match('^%s*$') then return nil,'Use /ocw test <phrase>' end
    if #text>2048 then return nil,'Use a phrase of at most 2,048 bytes.' end
    if ns.RulePacks.Restoring or ns.RulePacks.Busy then return nil,'Wait for pack verification to finish, then test again.' end
    local source={kind='player',sender='Phrase Tester',event='CHAT_MSG_SAY'}
    local hits,report,err=ns.Confidence.Analyze(ns.Matcher,text,ns.DB,ns.ExceptionMatcher,ns.DB.typoFiltering,source)
    if err then return nil,'Analysis left the phrase unchanged: '..err end
    local action=ns.MatchAction(hits)
    return {action=action,hits=hits,candidates=report,text=text,
        preset=({strict='Mild',balanced='Balanced',aggressive='Strict'})[ns.DB.preset] or 'Balanced',
        active=ns.Active('chat'),preview=action=='Hidden' and '[Whole message would be hidden]'
            or action=='Warning' and ns.RenderWarning(text) or ns.RenderRedacted(text,hits,nil,false)}
end
function T.Open()
    if InCombatLockdown and InCombatLockdown() then ns.Print('Open Test Filter after combat.');return end
    if not T.window then
        local V=ns.Art;local p=ns.Theme.Window('OlympusWardenFilterTester',UIParent,860,610);T.window=p
        V.Text(p,'ChatWarden • Test Filter',24,-24,760,25,V.gold)
        V.Text(p,'Local prediction with your current signed packs and preset. Nothing is sent or captured.',24,-66,800,14,V.muted)
        local channel='CHAT_MSG_SAY'
        V.Dropdown(p,24,-106,260,{{'CHAT_MSG_SAY','Say'},{'CHAT_MSG_GUILD','Guild'},{'CHAT_MSG_PARTY','Party'},{'CHAT_MSG_WHISPER','Whisper (synthetic)'}},function() return channel end,function(v) channel=v end)
        local input=V.Edit(p,24,-154,808,38,'Type a phrase to test…');input:SetMaxLetters(2048)
        local document=V.Document(p,24,-258,788,294)
        V.Button(p,'Test Filter',24,-208,244,34,function()
            local r,why=T.Analyze(input:GetText());local blocks={{kind='heading',text=r and r.action..' • '..r.preset or 'Unable to analyze'}}
            if r then
                blocks[#blocks+1]={text=r.preview,literal=true};blocks[#blocks+1]={kind='meta',text='Synthetic channel: '..channel..'. Wording analysis is channel independent.'}
                for i=1,math.min(8,#r.candidates) do local m=r.candidates[i];blocks[#blocks+1]={text=(ns.RulePacks.Title(m.pack) or m.pack)..' • '..m.reason,literal=true} end
            else blocks[#blocks+1]={text=why} end
            document:SetBlocks(blocks)
        end)
        V.Button(p,'Review decisions',286,-208,244,34,ns.OpenReview,'neutral')
        V.Button(p,'Close',550,-208,282,34,function() p:Hide() end,'neutral')
    end
    ns.Theme.ShowWindow(T.window);return T.window
end
function T.Run(text)
    local result,err=T.Analyze(text);if not result then ns.Print(err);return end
    ns.Print('Phrase test | Wording | '..result.preset..' | '..result.action..(result.active and '' or ' (predicted; live chat filtering is paused)'))
    ns.Print('Preview: '..result.preview)
    local count=0
    for _,match in ipairs(result.candidates) do
        if count>=5 then break end;count=count+1
        ns.Print(Safe((ns.RulePacks.Title(match.pack) or match.pack)..' | '..(match.accepted and (match.action or result.action) or 'No action')..' | '..match.reason))
    end
    if count==0 then ns.Print('No enabled rule matched. Uncertain or uncovered wording stays visible.') end
    if #result.candidates>5 then ns.Print('Showing 5 of '..#result.candidates..' candidate explanations.') end
    return result
end
