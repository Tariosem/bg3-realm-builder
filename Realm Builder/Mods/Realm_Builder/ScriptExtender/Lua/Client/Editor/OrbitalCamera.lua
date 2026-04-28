local eml = Ext.Math

local function calcNDC(x, y)
    local screenWH = Ext.IMGUI.GetViewportSize()
    return (2.0 * x) / screenWH[1] - 1.0,
           1.0 - (2.0 * y) / screenWH[2]
end

local function getNDC()
    local picker = Ext.ClientUI.GetPickingHelper(1)
    if not picker then return 0,0 end

    local mX, mY = picker.WindowCursorPos[1], picker.WindowCursorPos[2]

    return calcNDC(mX, mY)
end

local deepCopy = RBUtils.DeepCopy

--- @class OrbitalCamera
--- @field camera CameraProxy
--- @field target Vec3
--- @field distance number
--- @field rotateSpeed number
--- @field zoomSpeed number
--- @field moveSpeed number
--- @field minDistance number
--- @field maxDistance number
--- @field enableCollide boolean
--- @field collideCullingRadius number -- target radius for collision culling, default 0.5
--- @field collideRaidus number -- radius used for collision detection, default 1
--- @field IgnoreEntity string -- Guid of entity to ignore for collision
--- @field subs RBSubscription[]
local OrbitalCamera = {}

function OrbitalCamera.new(cam)
    local o = setmetatable({}, {__index = OrbitalCamera})

    o.camera = cam or CameraProxy.new()
    o.target = {0,0,0}
    o.distance = 10

    o.theta = 0
    o.phi = 0
    o.tilt = 0

    o.rotateSpeed = 2.0
    o.zoomSpeed = 0.9
    o.moveSpeed = 10.0

    o.minDistance = 1.0
    o.maxDistance = 100.0

    o.enableCollide = false
    o.collideCullingRadius = 0.5
    o.collideRaidus = 1

    o.IgnoreEntity = nil -- Guid of entity to ignore for collision, usually the player character

    return o
end

local allInclude = 0
local PhysicsGroupFlags = Ext.Enums.PhysicsGroupFlags
local PhysicsType = Ext.Enums.PhysicsType

for _, flag in pairs(PhysicsGroupFlags) do
    allInclude = allInclude | flag
end

local allPhyType = PhysicsType.Dynamic | PhysicsType.Static

--- @param transform Transform
function OrbitalCamera:SetCameraTransform(transform)
    if self.enableCollide then
        local sub = eml.Sub
        local mul = eml.Mul
        local add = eml.Add
        local length = eml.Length
        local targetPos = self.target
        local rayOrigin = targetPos
        local dirVec = sub(transform.Translate, targetPos)
        local rayDir = eml.Normalize(dirVec)
        local rayLength = self.distance or eml.Length(dirVec)
        local cullingRadius = self.collideCullingRadius or 0.5
        local colliderRadius = self.collideRadius or 1

        local startPoint = add(rayOrigin, mul(rayDir, cullingRadius)) -- Start a bit away from the target to prevent immediate collision
        local endPoint = transform.Translate

        local excludeFlag = 0
        if EntityHelpers.IsCharacter(self.IgnoreEntity) then
            excludeFlag = PhysicsGroupFlags.Group08 -- softbody
        end

        local hits = Ext.Level.RaycastAll(
            startPoint,
            endPoint,
            --- @diagnostic disable-next-line
            allPhyType,
            allInclude, -- includeFlags
            --- @diagnostic disable-next-line
            excludeFlag,
            -1  -- context
        )
        for i, pos in pairs(hits.Positions or {}) do
            local entity = hits.Shapes[i].PhysicsObject.Entity
            if entity and entity.Uuid and entity.Uuid.EntityUuid == self.IgnoreEntity then
                goto continue
            end

            local dis = length(sub(hits.Positions[i], targetPos))
            if dis < rayLength then
                transform.Translate = add(pos, mul(rayDir, -colliderRadius)) -- Pull back a bit to prevent clipping
                break
            end

            ::continue::
        end
    end

    self.camera:SetTransform(transform)
end

local function calculateCameraQuat(theta, phi, tilt)
    local rotX = eml.QuatRotateAxisAngle({0, 0, 0, 1}, {1, 0, 0}, phi)
    local rotY = eml.QuatRotateAxisAngle({0, 0, 0, 1}, {0, 1, 0}, theta)

    if tilt and tilt ~= 0 then
        local tiltRad = math.rad(tilt)
        local rotZ = eml.QuatRotateAxisAngle({0, 0, 0, 1}, {0, 0, 1}, tiltRad)
        return eml.QuatMul(eml.QuatMul(rotY, rotX), rotZ)
    end

    return eml.QuatMul(rotY, rotX)
end

local function calculateCameraTransform(target, distance, theta, phi, tilt)
    local rot = calculateCameraQuat(theta, phi, tilt)
    local dir = eml.QuatRotate(rot, {0, 0, -distance})
    local pos = eml.Add(target, dir)

    return {
        Translate = pos,
        RotationQuat = rot,
        Scale = {1, 1, 1}
    }

end

function OrbitalCamera:Rotate(deltaX, deltaY)
    self.theta = (self.theta or 0) + deltaX * self.rotateSpeed
    self.phi = (self.phi or 0) + -deltaY * self.rotateSpeed

    local newTransform = calculateCameraTransform(self.target, self.distance, self.theta, self.phi, self.tilt)
    self:SetCameraTransform(newTransform)
end

function OrbitalCamera:Move(deltaX, deltaY)
    local currentTransform = self.camera:GetTransform()
    local cameraQuat = currentTransform.RotationQuat

    local right = eml.QuatRotate(cameraQuat, {1, 0, 0})
    local up = eml.QuatRotate(cameraQuat, {0, 1, 0})

    for i=1,3 do
        right[i] = right[i] * deltaX * self.moveSpeed
        up[i] = up[i] * deltaY * self.moveSpeed
    end

    local moveVec = eml.Add(right, up)
    self.target = eml.Add(self.target, moveVec)

    local newPos = eml.Add(currentTransform.Translate, moveVec)

    local newDistance = eml.Length(eml.Sub(newPos, self.target))
    self.distance = newDistance

    local newTransform = {
        Translate = newPos,
        RotationQuat = currentTransform.RotationQuat,
        Scale = currentTransform.Scale
    }

    self:SetCameraTransform(newTransform)
end

function OrbitalCamera:Zoom(deltaZoom)
    local ratio = deltaZoom >= 0 and 1 * self.zoomSpeed or 1 / self.zoomSpeed
    self.distance = eml.Clamp(self.distance * ratio, self.minDistance, self.maxDistance)

    local currentTransform = self.camera:GetTransform()
    local dir = eml.QuatRotate(currentTransform.RotationQuat, {0, 0, -self.distance})
    local newPos = eml.Add(self.target, dir)

    local newTransform = {
        Translate = newPos,
        RotationQuat = currentTransform.RotationQuat,
        Scale = currentTransform.Scale
    }

    self:SetCameraTransform(newTransform)
end

function OrbitalCamera:SetTilt(deg)
    deg = -eml.Clamp(deg, -180, 180)

    self.tilt = deg

    local newTransform = calculateCameraTransform(self.target, self.distance, self.theta or 0, self.phi or 0, self.tilt)
    self:SetCameraTransform(newTransform)
end

function OrbitalCamera:SetTarget(target)
    self.target = target
end

function OrbitalCamera:SetCamera(camera)
    self.camera = camera
end

function OrbitalCamera:Subscribe()
    local mouseLastPos = nil
    local currentAction = nil
    
    local timer = nil

    local function launchInputTimer(actionType)
        if timer then return end
        currentAction = actionType

        timer = Timer:EveryFrame(function()
            if not mouseLastPos then
                Timer:Cancel(timer)
                timer = nil
                currentAction = nil
                return
            end

            local mouseX, mouseY = getNDC()
            local deltaX = mouseX - mouseLastPos[1]
            local deltaY = mouseY - mouseLastPos[2]

            if currentAction == "rotate" then
                self:Rotate(deltaX, deltaY)
            elseif currentAction == "move" then
                self:Move(deltaX, deltaY)
            end

            mouseLastPos = {mouseX, mouseY}
        end, true)
    end

    local subs = {

        InputEvents.SubscribeMouseInput({}, function (e)
            if e.Button ~= 3 then return end
            if InputEvents.GetGlobalInputStatesRef().Shift then return end

            if e.Pressed then
                mouseLastPos = {PickingUtils.GetNDC()}
                launchInputTimer("rotate")
            elseif currentAction == "rotate" then
                mouseLastPos = nil
            end
        end),

        InputEvents.SubscribeMouseWheel({}, function(e)
            self:Zoom(e.ScrollY)
        end),

        InputEvents.SubscribeKeyInput({}, function(e)
            local factor = e.Key == "PAGEUP" and 1 or (e.Key == "PAGEDOWN" and -1 or 0)
            if factor == 0 then return end
            self:Zoom(factor)
        end),

        InputEvents.SubscribeMouseInput({}, function (e)
            if e.Button ~= 3 then return end

            if e.Pressed and InputEvents.GetGlobalInputStatesRef().Shift then
                mouseLastPos = {PickingUtils.GetNDC()}
                launchInputTimer("move")
            elseif currentAction == "move" then
                mouseLastPos = nil
            end
        end),

        InputEvents.SubscribeKeyInput({}, function (e)
            if e.Key ~= "KP_PERIOD" then return end

            if e.Pressed then
                self:Reset()
            end
        end)
    }

    self.subs = subs
end

function OrbitalCamera:Reset()
    local currentTransform = self.camera:GetTransform()
    local newPos = Ext.Math.Add(self.target, Vec3.new(0, 0, -self.distance))
    self.theta = 0
    self.phi = 0
    self.tilt = 0
    local newTransform = {
        Translate = newPos,
        RotationQuat = Quat.Identity(),
        Scale = currentTransform.Scale
    }
    self.camera:SetTransform(newTransform)
    if self.OnReset then
        self.OnReset()
    end
end

function OrbitalCamera:IsActive()
    return next(self.subs or {}) ~= nil
end

function OrbitalCamera:EnableControls()
    self.subs = self.subs or {}

    for _, sub in pairs(self.subs) do
        sub:Unsubscribe()
    end
    self.subs = {}

    self:Subscribe()
end

function OrbitalCamera:DisableControls()
    self.subs = self.subs or {}

    for _, sub in pairs(self.subs) do
        sub:Unsubscribe()
    end
    self.subs = {}
end

--- @class OrbitalCameraUI
--- @field controller OrbitalCamera
--- @field Run fun(self: OrbitalCameraUI)
--- @field Stop fun(self: OrbitalCameraUI)
--- @field IsRunning fun(self: OrbitalCameraUI): boolean
--- @field RenderConfigTable fun(self: OrbitalCameraUI, parent: ExtuiTreeParent):AlignedTable
OrbitalCameraUI = {}

function OrbitalCameraUI.new(camProxy)
    local o = setmetatable({}, {__index = OrbitalCameraUI})

    local cam = camProxy or CameraProxy.new()
    local orbCam = OrbitalCamera.new(cam)

    o.controller = orbCam

    return o
end

--- @param target Vec3
function OrbitalCameraUI:SetTarget(target)
    self.controller:SetTarget(target)
end

function OrbitalCameraUI:Run()
    local ct = self.controller
    ct:SetTarget(deepCopy(_C().Transform.Transform.Translate))
    ct.camera:SetTransform(deepCopy(RBGetCamera().Transform.Transform))
    ct:EnableControls()
end

function OrbitalCameraUI:IsRunning()
    return self.controller:IsActive()
end

function OrbitalCameraUI:Stop()
    if self.controller then
        self.controller:DisableControls()
    end
end

--- @param parent ExtuiTreeParent
function OrbitalCameraUI:RenderConfigTable(parent)
    local aT = ImguiElements.AddAlignedTable(parent)

    aT:AddCheckbox("Enable Collision", self.controller.enableCollide or false).OnChange = function (s)
        self.controller.enableCollide = s.Checked
    end

    local titlSlider = aT:AddSliderWithStep("Camera Tilt", 0, -180, 180, 15, false)
    titlSlider.OnChange = function (s)
        self.controller:SetTilt(s.Value[1])
    end

    self.tiltSliders = self.tiltSliders or {}
    table.insert(self.tiltSliders, titlSlider)
    self.controller.OnReset = function ()
        if self.tiltSliders then
            for _, slider in pairs(self.tiltSliders) do
                slider.Value = {0, 0, 0, 0}
            end
        end
    end

    local fields = {
        {name = "Rotate Speed", var = "rotateSpeed", type = "number", minValue = 0.1, maxValue = 10, step = 0.1},
        {name = "Zoom Ratio", var = "zoomSpeed", type = "number", minValue = 0.1, maxValue = 1, step = 0.01},
        {name = "Move Speed", var = "moveSpeed", type = "number", minValue = 0.1, maxValue = 20, step = 0.1},
        {name = "Min Distance", var = "minDistance", type = "number", minValue = 0.1, maxValue = 50, step = 0.1},
        {name = "Max Distance", var = "maxDistance", type = "number", minValue = 1, maxValue = 200, step = 1},
        {name = "Collision Culling Radius", var = "collideCullingRadius", type = "number", minValue = 0.1, maxValue = 5, step = 0.1},
        {name = "Collision Pullback Radius", var = "collideRaidus", type = "number", minValue = 0.1, maxValue = 5, step = 0.1},
    }

    for _, field in pairs(fields) do
        aT:AddSliderWithStep(field.name, self.controller[field.var], field.minValue, field.maxValue, field.step, false).OnChange = function (s)
            local setValue = s.Value[1]
            if setValue < field.minValue then setValue = field.minValue end
            if setValue > field.maxValue then setValue = field.maxValue end
            self.controller[field.var] = setValue
        end
    end

    return aT
end

return OrbitalCameraUI