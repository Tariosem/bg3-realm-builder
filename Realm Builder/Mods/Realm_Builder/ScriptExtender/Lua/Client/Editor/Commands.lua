--- @class Commands
--- @field SetTransform fun(proxies: RB_MovableProxy|RB_MovableProxy[], transform: {Translate: Vec3|nil, RotationQuat: Quat|nil, Scale: Vec3|nil}, notRecordHistory: boolean|nil)
--- @field Bind fun(targets: GUIDSTRING|GUIDSTRING[], parent: GUIDSTRING)
--- @field Unbind fun(targets: GUIDSTRING[])
--- @field Snap fun(targets: GUIDSTRING|GUIDSTRING[], onlyRotation: boolean|nil, onlyPosition: boolean|nil)
Commands = Commands or {}

--- @param proxies RB_MovableProxy|RB_MovableProxy[]
--- @param notRecordHistory boolean|nil
function Commands.SetTransform(proxies, transform, notRecordHistory)
    local redoTransforms = {}
    local undoTransforms = {}
    for _,proxy in pairs(proxies) do
        undoTransforms[proxy] = proxy:GetTransform()
    end

    if transform.Translate or transform.RotationQuat or transform.Scale then
        local t = {}
        for _,proxy in pairs(proxies) do
            t[proxy] = transform
        end
        redoTransforms = t
    end

    local function doTransform(isReset)
        for _,proxy in pairs(proxies) do
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
    for _,guid in ipairs(targets) do
        local parent = EntityStore:GetBindParent(guid)
        if parent then
            oriParents[guid] = parent
        end
    end

    NetChannel.Bind:SendToServer({ Type = "Unbind", Guid = targets })

    HistoryManager:PushCommand({
        Undo = function()
            for guid,parent in pairs(oriParents) do
                NetChannel.Bind:SendToServer({ Type = "Bind", Guid = {guid}, Parent = parent })
            end
        end,
        Redo = function()
            NetChannel.Bind:SendToServer({ Type = "Unbind", Guid = targets })
        end
    })
end

function Commands.SnapCommand(targets, onlyRotation, onlyPosition)
    local parents = {}
    for _,guid in ipairs(targets) do
        local parent = EntityStore:GetBindParent(guid)
        if parent then
            parents[guid] = parent
        end
    end
    local targetPos = {}
    for guid,parent in pairs(parents) do
        targetPos[guid] = {Translate = {CGetPosition(parent)}, RotationQuat = {CGetRotation(parent)}}
    end
    if onlyRotation then
        for guid,pos in pairs(targetPos) do
            pos.Translate = nil
        end
    elseif onlyPosition then
        for guid,pos in pairs(targetPos) do
            pos.RotationQuat = nil
        end
    end

    local targetProxies = {}
    for _,guid in ipairs(targets) do
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

    NetChannel.Spawn:SendToServer(packedData)

    -- TODO: implement undo redo
end

--- @param targets GUIDSTRING|GUIDSTRING[]
function Commands.DuplicateCommand(targets)
    targets = NormalizeGuidList(targets)
    if #targets == 0 then return end
    local duplicated = {}
    local duplicatedSet = {}

    NetChannel.Duplicate:RequestToServer({ Guid = targets }, function (response)
        local newGuidsSet = {}
        for _,newGuid in pairs(response.NewGuids or {}) do
            newGuidsSet[newGuid] = true
        end
        Timer:Ticks(30, function (timerID)
            local newProxies = {}
            for newGuid,_ in pairs(newGuidsSet) do
                table.insert(newProxies, MovableProxy.CreateByGuid(newGuid))
            end

            RB_GLOBALS.TransformEditor:Select(newProxies)
            RB_GLOBALS.TransformEditor.Gizmo:StartDragging()     
        end)
        -- TODO: implement undo redo 
    end)
end

function Commands.DeleteCommand(targets)
    targets = NormalizeGuidList(targets)
    if #targets == 0 then return end

    local oriEntities = {}
    for _,guid in pairs(targets) do
        local entity = Ext.Entity.Get(guid) --[[@as EntityHandle]]
        if entity then
            oriEntities[guid] = DeepCopy(EntityStore:GetStoredData(guid))
        end
    end

    NetChannel.Delete:SendToServer({ Guid = targets })

    HistoryManager:PushCommand({
        Undo = function()
            for _,entityData in pairs(oriEntities) do
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
        Position = {CGetPosition(target)},
        Rotation = {CGetRotation(target)},
        EntInfo = {
            DisplayName = "Spot Light Marker",
        }
    }

    NetChannel.Spawn:RequestToServer(spwanPost, function (response)
        local newGuid = response.Guid
        if newGuid then
            PickingHelpers:RegisterGuidRedirect(newGuid, target)

           Commands.Bind(newGuid, target)
        end
    end)
end