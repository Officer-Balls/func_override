local hack_mat = CreateMaterial("_hack_material","UnlitGeneric",{["$basetexture"] = "models/cstrike/ct_sas"})
local sas_basetexture = GetRenderTargetEx("sas_cloaker_basetexture",1024,1024,RT_SIZE_NO_CHANGE,MATERIAL_RT_DEPTH_NONE,0,0,0)

render.PushRenderTarget(sas_basetexture)
cam.Start2D()
render.Clear(0,0,0,0)
surface.SetMaterial(hack_mat)
surface.SetDrawColor(color_white)
surface.DrawTexturedRect(0,0,1024,1024)

-- DrawColorModify({
-- 	[ "$pp_colour_addr" ] = 0,
-- 	[ "$pp_colour_addg" ] = 0,
-- 	[ "$pp_colour_addb" ] = 0,
-- 	[ "$pp_colour_brightness" ] = 0.5,
-- 	[ "$pp_colour_contrast" ] = 1.5,
-- 	[ "$pp_colour_colour" ] = 0,
-- 	[ "$pp_colour_mulr" ] = -1,
-- 	[ "$pp_colour_mulg" ] = -1,
-- 	[ "$pp_colour_mulb" ] = 0,
--     [ "$pp_colour_inv" ] = 1
-- })
DrawColorModify({
	[ "$pp_colour_addr" ] = 0,
	[ "$pp_colour_addg" ] = 0,
	[ "$pp_colour_addb" ] = 0,
	[ "$pp_colour_brightness" ] = -0.1,
	[ "$pp_colour_contrast" ] = 2,
	[ "$pp_colour_colour" ] = 0,
	[ "$pp_colour_mulr" ] = 1,
	[ "$pp_colour_mulg" ] = 1,
	[ "$pp_colour_mulb" ] = 0,
    [ "$pp_colour_inv" ] = 0
})
cam.End2D()
render.PopRenderTarget()



local body_mat = CreateMaterial("SASCloakerBody","VertexLitGeneric",{
    ["$basetexture"] = "models/cstrike/ct_sas",
    ["$bumpmap"] = "models/cstrike/ct_sas_normal",
    ["$phong"] = 1,
    ["$phongexponent"] = "5",
    ["$phongboost"] = "0.2",
    ["$phongfresnelranges"] = "[0.05 0.1 0.5]",
    ["$rimlight"] = "1",
    ["$rimlightexponent"] = "4",
    ["$rimlightboost"] = "2",
    ["$phongexponenttexture"] = "models/cstrike/ct_sas_normal",
    ["$rimmask"] = "1",
    ["$cloakpassenabled"] = 1,
})

body_mat:SetTexture("$basetexture",sas_basetexture)
body_mat:Recompute()

local lens_mat = CreateMaterial("SASCloakerLens","VertexLitGeneric",{
    ["$baseTexture"] = "models/cstrike/ct_sas_glass",
    ["$envmap"] = "env_cubemap",
    ["$envmapmask"] = "models/cstrike/ct_sas_glass_spec",
    ["$color2"] = "[1 0 0]",
    ["$envmaptint"] = "[1 0 0]",
    ["$translucent"] = 1,
    ["$cloakpassenabled"] = 1,
    ["$cloakcolortint"] = "[1 0 0]"
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
local RANDOM_END     = 0.5  -- ...then random glyphs up to here, then it's gone
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

local cloak_mats = {}
local function GetCloakMaterial(mat_path)
    if cloak_mats[mat_path] then return cloak_mats[mat_path] end
    local mat = Material(mat_path)

    if mat:IsError() then return end

    local newname = "c_"..mat:GetName()

    local key_values = mat:GetKeyValues()
    local flags = key_values["$flags"]
    local flags2 = key_values["$flags2"]
    local flags_defined = key_values["$flags_defined"]
    local flags_defined2 = key_values["$flags_defined2"]

    key_values["$flags"] = nil
    key_values["$flags2"] = nil
    key_values["$flags_defined"] = nil
    key_values["$flags_defined2"] = nil
    key_values["$cloakpassenabled"] = 1

    local cloak_mat = CreateMaterial(newname,mat:GetShader(),key_values)
    cloak_mat:SetTexture("$basetexture",mat:GetTexture("$basetexture"))
    cloak_mat:SetTexture("$bumpmap",mat:GetTexture("$bumpmap"))
    cloak_mat:SetInt("$flags",flags)
    cloak_mat:SetInt("$flags2",flags2)
    cloak_mat:SetInt("$flags_defined",flags_defined)
    cloak_mat:SetInt("$flags_defined2",flags_defined2)

    cloak_mats[mat_path] = cloak_mat
    return cloak_mat
end

local melee_weapon_types = {
    ["ma2z_blade_switchblade"] = true,
    ["ma2z_blade_cssknife"] = true,
    ["ma2z_blade_tanto"] = true,
    ["ma2z_blade_dadao"] = true,
    ["ma2z_blade_machete"] = true,
    ["ma2z_blade_katana"] = true,
    ["ma2z_spear_stick"] = true,
    ["ma2z_spear_fork"] = true,
    ["ma2z_spear_shovel"] = true,
    ["ma2z_spear_harpoon"] = true,
    ["ma2z_spear_spear"] = true,
    ["ma2z_spear_trident"] = true,
    ["ma2z_staff_branch"] = true,
    ["ma2z_staff_bo"] = true,
    ["ma2z_staff_nunchucks"] = true,
    ["ma2z_staff_quarterstaff"] = true,
    ["ma2z_staff_metal"] = true,
    ["ma2z_staff_scythe"] = true,
    ["ma2z_axe_survivalaxe"] = true,
    ["ma2z_axe_hatchet"] = true,
    ["ma2z_axe_pickaxe"] = true,
    ["ma2z_axe_beardedaxe"] = true,
    ["ma2z_axe_tomahawk"] = true,
    ["ma2z_axe_fireaxe"] = true,
    ["ma2z_bludgeon_hammer"] = true,
    ["ma2z_bludgeon_nightstick"] = true,
    ["ma2z_bludgeon_club"] = true,
    ["ma2z_bludgeon_bat"] = true,
    ["ma2z_bludgeon_crowbar"] = true,
    ["ma2z_bludgeon_sledgehammer"] = true,
    ["ma2z_syringe"] = true,
    ["ma2z_streiter"] = true,
    ["weapon_crowbar"] = true,
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

    local weapon = ply:GetActiveWeapon()
    if not weapon then return end
    if not weapon:IsWeaponVisible() then return end
    if not melee_weapon_types[weapon:GetClass()] then return end
    for i,mat_path in ipairs(weapon:GetMaterials()) do
        local swep_cloak_mat = GetCloakMaterial(mat_path)
        if not swep_cloak_mat then continue end
        swep_cloak_mat:SetFloat("$cloakfactor",factor)
        weapon:SetSubMaterial(i-1,"!"..swep_cloak_mat:GetName())
    end
end)


local effect = {
	[ "$pp_colour_addr" ] = 0,
	[ "$pp_colour_addg" ] = 0,
	[ "$pp_colour_addb" ] = 0,
	[ "$pp_colour_brightness" ] = 0.47,
	[ "$pp_colour_contrast" ] = 2.72,
	[ "$pp_colour_colour" ] = -1,
	[ "$pp_colour_mulr" ] = 0,
	[ "$pp_colour_mulg" ] = 0,
	[ "$pp_colour_mulb" ] = 0,
    [ "$pp_colour_inv" ] = 0
}

local vignette_mat = Material("vgui/zoom")
hook.Add("HUDPaint","Cloaker",function()
    if not LocalPlayer():GetNW2Bool("Cloaker",false) then return end
    if LocalPlayer():ShouldDrawLocalPlayer() then return end
    local intensity = LocalPlayer():GetNW2Float("CloakFactor")^7

    surface.SetMaterial(vignette_mat)

    local W,H = ScrW(),ScrH()

    for i = 0,2 do
        if intensity<i/3 then continue end
        local l_int = math.Remap(intensity,i/3,(i+1)/3,0,1)
        surface.SetDrawColor(0,0,0,l_int*255)

        surface.DrawTexturedRectUV(0,0,W*0.5,H*0.5,1,0,0,1)
        surface.DrawTexturedRectUV(W*0.5,0,W*0.5,H*0.5,0,0,1,1)
        surface.DrawTexturedRectUV(W*0.5,H*0.5,W*0.5,H*0.5,0,1,1,0)
        surface.DrawTexturedRectUV(0,H*0.5,W*0.5,H*0.5,1,1,0,0)
    end

    -- effect["$pp_colour_addr"] = 0.45*intensity
	effect[ "$pp_colour_brightness" ] = -0.06*intensity
	effect[ "$pp_colour_contrast" ] = 1-0.69*intensity
	effect[ "$pp_colour_colour" ] = 1-1*intensity
    effect["$pp_colour_mulr"] = 6*intensity
    DrawColorModify(effect)
end)
