PickingUtils = {
    GuidRedirects = {},
}

--- for markers
function PickingUtils:RegisterGuidRedirect(fromGuid, toGuid)
    self.GuidRedirects[fromGuid] = toGuid
end

--- @return GUIDSTRING|nil
function PickingUtils.GetPickingGuid()
    local pickHandle = Ext.ClientUI.GetPickingHelper(1).Inner.Inner[1].GameObject

    if pickHandle then
        local pickUuid = HandleToUuid(pickHandle)
        if pickUuid then
            if PickingUtils.GuidRedirects[pickUuid] then
                pickUuid = PickingUtils.GuidRedirects[pickUuid]
            end
            return pickUuid
        end
    end

    local mouseRay = ScreenToWorldRay()
    local returnGuid = nil
    local entity = nil

    if not mouseRay then return nil end
    local allPartyMembers = EntityHelpers.GetAllPartyMembers()
    local closestPartyMemberhit = nil
    for _, guid in ipairs(allPartyMembers) do
        local member = DummyHelpers.GetDummyByUuid(guid) or Ext.Entity.Get(guid) --[[@as EntityHandle]]

        local hit = mouseRay:IntersectEntity(member)
        if hit and (not closestPartyMemberhit or hit:IsCloserThan(closestPartyMemberhit)) then
            closestPartyMemberhit = hit
            returnGuid = guid
            --Debug("Picked party member: " .. Ext.Entity.Get(guid).DisplayName.Name:Get())
        end
    end

    if PickingUtils.GuidRedirects[returnGuid] then
        returnGuid = PickingUtils.GuidRedirects[returnGuid]
    end
    return returnGuid
end

function PickingUtils.GetPickingEntity()
    return Ext.ClientUI.GetPickingHelper(1).Inner.Inner[1].GameObject
end

---@param picker EclPlayerPickingHelper?
---@return number x
---@return number y
function PickingUtils.GetCursorPos(picker)
    if not picker then
        picker = Ext.ClientUI.GetPickingHelper(1)
    end
    if not picker then
        return 0, 0
    end
    local pos = picker.WindowCursorPos
    return pos[1], pos[2]
end

--- Returns the hit position and rotation from the picking helper
--- rotation is Y axis aligned to the hit normal
--- @param picker EclPlayerPickingHelper?
--- @return Vec3?
--- @return Quat?
function PickingUtils.GetPickingHitPosAndRot(picker)
    if not picker then
        picker = Ext.ClientUI.GetPickingHelper(1)
    end
    local pos = picker.Inner.SceneryPosition
    local normal = picker.Inner.SceneryNormal
    local rot = MathUtils.DirectionToQuat(normal, nil, "Y")

    pos = Vec3.new(pos) --[[@as Vec3]]

    if not pos:IsSanitized() then
        return nil, nil
    end

    return pos, rot
end

function PickingUtils.CalcNDC(x, y, screenW, screenH)
    local ndcX = (2.0 * x) / screenW - 1.0
    local ndcY = 1.0 - (2.0 * y) / screenH
    return ndcX, ndcY
end

-- Converts a 2D screen-space coordinate into a world-space ray.
---@param cameraHandle EntityHandle?
---@param mouseX number?
---@param mouseY number?
---@param screenW number?
---@param screenH number?
---@return Ray?
function ScreenToWorldRay(cameraHandle, mouseX, mouseY, screenW, screenH)
    if not screenW or not screenH then
        screenW, screenH = UIHelpers.GetScreenSize()
    end
    if not mouseX or not mouseY then
        mouseX, mouseY = PickingUtils.GetCursorPos()
    end
    if not cameraHandle then
        cameraHandle = RBGetCamera()
    end

    if not cameraHandle or not cameraHandle.Camera then
        Error("GetMouseRay: Invalid camera entity or missing Camera component")
        return nil
    end

    local camera = cameraHandle.Camera --[[@as CameraComponent]]
    local controller = camera.Controller

    local ndcX, ndcY = PickingUtils.CalcNDC(mouseX, mouseY, screenW, screenH)

    local zNearClip = 0
    local zFarClip  = 1.0

    local clipNear = Vec4.new({ ndcX, ndcY, zNearClip, 1.0 })
    local clipFar  = Vec4.new({ ndcX, ndcY, zFarClip,  1.0 })

    local invProj = Matrix.new(controller.Camera.InvProjectionMatrix)
    local invView = Matrix.new(controller.Camera.InvViewMatrix)

    --local projMat = Matrix.new(controller.Camera.ProjectionMatrix)
    --local viewMat = Matrix.new(controller.Camera.ViewMatrix)

    -- (A * B)^-1 = B^-1 * A^-1
    local inverse = invView * invProj
    --local inverse = (projMat * viewMat):Inverse()

    local worldNear4 = inverse * clipNear
    local worldFar4  = inverse * clipFar
    worldNear4 = worldNear4 / worldNear4.w
    worldFar4  = worldFar4  / worldFar4.w

    local worldNear = Vec3.new({ worldNear4.x, worldNear4.y, worldNear4.z })
    local worldFar  = Vec3.new({ worldFar4.x,  worldFar4.y,  worldFar4.z })

    local dir = worldNear - worldFar
    local origin
    if controller.IsOrthographic then
        origin = worldNear
    else
        origin = Vec3.new(cameraHandle.Transform.Transform.Translate)
    end
    dir = dir:Normalize()

    local ray = Ray.new(origin, dir)

    return ray
end

-- Converts a 3D world-space coordinate into a 2D screen-space coordinate.
--- @param worldPos Vec3
--- @param cameraHandle EntityHandle?
--- @param screenW number?
--- @param screenH number?
--- @return Vec2
function WorldToScreenPoint(worldPos, cameraHandle, screenW, screenH)
    if not screenW or not screenH then
        screenW, screenH = UIHelpers.GetScreenSize()
    end
    if not cameraHandle then
        cameraHandle = RBGetCamera()
    end

    if not cameraHandle or not cameraHandle.Camera then
        Error("WorldToScreenPoint: Invalid camera entity or missing Camera component")
        return {0, 0}
    end

    local camera = cameraHandle.Camera --[[@as CameraComponent]]
    local controller = camera.Controller

    local worldPos4 = Vec4.new({worldPos[1], worldPos[2], worldPos[3], 1.0})

    local viewMat = Matrix.new(controller.Camera.ViewMatrix)
    local projMat = Matrix.new(controller.Camera.ProjectionMatrix)

    local viewProj = projMat * viewMat

    local clipPos = viewProj * worldPos4

    if clipPos.w == 0 then
        return {0, 0}
    end

    local ndcPos = clipPos / clipPos.w

    local screenX = ((ndcPos.x + 1) / 2) * screenW
    local screenY = ((1 - ndcPos.y) / 2) * screenH

    return Vec2.new(screenX, screenY)
end