OsirisHelpers = OsirisHelpers or {}

function OsirisHelpers.Propify(guids)
    local targets = NormalizeGuidList(guids)
    for _, guid in ipairs(targets) do
        Osi.SetGravity(guid, 1)
        Osi.SetCanInteract(guid, 1)
        Osi.SetVisible(guid, 1)
        Osi.SetMovable(guid, 1)
        Osi.SetTag(guid, LOP_PROP_TAG)
        Osi.SetCanFight(guid, 0)
        Osi.SetCanJoinCombat(guid, 0)
        Osi.ClearTag(guid, LOP_GIZMO_TAG)
    end
end

function OsirisHelpers.DrawLine(startPos, endPos, lineThickness)
    if #startPos ~= 3 or #endPos ~= 3 then
        return
    end
    local dir = Ext.Math.Sub(startPos, endPos) -- beam's default direction is -z
    local length = Ext.Math.Length(dir) -- beam's default length is 10

    local toScale = length / 10

    local fxHandle = Osi.CreateAt(LOP_BEAM_ITEM_FX, 0, 0, 0, 0, 0, "") --[[@as string]]

    Osi.SetVisible(fxHandle, 0)
    Timer:Ticks(10, function (timerID)
        if not EntityExists(fxHandle) then return end
        
        TeleportTo(fxHandle, startPos[1], startPos[2], startPos[3])
        RotateTo(fxHandle, table.unpack(DirectionToQuat(dir)))

        NetChannel.SetVisualTransform:Broadcast({
            Guid = fxHandle,
            Transforms = {
                [fxHandle] = {
                    Scale = {0.3 * (lineThickness or 1) , 0.3 * (lineThickness or 1), toScale},
                }
            }
        })
        Osi.SetVisible(fxHandle, 1)
    end)

    return fxHandle
end

local edges = {
    {1,2}, {2,3}, {3,4}, {4,1},
    {5,6}, {6,7}, {7,8}, {8,5},
    {1,5}, {2,6}, {3,7}, {4,8}
}

---@param min Vec3
---@param max Vec3
---@return GUIDSTRING[] spawned
function OsirisHelpers.DrawBox(min, max, LineThickness)
    local spawned = {}
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
        local handle = OsirisHelpers.DrawLine(corners[edge[1]], corners[edge[2]], LineThickness)
        table.insert(spawned, handle)
    end

    return spawned
end

--- @param center Vec3
--- @param halfSizes Vec3
--- @param rotation Quat
--- @return GUIDSTRING[] spawned
function OsirisHelpers.DrawOrientedBox(center, halfSizes, rotation, LineThickness)
    local spawned = {}
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
        local handle = OsirisHelpers.DrawLine(worldCorners[edge[1]], worldCorners[edge[2]], LineThickness)
        table.insert(spawned, handle)
    end

    return spawned
end

function TeleportTo(uuid, x, y, z)
    if not uuid then
        Warning("Called TeleportTo with Invalid item")
        return false
    end
    if not x or not y or not z then
        Warning("Called TeleportTo with Invalid position")
        return false
    end

    if not EntityExists(uuid) then
        --Warning("TeleportTo: Entity does not exist: " .. tostring(uuid))
        return false
    end

    Osi.ToTransform(uuid, x, y, z, Osi.GetRotation(uuid))

    --Trace("Item teleported to position: " .. tostring(x) .. ", " .. tostring(y) .. ", " .. tostring(z))
    return true
end

function TeleportToTarget(uuid, targetUuid)
    if not uuid or not targetUuid then
        Warning("Called TeleportToTarget with Invalid item or target")
        return false
    end

    Osi.TeleportTo(uuid, targetUuid)
    --Trace("Item teleported to target position: " .. tostring(tx) .. ", " .. tostring(ty) .. ", " .. tostring(tz))
    return true
end

function RotateTo(guid, rx, ry, rz, w)
    if not guid then
        Warning("Called RotateTo with Invalid item")
        return false
    end

    local entity = UuidToHandle(guid)
    if not entity then
        return false
    end
    local transform = entity.Transform.Transform
    transform.RotationQuat = {rx or 0, ry or 0, rz or 0, w or 1}

    TeleportTo(guid, CGetPosition(guid))

    return true
end

SpawnedTemplates = {}

function PreviewTemplate(templateId, x, y, z, p, yaw, r, w, visualPreset)
    if not x or not y or not z then
        x, y, z = GetHostPosition()
    end
    if not p or not yaw or not r or not w then
        p, yaw, r, w = 0, 0, 0, 1
    end

    local templateName = TrimTail(templateId, 37)
    if templateName == "" then
        templateName = templateId
    end

    local preview = Osi.CreateAt(templateId, x, y, z, 0, 0, "") --[[@as string]]

    if not preview then
        Error("Failed to create preview for template: " .. tostring(templateId))
        return
    end

    RotateTo(preview, p, yaw, r, w)

    OsirisHelpers.Propify(preview)
    Osi.SetCanInteract(preview, 0)
    Osi.ClearTag(preview, LOP_PROP_TAG)

    if not SpawnedTemplates[templateName] then
        Timer:After(400, function ()
            NetChannel.NewTemplate:Broadcast({Guid=preview, TemplateName=templateName})
            SpawnedTemplates[templateName] = true
        end)
    end

    Timer:After(500, function ()
        NetChannel.ApplyVisualPreset:Broadcast({ Guid=preview, TemplateName=templateName, VisualPreset=visualPreset })
    end)
    
    Timer:After(10000, function ()
        Osi.RequestDelete(preview)
    end)
end

