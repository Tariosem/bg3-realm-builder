--- @class CameraHelpers
--- @field CameraMoveToEntity fun(guid:string)
--- @field CameraMoveToPosition fun(position:vec3)
CameraHelpers = CameraHelpers or {}

function CameraHelpers.CameraMoveToEntity(guid)
    local pos = {MathUtils.GetCenterPosition(guid)}
    local camera = Ext.Entity.GetAllEntitiesWithComponent("GameCameraBehavior")[1].GameCameraBehavior

    camera.Targets = {}
    camera.PlayerInControl = true
    camera.TrackTarget = nil

    camera.TargetDestination = pos
end

function CameraHelpers.CameraMoveToPosition(position)
    local camera = Ext.Entity.GetAllEntitiesWithComponent("GameCameraBehavior")[1].GameCameraBehavior

    camera.Targets = {}
    camera.PlayerInControl = true
    camera.TrackTarget = nil

    camera.TargetDestination = position
end

--- @class CameraProxy
--- @field GetTransform fun(self: CameraProxy): Transform
--- @field SetTransform fun(self: CameraProxy, transform: Transform)
CameraProxy = {}

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
