local function spawnHandler(data)
    local template = data.TemplateId
    local spawnTemplate = template
    local entInfo = data.EntInfo or {}
    local position = entInfo.Position
    local rotation = entInfo.Rotation
    if not position or #position ~= 3 then
        position = {0,0,0}
    end
    if not rotation or #rotation ~= 4 then
        rotation = {0,0,0,1}
    end
    local rtype = data.Type

    if rtype == "Preview" then
        local previewItem = OsirisHelpers.PreviewTemplate(template, position[1], position[2], position[3], rotation[1], rotation[2], rotation[3], rotation[4], entInfo and entInfo.VisualPreset)
        return {Guid = previewItem, TemplateId = template}
    end

    local newGuid = EntityManager:CreateAt(spawnTemplate, position[1], position[2], position[3], rotation[1], rotation[2], rotation[3], rotation[4])

    if not newGuid then
        return {Guid = nil, TemplateId = template}
    end

    EntityManager:SetEntity(newGuid, entInfo or {})

    entInfo.Visible = true
    entInfo.Guid = newGuid
    entInfo.TemplateId = template

    if entInfo.Scale then 
        NetChannel.SetVisualTransform:Broadcast({Guid = newGuid, Transforms = {[newGuid] = {Scale = entInfo.Scale}}})
    end

    NetChannel.Entities.Added:Broadcast({Entities = {entInfo}})

    return {Guid = newGuid }
end

NetChannel.Spawn:SetHandler(function(data, userID)
    spawnHandler(data)
end)

NetChannel.Spawn:SetRequestHandler(function(data, userID)
    return spawnHandler(data)
end)

NetChannel.Duplicate:SetRequestHandler(function(data, user)
    local guids = NormalizeGuidList(data.Guid)
    local newGuids = {}
    local guidToTemplateId = {}
    for _,guid in pairs(guids) do
        local template = Osi.GetTemplate(guid) --[[@as string]]
        local pos = {CGetPosition(guid)}
        --- @diagnostic disable-next-line
        local newGuid = EntityManager:CreateAt(template, pos[1], pos[2], pos[3], CGetRotation(guid))
        if not newGuid then
            Warning("Failed to duplicate entity: " .. tostring(guid))
            goto continue
        end
        --- @diagnostic disable-next-line
        guidToTemplateId[guid] = template
        table.insert(newGuids, newGuid)
        ::continue::
    end

    NetChannel.Entities.Added:Broadcast({Entities = EntityManager:GetEntities(newGuids)})

    return {GuidToTemplateId = guidToTemplateId, NewGuids = newGuids}
end)

local deleteHandler = function(data)
    local guids = NormalizeGuidList(data.Guid)
    local toCache = {}
    for _,guid in pairs(guids) do
        if EntityManager.SavedEntities[guid] then
            table.insert(toCache, guid)
        else
            Osi.RequestDelete(guid)
            Osi.RequestDeleteTemporary(guid)
        end
    end
    EntityManager:DeleteEntities(toCache)

    if data.Type == "DeleteAll" then
        EntityManager:DeleteAll()
    end
end

NetChannel.Delete:SetHandler(function(data, userID)
    deleteHandler(data)
end)

NetChannel.Restore:SetHandler(function(data, userID)
    EntityManager:RestoreEntities(data.Guid)
end)

NetChannel.Delete:SetRequestHandler(function(data, userID)
    deleteHandler(data)
    return {}
end)

NetChannel.AddItem:SetHandler(function(data)
    Osi.TemplateAddTo(data.TemplateId, data.Target, data.Count, 1)
end)

NetChannel.GetTemplate:SetRequestHandler(function(data, userID)
    local guid = NormalizeGuidList(data.Guid)

    local map = {}
    for _,g in pairs(guid) do
        if EntityManager.SavedEntities[g] then
            map[g] = EntityManager.SavedEntities[g].TemplateId
        else
            local template = Osi.GetTemplate(g)
            map[g] = template
        end
    end

    return {GuidToTemplateId = map}
end)

NetChannel.SpawnPreview:SetRequestHandler(function(data, userID)
    local template = data.TemplateId
    local position = data.Position
    local rotation = data.Rotation
    if not position or #position ~= 3 then
        position = {0,0,0}
    end
    if not rotation or #rotation ~= 4 then
        rotation = {0,0,0,1}
    end

    local preview = Osi.CreateAt(template, position[1], position[2], position[3], 0, 0, "") --[[@as string]]
    if not preview then return {Guid = nil, TemplateId = template} end
    OsirisHelpers.RotateTo(preview, rotation[1], rotation[2], rotation[3], rotation[4])
    OsirisHelpers.Propify(preview)
    Osi.ClearTag(preview, RB_PROP_TAG)
    Osi.SetCanInteract(preview, 0)

    return {Guid = preview, TemplateId = template}
end)

NetChannel.ManageEntity:SetHandler(function(data, userID)
    local action = data.Action
    if action == "Add" then
        if data.Guid then
            EntityManager:AddEntity(data.Guid)
        end
    elseif action == "Remove" then
        if data.Guid then
            EntityManager:FreeEntity(data.Guid)
        end
    elseif action == "Delete" then
        deleteHandler(data)
    elseif action == "Restore" then
        EntityManager:RestoreEntities(data.Guid)
    elseif action == "Clear" then
        EntityManager:Clear()
    elseif action == "BFDA" then
        EntityManager:BF_DeleteAll()
    elseif action == "Load" then
        EntityManager:LoadFromModVar()
    elseif action == "Scan" then
        EntityManager:ScanForEntities()
    end
end)

local function setTransform(data)
    local toSet = NormalizeGuidList(data.Guid)
    for _, guid in ipairs(toSet) do
        local transform = data.Transforms[guid]
        if not transform then goto continue end

        if transform.Translate and #transform.Translate == 3 then
            OsirisHelpers.TeleportTo(guid, transform.Translate[1], transform.Translate[2], transform.Translate[3])
        end
        if transform.RotationQuat and #transform.RotationQuat == 4 then
            OsirisHelpers.RotateTo(guid, transform.RotationQuat[1], transform.RotationQuat[2], transform.RotationQuat[3], transform.RotationQuat[4])
        end
        if transform.Scale and #transform.Scale == 3 then
            OsirisHelpers.ScaleTo(guid, transform.Scale[1], transform.Scale[2], transform.Scale[3])
            NetChannel.SetVisualTransform:Broadcast({Guid = guid, Transforms = {[guid] = {Scale = transform.Scale}}})
        end

        if BindManager then
            BindManager:UpdateOffset(guid)
        end
        ::continue::
    end

end

NetChannel.SetTransform:SetHandler(function(data, userID)
    setTransform(data)
end)

NetChannel.SetTransform:SetRequestHandler(function(data, userID)
    setTransform(data)
    return {} --finished
end)

NetChannel.TeleportTo:SetHandler(function(data, userID)
    local toTeleport = NormalizeGuidList(data.Guid)
    for _, guid in ipairs(toTeleport) do
        local position = data.Position
        Osi.TeleportToPosition(guid, position[1], position[2], position[3])

        if BindManager then
            BindManager:UpdateOffset(guid)
        end
    end
end)

NetChannel.Replicate:SetHandler(function (data, userID)

    for _, guid in ipairs(NormalizeGuidList(data.Guid)) do
        local entity = Ext.Entity.Get(guid) --[[@as EntityHandle]]
        entity:Replicate(data.Field)
    end
    
end)

local spawnedVisualizations = {}
NetChannel.Visualize:SetRequestHandler(function(data, userID)
    if not spawnedVisualizations[userID] then
        spawnedVisualizations[userID] = {}
    end
    local duration = data.Duration or 1000
    local entityHandles = {}
    if data.Type == "Point" then
        local pos = data.Position
        local pointEntity = Osi.CreateAt(RB_PROP_AXIS_FX, pos[1], pos[2], pos[3], 1, 0, "") --[[@as string]]
        table.insert(entityHandles, pointEntity)
        if data.Rotation then
            OsirisHelpers.RotateTo(pointEntity, table.unpack(data.Rotation))
        end

        -- prevent jump scare
        Osi.SetVisible(pointEntity, 0)
        Timer:Ticks(10, function (timerID)
            Osi.SetVisible(pointEntity, 1)
        end)

    elseif data.Type == "Line" then
        local startPos = data.Position
        local endPos = data.EndPosition
        local handle = OsirisHelpers.DrawLine(startPos, endPos, data.Width, userID)
        table.insert(entityHandles, handle)
    elseif data.Type == "Box" then
        entityHandles = OsirisHelpers.DrawBox(data.Min, data.Max, data.Width, userID)
    elseif data.Type == "OBB" then
        entityHandles = OsirisHelpers.DrawOrientedBox(data.Position, data.HalfSizes, data.Rotation, data.Width, userID)
    elseif data.Type == "Clear" then
        local existing = spawnedVisualizations[userID]
        for _,e in pairs(existing) do
            Osi.RequestDelete(e)
        end
        spawnedVisualizations[userID] = {}
    elseif data.Type == "Cursor" then
        local pos = data.Position
        local cursorEntity = Osi.CreateAt(GIZMO_CURSOR, pos[1], pos[2], pos[3], 1, 0, "") --[[@as string]]
        table.insert(entityHandles, cursorEntity)
        if data.Rotation then
            OsirisHelpers.RotateTo(cursorEntity, table.unpack(data.Rotation))
        end

        NetChannel.SetVisualTransform:Broadcast({Guid = cursorEntity, Transforms = {
            [cursorEntity] = { Scale = {0, 0, 0} }
        }})
    end
    for _,e in pairs(entityHandles) do
        RB_FlagHelpers.SetFlag(e, "IsGizmo")
    end

    if duration > 0 then
        Timer:After(duration, function()
            for _,e in pairs(entityHandles) do
                Osi.RequestDelete(e)
            end
        end)
    else
        for _,e in pairs(entityHandles) do
            table.insert(spawnedVisualizations[userID], e)
        end
    end

    return entityHandles
    
end)

NetChannel.SetAttributes:SetHandler(function(data, userID)
    local toSet = NormalizeGuidList(data.Guid)
    for _, guid in ipairs(toSet) do
        if data.Attributes then
            EntityManager:SetEntity(guid, data.Attributes or {})
        end
    end
    NetChannel.AttributeChanged:Broadcast({Guid = toSet, Attributes = data.Attributes or {}})
end)


NetChannel.Bind:SetHandler(function(data, userID)
    if not BindManager then
        Warning("BindManager not initialized.")
        return
    end

    local tobind = NormalizeGuidList(data.Guid)

    if IsCamera(data.Parent) then data.Parent = data.Parent .. tostring(userID) end

    for _, guid in ipairs(tobind) do
        if data.Type == "Unbind" then
            BindManager:Unbind(guid)
        elseif data.Type == "UpdateOffset" then
            BindManager:UpdateOffset(guid)
        elseif data.Type == "SetAttributes" then
            BindManager:UpdateAttributes(guid, data.Attributes)
        else
            local success = BindManager:Bind(guid, data.Parent, data.Attributes)
            if not success then
                Warning("Bind failed: " .. tostring(guid) .. " to " .. tostring(data.Parent))
            end
        end
    end

    if data.Type == "UpdateOffset" then return end
    BindManager:BroadcastBindState(tobind)
end)


local gizmoUserStack = {}
NetChannel.ManageGizmo:SetRequestHandler(function(data, userID)
    if data.Clear then
        local stack = gizmoUserStack[tostring(userID)] or {}
        if #stack == 0 then
            stack = BF_GetAllGizmos()
        end
        for _, guid in ipairs(stack) do
            Osi.RequestDelete(guid)
        end
        gizmoUserStack[tostring(userID)] = {}
        return { Clear = true }
    end

    if not Enums.TransformEditorMode[data.GizmoType] and data.GizmoType ~= "All" then
        return { Guid = nil }
    end

    data.Position = data.Position or {0,0,0}
    if #data.Position ~= 3 then
        data.Position = {0,0,0}
    end

    local guid = Osi.CreateAt(GIZMO_ITEM[data.GizmoType], data.Position[1], data.Position[2], data.Position[3], 1, 0, "") --[[@as string]]
    Osi.SetVisible(guid, 0)

    RB_FlagHelpers.SetFlag(guid, "IsGizmo")
    Timer:Ticks(30, function (timerID)
        NetChannel.SetVisualTransform:Broadcast({Guid = guid, Transforms = {
            [guid] = { Scale = {0, 0, 0} }
        }})
    end)

    gizmoUserStack[tostring(userID)] = gizmoUserStack[tostring(userID)] or {}
    table.insert(gizmoUserStack[tostring(userID)], guid)

    return {Guid = guid}
end)

NetChannel.UpdateCamera:SetHandler(function (data, userID)
    userID = CameraSymbol .. tostring(userID)

    if data.Deactive then
        SetCameraPosition(userID, nil)
        SetCameraRotation(userID, nil)
        return
    end

    SetCameraPosition(userID, data.CameraPosition)
    SetCameraRotation(userID, data.CameraRotation)
end)

NetChannel.UpdateDummies:SetHandler(function (data, userID)
    if data.Deactive then
        ClearDummyData()
        Debug("Clear server dummy data")
        return
    end

    for uuid, info in pairs(data.DummyInfos) do
        SetDummyPosition(uuid, info.Position)
        SetDummyRotation(uuid, info.Rotation)
    end
end)

NetChannel.PlayEffect:SetHandler(function(data, userID)
    EM:PlayEffects(data)
end)

NetChannel.StopEffect:SetHandler(function(data, userID)
    if data.Type == "All" then
        EM:StopAllEffects()
    elseif data.Type == "FxName" then
        EM:StopEffectByFxName(data.FxName)
    elseif data.Type == "Object" then
        EM:StopEffectByObject(data.Object)
    elseif data.Type == "Both" then
        EM:StopEffectByComb(data.FxName, data.Object)
    end
end)

NetChannel.CreateStat:SetHandler(function(data, userID)
    data.DisplayName = data.DisplayName .. tostring(userID)

    if data.Type == "StatusData" then
        EM:PlayStatus(data)
    elseif data.Type == "SpellData" then
        EM:PlaySpell(data)
    end
end)


NetChannel.StopStatus:SetHandler(function (data, userID)

    if data.Type == "All" then
        EM:RemoveAllStatuses()
        return
    end

    data.DisplayName = data.DisplayName .. tostring(userID)

    EM:RemoveStatus(data)
end)


NetChannel.GetAtmosphere:SetRequestHandler(function (data, userID)
    local trigger = FindCurrentAtmosphereTrigger()
    if not trigger then
        return {Guid = "", ResourceUUIDs = {}}
    end
    local atmosphereUuid = trigger.ServerAtmosphereTrigger.CurrentAtmosphereResourceID
    local allResources = LightCToArray(trigger.ServerAtmosphereTrigger.AtmosphereResourceIDs)
    for i=#allResources,1,-1 do
        local resUUID = allResources[i]
        if not IsUuid(resUUID) then
            table.remove(allResources, i)
        end
    end
    return {Guid = atmosphereUuid, ResourceUUIDs = allResources}
end)

NetChannel.GetLighting:SetRequestHandler(function (data, userID)
    local trigger = FindCurrentLightingTrigger()
    if not trigger then
        return {Guid = "", ResourceUUIDs = {}}
    end
    local lightingUuid = trigger.ServerLightingTrigger.CurrentLightingResourceID
    local allResources = LightCToArray(trigger.ServerLightingTrigger.LightingResourceIDs)
    for i=#allResources,1,-1 do
        local resUUID = allResources[i]
        if not IsUuid(resUUID) then
            table.remove(allResources, i)
        end
    end
    return {Guid = lightingUuid, ResourceUUIDs = allResources}
end)

NetChannel.SetAtmosphere:SetRequestHandler(function (data, userID)
    local toSet = data.ResourceUUID

    if data.Atmosphere then
        local currentAtmRes = Ext.Resource.Get(toSet, "Atmosphere") --[[@as ResourceAtmosphere]]
        if not currentAtmRes then
            Warning("Invalid atmosphere resource UUID: " .. tostring(toSet))
            return false
        end

        for k,v in pairs(data.Atmosphere) do
            currentAtmRes.Atmosphere[k] = v
        end
    end

    if data.Reset then
        local triggers = Ext.Entity.GetAllEntitiesWithComponent("ServerAtmosphereTrigger")
        if not triggers then
            Warning("No atmosphere trigger found to reset.")
            return false
        end
        for _, trigger in pairs(triggers) do
            Osi.TriggerResetAtmosphere(trigger.Uuid.EntityUuid)
        end
        return true
    end

    if data.Apply then
        local trigger = FindCurrentAtmosphereTrigger()
        if not trigger then
            Warning("No atmosphere trigger found to apply.")
            return false
        end
        Osi.TriggerResetAtmosphere(trigger.Uuid.EntityUuid)
        Osi.TriggerSetAtmosphere(trigger.Uuid.EntityUuid, toSet)
        trigger.ServerAtmosphereTrigger.CurrentAtmosphereResourceID = toSet
        return true
    end

    return true
end)

NetChannel.SetLighting:SetRequestHandler(function (data, userID)
    local toSet = data.ResourceUUID

    if data.Lighting then
        local currentLightRes = Ext.Resource.Get(toSet, "Lighting") --[[@as Lighting]]
        if not currentLightRes then
            Warning("Invalid lighting resource UUID: " .. tostring(toSet))
            return false
        end

        for k,v in pairs(data.Lighting) do
            currentLightRes.Lighting[k] = v
        end

        if data.Reset then
            local trigger = FindCurrentLightingTrigger()
            if trigger then
                Osi.TriggerResetLighting(trigger.Uuid.EntityUuid)
                return true
            else
                Warning("No lighting trigger found to reset.")
                return false
            end
        end
    end
    
    if data.Reset then
        local triggers = Ext.Entity.GetAllEntitiesWithComponent("ServerLightingTrigger")
        if not triggers then
            Warning("No lighting trigger found to reset.")
            return false
        end
        for _, trigger in pairs(triggers) do
            Osi.TriggerResetLighting(trigger.Uuid.EntityUuid)
        end
        return true
    end

    if data.Apply then
        local trigger = FindCurrentLightingTrigger()
        if not trigger then
            Warning("No lighting trigger found to apply.")
            return false
        end
        Osi.TriggerResetLighting(trigger.Uuid.EntityUuid)
        Osi.TriggerSetLighting(trigger.Uuid.EntityUuid, toSet)
        trigger.ServerLightingTrigger.CurrentLightingResourceID = toSet
        return true
    end



    return true
end)
