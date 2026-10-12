local body_mat = CreateMaterial("SASCloakerBody","VertexLitGeneric",{
    ["$basetexture"] = "models/cstrike/ct_sas",
    ["$bumpmap"] = "models/cstrike/ct_sas_normal",
    ["$phong"] = 1,
    ["$phongexponent"] = "10",
    ["$phongboost"] = "1",
    ["$phongfresnelranges"] = "[0.05 0.1 0.5]",
    ["$rimlight"] = "1",
    ["$rimlightexponent"] = "8",
    ["$rimlightboost"] = "2",
    ["$phongexponenttexture"] = "models/cstrike/ct_sas_normal",
    ["$rimmask"] = "1",
    ["$cloakpassenabled"] = 1,
})

local lens_mat = CreateMaterial("SASCloakerLens","VertexLitGeneric",{
    ["$baseTexture"] = "models/cstrike/ct_sas_glass",
    ["$envmap"] = "env_cubemap",
    ["$envmapmask"] = "models/cstrike/ct_sas_glass_spec",
    ["$color2"] = "[1 0.2 0]",
    ["$envmaptint"] = "[1 0.2 0]",
    ["$translucent"] = 1,
    ["$cloakpassenabled"] = 1,
    ["$cloakcolortint"] = "[1 0.6 0.6]"
})

local SIMILAR = {
    a = "4", A = "4", b = "8", B = "8", e = "3", E = "3",
    g = "9", G = "6", i = "1", I = "1", l = "1", L = "1",
    o = "0", O = "0", s = "5", S = "5", t = "7", T = "7",
    z = "2", Z = "2", h = "#", H = "#", x = "%", X = "%",
    ["!"] = "1", ["?"] = "7", ["."] = ",", [","] = ".",
    ["0"] = "O", ["1"] = "l",
}

-- pool for the random stage (includes a space, so letters
-- sometimes decay into blank gaps before vanishing)
local GLYPHS = "abcdefghijklmnopqrstuvwxyz0123456789#@$%&*+=<>?/\\|~ "

-- tweakables ----------------------------------------------------
local SPREAD         = 0.6   -- chars start decaying at different times, spread over this much of the fade
local SIMILAR_END    = 0.40  -- up to this point of a char's own decay it shows look-alikes...
local RANDOM_END     = 0.75  -- ...then random glyphs up to here, then it's gone
local FRACTION_STEPS = 6  -- scramble granularity (higher = decimals re-roll the glyphs more often)
------------------------------------------------------------------

local function HashString(str, seed)
    local h = bit.bxor(seed or 0, 0x9E3779B9)
    for i = 1, #str do
        h = bit.bxor(h, string.byte(str, i))
        h = bit.bxor(h, bit.lshift(h, 13))
        h = bit.bxor(h, bit.rshift(h, 17))
        h = bit.bxor(h, bit.lshift(h, 5))
    end
    return h
end

-- xorshift32: private RNG, doesn't touch global math.random state
local function MakeRNG(seed)
    local state = bit.band(seed, 0x7FFFFFFF)
    if state == 0 then state = 1 end
    return function()
        state = bit.bxor(state, bit.lshift(state, 13))
        state = bit.bxor(state, bit.rshift(state, 17))
        state = bit.bxor(state, bit.lshift(state, 5))
        return state
    end
end

local function RNGFloat(rng) -- [0, 1)
    return bit.band(rng(), 0xFFFF) / 0x10000
end

local function PickGlyph(r)
    local idx = math.floor(r * #GLYPHS) + 1
    return GLYPHS:sub(idx, idx)
end

function string.FadeText(str, fraction, nonce)
    if str == nil then return "" end
    if type(str) ~= "string" then str = tostring(str) end

    fraction = math.Clamp(tonumber(fraction) or 0, 0, 1)
    if fraction <= 0 then return str end
    if fraction >= 1 then return (" "):rep(#str) end

    -- seed = hash of the string + quantized fraction (+ optional nonce)
    local seed = HashString(str, math.floor(fraction * FRACTION_STEPS))
    if nonce ~= nil then
        seed = bit.bxor(seed, HashString(tostring(nonce), 0x51ED270B))
    end

    local rng = MakeRNG(seed)
    local out = {}

    for i = 1, #str do
        local c = str:sub(i, i)

        -- always drawn in the same order -> deterministic
        local offset = RNGFloat(rng) -- when this char starts decaying
        local pickA  = RNGFloat(rng) -- glyph for "look-alike" stage (if none in SIMILAR)
        local pickB  = RNGFloat(rng) -- glyph for "random" stage

        local startAt = offset * SPREAD

        if fraction <= startAt then
            out[#out + 1] = c -- not affected yet
        else
            local t = (fraction - startAt) / (1 - startAt) -- this char's own progress, 0..1

            if t < SIMILAR_END then
                out[#out + 1] = SIMILAR[c] or (c == " " and " " or PickGlyph(pickA))
            elseif t < RANDOM_END then
                out[#out + 1] = (c == " ") and " " or PickGlyph(pickB)
            else
                out[#out + 1] = " " -- fully decayed: keep the slot as whitespace
            end
        end
    end

    return table.concat(out)
end

local nick = FindMetaTable("Player").Nick

local override = {
    Nick = function(self)
        local name = nick(self)
        return string.FadeText(name,math.Round(math.ease.OutSine(self:GetNW2Float("CloakFactor",0)),3))
    end,
    GetTargetID = function(self)
        local fraction = math.Round(math.ease.OutSine(self:GetNW2Float("CloakFactor",0)),3)
        local health = string.FadeText(tostring(self:Health()).."% | "..tostring(self:Armor()).."%",fraction)
        return {
            {
                self:Nick(),
                self:GetPlayerColor():ToColor(),
                "TargetID"
            },
            {
                health,
                self:GetWeaponColor():ToColor(),
                "TargetIDSmall"
            }
        }
    end,
    Name = nick,
    GetName = nick
}


hook.Add("PrePlayerDraw","SasCloaker",function(ply)
    if not ply:GetNW2Bool("Cloaker",false) then return end
    if ply:GetModel()~="models/player/gasmask.mdl" then return end

    if ply:GetSubMaterial(0)~="!"..body_mat:GetName() then
        ply:SetSubMaterial(0,"!"..body_mat:GetName())
        ply:SetSubMaterial(1,"!"..lens_mat:GetName())
        ply.__override = override
    end

    local factor = math.ease.OutQuad(ply:GetNW2Float("CloakFactor"))

    body_mat:SetFloat("$cloakfactor",factor)
    lens_mat:SetFloat("$cloakfactor",factor)
end)
