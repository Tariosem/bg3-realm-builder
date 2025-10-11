local NetListener = {}

---@param channelName any
---@param func fun(channel:string, data:any, userID:string)
function RegisterNetListener(channelName, func)
    NetListener[channelName .. ModuleUUID] = func
    Ext.RegisterNetListener(channelName .. ModuleUUID, function(channel, payload, userID)
        local data = Ext.Json.Parse(payload)
        if not data then
            Error("Invalid payload for channel: " .. channel .. " - " .. tostring(payload))
            return
        end

        NetListener[channel](channel, data, userID)
    end)
end

RegisterNetListener("OsirisRequest", function (channel, data, userID)
    PostTo(userID, "OsirisResponse_" .. data.RequestId, {Result = Osi[data.Function](table.unpack(data.Args))})
end)

RegisterNetListener("BunchOsirisRequest", function (channel, data, userID)
    local results = {}
    for _, call in ipairs(data.Calls or {}) do
        if call.Function and type(call.Function) == "string" and call.Args and type(call.Args) == "table" then
            results[#results + 1] = {Function = call.Function, Result = Osi[call.Function](table.unpack(call.Args))}
        end
    end
    PostTo(userID, "BunchOsirisResponse_" .. data.RequestId, {Results = results})
end)

RegisterNetListener("AddItem", function(channel, data, userID)
    Osi.TemplateAddTo(data.TemplateId, data.Target, data.Count, 1)
end)

RegisterNetListener(NetChannel.Spawn, function(channel, data, userID)
    local x, y, z = table.unpack(data.Position)
    local p, yaw, r, w = table.unpack(data.Rotation)

    if data.Type and data.Type == "Preview" then
        PreviewTemplate(data.TemplateId, x, y, z, p, yaw, r, w, data.VisualPreset)
        return
    end

    local templateId = data.TemplateId or data.Guid

    local guid = PM:CreateProp(templateId, x, y, z, p, yaw, r, w)
    if data.PropInfo then
        PM:SetProp(guid, data.PropInfo)
    end

    if guid then
        BroadcastProp(guid)
    end
end)

RegisterNetListener(NetChannel.Duplicate, function (channel, data, userID)
    local toDuplicate = NormalizeGuidList(data.Guid)

    local broadCastGuids = {}
    for _,guid in ipairs(toDuplicate) do
        local templateId = Osi.GetTemplate(guid) --[[@as string]]
        local x, y, z = Osi.GetPosition(guid) --[[@as number]]
        local p, yaw, r, w = GetQuatRotation(guid)

        local newGuid = PM:CreateProp(templateId, x, y, z, p, yaw, r, w)

        if newGuid then
            table.insert(broadCastGuids, newGuid)
        else
            Warning("Duplicate: Failed to create prop with templateId: " .. tostring(templateId))
        end
    end

    Timer:Ticks(10, function ()
        BroadcastProps(broadCastGuids)
    end)
end)

local previewStack = {}

RegisterNetListener("Preview", function (channel, data, userID)
    if data.Type and data.Type == "Clear" then
        for _, guid in ipairs(previewStack) do
            Osi.RequestDelete(guid)
        end
        previewStack = {}
        return
    end

    if data.Position then
        data.x, data.y, data.z = table.unpack(data.Position)
    end
    if data.Rotation then
        data.pitch, data.yaw, data.roll, data.w = table.unpack(data.Rotation)
    end

    local preview = Osi.CreateAt(data.TemplateId, data.x, data.y, data.z, 0, 0, "") --[[@as string]]
    RotateTo(preview, data.pitch or 0, data.yaw or 0, data.roll or 0, data.w or 1)

    Propify(preview)
    Osi.SetCanInteract(preview, 0)
    Osi.ClearTag(preview, LOP_PROP_TAG)
    table.insert(previewStack, preview)

    PostTo(userID, "PreviewProp", {Guid = preview, Type = "Preview"})
end)

RegisterNetListener(NetChannel.Delete, function (channel, data, userID)
    local toDelete = NormalizeGuidList(data.Guid)
    local deleted = {}
    for _, guid in ipairs(toDelete) do
        if guid and guid ~= "" and EntityExists(guid) then
            if PM.Props[guid] then
                if PM:DeleteProp(guid) then
                    table.insert(deleted, guid)
                end
            else
                Osi.RequestDelete(guid)
            end
        end
    end
    BroadcastDeletedProps(deleted)
end)


RegisterNetListener(NetChannel.SpawnPreset, function(channel, data, userID)
    if IsCamera(data.Parent) then data.Parent = data.Parent .. userID end
    local preset = data.PresetData

    if not preset then
        Error("SpawnPreset: Preset not found: " .. data.Name)
        return
    end
    local props = preset.Props or {}
    local presetType = preset.PresetType or "Relative"
    local broadCastGuids = {}
    if IsCamera(data.Parent) then
        SetCameraPosition(data.Parent, data.Position)
        SetCameraRotation(data.Parent, data.Rotation)
    end
    for _, prop in ipairs(props) do
        if not prop.TemplateId then
            goto continue
        end
        local templateId = prop.TemplateId
        local x, y, z = prop.Position[1] or nil, prop.Position[2] or nil, prop.Position[3] or nil
        local p, yaw, r, w = prop.Rotation[1] or 0, prop.Rotation[2] or 0, prop.Rotation[3] or 0, prop.Rotation[4] or 1

        if presetType == "Relative" then
            local pos, rot = GetLocalRelativeTransform(data.Parent, {x, y, z}, {p, yaw, r, w})
            if pos and rot then
                x, y, z = pos[1], pos[2], pos[3]
                p, yaw, r, w = rot[1], rot[2], rot[3], rot[4]
            else
                Warning("SpawnPreset: Failed to get final transform for parent: " .. tostring(data.Parent))
                goto continue
            end
        elseif _C().Level.LevelName ~= prop.LevelName then
            goto continue
        end
        
        if data.Type and data.Type == "Preview" then
            PreviewTemplate(templateId, x, y, z, p, yaw, r, w, prop.VisualPreset)
            goto continue
        end
    
        local guid = PM:CreateProp(templateId, x, y, z, p, yaw, r, w)

        if guid then
            if not prop.Group or prop.Group == "" then
                prop.Group = data.Name
            end
            PM:SetProp(guid, prop)
            table.insert(broadCastGuids, guid)
        else
            Warning("SpawnPreset: Failed to create prop with templateId: " .. tostring(templateId))
        end
        ::continue::
    end

    if #broadCastGuids > 0 then
        Timer:Ticks(10, function ()
            BroadcastProps(broadCastGuids)
        end)
    end
    if IsCamera(data.Parent) then
        SetCameraPosition(data.Parent, nil)
        SetCameraRotation(data.Parent, nil)
    end
end)

RegisterNetListener("ShareVisualPresetData", function(channel, data, userID)
    BroadcastToChannel("ServerViusalPreset", data)
end)

RegisterNetListener("SharePresetData", function(channel, data, userID)
    BroadcastToChannel("ServerPreset", data)
end)

RegisterNetListener("DeletePropsByTemplateId", function(channel, data, userID)

    local templateId = data.TemplateId
    local guids = PM:DeletePropByTemplateId(templateId)

    BroadcastDeletedProps(guids)
end)

RegisterNetListener("DeleteAllProps", function (channel, data, userID)
    local guids = PM:DeleteAll()

    BroadcastDeletedProps(guids)
end)

RegisterNetListener(NetChannel.SetTransform, function (channel, data, userID)

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

        ::continue::
        if BindManager then
            BindManager:UpdateOffset(guid)
        end
    end
end)

RegisterNetListener(NetChannel.Bind, function (channel, data, userID)
    if not BindManager then
        Warning("BindManager not initialized.")
        return
    end

    local tobind = NormalizeGuidList(data.Guid)

    --Debug("BindManager Request: ", data.Type, " Parent: ", data.Parent, " NotFollowParent: ", tostring(data.NotFollowParent), " KeepLookingAt: ", tostring(data.KeepLookingAt), " Count: ", tobind)

    for _, guid in ipairs(tobind) do
        if data.Type == "Unbind" then
            BindManager:Unbind(guid)
        elseif data.Type == "Bind" then
            if data.Parent and IsCamera(data.Parent) then data.Parent = data.Parent .. tostring(userID) end
            local success = BindManager:Bind(guid, data.Parent, data.NotFollowParent, data.KeepLookingAt)
            if not success then
                Warning("Bind failed: " .. tostring(guid) .. " to " .. tostring(data.Parent))
            end
        elseif data.Type == "SetType" then
            local bindData = BindManager.BindStores[guid]
            if bindData then
                if data.NotFollowParent ~= nil then bindData.NotFollowParent = data.NotFollowParent end
                if data.KeepLookingAt ~= nil then bindData.KeepLookingAt = data.KeepLookingAt end
                BindManager:UpdateOffset(guid)
            else
                BindManager:Unbind(guid)
                if data.Parent and IsCamera(data.Parent) then data.Parent = data.Parent .. tostring(userID)
                elseif not data.Parent then Warning("Bind SetType missing parent for: " .. tostring(guid)) end
                BindManager:Bind(guid, data.Parent, data.NotFollowParent, data.KeepLookingAt)
            end
        elseif data.Type == "UpdateOffset" then
            BindManager:UpdateOffset(guid)
        end
    end

    if data.Type == "UpdateOffset" then return end
    BindManager:BroadcastBindState(tobind)
end)

RegisterNetListener("UpdateCamera", function (channel, data, userID)

    userID = CameraSymbol .. tostring(userID)

    if data.Type == "DeactiveTimer" then
        SetCameraPosition(userID, nil)
        SetCameraRotation(userID, nil)
        return
    end

    SetCameraPosition(userID, data.CameraPosition)
    SetCameraRotation(userID, data.CameraRotation)
end)

RegisterNetListener("UpdateDummies", function (channel, data, userID)

    if data.DummyDestroyed then
        ClearDummyData()
        Debug("Clear server dummy data")
        return
    end

    for uuid, info in pairs(data.DummyInfos) do
        SetDummyPosition(uuid, info.Position)
        SetDummyRotation(uuid, info.Rotation)
    end
end)

RegisterNetListener(NetChannel.SetAttributes, function (channel, data, userID)
    local toSet = NormalizeGuidList(data.Guid)
    local gravity = data.Gravity
    local isVisible = data.Visible
    local canInteract = data.CanInteract
    local movable = data.Movable
    local persistent = data.Persistent

    for _, guid in ipairs(toSet) do
        if gravity ~= nil then
            if gravity then
                Osi.SetGravity(guid, 0)
            else
                Osi.SetGravity(guid, 1)
            end
        end
        if isVisible ~= nil then
            if isVisible then
                Osi.SetVisible(guid, 1)
            else
                Osi.SetVisible(guid, 0)
            end
        end
        if canInteract ~= nil then
            if canInteract then
                Osi.SetCanInteract(guid, 1)
            else 
                Osi.SetCanInteract(guid, 0)
            end
        end
        if movable ~= nil then
            if movable then
                Osi.SetMovable(guid, 1)
            else
                Osi.SetMovable(guid, 0)
            end
        end
        if persistent ~= nil and PM.Props[guid] then
            PM.Props[guid].Persistent = persistent
        end
    end

    BroadcastToChannel(NetMessage.AttributeChanged, {
        Guid = toSet,
        Gravity = gravity,
        Visible = isVisible,
        CanInteract = canInteract,
        Movable = movable,
        Persistent = persistent,
    })
end)

RegisterNetListener("PlayEffect", function (channel, data, userID)
    EM:PlayEffects(data)
end)

RegisterNetListener("StopEffect", function (channel, data, userID)

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

RegisterNetListener("ScanAllProps", function (channel, data, userID)
    PM:Scan()
end)

RegisterNetListener("BF_DeleteAll", function (channel, data, userID)
    local deletedGuids = PM:BF_DeleteAll()

    BroadcastDeletedProps(deletedGuids)
end)

RegisterNetListener("CreateStat", function (channel, data, userID)

    data.DisplayName = data.DisplayName .. tostring(userID)

    if data.Type == "StatusData" then
        EM:PlayStatus(data)
    elseif data.Type == "SpellData" then
        EM:PlaySpell(data)
    end
end)

RegisterNetListener("StopStatus", function (channel, data, userID)

    data.DisplayName = data.DisplayName .. tostring(userID)

    if data.Type == "All" then
        EM:RemoveAllStatuses()
        return
    end

    EM:RemoveStatus(data)
end)

RegisterNetListener("CaptureItem", function (channel, data, userID)
    local item = data.Guid

    Propify(item)

    Timer:Ticks(2, function()
        PM:AddProp(item)
        BroadcastProp(item)
    end)
end)

RegisterNetListener("ReleaseItem", function (channel, data, userID)
    local item = data.Guid

    PM:FreeProp(item)
end)

local gizmoUserStack = {}

RegisterNetListener(NetChannel.ManageGizmo, function (channel, data, userID)
    --Debug("ManageGizmo: Type: ", tostring(data.Type), " Guid: ", tostring(data.Guid), " GizmoType: ", tostring(data.GizmoType), " GizmoSpace: ", tostring(data.GizmoSpace))

    if data.Clear then
        local stack = gizmoUserStack[tostring(userID)] or {}
        if #stack == 0 then
            stack = BF_GetAllGizmos()
        end
        for _, guid in ipairs(stack) do
            Osi.RequestDelete(guid)
        end
        gizmoUserStack[tostring(userID)] = {}
        PostTo(userID, NetMessage.ServerGizmo, { Clear = true })
        return
    end

    if not Enums.TransformEditorMode[data.GizmoType] then
        Warning("ManageGizmo: Invalid GizmoType: " .. tostring(data.GizmoType))
        return
    end

    local guid = Osi.CreateAt(GIZMO_ITEM[data.GizmoType], 0,0,0,0,0,"") --[[@as string]]

    gizmoUserStack[tostring(userID)] = gizmoUserStack[tostring(userID)] or {}
    table.insert(gizmoUserStack[tostring(userID)], guid)

    PostTo(userID, NetMessage.ServerGizmo, {Guid = guid})
end)

local visualizeStack = {}
local lastColor = nil
local edges = {
    {1,2},{2,3},{3,4},{4,1},
    {5,6},{6,7},{7,8},{8,5},
    {1,5},{2,6},{3,7},{4,8},
}

RegisterNetListener(NetChannel.Visualize, function (channel, data, userID)
    local entityHandles = {}
    local duration = data.Duration or 3000

    if data.Type == "Box" then
        local min = data.Min
        local max = data.Max
        local corners = {
            {min[1], min[2], min[3]},
            {max[1], min[2], min[3]},
            {max[1], max[2], min[3]},
            {min[1], max[2], min[3]},
            {min[1], min[2], max[3]},
            {max[1], min[2], max[3]},
            {max[1], max[2], max[3]},
            {min[1], max[2], max[3]},
        }
        
        for _, edge in ipairs(edges) do
            local handle = DrawLine(corners[edge[1]], corners[edge[2]], userID)
            table.insert(entityHandles, handle)
        end
    elseif data.Type == "OBB" then
        local center = data.Position
        local halfSizes = data.HalfSizes
        local rotation = data.Rotation

        local localCorners = {
            { -halfSizes[1], -halfSizes[2], -halfSizes[3] },
            {  halfSizes[1], -halfSizes[2], -halfSizes[3] },
            {  halfSizes[1],  halfSizes[2], -halfSizes[3] },
            { -halfSizes[1],  halfSizes[2], -halfSizes[3] },
            { -halfSizes[1], -halfSizes[2],  halfSizes[3] },
            {  halfSizes[1], -halfSizes[2],  halfSizes[3] },
            {  halfSizes[1],  halfSizes[2],  halfSizes[3] },
            { -halfSizes[1],  halfSizes[2],  halfSizes[3] },
        }

        local worldCorners = {}
        local quat = Quat.new(rotation)
        for i, pt in ipairs(localCorners) do
            local rotated = quat:Rotate(pt)
            worldCorners[i] = {
                center[1] + rotated[1],
                center[2] + rotated[2],
                center[3] + rotated[3]
            }
        end

        for _, edge in ipairs(edges) do
            local handle = DrawLine(worldCorners[edge[1]], worldCorners[edge[2]], userID)
            table.insert(entityHandles, handle)
        end
    elseif data.Type == "Point" then
        local pos = data.Position
        local pointEntity = Osi.CreateAt(LOP_PROP_AXIS_FX, pos[1], pos[2], pos[3], 0, 0, "") --[[@as string]]
        if data.Rotation then
            RotateTo(pointEntity, table.unpack(data.Rotation))
        end
        table.insert(entityHandles, pointEntity)

        if data.Scale then
            Osi.SetVisible(pointEntity, 0)
            Timer:Ticks(10, function()
                BroadcastToChannel(NetMessage.SetVisualTransform, {
                    Guid = pointEntity,
                    Transforms = {
                        [pointEntity] = {
                            Scale = data.Scale
                        }
                    }
                })
                Osi.SetVisible(pointEntity, 1)
            end)
        end
    elseif data.Type == "Scale" then
        local pos = data.Position
        local scale = data.Scale or 1.0
        local pointEntity = Osi.CreateAt(GIZMO_ITEM.Scale, pos[1], pos[2], pos[3], 0, 0, "") --[[@as string]]
        if data.Rotation then
            RotateTo(pointEntity, table.unpack(data.Rotation))
        end
        Osi.SetVisible(pointEntity, 0)
        table.insert(entityHandles, pointEntity)
    elseif data.Type == "Line" then
        local handle = DrawLine(data.Position, data.EndPosition, userID)
        table.insert(entityHandles, handle)
        if data.Color and not EqualArrays(data.Color, lastColor or {}) then
            Timer:Ticks(10, function()
                BroadcastToChannel(NetMessage.SetLineColor, {
                    Guid = handle,
                    Color = data.Color
                })
            end)
        end
    elseif data.Type == "Ring" then
        local handle = Osi.CreateAt(GIZMO_ITEM.Rotate, data.Position[1], data.Position[2], data.Position[3], 0, 0, "")
        RotateTo(handle, table.unpack(data.Rotation or {0,0,0,1}))
        table.insert(entityHandles, handle)
    elseif data.Type == "Clear" then
        Debug("Clear visualize for user: " .. tostring(userID))
        local stack = visualizeStack[tostring(userID)]
        for _, handles in ipairs(stack or {}) do
            for _, hhandle in ipairs(handles) do
                Osi.RequestDelete(hhandle)
            end
        end
        visualizeStack[tostring(userID)] = {}
        return
    end

    if duration <= 0 then
        visualizeStack[tostring(userID)] = visualizeStack[tostring(userID)] or {}
        local stack = visualizeStack[tostring(userID)]
        table.insert(stack, entityHandles)
        PostTo(userID, NetMessage.Visualization, { Guid = entityHandles, RequestId = data.RequestId })
    else
        Timer:After(duration, function()
            for _, handle in ipairs(entityHandles) do
                Osi.RequestDelete(handle)
            end
        end)
    end
end)

RegisterNetListener("SetDebugLevel", function (channel, data, userID)
    SetDebugLevel(data.Level or 0)
end)

Ext.ModEvents.BG3MCM["MCM_Setting_Saved"]:Subscribe(function(payload)
    if not payload or payload.modUUID ~= ModuleUUID or not payload.settingId then
        return
    end

    if payload.settingId == "slider_int_debug_level" then
        --Info("Debug level setting changed to: " .. tostring(payload.value))
        SetDebugLevel(payload.value)
        BroadcastToChannel("SetDebugLevel", payload)
    end
end)