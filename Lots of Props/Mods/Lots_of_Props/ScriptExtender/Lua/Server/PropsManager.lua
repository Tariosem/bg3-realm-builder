--- @class ServerPropData
--- @field TemplateId string
--- @field Guid string
--- @field Gravity boolean
--- @field CanInteract boolean
--- @field Visible boolean
--- @field Movable boolean
--- @field Persistent boolean
--- @field VisualPreset string|nil
--- @field Scale number
--- @field DisplayName string|nil
--- @field Group string|nil
--- @field Note string|nil
--- @field Tags string[]|nil
--- @field Parent string|nil
--- @field IconTintColor number[]|nil

--- @class PropsManager
--- @field name string
--- @field Props table<string, table>
--- @field CreateProp fun(self: PropsManager, TemplateId: string, x: number?, y: number?, z: number?, p: number?, yaw: number?, r: number?, w: number?): string|nil
--- @field AddProp fun(self: PropsManager, guid: string): string|nil
--- @field ReplaceProp fun(self: PropsManager, oldGuid: string): string|nil
--- @field Scan fun(self: PropsManager, refresh: boolean?)
--- @field DeleteProp fun(self: PropsManager, guid: string): boolean
--- @field DeletePropByTemplateId fun(self: PropsManager, TemplateId: string): string[]
--- @field DeleteAll fun(self: PropsManager): string[]
--- @field FreeProp fun(self: PropsManager, guids: string|string[])
--- @field GetAllProps fun(self: PropsManager): string[]
--- @field GetAllPropsForClients fun(self: PropsManager): ServerPropData[]
--- @field GetPropForClients fun(self: PropsManager, guid: string): ServerPropData[]|nil
--- @field GetPropsForClients fun(self: PropsManager, guids: string[]): ServerPropData[]
--- @field BF_DeleteAll fun(self: PropsManager): string[]
PropsManager = {}

function PropsManager:init(name)
    self.name = name or "PropsManager"
    self.Props = {}
    return self
end

-- Create Add

function PropsManager:CreateProp(TemplateId, x, y, z, p, yaw, r, w)
    --Trace("CreateProp called with TemplateId: " .. tostring(TemplateId))
    if not TemplateId then
        Error("Template is nil")
        return nil
    end

    if x == nil or y == nil or z == nil then
        x, y, z = GetHostPosition()
        if not x or not y or not z then
            Error("Failed to get host position for prop creation")
            x, y, z = 0, 0, 0
        end
    end

    local newProp = Osi.CreateAt(TemplateId, x, y, z, 0, 0, "") --[[@as string]]

    if not newProp then
        Error("Failed to create prop with TemplateId: " .. tostring(TemplateId))
        return nil
    end

    Propify(newProp)

    if p and yaw and r and w then
        RotateTo(newProp, p, yaw, r, w)
    end

    --Info("Prop created with TemplateId: " .. tostring(TemplateId) .. " at position (" .. x .. ", " .. y .. ", " .. z .. ")")

    local propData = {
        TemplateId = Osi.GetTemplate(newProp) or TemplateId,
        Guid = newProp,
        Scale = GetScale(newProp) or 1,
        Persistent = false,
        Parent = nil,
    }

    self.Props[newProp] = propData
    --Info("Prop added with guid: " .. tostring(newProp))

    local TemplateName = TrimTail(TemplateId, 37)
    if TemplateName == "" then
        TemplateName = TemplateId
    end

    if SpawnedTemplates and not SpawnedTemplates[TemplateName] then
        Timer:Ticks(6, function ()
            BroadcastToChannel("NewTemplate", {Guid=newProp, TemplateName=TemplateName})
        end)
        SpawnedTemplates[TemplateName] = true
    end

    return newProp
end

function PropsManager:SetProp(guid, propInfo)
    if propInfo.VisualPreset and propInfo.VisualPreset ~= "" then
        self.Props[guid].VisualPreset = propInfo.VisualPreset
    end

    if propInfo.TemplateId and propInfo.TemplateId ~= "" then
        self.Props[guid].TemplateId = propInfo.TemplateId
    end

    if propInfo.DisplayName and propInfo.DisplayName ~= "" then
        self.Props[guid].DisplayName = propInfo.DisplayName
    end

    if type(propInfo.Gravity) == "boolean" then
        if propInfo.Gravity then
            Osi.SetGravity(guid, 0)
        else
            Osi.SetGravity(guid, 1)
        end
        self.Props[guid].Gravity = propInfo.Gravity
    end

    if type(propInfo.Visible) == "boolean" then
        if propInfo.Visible then
            Osi.SetVisible(guid, 1)
        else
            Osi.SetVisible(guid, 0)
        end
        self.Props[guid].Visible = propInfo.Visible
    end

    if type(propInfo.Movable) == "boolean" then
        if propInfo.Movable then
            Osi.SetMovable(guid, 1)
        else
            Osi.SetMovable(guid, 0)
        end
        self.Props[guid].Movable = propInfo.Movable
    end

    if propInfo.Persistent and type(propInfo.Persistent) == "boolean" then
        self.Props[guid].Persistent = propInfo.Persistent
    end

    if type(propInfo.CanInteract) == "boolean" then
        if propInfo.CanInteract then
            Osi.SetCanInteract(guid, 1)
        else
            Osi.SetCanInteract(guid, 0)
        end
        self.Props[guid].CanInteract = propInfo.CanInteract
    end

    if propInfo.Group and type(propInfo.Group) == "string" then
        self.Props[guid].Group = propInfo.Group
    end

    if propInfo.Tags and type(propInfo.Tags) == "table" then
        self.Props[guid].Tags = propInfo.Tags
    end

    if propInfo.Note and type(propInfo.Note) == "string" then
        self.Props[guid].Note = propInfo.Note
    end

    if propInfo.IconTintColor and type(propInfo.IconTintColor) == "table" then
        self.Props[guid].IconTintColor = propInfo.IconTintColor
    end
end

function PropsManager:AddProp(guid)
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
        scale = GetScale(guid) or 1,
        Persistent = false,
        Parent = nil,
    }

    self.Props[guid] = propData
    --Info("Prop added with guid: " .. tostring(guid))

    return guid
end

function PropsManager:ReplaceProp(oldGuid)
    if not oldGuid then return nil end
    local oldProp = self.Props[oldGuid]
    if not oldProp then
        Error("Prop not found: " .. tostring(oldGuid))
        return nil
    end

    if oldProp.offsetTimer then
        --_P("Replacing prop: " .. tostring(oldGuid) .. " with new prop, cancelling offset timer")
        Timer:Cancel(oldProp.offsetTimer)
        oldProp.offsetTimer = nil
    end

    local oldParent = oldProp.Parent
    local childs = {}

    local templateId = oldProp.TemplateId
    if not templateId then
        Error("Missing templateId for " .. tostring(oldGuid))
        return nil
    end

    local x, y, z = Osi.GetPosition(oldGuid) --[[@as number]]
    local p, yaw, r, w = GetQuatRotation(oldGuid)

    Osi.RequestDelete(oldGuid)

    for child, prop in pairs(self.Props) do
        if prop.Parent == oldGuid then
            table.insert(childs, child)
            prop.Parent = nil
        end
    end

    local newGuid = self:CreateProp(templateId, x, y, z, p, yaw, r, w)
    if not newGuid then
        Error("Failed to recreate prop for " .. tostring(oldGuid))
        return nil
    end

    self.Props[newGuid].Persistent = oldProp.Persistent
    self.Props[newGuid].Parent = oldParent

    return newGuid
end


function PropsManager:Scan(refresh)
    local isRefresh = refresh ~= false
    --Trace("Scanning for props: isRefresh: " .. tostring(isRefresh))
    local allGuids = BF_GetAllProps()
    if not allGuids or #allGuids == 0 then
        --Warning("No props found during scan")
        return
    end

    local cnt = 0
    for _, guid in ipairs(allGuids) do
        if isRefresh or not self.Props[guid] then
            self:AddProp(guid)
            --Info("Prop scanned and added: " .. tostring(prop))
            cnt = cnt + 1
        else
        end
    end

    BroadcastAllProps()

    --Info("Scan completed with " .. cnt .. " props found")
end

-- Delete

function PropsManager:DeleteProp(guid)
    --Trace("DeleteProp called with guid: " .. tostring(guid))
    if not guid or not self.Props[guid] then
        Error("Invalid guid or prop not found")
        return false
    end

    if self.Props[guid].Persistent then
        --Warning("Cannot delete persistent prop: " .. tostring(guid))
        return false
    end

    Osi.ClearTag(guid, LOP_PROP_TAG)
    Osi.RequestDelete(guid)
    self.Props[guid] = nil
    --Info("Prop deleted with guid: " .. tostring(guid))

    return true
end

function PropsManager:DeletePropByTemplateId(TemplateId)
    --Trace("DeletePropByTemplateId called with TemplateId: " .. tostring(TemplateId))
    if not TemplateId then
        Error("TemplateId is nil")
        return {}
    end

    local deletedGuids = {}
    for guid, propData in pairs(self.Props) do
        if TakeTailTemplate(propData.TemplateId) == TakeTailTemplate(TemplateId) then
            if not self.Props[guid].Persistent then
                self:DeleteProp(guid)
                table.insert(deletedGuids, guid)
            end
        end
    end

    --Info("All props with TemplateId: " .. tostring(TemplateId) .. " deleted")
    return deletedGuids
end

function PropsManager:DeleteAll()
    local toDelete = {}
    for guid, item in pairs(self.Props) do
        if not item.Persistent then
            table.insert(toDelete, guid)
        end
    end

    local deletedGuids = {}
    for _, guid in ipairs(toDelete) do
        if self:DeleteProp(guid) then
            table.insert(deletedGuids, guid)
        else
            --Warning("Failed to delete prop with guid: " .. tostring(guid))
        end
    end

    return deletedGuids
end

function PropsManager:FreeProp(guids)
    local toFree = NormalizeGuidList(guids)

    for _, guid in ipairs(toFree) do
        if not guid or not self.Props[guid] then
            Warning("Invalid guid or prop not found: " .. tostring(guid))
        else
            Osi.ClearTag(guid, LOP_PROP_TAG)
            self.Props[guid] = nil

            BroadcastDeletedProps({guid})
            Info("Prop freed with guid: " .. tostring(guid))
        end
    end

end

function PropsManager:GetAllProps()
    --Trace("GetAllProps called")
    local propsList = {}
    for guid, propData in pairs(self.Props) do
        table.insert(propsList, guid)
    end
    return propsList
end

function PropsManager:GetAllPropsForClients()
    local propsList = self.Props
    local jsonProps = {}
    for _, prop in pairs(propsList) do
        local item = self:GetPropForClients(prop.Guid)
        if item then
            table.insert(jsonProps, item[1])
        else
            Warning("Prop not found for guid: " .. tostring(prop.Guid))
        end
    end
    --Info("Generated JSON for UI with " .. tostring(#jsonProps) .. " props")
    return jsonProps
end

function PropsManager:GetPropForClients(guid)
    local propData = self.Props[guid]
    if not propData then
        Error("Prop not found for guid: " .. tostring(guid))
        return nil
    end
    local item = {
        TemplateId = propData.TemplateId,
        Guid = propData.Guid,
        Gravity = propData.Gravity or false,
        CanInteract = Osi.GetCanInteract(propData.Guid) == 1 or false,
        Visible = Osi.IsInvisible(propData.Guid) ~= 1 or false,
        Movable = Osi.IsMovable(propData.Guid) == 1 or false,
        Persistent = propData.Persistent or false,
        VisualPreset = propData.VisualPreset or nil,
        Scale = propData.Scale or 1,
        DisplayName = propData.DisplayName or nil,
        Group = propData.Group or nil,
        Note = propData.Note or nil,
        Tags = propData.Tags or nil,
        Parent = propData.Parent or nil,
        IconTintColor = propData.IconTintColor or {1,1,1,1}
    }

    local jsonProps = {item}
    return jsonProps
end

function PropsManager:GetPropsForClients(guids)
    local jsonProps = {}
    for _, guid in ipairs(guids) do
        local item = self:GetPropForClients(guid)[1]
        if item then
            table.insert(jsonProps, item)
        else
            Warning("Prop not found for guid: " .. tostring(guid))
        end
    end

    return jsonProps
end

function PropsManager:BF_DeleteAll()
    --Trace("BF_DeleteAll called")
    self.Props = {}
    self:Scan(false)
    return self:DeleteAll()
    --Info("All props deleted")
end