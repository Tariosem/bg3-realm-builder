--- so the reset of the code is most about finding and tracking dummies on the client side
--- every time we find a dummy we store it and in visual helpers we redirect visual get/set to the dummy if it exists

local dummyUpdateTimer = nil 
local clientVisualDummies = {}
local isInMirror = false
local isInPhotoMode = false

local function postUpdateDummies()
    local dummiesInfo = {}
    local post = {}
    for uuid, dummy in pairs(DummyHelpers.GetAllDummies()) do
        if #dummy:GetAllComponentNames() == 0 then
            DummyHelpers.ClearDummyData()
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

--- @diagnostic disable-next-line
Ext.Entity.OnCreate("Visual", function (entity)
    if not entity then
        return
    end

    if EntityHelpers.IsDummy(entity) then
        --_P("Found dummy")
        local partyMembers = EntityHelpers.GetAllPartyMembers()
        for _, member in ipairs(partyMembers) do
            local uuid = member --[[@as string]]
            local memberHandle = UuidToHandle(uuid)
            if RBTableUtils.EqualArrays(memberHandle.Transform.Transform.Translate, entity.Transform.Transform.Translate) then
                Debug("Found dummy and coresponding party member : " .. memberHandle.DisplayName.Name:Get())
                isInPhotoMode = true
                DummyHelpers.SetClientDummyEntity(uuid, entity)

                Timer:Ticks(10, function (timerID)

                    local visualTab = VisualTab.FetchByGuid(uuid)
                    if visualTab then
                        visualTab:ReapplyCurrentChanges()
                    end
                end)

            end
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
                    visualTab:ReapplyCurrentChanges()
                end)
            end
        end
    end)
end)

local ccDummy = nil
local onEnterCharacterCreation = {}

--- @param entity any
--- @diagnostic disable-next-line
Ext.Entity.OnCreate("ClientCCDummyDefinition", function(entity)
    if not entity then return end

    Timer:Ticks(5, function()
        if not entity.CCChangeAppearanceDefinition then return end
        local name = entity.CCChangeAppearanceDefinition.Appearance.Name
        if not name then return end

        local allPartyMembers = EntityHelpers.GetAllPartyMembers()
        for _, uuid in pairs(allPartyMembers) do
            local handle = UuidToHandle(uuid)
            local displayName = handle.DisplayName.Name:Get()
            if displayName == name then
                if RB_GLOBALS.TransformEditor then
                    RB_GLOBALS.TransformEditor:Clear()
                end

                ccDummy = entity
                clientVisualDummies[uuid] = entity.ClientCCDummyDefinition.Dummy
                local visualTab = VisualTab.FetchByGuid(uuid)
                if visualTab then
                    visualTab:ReapplyCurrentChanges()
                end
                break
            end
        end

        Debug("Set CC dummy for : " .. name)
        isInMirror = true
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
            DummyHelpers.SetClientDummyEntity(owner.Uuid.EntityUuid, dummy)
            local displayNameComponent = owner.DisplayName
            Debug("Set TLPreview dummy for owner: " .. (displayNameComponent and displayNameComponent.Name:Get() or owner.Uuid.EntityUuid))
            local visualTab = VisualTab.FetchByGuid(owner.Uuid.EntityUuid)
            if visualTab then
                visualTab:ReapplyCurrentChanges()
            end

            if not dummyUpdateTimer then
                dummyUpdateTimer = Timer:EveryFrame(function()
                    postUpdateDummies()
                end)
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

function IsInCharacterCreationMirror()
    return isInMirror
end

function IsIsPhotoMode()
    return isInPhotoMode
end

---@param ownerUuid string
---@return EntityHandle|nil
function GetClientVisualDummy(ownerUuid)
    local dummy = clientVisualDummies[ownerUuid]

    if dummy and #dummy:GetAllComponentNames() == 0 then
        clientVisualDummies[ownerUuid] = nil
        isInMirror = false
        isInPhotoMode = false
        return nil
    end

    return dummy
end