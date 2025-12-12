local declare = {}

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


--- @param guid any
--- @return Transform
function EntityHelpers.SaveTransform(guid)
    local toSave = {
        Translate = Vec3.new({ RBGetPosition(guid) }),
        RotationQuat = Quat.new({ RBGetRotation(guid) }),
        Scale = Vec3.new({RBGetScale(guid)})
    }
    if not toSave.Translate or #toSave.Translate ~= 3 then
        toSave.Translate = { RBGetPosition(RBGetHostCharacter()) }
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

function EntityHelpers.GetTemplateId(guid)
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
function RBUtils.NormalizeGuidList(guids)
    local returnData = {}
    if type(guids) == "string" then
        return { guids }
    elseif type(guids) == "table" then
        returnData = RBUtils.DeepCopy(guids)
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

function EntityHelpers.EntityExists(guid)
    if not guid or guid == "" then
        return false
    end
    if RBUtils.IsCamera(guid) then
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
function EntityHelpers.IsDummy(entity)
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
function EntityHelpers.IsCharacter(object)
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
function EntityHelpers.IsItem(object)
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

function EntityHelpers.GetLevel(guid)
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

function RBGetHostCharacter()
    if Ext.IsServer() then
        return Osi.GetHostCharacter() --[[@as GUIDSTRING]]
    end

    for _, entity in pairs(Ext.Entity.GetAllEntitiesWithComponent("ClientControl")) do
        if entity.UserReservedFor.UserID == 1 then
            return HandleToUuid(entity)
        end
    end
end

--- strip uuid from format like 'name_uuid', usually from Osi.GetTemplate
--- @param templateId any
--- @return any
function EntityHelpers.TakeTailTemplate(templateId)
    if not templateId or templateId == "" then
        return templateId
    end
    if #templateId > 36 then
        return RBStringUtils.TakeTail(templateId, 36)
    end
    return templateId
end

function EntityHelpers.GetEntityPosition(handle)
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

function EntityHelpers.GetEntityRotation(handle)
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

function EntityHelpers.GetEntityScale(handle)
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
function EntityHelpers.SetEntityRotation(handle, rot)
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
function EntityHelpers.GetQuatRotation(uuid)
    if not uuid then
        return nil, nil, nil, nil
    end

    if RBUtils.IsCamera(uuid) then return CameraHelpers.GetCameraRotation(uuid) end
    if EntityHelpers.IsPartyMember(uuid) then return declare.GetPartyMemberRotation(uuid) end

    local entity = UuidToHandle(uuid)
    if not entity then
        return nil, nil, nil, nil
    end

    if Ext.IsClient() then
        return VisualHelpers.GetVisualRotation(entity)
    end

    return EntityHelpers.GetEntityRotation(entity)
end

--- @param guid string
--- @return number|nil x
--- @return number|nil y
--- @return number|nil z
function RBGetPosition(guid)
    if not guid then
        return nil, nil, nil
    end

    if RBUtils.IsCamera(guid) then return CameraHelpers.GetCameraPosition(guid) end
    if EntityHelpers.IsPartyMember(guid) then return declare.GetPartyMemberPosition(guid) end

    if Ext.IsServer() then
        return Osi.GetPosition(guid) --[[@as number, number, number]]
    end

    local entity = UuidToHandle(guid)
    if not entity then
        --Error("CGetPosition: Entity not found for GUID: " .. tostring(guid))
        return nil, nil, nil
    end

    if Ext.IsClient() and entity.Visual then
        return VisualHelpers.GetVisualPosition(entity)
    end

    return EntityHelpers.GetEntityPosition(entity)
end

function RBGetRotation(uuid)
    local qx, qy, qz, qw = EntityHelpers.GetQuatRotation(uuid)
    if not qx or not qy or not qz or not qw then
        return nil, nil, nil
    end

    return qx, qy, qz, qw
end

function RBGetScale(guid)
    if not guid then
        return nil, nil, nil
    end

    if RBUtils.IsCamera(guid) then return 1, 1, 1 end

    local entity = UuidToHandle(guid)
    if not entity then
        return nil, nil, nil
    end

    if Ext.IsClient() then
        return VisualHelpers.GetVisualScale(guid)
    end

    local scale = entity.Transform.Transform.Scale
    if not scale or #scale < 3 then
        return nil, nil, nil
    end

    return scale[1], scale[2], scale[3]
end

function GetHostPosition()
    return RBGetPosition(RBGetHostCharacter())
end

--- @return GUIDSTRING[]
function EntityHelpers.GetAllPartyMembers()
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

function EntityHelpers.IsTaggedProp(guid)
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

function EntityHelpers.ClearTag(guid, tag)
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

--- @param uuid EntityHandle|GUIDSTRING
--- @return boolean
function EntityHelpers.IsPartyMember(uuid)
    local entity = nil
    if type(uuid) == "string" then
        entity = UuidToHandle(uuid)
    else
        entity = uuid        
    end
    if not entity then
        return false
    end

    return entity.PartyMember ~= nil and true or false
end

--- @return string[]
function EntityHelpers.GetAllUuidsWithComponent(componentName)
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

function EntityHelpers.IsSpawned(uuid)
    if not uuid or uuid == "" then return false end

    if RB_FlagHelpers.HasFlag(uuid, "IsSpawned") then
        return true
    end

    if Ext.IsClient() or true then
        return EntityHelpers.IsTaggedProp(uuid)
    end
    return Osi.IsTagged(uuid, RB_PROP_TAG) == 1
end

function EntityHelpers.IsGizmo(uuid)
    if not uuid or uuid == "" then return false end

    if RB_FlagHelpers.HasFlag(uuid, "IsGizmo") then
        return true
    end

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

function EntityHelpers.GetAllSpawned()
    local props = {}
    local AllUuids = Ext.Vars.GetEntitiesWithVariable(RB_FLAG_FIELD)

    if not AllUuids or #AllUuids == 0 then
        AllUuids = EntityHelpers.GetAllUuidsWithComponent("Tag")
    end

    for _, uuid in ipairs(AllUuids) do
        if EntityHelpers.IsSpawned(uuid) then
            table.insert(props, uuid)
        end
    end
    return props
end

function EntityHelpers.BF_GetAllSpawned()
    local props = {}
    local AllUuids = EntityHelpers.GetAllUuidsWithComponent("Tag")

    for _, uuid in ipairs(AllUuids) do
        if EntityHelpers.IsSpawned(uuid) then
            table.insert(props, uuid)
        end
    end
    return props
end

function EntityHelpers.GetAllGizmos()
    local gizmos = {}
    local AllUuids = Ext.Vars.GetEntitiesWithVariable(RB_FLAG_FIELD)

    for _, uuid in ipairs(AllUuids) do
        if EntityHelpers.IsGizmo(uuid) then
            table.insert(gizmos, uuid)
        end
    end

    return gizmos
end

function EntityHelpers.BF_GetAllGizmos()
    local gizmos = {}
    local AllUuids = EntityHelpers.GetAllUuidsWithComponent("Tag")

    for _, uuid in ipairs(AllUuids) do
        if EntityHelpers.IsGizmo(uuid) then
            table.insert(gizmos, uuid)
        end
    end

    return gizmos
end

function EntityHelpers.GetDistance(uuid1, uuid2)
    local x1, y1, z1 = RBGetPosition(uuid1)
    local x2, y2, z2 = RBGetPosition(uuid2)
    if not x1 or not y1 or not z1 or not x2 or not y2 or not z2 then
        --Error("GetDistance: Invalid position data for UUIDs: " .. tostring(uuid1) .. " and " .. tostring(uuid2))
        return nil
    end
    return Ext.Math.Distance({ x1, y1, z1 }, { x2, y2, z2 })
end

function EntityHelpers.IsInInventory(holder, guid)
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
function EntityHelpers.GetNearbyCharactersAndItems(pos, radius)
    radius = radius or 18
    local nearbyEntities = {}

    for _, entity in pairs(Ext.Entity.GetEntitiesAroundPosition(pos, radius)) do
        local guid = HandleToUuid(entity)
        if EntityHelpers.IsGizmo(guid) then goto continue end
        if not guid then goto continue end
        local targetPos = { RBGetPosition(guid) }
        local distance = 0
        if #targetPos < 3 then
            Warning("Failed to get [" .. guid .. "] Position")     
        else
            distance = Ext.Math.Distance(pos, targetPos)
        end
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

--- @return EntityHandle|nil
function RBGetCamera()
    local Entities = Ext.Entity.GetAllEntitiesWithComponent("Camera")
    local returnCamera = nil
    local allActiveCameras = {}
    for _, entity in ipairs(Entities) do
        if entity.Camera.Active and entity.Camera.AcceptsInput then
            returnCamera = entity
            break
        elseif entity.Camera.Active then
            table.insert(allActiveCameras, entity)
        end
    end

    if not returnCamera and #allActiveCameras > 0 then
        returnCamera = allActiveCameras[1]
    end

    return returnCamera
end

--- @return RfCameraController?
function RBGetCameraController()
    local camera = RBGetCamera()
    if not camera or not camera.Camera then
        return nil
    end
    return camera.Camera.Controller
end

-- Dirty Workaround

CameraHelpers = CameraHelpers or {}
DummyHelpers = DummyHelpers or {}

CAMERA_SYMBOL = "__UserCamera__"

local ServerCameraPosition = {}
local ServerCameraRotation = {}
local ServerDummyPosition = {}
local ServerDummyRotation = {}
local ServerCameraForward = {}
local ClientDummyEntity = {}

function CameraHelpers.IsServerCameraValid(uuid)
    if Ext.IsServer() then
        return ServerCameraPosition[uuid] ~= nil and ServerCameraRotation[uuid] ~= nil
    end
    return false
end

function CameraHelpers.GetCameraPosition(UserID)
    if Ext.IsServer() then
        local serverData = ServerCameraPosition[UserID]
        if not serverData or #serverData < 3 then
            --Error("GetCameraPosition: Invalid server data for UserID: " .. tostring(UserID))
            return nil, nil, nil
        end
        return serverData[1], serverData[2], serverData[3]
    end

    local camera = RBGetCamera()
    if not camera then
        return nil, nil, nil
    end

    return EntityHelpers.GetEntityPosition(camera)
end

function CameraHelpers.SetCameraPosition(UserID, pos)
    if Ext.IsServer() then
        ServerCameraPosition[UserID] = pos
        return
    end
end

function CameraHelpers.GetCameraRotation(UserID)
    if Ext.IsServer() then
        local serverData = ServerCameraRotation[UserID]
        if not serverData or #serverData < 4 then
            --Error("GetCameraRotation: Invalid server data for UserID: " .. tostring(UserID))
            return nil, nil, nil, nil
        end
        return serverData[1] or 0, serverData[2] or 0, serverData[3] or 0, serverData[4] or 1
    end

    local camera = RBGetCamera()
    if not camera then
        return nil, nil, nil, nil
    end

    return EntityHelpers.GetEntityRotation(camera)
end

--- @param cameraHandle EntityHandle?
--- @return Vec3
function GetCameraForward(cameraHandle, userID)
    if Ext.IsServer() then
        return ServerCameraForward[userID] or Vec3.new({ 0, 0, 1 })
    end

    if not cameraHandle then
        cameraHandle = RBGetCamera()
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

function CameraHelpers.SetCameraRotation(UserID, rot)
    if Ext.IsServer() then
        ServerCameraRotation[UserID] = rot
        return
    end
end

function declare.GetPartyMemberPosition(uuid)
    if Ext.IsServer() then
        if ServerDummyPosition[uuid] then
            local pos = ServerDummyPosition[uuid]
            if not pos then return EntityHelpers.GetEntityPosition(UuidToHandle(uuid)) end
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

    return EntityHelpers.GetEntityPosition(UuidToHandle(uuid))
end

function DummyHelpers.SetDummyPosition(uuid, pos)
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

function declare.GetPartyMemberRotation(uuid)
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

    local p, y, r, w = EntityHelpers.GetEntityRotation(UuidToHandle(uuid))
    return p, y, r, w
end

function DummyHelpers.SetDummyRotation(uuid, rot)
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

function DummyHelpers.ClearDummyData()
    if Ext.IsServer() then
        ServerDummyPosition = {}
        ServerDummyRotation = {}
    end

    if Ext.IsClient() then
        ClientDummyEntity = {}
        NetChannel.UpdateDummies:SendToServer({ Deactive = true })
    end
end

if Ext.IsClient() then
    function DummyHelpers.SetClientDummyEntity(uuid, entity)
        ClientDummyEntity[uuid] = entity
    end

    function DummyHelpers.GetAllDummies()
        return ClientDummyEntity
    end

    --- @return EntityHandle|nil
    function DummyHelpers.GetDummyByUuid(uuid)
        return ClientDummyEntity[uuid]
    end
end
