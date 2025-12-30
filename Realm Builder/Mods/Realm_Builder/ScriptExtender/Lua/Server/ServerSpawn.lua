local spawnCoroutine = nil
local isWaitingForResume = false
local spawnBroadcastDirty = true

--- @class SpawnResponseData
--- @field Guid GUIDSTRING?
--- @field Idle boolean?
--- @field RequestId integer?

--- @type {Data:SpawnData, RequestId:integer, UserId:integer}[]
local queuedSpawnData = {}

--- @type function
local createCoroutine

local function safeResume()
    if isWaitingForResume then
        return
    end

    if not spawnCoroutine then
        RBPrintBlue("[SpawnCoroutine] No spawn coroutine to resume.")
        return
    end

    local isRunning = coroutine.status(spawnCoroutine) == "running"

    if isRunning then
        RBPrintBlue("[SpawnCoroutine] Spawn coroutine is already running, not resuming.")
        return
    end

    local ok, err = coroutine.resume(spawnCoroutine)
    if not ok then
        Error("Error when resuming spawn coroutine: " .. tostring(err))
    end
end

local function waitForTicks(cnt, user)
    cnt = cnt or 30
    isWaitingForResume = true
    local antiSpammer = nil
    Timer:ClientOnTicks(cnt, function(timerID)
        if antiSpammer then
            Timer:Cancel(antiSpammer)
            antiSpammer = nil
        end
        isWaitingForResume = false
        safeResume()
    end, user)

    antiSpammer = Timer:Ticks(600, function (timerID)
        isWaitingForResume = false
        safeResume()
    end)
end

--- @param data SpawnData
--- @return {Guid:GUIDSTRING?, TemplateId:string}
local function spawnHandler(data)
    local template = data.TemplateId
    local entInfo = data.EntInfo or {}
    local position = entInfo.Position
    local rotation = entInfo.Rotation
    if not position or #position ~= 3 then
        position = { 0, 0, 0 }
    end
    if not rotation or #rotation ~= 4 then
        rotation = { 0, 0, 0, 1 }
    end
    local rtype = data.Type

    if rtype == "Preview" then
        local previewItem = OsirisHelpers.PreviewTemplate(template, position[1], position[2], position[3], rotation[1],
            rotation[2], rotation[3], rotation[4], entInfo and entInfo.VisualPreset, data.Duration or 5000)
        if not previewItem then
            return { Guid = nil, TemplateId = template }
        end

        if entInfo.Scale then
            NetChannel.SetVisualTransform:Broadcast({ Guid = previewItem, Transforms = { [previewItem] = { Scale = entInfo.Scale } } })
        end
        return { Guid = previewItem, TemplateId = template }
    end

    local newGuid = EntityManager:CreateAt(template, position[1], position[2], position[3], rotation[1], rotation
        [2], rotation[3], rotation[4])

    if not newGuid then
        return { Guid = nil, TemplateId = template }
    end

    EntityManager:SetEntity(newGuid, entInfo or {})

    entInfo.Visible = true
    entInfo.Guid = newGuid
    entInfo.TemplateId = template

    if entInfo.Scale then
        NetChannel.SetVisualTransform:Broadcast({ Guid = newGuid, Transforms = { [newGuid] = { Scale = entInfo.Scale } } })
    end

    if entInfo.VisualPreset then
        Timer:Ticks(30, function()
            NetChannel.ApplyVisualPreset:Broadcast({ Guid = newGuid, TemplateName = RBStringUtils.TrimTail(template, 37), VisualPreset =
            entInfo.VisualPreset })
        end)
    end

    NetChannel.Entities.Added:Broadcast({ Entities = { entInfo } })

    return { Guid = newGuid }
end

function createCoroutine()
    if spawnCoroutine then
        return spawnCoroutine
    end
    spawnCoroutine = coroutine.create(function()
        while true do
            if #queuedSpawnData == 0 then
                --- wait for some time before checking the queue again
                --- so we don't spam the network with idle messages
                local antiSpammer = Timer:Ticks(30, function (timerID)
                    safeResume()
                end)
                coroutine.yield()
                Timer:Cancel(antiSpammer)

                if #queuedSpawnData == 0 then
                    RBPrintBlue("[SpawnCoroutine] Spawn queue is empty, broadcasting idle.")
                
                    NetChannel.Spawn:Broadcast({ Idle = true })
                    spawnBroadcastDirty = true
                    coroutine.yield()
                end
            end

            if spawnBroadcastDirty then
                NetChannel.Spawn:Broadcast({ Idle = false })
                spawnBroadcastDirty = false
            end

            RBPrintBlue("[SpawnCoroutine] Processing spawn queue. Queue length: " .. tostring(#queuedSpawnData))
            --- @type {Data:SpawnData, RequestId:integer, UserId:integer}?
            local data = table.remove(queuedSpawnData, 1)
            if data then
                local result = spawnHandler(data.Data, data.UserId)
                NetChannel.Spawn:SendToClient({
                    Guid = result.Guid,
                    RequestId = data.RequestId,
                }, data.UserId)
                if not RBUtils.IsItemOrCharacterTemplate(data.Data.TemplateId) then
                    waitForTicks(30, data.UserId)
                    coroutine.yield()
                end
            end
        end
    end)
    return spawnCoroutine
end

--- @param data SpawnData
--- @param reqId integer
--- @param userId integer
local function enqueueSpawnData(data, reqId, userId)
    table.insert(queuedSpawnData, {
        Data = data,
        RequestId = reqId,
        UserId = userId,
    })

    if not spawnCoroutine then
        createCoroutine()
        safeResume()
    else
        safeResume()
    end
end

createCoroutine()

--- @param data SpawnData
NetChannel.Spawn:SetHandler(function(data, userID)
    enqueueSpawnData(data, data.RequestId, userID)
    --spawnHandler(data)
end)

NetChannel.Spawn:SetRequestHandler(function(data, userID)
    return spawnHandler(data)
end)

RegisterConsoleCommand("rb_reboot_spawn_coroutine", function()
    if spawnCoroutine and coroutine.status(spawnCoroutine) ~= "dead" then
        local ok, err = coroutine.close(spawnCoroutine)
        if not ok then
            Error("Error when killing spawn coroutine: " .. tostring(err))
        end
        spawnCoroutine = nil
    end

    createCoroutine()
    safeResume()
end)