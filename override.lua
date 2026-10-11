local ENTITY = FindMetaTable('Entity')
local get_table = ENTITY.GetTable

local PLAYER = FindMetaTable('Player')
PLAYER.__oldindex = PLAYER.__oldindex or PLAYER.__index
local old_index = PLAYER.__oldindex
function PLAYER:__index(key)
    local ent_table = get_table(self)
    if not ent_table then return old_index(self,key) end
    local overrides = ent_table.__override
    if not overrides then return old_index(self,key) end
    return overrides[key] or old_index(self,key)
end
