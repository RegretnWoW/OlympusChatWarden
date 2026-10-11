-- Pure Lua 5.1-compatible Aho-Corasick phrase matcher. No WoW API dependencies.
local _, ns = ...
local Engine = {}
ns.Engine = Engine
Engine.MAX_RULES = 20000
Engine.MAX_PHRASE = 120
Engine.MAX_TEXT = 32768
Engine.MAX_RULE_BYTES = 300000
Engine.MAX_CANDIDATES = 1024

-- string.lower can case-map UTF-8 bytes under a non-C host locale. Only
-- ASCII letters are folded; lookalike glyphs retain their original bytes.
function Engine.Lower(text)
    return (text:gsub("[A-Z]", function(c) return string.char(c:byte()+32) end))
end

local function Word(byte)
    return byte and ((byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90)
        or (byte >= 97 and byte <= 122) or byte == 95 or byte >= 128)
end
local function Boundary(text, position, before)
    -- An apostrophe within a word is not the start of another whole word.
    -- Keep trailing possessive boundaries (Olympus's) and quoted 'LGBT' usable.
    if before then
        if text:sub(position, position) == "'" and Word(text:byte(position - 1)) then return false end
        if text:sub(position - 2, position) == "’" and Word(text:byte(position - 3)) then return false end
    end
    if not Word(text:byte(position)) then return true end
    -- Common UTF-8 punctuation is not a word letter. Keep all other non-ASCII
    -- bytes conservative so phrases cannot match inside accented words.
    for _, punctuation in ipairs({"“", "”", "‘", "’", "—", "–", "…"}) do
        local part = before and text:sub(position - #punctuation + 1, position)
            or text:sub(position, position + #punctuation - 1)
        if part == punctuation then return true end
    end
    return false
end

local function Validate(rules, minimum)
    if type(rules) ~= "table" then return nil, "Rules must be a list." end
    local result, seen, totalBytes = {}, {}, 0
    for _, phrase in ipairs(rules) do
        if type(phrase) ~= "string" then return nil, "Every rule must be text." end
        phrase = phrase:match("^%s*(.-)%s*$"):lower()
        if #phrase > 0 then
            if #phrase < minimum or #phrase > Engine.MAX_PHRASE then
                return nil, "Each phrase must contain " .. minimum .. "-120 ASCII characters."
            end
            if phrase:find("[^ -~]") or phrase:find("|", 1, true) then
                return nil, "Use printable English/ASCII phrases without WoW markup (|)."
            end
            if not seen[phrase] then
                seen[phrase] = true
                result[#result + 1] = phrase
                totalBytes = totalBytes + #phrase
                if #result > Engine.MAX_RULES then return nil, "Maximum 20,000 unique phrases." end
                if totalBytes > Engine.MAX_RULE_BYTES then return nil, "Rule text budget exceeded (300,000 bytes)." end
            end
        end
    end
    return result
end
function Engine.Validate(rules) return Validate(rules, 3) end

local function Compile(rules, minimum)
    local clean, err = Validate(rules, minimum)
    if not clean then return nil, err end
    local nodes = {{next = {}, fail = 1}}
    for id, phrase in ipairs(clean) do
        local state = 1
        for i = 1, #phrase do
            local byte = phrase:byte(i)
            local nextState = nodes[state].next[byte]
            if not nextState then
                nextState = #nodes + 1
                nodes[nextState] = {next = {}, fail = 1}
                nodes[state].next[byte] = nextState
            end
            state = nextState
        end
        nodes[state].output = id
    end
    local queue, first = {}, 1
    for _, state in pairs(nodes[1].next) do queue[#queue + 1] = state end
    while first <= #queue do
        local state = queue[first]
        first = first + 1
        for byte, child in pairs(nodes[state].next) do
            local failure = nodes[state].fail
            while failure ~= 1 and not nodes[failure].next[byte] do failure = nodes[failure].fail end
            nodes[child].fail = nodes[failure].next[byte] or 1
            local f = nodes[child].fail
            nodes[child].outputLink = nodes[f].output and f or nodes[f].outputLink
            queue[#queue + 1] = child
        end
    end
    return setmetatable({nodes = nodes, rules = clean}, {__index = Engine})
end
function Engine.Compile(rules) return Compile(rules, 3) end
-- Author-signed display lists may include short whole-word tokens.
-- Personal phrases and exceptions continue to use the original 3-character API.
function Engine.CompileLiteral(rules) return Compile(rules, 1) end

function Engine:FindPlain(text, allCandidates)
    local normalized, state, best, candidates = Engine.Lower(text), 1, {}, {}
    for i = 1, #normalized do
        local byte = normalized:byte(i)
        while state ~= 1 and not self.nodes[state].next[byte] do state = self.nodes[state].fail end
        state = self.nodes[state].next[byte] or 1
        local outputState = state
        while outputState do
            local id = self.nodes[outputState].output
            if id then
                local start = i - #self.rules[id] + 1
                if Boundary(normalized, start - 1, true) and Boundary(normalized, i + 1, false) then
                    if allCandidates then
                        if #candidates >= Engine.MAX_CANDIDATES then return {}, "candidate budget exceeded" end
                        candidates[#candidates + 1] = {first = start, last = i, rule = id}
                    end
                    if not best[start] or best[start].last < i then
                        best[start] = {first = start, last = i, rule = id}
                    end
                end
            end
            outputState = self.nodes[outputState].outputLink
        end
    end
    if allCandidates then return candidates end
    local matches, i = {}, 1
    while i <= #text do
        if best[i] then
            matches[#matches + 1] = best[i]
            i = best[i].last + 1
        else
            i = i + 1
        end
    end
    return matches
end

-- Preserve existing hyperlinks, textures/atlases, colors, and escaped pipes.
-- Phrases split by markup do not match in this first version.
function Engine.Segments(text)
    local pieces, start, i = {}, 1, 1
    local function Emit(last, editable)
        if last >= start then pieces[#pieces + 1] = {text = text:sub(start, last), editable = editable} end
        start = last + 1
    end
    while i <= #text do
        if text:sub(i, i) == "|" then
            local code, last = text:sub(i + 1, i + 1)
            if code == "H" then
                local h1 = text:find("|h", i + 2, true)
                last = h1 and text:find("|h", h1 + 2, true)
                last = last and last + 1
            elseif code == "T" or code == "A" then
                last = text:find(code == "T" and "|t" or "|a", i + 2, true)
                last = last and last + 1
            elseif code == "c" and text:sub(i + 2, i + 9):match("^%x%x%x%x%x%x%x%x$") then
                last = i + 9
            elseif code == "r" or code == "|" then
                last = i + 1
            end
            -- Unknown/malformed escapes: leave the rest unchanged, fail open.
            if not last then last = #text end
            Emit(i - 1, true)
            Emit(last, false)
            i = last + 1
        else
            i = i + 1
        end
    end
    Emit(#text, true)
    return pieces
end

function Engine:Find(text, allCandidates)
    if type(text) ~= "string" or #text > Engine.MAX_TEXT then return {}, "unsupported" end
    local matches, offset = {}, 0
    for _, piece in ipairs(Engine.Segments(text)) do
        if piece.editable then
            local found, err = self:FindPlain(piece.text, allCandidates)
            if err then return {}, err end
            for _, match in ipairs(found) do
                if allCandidates and #matches >= Engine.MAX_CANDIDATES then return {}, "candidate budget exceeded" end
                matches[#matches + 1] = {first = offset + match.first, last = offset + match.last, rule = match.rule,
                    segmentFirst = offset + 1, segmentLast = offset + #piece.text}
            end
        end
        offset = offset + #piece.text
    end
    return matches
end

-- Two bounded Aho-Corasick passes for author rules. Keep original byte ranges;
-- do not rewrite chat, personal rules, exceptions, markup or replacement data.
local leet = {['0']='o', ['1']='i', ['3']='e', ['4']='a', ['5']='s', ['7']='t', ['8']='b', ['@']='a', ['$']='s', ['!']='i'}
local confusable = {["Ａ"]="a", ["Ｂ"]="b", ["Ｃ"]="c", ["Ｄ"]="d", ["Ｅ"]="e", ["Ｆ"]="f", ["Ｇ"]="g", ["Ｈ"]="h", ["Ｉ"]="i", ["Ｊ"]="j", ["Ｋ"]="k", ["Ｌ"]="l", ["Ｍ"]="m", ["Ｎ"]="n", ["Ｏ"]="o", ["Ｐ"]="p", ["Ｑ"]="q", ["Ｒ"]="r", ["Ｓ"]="s", ["Ｔ"]="t", ["Ｕ"]="u", ["Ｖ"]="v", ["Ｗ"]="w", ["Ｘ"]="x", ["Ｙ"]="y", ["Ｚ"]="z", ["ａ"]="a", ["ｂ"]="b", ["ｃ"]="c", ["ｄ"]="d", ["ｅ"]="e", ["ｆ"]="f", ["ｇ"]="g", ["ｈ"]="h", ["ｉ"]="i", ["ｊ"]="j", ["ｋ"]="k", ["ｌ"]="l", ["ｍ"]="m", ["ｎ"]="n", ["ｏ"]="o", ["ｐ"]="p", ["ｑ"]="q", ["ｒ"]="r", ["ｓ"]="s", ["ｔ"]="t", ["ｕ"]="u", ["ｖ"]="v", ["ｗ"]="w", ["ｘ"]="x", ["ｙ"]="y", ["ｚ"]="z", ["А"]="a", ["а"]="a", ["В"]="b", ["Е"]="e", ["е"]="e", ["К"]="k", ["М"]="m", ["Н"]="h", ["н"]="n", ["О"]="o", ["о"]="o", ["Р"]="p", ["р"]="p", ["С"]="c", ["с"]="c", ["Т"]="t", ["Х"]="x", ["х"]="x", ["У"]="y", ["у"]="y", ["І"]="i", ["і"]="i", ["Ј"]="j", ["ј"]="j", ["Ѕ"]="s", ["ѕ"]="s", ["Α"]="a", ["α"]="a", ["Β"]="b", ["Ε"]="e", ["ε"]="e", ["Ι"]="i", ["ι"]="i", ["Κ"]="k", ["κ"]="k", ["Μ"]="m", ["Ν"]="n", ["Ο"]="o", ["ο"]="o", ["Ρ"]="p", ["ρ"]="p", ["Τ"]="t", ["τ"]="t", ["Υ"]="y", ["Χ"]="x", ["χ"]="x"}
for glyph,letter in pairs({["ԁ"]="d", ["ԛ"]="q", ["ԝ"]="w", ["Ԍ"]="g", ["ɡ"]="g",
    ["ӏ"]="l", ["Ɩ"]="i", ["ℓ"]="l", ["ſ"]="s", ["ν"]="v", ["υ"]="u"}) do confusable[glyph]=letter end
local invisible = {['\226\128\139']=true, ['\226\128\140']=true, ['\226\128\141']=true, ['\239\187\191']=true}
local acronyms = {dei=true, dib=true, deb=true}
local semantic = {[':']=true, [',']=true, ['/']=true, ['&']=true, ['+']=true, ['#']=true, ["'"]=true}
local function Skeleton(phrase)
    local chars={}
    for c in phrase:gmatch('.') do
        if c:match('[a-z0-9]') or semantic[c] then chars[#chars+1]=leet[c] or c end
    end
    return table.concat(chars)
end
local function Flexible(self)
    if self.flexible then return self.flexible end
    local rules, ids, seen = {}, {}, {}
    for id, phrase in ipairs(self.rules) do
        local key = Skeleton(phrase)
        -- Declaration colons, apostrophes, slashes and plus signs are
        -- meaningful tokens, not removable separators.
        local valid=true
        for c in phrase:gmatch('.') do if not c:match('[a-z0-9 _%-%.]') and not semantic[c] then valid=false;break end end
        if valid and (#key >= 4 or acronyms[key]) then
            if not seen[key] then rules[#rules+1]=key; seen[key]=#rules; ids[#rules]={} end
            ids[seen[key]][#ids[seen[key]]+1]=id
        end
    end
    self.flexible = {matcher=assert(Compile(rules, 1)), ids=ids}
    return self.flexible
end
local function Stream(text, substitute)
    local chars, first, last, i = {}, {}, {}, 1
    while i <= #text do
        local c, length = text:sub(i,i):lower(), 1
        local triple = text:sub(i,i+2)
        local value
        if invisible[triple] then length=3
        elseif substitute and (confusable[triple] or confusable[text:sub(i,i+1)]) then
            length=confusable[triple] and 3 or 2; value=confusable[text:sub(i,i+length-1)]
        elseif c:match('[a-z0-9]') then value=substitute and leet[c] or c
        elseif substitute and leet[c] then value=leet[c]
        elseif semantic[c] then value=c
        elseif c:match('[ \t_.%-%*]') then -- allowed small internal separators
        else value='|' end -- hard boundary: quotes, newlines, other Unicode
        if value then chars[#chars+1]=value; first[#chars]=i; last[#chars]=i+length-1 end
        i=i+length
    end
    return table.concat(chars), first, last
end
local function ValidFlexible(text, phrase, first, last, streamFirst, a, b)
    if not Boundary(text, first-1, true) or not Boundary(text, last+1, false) then return false end
    -- Short terminal letter labels (A/B, I/II) must not reinterpret a numeric
    -- identifier as a letter. Explicit numeric rules still match themselves.
    if phrase:match("%s[a-z][a-z]?$") and text:sub(last,last):match("%d") then return false end
    local index, expectedGap, expectedDot = a, false, false
    for c in phrase:gmatch('.') do
        if c:match('[a-z0-9]') or semantic[c] then
            -- A number in an authored rule remains that exact number. Only
            -- letters accept leet substitutions; body type 1 cannot become 2.
            if c:match('%d') and text:sub(streamFirst[index],b[index])~=c then return false end
            if index > a then
                local gap = text:sub(b[index-1]+1, streamFirst[index]-1)
                for mark in pairs(invisible) do gap=gap:gsub(mark,'') end
                if #gap > (expectedGap and 4 or 2) then return false end
                -- A sentence boundary cannot stand in for a phrase's word gap.
                if expectedGap and gap:find('%.') and not expectedDot then return false end
                if expectedDot and not gap:find('%.') then return false end
                if not expectedDot and (gap:find('%.%s') or gap:find('%s%.')) then return false end
            end
            index=index+1; expectedGap=false;expectedDot=false
        else expectedGap=true;expectedDot=expectedDot or c=='.' end
    end
    return true
end
function Engine:FindFlexible(text, allCandidates)
    local exact, err = self:Find(text, true)
    if err then return {}, err end
    local flex, seen = Flexible(self), {}
    for _, hit in ipairs(exact) do seen[hit.first..':'..hit.last..':'..hit.rule]=true end
    local offset = 0
    for _, piece in ipairs(Engine.Segments(text)) do
        if piece.editable then
            for _, substitute in ipairs({false,true}) do
                local stream, first, last = Stream(piece.text, substitute)
                -- Skeleton streams deliberately have no word boundaries. Check
                -- each candidate against the original text and bounded gaps.
                local node = 1
                for i=1,#stream do
                    local byte=stream:byte(i); local nodes=flex.matcher.nodes
                    while node~=1 and not nodes[node].next[byte] do node=nodes[node].fail end
                    node=nodes[node].next[byte] or 1
                    local out=node
                    while out do
                        local id=nodes[out].output
                        if id then
                            local start=i-#flex.matcher.rules[id]+1
                            for _, rule in ipairs(flex.ids[id]) do
                                local x,y=first[start],last[i]
                                if ValidFlexible(piece.text,self.rules[rule],x,y,first,start,last) then
                                    local key=(offset+x)..':'..(offset+y)..':'..rule
                                    if not seen[key] then
                                        if #exact>=Engine.MAX_CANDIDATES then return {},'candidate budget exceeded' end
                                        seen[key]=true
                                        exact[#exact+1]={first=offset+x,last=offset+y,rule=rule,evasion=true,
                                            segmentFirst=offset+1,segmentLast=offset+#piece.text}
                                    end
                                end
                            end
                        end
                        out=nodes[out].outputLink
                    end
                end
            end
        end
        offset=offset+#piece.text
    end
    if allCandidates then return exact end
    table.sort(exact,function(a,b) return a.first<b.first or a.first==b.first and a.last>b.last end)
    local result, cursor={},0
    for _, hit in ipairs(exact) do if hit.first>cursor then result[#result+1]=hit;cursor=hit.last end end
    return result
end

-- Directed grammar uses the same bounded spelling support at a clause edge.
-- The rest of the clause is not flattened, so negation and ordinary words stay.
function Engine.EvasionPrefix(text, term)
    if text:sub(1,#term)==term and Boundary(text,#term+1,false) then return #term end
    local cursor, gap = 1, false
    for c in term:gmatch('.') do
        if c:match('[a-z0-9]') then
            if cursor>1 then
                local count=0
                while cursor<=#text do
                    local triple=text:sub(cursor,cursor+2)
                    local nextChar=text:sub(cursor,cursor)
                    if invisible[triple] then cursor=cursor+3
                    elseif nextChar:match('[ \t_.%-%*]') then
                        if gap and nextChar=='.' then return end
                        if nextChar=='.' and text:sub(cursor+1,cursor+1):match('%s') then return end
                        count=count+1; if count>(gap and 4 or 2) then return end
                        cursor=cursor+1
                    else break end
                end
            end
            local actual=text:sub(cursor,cursor):lower()
            local glyph=confusable[text:sub(cursor,cursor+2)] and text:sub(cursor,cursor+2)
                or confusable[text:sub(cursor,cursor+1)] and text:sub(cursor,cursor+1)
            if glyph then actual=confusable[glyph] end
            if actual~=c and leet[actual]~=c then return end
            cursor=cursor+(glyph and #glyph or 1); gap=false
        else gap=true end
    end
    if Boundary(text,cursor,false) then return cursor-1 end
end
function Engine.EvasionSuffix(text,term)
    local cursor,gap=#text,false
    for i=#term,1,-1 do
        local c=term:sub(i,i)
        if c:match('[a-z0-9]') then
            if cursor<#text then
                local count=0
                while cursor>0 do
                    local triple=text:sub(math.max(1,cursor-2),cursor)
                    local actual=text:sub(cursor,cursor)
                    if invisible[triple] then cursor=cursor-3
                    elseif actual:match('[ \t_.%-%*]') then
                        if gap and actual=='.' then return end
                        if actual=='.' and text:sub(cursor+1,cursor+1):match('%s') then return end
                        count=count+1;if count>(gap and 4 or 2) then return end;cursor=cursor-1
                    else break end
                end
            end
            local actual=text:sub(cursor,cursor):lower()
            local triple=text:sub(math.max(1,cursor-2),cursor)
            local pair=text:sub(math.max(1,cursor-1),cursor)
            local glyph=confusable[triple] and triple or confusable[pair] and pair
            if glyph then actual=confusable[glyph] end
            if actual~=c and leet[actual]~=c then return end
            cursor=cursor-(glyph and #glyph or 1);gap=false
        else gap=true end
    end
    if Boundary(text,cursor,true) then return cursor+1 end
end

function Engine.Render(text, matches, makeMarker)
    if #matches == 0 then return text end
    local parts, cursor = {}, 1
    for _, match in ipairs(matches) do
        parts[#parts + 1] = text:sub(cursor, match.first - 1)
        parts[#parts + 1] = makeMarker(text:sub(match.first, match.last), match)
        cursor = match.last + 1
    end
    parts[#parts + 1] = text:sub(cursor)
    return table.concat(parts)
end
