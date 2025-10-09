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
    local spawned = {}
    local receive = ClientSubscribe(NetMessage.ServerProps, function (data)
        table.insert(spawned, data[1].Guid)
        return UNSUBSCRIBE_SYMBOL
    end)
    Post(NetChannel.Spawn, { TemplateId = template, Position = position, Rotation = rotation, PropInfo = propInfo })

    HistoryManager:PushCommand({
        Undo = function()
            if #spawned == 0 then return end
            Post(NetChannel.Delete, spawned)
        end,
        Redo = function()
            ClientSubscribe(NetMessage.ServerProps, function (data)
                table.insert(spawned, data[1].Guid)
                return UNSUBSCRIBE_SYMBOL
            end)

            Post(NetChannel.Spawn, { TemplateId = template, Position = position, Rotation = rotation })
        end
    })
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
        return UNSUBSCRIBE_SYMBOL
    end)
    Post(NetChannel.Duplicate, targets)

    HistoryManager:PushCommand({
        Undo = function()
            if #duplicated == 0 then return end
            Post(NetChannel.Delete, duplicated)
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

            Post(NetChannel.Duplicate, targets)
        end
    })
end