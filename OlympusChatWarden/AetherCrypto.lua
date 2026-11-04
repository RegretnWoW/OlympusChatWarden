-- Ed25519 support: ccryptolib arithmetic/SHA-512, MIT, pinned source in NOTICE.
-- Adaptations: private module namespace, non-code-generating binary packing,
-- WoW bit compatibility, RFC8032 deterministic signing and strict verification.
-- No random key generation: seed material must come from the enrollment helper.
local _,ns=...
local unpack=unpack or table.unpack
local recoveryDeadlines=setmetatable({},{__mode='k'})
local function RecoveryCheckpoint()
 local thread=coroutine.running();local deadline=thread and recoveryDeadlines[thread]
 if deadline then local now=ns.WardenPerformance and ns.WardenPerformance.Now()or os and os.clock and os.clock()*1000
  if now and now>=deadline then coroutine.yield()end
 end
end
local MOD=4294967296
local native=bit32 or bit or ns.PackCrypto and ns.PackCrypto.BitOps
local function binary(a,b,mode)
 a=a%MOD;b=b%MOD;local x,p=0,1
 for _=1,32 do local aa,bb=a%2,b%2;if (mode==1 and aa~=bb)or(mode==2 and aa==1 and bb==1)or(mode==3 and(aa==1 or bb==1))then x=x+p end;a=math.floor(a/2);b=math.floor(b/2);p=p*2 end
 return x
end
local bit32={}
for k,mode in pairs({bxor=1,band=2,bor=3})do local op=mode;local fn=native and native[k]
 bit32[k]=function(a,b,...)local x=fn and fn(a,b)%MOD or binary(a,b,op);for i=1,select('#',...)do local v=select(i,...);x=fn and fn(x,v)%MOD or binary(x,v,op)end;return x end
end
bit32.bnot=function(x)return MOD-1-x%MOD end
bit32.lshift=function(x,n)if n>=32 then return 0 end;return (x%MOD*2^n)%MOD end
bit32.rshift=function(x,n)if n>=32 then return 0 end;return math.floor(x%MOD/2^n)end
bit32.extract=function(x,f,w)return math.floor(x%MOD/2^f)%2^(w or 1)end
local modules,loaders={},{}
local function require(k)if modules[k]then return modules[k]end;assert(loaders[k],'Unknown internal crypto dependency');local m=loaders[k]();modules[k]=m;return m end
modules['cc.expect']={expect=function(i,x,t)assert(type(x)==t,'Invalid crypto argument '..i);return x end}
modules['ccryptolib.internal.packing']={}
local packing=modules['ccryptolib.internal.packing']
local function formatParts(fmt)local widths={};assert(fmt:match('^[<>]I[I%d]+$'));for n in fmt:gmatch('I(%d+)')do n=tonumber(n);assert(n>0 and n<=16);widths[#widths+1]=n end;return widths,fmt:sub(1,1)=='>'end
function packing.compilePack(fmt)local widths,be=formatParts(fmt)
 return function(_,...)local out={};for i,n in ipairs(widths)do local v=select(i,...);local b={};for j=1,n do b[j]=string.char(v%256);v=math.floor(v/256)end;if be then for j=n,1,-1 do out[#out+1]=b[j]end else for j=1,n do out[#out+1]=b[j]end end end;return table.concat(out)end,fmt
end
function packing.compileUnpack(fmt)local widths,be=formatParts(fmt)
 return function(_,s,p)local out={};for i,n in ipairs(widths)do local v=0;if be then for j=0,n-1 do v=v*256+s:byte(p+j)end else for j=n-1,0,-1 do v=v*256+s:byte(p+j)end end;out[i]=v;p=p+n end;out[#out+1]=p;return unpack(out)end,fmt
end

loaders['ccryptolib.internal.util']=function()
local function lassert(val, err, level)
    if not val then error(err, level + 1) end
    return val
end

--- Converts a little-endian array from one power-of-two base to another.
--- @param a number[] The array to convert, in little-endian.
--- @param base1 number The base to convert from. Must be a power of 2.
--- @param base2 number The base to convert to. Must be a power of 2.
--- @return number[]
local function rebaseLE(a, base1, base2) -- TODO Write contract properly.
    local out = {}
    local outlen = 1
    local acc = 0
    local mul = 1
    for i = 1, #a do
        acc = acc + a[i] * mul
        mul = mul * base1
        while mul >= base2 do
            local rem = acc % base2
            acc = (acc - rem) / base2
            mul = mul / base2
            out[outlen] = rem
            outlen = outlen + 1
        end
    end
    if mul > 0 then
        out[outlen] = acc
    end
    return out
end

--- Decodes bits with X25519/Ed25519 exponent clamping.
--- @param str string The 32-byte encoded exponent.
--- @return number[] bits The decoded clamped bits.
local function bits(str)
    -- Decode.
    local bytes = {str:byte(1, 32)}
    local out = {}
    for i = 1, 32 do
        local byte = bytes[i]
        for j = -7, 0 do
            local bit = byte % 2
            out[8 * i + j] = bit
            byte = (byte - bit) / 2
        end
    end

    -- Clamp.
    out[1] = 0
    out[2] = 0
    out[3] = 0
    out[255] = 1
    out[256] = 0

    return out
end

--- Decodes bits with X25519/Ed25519 exponent clamping and division by 8.
--- @param str string The 32-byte encoded exponent.
--- @return number[] bits The decoded clamped bits, divided by 8.
local function bits8(str)
    return {unpack(bits(str), 4)}
end

return {
    lassert = lassert,
    rebaseLE = rebaseLE,
    bits = bits,
    bits8 = bits8,
}

end

loaders['ccryptolib.internal.mp']=function()
--- Multi-precision arithmetic on 264-bit integers.

local unpack = unpack or table.unpack

--- A little-endian big integer of width 11 in (-2⁵²..2⁵²).
--- @class MpSW11L52

--- A little-endian big integer of width 11 in (-2²⁴, 2²⁴).
--- @class MpSW11L24: MpSW11L52

--- A little-endian big integer of width 11 in [0..2²⁴).
--- @class MpUW11L24: MpSW11L24

--- Carries a number in base 2²⁴ into a signed limb form.
--- @param a MpSW11L52
--- @return MpSW11L24 low The carried low limbs.
--- @return number carry The overflowed carry.
local function carryWeak(a)
    local a00, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10 = unpack(a)

    local h00 = a00 + 3 * 2 ^ 75 - 3 * 2 ^ 75 a01 = a01 + h00 * 2 ^ -24
    local h01 = a01 + 3 * 2 ^ 75 - 3 * 2 ^ 75 a02 = a02 + h01 * 2 ^ -24
    local h02 = a02 + 3 * 2 ^ 75 - 3 * 2 ^ 75 a03 = a03 + h02 * 2 ^ -24
    local h03 = a03 + 3 * 2 ^ 75 - 3 * 2 ^ 75 a04 = a04 + h03 * 2 ^ -24
    local h04 = a04 + 3 * 2 ^ 75 - 3 * 2 ^ 75 a05 = a05 + h04 * 2 ^ -24
    local h05 = a05 + 3 * 2 ^ 75 - 3 * 2 ^ 75 a06 = a06 + h05 * 2 ^ -24
    local h06 = a06 + 3 * 2 ^ 75 - 3 * 2 ^ 75 a07 = a07 + h06 * 2 ^ -24
    local h07 = a07 + 3 * 2 ^ 75 - 3 * 2 ^ 75 a08 = a08 + h07 * 2 ^ -24
    local h08 = a08 + 3 * 2 ^ 75 - 3 * 2 ^ 75 a09 = a09 + h08 * 2 ^ -24
    local h09 = a09 + 3 * 2 ^ 75 - 3 * 2 ^ 75 a10 = a10 + h09 * 2 ^ -24
    local h10 = a10 + 3 * 2 ^ 75 - 3 * 2 ^ 75

    return {
        a00 - h00,
        a01 - h01,
        a02 - h02,
        a03 - h03,
        a04 - h04,
        a05 - h05,
        a06 - h06,
        a07 - h07,
        a08 - h08,
        a09 - h09,
        a10 - h10,
    }, h10 * 2 ^ -24
end

--- Carries a number in base 2²⁴.
--- @param a MpSW11L52
--- @return MpUW11L24 low The low 11 limbs of the output.
--- @return number carry The overflow carry.
local function carry(a)
    local a00, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10 = unpack(a)

    local l00 = a00 % 2 ^ 24 a01 = a01 + (a00 - l00) * 2 ^ -24
    local l01 = a01 % 2 ^ 24 a02 = a02 + (a01 - l01) * 2 ^ -24
    local l02 = a02 % 2 ^ 24 a03 = a03 + (a02 - l02) * 2 ^ -24
    local l03 = a03 % 2 ^ 24 a04 = a04 + (a03 - l03) * 2 ^ -24
    local l04 = a04 % 2 ^ 24 a05 = a05 + (a04 - l04) * 2 ^ -24
    local l05 = a05 % 2 ^ 24 a06 = a06 + (a05 - l05) * 2 ^ -24
    local l06 = a06 % 2 ^ 24 a07 = a07 + (a06 - l06) * 2 ^ -24
    local l07 = a07 % 2 ^ 24 a08 = a08 + (a07 - l07) * 2 ^ -24
    local l08 = a08 % 2 ^ 24 a09 = a09 + (a08 - l08) * 2 ^ -24
    local l09 = a09 % 2 ^ 24 a10 = a10 + (a09 - l09) * 2 ^ -24
    local l10 = a10 % 2 ^ 24
    local h10 = (a10 - l10) * 2 ^ -24

    return {l00, l01, l02, l03, l04, l05, l06, l07, l08, l09, l10}, h10
end

--- Adds two numbers.
--- @param a MpSW11L24
--- @param b MpSW11L24
--- @return MpSW11L52 c a + b
local function add(a, b)
    local a00, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10 = unpack(a)
    local b00, b01, b02, b03, b04, b05, b06, b07, b08, b09, b10 = unpack(b)

    return {
        a00 + b00,
        a01 + b01,
        a02 + b02,
        a03 + b03,
        a04 + b04,
        a05 + b05,
        a06 + b06,
        a07 + b07,
        a08 + b08,
        a09 + b09,
        a10 + b10,
    }
end

--- Subtracts a number from another.
--- @param a MpSW11L24
--- @param b MpSW11L24
--- @return MpSW11L52 c a - b
local function sub(a, b)
    local a00, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10 = unpack(a)
    local b00, b01, b02, b03, b04, b05, b06, b07, b08, b09, b10 = unpack(b)

    return {
        a00 - b00,
        a01 - b01,
        a02 - b02,
        a03 - b03,
        a04 - b04,
        a05 - b05,
        a06 - b06,
        a07 - b07,
        a08 - b08,
        a09 - b09,
        a10 - b10,
    }
end

--- Computes the lower half of a product between two numbers.
--- @param a MpUW11L24
--- @param b MpUW11L24
--- @return MpUW11L24 c a × b (mod 2²⁶⁴)
--- @return number carry ⌊a × b ÷ 2²⁶⁴⌋
local function lmul(a, b)
    local a00, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10 = unpack(a)
    local b00, b01, b02, b03, b04, b05, b06, b07, b08, b09, b10 = unpack(b)

    return carry {
        a00 * b00,
        a01 * b00 + a00 * b01,
        a02 * b00 + a01 * b01 + a00 * b02,
        a03 * b00 + a02 * b01 + a01 * b02 + a00 * b03,
        a04 * b00 + a03 * b01 + a02 * b02 + a01 * b03 + a00 * b04,
        a05 * b00 + a04 * b01 + a03 * b02 + a02 * b03 + a01 * b04 + a00 * b05,
        a06 * b00 + a05 * b01 + a04 * b02 + a03 * b03 + a02 * b04 + a01 * b05 + a00 * b06,
        a07 * b00 + a06 * b01 + a05 * b02 + a04 * b03 + a03 * b04 + a02 * b05 + a01 * b06 + a00 * b07,
        a08 * b00 + a07 * b01 + a06 * b02 + a05 * b03 + a04 * b04 + a03 * b05 + a02 * b06 + a01 * b07 + a00 * b08,
        a09 * b00 + a08 * b01 + a07 * b02 + a06 * b03 + a05 * b04 + a04 * b05 + a03 * b06 + a02 * b07 + a01 * b08 + a00 * b09,
        a10 * b00 + a09 * b01 + a08 * b02 + a07 * b03 + a06 * b04 + a05 * b05 + a04 * b06 + a03 * b07 + a02 * b08 + a01 * b09 + a00 * b10,
    }
end

--- Computes the a product between two numbers.
--- @param a MpUW11L24
--- @param b MpUW11L24
--- @return MpUW11L24 low The low 11 limbs of a × b.
--- @return MpUW11L24 high The high 11 limbs of a × b.
local function mul(a, b)
    local low, of = lmul(a, b)

    local _, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10 = unpack(a)
    local _, b01, b02, b03, b04, b05, b06, b07, b08, b09, b10 = unpack(b)

    -- The carry is always 0.
    return low, (carry {
        of + a10 * b01 + a09 * b02 + a08 * b03 + a07 * b04 + a06 * b05 + a05 * b06 + a04 * b07 + a03 * b08 + a02 * b09 + a01 * b10,
        a10 * b02 + a09 * b03 + a08 * b04 + a07 * b05 + a06 * b06 + a05 * b07 + a04 * b08 + a03 * b09 + a02 * b10,
        a10 * b03 + a09 * b04 + a08 * b05 + a07 * b06 + a06 * b07 + a05 * b08 + a04 * b09 + a03 * b10,
        a10 * b04 + a09 * b05 + a08 * b06 + a07 * b07 + a06 * b08 + a05 * b09 + a04 * b10,
        a10 * b05 + a09 * b06 + a08 * b07 + a07 * b08 + a06 * b09 + a05 * b10,
        a10 * b06 + a09 * b07 + a08 * b08 + a07 * b09 + a06 * b10,
        a10 * b07 + a09 * b08 + a08 * b09 + a07 * b10,
        a10 * b08 + a09 * b09 + a08 * b10,
        a10 * b09 + a09 * b10,
        a10 * b10,
        0
    })
end

--- Computes a double-width sum of two numbers.
--- @param a0 MpUW11L24 The low 11 limbs of a.
--- @param a1 MpUW11L24 The high 11 limbs of a.
--- @param b0 MpUW11L24 The low 11 limbs of b.
--- @param b1 MpUW11L24 The high 11 limbs of b.
--- @return MpUW11L24 c0 The low 11 limbs of a + b.
--- @return MpUW11L24 c1 The high 11 limbs of a + b.
--- @return number The carry.
local function dwadd(a0, a1, b0, b1)
    local low, c = carry(add(a0, b0))
    local high = add(a1, b1)
    high[1] = high[1] + c
    return low, carry(high)
end

--- Computes half of a number.
--- @param a MpSW11L24 The number to halve, must be even.
--- @return MpSW11L24 c a ÷ 2
local function half(a)
    local a00, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10 = unpack(a)

    return (carryWeak {
        a00 * 0.5 + a01 * 2 ^ 23,
        a02 * 2 ^ 23,
        a03 * 2 ^ 23,
        a04 * 2 ^ 23,
        a05 * 2 ^ 23,
        a06 * 2 ^ 23,
        a07 * 2 ^ 23,
        a08 * 2 ^ 23,
        a09 * 2 ^ 23,
        a10 * 2 ^ 23,
        0,
    })
end

--- Computes a third of a number.
--- @param a MpSW11L24 The number to divide, must be a multiple of 3.
--- @return MpSW11L24 c a ÷ 3
local function third(a)
    local a00, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10 = unpack(a)

    local d00 = a00 * 0xaaaaaa
    local d01 = a01 * 0xaaaaaa + d00
    local d02 = a02 * 0xaaaaaa + d01
    local d03 = a03 * 0xaaaaaa + d02
    local d04 = a04 * 0xaaaaaa + d03
    local d05 = a05 * 0xaaaaaa + d04
    local d06 = a06 * 0xaaaaaa + d05
    local d07 = a07 * 0xaaaaaa + d06
    local d08 = a08 * 0xaaaaaa + d07
    local d09 = a09 * 0xaaaaaa + d08
    local d10 = a10 * 0xaaaaaa + d09

    -- We compute the modular division mod 2²⁶⁴. The carry isn't 0 but it isn't
    -- part of a ÷ 3 either.
    return (carryWeak {
        a00 + d00,
        a01 + d01,
        a02 + d02,
        a03 + d03,
        a04 + d04,
        a05 + d05,
        a06 + d06,
        a07 + d07,
        a08 + d08,
        a09 + d09,
        a10 + d10,
    })
end

--- Computes a number modulo 2.
--- @param a MpSW11L24
--- @return number c a mod 2.
local function mod2(a)
    return a[1] % 2
end

--- Computes a number modulo 3.
--- @param a MpSW11L24
--- @return number c a mod 3.
local function mod3(a)
    local a00, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10 = unpack(a)
    return (a00 + a01 + a02 + a03 + a04 + a05 + a06 + a07 + a08 + a09 + a10) % 3
end

--- Computes a double representing the most-significant bits of a number.
--- @param a MpSW11L52
--- @return number c A floating-point approximation for the value of a.
local function approx(a)
    local a00, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10 = unpack(a)
    return a00
         + a01 * 2 ^ 24
         + a02 * 2 ^ 48
         + a03 * 2 ^ 72
         + a04 * 2 ^ 96
         + a05 * 2 ^ 120
         + a06 * 2 ^ 144
         + a07 * 2 ^ 168
         + a08 * 2 ^ 192
         + a09 * 2 ^ 216
         + a10 * 2 ^ 240
end

--- Compares two numbers for ordering.
--- @param a MpSW11L24
--- @param b MpSW11L24
--- @return number ord Some number with ord < 0 iff a < b and ord = 0 iff a = b.
local function cmp(a, b)
    return approx(sub(a, b))
end

local function num(a)
    return {a, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
end

return {
    carry = carry,
    carryWeak = carryWeak,
    add = add,
    sub = sub,
    dwadd = dwadd,
    lmul = lmul,
    mul = mul,
    half = half,
    third = third,
    mod2 = mod2,
    mod3 = mod3,
    approx = approx,
    cmp = cmp,
    num = num,
}

end

loaders['ccryptolib.internal.fp']=function()
--- Arithmetic on Curve25519's base field.

local packing = require "ccryptolib.internal.packing"

local unpack = unpack or table.unpack
local ufp, fmtfp = packing.compileUnpack("<I3I3I2I3I3I2I3I3I2I3I3I2")

--- @class Fq An element of the field of integers modulo 2²⁵⁵ - 19.

--- @class FpR2: Fq An Fp element with limbs inside twice the standard range.

--- @class FpR1: FpR2 An Fp element with limbs inside the standard range. See
--- the Curve25519 polynomial representation for more info around this.

--- The modular square root of -1.
--- @type FpR1
local I = {
    0958640 * 2 ^ 0,
    0826664 * 2 ^ 22,
    1613251 * 2 ^ 43,
    1041528 * 2 ^ 64,
    0013673 * 2 ^ 85,
    0387171 * 2 ^ 107,
    1824679 * 2 ^ 128,
    0313839 * 2 ^ 149,
    0709440 * 2 ^ 170,
    0122635 * 2 ^ 192,
    0262782 * 2 ^ 213,
    0712905 * 2 ^ 234,
}

--- Converts a Lua number to an element.
--- @param n number A number n in [0..2²²).
--- @return FpR1 out The number as an element.
local function num(n)
    return {n, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
end

--- Negates an element.
--- @param a FpR1
--- @return FpR1 out -a.
local function neg(a)
    local a00, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10, a11 = unpack(a)
    return {
        -a00,
        -a01,
        -a02,
        -a03,
        -a04,
        -a05,
        -a06,
        -a07,
        -a08,
        -a09,
        -a10,
        -a11,
    }
end

--- Adds two elements.
--- @param a FpR1
--- @param b FpR1
--- @return FpR2 out a + b.
local function add(a, b)
    local a00, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10, a11 = unpack(a)
    local b00, b01, b02, b03, b04, b05, b06, b07, b08, b09, b10, b11 = unpack(b)
    return {
        a00 + b00,
        a01 + b01,
        a02 + b02,
        a03 + b03,
        a04 + b04,
        a05 + b05,
        a06 + b06,
        a07 + b07,
        a08 + b08,
        a09 + b09,
        a10 + b10,
        a11 + b11,
    }
end

--- Subtracts an element from another.
--- @param a FpR1
--- @param b FpR1
--- @return FpR2 out a - b.
local function sub(a, b)
    local a00, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10, a11 = unpack(a)
    local b00, b01, b02, b03, b04, b05, b06, b07, b08, b09, b10, b11 = unpack(b)
    return {
        a00 - b00,
        a01 - b01,
        a02 - b02,
        a03 - b03,
        a04 - b04,
        a05 - b05,
        a06 - b06,
        a07 - b07,
        a08 - b08,
        a09 - b09,
        a10 - b10,
        a11 - b11,
    }
end

--- Carries an element. Also performs a small reduction modulo p.
--- @param a FpR2 The element to carry.
--- @return FpR1 out The same element as a but in a tighter range.
local function carry(a)
    local a00, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10, a11 = unpack(a)
    local c00, c01, c02, c03, c04, c05, c06, c07, c08, c09, c10, c11

    c11 = a11 + 3 * 2 ^ 306 - 3 * 2 ^ 306  a00 = a00 + 19 / 2 ^ 255 * c11

    c00 = a00 + 3 * 2 ^ 73  - 3 * 2 ^ 73   a01 = a01 + c00
    c01 = a01 + 3 * 2 ^ 94  - 3 * 2 ^ 94   a02 = a02 + c01
    c02 = a02 + 3 * 2 ^ 115 - 3 * 2 ^ 115  a03 = a03 + c02
    c03 = a03 + 3 * 2 ^ 136 - 3 * 2 ^ 136  a04 = a04 + c03
    c04 = a04 + 3 * 2 ^ 158 - 3 * 2 ^ 158  a05 = a05 + c04
    c05 = a05 + 3 * 2 ^ 179 - 3 * 2 ^ 179  a06 = a06 + c05
    c06 = a06 + 3 * 2 ^ 200 - 3 * 2 ^ 200  a07 = a07 + c06
    c07 = a07 + 3 * 2 ^ 221 - 3 * 2 ^ 221  a08 = a08 + c07
    c08 = a08 + 3 * 2 ^ 243 - 3 * 2 ^ 243  a09 = a09 + c08
    c09 = a09 + 3 * 2 ^ 264 - 3 * 2 ^ 264  a10 = a10 + c09
    c10 = a10 + 3 * 2 ^ 285 - 3 * 2 ^ 285  a11 = a11 - c11 + c10

    c11 = a11 + 3 * 2 ^ 306 - 3 * 2 ^ 306

    return {
        a00 - c00 + 19 / 2 ^ 255 * c11,
        a01 - c01,
        a02 - c02,
        a03 - c03,
        a04 - c04,
        a05 - c05,
        a06 - c06,
        a07 - c07,
        a08 - c08,
        a09 - c09,
        a10 - c10,
        a11 - c11,
    }
end

--- Returns the canoncal representative of a modp number.
---
--- Some elements can be represented by two different arrays of floats. This
--- returns the canonical element of the represented equivalence class. We
--- define an element as canonical if it's the smallest nonnegative number in
--- its class.
---
--- @param a FpR2
--- @return FpR1 out A canonical element a' ≡ a (mod p).
local function canonicalize(a)
    local a00, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10, a11 = unpack(a)
    local c00, c01, c02, c03, c04, c05, c06, c07, c08, c09, c10, c11

    -- Perform an euclidean reduction.
    -- TODO Range check.
    c00 = a00 % 2 ^ 22   a01 = a00 - c00 + a01
    c01 = a01 % 2 ^ 43   a02 = a01 - c01 + a02
    c02 = a02 % 2 ^ 64   a03 = a02 - c02 + a03
    c03 = a03 % 2 ^ 85   a04 = a03 - c03 + a04
    c04 = a04 % 2 ^ 107  a05 = a04 - c04 + a05
    c05 = a05 % 2 ^ 128  a06 = a05 - c05 + a06
    c06 = a06 % 2 ^ 149  a07 = a06 - c06 + a07
    c07 = a07 % 2 ^ 170  a08 = a07 - c07 + a08
    c08 = a08 % 2 ^ 192  a09 = a08 - c08 + a09
    c09 = a09 % 2 ^ 213  a10 = a09 - c09 + a10
    c10 = a10 % 2 ^ 234  a11 = a10 - c10 + a11
    c11 = a11 % 2 ^ 255  c00 = c00 + 19 / 2 ^ 255 * (a11 - c11)

    -- Canonicalize.
    if      c11 / 2 ^ 234 == 2 ^ 21 - 1
        and c10 / 2 ^ 213 == 2 ^ 21 - 1
        and c09 / 2 ^ 192 == 2 ^ 21 - 1
        and c08 / 2 ^ 170 == 2 ^ 22 - 1
        and c07 / 2 ^ 149 == 2 ^ 21 - 1
        and c06 / 2 ^ 128 == 2 ^ 21 - 1
        and c05 / 2 ^ 107 == 2 ^ 21 - 1
        and c04 / 2 ^ 85  == 2 ^ 22 - 1
        and c03 / 2 ^ 64  == 2 ^ 21 - 1
        and c02 / 2 ^ 43  == 2 ^ 21 - 1
        and c01 / 2 ^ 22  == 2 ^ 21 - 1
        and c00 >= 2 ^ 22 - 19
    then
        return {19 - 2 ^ 22 + c00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    else
        return {c00, c01, c02, c03, c04, c05, c06, c07, c08, c09, c10, c11}
    end
end

--- Returns whether two elements are the same.
--- @param a FpR1
--- @param b FpR1
--- @return boolean eq Whether a ≡ b (mod p).
local function eq(a, b)
    local c = canonicalize(sub(a, b))
    for i = 1, 12 do if c[i] ~= 0 then return false end end
    return true
end

--- Multiplies two elements.
--- @param a FpR2
--- @param b FpR2
--- @return FpR1 c An element such that c ≡ a × b (mod p).
local function mul(a, b)
    local a00, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10, a11 = unpack(a)
    local b00, b01, b02, b03, b04, b05, b06, b07, b08, b09, b10, b11 = unpack(b)
    local c00, c01, c02, c03, c04, c05, c06, c07, c08, c09, c10, c11

    -- Multiply high half into c00..c11.
    c00 = a11 * b01
        + a10 * b02
        + a09 * b03
        + a08 * b04
        + a07 * b05
        + a06 * b06
        + a05 * b07
        + a04 * b08
        + a03 * b09
        + a02 * b10
        + a01 * b11
    c01 = a11 * b02
        + a10 * b03
        + a09 * b04
        + a08 * b05
        + a07 * b06
        + a06 * b07
        + a05 * b08
        + a04 * b09
        + a03 * b10
        + a02 * b11
    c02 = a11 * b03
        + a10 * b04
        + a09 * b05
        + a08 * b06
        + a07 * b07
        + a06 * b08
        + a05 * b09
        + a04 * b10
        + a03 * b11
    c03 = a11 * b04
        + a10 * b05
        + a09 * b06
        + a08 * b07
        + a07 * b08
        + a06 * b09
        + a05 * b10
        + a04 * b11
    c04 = a11 * b05
        + a10 * b06
        + a09 * b07
        + a08 * b08
        + a07 * b09
        + a06 * b10
        + a05 * b11
    c05 = a11 * b06
        + a10 * b07
        + a09 * b08
        + a08 * b09
        + a07 * b10
        + a06 * b11
    c06 = a11 * b07
        + a10 * b08
        + a09 * b09
        + a08 * b10
        + a07 * b11
    c07 = a11 * b08
        + a10 * b09
        + a09 * b10
        + a08 * b11
    c08 = a11 * b09
        + a10 * b10
        + a09 * b11
    c09 = a11 * b10
        + a10 * b11
    c10 = a11 * b11

    -- Multiply low half with reduction into c00..c11.
    c00 = c00 * (19 / 2 ^ 255)
        + a00 * b00
    c01 = c01 * (19 / 2 ^ 255)
        + a01 * b00
        + a00 * b01
    c02 = c02 * (19 / 2 ^ 255)
        + a02 * b00
        + a01 * b01
        + a00 * b02
    c03 = c03 * (19 / 2 ^ 255)
        + a03 * b00
        + a02 * b01
        + a01 * b02
        + a00 * b03
    c04 = c04 * (19 / 2 ^ 255)
        + a04 * b00
        + a03 * b01
        + a02 * b02
        + a01 * b03
        + a00 * b04
    c05 = c05 * (19 / 2 ^ 255)
        + a05 * b00
        + a04 * b01
        + a03 * b02
        + a02 * b03
        + a01 * b04
        + a00 * b05
    c06 = c06 * (19 / 2 ^ 255)
        + a06 * b00
        + a05 * b01
        + a04 * b02
        + a03 * b03
        + a02 * b04
        + a01 * b05
        + a00 * b06
    c07 = c07 * (19 / 2 ^ 255)
        + a07 * b00
        + a06 * b01
        + a05 * b02
        + a04 * b03
        + a03 * b04
        + a02 * b05
        + a01 * b06
        + a00 * b07
    c08 = c08 * (19 / 2 ^ 255)
        + a08 * b00
        + a07 * b01
        + a06 * b02
        + a05 * b03
        + a04 * b04
        + a03 * b05
        + a02 * b06
        + a01 * b07
        + a00 * b08
    c09 = c09 * (19 / 2 ^ 255)
        + a09 * b00
        + a08 * b01
        + a07 * b02
        + a06 * b03
        + a05 * b04
        + a04 * b05
        + a03 * b06
        + a02 * b07
        + a01 * b08
        + a00 * b09
    c10 = c10 * (19 / 2 ^ 255)
        + a10 * b00
        + a09 * b01
        + a08 * b02
        + a07 * b03
        + a06 * b04
        + a05 * b05
        + a04 * b06
        + a03 * b07
        + a02 * b08
        + a01 * b09
        + a00 * b10
    c11 = a11 * b00
        + a10 * b01
        + a09 * b02
        + a08 * b03
        + a07 * b04
        + a06 * b05
        + a05 * b06
        + a04 * b07
        + a03 * b08
        + a02 * b09
        + a01 * b10
        + a00 * b11

    -- Carry and reduce.
    a10 = c10 + 3 * 2 ^ 285 - 3 * 2 ^ 285  c11 = c11 + a10
    a11 = c11 + 3 * 2 ^ 306 - 3 * 2 ^ 306  c00 = c00 + 19 / 2 ^ 255 * a11

    a00 = c00 + 3 * 2 ^ 73  - 3 * 2 ^ 73   c01 = c01 + a00
    a01 = c01 + 3 * 2 ^ 94  - 3 * 2 ^ 94   c02 = c02 + a01
    a02 = c02 + 3 * 2 ^ 115 - 3 * 2 ^ 115  c03 = c03 + a02
    a03 = c03 + 3 * 2 ^ 136 - 3 * 2 ^ 136  c04 = c04 + a03
    a04 = c04 + 3 * 2 ^ 158 - 3 * 2 ^ 158  c05 = c05 + a04
    a05 = c05 + 3 * 2 ^ 179 - 3 * 2 ^ 179  c06 = c06 + a05
    a06 = c06 + 3 * 2 ^ 200 - 3 * 2 ^ 200  c07 = c07 + a06
    a07 = c07 + 3 * 2 ^ 221 - 3 * 2 ^ 221  c08 = c08 + a07
    a08 = c08 + 3 * 2 ^ 243 - 3 * 2 ^ 243  c09 = c09 + a08
    a09 = c09 + 3 * 2 ^ 264 - 3 * 2 ^ 264  c10 = c10 - a10 + a09
    a10 = c10 + 3 * 2 ^ 285 - 3 * 2 ^ 285  c11 = c11 - a11 + a10

    a11 = c11 + 3 * 2 ^ 306 - 3 * 2 ^ 306

    return {
        c00 - a00 + 19 / 2 ^ 255 * a11,
        c01 - a01,
        c02 - a02,
        c03 - a03,
        c04 - a04,
        c05 - a05,
        c06 - a06,
        c07 - a07,
        c08 - a08,
        c09 - a09,
        c10 - a10,
        c11 - a11,
    }
end

--- Squares an element.
--- @param a FpR2
--- @return FpR1 b An element such that b ≡ a² (mod p).
local function square(a)
    local a00, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10, a11 = unpack(a)
    local d00, d01, d02, d03, d04, d05, d06, d07, d08, d09, d10
    local c00, c01, c02, c03, c04, c05, c06, c07, c08, c09, c10, c11

    -- Compute 2a.
    d00 = a00 + a00
    d01 = a01 + a01
    d02 = a02 + a02
    d03 = a03 + a03
    d04 = a04 + a04
    d05 = a05 + a05
    d06 = a06 + a06
    d07 = a07 + a07
    d08 = a08 + a08
    d09 = a09 + a09
    d10 = a10 + a10

    -- Multiply high half into c00..c11.
    c00 = a11 * d01
        + a10 * d02
        + a09 * d03
        + a08 * d04
        + a07 * d05
        + a06 * a06
    c01 = a11 * d02
        + a10 * d03
        + a09 * d04
        + a08 * d05
        + a07 * d06
    c02 = a11 * d03
        + a10 * d04
        + a09 * d05
        + a08 * d06
        + a07 * a07
    c03 = a11 * d04
        + a10 * d05
        + a09 * d06
        + a08 * d07
    c04 = a11 * d05
        + a10 * d06
        + a09 * d07
        + a08 * a08
    c05 = a11 * d06
        + a10 * d07
        + a09 * d08
    c06 = a11 * d07
        + a10 * d08
        + a09 * a09
    c07 = a11 * d08
        + a10 * d09
    c08 = a11 * d09
        + a10 * a10
    c09 = a11 * d10
    c10 = a11 * a11

    -- Multiply low half with reduction into c00..c11.
    c00 = c00 * (19 / 2 ^ 255)
        + a00 * a00
    c01 = c01 * (19 / 2 ^ 255)
        + a01 * d00
    c02 = c02 * (19 / 2 ^ 255)
        + a02 * d00
        + a01 * a01
    c03 = c03 * (19 / 2 ^ 255)
        + a03 * d00
        + a02 * d01
    c04 = c04 * (19 / 2 ^ 255)
        + a04 * d00
        + a03 * d01
        + a02 * a02
    c05 = c05 * (19 / 2 ^ 255)
        + a05 * d00
        + a04 * d01
        + a03 * d02
    c06 = c06 * (19 / 2 ^ 255)
        + a06 * d00
        + a05 * d01
        + a04 * d02
        + a03 * a03
    c07 = c07 * (19 / 2 ^ 255)
        + a07 * d00
        + a06 * d01
        + a05 * d02
        + a04 * d03
    c08 = c08 * (19 / 2 ^ 255)
        + a08 * d00
        + a07 * d01
        + a06 * d02
        + a05 * d03
        + a04 * a04
    c09 = c09 * (19 / 2 ^ 255)
        + a09 * d00
        + a08 * d01
        + a07 * d02
        + a06 * d03
        + a05 * d04
    c10 = c10 * (19 / 2 ^ 255)
        + a10 * d00
        + a09 * d01
        + a08 * d02
        + a07 * d03
        + a06 * d04
        + a05 * a05
    c11 = a11 * d00
        + a10 * d01
        + a09 * d02
        + a08 * d03
        + a07 * d04
        + a06 * d05

    -- Carry and reduce.
    a10 = c10 + 3 * 2 ^ 285 - 3 * 2 ^ 285  c11 = c11 + a10
    a11 = c11 + 3 * 2 ^ 306 - 3 * 2 ^ 306  c00 = c00 + 19 / 2 ^ 255 * a11

    a00 = c00 + 3 * 2 ^ 73  - 3 * 2 ^ 73   c01 = c01 + a00
    a01 = c01 + 3 * 2 ^ 94  - 3 * 2 ^ 94   c02 = c02 + a01
    a02 = c02 + 3 * 2 ^ 115 - 3 * 2 ^ 115  c03 = c03 + a02
    a03 = c03 + 3 * 2 ^ 136 - 3 * 2 ^ 136  c04 = c04 + a03
    a04 = c04 + 3 * 2 ^ 158 - 3 * 2 ^ 158  c05 = c05 + a04
    a05 = c05 + 3 * 2 ^ 179 - 3 * 2 ^ 179  c06 = c06 + a05
    a06 = c06 + 3 * 2 ^ 200 - 3 * 2 ^ 200  c07 = c07 + a06
    a07 = c07 + 3 * 2 ^ 221 - 3 * 2 ^ 221  c08 = c08 + a07
    a08 = c08 + 3 * 2 ^ 243 - 3 * 2 ^ 243  c09 = c09 + a08
    a09 = c09 + 3 * 2 ^ 264 - 3 * 2 ^ 264  c10 = c10 - a10 + a09
    a10 = c10 + 3 * 2 ^ 285 - 3 * 2 ^ 285  c11 = c11 - a11 + a10

    a11 = c11 + 3 * 2 ^ 306 - 3 * 2 ^ 306

    return {
        c00 - a00 + 19 / 2 ^ 255 * a11,
        c01 - a01,
        c02 - a02,
        c03 - a03,
        c04 - a04,
        c05 - a05,
        c06 - a06,
        c07 - a07,
        c08 - a08,
        c09 - a09,
        c10 - a10,
        c11 - a11,
    }
end

--- Multiplies an element by a number.
--- @param a FpR2
--- @param k number A number in [0..2²²).
--- @return FpR1 c An element such that c ≡ a × k (mod p).
local function kmul(a, k)
    local a00, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10, a11 = unpack(a)
    local c00, c01, c02, c03, c04, c05, c06, c07, c08, c09, c10, c11

    -- TODO Range check.
    a00 = a00 * k
    a01 = a01 * k
    a02 = a02 * k
    a03 = a03 * k
    a04 = a04 * k
    a05 = a05 * k
    a06 = a06 * k
    a07 = a07 * k
    a08 = a08 * k
    a09 = a09 * k
    a10 = a10 * k
    a11 = a11 * k

    c11 = a11 + 3 * 2 ^ 306 - 3 * 2 ^ 306  a00 = a00 + 19 / 2 ^ 255 * c11

    c00 = a00 + 3 * 2 ^ 73  - 3 * 2 ^ 73   a01 = a01 + c00
    c01 = a01 + 3 * 2 ^ 94  - 3 * 2 ^ 94   a02 = a02 + c01
    c02 = a02 + 3 * 2 ^ 115 - 3 * 2 ^ 115  a03 = a03 + c02
    c03 = a03 + 3 * 2 ^ 136 - 3 * 2 ^ 136  a04 = a04 + c03
    c04 = a04 + 3 * 2 ^ 158 - 3 * 2 ^ 158  a05 = a05 + c04
    c05 = a05 + 3 * 2 ^ 179 - 3 * 2 ^ 179  a06 = a06 + c05
    c06 = a06 + 3 * 2 ^ 200 - 3 * 2 ^ 200  a07 = a07 + c06
    c07 = a07 + 3 * 2 ^ 221 - 3 * 2 ^ 221  a08 = a08 + c07
    c08 = a08 + 3 * 2 ^ 243 - 3 * 2 ^ 243  a09 = a09 + c08
    c09 = a09 + 3 * 2 ^ 264 - 3 * 2 ^ 264  a10 = a10 + c09
    c10 = a10 + 3 * 2 ^ 285 - 3 * 2 ^ 285  a11 = a11 - c11 + c10

    c11 = a11 + 3 * 2 ^ 306 - 3 * 2 ^ 306

    return {
        a00 - c00 + 19 / 2 ^ 255 * c11,
        a01 - c01,
        a02 - c02,
        a03 - c03,
        a04 - c04,
        a05 - c05,
        a06 - c06,
        a07 - c07,
        a08 - c08,
        a09 - c09,
        a10 - c10,
        a11 - c11
    }
end

--- Squares an element n times.
--- @param a FpR2
--- @param n number The number of times to square a.
--- @return FpR1 c A number c such that c ≡ a ^ 2 ^ n (mod p).
local function nsquare(a, n)
    for _ = 1, n do a = square(a) end
    return a
end

--- Computes the inverse of an element.
---
--- Performance: 11 multiplications and 252 squarings.
---
--- @param a FpR2
--- @return FpR1 c An element such that c ≡ a⁻¹ (mod p), or 0 if c doesn't exist.
local function invert(a)
    local a2 = square(a)
    local a9 = mul(a, nsquare(a2, 2))
    local a11 = mul(a9, a2)

    local x5 = mul(square(a11), a9)
    local x10 = mul(nsquare(x5, 5), x5)
    local x20 = mul(nsquare(x10, 10), x10)
    local x40 = mul(nsquare(x20, 20), x20)
    local x50 = mul(nsquare(x40, 10), x10)
    local x100 = mul(nsquare(x50, 50), x50)
    local x200 = mul(nsquare(x100, 100), x100)
    local x250 = mul(nsquare(x200, 50), x50)

    return mul(nsquare(x250, 5), a11)
end

--- Returns an element x that satisfies vx² = u.
---
--- Note that when v = 0, the returned element can take any value.
---
--- @param u FpR2
--- @param v FpR2
--- @return FpR1? x An element such that vx² ≡ u (mod p), if it exists.
local function sqrtDiv(u, v)
    u = carry(u)

    local v2 = square(v)
    local v3 = mul(v, v2)
    local v6 = square(v3)
    local v7 = mul(v, v6)
    local uv7 = mul(u, v7)

    local x2 = mul(square(uv7), uv7)
    local x4 = mul(nsquare(x2, 2), x2)
    local x8 = mul(nsquare(x4, 4), x4)
    local x16 = mul(nsquare(x8, 8), x8)
    local x18 = mul(nsquare(x16, 2), x2)
    local x32 = mul(nsquare(x16, 16), x16)
    local x50 = mul(nsquare(x32, 18), x18)
    local x100 = mul(nsquare(x50, 50), x50)
    local x200 = mul(nsquare(x100, 100), x100)
    local x250 = mul(nsquare(x200, 50), x50)
    local pr = mul(nsquare(x250, 2), uv7)

    local uv3 = mul(u, v3)
    local b = mul(uv3, pr)
    local b2 = square(b)
    local vb2 = mul(v, b2)

    if not eq(vb2, u) then
        -- Found sqrt(-u/v), multiply by i.
        b = mul(b, I)
        b2 = square(b)
        vb2 = mul(v, b2)
    end

    if eq(vb2, u) then
        return b
    else
        return nil
    end
end

--- @class String32: string A string with length equal to 32 bytes.

--- Encodes an element in little-endian.
--- @param a FpR1
--- @return String32 out The 32-byte canonical encoding of a.
local function encode(a)
    a = canonicalize(a)
    local a00, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10, a11 = unpack(a)

    local bytes = {}
    local acc = a00

    local function putBytes(n)
        for _ = 1, n do
            local byte = acc % 256
            bytes[#bytes + 1] = byte
            acc = (acc - byte) / 256
        end
    end

    putBytes(2) acc = acc + a01 / 2 ^ 16
    putBytes(3) acc = acc + a02 / 2 ^ 40
    putBytes(3) acc = acc + a03 / 2 ^ 64
    putBytes(2) acc = acc + a04 / 2 ^ 80
    putBytes(3) acc = acc + a05 / 2 ^ 104
    putBytes(3) acc = acc + a06 / 2 ^ 128
    putBytes(2) acc = acc + a07 / 2 ^ 144
    putBytes(3) acc = acc + a08 / 2 ^ 168
    putBytes(3) acc = acc + a09 / 2 ^ 192
    putBytes(2) acc = acc + a10 / 2 ^ 208
    putBytes(3) acc = acc + a11 / 2 ^ 232
    putBytes(3)

    return string.char(unpack(bytes)) --[[@as String32, putBytes sums to 32]]
end

--- Decodes an element in little-endian.
--- @param b String32 A 32-byte string, the most-significant bit is discarded.
--- @return FpR1 out The decoded element. It may not be canonical.
local function decode(b)
    local w00, w01, w02, w03, w04, w05, w06, w07, w08, w09, w10, w11 =
        ufp(fmtfp, b, 1)

    w11 = w11 % 2 ^ 15

    return carry {
        w00,
        w01 * 2 ^ 24,
        w02 * 2 ^ 48,
        w03 * 2 ^ 64,
        w04 * 2 ^ 88,
        w05 * 2 ^ 112,
        w06 * 2 ^ 128,
        w07 * 2 ^ 152,
        w08 * 2 ^ 176,
        w09 * 2 ^ 192,
        w10 * 2 ^ 216,
        w11 * 2 ^ 240,
    }
end

--- Checks if the given element is equal to 0.
--- @param a FpR2
--- @return boolean eqz Whether a ≡ 0 (mod p).
local function eqz(a)
    local c = canonicalize(a)
    local c00, c01, c02, c03, c04, c05, c06, c07, c08, c09, c10, c11 = unpack(c)
    return c00 + c01 + c02 + c03 + c04 + c05 + c06 + c07 + c08 + c09 + c10 + c11
        == 0
end

return {
    num = num,
    neg = neg,
    add = add,
    sub = sub,
    kmul = kmul,
    mul = mul,
    canonicalize = canonicalize,
    square = square,
    carry = carry,
    invert = invert,
    sqrtDiv = sqrtDiv,
    encode = encode,
    decode = decode,
    eqz = eqz,
}

end

loaders['ccryptolib.internal.fq']=function()
--- Arithmetic on Curve25519's scalar field.

local mp = require "ccryptolib.internal.mp"
local util = require "ccryptolib.internal.util"
local packing = require "ccryptolib.internal.packing"

local unpack = unpack or table.unpack
local pfq, fmtfq = packing.compilePack("<I3I3I3I3I3I3I3I3I3I3I2")
local ufq = packing.compileUnpack(fmtfq)
local ufql, fmtfql = packing.compileUnpack("<I3I3I3I3I3I3I3I3I3I3I3")
local ufqh, fmtfqh = packing.compileUnpack("<I3I3I3I3I3I3I3I3I3I3I1")

--- The scalar field's order, q = 2²⁵² + 27742317777372353535851937790883648493.
local Q = {
    16110573,
    06494812,
    14047250,
    10680220,
    14612958,
    00000020,
    00000000,
    00000000,
    00000000,
    00000000,
    00004096,
}

--- The first Montgomery precomputed constant, -q⁻¹ mod 2²⁶⁴.
local T0 = {
    05537307,
    01942290,
    16765621,
    16628356,
    10618610,
    07072433,
    03735459,
    01369940,
    15276086,
    13038191,
    13409718,
}

--- The second Montgomery precomputed constant, 2⁵²⁸ mod q.
local T1 = {
    11711996,
    01747860,
    08326961,
    03814718,
    01859974,
    13327461,
    16105061,
    07590423,
    04050668,
    08138906,
    00000283,
}

local T8 = {
    5110253,
    3039345,
    2503500,
    11779568,
    15416472,
    16766550,
    16777215,
    16777215,
    16777215,
    16777215,
    4095,
}

local ZERO = mp.num(0)

--- Reduces a number modulo q.
--
-- @tparam {number...} a A number a < 2q as 11 limbs in [0..2²⁵).
-- @treturn {number...} a mod q as 11 limbs in [0..2²⁴).
--
local function reduce(a)
    local c = mp.sub(a, Q)

    -- Return carry(a) if a < q.
    if mp.approx(c) < 0 then return (mp.carry(a)) end

    -- c >= q means c - q >= 0.
    -- Since q < 2²⁸⁸, c < 2q means c - q < q < 2²⁸⁸.
    -- c's limbs fit in (-2²⁶..2²⁶), since subtraction adds at most one bit.
    return (mp.carry(c)) -- cc < q implies that the carry number is 0.
end

--- Adds two scalars mod q.
--
-- If the two operands are in Montgomery form, returns the correct result also
-- in Montgomery form, since (2²⁶⁴ × a) + (2²⁶⁴ × b) ≡ 2²⁶⁴ × (a + b) (mod q).
--
-- @tparam {number...} a A number a < q as 11 limbs in [0..2²⁴).
-- @tparam {number...} b A number b < q as 11 limbs in [0..2²⁴).
-- @treturn {number...} a + b mod q as 11 limbs in [0..2²⁴).
--
local function add(a, b)
    return reduce(mp.add(a, b))
end

--- Negates a scalar mod q.
--
-- @tparam {number...} a A number a < q as 11 limbs in [0..2²⁴).
-- @treturn {number...} -a mod q as 11 limbs in [0..2²⁴).
--
local function neg(a)
    return reduce(mp.sub(Q, a))
end

--- Subtracts scalars mod q.
--
-- If the two operands are in Montgomery form, returns the correct result also
-- in Montgomery form, since (2²⁶⁴ × a) - (2²⁶⁴ × b) ≡ 2²⁶⁴ × (a - b) (mod q).
--
-- @tparam {number...} a A number a < q as 11 limbs in [0..2²⁴).
-- @tparam {number...} b A number b < q as 11 limbs in [0..2²⁴).
-- @treturn {number...} a - b mod q as 11 limbs in [0..2²⁴).
--
local function sub(a, b)
    return add(a, neg(b))
end

--- Given two scalars a and b, computes 2⁻²⁶⁴ × a × b mod q.
--
-- @tparam {number...} a A number a as 11 limbs in [0..2²⁴).
-- @tparam {number...} b A number b < q as 11 limbs in [0..2²⁴).
-- @treturn {number...} 2⁻²⁶⁴ × a × b mod q as 11 limbs in [0..2²⁴).
--
local function mul(a, b)
    local t0, t1 = mp.mul(a, b)
    local mq0, mq1 = mp.mul(mp.lmul(t0, T0), Q)
    local _, s1 = mp.dwadd(t0, t1, mq0, mq1)
    return reduce(s1)
end

--- Converts a scalar into Montgomery form.
--
-- @tparam {number...} a A number a as 11 limbs in [0..2²⁴).
-- @treturn {number...} 2²⁶⁴ × a mod q as 11 limbs in [0..2²⁴).
--
local function montgomery(a)
    -- 0 ≤ a < 2²⁶⁴ and 0 ≤ T1 < q.
    return mul(a, T1)
end

--- Converts a scalar from Montgomery form.
--
-- @tparam {number...} a A number a < q as 11 limbs in [0..2²⁴).
-- @treturn {number...} 2⁻²⁶⁴ × a mod q as 11 limbs in [0..2²⁴).
--
local function demontgomery(a)
    -- It's REDC all over again except b is 1.
    local mq0, mq1 = mp.mul(mp.lmul(a, T0), Q)
    local _, s1 = mp.dwadd(a, ZERO, mq0, mq1)
    return reduce(s1)
end

--- Encodes a scalar.
--
-- @tparam {number...} a A number 2²⁶⁴ × a mod q as 11 limbs in [0..2²⁴).
-- @treturn string The 32-byte string encoding of a.
--
local function encode(a)
    return pfq(fmtfq, unpack(demontgomery(a)))
end

--- Decodes a scalar.
--
-- @tparam string str A 32-byte string encoding some little-endian number a.
-- @treturn {number...} 2²⁶⁴ × a mod q as 11 limbs in [0..2²⁴).
--
local function decode(str)
    local dec = {ufq(fmtfq, str, 1)} dec[12] = nil
    return montgomery(dec)
end

--- Decodes a scalar from a "wide" string.
--
-- @tparam string str A 64-byte string encoding some little-endian number a.
-- @treturn {number...} 2²⁶⁴ × a mod q as 11 limbs in [0..2²⁴).
--
local function decodeWide(str)
    local low = {ufql(fmtfql, str, 1)} low[12] = nil
    local high = {ufqh(fmtfqh, str, 34)} high[12] = nil
    return add(montgomery(low), montgomery(montgomery(high)))
end

--- Decodes a scalar using the X25519/Ed25519 bit clamping scheme.
--
-- @tparam string str A 32-byte string encoding some little-endian number a.
-- @treturn {number...} 2²⁶⁴ × clamp(a) mod q as 11 limbs in [0..2²⁴).
--
local function decodeClamped(str)
    -- Decode.
    local words = {ufq(fmtfq, str, 1)} words[12] = nil

    -- Clamp.
    words[1] = bit32.band(words[1], 0xfffff8)
    words[11] = bit32.band(words[11], 0x7fff)
    words[11] = bit32.bor(words[11], 0x4000)

    return montgomery(words)
end

--- Divides a scalar by 8.
--
-- @tparam {number...} 2²⁶⁴ × a mod q as 11 limbs in [0..2²⁴).
-- @treturn {number...} 2²⁶⁵ × a ÷ 8 mod q as 11 limbs in [0..2²⁴).
local function eighth(a)
    return mul(a, T8)
end

--- Returns a scalar in binary.
--
-- @tparam {number...} a A number a < q as 11 limbs in [0..2²⁴).
-- @treturn {number...} 2⁻²⁶⁴ × a mod q as 253 bits.
--
local function bits(a)
    local out = util.rebaseLE(demontgomery(a), 2 ^ 24, 2)
    for i = 254, 289 do out[i] = nil end
    return out
end

--- Makes a PRAC ruleset from a pair of scalars.
--
-- For more information see section 3.3 of Speeding up subgroup cryptosystems:
-- Martijn Stam. Speeding up subgroup cryptosystems. PhD thesis, Technische
-- Universiteit Eindhoven, 2003. https://dx.doi.org/10.6100/IR564670.
--
-- @tparam {number...} a A scalar 2²⁶⁴ × a mod q as 11 limbs in [0..2²⁴).
-- @tparam {number...} b A scalar 2²⁶⁴ × b mod q as 11 limbs in [0..2²⁴).
-- @treturn {{number...}, {number...}} The generated ruleset.
--
local function makeRuleset(a, b)
    -- The numbers in raw multiprecision tables.
    local dt = demontgomery(a) -- (-2²⁴..2²⁴)
    local et = demontgomery(b) -- (-2²⁴..2²⁴)
    local ft = mp.sub(dt, et)  -- (-2²⁵..2²⁵)

    -- Residue classes of (d, e) modulo 2.
    local d2 = mp.mod2(dt)
    local e2 = mp.mod2(et)

    -- Residue classes of (d, e) modulo 3.
    local d3 = mp.mod3(dt)
    local e3 = mp.mod3(et)

    -- (e, d - e) in limited-precision floating-point numbers.
    local ef = mp.approx(et)
    local ff = mp.approx(ft)

    -- Lookup table for inversions and halvings modulo 3.
    local lut3 = {[0] = 0, 2, 1}

    local rules = {}
    while ff ~= 0 do
        if ff < 0 then
            -- M0. d < e
            rules[#rules + 1] = 0
            -- (d, e) ← (e, d)
            dt, et = et, dt
            d2, e2 = e2, d2
            d3, e3 = e3, d3
            ef = mp.approx(et)
            ft = mp.sub(dt, et)
            ff = -ff
        elseif 4 * ff < ef and d3 == lut3[e3] then
            -- M1. e < d ≤ 5/4 e, d ≡ -e (mod 3)
            rules[#rules + 1] = 1
            -- (d, e) ← ((2d - e)/3, (2e - d)/3)
            dt, et = mp.third(mp.add(dt, ft)), mp.third(mp.sub(et, ft))
            d2, e2 = e2, d2
            d3, e3 = mp.mod3(dt), mp.mod3(et)
            ef = mp.approx(et)
        elseif 4 * ff < ef and d2 == e2 and d3 == e3 then
            -- M2. e < d ≤ 5/4 e, d ≡ e (mod 6)
            rules[#rules + 1] = 2
            -- (d, e) ← ((d - e)/2, e)
            dt = mp.half(ft)
            d2 = mp.mod2(dt)
            d3 = lut3[(d3 - e3) % 3]
            ft = mp.sub(dt, et)
            ff = mp.approx(ft)
        elseif ff < 3 * ef then
            -- M3. d ≤ 4e
            rules[#rules + 1] = 3
            -- (d, e) ← (d - e, e)
            dt = mp.carryWeak(ft)
            d2 = (d2 - e2) % 2
            d3 = (d3 - e3) % 3
            ft = mp.sub(dt, et)
            ff = mp.approx(ft)
        elseif d2 == e2 then
            -- M4. d ≡ e (mod 2)
            rules[#rules + 1] = 2
            -- (d, e) ← ((d - e)/2, e)
            dt = mp.half(ft)
            d2 = mp.mod2(dt)
            d3 = lut3[(d3 - e3) % 3]
            ft = mp.sub(dt, et)
            ff = mp.approx(ft)
        elseif d2 == 0 then
            -- M5. d ≡ 0 (mod 2)
            rules[#rules + 1] = 5
            -- (d, e) ← (d/2, e)
            dt = mp.half(dt)
            d2 = mp.mod2(dt)
            d3 = lut3[d3]
            ft = mp.sub(dt, et)
            ff = mp.approx(ft)
        elseif d3 == 0 then
            -- M6. d ≡ 0 (mod 3)
            rules[#rules + 1] = 6
            -- (d, e) ← (d/3 - e, e)
            dt = mp.carryWeak(mp.sub(mp.third(dt), et))
            d2 = (d2 - e2) % 2
            d3 = mp.mod3(dt)
            ft = mp.sub(dt, et)
            ff = mp.approx(ft)
        elseif d3 == lut3[e3] then
            -- M7. d ≡ -e (mod 3)
            rules[#rules + 1] = 7
            -- (d, e) ← ((d - 2e)/3, e)
            dt = mp.third(mp.sub(ft, et))
            d3 = mp.mod3(dt)
            ft = mp.sub(dt, et)
            ff = mp.approx(ft)
        elseif d3 == e3 then
            -- M8. d ≡ e (mod 3)
            rules[#rules + 1] = 8
            -- (d, e) ← ((d - e)/3, e)
            dt = mp.third(ft)
            d2 = (d2 - e2) % 2
            d3 = mp.mod3(dt)
            ft = mp.sub(dt, et)
            ff = mp.approx(ft)
        else
            -- M9. e ≡ 0 (mod 2)
            rules[#rules + 1] = 9
            -- (d, e) ← (d, e/2)
            et = mp.half(et)
            e2 = mp.mod2(et)
            e3 = lut3[e3]
            ef = mp.approx(et)
            ft = mp.sub(dt, et)
            ff = mp.approx(ft)
        end
    end

    local ubits = util.rebaseLE(dt, 2 ^ 24, 2)
    while ubits[#ubits] == 0 do ubits[#ubits] = nil end

    return {ubits, rules}
end

return {
    add = add,
    sub = sub,
    mul = mul,
    encode = encode,
    decode = decode,
    decodeWide = decodeWide,
    decodeClamped = decodeClamped,
    eighth = eighth,
    bits = bits,
    makeRuleset = makeRuleset,
}

end

loaders['ccryptolib.internal.sha512']=function()
--- The SHA512 cryptographic hash function.

local expect  = require "cc.expect".expect
local packing = require "ccryptolib.internal.packing"

local shl = bit32.lshift
local shr = bit32.rshift
local bxor = bit32.bxor
local bnot = bit32.bnot
local band = bit32.band
local p1x16, fmt1x16 = packing.compilePack(">I16")
local p16x4, fmt16x4 = packing.compilePack(">I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4")
local u32x4, fmt32x4 = packing.compileUnpack(">I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4")

local function carry64(a1, a0)
    local r0 = a0 % 2 ^ 32
    a1 = a1 + (a0 - r0) / 2 ^ 32
    return a1 % 2 ^ 32, r0
end

local K = {
    0x428a2f98, 0xd728ae22, 0x71374491, 0x23ef65cd, 0xb5c0fbcf, 0xec4d3b2f,
    0xe9b5dba5, 0x8189dbbc, 0x3956c25b, 0xf348b538, 0x59f111f1, 0xb605d019,
    0x923f82a4, 0xaf194f9b, 0xab1c5ed5, 0xda6d8118, 0xd807aa98, 0xa3030242,
    0x12835b01, 0x45706fbe, 0x243185be, 0x4ee4b28c, 0x550c7dc3, 0xd5ffb4e2,
    0x72be5d74, 0xf27b896f, 0x80deb1fe, 0x3b1696b1, 0x9bdc06a7, 0x25c71235,
    0xc19bf174, 0xcf692694, 0xe49b69c1, 0x9ef14ad2, 0xefbe4786, 0x384f25e3,
    0x0fc19dc6, 0x8b8cd5b5, 0x240ca1cc, 0x77ac9c65, 0x2de92c6f, 0x592b0275,
    0x4a7484aa, 0x6ea6e483, 0x5cb0a9dc, 0xbd41fbd4, 0x76f988da, 0x831153b5,
    0x983e5152, 0xee66dfab, 0xa831c66d, 0x2db43210, 0xb00327c8, 0x98fb213f,
    0xbf597fc7, 0xbeef0ee4, 0xc6e00bf3, 0x3da88fc2, 0xd5a79147, 0x930aa725,
    0x06ca6351, 0xe003826f, 0x14292967, 0x0a0e6e70, 0x27b70a85, 0x46d22ffc,
    0x2e1b2138, 0x5c26c926, 0x4d2c6dfc, 0x5ac42aed, 0x53380d13, 0x9d95b3df,
    0x650a7354, 0x8baf63de, 0x766a0abb, 0x3c77b2a8, 0x81c2c92e, 0x47edaee6,
    0x92722c85, 0x1482353b, 0xa2bfe8a1, 0x4cf10364, 0xa81a664b, 0xbc423001,
    0xc24b8b70, 0xd0f89791, 0xc76c51a3, 0x0654be30, 0xd192e819, 0xd6ef5218,
    0xd6990624, 0x5565a910, 0xf40e3585, 0x5771202a, 0x106aa070, 0x32bbd1b8,
    0x19a4c116, 0xb8d2d0c8, 0x1e376c08, 0x5141ab53, 0x2748774c, 0xdf8eeb99,
    0x34b0bcb5, 0xe19b48a8, 0x391c0cb3, 0xc5c95a63, 0x4ed8aa4a, 0xe3418acb,
    0x5b9cca4f, 0x7763e373, 0x682e6ff3, 0xd6b2b8a3, 0x748f82ee, 0x5defb2fc,
    0x78a5636f, 0x43172f60, 0x84c87814, 0xa1f0ab72, 0x8cc70208, 0x1a6439ec,
    0x90befffa, 0x23631e28, 0xa4506ceb, 0xde82bde9, 0xbef9a3f7, 0xb2c67915,
    0xc67178f2, 0xe372532b, 0xca273ece, 0xea26619c, 0xd186b8c7, 0x21c0c207,
    0xeada7dd6, 0xcde0eb1e, 0xf57d4f7f, 0xee6ed178, 0x06f067aa, 0x72176fba,
    0x0a637dc5, 0xa2c898a6, 0x113f9804, 0xbef90dae, 0x1b710b35, 0x131c471b,
    0x28db77f5, 0x23047d84, 0x32caab7b, 0x40c72493, 0x3c9ebe0a, 0x15c9bebc,
    0x431d67c4, 0x9c100d4c, 0x4cc5d4be, 0xcb3e42b6, 0x597f299c, 0xfc657e2a,
    0x5fcb6fab, 0x3ad6faec, 0x6c44198c, 0x4a475817,
}

--- Hashes data bytes using SHA512.
--- @param data string The input data.
--- @return string hash The 64-byte hash value.
local function digest(data)
    expect(1, data, "string")

    -- Pad input.
    local bitlen = #data * 8
    local padlen = -(#data + 17) % 128
    data = data .. "\128" .. ("\0"):rep(padlen) .. p1x16(fmt1x16, bitlen)

    -- Initialize state.
    local h01, h00 = 0x6a09e667, 0xf3bcc908
    local h11, h10 = 0xbb67ae85, 0x84caa73b
    local h21, h20 = 0x3c6ef372, 0xfe94f82b
    local h31, h30 = 0xa54ff53a, 0x5f1d36f1
    local h41, h40 = 0x510e527f, 0xade682d1
    local h51, h50 = 0x9b05688c, 0x2b3e6c1f
    local h61, h60 = 0x1f83d9ab, 0xfb41bd6b
    local h71, h70 = 0x5be0cd19, 0x137e2179

    -- Digest.
    for i = 1, #data, 128 do
        RecoveryCheckpoint()
        local w = {u32x4(fmt32x4, data, i)}

        -- Message schedule.
        for j = 33, 160, 2 do
            local wf1, wf0 = w[j - 30], w[j - 29]
            local t1 = shr(wf1, 1) + shl(wf0, 31)
            local t0 = shr(wf0, 1) + shl(wf1, 31)
            local u1 = shr(wf1, 8) + shl(wf0, 24)
            local u0 = shr(wf0, 8) + shl(wf1, 24)
            local v1 = shr(wf1, 7)
            local v0 = shr(wf0, 7) + shl(wf1, 25)

            local w21, w20 = w[j - 4], w[j - 3]
            local w1 = shr(w21, 19) + shl(w20, 13)
            local w0 = shr(w20, 19) + shl(w21, 13)
            local x0 = shr(w21, 29) + shl(w20, 3)
            local x1 = shr(w20, 29) + shl(w21, 3)
            local y1 = shr(w21, 6)
            local y0 = shr(w20, 6) + shl(w21, 26)

            local r1, r0 =
                w[j - 32] + bxor(t1, u1, v1) + w[j - 14] + bxor(w1, x1, y1),
                w[j - 31] + bxor(t0, u0, v0) + w[j - 13] + bxor(w0, x0, y0)

            w[j], w[j + 1] = carry64(r1, r0)
        end

        -- Block function.
        local a1, a0 = h01, h00
        local b1, b0 = h11, h10
        local c1, c0 = h21, h20
        local d1, d0 = h31, h30
        local e1, e0 = h41, h40
        local f1, f0 = h51, h50
        local g1, g0 = h61, h60
        local h1, h0 = h71, h70
        for j = 1, 160, 2 do
            local t1 = shr(e1, 14) + shl(e0, 18)
            local t0 = shr(e0, 14) + shl(e1, 18)
            local u1 = shr(e1, 18) + shl(e0, 14)
            local u0 = shr(e0, 18) + shl(e1, 14)
            local v0 = shr(e1, 9) + shl(e0, 23)
            local v1 = shr(e0, 9) + shl(e1, 23)
            local s11 = bxor(t1, u1, v1)
            local s10 = bxor(t0, u0, v0)

            local ch1 = bxor(band(e1, f1), band(bnot(e1), g1))
            local ch0 = bxor(band(e0, f0), band(bnot(e0), g0))

            local temp11 = h1 + s11 + ch1 + K[j] + w[j]
            local temp10 = h0 + s10 + ch0 + K[j + 1] + w[j + 1]

            local w1 = shr(a1, 28) + shl(a0, 4)
            local w0 = shr(a0, 28) + shl(a1, 4)
            local x0 = shr(a1, 2) + shl(a0, 30)
            local x1 = shr(a0, 2) + shl(a1, 30)
            local y0 = shr(a1, 7) + shl(a0, 25)
            local y1 = shr(a0, 7) + shl(a1, 25)
            local s01 = bxor(w1, x1, y1)
            local s00 = bxor(w0, x0, y0)

            local maj1 = bxor(band(a1, b1), band(a1, c1), band(b1, c1))
            local maj0 = bxor(band(a0, b0), band(a0, c0), band(b0, c0))

            local temp21 = s01 + maj1
            local temp20 = s00 + maj0

            h1 = g1  h0 = g0
            g1 = f1  g0 = f0
            f1 = e1  f0 = e0
            e1, e0 = carry64(d1 + temp11, d0 + temp10)
            d1 = c1  d0 = c0
            c1 = b1  c0 = b0
            b1 = a1  b0 = a0
            a1, a0 = carry64(temp11 + temp21, temp10 + temp20)
        end

        h01, h00 = carry64(h01 + a1, h00 + a0)
        h11, h10 = carry64(h11 + b1, h10 + b0)
        h21, h20 = carry64(h21 + c1, h20 + c0)
        h31, h30 = carry64(h31 + d1, h30 + d0)
        h41, h40 = carry64(h41 + e1, h40 + e0)
        h51, h50 = carry64(h51 + f1, h50 + f0)
        h61, h60 = carry64(h61 + g1, h60 + g0)
        h71, h70 = carry64(h71 + h1, h70 + h0)
    end

    return p16x4(fmt16x4,
        h01, h00, h11, h10, h21, h20, h31, h30,
        h41, h40, h51, h50, h61, h60, h71, h70
    )
end

return {
    digest = digest,
}

end

loaders['ccryptolib.internal.edwards25519']=function()
--- Point arithmetic on the Edwards25519 Edwards curve.

local fp = require "ccryptolib.internal.fp"

local unpack = unpack or table.unpack

--- @class EdPoint A point on Edwards25519, in extended coordinates.
--- @field [1] number[] The X coordinate.
--- @field [2] number[] The Y coordinate.
--- @field [3] number[] The Z coordinate.
--- @field [4] number[] The T coordinate.

--- @class NsPoint A point on Edwards25519, in Niels' coordinates.
--- @field [1] number[] Preprocessed Y + X.
--- @field [2] number[] Preprocessed Y - X.
--- @field [3] number[] Preprocessed 2Z.
--- @field [4] number[] Preprocessed 2DT.

local D = fp.mul(fp.num(-121665), fp.invert(fp.num(121666)))
local K = fp.kmul(D, 2)

--- @type EdPoint
local O = {fp.num(0), fp.num(1), fp.num(1), fp.num(0)}
local G = nil

--- Doubles a point.
--- @param P1 EdPoint The point to double.
--- @return EdPoint P2 P1 + P1.
local function double(P1)
    -- Unsoundness: fp.sub(g, e), and fp.sub(d, i) break fp.sub's contract since
    -- it doesn't accept an fp2. Although not ideal, in practice this doesn't
    -- matter since fp.carry handles the larger sum.
    local P1x, P1y, P1z = unpack(P1)
    local a = fp.square(P1x)
    local b = fp.square(P1y)
    local c = fp.square(P1z)
    local d = fp.add(c, c)
    local e = fp.add(a, b)
    local f = fp.add(P1x, P1y)
    local g = fp.square(f)
    local h = fp.carry(fp.sub(g, e))
    local i = fp.sub(b, a)
    local j = fp.carry(fp.sub(d, i))
    local P3x = fp.mul(h, j)
    local P3y = fp.mul(i, e)
    local P3z = fp.mul(j, i)
    local P3t = fp.mul(h, e)
    return {P3x, P3y, P3z, P3t}
end

--- Adds two points.
--- @param P1 EdPoint The first summand point.
--- @param N2 NsPoint The second summand point.
--- @return EdPoint P3 P1 + P2, where N2 = niels(P2).
local function add(P1, N2)
    local P1x, P1y, P1z, P1t = unpack(P1)
    local N1p, N1m, N1z, N1t = unpack(N2)
    local a = fp.sub(P1y, P1x)
    local b = fp.mul(a, N1m)
    local c = fp.add(P1y, P1x)
    local d = fp.mul(c, N1p)
    local e = fp.mul(P1t, N1t)
    local f = fp.mul(P1z, N1z)
    local g = fp.sub(d, b)
    local h = fp.sub(f, e)
    local i = fp.add(f, e)
    local j = fp.add(d, b)
    local P3x = fp.mul(g, h)
    local P3y = fp.mul(i, j)
    local P3z = fp.mul(h, i)
    local P3t = fp.mul(g, j)
    return {P3x, P3y, P3z, P3t}
end

--- Subtracts one point from another.
--- @param P1 EdPoint The first summand point.
--- @param N2 NsPoint The second summand point.
--- @return EdPoint P3 P1 - P2, where N2 = niels(P2).
local function sub(P1, N2)
    local P1x, P1y, P1z, P1t = unpack(P1)
    local N1p, N1m, N1z, N1t = unpack(N2)
    local a = fp.sub(P1y, P1x)
    local b = fp.mul(a, N1p)
    local c = fp.add(P1y, P1x)
    local d = fp.mul(c, N1m)
    local e = fp.mul(P1t, N1t)
    local f = fp.mul(P1z, N1z)
    local g = fp.sub(d, b)
    local h = fp.add(f, e)
    local i = fp.sub(f, e)
    local j = fp.add(d, b)
    local P3x = fp.mul(g, h)
    local P3y = fp.mul(i, j)
    local P3z = fp.mul(h, i)
    local P3t = fp.mul(g, j)
    return {P3x, P3y, P3z, P3t}
end

--- Computes the Niels representation of a point.
--- @param P1 EdPoint The input point.
--- @return NsPoint N1 Niels' precomputation applied to P1.
local function niels(P1)
    local P1x, P1y, P1z, P1t = unpack(P1)
    local N3p = fp.add(P1y, P1x)
    local N3m = fp.sub(P1y, P1x)
    local N3z = fp.add(P1z, P1z)
    local N3t = fp.mul(P1t, K)
    return {N3p, N3m, N3z, N3t}
end

--- Scales a point.
--- @param P1 EdPoint The input point.
--- @return EdPoint P2 The same point as P1, but with Z = 1.
local function scale(P1)
    local P1x, P1y, P1z = unpack(P1)
    local zInv = fp.invert(P1z)
    local P3x = fp.mul(P1x, zInv)
    local P3y = fp.mul(P1y, zInv)
    local P3z = fp.num(1)
    local P3t = fp.mul(P3x, P3y)
    return {P3x, P3y, P3z, P3t}
end

--- Encodes a scaled point.
--- @param P1 EdPoint The scaled point to encode.
--- @return string out P1 encoded as a 32-byte string.
local function encode(P1)
    P1 = scale(P1)
    local P1x, P1y = unpack(P1)
    local y = fp.encode(P1y)
    local xBit = fp.canonicalize(P1x)[1] % 2
    return y:sub(1, -2) .. string.char(y:byte(-1) + xBit * 128)
end

--- Decodes a point.
--- @param str String32 A 32-byte encoded point.
--- @return EdPoint? P1 The decoded point, or nil if it isn't on the curve.
local function decode(str)
    local P3y = fp.decode(str)
    local a = fp.square(P3y)
    local b = fp.sub(a, fp.num(1))
    local c = fp.mul(a, D)
    local d = fp.add(c, fp.num(1))
    local P3x = fp.sqrtDiv(b, d)
    if not P3x then return nil end
    local xBit = fp.canonicalize(P3x)[1] % 2
    if xBit ~= bit32.extract(str:byte(-1), 7) then
        P3x = fp.carry(fp.neg(P3x))
    end
    local P3z = fp.num(1)
    local P3t = fp.mul(P3x, P3y)
    return {P3x, P3y, P3z, P3t}
end

G = decode("Xfffffffffffffffffffffffffffffff") --[[@as EdPoint, G is valid]]

--- Transforms little-endian bits into a signed radix-2^w form.
--- @param bits number[]
--- @param w number Log2 of the radix, must be at least 1.
--- @return number[]
local function signedRadixW(bits, w)
    -- TODO Find a more elegant way of doing this.
    local wPow = 2 ^ w
    local wPowh = wPow / 2
    local out = {}
    local acc = 0
    local mul = 1
    for i = 1, #bits do
        acc = acc + bits[i] * mul
        mul = mul * 2
        while i == #bits and acc > 0 or mul > wPow do
            local rem = acc % wPow
            if rem >= wPowh then rem = rem - wPow end
            acc = (acc - rem) / wPow
            mul = mul / wPow
            out[#out + 1] = rem
        end
    end
    return out
end

--- Computes a multiplication table for radix-2^w form multiplication.
--- @param P EdPoint The base point.
--- @param w number Log2 of the radix, must be at least 1.
--- @return NsPoint[][]
local function radixWTable(P, w)
    local out = {}
    for i = 1, math.ceil(256 / w) do
        local row = {niels(P)}
        for j = 2, 2 ^ w / 2 do
            P = add(P, row[1])
            row[j] = niels(P)
        end
        out[i] = row
        P = double(P)
    end
    return out
end

--- The radix logarithm of the precomputed table for G.
local G_W = 5

--- The precomputed multiplication table for G.
local G_TABLE = radixWTable(G, G_W)

--- Transforms little-endian bits into a signed radix-2^w non-adjacent form.
---
--- The returned array contains a 0 whenever a single doubling is needed, or an
--- odd integer when an addition with a multiple of the base is needed.
---
--- @param bits number[]
--- @param w number Log2 of the radix, must be at least 1.
--- @return number[]
local function wNaf(bits, w)
    -- TODO Find a more elegant way of doing this.
    local wPow = 2 ^ w
    local wPowh = wPow / 2
    local out = {}
    local acc = 0
    local mul = 1
    for i = 1, #bits do
        acc = acc + bits[i] * mul
        mul = mul * 2
        while i == #bits and acc > 0 or mul > wPow do
            if acc % 2 == 0 then
                acc = acc / 2
                mul = mul / 2
                out[#out + 1] = 0
            else
                local rem = acc % wPow
                if rem >= wPowh then rem = rem - wPow end
                acc = acc - rem
                out[#out + 1] = rem
            end
        end
    end
    while out[#out] == 0 do out[#out] = nil end
    return out
end

--- Computes a multiplication table for wNAF form multiplication.
--- @param P EdPoint The base point.
--- @param w number Log2 of the radix, must be at least 1.
--- @return NsPoint[]
local function WNAFTable(P, w)
    local dP = double(P)
    local out = {niels(P)}
    for i = 3, 2 ^ w, 2 do
        out[i] = niels(add(dP, out[i - 2]))
    end
    return out
end

--- Performs a scalar multiplication by the base point G.
--- @param bits number[] The scalar multiplicand little-endian bits.
--- @return EdPoint
local function mulG(bits)
    local sw = signedRadixW(bits, G_W)
    local R = O
    for i = 1, #sw do
        RecoveryCheckpoint()
        local b = sw[i]
        if b > 0 then
            R = add(R, G_TABLE[i][b])
        elseif b < 0 then
            R = sub(R, G_TABLE[i][-b])
        end
    end
    return R
end

--- Performs a scalar multiplication operation.
--- @param P EdPoint The base point.
--- @param bits number[] The scalar multiplicand little-endian bits.
--- @return EdPoint
local function mul(P, bits)
    local naf = wNaf(bits, 5)
    local tbl = WNAFTable(P, 5)
    local R = O
    for i = #naf, 1, -1 do
        RecoveryCheckpoint()
        local b = naf[i]
        if b == 0 then
            R = double(R)
        elseif b > 0 then
            R = add(R, tbl[b])
        else
            R = sub(R, tbl[-b])
        end
    end
    return R
end

return {
    double = double,
    add = add,
    sub = sub,
    niels = niels,
    scale = scale,
    encode = encode,
    decode = decode,
    mulG = mulG,
    mul = mul,
}

end


local fq=require('ccryptolib.internal.fq')
local ed=require('ccryptolib.internal.edwards25519')
local sha512=require('ccryptolib.internal.sha512')
local C={};ns.AetherCrypto=C
function C.RecoveryBudget(thread,deadline)recoveryDeadlines[thread]=deadline end
local function raw(h,n)if type(h)~='string'or #h~=n*2 or h:find('[^a-f0-9]')then return end;return(h:gsub('..',function(v)return string.char(tonumber(v,16))end))end
local function hex(s)return(s:gsub('.',function(v)return string.format('%02x',v:byte())end))end
local function public(seed)local h=sha512.digest(seed);return ed.encode(ed.mulG(fq.bits(fq.decodeClamped(h:sub(1,32)))))end
function C.Public(seedHex)local seed=raw(seedHex,32);if not seed then return end;return hex(public(seed))end
function C.Sign(seedHex,message)
 local seed=raw(seedHex,32);if not seed or type(message)~='string'or #message>24576 then return end
 local h=sha512.digest(seed);local x=fq.decodeClamped(h:sub(1,32));local pk=public(seed)
 local k=fq.decodeWide(sha512.digest(h:sub(33,64)..message));local r=ed.encode(ed.mulG(fq.bits(k)))
 local e=fq.decodeWide(sha512.digest(r..pk..message));return hex(r..fq.encode(fq.add(k,fq.mul(x,e))))
end
local ORDER=raw('edd3f55c1a631258d69cf7a2def9de1400000000000000000000000000000010',32)
local IDENTITY=string.char(1)..string.rep(string.char(0),31)
local function lessLE(a,b)for i=32,1,-1 do local x,y=a:byte(i),b:byte(i);if x~=y then return x<y end end;return false end
local function point(s)
 local p=ed.decode(s);if not p or ed.encode(p)~=s then return end
 local eight=ed.double(ed.double(ed.double(p)));if ed.encode(eight)==IDENTITY then return end
 return p
end
function C.Verify(pkHex,message,sigHex)
 local pk,sig=raw(pkHex,32),raw(sigHex,64)
 if not pk or not sig or type(message)~='string'or #message>24576 or not lessLE(sig:sub(33),ORDER)then return false end
 local y=point(pk);if not y or not point(sig:sub(1,32))then return false end
 local e=fq.decodeWide(sha512.digest(sig:sub(1,32)..pk..message))
 local gs=ed.mulG(fq.bits(fq.decode(sig:sub(33))));local ye=ed.mul(y,fq.bits(e))
 return ed.encode(ed.sub(gs,ed.niels(ye)))==sig:sub(1,32)
end
