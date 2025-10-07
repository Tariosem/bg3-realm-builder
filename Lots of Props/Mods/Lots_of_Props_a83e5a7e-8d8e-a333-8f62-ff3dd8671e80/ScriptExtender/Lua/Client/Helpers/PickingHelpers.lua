--- @return GUIDSTRING|nil
function GetPickingGuid()
    local mouseRay = ScreenToWorldRay()

    local pick = HandleToUuid(Ext.ClientUI.GetPickingHelper(1).Inner.Inner[1].GameObject) --[[@as GUIDSTRING|nil]]
    if pick then --Debug("Returning pick" .. pick) 
    return pick end
    local returnGuid = nil
    local entity = nil

    local allPartyMembers = GetAllPartyMembers()
    local closestPartyMemberhit = nil
    for _, guid in ipairs(allPartyMembers) do
        local member = GetDummyByUuid(guid) or Ext.Entity.Get(guid)

        local hit = mouseRay:IntersectEntity(member)
        if hit and (not closestPartyMemberhit or hit:IsCloserThan(closestPartyMemberhit)) then
            closestPartyMemberhit = hit
            returnGuid = guid
            --Debug("Picked party member: " .. Ext.Entity.Get(guid).DisplayName.Name:Get())
        end
    end
    
    return returnGuid
end

function GetPickingEntity()
    return Ext.ClientUI.GetPickingHelper(1).Inner.Inner[1].GameObject
end

---@return number x
---@return number y
function GetCursorPos()
    local picker = Ext.ClientUI.GetPickingHelper(1)
    local pos = picker.WindowCursorPos
    return pos[1], pos[2]
end

--- @param picker EclPlayerPickingHelper?
--- @return Vec3?
--- @return Quat?
function GetCursorPosAndRot(picker)
    if not picker then
        picker = Ext.ClientUI.GetPickingHelper(1)
    end
    local pos = picker.Inner.Position
    local normal = picker.Inner.Normal
    local rot = DirectionToQuat(normal, nil, "Y")

    if pos[1] == 0 and pos[2] == 0 and pos[3] == 0 then
        return nil, nil
    end

    return Vec3.new(pos), Quat.new(rot)
end

function CalcNDC(x, y, screenW, screenH)
    local ndcX = (2.0 * x) / screenW - 1.0
    local ndcY = 1.0 - (2.0 * y) / screenH
    return ndcX, ndcY
end

---@param cameraHandle EntityHandle?
---@param mouseX number?
---@param mouseY number?
---@param screenW number?
---@param screenH number?
---@return Ray? -- default returns a mouse ray
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

    local camera = cameraHandle.Camera
    local controller = camera.Controller

    local ndcX, ndcY = CalcNDC(mouseX, mouseY, screenW, screenH)

    local zNearClip = 0
    local zFarClip  = 1.0

    local clipNear = Vec4.new({ ndcX, ndcY, zNearClip, 1.0 })
    local clipFar  = Vec4.new({ ndcX, ndcY, zFarClip,  1.0 })

    local invProj = Matrix.new(controller.Camera.InvProjectionMatrix)
    local invView = Matrix.new(controller.Camera.InvViewMatrix)

    local viewNear = invProj * clipNear
    local viewFar  = invProj * clipFar
    viewNear = viewNear / viewNear.w
    viewFar  = viewFar  / viewFar.w

    local worldNear4 = invView * viewNear
    local worldFar4  = invView * viewFar

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

--- @param worldPos Vec3
--- @param cameraHandle EntityHandle?
--- @param screenW number?
--- @param screenH number?
--- @return Vec2|nil
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

    local camera = cameraHandle.Camera
    local controller = camera.Controller

    local worldPos4 = Vec4.new({worldPos[1], worldPos[2], worldPos[3], 1.0})

    local viewMat = Matrix.new(controller.Camera.ViewMatrix)
    local projMat = Matrix.new(controller.Camera.ProjectionMatrix)


    local viewPos = viewMat * worldPos4
    local clipPos = projMat * viewPos

    if clipPos.w == 0 then
        return nil
    end

    local ndcPos = clipPos / clipPos.w

    local screenX = ((ndcPos.x + 1) / 2) * screenW
    local screenY = ((1 - ndcPos.y) / 2) * screenH

    return Vec2.new(screenX, screenY)
end