--- @class Commands
--- @field SetTransform fun(proxies: RB_MovableProxy|RB_MovableProxy[], transform: {Translate: Vec3|nil, RotationQuat: Quat|nil, Scale: Vec3|nil}, notRecordHistory: boolean|nil)
--- @field Bind fun(targets: GUIDSTRING|GUIDSTRING[], parent: GUIDSTRING)
--- @field Unbind fun(targets: GUIDSTRING[])
--- @field Snap fun(targets: GUIDSTRING|GUIDSTRING[], onlyRotation: boolean|nil, onlyPosition: boolean|nil)
Commands = Commands or {}

--- @param proxies RB_MovableProxy[]
--- @param notRecordHistory boolean|nil
function Commands.SetTransform(proxies, transform, notRecordHistory)
    local redoTransforms = {}
    local undoTransforms = {}
    for _, proxy in pairs(proxies) do
        undoTransforms[proxy] = proxy:GetTransform()
    end

    if transform.Translate or transform.RotationQuat or transform.Scale then
        local t = {}
        for _, proxy in pairs(proxies) do
            t[proxy] = transform
        end
        redoTransforms = t
    end

    local function doTransform(isReset)
        for _, proxy in pairs(proxies) do
            local targetTransform = isReset and undoTransforms[proxy] or redoTransforms[proxy]
            if targetTransform then
                proxy:SetTransform(targetTransform)
            end
        end
    end

    doTransform()
    if not notRecordHistory then
        HistoryManager:PushCommand({
            Undo = function()
                doTransform(true)
            end,
            Redo = function()
                doTransform(false)
            end
        })
    end
end

function Commands.Bind(targets, parent)
    NetChannel.Bind:SendToServer({ Type = "Bind", Parent = parent, Guid = targets })

    HistoryManager:PushCommand({
        Undo = function()
            NetChannel.Bind:SendToServer({ Type = "Unbind", Guid = targets })
        end,
        Redo = function()
            NetChannel.Bind:SendToServer({ Type = "Bind", Parent = parent, Guid = targets })
        end
    })
end

function Commands.Unbind(targets)
    local oriParents = {}
    for _, guid in ipairs(targets) do
        local parent = EntityStore:GetBindParent(guid)
        if parent then
            oriParents[guid] = parent
        end
    end

    NetChannel.Bind:SendToServer({ Type = "Unbind", Guid = targets })

    HistoryManager:PushCommand({
        Undo = function()
            for guid, parent in pairs(oriParents) do
                NetChannel.Bind:SendToServer({ Type = "Bind", Guid = { guid }, Parent = parent })
            end
        end,
        Redo = function()
            NetChannel.Bind:SendToServer({ Type = "Unbind", Guid = targets })
        end
    })
end

function Commands.SnapCommand(targets, onlyRotation, onlyPosition)
    local parents = {}
    for _, guid in ipairs(targets) do
        local parent = EntityStore:GetBindParent(guid)
        if parent then
            parents[guid] = parent
        end
    end
    local targetPos = {}
    for guid, parent in pairs(parents) do
        targetPos[guid] = { Translate = { CGetPosition(parent) }, RotationQuat = { CGetRotation(parent) } }
    end
    if onlyRotation then
        for guid, pos in pairs(targetPos) do
            pos.Translate = nil
        end
    elseif onlyPosition then
        for guid, pos in pairs(targetPos) do
            pos.RotationQuat = nil
        end
    end

    local targetProxies = {}
    for _, guid in ipairs(targets) do
        local proxy = MovableProxy.CreateByGuid(guid)
        if proxy then
            table.insert(targetProxies, proxy)
        end
    end

    Commands.SetTransform(targetProxies, targetPos)
end

---@param template string
---@param position Vec3
---@param rotation Quat
---@param entInfo EntityData|nil
function Commands.SpawnCommand(template, position, rotation, entInfo)
    entInfo = entInfo and DeepCopy(entInfo) or {}
    local packedData = {
        TemplateId = template,
        Position = position,
        Rotation = rotation,
        EntInfo = entInfo
    }
    local spawnedGuid = nil

    NetChannel.Spawn:RequestToServer(packedData, function(response)
        spawnedGuid = response.Guid
    end)

    HistoryManager:PushCommand({
        Undo = function()
            if spawnedGuid then
                NetChannel.Delete:SendToServer({ Guid = spawnedGuid })
            end
        end,
        Redo = function()
            NetChannel.Spawn:SendToServer(packedData)
        end
    })
end

--- @param targets GUIDSTRING[]
function Commands.DuplicateCommand(targets)
    if #targets == 0 then return end
    local oriTransforms = {}
    for _, guid in pairs(targets) do
        oriTransforms[guid] = EntityHelpers.SaveTransform(guid)
    end
    local spawnedDuplications = {}
    local templateMap = {}
    local nonItemNonCharacter = {}

    local toGet = {}
    
    for _, guid in pairs(targets) do
        local stored = EntityStore:GetStoredData(guid)
        if stored then
            templateMap[guid] = stored.TemplateId
            if stored.IsScenery then
                nonItemNonCharacter[guid] = true
            end
        else
            table.insert(toGet, guid)
        end
    end

    NetChannel.GetTemplate:RequestToServer({ Guid = toGet }, function(response)
        for guid, templateId in pairs(response.GuidToTemplateId) do
            templateMap[guid] = templateId
        end

        local toDuplicate = {}
        for _, guid in pairs(targets) do
            local templateId = templateMap[guid]
            if templateId then
                table.insert(toDuplicate, guid)
            end
        end
    end)

    local thread
    local function spawn()
        for guid, templateId in pairs(templateMap) do
            local transform = oriTransforms[guid]
            
            NetChannel.Spawn:RequestToServer({
                TemplateId = templateId,
                Position = transform.Translate,
                Rotation = transform.RotationQuat,
            }, function(response)
                table.insert(spawnedDuplications, response.Guid)
                if #spawnedDuplications == CountMap(templateMap) then
                    coroutine.resume(thread)
                end
            end)

            if nonItemNonCharacter[guid] then
                -- Wait to make template overwirte work properly
                Timer:Ticks(30, function (timerID)
                    local ok, suc = coroutine.resume(thread)
                    if not ok then
                        Error("Error resuming duplication coroutine: " .. tostring(suc))
                    end
                end)

                coroutine.yield()
            end
        end
        coroutine.yield()

        local proxies = {}
        for _, guid in pairs(spawnedDuplications) do
            local proxy = MovableProxy.CreateByGuid(guid)
            if proxy then
                table.insert(proxies, proxy)
            end
        end

        RB_GLOBALS.TransformEditor:Select(proxies)
        RB_GLOBALS.TransformEditor.Gizmo:StartDragging()
    end

    thread = coroutine.create(spawn)
    coroutine.resume(thread)

    HistoryManager:PushCommand({
        Undo = function()
            NetChannel.Delete:SendToServer({ Guid = spawnedDuplications })
            spawnedDuplications = {}
        end,
        Redo = function()
            thread = coroutine.create(spawn)
            coroutine.resume(thread)
        end
    })
end

--- @param data SceneData
function Commands.SpawnPreset(data)
    _D(data)
    local spawnedGuids = {}
    local thread = nil
    local ok, err
    local tree = TreeTable.FromTableStatic(data.Tree)
    local pivotTransform = {
        Translate = Vec3.new(data.Position),
        RotationQuat = Quat.new(data.Rotation),
        Scale = Vec3.new(1,1,1)
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
                spawnedGuids = {}
            end,
            Redo = function()
                thread = coroutine.create(threadFunc)
                ok, err = coroutine.resume(thread)
                if not ok then
                    Error("SpawnPreset: Coroutine error: " .. tostring(err))
                end
            end
        })
    end

    function spawnNode(entData, savedGuid)
        local pos, rot = entData.Position, entData.Rotation
        if data.PresetType == "Relative" then
            pos, rot = GetLocalRelativeTransform(pivotTransform, pos, rot)
        end
        if not pos or not rot then
            Warning("[SpawnPreset] Entity data missing position or rotation.")
            return
        end

        if tree then
            entData.Path = tree:GetPath(savedGuid)
        end

        if not entData.Group then
            entData.Group = data.Name
        end

        NetChannel.Spawn:RequestToServer({
            TemplateId = entData.TemplateId,
            Position = pos,
            Rotation = rot,
            EntInfo = entData.EntInfo or {},
            Type = data.SpawnType
        }, function(response)
            local newGuid = response.Guid
            table.insert(spawnedGuids, newGuid)

            if #spawnedGuids == CountMap(data.Spawned) then
                pushCommand()
            end
        end)

        local templateObj = Ext.Template.GetTemplate(TakeTailTemplate(entData.TemplateId))
        if templateObj.TemplateType ~= "item" and templateObj.TemplateType ~= "character" then
            -- Wait to make template overwirte work properly
            Timer:Ticks(30, function (timerID)
                if not thread then
                    Error("SpawnPreset: Coroutine thread is nil.")
                    return
                end

                ok, err = coroutine.resume(thread)
                if not ok then
                    Error("Error resuming SpawnPreset coroutine: " .. tostring(err))
                end
            end)
            coroutine.yield()
        end
    end

    thread = coroutine.create(threadFunc)
    ok, err = coroutine.resume(thread)
    if not ok then
        Error("SpawnPreset: Coroutine error: " .. tostring(err))
    end
end

function Commands.DeleteCommand(targets)
    targets = NormalizeGuidList(targets)
    if #targets == 0 then return end

    local oriEntities = {}
    for _, guid in pairs(targets) do
        local entity = Ext.Entity.Get(guid) --[[@as EntityHandle]]
        if entity then
            oriEntities[guid] = DeepCopy(EntityStore:GetStoredData(guid))
        end
    end

    NetChannel.Delete:SendToServer({ Guid = targets })

    HistoryManager:PushCommand({
        Undo = function()
            for _, entityData in pairs(oriEntities) do
                Commands.SpawnCommand(
                    entityData.TemplateId,
                    Vec3.New(entityData.Transform.Position),
                    Quat.New(entityData.Transform.RotationQuat),
                    entityData
                )
            end
        end,
        Redo = function()
            NetChannel.Delete:SendToServer({ Guid = targets })
        end
    })
end

---@param target GUIDSTRING
---@param markerType 'SpotLight'|'PointLight'
function Commands.AddMarker(target, markerType)
    local spwanPost = {
        TemplateId = MARKER_ITEM[markerType],
        Position = { CGetPosition(target) },
        Rotation = { CGetRotation(target) },
        EntInfo = {
            DisplayName = "Spot Light Marker",
        }
    }

    NetChannel.Spawn:RequestToServer(spwanPost, function(response)
        local newGuid = response.Guid
        if newGuid then
            PickingHelpers:RegisterGuidRedirect(newGuid, target)

            Commands.Bind(newGuid, target)
        end
    end)
end
