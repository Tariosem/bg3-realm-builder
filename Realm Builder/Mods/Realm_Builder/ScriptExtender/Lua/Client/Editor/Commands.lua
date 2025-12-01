--- @class Commands
--- @field SetTransform fun(proxies: RB_MovableProxy|RB_MovableProxy[], transform: {Translate: Vec3|nil, RotationQuat: Quat|nil, Scale: Vec3|nil}, notRecordHistory: boolean|nil)
--- @field Bind fun(targets: GUIDSTRING|GUIDSTRING[], parent: GUIDSTRING)
--- @field Unbind fun(targets: GUIDSTRING[])
--- @field Snap fun(targets: GUIDSTRING|GUIDSTRING[], onlyRotation: boolean|nil, onlyPosition: boolean|nil)
Commands = Commands or {}

--- @param proxies RB_MovableProxy[]
--- @param transform table< RB_MovableProxy, {Translate: Vec3|nil, RotationQuat: Quat|nil, Scale: Vec3|nil} >|{Translate: Vec3|nil, RotationQuat: Quat|nil, Scale: Vec3|nil}
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

function Commands.SetTransformSeparate(proxies, transforms, notRecordHistory)
    local redoTransforms = transforms
    local undoTransforms = {}
    for _, proxy in pairs(proxies) do
        undoTransforms[proxy] = proxy:GetTransform()
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
    local targetProxies = {}
    local allParentTransform = {}
    for guid, parent in pairs(parents) do
        if allParentTransform[parent] == nil then
            local parentProxy = MovableProxy.CreateByGuid(parent)
            if parentProxy then
                allParentTransform[parent] = parentProxy:GetTransform()
                allParentTransform[parent].Scale = nil
            else
                allParentTransform[parent] = {
                    Translate = { CGetPosition(parent) },
                    RotationQuat = { CGetRotation(parent) },
                }
            end
            ::continue::
        end
        local proxy = MovableProxy.CreateByGuid(guid)
        if proxy then
            table.insert(targetProxies, proxy)
            targetPos[proxy] = allParentTransform[parent]
        end
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
    Commands.SetTransformSeparate(targetProxies, targetPos)
end

local function spawnPrefab(prefabObj, entInfo)
    local pivotTransform = {
        Translate = entInfo.Position or {0,0,0},
        RotationQuat = entInfo.Rotation or {0,0,0,1},
        Scale = {1,1,1}
    }
    local spawned = {}

    local cnt = 1
    local folderName = prefabObj.Name
    while EntityStore.Tree:Find(folderName) do
        folderName = prefabObj.Name .. "_" .. tostring(cnt)
        cnt = cnt + 1
    end
    local entPath = { folderName }

    local function pushCommand()
        HistoryManager:PushCommand({
            Undo = function()
                NetChannel.Delete:SendToServer({ Guid = spawned })
            end,
            Redo = function()
                NetChannel.Restore:SendToServer({ Guid = spawned })
            end
        })
    end

    local thread
    thread = coroutine.create(function()
        for i, child in pairs(prefabObj.Children or {}) do
            local childTemplateId = child
            local childTemplateObj = Ext.Template.GetTemplate(childTemplateId)
            if not childTemplateObj then
                Warning("[spawnPrefab] Child template not found: " .. tostring(childTemplateId))
                goto continue
            end
            local childEntInfo = {}

            childEntInfo.Position = prefabObj.ChildrenTransforms[i].Translate or {0,0,0}
            childEntInfo.Rotation = prefabObj.ChildrenTransforms[i].RotationQuat or {0,0,0,1}

            -- Calculate relative position/rotation
            local pos, rot = GetLocalRelativeTransform(pivotTransform, childEntInfo.Position, childEntInfo.Rotation)
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
                Timer:Ticks(30, function (timerID)
                    local ok, suc = coroutine.resume(thread)
                    if not ok then
                        Error("Error resuming spawnPrefab coroutine: " .. tostring(suc))
                    end
                end)

                coroutine.yield()
            end
            ::continue::
        end
    end)

    local ok, err = coroutine.resume(thread)
    if not ok then
        Error("spawnPrefab: Coroutine error: " .. tostring(err))
    end
end

---@param template string
---@param entInfo EntityData|nil
function Commands.SpawnCommand(template, entInfo)
    entInfo = entInfo and DeepCopy(entInfo) or {}
    local packedData = {
        TemplateId = template,
        EntInfo = entInfo
    }
    local spawnedGuid = nil

    local templateObj = Ext.Template.GetTemplate(TakeTailTemplate(template))
    local isVisual = Ext.Resource.Get(template, "Visual")
    if not templateObj and not isVisual then
        Warning("[SpawnCommand] Template not found: " .. tostring(template))
        return
    end
    if templateObj and templateObj.TemplateType == "prefab" then
        spawnPrefab(templateObj, entInfo)
        return
    end
    if isVisual then
        packedData.EntInfo.DisplayName = GetLastPath(isVisual.SourceFile)
    end

    NetChannel.Spawn:RequestToServer(packedData, function(response)
        spawnedGuid = response.Guid
        HistoryManager:PushCommand({
            Undo = function()
                NetChannel.Delete:SendToServer({ Guid = spawnedGuid })
            end,
            Redo = function()
                NetChannel.Restore:SendToServer({ Guid = spawnedGuid })
            end
        })
    end)
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
            local templateObj = Ext.Template.GetTemplate(TakeTailTemplate(stored.TemplateId))
            if not templateObj or (templateObj.TemplateType ~= "item" and templateObj.TemplateType ~= "character") then
                nonItemNonCharacter[guid] = true
            end
            originStats[guid] = DeepCopy(stored)
            originStats[guid].DisplayName = nil
            if path then
                originStats[guid].Path = path
            end
        else
            table.insert(toGet, guid)
        end
    end

    local spawn
    local thread
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
        thread = coroutine.create(spawn)
        local ok, err = coroutine.resume(thread)
        if not ok then
            Error("DuplicateCommand: Coroutine error: " .. tostring(err))
        end
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
            end
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
                if #spawnedDuplications == CountMap(templateMap) then
                    selectAndPushCommand()
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
    end
end

--- @param data SceneData
function Commands.SpawnPreset(data)
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
            end,
            Redo = function()
                NetChannel.Restore:SendToServer({ Guid = spawnedGuids })
            end
        })
    end

    function spawnNode(entData, savedGuid)
        local pos, rot = entData.Position, entData.Rotation or Quat.Identity()
        if data.PresetType == "Relative" then
            --- @diagnostic disable-next-line
            pos, rot = GetLocalRelativeTransform(pivotTransform, pos, rot)
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
            if #spawnedGuids == CountMap(data.Spawned) then
                pushCommand()
            end
        end)

        local templateObj = Ext.Template.GetTemplate(TakeTailTemplate(entData.TemplateId))
        if not templateObj or (templateObj.TemplateType ~= "item" and templateObj.TemplateType ~= "character") then
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

--- @param targets GUIDSTRING[]
function Commands.DeleteCommand(targets)
    targets = NormalizeGuidList(targets)
    if #targets == 0 then return end

    local spawned = targets
    
    for _, guid in ipairs(targets) do
        EntityStore:RemoveEntity(guid)
    end

    NetChannel.Delete:SendToServer({ Guid = targets })

    HistoryManager:PushCommand({
        Undo = function()
            NetChannel.Restore:SendToServer({ Guid = spawned })
        end,
        Redo = function()
            NetChannel.Delete:SendToServer({ Guid = spawned })
        end
    })
end

---@param target GUIDSTRING
---@param markerType 'SpotLight'|'PointLight'
function Commands.AddMarker(target, markerType)
    local spwanPost = {
        TemplateId = MARKER_ITEM[markerType],
        EntInfo = {
            Position = { CGetPosition(target) },
            Rotation = { CGetRotation(target) },
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
