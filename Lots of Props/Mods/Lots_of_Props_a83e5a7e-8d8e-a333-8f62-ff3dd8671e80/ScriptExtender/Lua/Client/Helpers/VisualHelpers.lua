VisualHelpers = VisualHelpers or {}

--- @param handle EntityHandle
--- @return Visual?
function VisualHelpers.GetEntityVisual(handle)
    local entity = handle
    if not entity or not entity.Visual or not entity.Visual.Visual then
        return nil
    end
    return entity.Visual.Visual
end

--- @param handle any
--- @return nil
--- @return nil
--- @return nil
function VisualHelpers.GetVisualPosition(handle)
    local entity = handle
    local visual = VisualHelpers.GetEntityVisual(entity)
    if not visual or not visual.WorldTransform then
        return nil, nil, nil
    end
    local transform = visual.WorldTransform.Translate
    if not transform or #transform < 3 then
        return nil, nil, nil
    end
    return transform[1], transform[2], transform[3]
    
end

--- @param handle any
--- @param pos any
--- @return boolean
function VisualHelpers.SetVisualPosition(handle, pos)
    local entity = handle
    local visual = VisualHelpers.GetEntityVisual(entity)
    if not visual or not visual.WorldTransform then
        return false
    end
    local transform = visual.WorldTransform.Translate
    if not transform or #transform < 3 then
        return false
    end
    visual.WorldTransform.Translate = {pos[1], pos[2], pos[3]}
    return true
end

---@param handle any
---@return nil
---@return nil
---@return nil
---@return nil
function VisualHelpers.GetVisualRotation(handle)
    local entity = handle
    local visual = VisualHelpers.GetEntityVisual(entity)
    if not visual or not visual.WorldTransform then
        return nil, nil, nil, nil
    end
    local rotation = visual.WorldTransform.RotationQuat
    if not rotation or #rotation < 4 then
        return nil, nil, nil, nil
    end
    return rotation[1], rotation[2], rotation[3], rotation[4]
end

---@param handle any
---@return nil
---@return nil
---@return nil
function VisualHelpers.GetVisualScale(handle)
    local entity = handle
    local visual = VisualHelpers.GetEntityVisual(entity)
    if not visual or not visual.WorldTransform then
        return nil, nil, nil
    end
    local scale = visual.WorldTransform.Scale
    if not scale or #scale < 3 then
        return nil, nil, nil
    end
    return scale[1], scale[2], scale[3]
end

--- @param handle EntityHandle
function VisualHelpers.SetVisualRotation(handle, rot)
    local entity = handle
    local visual = VisualHelpers.GetEntityVisual(entity)
    if not visual or not visual.WorldTransform then
        return false
    end
    local worldTransform = visual.WorldTransform
    if not worldTransform.RotationQuat or #worldTransform.RotationQuat < 4 then
        return false
    end
    visual:SetWorldRotate(rot)
    return true
end

--- @param handle EntityHandle
function VisualHelpers.SetVisualScale(handle, scale)
    local entity = handle
    local visual = VisualHelpers.GetEntityVisual(entity)
    if not visual or not visual.WorldTransform then
        return false
    end
    local transform = visual.WorldTransform.Scale
    if not transform or #transform < 3 then
        return false
    end
    visual:SetWorldScale(scale)
    return true
end

function VisualHelpers.GetEntityAABB(handle)
    local entity = handle
    local visual = VisualHelpers.GetEntityVisual(entity)
    if not visual or not visual.WorldTransform then
        return nil
    end
    local aabb = { Min = visual.WorldBound.Min, Max = visual.WorldBound.Max }
    if not aabb then return nil end

    return aabb
end

---@param entity EntityHandle|GUIDSTRING
function VisualHelpers.VisualizeAABB(entity)
    if type(entity) == "string" then
        if IsCamera(entity) then return end
        entity = Ext.Entity.Get(entity) --[[@as EntityHandle]]
    end

    if entity.PartyMember then
        local dummy = GetDummyByUuid(HandleToUuid(entity))
        if dummy and dummy.Visual and dummy.Visual.Visual then
            entity = dummy
        end
    end

    local visual = VisualHelpers.GetEntityVisual(entity)
    if not visual or not visual.WorldTransform then
        return
    end
    local aabb = visual.WorldBound
    if not aabb then return end
    Post("Visualize", { Type = "Box", Min = aabb.Min, Max = aabb.Max })
end

