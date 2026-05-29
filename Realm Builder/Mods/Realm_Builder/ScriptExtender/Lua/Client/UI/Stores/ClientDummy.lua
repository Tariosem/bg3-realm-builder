--- so the reset of the code is most about finding and tracking dummies on the client side
--- every time we find a dummy we store it and in visual helpers we redirect visual get/set to the dummy if it exists

local Debug = function ()
    -- disabled 
end

local dummyUpdateTimer = nil
--- @type table<string, EntityHandle>
local clientVisualDummies = {}
local isInMirror = false
local isInPhotoMode = false


local function postUpdateDummies()
    local dummiesInfo = {}
    local post = {}
    for uuid, dummy in pairs(clientVisualDummies) do
        if #dummy:GetAllComponentNames() == 0 then
            DummyHelpers.ClearDummyData()
            Timer:Cancel(dummyUpdateTimer)
            dummyUpdateTimer = nil
            isInPhotoMode = false
            isInMirror = false
            return
        end
        if not dummy.Visual or not dummy.Visual.Visual then
            Debug("Dummy " .. uuid .. " is missing visual component, skipping update.")
            goto continue
        end
        dummiesInfo[uuid] = {}
        dummiesInfo[uuid].Position = dummy.Visual.Visual.WorldTransform.Translate
        dummiesInfo[uuid].Rotation = dummy.Visual.Visual.WorldTransform.RotationQuat
        ::continue::
    end
    post.DummyInfos = dummiesInfo

    NetChannel.UpdateDummies:SendToServer(post)
end

local function startDummyUpdateTimer()
    if not dummyUpdateTimer then
        dummyUpdateTimer = Timer:EveryFrame(function()
            postUpdateDummies()
        end)
    end
end

-- LoadMenu

local function checkIfRunning()
    return Ext.Utils.GetGameState() == "Running"
end

local function reapplyVisualsForDummy(uuid)
    Ext.OnNextTick(function()
        local visualTab = VisualTab.FetchByGuid(uuid)
        if visualTab then
            visualTab:ReapplyCurrentChanges()
        end
    end)
end

--- @diagnostic disable-next-line
Ext.Entity.OnCreate("HasDummy", function (entity)
    if not entity or not checkIfRunning() then
        return
    end

    local uuid = entity.Uuid and entity.Uuid.EntityUuid
    if not uuid then return end

    Debug("Found dummy and coresponding party member : " .. entity.DisplayName.Name:Get())
    isInPhotoMode = true
    clientVisualDummies[uuid] = entity.HasDummy.Entity

    reapplyVisualsForDummy(uuid)
    startDummyUpdateTimer()
end)

--- @param entity EntityHandle
--- @diagnostic disable-next-line
Ext.Entity.OnCreate("ClientPaperdoll", function (entity)
    if not entity or not checkIfRunning() then
        return
    end

    Ext.OnNextTick(function()
        if not entity.ClientPaperdoll or entity.ClientPaperdoll.Combat then return end -- skip combat paperdolls
        local owner = entity.ClientPaperdoll.Entity
        if not owner or not owner.Uuid then return end
        local ownerGuid = owner.Uuid.EntityUuid
        clientVisualDummies[ownerGuid] = entity
        local displayNameComponent = owner.DisplayName
        Debug("Set paperdoll dummy for owner: " .. (displayNameComponent and displayNameComponent.Name:Get() or ownerGuid))
        reapplyVisualsForDummy(ownerGuid)
    end)
end)

--- @param entity any
--- @diagnostic disable-next-line
Ext.Entity.OnCreate("ClientCCDummyDefinition", function(entity)
    if not entity or not checkIfRunning() then
        return
    end

    Ext.OnNextTick(function()
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

                clientVisualDummies[uuid] = entity.ClientCCDummyDefinition.Dummy
                reapplyVisualsForDummy(uuid)
                break
            end
        end

        Debug("Set CC dummy for : " .. name)
        isInMirror = true
    end)
end)

local tlPreviewDummyCache = {}

local function mapTLDummies()
    local allPosibleOwners = Ext.Entity.GetAllEntitiesWithComponent("Origin")
    --- @type string[]
    local guids = {}

    for _, owner in pairs(allPosibleOwners) do
        if owner.TimelineActorData and owner.Uuid then
            table.insert(guids, owner.Uuid.EntityUuid)
        end
    end

    RBUtils.AsyncForEach(guids, function(guid)
        local owner = Ext.Entity.Get(guid)
        if owner and owner.TimelineActorData and owner.Uuid then
            local actorLink = owner.TimelineActorData.field_0
            local dummy = tlPreviewDummyCache[actorLink]

            if dummy then
                clientVisualDummies[owner.Uuid.EntityUuid] = dummy
                local displayNameComponent = owner.DisplayName
                Debug("Set TLPreview dummy for owner: " .. (displayNameComponent and displayNameComponent.Name:Get() or owner.Uuid.EntityUuid))
                reapplyVisualsForDummy(owner.Uuid.EntityUuid)

                tlPreviewDummyCache[actorLink] = nil
                startDummyUpdateTimer()
            end
        end
    end).OnComplete = function()
        tlPreviewDummyCache = {}
    end
end

local debounceMapping = RBUtils.Debounce(1000, mapTLDummies)

--- @param entity EntityHandle
--- @diagnostic disable-next-line
Ext.Entity.OnCreate("TLPreviewDummy", function(entity)
    Ext.Timer.WaitForRealtime(100, function()
        if not entity or not checkIfRunning() then return end
    
        if not entity.ClientTimelineActorControl then return end
        
        local actorLink = entity.ClientTimelineActorControl.field_0
        tlPreviewDummyCache[actorLink] = entity
        
        debounceMapping()
    end)
end)

function IsInCharacterCreationMirror()
    return isInMirror
end

function IsInPhotoMode()
    return isInPhotoMode
end

---@param ownerUuid string
---@return EntityHandle|nil
local function GetClientVisualDummy(ownerUuid)
    if clientVisualDummies[ownerUuid] and #clientVisualDummies[ownerUuid]:GetAllComponentNames() == 0 then
        clientVisualDummies[ownerUuid] = nil
        isInMirror = false
        isInPhotoMode = false
        return nil
    end


    return clientVisualDummies[ownerUuid]
end

DummyHelpers.GetClientVisualDummy = GetClientVisualDummy