function FindCurrentAtmosphereTrigger(pos, user)
    local allAtmosTriggers = Ext.Entity.GetAllEntitiesWithComponent("ServerAtmosphereTrigger")
    local player = Osi.GetHostCharacter() --[[@as GUIDSTRING]]

    pos = pos or {RBGetPosition(player)}

    for i, trigger in ipairs(allAtmosTriggers) do
        local max = trigger.TriggerArea.Bounds.BoundsMax
        local min = trigger.TriggerArea.Bounds.BoundsMin

        local triggerPos = trigger.Transform.Transform.Translate

        local worldMin = {
            min[1] + triggerPos[1],
            min[2] + triggerPos[2],
            min[3] + triggerPos[3],
        }
        local worldMax = {
            max[1] + triggerPos[1],
            max[2] + triggerPos[2],
            max[3] + triggerPos[3],
        }

        if MathUtils.IsInBoundingBox(pos, worldMin, worldMax) then
            return trigger
        end
    end

    return nil
end

function FindCurrentLightingTrigger(pos, user)
    local allLightTriggers = Ext.Entity.GetAllEntitiesWithComponent("ServerLightingTrigger")
    local player = Osi.GetHostCharacter() --[[@as GUIDSTRING]]

    pos = pos or {RBGetPosition(player)}
    for i, trigger in ipairs(allLightTriggers) do
        local max = trigger.TriggerArea.Bounds.BoundsMax
        local min = trigger.TriggerArea.Bounds.BoundsMin

        local triggerPos = trigger.Transform.Transform.Translate

        local worldMin = {
            min[1] + triggerPos[1],
            min[2] + triggerPos[2],
            min[3] + triggerPos[3],
        }
        local worldMax = {
            max[1] + triggerPos[1],
            max[2] + triggerPos[2],
            max[3] + triggerPos[3],
        }

        if MathUtils.IsInBoundingBox(pos, worldMin, worldMax) then
            return trigger
        end
    end

    return nil
end