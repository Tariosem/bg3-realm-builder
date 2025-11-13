VisualHelpers = VisualHelpers or {}

--- @param handle EntityHandle|GUIDSTRING
--- @return Visual?
function VisualHelpers.GetEntityVisual(handle)
    if type(handle) == "string" then
        if CIsCharacter(handle) then
            local dummy = GetDummyByUuid(handle)
            if dummy then
                handle = dummy
            elseif GetClientVisualDummy(handle) then
                handle = GetClientVisualDummy(handle) --[[@as EntityHandle]]
            else
                handle = UuidToHandle(handle)
            end
        else
            handle = UuidToHandle(handle)
        end
    end

    local entity = handle
    if not entity or not entity.Visual or not entity.Visual.Visual then
        return nil
    end
    return entity.Visual.Visual
end

--- @param handle any
--- @return number?
--- @return number?
--- @return number?
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

---@param handle EntityHandle|GUIDSTRING
---@return number?
---@return number?
---@return number?
function VisualHelpers.GetVisualScale(handle)
    local visual = VisualHelpers.GetEntityVisual(handle)

    if CIsItem(handle) then
        local renderable = VisualHelpers.GetRenderable(handle, 1)
        if renderable and renderable.WorldTransform then
            local scale = renderable.WorldTransform.Scale
            if scale and #scale >= 3 then
                return scale[1], scale[2], scale[3]
            end
        end
    end

    if not visual or not visual.WorldTransform then
        return nil, nil, nil
    end
    local scale = visual.WorldTransform.Scale
    if not scale or #scale < 3 then
        return nil, nil, nil
    end
    return scale[1], scale[2], scale[3]
end

function VisualHelpers.GetRenderableScale(handle, descIndex, attachIndex)
    local renderable = VisualHelpers.GetRenderable(handle, descIndex, attachIndex)
    if not renderable or not renderable.WorldTransform then
        return nil, nil, nil
    end
    local scale = renderable.WorldTransform.Scale
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

function VisualHelpers.GetVisualTransform(handle)
    local entity = handle
    local visual = VisualHelpers.GetEntityVisual(entity)
    if not visual or not visual.WorldTransform then
        return nil
    end
    local transform = {}
    transform.Translate = visual.WorldTransform.Translate
    transform.RotationQuat = visual.WorldTransform.RotationQuat
    transform.Scale = visual.WorldTransform.Scale
    return transform
end

---@param guids GUIDSTRING[]
---@param transforms table<GUIDSTRING, Transform>
function VisualHelpers.SetVisualTransform(guids, transforms)
    local visuals = {} --[[@as table<GUIDSTRING, Visual>]]

    for _,guid in pairs(guids) do
        if type(guid) ~= "string" or guid == "" then
            
            goto continue
        end
        local visual = VisualHelpers.GetEntityVisual(guid)
        if visual then
            visuals[guid] = visual
        else
            Warning("TransformEditor: Entity not found: ", guid)
        end
        ::continue::
    end


    for guid,visual in pairs(visuals) do
        if CIsCharacter(guid) then
            local transform = transforms[guid]
            if not transform then
                --Warning("TransformEditor: No transform provided for guid: "..tostring(guid))
                return
            end
            if transform.Translate then
                visual:SetWorldTranslate(transform.Translate)
            end
            if transform.RotationQuat then
                visual:SetWorldRotate(transform.RotationQuat)
            end
            if transform.Scale then
                visual:SetWorldScale(transform.Scale)
            end
        else
            local transform = transforms[guid]
            local objs = visual.ObjectDescs --[[@as VisualObjectDesc[] ]]
            for _,obj in pairs(objs) do
                local renderable = obj.Renderable
                if not renderable or not renderable.WorldTransform then
                    goto continue
                end
                if transform.Translate then
                    renderable.WorldTransform.Translate = transform.Translate
                end
                if transform.RotationQuat then
                    renderable.WorldTransform.RotationQuat = transform.RotationQuat
                end
                if transform.Scale then
                    renderable.WorldTransform.Scale = transform.Scale
                end
                ::continue::
            end
        end
    end
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
    local visual = VisualHelpers.GetEntityVisual(entity)
    if not visual or not visual.WorldTransform then
        return
    end
    local aabb = visual.WorldBound
    if not aabb then return end
    NetChannel.VisualizeAABB:SendToServer({Min = aabb.Min, Max = aabb.Max})
end

function VisualHelpers.ChangeFrames(frames, value, isColor)
    isColor = isColor or false
    for _, frame in ipairs(frames) do
        if isColor then
            frame.Color = value
        else
            frame.Value = value
        end
    end
end

function VisualHelpers.ChangeABCDFrames(frames, a, b, c, d)
    for _, frame in ipairs(frames) do
        frame.A = a
        frame.B = b
        frame.C = c
        frame.D = d
    end
end

--- @param guid string
--- @param preset table
--- @param retryCnt number?
function VisualHelpers.ApplyVisualParams(guid, preset, retryCnt)
    if not guid or not preset then
        Warning("ApplyVisualParams: Invalid parameters.")
        return
    end
    
    retryCnt = retryCnt or 0
    local isCharacter = CIsCharacter(guid)

    local liveEntity = UuidToHandle(guid)
    if not liveEntity or not liveEntity.Visual then
        if not liveEntity and retryCnt < 1 then
            Timer:After(500, function()
                VisualHelpers.ApplyVisualParams(guid, preset, retryCnt+1)
            end)
        else
            Error("Visual not found for GUID: " .. tostring(guid))
        end
        return
    end

    local handlers = {
        Scale = function(value, entity)
            local renderable = VisualHelpers.GetRenderable(entity, value.DescIndex, value.AttachIndex)
            if renderable then
                renderable.WorldTransform.Scale = value.Value
            end
        end,

        Light = function(value, entity)
            local component = VisualHelpers.GetEffectComponent(entity, value.CompIndex)
            if not component then return end
            
            local property = component.Properties[value.PropertyName]
            if type(value.Value) == "boolean" then property = true end
            if not property then return end

            if value.PropertyName == "Appearance.Color" then
                VisualHelpers.ChangeFrames(property.Frames, value.Value, true)
            elseif type(value.Value) == "table" and #value.Value == 4 then
                for _, keyFrame in ipairs(property.KeyFrames) do
                    VisualHelpers.ChangeABCDFrames(keyFrame.Frames, value.Value[1], value.Value[2], value.Value[3], value.Value[4])
                end
            elseif type(value.Value) == "number" then
                for _, keyFrame in ipairs(property.KeyFrames) do
                    VisualHelpers.ChangeFrames(keyFrame.Frames, value.Value)
                end
            elseif type(value.Value) == "boolean" then
                component[value.PropertyName] = value.Value
            end
        end,
        
        ParticleSystem = function(value, entity)
            local component = VisualHelpers.GetEffectComponent(entity, value.CompIndex)
            if component then
                component[value.PropertyName] = value.Value
            end
        end,

        LightEntity = function(value, entity)
            local light = VisualHelpers.GetLightEntity(entity, value.CompIndex)
            if light then
                light[value.PropertyName] = value.Value
                if value.IsTemplate and light.Template then
                    light.Template[value.PropertyName] = value.Value
                end
            end

        end,
    }

    for _, value in pairs(preset.ModifiedParams) do
        local handler = handlers[value.Type]
        if handler then
            handler(value, liveEntity)
        else
        end
    end

    for key, matParam in pairs(preset.Materials) do
        local parsed = SplitByString(key, "::")
        local descIndex, attachIndex = tonumber(parsed[#parsed]), tonumber(parsed[#parsed-1])
        local mat = isCharacter and VisualHelpers.GetActiveMaterial(liveEntity, descIndex, attachIndex) or VisualHelpers.GetMaterial(liveEntity, descIndex, attachIndex)
        if not mat then return false end

        for i,params in pairs(matParam) do
            i = tonumber(i) --[[@as number]]
            for paramName, value in pairs(params) do
                local applyValue = #value == 1 and value[1] or value
                mat[PropTypeToFunc[#value]](mat, paramName, applyValue)
            end
        end

    end
end

--- @param entity EntityHandle|GUIDSTRING
--- @param descIndex number
--- @param attachIndex number|nil
--- @return RenderableObject|nil
function VisualHelpers.GetRenderable(entity, descIndex, attachIndex)
    local visual = VisualHelpers.GetEntityVisual(entity)
    if not visual then return nil end

    if attachIndex then
        if visual.Attachments and visual.Attachments[attachIndex] and visual.Attachments[attachIndex].Visual.ObjectDescs then
            local attach = visual.Attachments[attachIndex].Visual
            if attach.ObjectDescs and attach.ObjectDescs[descIndex] then
                local desc = attach.ObjectDescs[descIndex]
                return desc and desc.Renderable
            end
        end
    else
        if visual.ObjectDescs and visual.ObjectDescs[descIndex] then
            local desc = visual.ObjectDescs[descIndex]
            return desc and desc.Renderable
        end
    end

    return nil
end

function VisualHelpers.GetAttachment(entity, attachIndex)
    local visual = VisualHelpers.GetEntityVisual(entity)
    if not visual then return nil end

    if visual.Attachments and visual.Attachments[attachIndex] then
        return visual.Attachments[attachIndex]
    end

    return nil
end

function VisualHelpers.GetMaterial(entity, descIndex, attachIndex)
    local renderable = VisualHelpers.GetRenderable(entity, descIndex, attachIndex)
    return renderable and renderable.ActiveMaterial and renderable.ActiveMaterial.Material
end

function VisualHelpers.GetActiveMaterial(entity, descIndex, attachIndex)
    local renderable = VisualHelpers.GetRenderable(entity, descIndex, attachIndex)
    return renderable and renderable.ActiveMaterial
end

function VisualHelpers.GetEffectComponent(entity, compIndex)
    if entity.Effect and entity.Effect.Timeline and entity.Effect.Timeline.Components then
        return entity.Effect.Timeline.Components[compIndex]
    end
    return nil
end

function VisualHelpers.GetLightEntity(entity, compIndex)
    if not entity.Effect then return nil end
    return entity.Effect.Timeline.Components[compIndex].LightEntity.Light
end
