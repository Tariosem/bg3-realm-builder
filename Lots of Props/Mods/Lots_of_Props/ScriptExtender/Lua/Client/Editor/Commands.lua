---@param guids GUIDSTRING[]
---@param transforms table<GUIDSTRING, {Translate: Vec3|nil, RotationQuat: Vec4|nil, Scale: Vec3|nil}>
local function SetVisualTransform(guids, transforms)
    local entities = {}

    for _,guid in pairs(guids) do
        if type(guid) ~= "string" or guid == "" then
            Warning("TransformEditor: Invalid GUID provided: ", guid)
            goto continue
        end
        local entity = Ext.Entity.Get(guid) --[[@as EntityHandle]]
        if entity.PartyMember then
            local dummy = GetDummyByUuid(guid)
            if dummy and #dummy:GetAllComponentNames() ~= 0 then
                entity = dummy
            end
        end

        if entity then
            entities[guid] = entity
        else
            Warning("TransformEditor: Entity not found: ", guid)
        end
        ::continue::
    end

    for guid,entity in pairs(entities) do
        if not entity or not entity.Visual or not entity.Visual.Visual then return end
        local transform = transforms[guid]
        if not transform then
            --Warning("TransformEditor: No transform provided for guid: "..tostring(guid))
            return
        end
        local visual = entity.Visual.Visual
        if transform.Translate then
            visual:SetWorldTranslate(transform.Translate)
        end
        if transform.RotationQuat then
            visual:SetWorldRotate(transform.RotationQuat)
        end
        if transform.Scale then
            visual:SetWorldScale(transform.Scale)
        end
    end
end

--- @param guids GUIDSTRING[]
--- @param transforms table<GUIDSTRING, {Translate: Vec3|nil, RotationQuat: Vec4|nil, Scale: Vec3|nil}>
local function SetItemTransform(guids, transforms)
    SetVisualTransform(guids, transforms)
    Post(NetChannel.SetTransform, {Guid=guids, Transforms = transforms})
end

local templateTypeHandler = {
    Character = SetVisualTransform,
    Item = SetItemTransform,
    Unmapped = SetItemTransform,
}

--- @class Commands
--- @field SetTransform fun(guids: GUIDSTRING|GUIDSTRING[], transform: {Translate: Vec3|nil, RotationQuat: Vec4|nil, Scale: Vec3|nil}|table<GUIDSTRING, {Translate: Vec3|nil, RotationQuat: Vec4|nil, Scale: Vec3|nil}>, notRecordHistory: boolean|nil)
--- @field Bind fun(targets: GUIDSTRING|GUIDSTRING[], parent: GUIDSTRING)
--- @field Unbind fun(targets: GUIDSTRING[])
--- @field Snap fun(targets: GUIDSTRING|GUIDSTRING[], onlyRotation: boolean|nil, onlyPosition: boolean|nil)
Commands = Commands or {}

--- @param guids GUIDSTRING|GUIDSTRING[]
--- @param transform {Translate: Vec3|nil, RotationQuat: Vec4|nil, Scale: Vec3|nil}|table<GUIDSTRING, {Translate: Vec3|nil, RotationQuat: Vec4|nil, Scale: Vec3|nil}>
--- @param notRecordHistory boolean|nil
function Commands.SetTransformCommand(guids, transform, notRecordHistory)
    guids = NormalizeGuidList(guids)
    local groups = EntityHelpers.FilterUuidsByType(guids)
    local originTransform = {}
    for _,guid in pairs(guids) do
        originTransform[guid] = EntityHelpers.SaveTransform(guid)
    end

    if transform.Translate or transform.RotationQuat or transform.Scale then
        local t = {}
        for _,guid in pairs(guids) do
            t[guid] = transform
        end
        transform = t
    end

    local function doTransform(isReset)
        for t, handler in pairs(templateTypeHandler) do
            handler(groups[t], isReset and originTransform or transform)
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

function Commands.BindCommand(targets, parent)
    Post(NetChannel.Bind, { Type = "Bind", Parent = parent, Guid = targets })

    HistoryManager:PushCommand({
        Undo = function()
            Post(NetChannel.Bind, { Type = "Unbind", Guid = targets, Parent = nil })
        end,
        Redo = function()
            Post(NetChannel.Bind, { Type = "Bind", Parent = parent, Guid = targets })
        end
    })

end

function Commands.UnbindCommand(targets)
    local oriParents = {}
    for _,guid in ipairs(targets) do
        local parent = PropStore:GetBindParent(guid)
        if parent then
            oriParents[guid] = parent
        end
    end

    Post(NetChannel.Bind, { Type = "Unbind", Guid = targets, Parent = nil })
    HistoryManager:PushCommand({
        Undo = function()
            for guid,parent in pairs(oriParents) do
                Post(NetChannel.Bind, { Type = "Bind", Guid = {guid}, Parent = parent })
            end
        end,
        Redo = function()
            Post(NetChannel.Bind, { Type = "Unbind", Guid = targets, Parent = nil })
        end
    })
end

function Commands.SnapCommand(targets, onlyRotation, onlyPosition)
    local parents = {}
    for _,guid in ipairs(targets) do
        local parent = PropStore:GetBindParent(guid)
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

    Commands.SetTransformCommand(targets, targetPos)
end

---@param template string
---@param position Vec3
---@param rotation Quat
---@param propInfo PropData|nil
function Commands.SpawnCommand(template, position, rotation, propInfo)
    propInfo = propInfo and DeepCopy(propInfo) or {}
    local packedData = {
        TemplateId = template,
        Position = position,
        Rotation = rotation,
        PropInfo = propInfo
    }
    --packedData = DeepCopy(packedData)
    --local currentSpawned = {}

    --[[local receive = ClientSubscribe(NetMessage.ServerProps, function (data)
        currentSpawned = {}
        for _,d in pairs(data) do
            table.insert(currentSpawned, d.Guid)
        end
        return UNSUBSCRIBE_SYMBOL
    end)]]

    Post(NetChannel.Spawn, packedData)

    --[[HistoryManager:PushCommand({
        Undo = function()
            if not currentSpawned or #currentSpawned == 0 then return end
            Post(NetChannel.Delete, {Guid = DeepCopy(currentSpawned)})
        end,
        Redo = function()
            local redoSpawned = {}
            ClientSubscribe(NetMessage.ServerProps, function (data)
                redoSpawned = {}
                for _,d in pairs(data) do
                    table.insert(redoSpawned, d.Guid)
                end
                currentSpawned = redoSpawned
                return UNSUBSCRIBE_SYMBOL
            end)
            Post(NetChannel.Spawn, packedData)
        end
    })]]
end

--- @param targets GUIDSTRING|GUIDSTRING[]
function Commands.DuplicateCommand(targets)
    targets = NormalizeGuidList(targets)
    if #targets == 0 then return end
    local duplicated = {}
    local duplicatedSet = {}
    local receive = ClientSubscribe(NetMessage.ServerProps, function (data)
        for _,d in pairs(data) do
            table.insert(duplicated, d.Guid)
            duplicatedSet[d.Guid] = {}
        end
        TransformEditor:Select(duplicatedSet)
        TransformEditor:SetMode(Enums.TransformEditorMode.Translate)
        TransformEditor.Gizmo:StartDragging()
        return UNSUBSCRIBE_SYMBOL
    end)
    Post(NetChannel.Duplicate, { Guid = targets })

    --[[HistoryManager:PushCommand({
        Undo = function()
            if #duplicated == 0 then return end
            Post(NetChannel.Delete, {Guid = duplicated})
        end,
        Redo = function()
            ClientSubscribe(NetMessage.ServerProps, function (data)
                for _,d in pairs(data) do
                    table.insert(duplicated, d.Guid)
                    duplicatedSet[d.Guid] = {}
                end
                TransformEditor:Select(duplicatedSet)
                return UNSUBSCRIBE_SYMBOL
            end)

            Post(NetChannel.Duplicate, { Guid = targets }) -- Maybe let server also return template?
        end
    })]]
end