-- Built-in display preference, independent of imported category vocabulary.
local _,ns=...
local text={['body type 1']='male',['body type 2']='female'}
for _,pair in ipairs({{BODY_1,'male'},{BODY_2,'female'}}) do
    if type(pair[1])=='string' and pair[1]~='' then text[ns.Engine.Lower(pair[1])]=pair[2] end
end
local phrases={};for phrase in pairs(text) do phrases[#phrases+1]=phrase end;table.sort(phrases)
ns.BuiltinBodyText=text
ns.BuiltinBodyReplacements=assert(ns.Engine.CompileLiteral(phrases))
