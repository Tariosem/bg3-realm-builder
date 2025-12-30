local nearByEntries = {
}

NearbyMap = NearbyMap or {}

local function safeGetSceneryName(entity)
    local vres = entity.Visual and entity.Visual.Visual and entity.Visual.Visual.VisualResource
    local displayName = vres and RBStringUtils.GetLastPath(vres.SourceFile) or "Unknown_Scenery"
    return displayName
end

--- @type table<string,EntityHandle>
local SceneryRegistry = {}

local function ClearNearbyMap(pos, radius)
    nearByEntries = {}
    for guid, ent in pairs(SceneryRegistry) do
        if not ent.Transform or not ent.Transform.Transform or not ent.Transform.Transform.Translate then
            SceneryRegistry[guid] = nil
            goto continue
        end
        local newDis = Ext.Math.Distance(pos, ent.Transform.Transform.Translate)
        if radius and newDis > radius then
            SceneryRegistry[guid] = nil
        else
            local newEntry = {
                Guid = guid,
                DisplayName = safeGetSceneryName(ent),
                Entity = ent,
                Distance = newDis,
                IsScenery = true,
            }
            table.insert(nearByEntries, newEntry)
        end
        ::continue::
    end
end

---@param pos Vec3?
---@param radius number?
function NearbyMap.UpdateNearbyMap(pos, radius)
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

function NearbyMap.PopulateSceneryNearby(pos, radius, onComplete)
    pos = pos or { RBGetPosition(RBGetHostCharacter()) }
    radius = radius or 18
    local thread
    local lastYieldTime = Ext.Timer.MicrosecTime()
    local yieldThreshold = 100 -- microseconds
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
            local entry = {
                Guid = guid,
                DisplayName = safeGetSceneryName(entity),
                Entity = entity,
                Distance = dis,
                IsScenery = true,
            }
            table.insert(nearByEntries, entry)
            SceneryRegistry[guid] = entity
            if Ext.Timer.MicrosecTime() - lastYieldTime > yieldThreshold then
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
function NearbyMap.GetAllNearbyEntries()
    return nearByEntries
end

function NearbyMap.RegisterScenery(entity)
    if not entity or not entity.Scenery then return end
    local guid = entity.Scenery.Uuid
    SceneryRegistry[guid] = entity
end

function NearbyMap.GetRegisteredScenery(guid)
    return SceneryRegistry[guid]
end