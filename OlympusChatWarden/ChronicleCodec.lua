-- Lossless IEEE-754 route packing. No rounding, executable data or dependencies.
local _,ns=...
local S,P=ns.ChronicleStore,ns.PackCrypto
local K={};ns.ChronicleCodec=K
local floor,char,byte=math.floor,string.char,string.byte
local function SameElapsed(a,b)
    -- The binary payload is authoritative. Decimal SavedVariables parsing can
    -- move redundant elapsed metadata by an IEEE-754 rounding unit. Permit
    -- only that bounded representation error, never rounded coordinates.
    return a==b or math.abs(a-b)<=4*2.220446049250313e-16*math.max(1,math.abs(a),math.abs(b))
end
local function U32(v) return char(floor(v/16777216)%256,floor(v/65536)%256,floor(v/256)%256,v%256) end
local function Double(v)
    local sign=(v<0 or v==0 and 1/v==-math.huge) and 2147483648 or 0;v=math.abs(v)
    local exponent,fraction=0,0
    if v~=0 then
        local m,e=math.frexp(v);exponent=e+1022
        if exponent<=0 then exponent=0;fraction=math.ldexp(v,1074)
        else fraction=(m*2-1)*4503599627370496 end
    end
    return U32(sign+exponent*1048576+floor(fraction/4294967296))..U32(fraction%4294967296)
end
local function Number(raw)
    local a,b,c,d,e,f,g,h=byte(raw,1,8)
    local hi=a*16777216+b*65536+c*256+d;local lo=e*16777216+f*65536+g*256+h
    local negative=hi>=2147483648;hi=hi%2147483648
    local exponent=floor(hi/1048576);local fraction=(hi%1048576)*4294967296+lo
    if exponent==2047 then return end
    local value=exponent==0 and math.ldexp(fraction,-1074) or math.ldexp(1+fraction/4503599627370496,exponent-1023)
    return negative and -value or value
end
function K.Encode(route)
    local clean=S.Route(route);if not clean or clean.format~=1 then return end
    local out={'OCWR',char(#clean.points)};local previous={};local samples=0
    for _,point in ipairs(clean.points) do
        samples=samples+point[12]
        for j=1,12 do
            local v=point[j]
            if v==false then out[#out+1]=char(9)
            else
                local raw=Double(v);local old=previous[j];local prefix=0
                if old then while prefix<8 and raw:byte(prefix+1)==old:byte(prefix+1) do prefix=prefix+1 end end
                out[#out+1]=char(prefix)..raw:sub(prefix+1);previous[j]=raw
            end
        end
    end
    local raw=table.concat(out);local first,last=clean.points[1],clean.points[#clean.points]
    return {format=2,mapID=clean.mapID,worldMapID=clean.worldMapID,count=#clean.points,
        data=P.Base64Encode(raw),sha256=P.Hex(P.SHA256(raw)),firstAt=first[1],lastAt=last[10],
        firstElapsed=first[2],lastElapsed=last[11],observations=samples}
end
function K.Decode(route,checkpoint)
    route=S.Route(route);if not route then return end
    if route.format==1 then return S.Route(route) end
    if route.format~=2 then return end
    local raw=P.Base64Decode(route.data,8192)
    if not raw or raw:sub(1,4)~='OCWR' or P.Hex(P.SHA256(raw,checkpoint))~=route.sha256 or raw:byte(5)~=route.count then return end
    local ok,result=pcall(function()
        local previous={};local pos=6;local points={};local samples=0
        for i=1,route.count do
            local point={}
            for j=1,12 do
                local prefix=raw:byte(pos);pos=pos+1;assert(prefix and prefix<=9)
                if prefix==9 then point[j]=false
                else
                    assert(prefix==0 or previous[j]);local length=8-prefix
                    local bits=(previous[j] or ''):sub(1,prefix)..raw:sub(pos,pos+length-1);pos=pos+length
                    assert(#bits==8);point[j]=Number(bits);assert(point[j]~=nil);previous[j]=bits
                end
            end
            samples=samples+point[12];points[i]=point
        end
        assert(pos==#raw+1)
        local first,last=points[1],points[#points]
        assert(first[1]==route.firstAt and last[10]==route.lastAt and SameElapsed(first[2],route.firstElapsed)
            and SameElapsed(last[11],route.lastElapsed) and samples==route.observations)
        return S.Route({format=1,mapID=route.mapID,worldMapID=route.worldMapID,points=points})
    end)
    return ok and result or nil
end
