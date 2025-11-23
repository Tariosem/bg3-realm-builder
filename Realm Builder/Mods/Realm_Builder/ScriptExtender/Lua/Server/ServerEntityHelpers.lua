function FindCurrentAtmosphereTrigger()
    local allAtmosTriggers = Ext.Entity.GetAllEntitiesWithComponent("ServerAtmosphereTrigger")
    local player = Osi.GetHostCharacter() --[[@as GUIDSTRING]]

    local px, py, pz = CGetPosition(player)

    for i, trigger in ipairs(allAtmosTriggers) do
        local max = trigger.TriggerArea.Bounds.BoundsMax
        local min = trigger.TriggerArea.Bounds.BoundsMin

        local pos = trigger.Transform.Transform.Translate

        local worldMin = {
            min[1] + pos[1],
            min[2] + pos[2],
            min[3] + pos[3],
        }
        local worldMax = {
            max[1] + pos[1],
            max[2] + pos[2],
            max[3] + pos[3],
        }

        if IsInBoundingBox({px, py, pz}, worldMin, worldMax) then
            return trigger
        end
    end

    return nil
end

function FindCurrentLightingTrigger()
    local allLightTriggers = Ext.Entity.GetAllEntitiesWithComponent("ServerLightingTrigger")
    local player = Osi.GetHostCharacter() --[[@as GUIDSTRING]]

    local px, py, pz = CGetPosition(player)

    for i, trigger in ipairs(allLightTriggers) do
        local max = trigger.TriggerArea.Bounds.BoundsMax
        local min = trigger.TriggerArea.Bounds.BoundsMin

        local pos = trigger.Transform.Transform.Translate

        local worldMin = {
            min[1] + pos[1],
            min[2] + pos[2],
            min[3] + pos[3],
        }
        local worldMax = {
            max[1] + pos[1],
            max[2] + pos[2],
            max[3] + pos[3],
        }

        if IsInBoundingBox({px, py, pz}, worldMin, worldMax) then
            return trigger
        end
    end

    return nil
end