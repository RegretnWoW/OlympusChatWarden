-- Shared, bounded spelling primitives. No vocabulary, saved data or UI.
local _,ns=...
local M={};ns.SpellingMatch=M
function M.Distance(a,b,limit,transpose)
    limit=limit or 2
    if math.abs(#a-#b)>limit then return limit+1 end
    local previous,older={},nil
    for j=0,#b do previous[j]=j end
    for i=1,#a do
        local row={[0]=i};local minimum=i
        for j=1,#b do
            local cost=a:byte(i)==b:byte(j) and 0 or 1
            local value=math.min(previous[j]+1,row[j-1]+1,previous[j-1]+cost)
            if transpose and older and j>1 and a:byte(i)==b:byte(j-1) and a:byte(i-1)==b:byte(j) then
                value=math.min(value,older[j-2]+1)
            end
            row[j]=value;minimum=math.min(minimum,value)
        end
        if minimum>limit then return limit+1 end
        older,previous=previous,row
    end
    return previous[#b]
end
function M.OneEdit(word,add)
    for i=1,#word do
        add(word:sub(1,i-1)..word:sub(i+1),1)
        if i<#word then add(word:sub(1,i-1)..word:sub(i+1,i+1)..word:sub(i,i)..word:sub(i+2),0.75) end
        for code=97,122 do add(word:sub(1,i-1)..string.char(code)..word:sub(i+1),1) end
    end
    for i=0,#word do for code=97,122 do add(word:sub(1,i)..string.char(code)..word:sub(i+1),1) end end
    for i=1,#word-1 do
        if word:byte(i)==word:byte(i+1) then add(word:sub(1,i)..word:sub(i+2),0.5) end
    end
end
