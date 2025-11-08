PickingHelpers = {
    GuidRedirects = {},
}

function PickingHelpers:RegisterGuidRedirect(fromGuid, toGuid)
    self.GuidRedirects[fromGuid] = toGuid
end

--- @return GUIDSTRING|nil
function GetPickingGuid()
    local pickHandle = Ext.ClientUI.GetPickingHelper(1).Inner.Inner[1].GameObject

    if pickHandle then
        local pickUuid = HandleToUuid(pickHandle)
        Debug("Picked GUID: " .. tostring(pickUuid))
        if pickUuid then
            if PickingHelpers.GuidRedirects[pickUuid] then
                Debug("Redirected picked GUID from " .. pickUuid .. " to " .. PickingHelpers.GuidRedirects[pickUuid])
                pickUuid = PickingHelpers.GuidRedirects[pickUuid]
            end
            return pickUuid
        end
    end

    local mouseRay = ScreenToWorldRay()
    local returnGuid = nil
    local entity = nil

    if not mouseRay then return nil end
    local allPartyMembers = GetAllPartyMembers()
    local closestPartyMemberhit = nil
    for _, guid in ipairs(allPartyMembers) do
        local member = GetDummyByUuid(guid) or Ext.Entity.Get(guid) --[[@as EntityHandle]]

        local hit = mouseRay:IntersectEntity(member)
        if hit and (not closestPartyMemberhit or hit:IsCloserThan(closestPartyMemberhit)) then
            closestPartyMemberhit = hit
            returnGuid = guid
            --Debug("Picked party member: " .. Ext.Entity.Get(guid).DisplayName.Name:Get())
        end
    end

    if PickingHelpers.GuidRedirects[returnGuid] then
        returnGuid = PickingHelpers.GuidRedirects[returnGuid]
    end
    return returnGuid
end

function GetPickingEntity()
    return Ext.ClientUI.GetPickingHelper(1).Inner.Inner[1].GameObject
end

---@param picker EclPlayerPickingHelper?
---@return number x
---@return number y
function GetCursorPos(picker)
    if not picker then
        picker = Ext.ClientUI.GetPickingHelper(1)
    end
    local pos = picker.WindowCursorPos
    return pos[1], pos[2]
end

--- Returns the hit position and rotation from a picking helper.
--- @param picker EclPlayerPickingHelper?
--- @return Vec3?
--- @return Quat?
function GetPickingHitPosAndRot(picker)
    if not picker then
        picker = Ext.ClientUI.GetPickingHelper(1)
    end
    local pos = picker.Inner.SceneryPosition
    local normal = picker.Inner.SceneryNormal
    local rot = DirectionToQuat(normal, nil, "Y")

    local host = CGetHostCharacter()
    local sanitizedPos = Vec3.new(pos):Sanitize({CGetPosition(host)}) --[[@as Vec3]]
    return sanitizedPos, rot
end

function CalcNDC(x, y, screenW, screenH)
    local ndcX = (2.0 * x) / screenW - 1.0
    local ndcY = 1.0 - (2.0 * y) / screenH
    return ndcX, ndcY
end

--[[
    Converts a 2D screen-space coordinate into a 3D world-space coordinate.

    Similar to glm::unProjectZO, but only for a single depth value.
]]
local function Unproject(screenX, screenY, screenZ, viewMatrix, projMatrix, screenW, screenH)
    local ndcX, ndcY = CalcNDC(screenX, screenY, screenW, screenH)
    local clipPos = Vec4.new({ndcX, ndcY, screenZ, 1.0})

    local invProj = Matrix.new(projMatrix):Inverse()
    local invView = Matrix.new(viewMatrix):Inverse()

    -- (A * B)^-1 = B^-1 * A^-1
    local inverse = invView * invProj

    local worldPos4 = inverse * clipPos
    worldPos4 = worldPos4 / worldPos4.w

    local worldPos = Vec3.new({worldPos4.x, worldPos4.y, worldPos4.z})
    return worldPos
end

function UnprojectNear(screenX, screenY, viewMatrix, projMatrix, screenW, screenH)
    return Unproject(screenX, screenY, 0.0, viewMatrix, projMatrix, screenW, screenH)
end

function UnprojectFar(screenX, screenY, viewMatrix, projMatrix, screenW, screenH)
    return Unproject(screenX, screenY, 1.0, viewMatrix, projMatrix, screenW, screenH)
end

--[[
    Converts a 2D screen-space coordinate into a world-space ray.

    Conceptually similar to the following glm code:
        worldNear = glm::unProjectZO(vec3(mouseX, mouseY, 0.0), view, proj, viewport)
        worldFar  = glm::unProjectZO(vec3(mouseX, mouseY, 1.0), view, proj, viewport)
        rayDir    = glm::normalize(worldFar - worldNear)

    though I don't why we have to subtract near from far to get the correct direction.
]]
---@param cameraHandle EntityHandle?
---@param mouseX number?
---@param mouseY number?
---@param screenW number?
---@param screenH number?
---@return Ray?
function ScreenToWorldRay(cameraHandle, mouseX, mouseY, screenW, screenH)
    if not screenW or not screenH then
        screenW, screenH = GetScreenSize()
    end
    if not mouseX or not mouseY then
        mouseX, mouseY = GetCursorPos()
    end
    if not cameraHandle then
        cameraHandle = GetCamera()
    end

    if not cameraHandle or not cameraHandle.Camera then
        Error("GetMouseRay: Invalid camera entity or missing Camera component")
        return nil
    end

    local camera = cameraHandle.Camera --[[@as CameraComponent]]
    local controller = camera.Controller

    local ndcX, ndcY = CalcNDC(mouseX, mouseY, screenW, screenH)

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

    -- mystery
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



--[[
    Converts a 3D world-space coordinate into a 2D screen-space coordinate.
]]
--- @param worldPos Vec3
--- @param cameraHandle EntityHandle?
--- @param screenW number?
--- @param screenH number?
--- @return Vec2
function WorldToScreenPoint(worldPos, cameraHandle, screenW, screenH)
    if not screenW or not screenH then
        screenW, screenH = GetScreenSize()
    end
    if not cameraHandle then
        cameraHandle = GetCamera()
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