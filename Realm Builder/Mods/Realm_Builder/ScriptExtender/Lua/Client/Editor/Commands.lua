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
    NetChannel.SetTransform:SendToServer({Guid=guids, Transforms = transforms})
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
function Commands.SetTransform(guids, transform, notRecordHistory)
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

    Commands.SetTransform(targets, targetPos)
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
            TransformEditor:Select(newGuidsSet)
            TransformEditor.Gizmo:StartDragging()     
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