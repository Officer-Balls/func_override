local ENTITY = FindMetaTable('Entity')
local get_table = ENTITY.GetTable

local PLAYER = FindMetaTable('Player')
PLAYER.__oldindex = PLAYER.__oldindex or PLAYER.__index
local old_index = PLAYER.__oldindex
function PLAYER:__index(key)
    local tbl = get_table(self)
    if not tbl then
        return old_index(self,key)
    end
    return tbl[key] or old_index(self,key)
end
