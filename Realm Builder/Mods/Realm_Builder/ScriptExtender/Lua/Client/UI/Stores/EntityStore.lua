local EntityDatas = {}
local BindDatas = {}
local GuidToDisplayName = {}
local DisplayNameToGuid = {}

local entityNameBlacklist = {
    ["Group Analog Stick"] = true,
    ["Camera"] = true,
}

EntityStore = {
    Tree = TreeTable.new()
}

--- @class EntityData
--- @field Guid string
--- @field DisplayName string
--- @field TemplateId string
--- @field Tags string[]
--- @field Group string
--- @field Note string
--- @field IconTintColor vec4
--- @field VisualPreset string
--- @field Visible boolean
--- @field Gravity boolean
--- @field CanInteract boolean
--- @field Persistent boolean
--- @field LevelName string
--- @field Path string[]?
--- @field Position Vec3?
--- @field Rotation Quat?
--- @field Scale Vec3?

--- @class EntityStore
--- @field AddEntity fun(self:EntityStore, guid:string, data:EntityData|ServerEntityData)
--- @field RemoveEntity fun(self:EntityStore, guid:string)
--- @field SetEntity fun(self:EntityStore, guid:string, data:EntityData)
--- @field GetEntity fun(self:EntityStore, guid:string):EntityData
--- @field GetEntities fun(self:EntityStore, guids:string[]):table<string, EntityData>
--- @field GetAllEntities fun(self:EntityStore):table<string, EntityData>
--- @field CountGroupAndTag fun(self:EntityStore): (table<string, number>, table<string, number>)
--- @field Filter fun(self:EntityStore, fn:fun(guid:string, data:EntityData):boolean):table<string, EntityData>
--- @field FilterByTag fun(self:EntityStore, tag:string):table<string, EntityData>
--- @field FilterByTags fun(self:EntityStore, tags:string[]):table<string, EntityData>
--- @field FilterByGroup fun(self:EntityStore, group:string):table<string, EntityData>
--- @field SearchByNote fun(self:EntityStore, keyword:string):table<string, EntityData>
--- @field GetDisplayNameFromGuid fun(self:EntityStore, guid:string):string|nil
--- @field GetGuidFromDisplayName fun(self:EntityStore, displayName:string):string
--- @field RegisterDisplayName fun(self:EntityStore, displayName:string, guid?:string, discardName?:string):string
--- @field RemoveDisplayName fun(self:EntityStore, displayName:string)
--- @field GetAllDisplayNames fun(self:EntityStore):string[]

setmetatable(EntityStore, {
    __index = function(t, k)
        return rawget(t, k) or EntityDatas[k]
    end,
    __newindex = function(t, k, v)
        if type(k) == "string" and type(v) ~= "function" then
            EntityDatas[k] = v
        else
            rawset(t, k, v)
        end
    end
})

function EntityStore:SetupServerListeners()

    local popupNotif = Notification.new("Realm Builder")
    popupNotif.Pivot = {0.5, 0.1}
    popupNotif.FlickToDismiss = true

    NetChannel.Entities.Added:SetHandler(function (data)
        if not data.Entities or #data.Entities == 0 then
            return
        end

        local list = {}
        for _, entity in ipairs(data.Entities) do
            if not EntityDatas[entity.Guid] then
                self:AddEntity(entity.Guid, entity)
                --Debug("New Prop", prop)
                table.insert(list, entity.Guid)
            end
        end
        RBMenu:NewEntityAdded(list)
    end)


    NetChannel.Entities.Deleted:SetHandler(function (data)
        Debug("Entities.Deleted", data)
        if #data == 0 then
            return
        end

        for _, guid in ipairs(data) do
            if guid ~= nil and guid ~= "" then
                EntityStore:RemoveProp(guid)
            end
        end
        RBMenu:EntityDeleted(data)
    end)

    NetChannel.AttributeChanged:SetHandler(function(data)
        for _,guid in pairs(data.Guid) do
            if EntityDatas[guid] then
                for k, v in pairs(data.Attributes) do
                    EntityDatas[guid][k] = v
                end
            end
        end

        RBMenu.entityMenu:UpdateList()
    end)

    NetChannel.BindProps:SetHandler(function(data)
        for _, info in ipairs(data.BindInfos) do
            local guid = info.Guid
            local parent = info.BindParent
            if IsCamera(parent) then parent = CameraSymbol end
            if not parent then BindDatas[guid] = nil goto continue end
            BindDatas[guid] = BindDatas[guid] or {}
            BindDatas[guid].BindParent = parent
            BindDatas[guid].KeepLookingAt = info.KeepLookingAt
            BindDatas[guid].FollowParent = info.FollowParent
            ::continue::
        end

        popupNotif:Show("Bind Update", function (panel)
            for _, info in ipairs(data.BindInfos) do
                local guid = info.Guid
                local parent = info.BindParent
                panel:AddText(string.format("%s => %s", 
                    GetName(guid) or guid, 
                    GetName(parent) or (parent and parent or "Unbound"
                )))
                panel:AddText("Attributes: " .. (info.KeepLookingAt and "KeepLookingAt " or "") .. (info.FollowParent and "FollowParent" or ""))
            end
        end)
    end)
end

---@param guid string
---@param data EntityData|ServerEntityData
function EntityStore:AddEntity(guid, data)
    EntityDatas[guid] = data

    self:RegisterDisplayName(GetDisplayNameForTemplateId(data.TemplateId), guid)

    if not self.Tree:Find(guid) then
        self.Tree:AddLeaf(guid, "end")
    end


    if not EntityDatas[guid].Tags then
        EntityDatas[guid].Tags = {}
    end
end

function EntityStore:RemoveProp(guid)
    self.Tree:Remove(guid)
    self:RemoveDisplayName(EntityDatas[guid] and EntityDatas[guid].DisplayName)
    EntityDatas[guid] = nil
end

function EntityStore:SetProp(guid, data)
    for k, v in pairs(data) do
        if EntityDatas[guid] then
            EntityDatas[guid][k] = v
        end
    end
end

--- @param guid string
--- @return EntityData|nil
function EntityStore:GetEntity(guid)
    return EntityDatas[guid]
end

function EntityStore:GetEntities(guids)
    local results = {}
    for _, guid in pairs(guids) do
        if EntityDatas[guid] then
            results[guid] = EntityDatas[guid]
        end
    end
    return results
end

function EntityStore:GetAll()
    return DeepCopy(EntityDatas)
end

function EntityStore:CountGroupAndTag()
    local groupCnt = {}
    local tagsCnt = {}
    for _, data in pairs(EntityDatas) do
        if data.Group and data.Group ~= "" then
            groupCnt[data.Group] = (groupCnt[data.Group] or 0) + 1
        end
        if data.Tags then
            for _, tag in pairs(data.Tags) do
                tagsCnt[tag] = (tagsCnt[tag] or 0) + 1
            end
        end
    end
    return groupCnt, tagsCnt
end

---@param fn fun(guid:string, data:EntityData):boolean
---@return table<string, EntityData>
function EntityStore:Filter(fn)
    local results = {}
    for guid, data in pairs(EntityDatas) do
        if fn(guid, data) then
            results[guid] = data
        end
    end
    return results
end

function EntityStore:FilterByTag(tag)
    return self:Filter(function(guid, data)
        return data.Tags and TableContains(data.Tags, tag)
    end)
end

function EntityStore:FilterByTags(tags)
    return self:Filter(function(guid, data)
        if not data.Tags then
            return false
        end
        for _, tag in pairs(tags) do
            if not TableContains(data.Tags, tag) then
                return false
            end
        end
        return true
    end)
end

function EntityStore:FilterByGroup(group)
    return self:Filter(function(guid, data)
        return data.Group == group
    end)
end

function EntityStore:SearchByNote(keyword)
    return self:Filter(function(guid, data)
        return data.Note and string.find(string.lower(data.Note), string.lower(keyword), 1, true) ~= nil
    end)
end

function EntityStore:RegisterDisplayName(displayName, guid, discardName)
    if not displayName or displayName == "" then
        return
    end

    self:RemoveDisplayName(discardName)

    if entityNameBlacklist[displayName] then
        displayName = displayName .. " (Prop)"
    end

    local returnName = displayName

    local cnt = 1
    while DisplayNameToGuid[returnName] do
        cnt = cnt + 1
        returnName = string.format("%s (%d)", displayName, cnt)
    end

    if guid then
        GuidToDisplayName[guid] = returnName
        DisplayNameToGuid[returnName] = guid
        EntityDatas[guid].DisplayName = returnName
    else
        Warning("[Realm Builder] RegisterDisplayName called without guid for name: " .. returnName)
        return
    end

    return returnName
end

function EntityStore:RemoveDisplayName(displayName)
    if not displayName or displayName == "" then
        return
    end

    if DisplayNameToGuid[displayName] then
        local guid = DisplayNameToGuid[displayName]
        DisplayNameToGuid[displayName] = nil
        GuidToDisplayName[guid] = nil
    end
end

function EntityStore:GetAllDisplayNames()
    local names = {}
    for guid, displayName in pairs(GuidToDisplayName) do
        if displayName and displayName ~= "" then
            table.insert(names, displayName)
        end
    end
    return names
end

--- @param guid GUIDSTRING
--- @return string|nil
function EntityStore:GetPropNameFromGuid(guid)
    if GuidToDisplayName[guid] then
        return GuidToDisplayName[guid]
    end
    return nil
end

function EntityStore:GetGuidFromPropName(displayName)
    if DisplayNameToGuid[displayName] then
        return DisplayNameToGuid[displayName]
    end
    return nil
end

function EntityStore:GetBindParent(guid)
    return BindDatas[guid] and BindDatas[guid].BindParent or nil
end

--- @param guid GUIDSTRING
--- @return BindInfo|nil
function EntityStore:GetBindInfo(guid)
    return BindDatas[guid] or {}
end

function EntityStore:BuildDisplayNameToTemplateTree()
    local tree = TreeTable.new()
    
    return tree
end

function EntityStore:RestoreTreeListFromTable()


end

EntityStore:SetupServerListeners()