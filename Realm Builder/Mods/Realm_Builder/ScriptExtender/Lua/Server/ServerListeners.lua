NetChannel.Spawn:SetHandler(function(data, userID)
    local template = data.TemplateId
    local position = data.Position
    local rotation = data.Rotation
    local entInfo = data.EntInfo
    local rtype = data.Type

    if rtype == "Preview" then
        local previewItem = PreviewTemplate(template, table.unpack(position), table.unpack(rotation), entInfo and entInfo.VisualPreset)
        return
    end

    local newGuid = EntityManager:CreateAt(template, position[1], position[2], position[3], rotation[1], rotation[2], rotation[3], rotation[4])

    if not newGuid then Warning("") return end

    EntityManager:SetEntity(newGuid, entInfo or {})

    entInfo.Visible = true
    entInfo.Guid = newGuid
    entInfo.TemplateId = template

    NetChannel.Entities.Added:Broadcast({Entities = {entInfo}})
end)

NetChannel.Spawn:SetRequestHandler(function(data, userID)
    local template = data.TemplateId
    local position = data.Position
    local rotation = data.Rotation
    local entInfo = data.EntInfo
    local rtype = data.Type

    if rtype == "Preview" then
        local previewItem = PreviewTemplate(template, table.unpack(position), table.unpack(rotation), entInfo and entInfo.VisualPreset)
        return {Guid = previewItem, TemplateId = template}
    end

    local newGuid = EntityManager:CreateAt(template, position[1], position[2], position[3], rotation[1], rotation[2], rotation[3], rotation[4])

    if not newGuid then
        Warning("Spawn: Failed to create entity at position.")
        return {Guid = nil, TemplateId = template}
    end

    EntityManager:SetEntity(newGuid, entInfo or {})

    entInfo.Visible = true
    entInfo.Guid = newGuid
    entInfo.TemplateId = template

    NetChannel.Entities.Added:Broadcast({Entities = {entInfo}})

    return {Guid = newGuid, TemplateId = Osi.GetTemplate(newGuid)}
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

NetChannel.Delete:SetHandler(function(data, userID)
    local guids = NormalizeGuidList(data.Guid)
    for _,guid in pairs(guids) do
        if EntityManager.TaggedEntities[guid] then
            EntityManager:DeleteEntity(guid)
        else
            Osi.RequestDelete(guid)
        end
    end

    if data.Type == "DeleteAll" then
        EntityManager:DeleteAll()
    elseif data.Type == "DeleteByTemplateId" and data.TemplateId then
        EntityManager:DeleteEntityByTemplateId(data.TemplateId)
    end
end)

NetChannel.AddItem:SetHandler(function(data)
    Osi.TemplateAddTo(data.TemplateId, data.Target, data.Count, 1)
end)

NetChannel.GetTemplate:SetRequestHandler(function(data, userID)
    local guid = data.Guid

    local template = Osi.GetTemplate(guid)

    return {Success = true, Template = template}
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
    RotateTo(preview, rotation[1], rotation[2], rotation[3], rotation[4])
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
        if data.Guid then
            EntityManager:DeleteEntity(data.Guid)
        end
    elseif action == "Clear" then
        EntityManager:Clear()
    elseif action == "Scan" then
        local newEntities = EntityManager:Scan()
        NetChannel.Entities.Added:Broadcast({Entities = newEntities})
    elseif action == "BFDA" then
        EntityManager:BF_DeleteAll()
    end
end)

NetChannel.SetTransform:SetHandler(function(data, userID)
    local toSet = NormalizeGuidList(data.Guid)
    for _, guid in ipairs(toSet) do
        local transform = data.Transforms[guid]
        if not transform then goto continue end

        if transform.Translate and #transform.Translate == 3 then
            TeleportTo(guid, transform.Translate[1], transform.Translate[2], transform.Translate[3])
        end
        if transform.RotationQuat and #transform.RotationQuat == 4 then
            RotateTo(guid, transform.RotationQuat[1], transform.RotationQuat[2], transform.RotationQuat[3], transform.RotationQuat[4])
        end
        if transform.Scale and #transform.Scale == 3 then
            NetChannel.SetVisualTransform:Broadcast({Guid = guid, Transforms = {[guid] = {Scale = transform.Scale}}})
        end

        ::continue::
        if BindManager then
            BindManager:UpdateOffset(guid)
        end
    end
end)

NetChannel.SetTransform:SetRequestHandler(function(data, userID)
    local toSet = NormalizeGuidList(data.Guid)
    for _, guid in ipairs(toSet) do
        local transform = data.Transforms[guid]
        if not transform then goto continue end

        if transform.Translate and #transform.Translate == 3 then
            TeleportTo(guid, table.unpack(transform.Translate))
        end
        if transform.RotationQuat and #transform.RotationQuat == 4 then
            RotateTo(guid, table.unpack(transform.RotationQuat))
        end
        if transform.Scale and #transform.Scale == 3 then
            NetChannel.SetVisualTransform:Broadcast({Guid = guid, Transforms = {[guid] = {Scale = transform.Scale}}})
        end


        ::continue::
        if BindManager then
            BindManager:UpdateOffset(guid)
        end
    end

    return { } --finished
end)

NetChannel.Replicate:SetHandler(function (data, userID)

    for _, guid in ipairs(NormalizeGuidList(data.Guid)) do
        local entity = Ext.Entity.Get(guid) --[[@as EntityHandle]]
        entity:Replicate(data.Field)
    end
    
end)

NetChannel.SpawnPreset:SetHandler(function(data, userID)
    if IsCamera(data.Parent) then data.Parent = data.Parent .. userID end
    local preset = data.PresetData

    if not preset then
        Error("SpawnPreset: Preset not found: " .. data.Name)
        return
    end
    local presetType = preset.PresetType or "Relative"
    local broadCastData = {}
    if IsCamera(data.Parent) then
        SetCameraPosition(data.Parent, data.Position)
        SetCameraRotation(data.Parent, data.Rotation)
    end
    local tree = nil --[[@as TreeTable]]
    if preset.Tree then
        tree = TreeTable.FromTableStatic(preset.Tree)
    else
        Warning("SpawnPreset: Preset tree not found: " .. data.Name)
    end

    local spawneds = preset.Spawned

    for savedguid, ent in pairs(spawneds) do
        if not ent.TemplateId then
            goto continue
        end
        local templateId = ent.TemplateId
        local x, y, z = ent.Position[1] or nil, ent.Position[2] or nil, ent.Position[3] or nil
        local p, yaw, r, w = ent.Rotation[1] or 0, ent.Rotation[2] or 0, ent.Rotation[3] or 0, ent.Rotation[4] or 1

        if presetType == "Relative" then
            local pos, rot = GetLocalRelativeTransform(data.Parent, {x, y, z}, {p, yaw, r, w})
            if pos and rot then
                x, y, z = pos[1], pos[2], pos[3]
                p, yaw, r, w = rot[1], rot[2], rot[3], rot[4]
            else
                Warning("SpawnPreset: Failed to get final transform for parent: " .. tostring(data.Parent))
                goto continue
            end
        elseif _C().Level.LevelName ~= ent.LevelName then
            goto continue
        end
        
        if data.Type and data.Type == "Preview" then
            PreviewTemplate(templateId, x, y, z, p, yaw, r, w, ent.VisualPreset)
            goto continue
        end
    
        local guid = EntityManager:CreateAt(templateId, x, y, z, p, yaw, r, w)
        if tree then
            ent.Path = tree:GetPath(savedguid, true) or nil
        end

        if guid then
            if not ent.Group or ent.Group == "" then
                ent.Group = data.Name
            end
            ent.Guid = guid
            EntityManager:SetEntity(guid, ent)
            table.insert(broadCastData, ent)
        else
            Warning("SpawnPreset: Failed to create prop with templateId: " .. tostring(templateId))
        end
        ::continue::
    end

    if #broadCastData > 0 then
        Timer:Ticks(10, function ()
            NetChannel.Entities.Added:Broadcast({ Entities = broadCastData })
        end)
    end
    if IsCamera(data.Parent) then
        SetCameraPosition(data.Parent, nil)
        SetCameraRotation(data.Parent, nil)
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


        local pointEntity = Osi.CreateAt(RB_PROP_AXIS_FX, pos[1], pos[2], pos[3], 0, 0, "") --[[@as string]]
        table.insert(entityHandles, pointEntity)
        if data.Rotation then
            RotateTo(pointEntity, table.unpack(data.Rotation))
        end

        -- prevent jump scare
        Osi.SetVisible(pointEntity, 0)
        Timer:Ticks(10, function (timerID)
            Osi.SetVisible(pointEntity, 1)
        end)

    elseif data.Type == "Line" then
        local startPos = data.Position
        local endPos = data.EndPosition
        local handle = OsirisHelpers.DrawLine(startPos, endPos, data.Width)
        table.insert(entityHandles, handle)
    elseif data.Type == "Box" then
        entityHandles = OsirisHelpers.DrawBox(data.Min, data.Max, data.Width)
    elseif data.Type == "OBB" then
        entityHandles = OsirisHelpers.DrawOrientedBox(data.Position, data.HalfSizes, data.Rotation, data.Width)
    elseif data.Type == "Clear" then
        local existing = spawnedVisualizations[userID]
        for _,e in pairs(existing) do
            Osi.RequestDelete(e)
        end
        spawnedVisualizations[userID] = {}
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

    if not Enums.TransformEditorMode[data.GizmoType] then
        return { Guid = nil }
    end

    data.Position = data.Position or {0,0,0}
    if #data.Position ~= 3 then
        data.Position = {0,0,0}
    end

    local guid = Osi.CreateAt(GIZMO_ITEM[data.GizmoType], data.Position[1], data.Position[2], data.Position[3], 0, 0, "") --[[@as string]]
    Osi.SetVisible(guid, 0)

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

    data.DisplayName = data.DisplayName .. tostring(userID)

    if data.Type == "All" then
        EM:RemoveAllStatuses()
        return
    end

    EM:RemoveStatus(data)
end)