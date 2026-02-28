local eml = Ext.Math

--- @class CameraInterface
--- @field GetTransform fun(self: CameraInterface): Transform
--- @field SetTransform fun(self: CameraInterface, transform: Transform)
local CameraInterface = {}

local function getNDC()
    local pH = Ext.ClientUI.GetPickingHelper(1)
    if not pH then return 0,0 end

    local screenWH = Ext.IMGUI.GetViewportSize()

    local mX, mY = pH.WindowCursorPos[1], pH.WindowCursorPos[2]

    local ndcX = (2.0 * mX) / screenWH[1] - 1.0
    local ndcY = 1.0 - (2.0 * mY) / screenWH[2]

    return ndcX, ndcY
end

local deepCopy = RBUtils.DeepCopy

function CameraInterface.new()
    local o = {
        Transform = {
            Translate = {0,0,0},
            RotationQuat = {0,0,0,1},
            Scale = {1,1,1}
        }
    }
    setmetatable(o, {__index = CameraInterface})
    return o
end

function CameraInterface:GetTransform()
    return self.Transform
end

function CameraInterface:SetTransform(transform)
    self.Transform = transform
    local cam = RBGetCamera()
    if not cam or not cam.PhotoModeCameraSavedTransform then return end
    cam.PhotoModeCameraSavedTransform.Transform = transform
    Ext.OnNextTick(function()
        --- @diagnostic disable-next-line
        Ext.UI.GetRoot():Find("ContentRoot"):Child(21).DataContext.RecallCameraTransform:Execute()
    end)
end

--- @class OrbitalCameraController
--- @field camera CameraInterface
--- @field target Vec3
--- @field distance number
--- @field xSpeed number 
--- @field ySpeed number 
--- @field zoomSpeed number
--- @field moveSpeed number
--- @field subs RBSubscription[]
local OrbitalCameraController = {}

function OrbitalCameraController.new(camInt)

    local o = setmetatable({}, {__index = OrbitalCameraController})

    o.camera = camInt or CameraInterface.new()
    o.target = {0,0,0}
    o.distance = 10

    o.rotateSpeed = 1.0
    o.zoomSpeed = 0.9
    o.moveSpeed = 10.0

    o.minDistance = 1.0
    o.maxDistance = 100.0

    return o
end

function OrbitalCameraController:Rotate(deltaX, deltaY)
    local currentTransform = self.camera:GetTransform()
    local currentRot = currentTransform.RotationQuat

    local rotX = eml.QuatRotateAxisAngle(currentRot, {1, 0, 0}, -deltaY * self.rotateSpeed)
    local rotY = eml.QuatRotateAxisAngle({0, 0, 0, 1}, {0, 1, 0}, deltaX * self.rotateSpeed)

    currentRot = eml.QuatMul(rotY, rotX)

    local dir = eml.QuatRotate(currentRot, {0, 0, -self.distance})
    local newPos = eml.Add(self.target, dir)

    local newTransform = {
        Translate = newPos,
        RotationQuat = currentRot,
        Scale = {1, 1, 1}
    }

    self.camera:SetTransform(newTransform)
end

function OrbitalCameraController:Move(deltaX, deltaY)
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

    self.camera:SetTransform(newTransform)
end

function OrbitalCameraController:Zoom(deltaZoom)
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

    self.camera:SetTransform(newTransform)
end

function OrbitalCameraController:SetTarget(target)
    self.target = target
end

function OrbitalCameraController:SetCamera(camera)
    self.camera = camera
end

function OrbitalCameraController:Subscribe()
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

    local sub = InputEvents.SubscribeMouseInput({}, function (e)
        if e.Button ~= 3 then return end
        if InputEvents.GetGlobalInputStatesRef().Shift then return end

        if e.Pressed then
            mouseLastPos = {PickingUtils.GetNDC()}
            launchInputTimer("rotate")
        elseif currentAction == "rotate" then
            mouseLastPos = nil
        end
    end)

    local scrollSub = InputEvents.SubscribeMouseWheel({}, function(e)
        self:Zoom(e.ScrollY)
    end)

    local pageDownPageUpSub = InputEvents.SubscribeKeyInput({}, function(e)
        local factor = e.Key == "PAGEUP" and 1 or (e.Key == "PAGEDOWN" and -1 or 0)
        if factor == 0 then return end
        self:Zoom(factor)
    end)

    local shiftRMB = InputEvents.SubscribeMouseInput({}, function (e)
        if e.Button ~= 3 then return end
        if not InputEvents.GetGlobalInputStatesRef().Shift then return end

        if e.Pressed then
            mouseLastPos = {PickingUtils.GetNDC()}
            launchInputTimer("move")
        elseif currentAction == "move" then
            mouseLastPos = nil
        end
    end)

    local resetSub = InputEvents.SubscribeKeyInput({}, function (e)
        if e.Key ~= "KP_PERIOD" then return end

        if e.Pressed then
            self:Reset()
        end
    end)

    self.subs = self.subs or {}

    self.subs["RMB"] = sub
    self.subs["Scroll"] = scrollSub
    self.subs["PageUpDown"] = pageDownPageUpSub
    self.subs["Shift+RMB"] = shiftRMB
    self.subs["Reset"] = resetSub
end

function OrbitalCameraController:Reset()
    self.distance = 10
    local currentTransform = self.camera:GetTransform()
    local newPos = Ext.Math.Add(self.target, Vec3.new(0, 0, -self.distance))
    local newTransform = {
        Translate = newPos,
        RotationQuat = Quat.Identity(),
        Scale = currentTransform.Scale
    }
    self.camera:SetTransform(newTransform)
end

function OrbitalCameraController:IsActive()
    return next(self.subs or {}) ~= nil
end

function OrbitalCameraController:EnableControls()
    self.subs = self.subs or {}

    for _, sub in pairs(self.subs) do
        sub:Unsubscribe()
    end
    self.subs = {}

    self:Subscribe()
end

function OrbitalCameraController:DisableControls()
    self.subs = self.subs or {}

    for _, sub in pairs(self.subs) do
        sub:Unsubscribe()
    end
    self.subs = {}
end

--- @class OrbitalCameraApp
--- @field controller OrbitalCameraController
--- @field Run fun(self: OrbitalCameraApp)
--- @field Stop fun(self: OrbitalCameraApp)
OrbitalCameraApp = {}

function OrbitalCameraApp.new()
    local o = setmetatable({}, {__index = OrbitalCameraApp})

    local camInterface = CameraInterface.new()
    local camController = OrbitalCameraController.new(camInterface)

    o.controller = camController

    return o
end

--- @param target Vec3
function OrbitalCameraApp:SetTarget(target)
    self.controller:SetTarget(target)
end

function OrbitalCameraApp:Run()
    local ct = self.controller
    ct:SetTarget(deepCopy(_C().Transform.Transform.Translate))
    ct.camera:SetTransform(deepCopy(RBGetCamera().Transform.Transform))
    ct:EnableControls()
end

function OrbitalCameraApp:IsRunning()
    return self.controller:IsActive()
end

function OrbitalCameraApp:Stop()
    if self.controller then
        self.controller:DisableControls()
    end
end

--- @param parent ExtuiTreeParent
function OrbitalCameraApp:RenderConfigTable(parent)
    local aT = ImguiElements.AddAlignedTable(parent)

    local fields = {
        {name = "Rotate Speed", var = "rotateSpeed", type = "number", minValue = 0.1, maxValue = 10, step = 0.1},
        {name = "Zoom Ratio", var = "zoomSpeed", type = "number", minValue = 0.1, maxValue = 10, step = 0.1},
        {name = "Move Speed", var = "moveSpeed", type = "number", minValue = 0.1, maxValue = 20, step = 0.1},
        {name = "Min Distance", var = "minDistance", type = "number", minValue = 0.1, maxValue = 50, step = 0.1},
        {name = "Max Distance", var = "maxDistance", type = "number", minValue = 1, maxValue = 200, step = 1},
    }

    for _, field in pairs(fields) do
        aT:AddSliderWithStep(field.name, self.controller[field.var], field.minValue, field.maxValue, field.step, false)
    end
end

return OrbitalCameraApp