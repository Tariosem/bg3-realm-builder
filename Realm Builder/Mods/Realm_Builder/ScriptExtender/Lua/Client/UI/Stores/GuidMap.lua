--- so the reset of the code is most about finding and tracking dummies on the client side
--- every time we find a dummy we store it and in visual helpers we redirect visual get/set to the dummy if it exists

local dummyUpdateTimer = nil 
local clientVisualDummies = {}

--- @diagnostic disable-next-line
Ext.Entity.OnCreate("Visual", function (entity)
    if not entity then
        return
    end

    if IsDummy(entity) then
        --_P("Found dummy")
        local partyMembers = GetAllPartyMembers()
        for _, member in ipairs(partyMembers) do
            local uuid = member --[[@as string]]
            local memberHandle = UuidToHandle(uuid)
            if EqualArrays(memberHandle.Transform.Transform.Translate, entity.Transform.Transform.Translate) then
                Debug("Found dummy and coresponding party member : " .. memberHandle.DisplayName.Name:Get())
                SetClientDummyEntity(uuid, entity)

                Timer:Ticks(10, function (timerID)

                    local visualTab = VisualTab.FetchByGuid(uuid)
                    if visualTab then
                        visualTab:Refresh()
                        visualTab:ReapplyCurrentChanges()
                    end
                end)
            end
        end

        local function postUpdateDummies()
            local dummiesInfo = {}
            local post = {}
            for uuid, dummy in pairs(GetAllDummies()) do
                if #dummy:GetAllComponentNames() == 0 then
                    ClearDummyData()
                    Timer:Cancel(dummyUpdateTimer)
                    dummyUpdateTimer = nil
                    post.Deactive = true
                    break
                end
                local x, y, z = VisualHelpers.GetVisualPosition(dummy)
                local pitch, yaw, roll, w = VisualHelpers.GetVisualRotation(dummy)
                dummiesInfo[uuid] = {}
                dummiesInfo[uuid].Position = {x, y, z}
                dummiesInfo[uuid].Rotation = {pitch, yaw, roll, w}
            end
            post.DummyInfos = dummiesInfo

            NetChannel.UpdateDummies:SendToServer(post)
        end

        if not dummyUpdateTimer then
            dummyUpdateTimer = Timer:EveryFrame(function()
                postUpdateDummies()
            end)
        end
    end
end)


--- @param entity EntityHandle
--- @diagnostic disable-next-line
Ext.Entity.OnCreate("ClientPaperdoll", function (entity)
    if not entity then return end

    Timer:Ticks(60, function (timerID)
        local owner = Paperdoll.GetDollOwner(entity)
        if owner then
            local ownerGuid = owner.Uuid.EntityUuid
            clientVisualDummies[ownerGuid] = entity
            local displayNameComponent = owner.DisplayName
            Debug("Set paperdoll dummy for owner: " .. (displayNameComponent and displayNameComponent.Name:Get() or ownerGuid))
            local visualTab = VisualTab.FetchByGuid(ownerGuid)
            if visualTab then
                Timer:Ticks(5, function()
                    visualTab:Refresh()
                    visualTab:ReapplyCurrentChanges()
                end)
            end
        end
    end)
end)

local ccDummies = {}

--- @param entity any
--- @diagnostic disable-next-line
Ext.Entity.OnCreate("ClientCCDummyDefinition", function(entity)
    if not entity then return end

    Timer:Ticks(5, function()
        if not entity.CCChangeAppearanceDefinition then return end
        local name = entity.CCChangeAppearanceDefinition.Appearance.Name
        if not name then return end

        local allPartyMembers = GetAllPartyMembers()
        for _, uuid in pairs(allPartyMembers) do
            local handle = UuidToHandle(uuid)
            local displayName = handle.DisplayName.Name:Get()
            if displayName == name then
                if TransformEditor then
                    TransformEditor:Clear()
                end

                clientVisualDummies[uuid] = entity.ClientCCDummyDefinition.Dummy
                local visualTab = VisualTab.FetchByGuid(uuid)
                if visualTab then
                    visualTab:Refresh()
                end
                break
            end
        end

        Debug("Set CC dummy for appearance: " .. name)
    end)
end)

local tlPreviewDummyCache = {}
local mapTimer = nil

local function mapTLDummies()
    local allPosibleOwners = Ext.Entity.GetAllEntitiesWithComponent("Origin")

    for i = #allPosibleOwners, 1, -1 do
        local owner = allPosibleOwners[i]
        if not owner.TimelineActorData then
            table.remove(allPosibleOwners, i)
        end
    end

    for _, owner in pairs(allPosibleOwners) do
        local actorLink = owner.TimelineActorData.field_0
        local dummy = tlPreviewDummyCache[actorLink]

        if dummy then
            clientVisualDummies[owner.Uuid.EntityUuid] = dummy
            local displayNameComponent = owner.DisplayName
            Debug("Set TLPreview dummy for owner: " .. (displayNameComponent and displayNameComponent.Name:Get() or owner.Uuid.EntityUuid))
            local visualTab = VisualTab.FetchByGuid(owner.Uuid.EntityUuid)
            if visualTab then
                visualTab:ReapplyCurrentChanges()
            end
        end
    end

end

function GetTLPreviewDummy(entity)
    local dummies = Ext.Entity.GetAllEntitiesWithComponent("ClientTimelineActorControl")
    for _, dummy in pairs(dummies) do
        if dummy.TLPreviewDummy ~= nil and dummy.ClientTimelineActorControl ~= nil then
            local actorLink = dummy.ClientTimelineActorControl.field_0
            if entity.TimelineActorData ~= nil and entity.TimelineActorData.field_0 == actorLink then
                return dummy
            end
        end
    end 
end

local function debounceMapping()
    if mapTimer then
        Timer:Cancel(mapTimer)
    end
    
    mapTimer = Timer:Ticks(60, function()
        mapTimer = nil
        mapTLDummies()
    end)
end

--- @param entity EntityHandle
--- @diagnostic disable-next-line
Ext.Entity.OnCreate("TLPreviewDummy", function(entity)
    if not entity then return end
    
    Timer:Ticks(5, function()
        if not entity.ClientTimelineActorControl then return end
        
        local actorLink = entity.ClientTimelineActorControl.field_0
        tlPreviewDummyCache[actorLink] = entity
        
        debounceMapping()
    end)
end)

---@param ownerUuid string
---@return EntityHandle|nil
function GetClientVisualDummy(ownerUuid)
    local dummy = clientVisualDummies[ownerUuid]

    if dummy and #dummy:GetAllComponentNames() == 0 then
        clientVisualDummies[ownerUuid] = nil
        return nil
    end

    return dummy
end

--#region VisualPreset

ClientVisualPresetData = {}
ClientOriginalVisualData = {}
ClientPresetData = {}

local function LoadVisualPresetData()
    local refFile = GetVisualReferencePath()
    local refData = Ext.Json.Parse(Ext.IO.LoadFile(refFile) or "{}")
    for templateName, data in pairs(refData) do
        local visualPresetFile = GetVisualPresetsPath(templateName)
        local visualPresetData = Ext.Json.Parse(Ext.IO.LoadFile(visualPresetFile) or "{}")
        if visualPresetData then
            ClientVisualPresetData[templateName] = visualPresetData
        else
            Warning("VisualPresetDataLoadFromFile: Failed to load preset data for template: " .. templateName)
        end
    end
end

local function UpdateVisualPresetDataFromServer(data)
    for templateName, presets in pairs(data) do
        if not ClientVisualPresetData[templateName] then
            ClientVisualPresetData[templateName] = {}
        end
        for presetName, presetData in pairs(presets) do
            if not ClientVisualPresetData[templateName][presetName] then
                ClientVisualPresetData[templateName][presetName] = presetData
            end
        end
    end
end

local function UpdatePresetDataFromServer(data)
    if not data or not data.Presets then
        Warning("UpdatePresetDataFromServer: Invalid data received")
        return
    end

    for name, presetData in ipairs(data) do
        if not ClientPresetData[name] then
            ClientPresetData[name] = presetData 
        end
    end
end

local function ClearOriginalVisualData(templateName)
    if templateName then
        ClientOriginalVisualData[templateName] = nil
    else
        ClientOriginalVisualData = {}
    end
    --Info("Cleared original visual data for template: " .. tostring(templateName or "all"))
end

function GetVisualPresetData(templateName, presetName)
    if not templateName or not presetName then
        Warning("GetVisualPresetData: Invalid templateName or presetName")
        return nil
    end

    local templateData = ClientVisualPresetData[templateName]
    if not templateData then
        Warning("GetVisualPresetData: No data found for template: " .. templateName)
        return nil
    end

    return templateData[presetName]
end

ClientSubscribe("ServerVisualPreset", function(data)
    UpdateVisualPresetDataFromServer(data)
end)

ClientSubscribe("ServerPreset", function(data)
    UpdatePresetDataFromServer(data)
end)

RegisterOnSessionLoaded(function()
    --local now = Ext.Utils.MonotonicTime()
    LoadVisualPresetData()
    ClearOriginalVisualData()
    --Debug("Visual preset data loaded in " .. (Ext.Utils.MonotonicTime() - now) .. "ms")
end)

--#endregion VisualPreset