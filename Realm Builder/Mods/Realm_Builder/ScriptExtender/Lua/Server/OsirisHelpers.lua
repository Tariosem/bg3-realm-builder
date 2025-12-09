--- @class OsirisHelpers
--- @field Propify fun(guids: GUIDSTRING|GUIDSTRING[])
--- @field DrawLine fun(startPos: Vec3, endPos: Vec3, width:number, user:number):GUIDSTRING?
--- @field DrawBox fun(min:Vec3, max:Vec3, LineThickness:number, user:number):GUIDSTRING[]
--- @field DrawOrientedBox fun(center:Vec3, halfSizes:Vec3, rotation: Quat, LineThickness:number, user:number):GUIDSTRING[]
--- @field TeleportTo fun(uuid:GUIDSTRING, x:number, y:number, z:number):boolean
--- @field TeleportToTarget fun(uuid:GUIDSTRING, targetUuid:GUIDSTRING):boolean
--- @field RotateTo fun(guid:GUIDSTRING, rx:number, ry:number, rz:number, w:number):boolean
--- @field ScaleTo fun(guid:GUIDSTRING, sx:number, sy:number, sz:number):boolean
--- @field ToTransform fun(guid:GUIDSTRING, transform:Transform):boolean
--- @field PreviewTemplate fun(templateId:string, x:number, y:number, z:number, p:number, yaw:number, r:number, w:number, visualPreset:string):string?
OsirisHelpers = OsirisHelpers or {}

function OsirisHelpers.Propify(guids)
    local targets = RBUtils.NormalizeGuidList(guids)
    for _, guid in ipairs(targets) do
        Osi.SetGravity(guid, 1)
        Osi.SetCanInteract(guid, 1)
        Osi.SetVisible(guid, 1)
        --Osi.SetMovable(guid, 1)
        Osi.SetTag(guid, RB_PROP_TAG)
        Osi.SetCanFight(guid, 0)
        Osi.SetCanJoinCombat(guid, 0)
    end
end

function OsirisHelpers.DrawLine(startPos, endPos, width, user)
    if #startPos ~= 3 or #endPos ~= 3 then
        return nil
    end
    local dir = Ext.Math.Sub(startPos, endPos) -- beam's default direction is -z
    local length = Ext.Math.Length(dir) -- beam's default length is 10

    local toScale = length / 10

    local fxHandle = Osi.CreateAt(RB_BEAM_ITEM_FX, 0, 0, 0, 1, 0, "") --[[@as string]]
    OsirisHelpers.TeleportTo(fxHandle, startPos[1], startPos[2], startPos[3])
    OsirisHelpers.RotateTo(fxHandle, table.unpack(MathUtils.DirectionToQuat(dir)))
    Timer:Ticks(10, function (timerID)
        if not EntityHelpers.EntityExists(fxHandle) then return end

        NetChannel.SetVisualTransform:Broadcast({
            Guid = fxHandle,
            Transforms = {
                [fxHandle] = {
                    Scale = {0, 0, 0},
                }
            }
        })

        NetChannel.SetVisualTransform:SendToClient({
            Guid = fxHandle,
            Transforms = {
                [fxHandle] = {
                    Scale = {1 * (width or 1) , 1 * (width or 1), toScale},
                }
            }
        }, user)
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
function OsirisHelpers.DrawBox(min, max, LineThickness, user)
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
        local handle = OsirisHelpers.DrawLine(corners[edge[1]], corners[edge[2]], LineThickness, user)
        table.insert(spawned, handle)
    end

    return spawned
end

--- @param center Vec3
--- @param halfSizes Vec3
--- @param rotation Quat
--- @return GUIDSTRING[] spawned
function OsirisHelpers.DrawOrientedBox(center, halfSizes, rotation, LineThickness, user)
    local spawned = {}
    --- @type Vec3[]
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
        local handle = OsirisHelpers.DrawLine(worldCorners[edge[1]], worldCorners[edge[2]], LineThickness, user)
        table.insert(spawned, handle)
    end

    return spawned
end

function OsirisHelpers.TeleportTo(uuid, x, y, z)
    if not uuid then
        Warning("Called TeleportTo with Invalid item")
        return false
    end
    if not x or not y or not z then
        Warning("Called TeleportTo with Invalid position")
        return false
    end

    local rx, ry, rz = Osi.GetRotation(uuid)
    if not rx or not ry or not rz then
        rx, ry, rz = 0, 0, 0
    end
    
    Osi.ToTransform(uuid, x, y, z, rx, ry, rz)

    --Trace("Item teleported to position: " .. tostring(x) .. ", " .. tostring(y) .. ", " .. tostring(z))
    return true
end

function OsirisHelpers.TeleportToTarget(uuid, targetUuid)
    if not uuid or not targetUuid then
        Warning("Called TeleportToTarget with Invalid item or target")
        return false
    end

    Osi.TeleportTo(uuid, targetUuid)
    --Trace("Item teleported to target position: " .. tostring(tx) .. ", " .. tostring(ty) .. ", " .. tostring(tz))
    return true
end

function OsirisHelpers.RotateTo(guid, rx, ry, rz, w)
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

    --- @diagnostic disable-next-line: param-type-mismatch
    OsirisHelpers.TeleportTo(guid, RBGetPosition(guid))

    return true
end

function OsirisHelpers.ScaleTo(guid, sx, sy, sz)
    if not guid then
        Warning("Called ScaleTo with Invalid item")
        return false
    end

    local entity = UuidToHandle(guid)
    if not entity then
        return false
    end
    local transform = entity.Transform.Transform
    transform.Scale = {sx or 1, sy or 1, sz or 1}

    --- @diagnostic disable-next-line: param-type-mismatch
    OsirisHelpers.TeleportTo(guid, RBGetPosition(guid))

    return true
end

function OsirisHelpers.ToTransform(guid, transform)
    if not guid then
        Warning("Called ToTransform with Invalid item")
        return false
    end

    local entity = UuidToHandle(guid)
    if not entity then
        return false
    end
    entity.Transform.Transform = transform

    OsirisHelpers.TeleportTo(guid, transform.Translate[1], transform.Translate[2], transform.Translate[3])
    return true
    
end

function OsirisHelpers.PreviewTemplate(templateId, x, y, z, p, yaw, r, w, visualPreset, duration)
    if not x or not y or not z then
        x, y, z = GetHostPosition()
    end
    if not p or not yaw or not r or not w then
        p, yaw, r, w = 0, 0, 0, 1
    end

    local templateName = RBStringUtils.TrimTail(templateId, 37)
    if templateName == "" then
        templateName = templateId
    end

    local spawnTemplate = templateId --[[@as string?]]
    local templateObj = Ext.Template.GetTemplate(EntityHelpers.TakeTailTemplate(templateId))
    local tempoFlag = 0
    spawnTemplate, tempoFlag = EntityManager.TemplateTrick(templateObj, templateId)
    if not spawnTemplate then
        Error("Failed to create preview for template: " .. tostring(templateId))
        return
    end

    local preview = Osi.CreateAt(spawnTemplate, x, y, z, tempoFlag, 0, "") --[[@as string]]
    if not preview then
        Error("Failed to create preview for template: " .. tostring(templateId))
        return
    end

    OsirisHelpers.RotateTo(preview, p, yaw, r, w)
    OsirisHelpers.Propify(preview)
    Osi.SetCanInteract(preview, 0)
    Osi.ClearTag(preview, RB_PROP_TAG)
    RB_FlagHelpers.SetFlag(preview, "DeleteLater")
    
    if visualPreset then
        Timer:After(500, function ()
            NetChannel.ApplyVisualPreset:Broadcast({ Guid=preview, TemplateName=templateName, VisualPreset=visualPreset })
        end)
    end
    
    if duration > 0 then
        Timer:After(duration, function ()
            Osi.RequestDelete(preview)
            Osi.RequestDeleteTemporary(preview)
        end)
    end
    return preview
end

