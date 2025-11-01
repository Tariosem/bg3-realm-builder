EntityHelpers = EntityHelpers or {}

function EntityHelpers.EqualTransforms(a, b)
    if not a or not b then return false end
    if not a.Translate or not b.Translate then return false end
    if not a.RotationQuat or not b.RotationQuat then return false end
    if not a.Scale or not b.Scale then return false end

    local eps = EPSILON
    for i = 1, 3 do
        if math.abs(a.Translate[i] - b.Translate[i]) > eps then
            return false
        end
    end

    for i = 1, 4 do
        if math.abs(a.RotationQuat[i] - b.RotationQuat[i]) > eps then
            return false
        end
    end

    for i = 1, 3 do
        if math.abs(a.Scale[i] - b.Scale[i]) > eps then
            return false
        end
    end

    return true
end

function EntityHelpers.SaveTransform(guid)
    local toSave = {
        Translate = Vec3.new({ CGetPosition(guid) }),
        RotationQuat = Quat.new({ CGetRotation(guid) }),
        Scale = Vec3.new(CGetScale(guid))
    }
    if not toSave.Translate or #toSave.Translate ~= 3 then
        toSave.Translate = { CGetPosition(CGetHostCharacter()) }
    end
    if not toSave.RotationQuat or #toSave.RotationQuat ~= 4 then
        toSave.RotationQuat = { 0, 0, 0, 1 }
    end
    return toSave
end

--- @return table<"Character"|"Item"|"Unmapped", GUIDSTRING[]>
function EntityHelpers.FilterUuidsByType(guids)
    local groups = { Character = {}, Item = {}, Unmapped = {} }
    for _, guid in ipairs(guids) do
        local entity = UuidToHandle(guid)
        if entity and entity.IsCharacter then
            table.insert(groups.Character, guid)
        elseif entity and entity.IsItem then
            table.insert(groups.Item, guid)
        elseif entity then
            table.insert(groups.Unmapped, guid)
            --Debug("Unmapped entity type for "..tostring(guid))
        else
        end
    end
    return groups
end

function GetTemplateId(guid)
    if not guid or guid == "" then
        return nil
    end

    local entity = UuidToHandle(guid)
    if not entity then
        return nil
    end

    if not entity.OriginalTemplate or not entity.OriginalTemplate.OriginalTemplate then
        return nil
    end

    return entity.OriginalTemplate.OriginalTemplate
end

--- @param guids GUIDSTRING|GUIDSTRING[]
--- @return GUIDSTRING[] copy
function NormalizeGuidList(guids)
    local returnData = {}
    if type(guids) == "string" then
        return { guids }
    elseif type(guids) == "table" then
        returnData = DeepCopy(guids)
    else
        return {}
    end

    if Ext.IsServer() then
        if BindManager and BindManager.SortByDepth then
            returnData = BindManager:SortByDepth(returnData)
        end
    end

    return returnData
end

function EntityExists(guid)
    if not guid or guid == "" then
        return false
    end
    if IsCamera(guid) then
        return true
    end

    local entity = UuidToHandle(guid)
    if not entity then
        return false
    end
    return true
end

local DummyComponentList = {
    ["ecl::dummy::AnimationStateComponent"] = true,
    ["ecl::dummy::AvailableAnimationsComponent"] = true,
    ["ecl::dummy::DummyComponent"] = true,
    ["ecl::dummy::EquipmentVisualsStateComponent"] = true,
    ["ecl::dummy::FootIKStateComponent"] = true,
    ["ecl::dummy::LoadedComponent"] = true,
    ["ecl::dummy::OriginalTransformComponent"] = true,
    ["ecl::dummy::SplatterComponent"] = true,
    ["ecl::dummy::StatusVFXInitializationComponent"] = true,
    ["ecl::dummy::UnsheathComponent"] = true,
    ["ecl::dummy::VFXEntitiesComponent"] = true,
}

---@param entity EntityHandle
---@return boolean
function IsDummy(entity)
    if not entity then
        return false
    end

    for _, comp in ipairs(entity:GetAllComponentNames()) do
        if DummyComponentList[comp] then
            return true
        end
    end

    return false
end

---@param object any
---@return boolean
function CIsCharacter(object)
    local objectType = type(object)
    if objectType == "userdata" then
        local mt = getmetatable(object)
        local userdataType = Ext.Types.GetObjectType(object)
        if mt == "EntityProxy" and object.IsCharacter ~= nil then
            return true
        elseif userdataType == "esv::CharacterComponent"
            or userdataType == "ecl::CharacterComponent"
            or userdataType == "esv::Character"
            or userdataType == "ecl::Character" then
            return true
        end
    elseif objectType == "string" or objectType == "number" then
        local entity = Ext.Entity.Get(object)
        return entity ~= nil and entity.IsCharacter ~= nil
    end
    return false
end

---@param object any
---@return boolean
function CIsItem(object)
    local objectType = type(object)
    if objectType == "userdata" then
        local mt = getmetatable(object)
        local userdataType = Ext.Types.GetObjectType(object)
        if mt == "EntityProxy" and object.IsItem ~= nil then
            return true
        elseif userdataType == "esv::ItemComponent"
            or userdataType == "ecl::ItemComponent"
            or userdataType == "esv::Item"
            or userdataType == "ecl::Item" then
            return true
        end
    elseif objectType == "string" or objectType == "number" then
        local entity = Ext.Entity.Get(object)
        return entity ~= nil and entity.IsItem ~= nil
    end
    return false
end

function GetLevel(guid)
    local entity = UuidToHandle(guid)
    if not entity then
        return nil
    end

    local level = entity.Level.LevelName
    if not level then
        return nil
    end

    return level
end

function CGetHostCharacter()
    for _, entity in pairs(Ext.Entity.GetAllEntitiesWithComponent("ClientControl")) do
        if entity.UserReservedFor.UserID == 1 then
            return HandleToUuid(entity)
        end
    end
end

function TakeTailTemplate(templateId)
    if not templateId or templateId == "" then
        return templateId
    end
    if #templateId > 36 then
        return TakeTail(templateId, 36)
    end
    return templateId
end

function GetEntityPosition(handle)
    if not handle then
        return nil, nil, nil
    end

    local Transform = handle.Transform.Transform.Translate
    local x, y, z = Transform[1], Transform[2], Transform[3]

    if not x or not y or not z then
        return nil, nil, nil
    end

    return x, y, z
end

function GetEntityRotation(handle)
    if not handle then
        return nil, nil, nil, nil
    end

    local Transform = handle.Transform.Transform.RotationQuat
    local qx, qy, qz, qw = Transform[1], Transform[2], Transform[3], Transform[4]

    if not qx or not qy or not qz or not qw then
        return nil, nil, nil, nil
    end

    return qx, qy, qz, qw
end

function GetEntityScale(handle)
    if not handle then
        return nil, nil, nil
    end

    local Transform = handle.Transform.Transform.Scale
    local sx, sy, sz = Transform[1], Transform[2], Transform[3]

    if not sx or not sy or not sz then
        return nil, nil, nil
    end

    return sx, sy, sz
end

---@param handle EntityHandle
---@param rot any
---@return boolean
function SetEntityRotation(handle, rot)
    local entity = handle
    if not entity or not entity.Transform or not entity.Transform.Transform then
        return false
    end
    local transform = entity.Transform.Transform
    if not transform.RotationQuat or #transform.RotationQuat < 4 then
        return false
    end
    entity.Transform.Transform.RotationQuat = { rot[1], rot[2], rot[3], rot[4] }
    return true
end

--- @param uuid string
--- @return number|nil qx
--- @return number|nil qy
--- @return number|nil qz
--- @return number|nil qw
function GetQuatRotation(uuid)
    if not uuid then
        return nil, nil, nil, nil
    end

    if IsCamera(uuid) then return GetCameraRotation(uuid) end
    if IsPartyMember(uuid) then return GetPartyMemberRotation(uuid) end

    local entity = UuidToHandle(uuid)
    if not entity then
        return nil, nil, nil, nil
    end

    if Ext.IsClient() then
        return VisualHelpers.GetVisualRotation(entity)
    end

    return GetEntityRotation(entity)
end

--- @param guid string
--- @return number|nil x
--- @return number|nil y
--- @return number|nil z
function CGetPosition(guid)
    if not guid then
        return nil, nil, nil
    end

    if IsCamera(guid) then return GetCameraPosition(guid) end
    if IsPartyMember(guid) then return GetPartyMemberPosition(guid) end

    if Ext.IsServer() then
        return Osi.GetPosition(guid) --[[@as number, number, number]]
    end

    local entity = UuidToHandle(guid)
    if not entity then
        --Error("CGetPosition: Entity not found for GUID: " .. tostring(guid))
        return nil, nil, nil
    end

    if Ext.IsClient() then
        return VisualHelpers.GetVisualPosition(entity)
    end

    return GetEntityPosition(entity)
end

function CGetRotation(uuid)
    local qx, qy, qz, qw = GetQuatRotation(uuid)
    if not qx or not qy or not qz or not qw then
        return nil, nil, nil
    end

    return qx, qy, qz, qw
end

function CGetScale(guid)
    if not guid then
        return nil, nil, nil
    end

    local entity = UuidToHandle(guid)
    if not entity then
        return nil, nil, nil
    end

    if Ext.IsClient() then
        return VisualHelpers.GetVisualScale(entity)
    end

    local scale = entity.Transform.Transform.Scale
    if not scale or #scale < 3 then
        return nil, nil, nil
    end

    return scale[1], scale[2], scale[3]
end

function GetHostPosition()
    return CGetPosition(CGetHostCharacter())
end

--- @return GUIDSTRING[]
function GetAllPartyMembers()
    local partyMembers = {}
    local entities = Ext.Entity.GetAllEntitiesWithComponent("PartyMember")
    for _, entity in ipairs(entities) do
        local uuid = HandleToUuid(entity)
        if uuid then
            table.insert(partyMembers, uuid)
        else
            --Warning("Party member without UUID found: " .. tostring(entity))
        end
    end
    return partyMembers
end

function CIsTagged(guid)
    local entity = UuidToHandle(guid)

    if not entity then
        return false
    end

    local tags = entity.Tag.Tags
    for _, tag in ipairs(tags) do
        if tag == RB_PROP_TAG then
            return true
        end
    end

    return false
end

function CClearTag(guid, tag)
    local entity = UuidToHandle(guid)
    if not entity then
        return false
    end

    local tags = entity.Tag.Tags
    for i = #tags, 1, -1 do
        if tags[i] == tag then
            table.remove(tags, i)
        end
    end

    return true
end

function IsItem(guid)
    local entity = UuidToHandle(guid)
    if not entity then
        return false
    end

    return entity.IsItem ~= nil and true or false
end

function IsPartyMember(uuid)
    local entity = UuidToHandle(uuid)
    if not entity then
        return false
    end

    return entity.PartyMember ~= nil and true or false
end

--- @return string[]
function GetAllUuidsWithComponent(componentName)
    local entities = Ext.Entity.GetAllEntitiesWithComponent(componentName)
    if not entities or #entities == 0 then
        --Warning("No entities found with component: " .. componentName)
        return {}
    end
    local uuids = {}
    for _, entity in pairs(entities) do
        local uuid = HandleToUuid(entity)
        if uuid then
            table.insert(uuids, uuid)
        else
            --Warning("Entity without UUID found: " .. tostring(entity))
        end
    end
    return uuids
end

function IsProp(uuid)
    if Ext.IsClient() or true then
        return CIsTagged(uuid)
    end
    return Osi.IsTagged(uuid, RB_PROP_TAG) == 1
end

function IsGizmo(uuid)
    if not uuid or uuid == "" then return false end

    if Ext.IsClient() or true then
        local entity = UuidToHandle(uuid)
        if not entity then return false end

        local tags = entity.Tag and entity.Tag.Tags or {}
        for _, tag in ipairs(tags or {}) do
            if tag == RB_GIZMO_TAG then
                return true
            end
        end

        return false
    end
    return Osi.IsTagged(uuid, RB_GIZMO_TAG) == 1
end

function BF_GetAllTagged()
    local props = {}
    local AllUuids = GetAllUuidsWithComponent("Tag")
    for _, uuid in ipairs(AllUuids) do
        if IsProp(uuid) then
            table.insert(props, uuid)
        end
    end
    return props
end

function BF_GetAllGizmos()
    local gizmos = {}
    local AllUuids = GetAllUuidsWithComponent("Tag")
    for _, uuid in ipairs(AllUuids) do
        if IsGizmo(uuid) then
            table.insert(gizmos, uuid)
        end
    end
    if #gizmos == 0 then
        --Warning("No gizmos found in the game.")
    end
    return gizmos
end

function GetAllPlayers()
    local players = Ext.Entity.GetAllEntitiesWithComponent("Player")
    if not players or #players == 0 then
        Warning("No players found in the game.")
        return {}
    end
    local uuids = {}
    for _, player in ipairs(players) do
        local uuid = HandleToUuid(player)
        if uuid then
            table.insert(uuids, uuid)
        else
            Warning("Player without UUID found: " .. tostring(player))
        end
    end
    return uuids
end

function GetAllItems()
    local items = Ext.Entity.GetAllEntitiesWithComponent("IsItem")
    if not items or #items == 0 then
        Warning("No players found in the game.")
        return {}
    end
    local uuids = {}
    for _, item in ipairs(items) do
        local uuid = HandleToUuid(item)
        if uuid then
            table.insert(uuids, uuid)
        else
        end
    end
    return uuids
end

function GetAllCharacters()
    local characters = Ext.Entity.GetAllEntitiesWithComponent("IsCharacter")
    if not characters or #characters == 0 then
        Warning("No players found in the game.")
        return {}
    end
    local uuids = {}
    for _, character in ipairs(characters) do
        local uuid = HandleToUuid(character)
        if uuid then
            table.insert(uuids, uuid)
        else
        end
    end
    return uuids
end

function GetDistance(uuid1, uuid2)
    local x1, y1, z1 = CGetPosition(uuid1)
    local x2, y2, z2 = CGetPosition(uuid2)
    if not x1 or not y1 or not z1 or not x2 or not y2 or not z2 then
        --Error("GetDistance: Invalid position data for UUIDs: " .. tostring(uuid1) .. " and " .. tostring(uuid2))
        return nil
    end
    return Ext.Math.Distance({ x1, y1, z1 }, { x2, y2, z2 })
end

function IsInInventory(holder, guid)
    local holderEntity = UuidToHandle(holder)
    local itemEntity = UuidToHandle(guid)
    if itemEntity ~= nil and holderEntity ~= nil then
        local parentInventory = itemEntity.InventoryMember and
            itemEntity.InventoryMember.Inventory.InventoryIsOwned.Owner
        while parentInventory do
            if parentInventory == holderEntity then
                return true
            else
                parentInventory = parentInventory.InventoryMember and
                    parentInventory.InventoryMember.Inventory.InventoryIsOwned.Owner
            end
        end
    end
    return false
end

--- @class NearbyEntry
--- @field Guid string
--- @field Distance number
--- @field DisplayName string

--- sorted by distance
---@param pos Vec3
---@param radius number
---@return table<number, {Entity:EntityHandle, Guid:string, Distance:number, DisplayName:string}>
function GetNearbyCharactersAndItems(pos, radius)
    radius = radius or 10
    local nearbyEntities = {}

    for _, entity in pairs(Ext.Entity.GetEntitiesAroundPosition(pos, radius)) do
        if not (entity.IsCharacter or entity.IsItem) then goto continue end
        local guid = HandleToUuid(entity)
        if IsGizmo(guid) then goto continue end
        if not guid then goto continue end
        local distance = Ext.Math.Distance(pos, { CGetPosition(guid) })
        if distance and distance <= radius then
            table.insert(nearbyEntities, {
                Entity = entity,
                Guid = guid,
                Distance = distance,
                DisplayName = entity.DisplayName.Name:Get()
            })
        else
        end
        ::continue::
    end

    table.sort(nearbyEntities, function(a, b) return a.Distance < b.Distance end)
    return nearbyEntities
end

function GetCamera()
    local Entities = Ext.Entity.GetAllEntitiesWithComponent("Camera")
    local returnCamera = nil
    local allActiveCameras = {}
    for _, entity in ipairs(Entities) do
        if entity.Camera.Active and entity.Camera.AcceptsInput then
            returnCamera = entity
        elseif entity.Camera.Active then
            table.insert(allActiveCameras, entity)
        end
    end

    if not returnCamera and #allActiveCameras > 0 then
        returnCamera = allActiveCameras[1]
    end

    return returnCamera
end

function GetCameraController()
    local camera = GetCamera()
    if not camera or not camera.Camera then
        return nil
    end
    return camera.Camera.Controller
end

-- Dirty Workaround

CameraSymbol = "__UserCamera__"

local ServerCameraPosition = {}
local ServerCameraRotation = {}
local ServerDummyPosition = {}
local ServerDummyRotation = {}
local ServerCameraForward = {}
local ClientDummyEntity = {}

function IsServerCameraValid(uuid)
    if Ext.IsServer() then
        return ServerCameraPosition[uuid] ~= nil and ServerCameraRotation[uuid] ~= nil
    end
    return false
end

function GetCameraPosition(UserID)
    if Ext.IsServer() then
        local serverData = ServerCameraPosition[UserID]
        if not serverData or #serverData < 3 then
            --Error("GetCameraPosition: Invalid server data for UserID: " .. tostring(UserID))
            return nil, nil, nil
        end
        return serverData[1], serverData[2], serverData[3]
    end

    local camera = GetCamera()
    if not camera then
        return nil, nil, nil
    end

    return GetEntityPosition(camera)
end

function SetCameraPosition(UserID, pos)
    if Ext.IsServer() then
        ServerCameraPosition[UserID] = pos
        return
    end
end

function GetCameraRotation(UserID)
    if Ext.IsServer() then
        local serverData = ServerCameraRotation[UserID]
        if not serverData or #serverData < 4 then
            --Error("GetCameraRotation: Invalid server data for UserID: " .. tostring(UserID))
            return nil, nil, nil, nil
        end
        return serverData[1] or 0, serverData[2] or 0, serverData[3] or 0, serverData[4] or 1
    end

    local camera = GetCamera()
    if not camera then
        return nil, nil, nil, nil
    end

    return GetEntityRotation(camera)
end

function SetCameraForward(UserID, forward)
    if Ext.IsServer() then
        ServerCameraForward[UserID] = forward
        return
    end
end

--- @param cameraHandle EntityHandle?
--- @return Vec3
function GetCameraForward(cameraHandle, userID)
    if Ext.IsServer() then
        return ServerCameraForward[userID] or Vec3.new({ 0, 0, 1 })
    end

    if not cameraHandle then
        cameraHandle = GetCamera()
    end
    if not cameraHandle or not cameraHandle.Camera then
        Error("GetCameraForward: Invalid camera entity or missing Camera component")
        return Vec3.new({ 0, 0, 1 })
    end

    local controller = cameraHandle.Camera.Controller
    local invView = Matrix.new(controller.Camera.InvViewMatrix)
    local forward4 = invView * Vec4.new(GLOBAL_COORDINATE.Z) --[[@as Vec4]]
    local forward = Vec3.new({ forward4.x, forward4.y, forward4.z }):Normalize()
    return forward --[[@as Vec3]]
end

function SetCameraRotation(UserID, rot)
    if Ext.IsServer() then
        ServerCameraRotation[UserID] = rot
        return
    end
end

function GetPartyMemberPosition(uuid)
    if Ext.IsServer() then
        if ServerDummyPosition[uuid] then
            local pos = ServerDummyPosition[uuid]
            if not pos then return GetEntityPosition(UuidToHandle(uuid)) end
            return pos[1], pos[2], pos[3]
        end
    end

    if Ext.IsClient() then
        if ClientDummyEntity[uuid] then
            local entity = ClientDummyEntity[uuid]
            return VisualHelpers.GetVisualPosition(entity)
        end
        if VisualHelpers.GetEntityVisual(uuid) then
            return VisualHelpers.GetVisualPosition(uuid)
        end
    end

    return GetEntityPosition(UuidToHandle(uuid))
end

function SetDummyPosition(uuid, pos)
    if Ext.IsServer() then
        ServerDummyPosition[uuid] = pos
        return
    end

    if Ext.IsClient() then
        local entity = ClientDummyEntity[uuid]
        if entity then
            if not VisualHelpers.SetVisualPosition(entity, pos) then
                --Error("SetPartyMemberPosition: Failed to set visual position for UUID: " .. tostring(uuid))
                return
            end
            return
        end
    end
end

-- Flip X and Z axis to convert between left-handed and right-handed coordinate systems
local function FlipCharacter(rot)
    return FlipAxis(FlipAxis(rot, "X"), "Z")
end

function GetPartyMemberRotation(uuid)
    if Ext.IsServer() then
        if ServerDummyRotation[uuid] then
            local rot = ServerDummyRotation[uuid]
            return rot[1], rot[2], rot[3], rot[4]
        end
    end

    if Ext.IsClient() then
        if ClientDummyEntity[uuid] then
            local entity = ClientDummyEntity[uuid]
            local p, y, r, w = VisualHelpers.GetVisualRotation(entity)
            return p, y, r, w
        end
    end

    local p, y, r, w = GetEntityRotation(UuidToHandle(uuid))
    return p, y, r, w
end

function SetDummyRotation(uuid, rot)
    if Ext.IsServer() then
        ServerDummyRotation[uuid] = rot
        return
    end

    if Ext.IsClient() then
        local entity = ClientDummyEntity[uuid]
        if entity then
            if not VisualHelpers.SetVisualRotation(entity, rot) then
                --Error("SetPartyMemberRotation: Failed to set visual rotation for UUID: " .. tostring(uuid))
                return
            end
            return
        end
    end
end

function ClearDummyData()
    if Ext.IsServer() then
        ServerDummyPosition = {}
        ServerDummyRotation = {}
    end

    if Ext.IsClient() then
        ClientDummyEntity = {}
        Post("UpdateDummies", { DummyDestroyed = true })
    end
end

if Ext.IsClient() then
    function SetClientDummyEntity(uuid, entity)
        ClientDummyEntity[uuid] = entity
    end

    function GetAllDummies()
        return ClientDummyEntity
    end

    --- @return EntityHandle|nil
    function GetDummyByUuid(uuid)
        return ClientDummyEntity[uuid]
    end
end
