local eml = Ext.Math

--- @class CameraProxy
--- @field GetTransform fun(self: CameraProxy): Transform
--- @field SetTransform fun(self: CameraProxy, transform: Transform)
local CameraProxy = {}

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

function CameraProxy.new()
    local o = {
        Transform = {
            Translate = {0,0,0},
            RotationQuat = {0,0,0,1},
            Scale = {1,1,1}
        }
    }
    setmetatable(o, {__index = CameraProxy})
    return o
end

function CameraProxy:GetTransform()
    return self.Transform
end

function CameraProxy:SetTransform(transform)
    self.Transform = transform
    local cam = RBGetCamera()
    if not cam or not cam.PhotoModeCameraSavedTransform then return end

    cam.PhotoModeCameraSavedTransform.Transform = transform
    Ext.OnNextTick(function()
        --- @diagnostic disable-next-line
        Ext.UI.GetRoot():Find("ContentRoot"):Child(21).DataContext.RecallCameraTransform:Execute()
    end)
end

--- @class OrbitalCamera
--- @field camera CameraProxy
--- @field target Vec3
--- @field distance number
--- @field rotateSpeed number
--- @field zoomSpeed number
--- @field moveSpeed number
--- @field subs RBSubscription[]
local OrbitalCamera = {}

function OrbitalCamera.new(cam)
    local o = setmetatable({}, {__index = OrbitalCamera})

    o.camera = cam or CameraProxy.new()
    o.target = {0,0,0}
    o.distance = 10

    o.rotateSpeed = 1.0
    o.zoomSpeed = 0.9
    o.moveSpeed = 10.0

    o.minDistance = 1.0
    o.maxDistance = 100.0

    return o
end

function OrbitalCamera:Rotate(deltaX, deltaY)
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

    self.camera:SetTransform(newTransform)
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

    self.camera:SetTransform(newTransform)
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
            if not InputEvents.GetGlobalInputStatesRef().Shift then return end

            if e.Pressed then
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
--- @field RenderConfigTable fun(self: OrbitalCameraUI, parent: ExtuiTreeParent)
OrbitalCameraUI = {}

function OrbitalCameraUI.new()
    local o = setmetatable({}, {__index = OrbitalCameraUI})

    local cam = CameraProxy.new()
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

    local fields = {
        {name = "Rotate Speed", var = "rotateSpeed", type = "number", minValue = 0.1, maxValue = 10, step = 0.1},
        {name = "Zoom Ratio", var = "zoomSpeed", type = "number", minValue = 0.1, maxValue = 1, step = 0.01},
        {name = "Move Speed", var = "moveSpeed", type = "number", minValue = 0.1, maxValue = 20, step = 0.1},
        {name = "Min Distance", var = "minDistance", type = "number", minValue = 0.1, maxValue = 50, step = 0.1},
        {name = "Max Distance", var = "maxDistance", type = "number", minValue = 1, maxValue = 200, step = 1},
    }

    for _, field in pairs(fields) do
        aT:AddSliderWithStep(field.name, self.controller[field.var], field.minValue, field.maxValue, field.step, false).OnChange = function (s)
            local setValue = s.Value[1]
            if setValue < field.minValue then setValue = field.minValue end
            if setValue > field.maxValue then setValue = field.maxValue end
            self.controller[field.var] = setValue
        end
    end
end