--- @class CameraHelpers
--- @field CameraMoveToEntity fun(guid:string)
--- @field CameraMoveToPosition fun(position:vec3)
CameraHelpers = CameraHelpers or {}

function CameraHelpers.CameraMoveToEntity(guid)
    local pos = {MathHelpers.GetCenterPosition(guid)}
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
