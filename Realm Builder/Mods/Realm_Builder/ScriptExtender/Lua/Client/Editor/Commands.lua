--- @class Commands
--- @field SetTransform fun(proxies: RB_MovableProxy|RB_MovableProxy[], transform: {Translate: Vec3|nil, RotationQuat: Quat|nil, Scale: Vec3|nil}, notRecordHistory: boolean|nil)
--- @field Bind fun(targets: GUIDSTRING|GUIDSTRING[], parent: GUIDSTRING)
--- @field Unbind fun(targets: GUIDSTRING[])
--- @field SnapToParent fun(targets: RB_MovableProxy[], onlyRotation: boolean|nil, onlyPosition: boolean|nil)
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
            if not proxy:IsValid() then
                goto continue
            end
            local targetTransform = isReset and undoTransforms[proxy] or redoTransforms[proxy]
            if targetTransform then
                proxy:SetTransform(targetTransform)
            end
            ::continue::
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
            end,
            Description = "Set Transform"
        })
    end
end

--- @param proxies RB_MovableProxy[]
--- @param transforms table< RB_MovableProxy, Transform>
--- @param notRecordHistory boolean|nil
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
        end,
        Description = "Bind Entities"
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
        end,
        Description = "Unbind Entities"
    })
end

--- @param targets RB_MovableProxy[]
function Commands.SnapToGround(targets)
    if #targets == 0 then return end

    local proxyPairs = {}
    for _, proxy in pairs(targets) do
        table.insert(proxyPairs, {proxy, proxy:GetWorldTranslate()})
    end
    table.sort(proxyPairs, function(a, b)
        return a[2][2] < b[2][2]
    end)

    local targetPos = {}
    for _, pair in ipairs(proxyPairs) do
        local proxy = pair[1] --[[@type RB_MovableProxy]]
        local pos = Ext.Level.GetHeightsAt(pair[2][1], pair[2][3])

        local finalPos = {pair[2][1], pos[1], pair[2][3]}
        targetPos[proxy] = finalPos
        proxy:SetWorldTranslate(finalPos)
    end

    HistoryManager:PushCommand({
        Undo = function()
            for _, pair in ipairs(proxyPairs) do
                local proxy = pair[1] --[[@type RB_MovableProxy]]
                proxy:SetWorldTranslate(pair[2])
            end
        end,
        Redo = function()
            for _, pair in ipairs(proxyPairs) do
                local proxy = pair[1] --[[@type RB_MovableProxy]]
                proxy:SetWorldTranslate(targetPos[proxy])
            end
        end,
        Description = "Snap To Ground"
    })
end

--- @param targets RB_MovableProxy[]
--- @param targetTransform Transform
--- @param onlyRotation boolean|nil
--- @param onlyPosition boolean|nil
function Commands.SnapToTarget(targets, targetTransform, onlyRotation, onlyPosition)
    local targetTransforms = {} --[[@type table<RB_MovableProxy, Transform>]]
    for _, proxy in pairs(targets) do
        targetTransforms[proxy] = targetTransform
        targetTransforms[proxy].Scale = nil
    end
    if onlyRotation then
        for _, pos in pairs(targetTransforms) do
            pos.Translate = nil
        end
    elseif onlyPosition then
        for _, pos in pairs(targetTransforms) do
            pos.RotationQuat = nil
        end
    end
    Commands.SetTransformSeparate(targets, targetTransforms)
end

function Commands.SnapToParent(targets, onlyRotation, onlyPosition)
    local parents = {} --[[@type table<RB_MovableProxy, RB_MovableProxy>]]
    for _, proxy in ipairs(targets) do
        local parent = proxy:GetParent()
        if parent then
            parents[proxy] = parent
        end
    end
    local targetTransforms = {} --[[@type table<RB_MovableProxy, Transform>]]
    for proxy, parent in pairs(parents) do
        targetTransforms[proxy] = parent:GetTransform()
        targetTransforms[proxy].Scale = nil
    end
    if onlyRotation then
        for _, pos in pairs(targetTransforms) do
            pos.Translate = nil
        end
    elseif onlyPosition then
        for _, pos in pairs(targetTransforms) do
            pos.RotationQuat = nil
        end
    end
    Commands.SetTransformSeparate(targets, targetTransforms)
end

--- @param targets GUIDSTRING[]
function Commands.DeleteCommand(targets)
    targets = RBUtils.NormalizeGuidList(targets)
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
        end,
        Description = "Delete Entities"
    })
end

---@param target GUIDSTRING
---@param markerType 'SpotLight'|'PointLight'
function Commands.AddMarker(target, markerType)
    local spwanPost = {
        TemplateId = MARKER_ITEM[markerType],
        EntInfo = {
            Position = { RBGetPosition(target) },
            Rotation = { RBGetRotation(target) },
            DisplayName = "Spot Light Marker",
        }
    }

    NetChannel.Spawn:RequestToServer(spwanPost, function(response)
        local newGuid = response.Guid
        if newGuid then
            PickingUtils:RegisterGuidRedirect(newGuid, target)

            Commands.Bind(newGuid, target)
        end
    end)
end
