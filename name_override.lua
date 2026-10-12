local steamid = "STEAM_0:1:241616868"

local ply = player.GetBySteamID(steamid)

local NICK = FindMetaTable("Player").Nick

local override = {}
override.Nick = function(self)
    local name = self:GetNW2String("NameOverride","")
    if name == "" then name = nil end
    return name or NICK(self)
end
override.Name = override.Nick
override.GetName = override.Nick

local function Init()
    ply.__override = override
end

if not IsValid(ply) then
    gameevent.Listen("player_connect")
    hook.Add("player_connect","FindBalls",function(data)
        if data.networkid~=steamid then return end
        ply = Player(data.userid)
        Init()
        hook.Remove("player_connect","FindBalls")
    end)
    return
end
Init()
