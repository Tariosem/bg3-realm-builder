--- workaround for spawning scenery
local isSpawning = false

--- @type table<integer, fun(data: SpawnResponseData)>
local spawnIdCallbacks = {}
local spawnId = 0

--- @param data SpawnResponseData
NetChannel.Spawn:SetHandler(function(data, userID)
    if data.RequestId then
        local callback = spawnIdCallbacks[data.RequestId]
        if callback then
            callback(data)
        end
    end
    if data.Idle ~= nil then
        isSpawning = not data.Idle
    end
end)

local function getSpawnId()
    spawnId = spawnId + 1
    return spawnId
end

--- @param id integer
--- @param callback fun(data: {Guid: GUIDSTRING, RequestId: integer})?
local function setSpawnIdCallback(id, callback)
    spawnIdCallbacks[id] = callback
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

    local reqId = getSpawnId()
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

    local childrenCnt = #prefabObj.Children
    setSpawnIdCallback(reqId, function(data)
        table.insert(spawned, data.Guid)
        _P("Spawned: " .. #spawned .. " / " .. childrenCnt)
        if #spawned == childrenCnt then
            pushCommand()
            setSpawnIdCallback(reqId, nil)
        end
    end)

    while EntityStore.Tree:Find(folderName) do
        folderName = prefabObj.Name .. "_" .. tostring(cnt)
        cnt = cnt + 1
    end
    local entPath = { folderName }
    for i, child in pairs(prefabObj.Children or {}) do
        local childTemplateId = child
        local childTemplateObj = Ext.Template.GetTemplate(childTemplateId)
        local childTemplateNameId = childTemplateObj.Name .. "_" .. child
        if not childTemplateObj then
            Warning("[spawnPrefab] Child template not found: " .. tostring(childTemplateId))
            goto continue
        end
        local childEntInfo = {}

        childEntInfo.Position = prefabObj.ChildrenTransforms[i].Translate or { 0, 0, 0 }
        childEntInfo.Rotation = prefabObj.ChildrenTransforms[i].RotationQuat or { 0, 0, 0, 1 }

        -- Calculate relative position/rotation
        local pos, rot = MathUtils.GetLocalRelativeTransform(pivotTransform, childEntInfo.Position, childEntInfo.Rotation)
        if not pos or not rot then
            Warning("[spawnPrefab] Failed to calculate relative transform for prefab child.")
            pos = pivotTransform.Translate
            rot = pivotTransform.RotationQuat
        end
        childEntInfo.Position = pos
        childEntInfo.Rotation = rot
        childEntInfo.Scale = prefabObj.ChildrenTransforms[i].Scale
        childEntInfo.Path = entPath


        NetChannel.Spawn:SendToServer({
            TemplateId = childTemplateNameId,
            EntInfo = childEntInfo,
            RequestId = reqId
        })
    
        ::continue::
    end
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

    local templateObj = Ext.Template.GetTemplate(RBUtils.TakeTailTemplate(template))
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

    local reqId = getSpawnId()
    setSpawnIdCallback(reqId, function(data)
        spawnedGuid = data.Guid
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
    packedData.RequestId = reqId

    NetChannel.Spawn:SendToServer(packedData)
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


    local duplicateCnt = 0
    local toGet = {}
    for _, guid in pairs(targets) do
        local stored = EntityStore:GetStoredData(guid)
        if stored then
            templateMap[guid] = stored.TemplateId
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
    NetChannel.GetTemplate:RequestToServer({ Guid = toGet }, function(response)
        for guid, templateId in pairs(response.GuidToTemplateId) do
            templateMap[guid] = templateId
        end

        for _, guid in pairs(targets) do
            local templateId = templateMap[guid]
            if templateId then
                duplicateCnt = duplicateCnt + 1
            end
        end
        if duplicateCnt == 0 then
            Warning("[DuplicateCommand] No valid entities to duplicate.")
            return
        end
        spawn()
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

    local reqId = getSpawnId()
    setSpawnIdCallback(reqId, function(data)
        table.insert(spawnedDuplications, data.Guid)
        _P("Duplicated: " .. #spawnedDuplications .. " / " .. duplicateCnt)
        if #spawnedDuplications == duplicateCnt then
            selectAndPushCommand()
            setSpawnIdCallback(reqId, nil)
        end
    end)

    Debug("[DuplicateCommand] Spawning " .. tostring(duplicateCnt) .. " duplicated entities.")
    function spawn()
        for guid, templateId in pairs(templateMap) do
            local transform = oriTransforms[guid]

            local entData = originStats[guid] or {}
            entData.Path = path
            entData.Position = transform.Translate
            entData.Rotation = transform.RotationQuat
            NetChannel.Spawn:SendToServer({
                TemplateId = templateId,
                EntInfo = entData,
                RequestId = reqId
            })
        end
    end
end

--- @param data SceneData
function Commands.SpawnPreset(data)
    local spawnedGuids = {}
    local tree = TreeTable.FromTableStatic(data.Tree)
    local toSpawnCnt = RBTableUtils.CountMap(data.Spawned)
    local pivotTransform = {
        Translate = Vec3.new(data.Position),
        RotationQuat = Quat.new(data.Rotation),
        Scale = Vec3.new(1, 1, 1)
    }

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
    local reqId = getSpawnId()
    setSpawnIdCallback(reqId, function(data)
        table.insert(spawnedGuids, data.Guid)
        if #spawnedGuids == toSpawnCnt then
            pushCommand()
            setSpawnIdCallback(reqId, nil)
        end
    end)

    local function spawnNode(entData, savedGuid)
        local pos, rot = entData.Position, entData.Rotation or Quat.Identity()
        if data.PresetType == "Relative" then
            --- @diagnostic disable-next-line
            pos, rot = MathUtils.GetLocalRelativeTransform(pivotTransform, pos, rot)
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

        NetChannel.Spawn:SendToServer({
            TemplateId = entData.TemplateId,
            EntInfo = entData or {},
            Type = data.SpawnType,
            RequestId = reqId
        })
    end

    for savedGuid, entData in pairs(data.Spawned) do
        spawnNode(entData, savedGuid)
    end
end

SpawnInspector = {}

function SpawnInspector.IsSpawningInProgress()
    return isSpawning
end