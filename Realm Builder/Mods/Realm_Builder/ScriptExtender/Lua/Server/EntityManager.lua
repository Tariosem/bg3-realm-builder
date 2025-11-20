--- @class ServerEntityData
--- @field TemplateId string
--- @field Guid string
--- @field Gravity boolean
--- @field CanInteract boolean
--- @field Visible boolean
--- @field Movable boolean
--- @field Persistent boolean
--- @field VisualPreset string|nil

--- @class EntityManager
--- @field SavedEntities table<string, ServerEntityData>
--- @field CachedTransforms table<string, Transform>
--- @field CachedEntityData table<string, ServerEntityData>
--- @field CreateAt fun(self: EntityManager, TemplateId: string, x:number?, y:number?, z:number?, rx:number?, ry:number?, rz:number?, w:number?): string|nil
--- @field AddEntity fun(self: EntityManager, guid: string): string|nil
--- @field SetEntity fun(self: EntityManager, guid: string, entInfo: ServerEntityData)
--- @field LoadFromModVar fun(self: EntityManager):any
--- @field DeleteEntities fun(self: EntityManager, guid: string, doBroadcast: boolean?): boolean
--- @field DeleteEntityByTemplateId fun(self: EntityManager, TemplateId: string): string[]
--- @field DeleteAll fun(self: EntityManager)
--- @field FreeEntity fun(self: EntityManager, guids: string|string[])
EntityManager = {
    SavedEntities = {},
    CachedTransforms = {},
    CachedEntityData = {},
}

--- @class EntitySave
--- @field SavedEntities table<string, boolean>
--- @field DeleteOnNextSession table<string, boolean>

Ext.Vars.RegisterModVariable(ModuleUUID, "EntityManager", {})

local initModVar = Ext.Vars.GetModVariables(ModuleUUID)
if not initModVar then
    initModVar = {}
end
if not initModVar.EntityManager then
    initModVar.EntityManager = {
        SavedEntities = {},
        DeleteOnNextSession = {},
    }
end

--- @return EntitySave
local function getModVar()
    local modVar = Ext.Vars.GetModVariables(ModuleUUID)
    if not modVar.EntityManager then
        modVar.EntityManager = {
            SavedEntities = {},
            DeleteOnNextSession = {}
        }
    end
    return modVar.EntityManager
end

local function setModVar(modVar)
    local allModVars = Ext.Vars.GetModVariables(ModuleUUID)
    allModVars.EntityManager = modVar
    Ext.Vars.DirtyModVariables(ModuleUUID)
end

RegisterConsoleCommand("rb_dump_modvar", function ()
    local modVar = getModVar()
    _D(modVar)
end, "Dump the EntityManager mod variable to console.")

--[[
RegisterOnSessionLoaded(function ()
    local modVar = getModVar()
    for guid, _ in pairs(modVar.DeleteOnNextSession) do
        Osi.RequestDelete(guid)
        Osi.RequestDeleteTemporary(guid)
        modVar.SavedEntities[guid] = nil
        modVar.DeleteOnNextSession[guid] = nil
    end
end)

Ext.Events.ResetCompleted:Subscribe(function ()
    local modVar = getModVar()
    for guid, _ in pairs(modVar.DeleteOnNextSession) do
        Osi.RequestDelete(guid)
        Osi.RequestDeleteTemporary(guid)
        modVar.SavedEntities[guid] = nil
        modVar.DeleteOnNextSession[guid] = nil
    end
end)]]

function EntityManager:StoreGuid(guid)
    local modVar = getModVar()
    modVar.SavedEntities[guid] = true
end

function EntityManager:DeleteEntities(guids)
    guids = NormalizeGuidList(guids)
    local modVar = getModVar()
    
    for _, guid in FilteredPairs(guids, function(_,guid) return self.SavedEntities[guid] ~= nil end) do
        modVar.DeleteOnNextSession[guid] = true
        modVar.SavedEntities[guid] = nil

        self.CachedTransforms = self.CachedTransforms or {}
        self.CachedTransforms[guid] = EntityHelpers.SaveTransform(guid)
        self.CachedEntityData[guid] = self.SavedEntities[guid]

        self.SavedEntities[guid] = nil

        OsirisHelpers.TeleportTo(guid, 0, -10000, 0)

        Osi.SetVisible(guid, 0)
        Osi.SetCanInteract(guid, 0)
    end

    NetChannel.Entities.Deleted:Broadcast(guids)
    setModVar(modVar)

    return true
end

function EntityManager:RestoreEntities(guids)
    guids = NormalizeGuidList(guids)
    local modVar = getModVar()
    for _, guid in FilteredPairs(guids, function(_,guid) return modVar.DeleteOnNextSession[guid] == true end) do
        modVar.DeleteOnNextSession[guid] = nil
        modVar.SavedEntities[guid] = true

        local transform = self.CachedTransforms and self.CachedTransforms[guid]
        if transform then
            OsirisHelpers.ToTransform(guid, transform)
        else
            --- @diagnostic disable-next-line
            OsirisHelpers.TeleportTo(guid, GetHostPosition())
        end
        if self.CachedEntityData and self.CachedEntityData[guid] then
            self.SavedEntities[guid] = self.CachedEntityData[guid]
        end

        Osi.SetVisible(guid, 1)
        Osi.SetCanInteract(guid, 1)
    end

    setModVar(modVar)
    NetChannel.Entities.Added:Broadcast({Entities = self:GetEntities(guids)})
    

    return true
end

local readOnlyTemplateProperty = {
    Id = true,
    TemplateName = true,
    ParentTemplateId = true,
    TemplateHandle = true,
    TemplateType = true,
    Name = true,
    Tags = true,
    TemplateId = true,
    DisplayName = true,
    Icon = true,
    ConstructionBend = true,
    TileSet = true,
    Tiles = true,
    field_100 = true,
    field_108 = true,
}

local function copyTemplateProperties(fromTemplate, toTemplate)
    for k,v in pairs(fromTemplate) do
        if not readOnlyTemplateProperty[k] then 
            toTemplate[k] = v
        end
    end
end

local debugText = 
[[

    ===========================
    Create [%s] At (%.2f, %.2f, %.2f)
    TemplateId : %s
    Spawned As : %s
    ===========================
]]

function EntityManager:CreateAt(templateId, x, y, z, rx, ry, rz, w)
    --Trace("CreateProp called with TemplateId: " .. tostring(TemplateId))
    if not templateId then
        Error("Template is nil")
        return nil
    end

    if x == nil or y == nil or z == nil then
        x, y, z = GetHostPosition()
        if not x or not y or not z then
            x, y, z = 0, 0, 0
        end
    end

    local templateObj = Ext.Template.GetTemplate(TakeTailTemplate(templateId))
    local tempoFlag = templateObj.TemplateType == "character" and 1 or 0
    local spawnTemplate = templateId
    if templateObj.TemplateType == "scenery" or templateObj.TemplateType == "TileConstruction" then
        local sceneryTemplate = templateObj --[[@as SceneryTemplate|ConstructionTemplate]]  
        local helperATemplate = Ext.Template.GetTemplate(INVISIBLE_HELPER_SCENERY) --[[@as ItemTemplate]]

        copyTemplateProperties(sceneryTemplate, helperATemplate)
        spawnTemplate = helperATemplate.Name .. "-" .. helperATemplate.Id
    elseif templateObj.TemplateType ~= "item" and templateObj.TemplateType ~= "character" then
        Debug(" Sorry , but we can't spawn root template of type: " .. tostring(templateObj.TemplateType))
        return nil
    end

    local newProp = Osi.CreateAt(spawnTemplate, x, y, z, tempoFlag, 0, "") --[[@as string]]

    if not newProp then
        Error("Failed to create prop with TemplateId: " .. tostring(templateId))
        return nil
    end

    Debug(debugText:format(tostring(templateObj.TemplateType), x, y, z, tostring(templateId), tostring(newProp)))

    OsirisHelpers.Propify(newProp)

    if rx and ry and rz and w then
        OsirisHelpers.RotateTo(newProp, rx, ry, rz, w)
    end

    local propData = {
        TemplateId = templateId,
        Guid = newProp,
    }

    self.SavedEntities[newProp] = propData
    self:StoreGuid(newProp)


    local TemplateName = TrimTail(templateId, 37)
    if TemplateName == "" then
        TemplateName = templateId
    end

    return newProp
end

function EntityManager:SetEntity(guid, entInfo)
    if entInfo.VisualPreset and entInfo.VisualPreset ~= "" then
        self.SavedEntities[guid].VisualPreset = entInfo.VisualPreset
    end


    if type(entInfo.Gravity) == "boolean" then
        if entInfo.Gravity then
            Osi.SetGravity(guid, 0)
        else
            Osi.SetGravity(guid, 1)
        end
        self.SavedEntities[guid].Gravity = entInfo.Gravity
    end

    if type(entInfo.Visible) == "boolean" then
        if entInfo.Visible then
            Osi.SetVisible(guid, 1)
        else
            Osi.SetVisible(guid, 0)
        end
        if self.SavedEntities[guid] then
            self.SavedEntities[guid].Visible = entInfo.Visible
        end
    end

    if type(entInfo.Movable) == "boolean" then
        if entInfo.Movable then
            Osi.SetMovable(guid, 1)
        else
            Osi.SetMovable(guid, 0)
        end
        if self.SavedEntities[guid] then
            self.SavedEntities[guid].Movable = entInfo.Movable
        end
    end

    if type(entInfo.CanInteract) == "boolean" then
        if entInfo.CanInteract then
            Osi.SetCanInteract(guid, 1)
        else
            Osi.SetCanInteract(guid, 0)
        end
        if self.SavedEntities[guid] then
            self.SavedEntities[guid].CanInteract = entInfo.CanInteract
        end
    end
end

function EntityManager:AddEntity(guid)
    --Trace("AddProp called with guid: " .. tostring(guid))
    if not guid then
        Error("Invalid guid or object does not exist")
        return nil
    end

    if self.SavedEntities[guid] then
        return guid
    end

    local templateId = Osi.GetTemplate(guid)
    if not templateId then
        Error("Failed to get template for guid: " .. tostring(guid))
        self.SavedEntities[guid] = nil
        return nil
    end

    local propData = {
        TemplateId = templateId,
        Guid = guid,
        Persistent = false,
    }

    self.SavedEntities[guid] = propData
    self:StoreGuid(guid)
    --Info("Prop added with guid: " .. tostring(guid))

    return guid
end

function EntityManager:LoadFromModVar()
    local modVar = getModVar()

    Debug("Loading from mod var")
    _D(modVar)

    local existingEntities = {}
    for guid,_ in pairs(modVar.DeleteOnNextSession) do
        Osi.RequestDelete(guid)
        Osi.RequestDeleteTemporary(guid)
        modVar.SavedEntities[guid] = nil
        modVar.DeleteOnNextSession[guid] = nil
    end

    for guid, _ in pairs(modVar.SavedEntities) do
        if TakeTailTemplate(Osi.GetTemplate(guid)) == INVISIBLE_HELPER_SCENERY then
            Osi.RequestDelete(guid)
            Osi.RequestDeleteTemporary(guid)
            goto continue
        end
        if not self:AddEntity(guid) then
            modVar.SavedEntities[guid] = nil
        else
            table.insert(existingEntities, guid)
        end
        ::continue::
    end
    NetChannel.Entities.Added:Broadcast({Entities = self:GetEntities(existingEntities)})

    setModVar(modVar)
end

function EntityManager:ScanForEntities()
    local modVar = getModVar()
    local allEntities = Ext.Entity.GetAllEntitiesWithComponent("Tag")
    for _, entity in pairs(allEntities) do
        local uuid = entity.Uuid.EntityUuid
        if CIsTagged(uuid) and not modVar.DeleteOnNextSession[uuid] and not self.SavedEntities[uuid] then
            self:AddEntity(uuid)
            NetChannel.Entities.Added:Broadcast({Entities = self:GetEntities({uuid})})
        end
    end
end

function EntityManager:DeleteAll()
    for guid, _ in pairs(self.SavedEntities) do
        self:DeleteEntities(guid)
    end
end

function EntityManager:FreeEntity(guids)
    local toFree = NormalizeGuidList(guids)

    for _, guid in ipairs(toFree) do
        if not guid or not self.SavedEntities[guid] then
            Warning("Invalid guid or prop not found: " .. tostring(guid))
        else
            self.SavedEntities[guid] = nil

            NetChannel.Entities.Deleted:Broadcast({guid})
            Info("Prop freed with guid: " .. tostring(guid))
        end
    end

end

function EntityManager:GetAllEntitiesForClients()
    local entityList = self.SavedEntities
    local items = {}
    for _, prop in pairs(entityList) do
        local item = self:GetEntityForClients(prop.Guid)
        if item then
            table.insert(items, item[1])
        else
            Warning("Prop not found for guid: " .. tostring(prop.Guid))
        end
    end
    --Info("Generated JSON for UI with " .. tostring(#jsonProps) .. " props")
    return items
end

function EntityManager:GetEntityForClients(guid)
    local entityData = self.SavedEntities[guid]
    if not entityData then
        Error("Prop not found for guid: " .. tostring(guid))
        return nil
    end
    local entity = Ext.Entity.Get(guid) --[[@as EntityHandle]]
    if not entity then
        Warning("Entity handle not found for guid: " .. tostring(guid))
        return nil
    end
    local serverItem = entity.ServerItem

    local item = {
        TemplateId = entityData.TemplateId or Osi.GetTemplate(entityData.Guid),
        Guid = entityData.Guid or guid,
        CanInteract = Osi.GetCanInteract(entityData.Guid) == 1 or false,
        Visible = Osi.IsInvisible(entityData.Guid) ~= 1 or false,
        Movable = Osi.IsMovable(entityData.Guid) == 1 or false,
    }

    if serverItem then
        item.Gravity = serverItem.FreezeGravity == false
    end

    local items = {item}
    return items
end

--- @param guids GUIDSTRING|GUIDSTRING[]
--- @return ServerEntityData[]
function EntityManager:GetEntities(guids)
    local list = NormalizeGuidList(guids)
    local items = {}
    for _, guid in ipairs(list) do
        local entity = self:GetEntityForClients(guid)
        if entity then
            table.insert(items, entity[1])
        else
            Warning("Prop not found for guid: " .. tostring(guid))
        end
    end
    return items
end

function EntityManager:BF_DeleteAll()
    --Trace("BF_DeleteAll called")
    local modVar = getModVar()
    local allEntities = Ext.Entity.GetAllEntitiesWithComponent("Tag")
    local broadcastData = {}
    for _, entity in pairs(allEntities) do
        local uuid = entity.Uuid.EntityUuid
        if CIsTagged(uuid) then
            Osi.ClearTag(uuid, RB_PROP_TAG)
            Osi.RequestDelete(uuid)
            Osi.RequestDeleteTemporary(uuid)
            self.SavedEntities[uuid] = nil
            modVar.SavedEntities[uuid] = nil
            modVar.DeleteOnNextSession[uuid] = nil
            table.insert(broadcastData, uuid)
        end
    end

    NetChannel.Entities.Deleted:Broadcast(broadcastData)
end