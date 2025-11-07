function CameraMoveToEntity(guid)
    local pos = {GetCenterPosition(guid)}
    local camera = Ext.Entity.GetAllEntitiesWithComponent("GameCameraBehavior")[1].GameCameraBehavior

    camera.Targets = {}
    camera.PlayerInControl = true
    camera.TrackTarget = nil

    camera.TargetDestination = pos
end

function CameraMoveToPosition(position)
    local camera = Ext.Entity.GetAllEntitiesWithComponent("GameCameraBehavior")[1].GameCameraBehavior

    camera.Targets = {}
    camera.PlayerInControl = true
    camera.TrackTarget = nil

    camera.TargetDestination = position
end
