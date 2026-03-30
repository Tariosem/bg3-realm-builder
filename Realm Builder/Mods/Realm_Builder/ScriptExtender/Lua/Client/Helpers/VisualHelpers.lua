VisualHelpers = VisualHelpers or {}

local visualRegistry = {}

function VisualHelpers.RegisterVisual(scenery)
    if not scenery or not scenery.Scenery or not scenery.Scenery.Uuid then
        return
    end
    visualRegistry[scenery.Scenery.Uuid] = scenery
end

--- @param handle EntityHandle|GUIDSTRING
--- @return Visual?
function VisualHelpers.GetEntityVisual(handle)
    if type(handle) == "string" then
        if visualRegistry[handle] then
            return visualRegistry[handle].Visual.Visual
        end

        local entityHandle = UuidToHandle(handle)
        if not entityHandle then
            return nil
        end
        local hasPMDummy = entityHandle.HasDummy
        if hasPMDummy then
            handle = hasPMDummy.Entity
        elseif GetClientVisualDummy(handle) then
            handle = GetClientVisualDummy(handle) --[[@as EntityHandle]]
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

--- @param handle EntityHandle|GUIDSTRING
--- @param set RB_ParameterSet
function VisualHelpers.ApplyParamSet(handle, set)
    if not handle or not set then
        return
    end

    -- todo?
end

--- @param handle any
--- @return number?
--- @return number?
--- @return number?
function VisualHelpers.GetVisualPosition(handle)
    local visual = VisualHelpers.GetEntityVisual(handle)
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
    local visual = VisualHelpers.GetEntityVisual(handle)
    if not visual or not visual.WorldTransform then
        return false
    end
    local transform = visual.WorldTransform.Translate
    if not transform or #transform < 3 then
        return false
    end
    visual.WorldTransform.Translate = { pos[1], pos[2], pos[3] }
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

--- @param handle EntityHandle|GUIDSTRING
function VisualHelpers.SetVisualScale(handle, scale)
    local visual = VisualHelpers.GetEntityVisual(handle)
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
    
    for _, guid in pairs(guids) do
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


    for guid, visual in pairs(visuals) do
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
    NetChannel.VisualizeAABB:SendToServer({ Min = aabb.Min, Max = aabb.Max })
end

local checkMap = { A = true, B = true, C = true, D = true }

--- @param frames AspkFloatKeyFrame[]
--- @return boolean
function VisualHelpers.AreFloakKeyFramesCubic(frames)
    for pName, pValue in pairs(frames[1]) do
        if checkMap[pName] then
            return true
        end
    end
    return false
end

function VisualHelpers.ChangeFrames(frames, value, isColor)
    isColor = isColor or false
    if VisualHelpers.AreFloakKeyFramesCubic(frames) then
        VisualHelpers.ChangeDFrames(frames, value)
        --VisualHelpers.ChangeABCDFrames(frames, value[1], value[2], value[3], value[4])
        return
    end

    for _, frame in ipairs(frames) do
        if isColor then
            frame.Color = value
        else
            frame.Value = value
        end
    end
end

function VisualHelpers.ChangeKeyFrames(keyFrames, value, isColor)
    isColor = isColor or false
    for _, keyFrame in ipairs(keyFrames) do
        VisualHelpers.ChangeFrames(keyFrame.Frames, value, isColor)
    end
end

--- @param frames AspkCubicFloatKeyFrame[]
function VisualHelpers.ChangeABCDFrames(frames, a, b, c, d)
    for _, frame in ipairs(frames) do
        frame.A = a
        frame.B = b
        frame.C = c
        frame.D = d
    end
end

--- @param frames AspkCubicFloatKeyFrame[]
function VisualHelpers.ChangeDFrames(frames, d)
    for _, frame in ipairs(frames) do
        frame.D = frame.D * d
    end
end

--- @param guid string
--- @param compIndex number
--- @param value any
--- @param propName string
function VisualHelpers.ApplyValueToFrames(guid, compIndex, value, propName)
    local comp = VisualHelpers.GetEffectComponent(guid, compIndex) --[[@as AspkLightComponent]]
    if not comp then return end

    local property = comp[propName]

    local frameField = propName == "ColorProperty" and "Frames" or "KeyFrames"

    if not property or not property[frameField] then return end

    if frameField == "KeyFrames" then
        VisualHelpers.ChangeKeyFrames(property.KeyFrames, value)
    else
        VisualHelpers.ChangeFrames(property.Frames, value, true)
    end
end

local lightComponentFields = {
    OverrideLightTemplateColor = true,
    OverrideLightTemplateFlickerSpeed = true,
    ModulateLightTemplateRadius = true,
}

--- @param comp AspkLightComponent
--- @param propName string
function VisualHelpers.GetLightComponentValue(comp, propName)
    if lightComponentFields[propName] then
        return comp[propName]
    end

    if RBStringUtils.TakeTail(propName, #"Property") == "Property" then
        local property = comp[propName] --[[@as AspkFloatKeyFrameProperty|AspkColorARGBKeyFrameProperty]]
        if not property then return nil end
        local frameField = propName == "ColorProperty" and "Frames" or "KeyFrames"
        if frameField == "KeyFrames" then
            local frames = property.KeyFrames[1].Frames
            if not frames then return nil end
            if VisualHelpers.AreFloakKeyFramesCubic(frames) then
                return frames[1].D
            else
                return frames[1].Value
            end
        else
            return property.Frames[1].Color
        end

        return nil
    end

    local lightEntity = comp.LightEntity.Light
    if not lightEntity then return nil end

    return lightEntity[propName]
end

--- @param comp AspkComponent
--- @param propName string
function VisualHelpers.GetEffectComponentValue(comp, propName)
    if comp.TypeName == "Light" then
        return VisualHelpers.GetLightComponentValue(comp --[[@as AspkLightComponent]], propName)
    end

    return comp[propName]
end

function VisualHelpers.SetEffectComponentValue(comp, propName, value)
    if comp.TypeName == "Light" then
        comp = comp --[[@as AspkLightComponent]]
        if RBStringUtils.EndsWith(propName, "Property") then
            -- VisualHelpers.ApplyValueToFrames not used here to avoid redundant GetEffectComponent call
            local property = comp[propName]
            local frameField = propName == "ColorProperty" and "Frames" or "KeyFrames"
            if not property or not property[frameField] then return end

            if frameField == "KeyFrames" then
                VisualHelpers.ChangeKeyFrames(property.KeyFrames, value)
            else
                VisualHelpers.ChangeFrames(property.Frames, value, true)
            end
            return
        end

        if lightComponentFields[propName] then
            comp[propName] = value
            return
        end

        local lightEntity = comp.LightEntity.Light --[[@as LightComponent]]
        if not lightEntity then return end

        lightEntity[propName] = value
        return
    end

    comp[propName] = value
end

--- @param guid string
--- @param compIndex number
--- @param value any
--- @param propName string
function VisualHelpers.ApplyValueToLightComponent(guid, compIndex, value, propName)
    local comp = VisualHelpers.GetEffectComponent(guid, compIndex) --[[@as AspkLightComponent]]
    if not comp then return end

    if RBStringUtils.TakeTail(propName, #"Property") == "Property" then
        VisualHelpers.ApplyValueToFrames(guid, compIndex, value, propName)
        return
    end

    if lightComponentFields[propName] then
        comp[propName] = value
        return
    end

    local lightEntity = comp.LightEntity.Light
    if not lightEntity then return end

    lightEntity[propName] = value
end

--- @param guid string
--- @param preset RB_VisualPreset
--- @param retryCnt number?
function VisualHelpers.ApplyVisualParams(guid, preset, retryCnt)
    if not guid or not preset then
        Warning("ApplyVisualParams: Invalid parameters.")
        return
    end

    retryCnt = retryCnt or 0

    local visual = VisualHelpers.GetEntityVisual(guid)
    if not visual then
        if retryCnt < 1 then
            Timer:After(500, function()
                VisualHelpers.ApplyVisualParams(guid, preset, retryCnt + 1)
            end)
        else
            Error("Visual not found for GUID: " .. tostring(guid))
        end
        return
    end

    local effectSetter = VisualHelpers.SetEffectComponentValue
    for key, compParams in pairs(preset.Effects) do
        local parsed = RBStringUtils.SplitByString(key, "::")
        local compType, compIndex = parsed[#parsed - 1], tonumber(parsed[#parsed])
        if not compIndex then
            Warning("Invalid component index in preset key:" ..
                "\n Parsed key:" .. tostring(key), " Type: " .. tostring(compType) .. " Index: " .. tostring(compIndex))
            goto continue1
        end
        local comp = VisualHelpers.GetEffectComponent(guid, compIndex) --[[@as AspkComponent]]
        if comp.TypeName ~= compType then
            Warning("Component type mismatch in preset key:" ..
                "\n Parsed key:" .. tostring(key),
                " Expected Type: " .. tostring(compType) .. " Actual Type: " .. tostring(comp.TypeName))
            goto continue1
        end
        for propName, value in pairs(compParams) do
            effectSetter(comp, propName, value)
        end
        ::continue1::
    end

    for key, matParam in pairs(preset.Materials) do
        local parsed = RBStringUtils.SplitByString(key, "::")
        local descIndex, attachIndex = tonumber(parsed[#parsed]), tonumber(parsed[#parsed - 1])
        if not descIndex then
            Warning([[Invalid desc index in preset key: ]] .. tostring(key) ..
                "\n Parsed key: " .. tostring(key),
                " DescIndex: " .. tostring(descIndex) .. " AttachIndex: " .. tostring(attachIndex))
            goto continue
        end

        --- verify attachment visual resource ID if attachIndex is provided
        if attachIndex ~= nil then
            local currentAttachment = VisualHelpers.GetAttachment(guid, attachIndex)
            if not currentAttachment then
                Warning("Attachment not found for preset key: " .. tostring(key) ..
                    "\n Parsed key: " .. tostring(key),
                    " AttachIndex: " .. tostring(attachIndex))
                goto continue
            end
            local currentVresId = currentAttachment.Visual.VisualResource and currentAttachment.Visual.VisualResource.Guid or nil
            local parsedVresId = parsed[1]
            if currentVresId ~= parsedVresId then
                Warning("Attachment visual resource ID mismatch for preset key: " .. tostring(key) ..
                    "\n Parsed key: " .. tostring(key),
                    " Expected VresId: " .. tostring(parsedVresId) .. " Actual VresId: " .. tostring(currentVresId))
                goto continue
            end
        end

        if preset.Transforms and preset.Transforms[key] then
            local transform = preset.Transforms[key]
            local renderable = VisualHelpers.GetRenderable(guid, descIndex, attachIndex)
            if renderable and renderable.WorldTransform then
                if transform.Scale then
                    renderable.WorldTransform.Scale = transform.Scale
                end
            end
        end

        local mat = VisualHelpers.GetActiveMaterial(guid, descIndex, attachIndex)
        if not mat then return false end

        for i, params in pairs(matParam) do
            i = tonumber(i) --[[@as number]]
            for paramName, value in pairs(params) do
                mat[MaterialEnums.ParamTypeToSetFunc[i]](mat, paramName, value)
            end
        end
        ::continue::
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

--- @param entity EntityHandle|GUIDSTRING
--- @param attachIndex integer
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

--- @param entity EntityHandle|GUIDSTRING
--- @param descIndex integer
--- @param attachIndex integer?
--- @return AppliedMaterial|nil
function VisualHelpers.GetActiveMaterial(entity, descIndex, attachIndex)
    local renderable = VisualHelpers.GetRenderable(entity, descIndex, attachIndex)
    return renderable and renderable.ActiveMaterial
end

--- @param visual Visual
--- @param descIndex integer
--- @param attachIndex integer?
function VisualHelpers.GetActiveMaterialFromVisual(visual, descIndex, attachIndex)
    if not visual then return nil end
    local renderable = nil
    if attachIndex then
        if visual.Attachments and visual.Attachments[attachIndex] and visual.Attachments[attachIndex].Visual.ObjectDescs then
            local attach = visual.Attachments[attachIndex].Visual
            if attach.ObjectDescs and attach.ObjectDescs[descIndex] then
                local desc = attach.ObjectDescs[descIndex]
                renderable = desc and desc.Renderable
            end
        end
    else
        if visual.ObjectDescs and visual.ObjectDescs[descIndex] then
            local desc = visual.ObjectDescs[descIndex]
            renderable = desc and desc.Renderable
        end
    end

    return renderable and renderable.ActiveMaterial
end 

--- @param entity EntityHandle|GUIDSTRING
--- @param compIndex number
--- @return AspkComponent|nil
function VisualHelpers.GetEffectComponent(entity, compIndex)
    if not entity then return nil end
    if type(entity) == "string" then
        entity = UuidToHandle(entity)
    end

    if entity.Effect and entity.Effect.Timeline and entity.Effect.Timeline.Components then
        return entity.Effect.Timeline.Components[compIndex]
    end
    return nil
end

function VisualHelpers.GetLightEntity(entity, compIndex)
    if not entity.Effect then return nil end
    return entity.Effect.Timeline.Components[compIndex].LightEntity.Light
end
