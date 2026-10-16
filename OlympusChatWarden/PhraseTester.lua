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
