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

local debounceSync = RBUtils.Debounce(100, function()
    Ext.Vars.SyncUserVariables(RB_FLAG_FIELD)
end)

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

    local flags = entity.Vars[RB_FLAG_FIELD] or 0
    return (flags & flag) ~= 0
end

--- @param entity GUIDSTRING|EntityHandle
--- @param flag RB_UserVars_Flags
--- @param retryCnt number?
--- @return boolean
function RB_FlagHelpers.SetFlag(entity, flag, retryCnt)
    if type(flag) == "string" then
        flag = RB_UserVars_Flags[flag]
    end
    if type(entity) == "string" then
        entity = Ext.Entity.Get(entity) --[[@as EntityHandle]]
    end
    if not entity or not entity.Vars then
        if retryCnt and retryCnt >= 5 then
            Warning("Failed to set flag after 5 retries: " .. tostring(entity) .. ", " .. tostring(flag))
            return false
        end
        Timer:After(100, function (timerID)
            RB_FlagHelpers.SetFlag(entity, flag, (retryCnt or 0) + 1)
        end)
        return false
    end

    local flags = entity.Vars[RB_FLAG_FIELD] or RB_UserVars_Flags.None
    entity.Vars[RB_FLAG_FIELD] = flags | flag
    Ext.Vars.DirtyUserVariables(entity.Uuid.EntityUuid, RB_FLAG_FIELD)
    debounceSync()
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
    Ext.Vars.DirtyUserVariables(entity.Uuid.EntityUuid, RB_FLAG_FIELD)
    debounceSync()
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
    debounceSync()
    return true
end



