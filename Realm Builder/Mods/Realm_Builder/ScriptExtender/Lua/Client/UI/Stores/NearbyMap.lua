local nearByEntries = {
}

--- @type table<string,EntityHandle>
SceneryRegistry = SceneryRegistry or {}

local function ClearNearbyMap(pos, radius)
    nearByEntries = {}
    for guid, entry in pairs(SceneryRegistry) do
        local newDis = Ext.Math.Distance(pos, entry.Transform.Transform.Translate)
        if radius and newDis > radius then
            SceneryRegistry[guid] = nil
        else
            local newEntry = {
                Guid = guid,
                DisplayName = entry.Visual and entry.Visual.Visual and
                RBStringUtils.GetLastPath(entry.Visual.Visual.VisualResource.SourceFile),
                Entity = entry,
                Distance = newDis,
                IsScenery = true,
            }
            table.insert(nearByEntries, newEntry)
        end
    end
end

---@param pos Vec3?
---@param radius number?
function UpdateNearbyMap(pos, radius)
    if not pos then
        pos = { RBGetPosition(RBGetHostCharacter()) }
    end
    radius = radius or 18
    ClearNearbyMap(pos, radius)

    if #pos ~= 3 then
        return
    end

    local entries = EntityHelpers.GetNearbyCharactersAndItems(pos, radius)
    if not entries or #entries == 0 then return end

    for _, entry in pairs(entries) do
        local guid = entry.Guid
        local displayName = RBGetName(guid)
        entry.DisplayName = displayName
        entry.Entity = nil
        table.insert(nearByEntries, entry)
    end
end

function PopulateSceneryNearby(pos, radius, onComplete)
    pos = pos or { RBGetPosition(RBGetHostCharacter()) }
    radius = radius or 18
    local thread
    local lastYieldTime = Ext.Timer.MicrosecTime()
    thread = coroutine.create(function()
        local entities = Ext.Entity.GetAllEntitiesWithComponent("Scenery")
        for _, entity in pairs(entities) do
            local guid = entity.Scenery.Uuid
            local entityPos = entity.Transform and entity.Transform.Transform and entity.Transform.Transform.Translate
            if not entityPos then
                goto continue
            end
            local dis = Ext.Math.Distance(entityPos, pos)
            if dis > radius then
                goto continue
            end
            if SceneryRegistry[guid] then
                goto continue
            end
            local displayName = entity.Visual and entity.Visual.Visual and
            RBStringUtils.GetLastPath(entity.Visual.Visual.VisualResource.SourceFile)
            local entry = {
                Guid = guid,
                DisplayName = displayName,
                Entity = entity,
                Distance = dis,
                IsScenery = true,
            }
            table.insert(nearByEntries, entry)
            SceneryRegistry[guid] = entity
            if Ext.Timer.MicrosecTime() - lastYieldTime > 1 then
                lastYieldTime = Ext.Timer.MicrosecTime()
                Ext.OnNextTick(function()
                    local ok, err = coroutine.resume(thread)
                    if not ok then
                        Error("PopulateSceneryNearby Error: " .. err)
                        Error(debug.traceback(thread, err))
                    end
                end)
                coroutine.yield()
            end
            ::continue::
        end
        if onComplete then
            onComplete()
        end
    end)

    local ok, err = coroutine.resume(thread)
    if not ok then
        Error("PopulateSceneryNearby Error: " .. err)
        Error(debug.traceback(thread, err))
    end
end

--- @return NearbyEntry[]
function GetAllNearbyEntries()
    return nearByEntries
end
