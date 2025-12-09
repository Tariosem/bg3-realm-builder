--- workaround for spawning scenery
--- @type ({func:fun(), cnt:number})[]
local spawnQueue = {}
local maxSpawningAtOnce = 500
local spawningCnt = 0
local isResuming = false
local spawnPipeline

--[[
NetChannel.Spawn:SetHandler(function(data, userID)
    Timer:Ticks(30, function(timerID)
        NetChannel.Spawn:SendToServer({
            Resume = true,
        })
    end)
end)
]]

local function safeResume(co)
    if isResuming then
        Warning("Spawn pipeline is already resuming, skipping nested resume.")
        return
    end
    if coroutine.status(co) ~= "suspended" then
        Warning("Spawn pipeline is not in a resumable state: " .. tostring(coroutine.status(co)))
        return
    end

    local ok, err = coroutine.resume(co)
    if not ok then
        Error(debug.traceback(co, "Error resuming spawn pipeline: " .. tostring(err)))
    end
end

local function reviveSpawnPipeline()
    spawnPipeline = coroutine.create(function()
        while true do
            if #spawnQueue == 0 then
                Debug("Spawn pipeline idle, yielding...")
                coroutine.yield()
            else
                Debug("Spawn pipeline processing queue, remaining items: " .. tostring(#spawnQueue))
                local spawnObj = table.remove(spawnQueue, 1)
                local spawnFunc = spawnObj.func
                local spawnCnt = spawnObj.cnt or 1
                spawnFunc()
                spawningCnt = spawningCnt - spawnCnt
            end
        end
    end)
    if #spawnQueue > 0 then
        safeResume(spawnPipeline)
    end
end

reviveSpawnPipeline()

local function waitFor30TicksAndResume()
    isResuming = true
    Timer:Ticks(30, function(timerID)
        isResuming = false
        local ok, err = coroutine.resume(spawnPipeline)
        if not ok then
            Error("Error resuming spawn pipeline: " .. tostring(err))
        end
    end)
    coroutine.yield()
end

local exceedNotif = Notification.new("Spawn Queue Full")
exceedNotif.Pivot = { 0.7, 0 }
local function push(func, cnt)
    if cnt + spawningCnt > maxSpawningAtOnce then
        exceedNotif:Show("Spawn Queue Full",
            "The spawn queue has reached its maximum capacity of " ..
            tostring(maxSpawningAtOnce) ..
            " spawning operations.\n Please wait for existing operations to complete before adding more.")
        Warning("Try again later, too many spawning operations in the queue.")
        return
    end
    spawningCnt = spawningCnt + (cnt or 1)
    table.insert(spawnQueue, { func = func, cnt = cnt or 1 })
    if coroutine.status(spawnPipeline) == "suspended" then
        safeResume(spawnPipeline)
    else
        reviveSpawnPipeline()
    end
end

--- @param prefabObj PrefabTemplate
---@param entInfo EntityData
local function spawnPrefab(prefabObj, entInfo)
    local pivotTransform = {
        Translate = entInfo.Position or { 0, 0, 0 },
        RotationQuat = entInfo.Rotation or { 0, 0, 0, 1 },
        Scale = { 1, 1, 1 }
    }
    local spawned = {}

    local cnt = 1
    local folderName = prefabObj.Name

    local function pushCommand()
        HistoryManager:PushCommand({
            Undo = function()
                NetChannel.Delete:SendToServer({ Guid = spawned })
            end,
            Redo = function()
                NetChannel.Restore:SendToServer({ Guid = spawned })
            end,
            Description = "Spawn Prefab"
        })
    end

    push(function()
        while EntityStore.Tree:Find(folderName) do
            folderName = prefabObj.Name .. "_" .. tostring(cnt)
            cnt = cnt + 1
        end
        local entPath = { folderName }
        for i, child in pairs(prefabObj.Children or {}) do
            local childTemplateId = child
            local childTemplateObj = Ext.Template.GetTemplate(childTemplateId)
            if not childTemplateObj then
                Warning("[spawnPrefab] Child template not found: " .. tostring(childTemplateId))
                goto continue
            end
            local childEntInfo = {}

            childEntInfo.Position = prefabObj.ChildrenTransforms[i].Translate or { 0, 0, 0 }
            childEntInfo.Rotation = prefabObj.ChildrenTransforms[i].RotationQuat or { 0, 0, 0, 1 }

            -- Calculate relative position/rotation
            local pos, rot = MathHelpers.GetLocalRelativeTransform(pivotTransform, childEntInfo.Position, childEntInfo.Rotation)
            if not pos or not rot then
                Warning("[spawnPrefab] Failed to calculate relative transform for prefab child.")
                pos = pivotTransform.Translate
                rot = pivotTransform.RotationQuat
            end
            childEntInfo.Position = pos
            childEntInfo.Rotation = rot
            childEntInfo.Scale = prefabObj.ChildrenTransforms[i].Scale
            childEntInfo.Path = entPath

            NetChannel.Spawn:RequestToServer({
                TemplateId = childTemplateId,
                EntInfo = childEntInfo
            }, function(response)
                table.insert(spawned, response.Guid)
                if #spawned == #prefabObj.Children then
                    pushCommand()
                end
            end)

            if childTemplateObj.TemplateType ~= "item" and childTemplateObj.TemplateType ~= "character" then
                -- Wait to make template overwirte work properly
                waitFor30TicksAndResume()
            end
            ::continue::
        end
    end, #prefabObj.Children)
end

---@param template string
---@param entInfo EntityData|nil
function Commands.SpawnCommand(template, entInfo)
    entInfo = entInfo and RBUtils.DeepCopy(entInfo) or {}
    local packedData = {
        TemplateId = template,
        EntInfo = entInfo
    }
    local spawnedGuid = nil

    local templateObj = Ext.Template.GetTemplate(EntityHelpers.TakeTailTemplate(template))
    local isVisual = Ext.Resource.Get(template, "Visual")
    if not templateObj and not isVisual then
        Warning("[SpawnCommand] Template not found: " .. tostring(template))
        return
    end
    if templateObj and templateObj.TemplateType == "prefab" then
        --- @diagnostic disable-next-line
        spawnPrefab(templateObj, entInfo)
        return
    end
    if isVisual then
        packedData.EntInfo.DisplayName = RBStringUtils.GetLastPath(isVisual.SourceFile)
    end

    push(function()
        NetChannel.Spawn:RequestToServer(packedData, function(response)
            spawnedGuid = response.Guid
            HistoryManager:PushCommand({
                Undo = function()
                    NetChannel.Delete:SendToServer({ Guid = spawnedGuid })
                end,
                Redo = function()
                    NetChannel.Restore:SendToServer({ Guid = spawnedGuid })
                end,
                Description = "Spawn Entity"
            })
        end)
        if templateObj and templateObj.TemplateType ~= "item" and templateObj.TemplateType ~= "character" then
            -- Wait to make template overwirte work properly
            waitFor30TicksAndResume()
        end
    end, 1)
end

--- @param targets GUIDSTRING[]
--- @param path string[]?
function Commands.DuplicateCommand(targets, path)
    if #targets == 0 then return end
    local oriTransforms = {}
    for _, guid in pairs(targets) do
        oriTransforms[guid] = EntityHelpers.SaveTransform(guid)
    end
    local spawnedDuplications = {}
    local templateMap = {}
    local originStats = {}
    local nonItemNonCharacter = {}

    local toGet = {}

    for _, guid in pairs(targets) do
        local stored = EntityStore:GetStoredData(guid)
        if stored then
            templateMap[guid] = stored.TemplateId
            local templateObj = Ext.Template.GetTemplate(EntityHelpers.TakeTailTemplate(stored.TemplateId))
            if not templateObj or (templateObj.TemplateType ~= "item" and templateObj.TemplateType ~= "character") then
                nonItemNonCharacter[guid] = true
            end
            originStats[guid] = RBUtils.DeepCopy(stored)
            originStats[guid].DisplayName = nil
            if path then
                originStats[guid].Path = path
            end
        else
            table.insert(toGet, guid)
        end
    end

    local spawn
    local toDuplicate = {}
    NetChannel.GetTemplate:RequestToServer({ Guid = toGet }, function(response)
        for guid, templateId in pairs(response.GuidToTemplateId) do
            templateMap[guid] = templateId
        end

        for _, guid in pairs(targets) do
            local templateId = templateMap[guid]
            if templateId then
                table.insert(toDuplicate, guid)
            end
        end
        push(function()
            spawn()
        end, #toDuplicate)
    end)

    local function selectAndPushCommand()
        local proxies = {}
        for _, guid in pairs(spawnedDuplications) do
            local proxy = MovableProxy.CreateByGuid(guid)
            if proxy then
                table.insert(proxies, proxy)
            end
        end

        HistoryManager:PushCommand({
            Undo = function()
                NetChannel.Delete:SendToServer({ Guid = spawnedDuplications })
            end,
            Redo = function()
                NetChannel.Restore:SendToServer({ Guid = spawnedDuplications })
            end,
            Description = "Duplicate Entities"
        })

        Timer:Ticks(30, function()
            RB_GLOBALS.TransformEditor:Select(proxies)
            RB_GLOBALS.TransformEditor.Gizmo:StartDragging()
        end)
    end

    function spawn()
        for guid, templateId in pairs(templateMap) do
            local transform = oriTransforms[guid]

            local entData = originStats[guid] or {}
            entData.Path = path
            entData.Position = transform.Translate
            entData.Rotation = transform.RotationQuat
            NetChannel.Spawn:RequestToServer({
                TemplateId = templateId,
                EntInfo = entData
            }, function(response)
                table.insert(spawnedDuplications, response.Guid)
                if #spawnedDuplications == RBTableUtils.CountMap(templateMap) then
                    selectAndPushCommand()
                end
            end)

            if nonItemNonCharacter[guid] then
                -- Wait to make template overwirte work properly
                waitFor30TicksAndResume()
            end
        end
    end
end

--- @param data SceneData
function Commands.SpawnPreset(data)
    local spawnedGuids = {}
    local tree = TreeTable.FromTableStatic(data.Tree)
    local pivotTransform = {
        Translate = Vec3.new(data.Position),
        RotationQuat = Quat.new(data.Rotation),
        Scale = Vec3.new(1, 1, 1)
    }

    local spawnNode
    local function threadFunc()
        for savedGuid, entData in pairs(data.Spawned) do
            spawnNode(entData, savedGuid)
        end
    end

    local function pushCommand()
        HistoryManager:PushCommand({
            Undo = function()
                NetChannel.Delete:SendToServer({ Guid = spawnedGuids })
            end,
            Redo = function()
                NetChannel.Restore:SendToServer({ Guid = spawnedGuids })
            end,
            Description = "Spawn Preset"
        })
    end

    function spawnNode(entData, savedGuid)
        local pos, rot = entData.Position, entData.Rotation or Quat.Identity()
        if data.PresetType == "Relative" then
            --- @diagnostic disable-next-line
            pos, rot = MathHelpers.GetLocalRelativeTransform(pivotTransform, pos, rot)
            if not pos or not rot then
                Warning("[SpawnPreset] Failed to calculate relative transform.")
                return
            end
            entData.Position = pos
            entData.Rotation = rot
        end
        if not pos or not rot then
            Warning("[SpawnPreset] Entity data missing position or rotation.")
            return
        end

        if tree then
            entData.Path = tree:GetPath(savedGuid, true, true)
        end

        if not entData.Group then
            entData.Group = data.Name
        end

        NetChannel.Spawn:RequestToServer({
            TemplateId = entData.TemplateId,
            EntInfo = entData or {},
            Type = data.SpawnType
        }, function(response)
            local newGuid = response.Guid
            table.insert(spawnedGuids, newGuid)
            if #spawnedGuids == RBTableUtils.CountMap(data.Spawned) then
                pushCommand()
            end
        end)

        local templateObj = Ext.Template.GetTemplate(EntityHelpers.TakeTailTemplate(entData.TemplateId))
        if not templateObj or (templateObj.TemplateType ~= "item" and templateObj.TemplateType ~= "character") then
            -- Wait to make template overwirte work properly
            waitFor30TicksAndResume()
        end
    end

    push(threadFunc, RBTableUtils.CountMap(data.Spawned))
end
