Ext.Vars.RegisterModVariable(ModuleUUID, "EntityManager", {})

--- @enum RB_UserVars_Flags
local RB_UserVars_Flags = {
    None = 1,
    IsSpawned = 2,
    IsGizmo = 4,
    DeleteLater = 8,
    [1] = "None",
    [2] = "IsSpawned",
    [4] = "IsGizmo",
    [8] = "DeleteLater",
}

RB_FLAG_FIELD = "RB_Flags"

Ext.Vars.RegisterUserVariable(RB_FLAG_FIELD, {
    Client = true,
})

RB_FlagHelpers = {}

--- @param entity GUIDSTRING|EntityHandle
--- @param flag RB_UserVars_Flags
--- @return boolean
function RB_FlagHelpers.HasFlag(entity, flag)
    if type(flag) == "string" then
        flag = RB_UserVars_Flags[flag]
    end
    if type(entity) == "string" then
        entity = Ext.Entity.Get(entity) --[[@as EntityHandle]]
    end
    if not entity or not entity.Vars then return false end

    local flags = entity.Vars[RB_FLAG_FIELD] or RB_UserVars_Flags.None
    return (flags & flag) ~= 0
end

--- @param entity GUIDSTRING|EntityHandle
--- @param flag RB_UserVars_Flags
--- @return boolean
function RB_FlagHelpers.SetFlag(entity, flag)
    if type(flag) == "string" then
        flag = RB_UserVars_Flags[flag]
    end
    if type(entity) == "string" then
        entity = Ext.Entity.Get(entity) --[[@as EntityHandle]]
    end
    if not entity or not entity.Vars then return false end

    local flags = entity.Vars[RB_FLAG_FIELD] or RB_UserVars_Flags.None
    entity.Vars[RB_FLAG_FIELD] = flags | flag
    return true
end

function RB_FlagHelpers.RemoveFlag(entity, flag)
    if type(flag) == "string" then
        flag = RB_UserVars_Flags[flag]
    end
    if type(entity) == "string" then
        entity = Ext.Entity.Get(entity) --[[@as EntityHandle]]
    end
    if not entity or not entity.Vars then return false end

    local flags = entity.Vars[RB_FLAG_FIELD] or RB_UserVars_Flags.None
    entity.Vars[RB_FLAG_FIELD] = flags & (~flag)
    return true
end

function RB_FlagHelpers.ToggleFlag(entity, flag)
    if RB_FlagHelpers.HasFlag(entity, flag) then
        return RB_FlagHelpers.RemoveFlag(entity, flag)
    else
        return RB_FlagHelpers.SetFlag(entity, flag)
    end
end

function RB_FlagHelpers.ClearFlags(entity)
    if type(entity) == "string" then
        entity = Ext.Entity.Get(entity) --[[@as EntityHandle]]
    end
    if not entity or not entity.Vars then return false end

    entity.Vars[RB_FLAG_FIELD] = RB_UserVars_Flags.None
    return true
end



