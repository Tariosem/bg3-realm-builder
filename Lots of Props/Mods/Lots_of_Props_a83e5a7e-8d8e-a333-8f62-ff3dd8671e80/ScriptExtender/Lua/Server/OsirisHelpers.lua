function Propify(arg)
    if type(arg) == "table" and #arg > 0 then
        for _, item in ipairs(arg) do
            if item then
                Propify(item)
                --Trace("Propified item: " .. tostring(item))
            else
                Warning("Item is nil in items list")
            end
        end
        return true
    elseif arg ~= nil then
        Osi.SetGravity(arg, 1)
        Osi.SetCanInteract(arg, 1)
        Osi.SetVisible(arg, 1)
        Osi.SetMovable(arg, 1)
        Osi.SetTag(arg, LOP_PROP_TAG)
        Osi.SetCanFight(arg, 0)
        Osi.SetCanJoinCombat(arg, 0)
        Osi.ClearTag(arg, LOP_GIZMO_TAG)
        return true
    else
        Error("Propify: input is nil or invalid")
        return false
    end
end

function DrawLine(startPos, endPos, userID)
    if #startPos ~= 3 or #endPos ~= 3 then
        return
    end
    local dir = Ext.Math.Sub(startPos, endPos) -- beam's default direction is -z
    local length = Ext.Math.Length(dir) -- beam's default length is 10

    local toScale = length / 10

    local fxHandle = Osi.CreateAt(LOP_BEAM_ITEM_FX, 0, 0, 0, 0, 0, "") --[[@as string]]

    Osi.SetVisible(fxHandle, 0)
    Timer:Ticks(10, function (timerID)
        if not EntityExists(fxHandle) then
            return
        end
        
        TeleportTo(fxHandle, startPos[1], startPos[2], startPos[3])
        RotateTo(fxHandle, table.unpack(DirectionToQuat(dir)))

        BroadcastToChannel(NetMessage.SetVisualTransform, {
            Guid = fxHandle,
            Transforms = {
                [fxHandle] = {
                    Scale = {0, 0, 0}
                }
            }
        })
        PostTo(userID, NetMessage.SetVisualTransform, {
            Guid = fxHandle,
            Transforms = {
                [fxHandle] = {
                    Scale = {0.5, 0.5, toScale}
                }
            }
        })
        Osi.SetVisible(fxHandle, 1)
    end)

    return fxHandle
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

function RotateTo(guid, pitch, yaw, roll, w)
    if not guid then
        Warning("Called RotateTo with Invalid item")
        return false
    end

    local entity = UuidToHandle(guid)
    local transform = entity.Transform.Transform
    transform.RotationQuat = {pitch or 0, yaw or 0, roll or 0, w or 1}

    TeleportTo(guid, CGetPosition(guid))

    return true
end

function SetTransform(guid, position, rotation)
    if not guid then
        Warning("Called SetTransform with Invalid item")
        return false
    end

    local entity = UuidToHandle(guid)
    if not entity then
        Warning("SetTransform: Entity not found for GUID: " .. tostring(guid))
        return false
    end

    if position then
        entity.Transform.Transform.Translate = {position[1], position[2], position[3]}
    end
    if rotation then
        entity.Transform.Transform.RotationQuat = {rotation[1], rotation[2], rotation[3], rotation[4]}
    end

    TeleportTo(guid, table.unpack(entity.Transform.Transform.Translate))

    return true
end

function SetTemplateScale(templateId, scale)
    local uuid = templateId
    if #templateId > 36 then
        uuid = TakeTail(templateId, 36)
    end
    local templateObject = Ext.ServerTemplate.GetTemplate(uuid)
    if not templateObject then
        Error("SetTemplateScale: Template not found for UUID: " .. tostring(uuid))
        return false
    end

    local transform = templateObject.Transform
    if not transform then
        Error("SetTemplateScale: Transform not found in template for UUID: " .. tostring(uuid))
        return false
    end

    transform.Scale = {scale, scale, scale}
    --Info("Template scale set to " .. tostring(scale) .. " for UUID: " .. tostring(uuid))
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

    local preview = Osi.CreateAt(templateId, x, y, z, 0, 0, "")

    if not preview then
        Error("Failed to create preview for template: " .. tostring(templateId))
        return
    end

    RotateTo(preview, p, yaw, r, w)

    Propify(preview)
    Osi.SetCanInteract(preview, 0)

    Osi.ClearTag(preview, LOP_PROP_TAG)

    if not SpawnedTemplates[templateName] then
        Timer:After(400, function ()
            BroadcastToChannel("NewTemplate", {Guid=preview, TemplateName=templateName})
            SpawnedTemplates[templateName] = true
        end)
    end

    Timer:After(500, function ()
        BroadcastVisualPreset(preview, templateName, visualPreset)
    end)
    
    Timer:After(10000, function ()
        Osi.RequestDelete(preview)
    end)
end

