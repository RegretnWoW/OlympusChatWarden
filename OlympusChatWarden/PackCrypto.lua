-- Verification only. RSA-2048 / exponent 65537, PSS-SHA256, MGF1-SHA256,
-- 32-byte salt. RFC 8017 sections 8.1.2, 9.1.2 and B.2.1; FIPS 180-4.
-- Public operands use base-65536 limbs; every intermediate is < 2^53.
-- No signing secret, executable import, network call or decryption is present.
local _, ns = ...
local C = {}; ns.PackCrypto = C
local floor, char, byte, concat = math.floor, string.char, string.byte, table.concat
local MOD, BASE, N = 4294967296, 65536, 128
local native = bit or bit32
local xorNibble = {}
for a = 0, 15 do
    xorNibble[a] = {}
    for b = 0, 15 do
        local x, y, value, power = a, b, 0, 1
        for _ = 1, 4 do
            if x % 2 ~= y % 2 then value = value + power end
            x, y, power = floor(x / 2), floor(y / 2), power * 2
        end
        xorNibble[a][b] = value
    end
end
local function Xor2(a, b)
    if native then return native.bxor(a, b) % MOD end
    local value, power = 0, 1
    for _ = 1, 8 do
        value = value + xorNibble[a % 16][b % 16] * power
        a, b, power = floor(a / 16), floor(b / 16), power * 16
    end
    return value
end
local function Xor(a, b, c)
    if native then return (c and native.bxor(a,b,c) or native.bxor(a,b)) % MOD end
    local x = Xor2(a, b); return c and Xor2(x, c) or x
end
local function And(a, b)
    if native then return native.band(a, b) % MOD end
    return (a + b - Xor2(a, b)) / 2
end
local rotate = native and (native.ror or native.rrotate)
local function Ror(x, n)
    if rotate then return rotate(x,n) % MOD end
    return floor(x / 2^n) + (x % 2^n) * 2^(32 - n)
end
local function U32(x) return char(floor(x / 16777216) % 256, floor(x / 65536) % 256, floor(x / 256) % 256, x % 256) end
local K = {1116352408,1899447441,3049323471,3921009573,961987163,1508970993,2453635748,2870763221,
    3624381080,310598401,607225278,1426881987,1925078388,2162078206,2614888103,3248222580,
    3835390401,4022224774,264347078,604807628,770255983,1249150122,1555081692,1996064986,
    2554220882,2821834349,2952996808,3210313671,3336571891,3584528711,113926993,338241895,
    666307205,773529912,1294757372,1396182291,1695183700,1986661051,2177026350,2456956037,
    2730485921,2820302411,3259730800,3345764771,3516065817,3600352804,4094571909,275423344,
    430227734,506948616,659060556,883997877,958139571,1322822218,1537002063,1747873779,
    1955562222,2024104815,2227730452,2361852424,2428436474,2756734187,3204031479,3329325298}
function C.SHA256(message, checkpoint)
    local length = #message
    message = message .. char(128) .. string.rep(char(0), (55 - length) % 64)
        .. U32(floor(length / 536870912)) .. U32((length * 8) % MOD)
    local h = {1779033703,3144134277,1013904242,2773480762,1359893119,2600822924,528734635,1541459225}
    local w = {}
    for offset = 1, #message, 64 do
        for i = 1, 16 do
            local j = offset + (i - 1) * 4
            w[i] = byte(message,j)*16777216 + byte(message,j+1)*65536 + byte(message,j+2)*256 + byte(message,j+3)
        end
        for i = 17, 64 do
            local x, y = w[i-15], w[i-2]
            w[i] = (w[i-16] + Xor(Ror(x,7), Ror(x,18), floor(x/8)) + w[i-7]
                + Xor(Ror(y,17), Ror(y,19), floor(y/1024))) % MOD
        end
        local a,b,c,d,e,f,g,j = h[1],h[2],h[3],h[4],h[5],h[6],h[7],h[8]
        for i = 1, 64 do
            local t1 = (j + Xor(Ror(e,6),Ror(e,11),Ror(e,25)) + Xor(And(e,f),And(MOD-1-e,g)) + K[i] + w[i]) % MOD
            local t2 = (Xor(Ror(a,2),Ror(a,13),Ror(a,22)) + Xor(And(a,b),And(a,c),And(b,c))) % MOD
            j,g,f,e,d,c,b,a = g,f,e,(d+t1)%MOD,c,b,a,(t1+t2)%MOD
        end
        local values = {a,b,c,d,e,f,g,j}
        for i = 1, 8 do h[i] = (h[i] + values[i]) % MOD end
        if checkpoint then checkpoint() end
    end
    for i = 1, 8 do h[i] = U32(h[i]) end
    return concat(h)
end
function C.Hex(raw) return (raw:gsub('.', function(c) return string.format('%02x', byte(c)) end)) end
function C.Unhex(hex)
    if type(hex) ~= 'string' or #hex % 2 ~= 0 or hex:find('[^0-9a-f]') then return end
    return (hex:gsub('..', function(x) return char(tonumber(x,16)) end))
end
local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local decode = {}; for i=1,64 do decode[alphabet:sub(i,i)] = i-1 end
function C.Base64Encode(raw)
    local output = {}
    for i=1,#raw,3 do
        local a,b,c = byte(raw,i),byte(raw,i+1),byte(raw,i+2)
        local n = a*65536 + (b or 0)*256 + (c or 0)
        output[#output+1] = alphabet:sub(floor(n/262144)+1,floor(n/262144)+1)
            .. alphabet:sub(floor(n/4096)%64+1,floor(n/4096)%64+1)
            .. (b and alphabet:sub(floor(n/64)%64+1,floor(n/64)%64+1) or '=')
            .. (c and alphabet:sub(n%64+1,n%64+1) or '=')
    end
    return concat(output)
end
function C.Base64Decode(text, limit, checkpoint)
    if type(text) ~= 'string' or #text == 0 or #text % 4 ~= 0 or #text > 4*math.ceil(limit/3) then return end
    local output = {}
    for i=1,#text,4 do
        local a,b,c,d = text:sub(i,i),text:sub(i+1,i+1),text:sub(i+2,i+2),text:sub(i+3,i+3)
        local x,y,z,t = decode[a],decode[b],decode[c],decode[d]
        if not x or not y then return end
        if c == '=' then
            if d ~= '=' or i ~= #text-3 or y%16 ~= 0 then return end
        elseif not z then return end
        if d == '=' then
            if i ~= #text-3 or c ~= '=' and z%4 ~= 0 then return end
        elseif not t or c == '=' then return end
        local n = x*262144 + y*4096 + (z or 0)*64 + (t or 0)
        output[#output+1] = char(floor(n/65536)) .. (z and char(floor(n/256)%256) or '') .. (t and char(n%256) or '')
        if checkpoint and i%1024 == 1 then checkpoint() end
    end
    local raw = concat(output); if #raw > limit then return end
    return raw
end
local function Limbs(raw)
    local x = {}
    for i=1,N do local j = #raw-(i-1)*2; x[i] = byte(raw,j-1)*256 + byte(raw,j) end
    return x
end
local function Compare(a,b)
    for i=N,1,-1 do if a[i] ~= b[i] then return a[i] < b[i] and -1 or 1 end end
    return 0
end
local function Subtract(a,b)
    local borrow = 0
    for i=1,N do
        local value = a[i] - b[i] - borrow
        borrow = value < 0 and 1 or 0; a[i] = value % BASE
    end
end
local function Montgomery(a,b,key,checkpoint)
    local t = {}; for i=1,2*N+2 do t[i]=0 end
    for i=1,N do
        local carry = 0
        for j=1,N do
            local k = i+j-1; local v = t[k] + a[i]*b[j] + carry
            t[k],carry = v%BASE,floor(v/BASE)
        end
        t[i+N] = carry
        if checkpoint and i%8 == 0 then checkpoint() end
    end
    for i=1,N do
        local m = (t[i]*key.inverse)%BASE; local carry=0
        for j=1,N do
            local k = i+j-1; local v = t[k] + m*key.n[j] + carry
            t[k],carry = v%BASE,floor(v/BASE)
        end
        local k=i+N
        while carry > 0 do local v=t[k]+carry; t[k],carry=v%BASE,floor(v/BASE); k=k+1 end
        if checkpoint and i%8 == 0 then checkpoint() end
    end
    local result = {}; for i=1,N do result[i]=t[i+N] end
    if t[2*N+1] > 0 or Compare(result,key.n)>=0 then Subtract(result,key.n) end
    return result
end
local contexts = setmetatable({}, {__mode='k'})
function C.RSA(signature, publicKey, checkpoint)
    if type(signature)~='string' or #signature~=256 or type(publicKey)~='table' then return end
    local key=contexts[publicKey]
    if not key then
        local modulus,r2 = C.Unhex(publicKey.modulus),C.Unhex(publicKey.r2)
        if not modulus or #modulus~=256 or byte(modulus,1)<128 or byte(modulus,256)%2~=1
            or not r2 or #r2~=256 or type(publicKey.inverse)~='number' then return end
        key={n=Limbs(modulus),r2=Limbs(r2),inverse=publicKey.inverse}; contexts[publicKey]=key
    end
    local input=Limbs(signature); if Compare(input,key.n)>=0 then return end
    local x=Montgomery(input,key.r2,key,checkpoint); local result=x
    for _=1,16 do result=Montgomery(result,result,key,checkpoint) end
    result=Montgomery(result,x,key,checkpoint)
    local one={}; for i=1,N do one[i]=i==1 and 1 or 0 end
    result=Montgomery(result,one,key,checkpoint)
    local output={}; for i=N,1,-1 do output[#output+1]=char(floor(result[i]/256),result[i]%256) end
    return concat(output)
end
function C.Verify(message, signature, publicKey, checkpoint)
    local em=C.RSA(signature,publicKey,checkpoint)
    if not em or byte(em,256)~=188 or byte(em,1)>=128 then return false end
    local hash=em:sub(224,255); local mask={}
    for i=0,6 do mask[#mask+1]=C.SHA256(hash..U32(i),checkpoint) end
    mask=concat(mask)
    local db={}
    for i=1,223 do db[i]=Xor2(byte(em,i),byte(mask,i)) end
    db[1]=db[1]%128
    for i=1,190 do if db[i]~=0 then return false end end
    if db[191]~=1 then return false end
    local salt={}; for i=192,223 do salt[#salt+1]=char(db[i]) end
    local expected=C.SHA256(string.rep(char(0),8)..C.SHA256(message,checkpoint)..concat(salt),checkpoint)
    return expected==hash
end
