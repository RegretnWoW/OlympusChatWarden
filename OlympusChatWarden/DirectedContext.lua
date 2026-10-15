-- Bounded context for the two stock subject preferences. No intent classifier.
-- This module changes eligibility, never the vocabulary of a signed import.
local _,ns=...
local D={};ns.DirectedContext=D
local function Has(text,phrase)
    local at=1
    while true do
        local a,b=text:find(phrase,at,true);if not a then return false end
        if not text:sub(a-1,a-1):match('[%w_]') and not text:sub(b+1,b+1):match('[%w_]') then return true end
        at=a+1
    end
end
local function Any(text,phrases)
    for _,phrase in ipairs(phrases) do if Has(text,phrase) then return phrase end end
end
function D.Apply(before,after,score,quoted)
    local lead=before:sub(-80):gsub('’',"'")
    local tail=after:sub(1,100):gsub('’',"'")
    -- Negation belongs to the statement, rather than a fixed score deduction.
    -- "not only trash" is an assertion; "not trash" is its opposite.
    local assertion=tail:gsub('^%s*','')
    local negated=assertion:match('^is%s+not%s+') or assertion:match('^are%s+not%s+')
        or assertion:match("^isn't%s+") or assertion:match("^aren't%s+")
    if negated and not assertion:match('^%a+%s+not%s+only%s+') then
        return 0,'negated statement; stock subject rule excluded'
    end
    for _,phrase in ipairs({"don't hate","do not hate","doesn't hate","does not hate","never hated","not hating"}) do
        if lead:match(phrase:gsub('([%%%-%^%$%(%)%.%[%]%*%+%?])','%%%1')..'%s*$') then
            return 0,'negated hostility; stock subject rule excluded'
        end
    end
    local defending=Any(lead,{"don't say","do not say","stop saying","don't call","do not call","stop calling",
        'no one should say','nobody should say','no one should call','nobody should call','not saying',
        'wrong to say','wrong to call','avoid saying','never said','never called'})
    if defending then return 0,'discouraging or denying the wording: '..defending end
    -- Reported speech is uncertain even without literal quotation marks.
    -- Broad may show a warning; Balanced/Selective leave it untouched.
    local reported=Any(lead,{'say','said','says','saying','write','wrote','writes','claim','claimed','claims','claiming','quoted','quoting',
        'someone called','people call','people called','heard that','hear that'})
    if quoted or reported then return math.min(score,55),quoted and 'quoted statement; stock score capped at 55'
        or 'reported statement; stock score capped at 55: '..reported end
    if lead:match('^%s*is%s*$') or lead:match('^%s*are%s*$') then
        return math.min(score,55),'question about the subject; stock score capped at 55'
    end
    return score
end
