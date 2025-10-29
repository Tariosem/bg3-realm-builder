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
--- @field TaggedEntities table<string, ServerEntityData>
--- @field CreateAt fun(self: EntityManager, TemplateId: string, x:number?, y:number?, z:number?, rx:number?, ry:number?, rz:number?, w:number?): string|nil
--- @field AddEntity fun(self: EntityManager, guid: string): string|nil
--- @field SetEntity fun(self: EntityManager, guid: string, entInfo: ServerEntityData)
--- @field Scan fun(self: EntityManager, refresh: boolean?):any
--- @field DeleteEntity fun(self: EntityManager, guid: string, doBroadcast: boolean?): boolean
--- @field DeleteEntityByTemplateId fun(self: EntityManager, TemplateId: string): string[]
--- @field DeleteAll fun(self: EntityManager): string[]
--- @field FreeEntity fun(self: EntityManager, guids: string|string[])
EntityManager = {
    TaggedEntities = {},
}

-- Create Add

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

    local newProp = Osi.CreateAt(templateId, x, y, z, 0, 0, "") --[[@as string]]

    if not newProp then
        Error("Failed to create prop with TemplateId: " .. tostring(templateId))
        return nil
    end

    OsirisHelpers.Propify(newProp)

    if rx and ry and rz and w then
        RotateTo(newProp, rx, ry, rz, w)
    end

    --Info("Prop created with TemplateId: " .. tostring(TemplateId) .. " at position (" .. x .. ", " .. y .. ", " .. z .. ")")

    local propData = {
        TemplateId = Osi.GetTemplate(newProp) or templateId,
        Guid = newProp,
        Persistent = false,
        Parent = nil,
    }

    self.TaggedEntities[newProp] = propData
    --Info("Prop added with guid: " .. tostring(newProp))

    local TemplateName = TrimTail(templateId, 37)
    if TemplateName == "" then
        TemplateName = templateId
    end

    return newProp
end

function EntityManager:SetEntity(guid, entInfo)
    if entInfo.VisualPreset and entInfo.VisualPreset ~= "" then
        self.TaggedEntities[guid].VisualPreset = entInfo.VisualPreset
    end

    if entInfo.TemplateId and entInfo.TemplateId ~= "" then
        self.TaggedEntities[guid].TemplateId = entInfo.TemplateId
    end

    if type(entInfo.Gravity) == "boolean" then
        if entInfo.Gravity then
            Osi.SetGravity(guid, 0)
        else
            Osi.SetGravity(guid, 1)
        end
        self.TaggedEntities[guid].Gravity = entInfo.Gravity
    end

    if type(entInfo.Visible) == "boolean" then
        if entInfo.Visible then
            Osi.SetVisible(guid, 1)
        else
            Osi.SetVisible(guid, 0)
        end
        if self.TaggedEntities[guid] then
            self.TaggedEntities[guid].Visible = entInfo.Visible
        end
    end

    if type(entInfo.Movable) == "boolean" then
        if entInfo.Movable then
            Osi.SetMovable(guid, 1)
        else
            Osi.SetMovable(guid, 0)
        end
        if self.TaggedEntities[guid] then
            self.TaggedEntities[guid].Movable = entInfo.Movable
        end
    end

    if entInfo.Persistent and type(entInfo.Persistent) == "boolean" then
        self.TaggedEntities[guid].Persistent = entInfo.Persistent
    end

    if type(entInfo.CanInteract) == "boolean" then
        if entInfo.CanInteract then
            Osi.SetCanInteract(guid, 1)
        else
            Osi.SetCanInteract(guid, 0)
        end
        if self.TaggedEntities[guid] then
            self.TaggedEntities[guid].CanInteract = entInfo.CanInteract
        end
    end
end

function EntityManager:AddEntity(guid)
    --Trace("AddProp called with guid: " .. tostring(guid))
    if not guid then
        Error("Invalid guid or object does not exist")
        return nil
    end

    local templateId = Osi.GetTemplate(guid)
    if not templateId then
        Error("Failed to get template for guid: " .. tostring(guid))
        return nil
    end

    local propData = {
        TemplateId = templateId,
        Guid = guid,
        Persistent = false,
    }

    self.TaggedEntities[guid] = propData
    --Info("Prop added with guid: " .. tostring(guid))

    return guid
end

function EntityManager:Scan(refresh)
    local isRefresh = refresh ~= false
    --Trace("Scanning for props: isRefresh: " .. tostring(isRefresh))
    local allGuids = BF_GetAllTagged()
    if not allGuids or #allGuids == 0 then
        --Warning("No props found during scan")
        return
    end
    local newEntities = {}

    local cnt = 0
    for _, guid in ipairs(allGuids) do
        if isRefresh or not self.TaggedEntities[guid] then
            table.insert(newEntities, guid)
            self:AddEntity(guid)
            --Info("Prop scanned and added: " .. tostring(prop))
            cnt = cnt + 1
        else
        end
    end

    --Info("Scan completed with " .. cnt .. " props found")
    return self:GetEntities(newEntities)
end

-- Delete

function EntityManager:DeleteEntity(guid, doBroadcast)
    doBroadcast = doBroadcast ~= false
    --Trace("DeleteProp called with guid: " .. tostring(guid))
    if not guid or not self.TaggedEntities[guid] then
        Error("Invalid guid or prop not found")
        return false
    end

    if self.TaggedEntities[guid].Persistent then
        --Warning("Cannot delete persistent prop: " .. tostring(guid))
        return false
    end

    Osi.ClearTag(guid, RB_PROP_TAG)
    Osi.RequestDelete(guid)
    self.TaggedEntities[guid] = nil
    --Info("Prop deleted with guid: " .. tostring(guid))

    if doBroadcast then
        NetChannel.Entities.Deleted:Broadcast({guid})
    end

    return true
end

function EntityManager:DeleteEntityByTemplateId(TemplateId)
    --Trace("DeletePropByTemplateId called with TemplateId: " .. tostring(TemplateId))
    if not TemplateId then
        Error("TemplateId is nil")
        return {}
    end

    local deletedGuids = {}
    for guid, propData in pairs(self.TaggedEntities) do
        if TakeTailTemplate(propData.TemplateId) == TakeTailTemplate(TemplateId) then
            if not self.TaggedEntities[guid].Persistent then
                self:DeleteEntity(guid, false)
                table.insert(deletedGuids, guid)
            end
        end
    end

    NetChannel.Entities.Deleted:Broadcast(deletedGuids)

    --Info("All props with TemplateId: " .. tostring(TemplateId) .. " deleted")
    return deletedGuids
end

function EntityManager:DeleteAll()
    local toDelete = {}
    for guid, item in pairs(self.TaggedEntities) do
        if not item.Persistent then
            table.insert(toDelete, guid)
        end
    end

    local deletedGuids = {}
    for _, guid in ipairs(toDelete) do
        if self:DeleteEntity(guid, false) then
            table.insert(deletedGuids, guid)
        else
            --Warning("Failed to delete prop with guid: " .. tostring(guid))
        end
    end

    NetChannel.Entities.Deleted:Broadcast(deletedGuids)

    return deletedGuids
end

function EntityManager:FreeEntity(guids)
    local toFree = NormalizeGuidList(guids)

    for _, guid in ipairs(toFree) do
        if not guid or not self.TaggedEntities[guid] then
            Warning("Invalid guid or prop not found: " .. tostring(guid))
        else
            Osi.ClearTag(guid, RB_PROP_TAG)
            self.TaggedEntities[guid] = nil

            NetChannel.Entities.Deleted:Broadcast({guid})
            Info("Prop freed with guid: " .. tostring(guid))
        end
    end

end

function EntityManager:GetAllEntitiesForClients()
    local entityList = self.TaggedEntities
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
    local entityData = self.TaggedEntities[guid]
    if not entityData then
        Error("Prop not found for guid: " .. tostring(guid))
        return nil
    end
    local item = {
        TemplateId = entityData.TemplateId,
        Guid = entityData.Guid,
        Gravity = entityData.Gravity or false,
        CanInteract = Osi.GetCanInteract(entityData.Guid) == 1 or false,
        Visible = Osi.IsInvisible(entityData.Guid) ~= 1 or false,
        Movable = Osi.IsMovable(entityData.Guid) == 1 or false,
        Persistent = entityData.Persistent or false,
    }

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
    self.TaggedEntities = {}
    self:Scan(false)
    return self:DeleteAll()
    --Info("All props deleted")
end