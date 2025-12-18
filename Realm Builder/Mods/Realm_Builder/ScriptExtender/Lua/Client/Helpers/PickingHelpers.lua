PickingUtils = {
    GuidRedirects = {},
}

--- for markers
function PickingUtils:RegisterGuidRedirect(fromGuid, toGuid)
    self.GuidRedirects[fromGuid] = toGuid
end

--- @param ray Ray?
--- @return GUIDSTRING|nil
function PickingUtils.GetPickingGuid(ray)
    ray = ray or ScreenToWorldRay()
    if not ray then return nil end

    local result = ray:IntersectAll()

    for _, hit in ipairs(result) do
        local entity = hit.Target
        if not entity then
            goto continue
        end
        local uuid = entity.Uuid and entity.Uuid.EntityUuid
        if not uuid and entity.Scenery then
            uuid = entity.Scenery.Uuid
            NearbyMap.RegisterScenery(entity)
            return uuid
        end
        if uuid then
            if PickingUtils.GuidRedirects[uuid] then
                uuid = PickingUtils.GuidRedirects[uuid]
            end
            return uuid
        end
        ::continue::
    end

    return nil
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

    local ndcX = (2.0 * mouseX) / screenW - 1.0
    local ndcY = 1.0 - (2.0 * mouseY) / screenH

    local zNearClip = 0
    local zFarClip  = 1.0

    local clipNear = { ndcX, ndcY, zNearClip, 1.0 }
    local clipFar  = { ndcX, ndcY, zFarClip,  1.0 }

    local invProj = controller.Camera.InvProjectionMatrix
    local invView = controller.Camera.InvViewMatrix

    --local projMat = Matrix.new(controller.Camera.ProjectionMatrix)
    --local viewMat = Matrix.new(controller.Camera.ViewMatrix)

    -- (A * B)^-1 = B^-1 * A^-1
    local inverse = Ext.Math.Mul(invView, invProj)
    --local inverse = (projMat * viewMat):Inverse()

    local worldNear4 = Ext.Math.Mul(inverse, clipNear)
    local worldFar4  = Ext.Math.Mul(inverse, clipFar)

    --- normalize homogeneous coordinates
    local worldNear = { worldNear4[1] / worldNear4[4], worldNear4[2] / worldNear4[4], worldNear4[3] / worldNear4[4] }
    local worldFar = { worldFar4[1] / worldFar4[4], worldFar4[2] / worldFar4[4], worldFar4[3] / worldFar4[4] }

    local dir = { worldNear[1] - worldFar[1], worldNear[2] - worldFar[2], worldNear[3] - worldFar[3] }

    local origin = Vec3.new(cameraHandle.Transform.Transform.Translate)

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