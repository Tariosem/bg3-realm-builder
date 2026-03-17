local function spawnHandler(data)
    local template = data.TemplateId
    local entInfo = data.EntInfo or {}
    local position = entInfo.Position
    local rotation = entInfo.Rotation
    if not position or #position ~= 3 then
        position = { 0, 0, 0 }
    end
    if not rotation or #rotation ~= 4 then
        rotation = { 0, 0, 0, 1 }
    end
    local rtype = data.Type

    if rtype == "Preview" then
        local previewItem = OsirisHelpers.PreviewTemplate(template, position[1], position[2], position[3], rotation[1],
            rotation[2], rotation[3], rotation[4], entInfo and entInfo.VisualPreset, data.Duration or 5000)
        if not previewItem then
            return { Guid = nil, TemplateId = template }
        end

        if entInfo.Scale then
            NetChannel.SetVisualTransform:Broadcast({ Guid = previewItem, Transforms = { [previewItem] = { Scale = entInfo.Scale } } })
        end
        return { Guid = previewItem, TemplateId = template }
    end

    local newGuid = EntityManager:CreateAt(template, position[1], position[2], position[3], rotation[1], rotation
    [2], rotation[3], rotation[4])

    if not newGuid then
        return { Guid = nil, TemplateId = template }
    end

    EntityManager:SetEntity(newGuid, entInfo or {})

    entInfo.Visible = true
    entInfo.Guid = newGuid
    entInfo.TemplateId = template

    if entInfo.Scale then
        NetChannel.SetVisualTransform:Broadcast({ Guid = newGuid, Transforms = { [newGuid] = { Scale = entInfo.Scale } } })
    end

    if entInfo.VisualPreset then
        Timer:Ticks(30, function()
            NetChannel.ApplyVisualPreset:Broadcast({ Guid= newGuid, TemplateName = RBStringUtils.TrimTail(template, 37), VisualPreset = entInfo.VisualPreset })
        end)
    end

    NetChannel.Entities.Added:Broadcast({ Entities = { entInfo } })

    return { Guid = newGuid }
end

local deleteHandler = function(data)
    local guids = RBUtils.NormalizeGuidList(data.Guid)
    local toCache = {}
    for _, guid in pairs(guids) do
        if RB_FlagHelpers.HasFlag(guid, "IsSpawned") then
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
    local guid = RBUtils.NormalizeGuidList(data.Guid)

    local map = {}
    for _, g in pairs(guid) do
        if EntityManager.SavedEntities[g] then
            map[g] = EntityManager.SavedEntities[g].TemplateId
        else
            local template = Osi.GetTemplate(g)
            map[g] = template
        end
    end

    return { GuidToTemplateId = map }
end)

NetChannel.SpawnPreview:SetRequestHandler(function(data, userID)
    local template = data.TemplateId
    local templateId = RBUtils.TakeTailTemplate(template)
    local position = data.Position
    local rotation = data.Rotation
    if not position or #position ~= 3 then
        position = { 0, 0, 0 }
    end
    if not rotation or #rotation ~= 4 then
        rotation = { 0, 0, 0, 1 }
    end

    local templateObj = Ext.Template.GetTemplate(templateId)
    local spawnTemplate = EntityManager.TemplateTrick(templateObj, templateId)
    if not spawnTemplate then
        return { Guid = nil, TemplateId = template }
    end

    local preview = Osi.CreateAt(spawnTemplate, position[1], position[2], position[3], 1, 0, "") --[[@as string]]
    if not preview then return { Guid = nil, TemplateId = template } end
    RB_FlagHelpers.SetFlag(preview, "DeleteLater")
    OsirisHelpers.RotateTo(preview, rotation[1], rotation[2], rotation[3], rotation[4])
    OsirisHelpers.Propify(preview)
    Osi.ClearTag(preview, RB_PROP_TAG)
    Osi.SetCanInteract(preview, 0)

    return { Guid = preview, TemplateId = template }
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
    local toSet = RBUtils.NormalizeGuidList(data.Guid)
    for _, guid in ipairs(toSet) do
        local transform = data.Transforms[guid]
        if not transform then goto continue end

        if transform.Translate and #transform.Translate == 3 then
            OsirisHelpers.TeleportTo(guid, transform.Translate[1], transform.Translate[2], transform.Translate[3])
        end
        if transform.RotationQuat and #transform.RotationQuat == 4 then
            OsirisHelpers.RotateTo(guid, transform.RotationQuat[1], transform.RotationQuat[2], transform.RotationQuat[3],
                transform.RotationQuat[4])
        end
        if transform.Scale and #transform.Scale == 3 then
            OsirisHelpers.ScaleTo(guid, transform.Scale[1], transform.Scale[2], transform.Scale[3])
            NetChannel.SetVisualTransform:Broadcast({ Guid = guid, Transforms = { [guid] = { Scale = transform.Scale } } })
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
    local toTeleport = RBUtils.NormalizeGuidList(data.Guid)
    for _, guid in ipairs(toTeleport) do
        local position = data.Position
        Osi.TeleportToPosition(guid, position[1], position[2], position[3])

        if BindManager then
            BindManager:UpdateOffset(guid)
        end
    end
end)

NetChannel.Replicate:SetHandler(function(data, userID)
    for _, guid in ipairs(RBUtils.NormalizeGuidList(data.Guid)) do
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
        Timer:Ticks(10, function(timerID)
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
        for _, e in pairs(existing) do
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

        NetChannel.SetVisualTransform:Broadcast({
            Guid = cursorEntity,
            Transforms = {
                [cursorEntity] = { Scale = { 0, 0, 0 } }
            }
        })
    end

    for _, e in pairs(entityHandles) do
        RB_FlagHelpers.SetFlag(e, "IsGizmo")
    end

    if duration > 0 then
        Timer:After(duration, function()
            for _, e in pairs(entityHandles) do
                Osi.RequestDelete(e)
            end
        end)
    else
        for _, e in pairs(entityHandles) do
            table.insert(spawnedVisualizations[userID], e)
        end
    end

    return entityHandles
end)

NetChannel.SetAttributes:SetHandler(function(data, userID)
    local toSet = RBUtils.NormalizeGuidList(data.Guid)
    for _, guid in ipairs(toSet) do
        if data.Attributes then
            EntityManager:SetEntity(guid, data.Attributes or {})
        end
    end
    NetChannel.AttributeChanged:Broadcast({ Guid = toSet, Attributes = data.Attributes or {} })
end)


NetChannel.Bind:SetHandler(function(data, userID)
    if not BindManager then
        Warning("BindManager not initialized.")
        return
    end

    local tobind = RBUtils.NormalizeGuidList(data.Guid)

    if RBUtils.IsCamera(data.Parent) then data.Parent = data.Parent .. tostring(userID) end

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
            stack = EntityHelpers.GetAllGizmos()
        end
        if #stack == 0 then
            stack = EntityHelpers.BF_GetAllGizmos()
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

    data.Position = data.Position or { 0, 0, 0 }
    if #data.Position ~= 3 then
        data.Position = { 0, 0, 0 }
    end

    local guid = Osi.CreateAt(GIZMO_ITEM[data.GizmoType], data.Position[1], data.Position[2], data.Position[3], 1, 0, "") --[[@as string]]
    Osi.SetVisible(guid, 0)
    RB_FlagHelpers.SetFlag(guid, "IsGizmo")

    Timer:Ticks(30, function(timerID)
        NetChannel.SetVisualTransform:Broadcast({
            Guid = guid,
            Transforms = {
                [guid] = { Scale = { 0, 0, 0 } }
            }
        })
        NetChannel.SetVisualTransform:SendToClient({ Guid = guid, Transforms = {
            [guid] = { Scale = { 1, 1, 1 } }
        } }, userID)
    end)

    gizmoUserStack[tostring(userID)] = gizmoUserStack[tostring(userID)] or {}
    table.insert(gizmoUserStack[tostring(userID)], guid)

    return { Guid = guid }
end)

NetChannel.UpdateCamera:SetHandler(function(data, userID)
    userID = CAMERA_SYMBOL .. tostring(userID)

    if data.Deactive then
        CameraHelpers.SetCameraPosition(userID, nil)
        CameraHelpers.SetCameraRotation(userID, nil)
        return
    end

    CameraHelpers.SetCameraPosition(userID, data.CameraPosition)
    CameraHelpers.SetCameraRotation(userID, data.CameraRotation)
end)

NetChannel.UpdateDummies:SetHandler(function(data, userID)
    if data.Deactive then
        DummyHelpers.ClearDummyData()
        Debug("Clear server dummy data")
        return
    end

    for uuid, info in pairs(data.DummyInfos) do
        DummyHelpers.SetDummyPosition(uuid, info.Position)
        DummyHelpers.SetDummyRotation(uuid, info.Rotation)
    end
end)

NetChannel.PlayEffect:SetHandler(function(data, userID)
    RB_GLOBALS.EffectManager:PlayEffects(data)
end)

NetChannel.PlayEffect:SetRequestHandler(function(data, userID)
    return RB_GLOBALS.EffectManager:PlayEffects(data)
end)

NetChannel.StopEffect:SetHandler(function(data, userID)
    if data.Type == "All" then
        RB_GLOBALS.EffectManager:StopAllEffects()
    elseif data.Type == "FxName" then
        RB_GLOBALS.EffectManager:StopEffectByFxName(data.FxName)
    elseif data.Type == "Object" then
        RB_GLOBALS.EffectManager:StopEffectByObject(data.Object)
    elseif data.Type == "Both" then
        RB_GLOBALS.EffectManager:StopEffectByComb(data.FxName, data.Object)
    elseif data.Type == "Handles" then
        for i, handle in ipairs(data.Handles) do
            RB_GLOBALS.EffectManager:StopEffectByHandle(handle)
        end
    end
end)

NetChannel.CreateStat:SetHandler(function(data, userID)
    local eM = RB_GLOBALS.EffectManager

    --- @type table<string, table<string, fun(effectManager: RB_EffectsManager, data: any)>>
    local handler = {
        StatusData = {
            Play = eM.PlayStatus,
            Update = eM.UpdateStatus,
        },
        SpellData = {
            Play = eM.PlaySpell,
            Update = eM.UpdateSpell,
        }
    }
    data.Action = data.Action or "Play"

    local func = handler[data.Type] and handler[data.Type][data.Action]
    if not func then
        Warning("Invalid CreateStat request: " .. tostring(data.Type) .. " with action " .. tostring(data.Action))
        return
    end

    func(eM, data)
end)

NetChannel.StopStatus:SetHandler(function(data, userID)
    if data.Type == "All" then
        RB_GLOBALS.EffectManager:RemoveAllStatuses()
        return
    end

    RB_GLOBALS.EffectManager:RemoveStatus(data)
end)


NetChannel.GetAtmosphere:SetRequestHandler(function(data, userID)
    local trigger = ServerEntityHelpers.FindCurrentAtmosphereTrigger(data.Position)
    if not trigger then
        return { Guid = "", ResourceUUIDs = {} }
    end
    local atmosphereUuid = trigger.ServerAtmosphereTrigger.CurrentAtmosphereResourceID
    local allResources = RBUtils.LightCToArray(trigger.ServerAtmosphereTrigger.AtmosphereResourceIDs)
    local availableResources = {}
    for i, resUuuid in pairs(allResources) do
        availableResources[resUuuid] = true
    end
    return { Guid = atmosphereUuid, ResourceUUIDs = availableResources }
end)

NetChannel.GetLighting:SetRequestHandler(function(data, userID)
    local trigger = ServerEntityHelpers.FindCurrentLightingTrigger(data.Position)
    if not trigger then
        return { Guid = "", ResourceUUIDs = {} }
    end
    local lightingUuid = trigger.ServerLightingTrigger.CurrentLightingResourceID
    local allResources = RBUtils.LightCToArray(trigger.ServerLightingTrigger.LightingResourceIDs)
    local availableResources = {}
    for i, resUuuid in pairs(allResources) do
        availableResources[resUuuid] = true
    end
    return { Guid = lightingUuid, ResourceUUIDs = availableResources }
end)

NetChannel.SetAtmosphere:SetRequestHandler(function(data, userID)
    local toSet = data.ResourceUUID

    if data.Atmosphere then
        local currentAtmRes = Ext.Resource.Get(toSet, "Atmosphere") --[[@as ResourceAtmosphere]]
        if not currentAtmRes then
            Warning("Invalid atmosphere resource UUID: " .. tostring(toSet))
            return false
        end

        for k, v in pairs(data.Atmosphere) do
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
        local trigger = ServerEntityHelpers.FindCurrentAtmosphereTrigger(data.Position)
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

NetChannel.SetLighting:SetRequestHandler(function(data, userID)
    local toSet = data.ResourceUUID

    if data.Lighting then
        local currentLightRes = Ext.Resource.Get(toSet, "Lighting") --[[@as Lighting]]
        if not currentLightRes then
            Warning("Invalid lighting resource UUID: " .. tostring(toSet))
            return false
        end

        for k, v in pairs(data.Lighting) do
            currentLightRes.Lighting[k] = v
        end

        if data.Reset then
            local trigger = ServerEntityHelpers.FindCurrentLightingTrigger(data.Position)
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
        local trigger = ServerEntityHelpers.FindCurrentLightingTrigger(data.Position)
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

NetChannel.SetResource:SetHandler(function(data, userID)
    local res = Ext.Resource.Get(data.ResourceUUID, data.ResourceType)
    if not res then
        Warning("Resource not found: " .. tostring(data.ResourceUUID) .. " of type " .. tostring(data.ResourceType))
        return
    end

    for k, v in pairs(data.Data) do
        res[k] = v
    end
end)

local function callOsirisFunction(data)
    local func = data.Function
    local args = data.Args or {}

    if not Osi[func] then
        Warning("Osiris function not found: " .. tostring(func))
        return
    end

    return {Osi[func](table.unpack(args))}
end

NetChannel.CallOsiris:SetHandler(function(data, userID)
    callOsirisFunction(data)
end)

NetChannel.CallOsiris:SetRequestHandler(function(data, userID)
    return callOsirisFunction(data)
end)

NetChannel.SetServerEntity:SetHandler(function(data, userID)
    local entity = Ext.Entity.Get(data.Guid) --[[@as EntityHandle]]
    if not entity then return end
    for k, v in pairs(data.Data) do
        if entity[k] then
            for key, value in pairs(v) do
                entity[k][key] = value
            end
        end
    end
end)

NetChannel.GetServerEntity:SetRequestHandler(function(data, userID)
    local entity = Ext.Entity.Get(data.Guid) --[[@as EntityHandle]]
    if not entity then return { Guid = data.Guid, Data = {} } end

    data.Config = data.Config or {}
    local result = {}
    for k, v in pairs(data.Data) do
        if entity[k] then
            result[k] = {}
            if data.Config.GetAll then
                for key, value in pairs(entity[k]) do
                    if RBUtils.IsSerializable(value) then
                        result[k][key] = value
                        --elseif type(value) == "userdata" then
                        --    result[k][key] = DeepCopyAllSerializable(LightUserdataToTable(value))
                    end
                end
            else
                for key, _ in pairs(v) do
                    if RBUtils.IsSerializable(entity[k][key]) then
                        result[k][key] = entity[k][key]
                    end 
                end
            end
        end
    end

    return { Guid = data.Guid, Data = result }
end)

NetChannel.ClientTimer:SetHandler(function (data, userID)
    if not data.TimerID then
        Warning("ClientTimer: No TimerID provided")
        return
    end
    Timer:ReceiveClientTimer(data.TimerID)
end)