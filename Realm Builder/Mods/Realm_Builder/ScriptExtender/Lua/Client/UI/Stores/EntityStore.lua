--- @type table<string, EntityData>
local EntityDatas = {}
local BindDatas = {}
local GuidToDisplayName = {}
local DisplayNameToGuid = {}
local sceneryMap = {}
local cachedToRestore = {}

local entityNameBlacklist = {
    ["Camera"] = true,
}

--- @class EntityData
--- @field Guid string
--- @field DisplayName string
--- @field TemplateId string
--- @field TemplateType 'item'|'character'|'scenery'
--- @field Tags string[]
--- @field Group string
--- @field Note string
--- @field IconTintColor vec4
--- @field VisualPreset string
--- @field Visible boolean
--- @field Gravity boolean
--- @field DisableGravityUntilMoved boolean
--- @field CanInteract boolean
--- @field Movable boolean
--- @field CanBeLooted boolean
--- @field LevelName string
--- @field Path string[]?
--- @field Position Vec3?
--- @field Rotation Quat?
--- @field Scale Vec3?
--- @field Icon string?
--- mostly for export use
--- @field OverrideVisualUuid string?
--- @field OriginalVisualUuid string?
--- @field UseCustomVisualParameters boolean?
--- @field OverrideVisualParameters RB_ParameterSet?
--- @field WanderConfig WanderConfig? -- character only
--- @field VisualObjectMaterialOverride RB_ObjectEdit? -- item only

--- @class EntityStore
--- @field AddEntity fun(self:EntityStore, guid:string, data:EntityData|EntityData)
--- @field RemoveEntity fun(self:EntityStore, guid:string)
--- @field SetEntity fun(self:EntityStore, guid:string, data:EntityData)
--- @field GetEntity fun(self:EntityStore, guid:string):EntityHandle?
--- @field GetStoredData fun(self:EntityStore, guid:string):EntityData|nil
--- @field GetStoredDatas fun(self:EntityStore, guids:string[]):table<string, EntityData>
--- @field GetExportCopy fun(self:EntityStore, guids:GUIDSTRING[]):table<GUIDSTRING, EntityData>
--- @field GetAllStored fun(self:EntityStore):table<string, EntityData>
--- @field CountGroupAndTag fun(self:EntityStore): (table<string, number>, table<string, number>)
--- @field Filter fun(self:EntityStore, fn:fun(guid:string, data:EntityData):boolean):table<string, EntityData>
--- @field FilterByTag fun(self:EntityStore, tag:string):table<string, EntityData>
--- @field FilterByTags fun(self:EntityStore, tags:string[]):table<string, EntityData>
--- @field FilterByGroup fun(self:EntityStore, group:string):table<string, EntityData>
--- @field SearchByNote fun(self:EntityStore, keyword:string):table<string, EntityData>
--- @field GetDisplayNameFromGuid fun(self:EntityStore, guid:string):string|nil
--- @field GetGuidFromDisplayName fun(self:EntityStore, displayName:string?):string
--- @field RegisterDisplayName fun(self:EntityStore, displayName:string, guid?:string, discardName?:string):string?
--- @field RemoveDisplayName fun(self:EntityStore, displayName:string?)
--- @field GetAllDisplayNames fun(self:EntityStore):string[]
EntityStore = {
    Tree = TreeTable.new(),
    BindSubscriptions = {}
}

setmetatable(EntityStore, {
    __index = function(t, k)
        return rawget(t, k) or EntityStore:GetStoredData(k)
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
    Debug("Setting up EntityStore server listeners...")
    local popupNotif = Notification.new("Realm Builder")
    popupNotif.Pivot = {0.5, 0.1}
    popupNotif.FlickToDismiss = true

    NetChannel.Entities.Added:SetHandler(function (data)
        if not data.Entities or #data.Entities == 0 then
            return
        end

        local list = {}
        local now = Ext.Timer.MonotonicTime()
        for _, entity in ipairs(data.Entities) do
            if not EntityDatas[entity.Guid] then
                self:AddEntity(entity.Guid, entity)
                --Debug("New Prop", prop)
                table.insert(list, entity.Guid)
            end
        end
        now = Ext.Timer.MonotonicTime()
        if RB_GLOBALS.MainMenu then
            RB_GLOBALS.MainMenu:NewEntityAdded(list)
        end
        --Debug(string.format("Notified UI of %d new entities in %.2f ms", #list, (Ext.Timer.MonotonicTime() - now)))
    end)


    NetChannel.Entities.Deleted:SetHandler(function (data)
        if #data == 0 then
            return
        end

        for _, guid in ipairs(data) do
            if guid ~= nil and guid ~= "" and EntityDatas[guid] then
                EntityStore:RemoveEntity(guid)
            end
        end
        RB_GLOBALS.MainMenu:EntityDeleted(data)
    end)

    NetChannel.AttributeChanged:SetHandler(function(data)
        for _,guid in pairs(data.Guid) do
            if EntityDatas[guid] then
                EntityDatas[guid].Visible = data.Attributes.Visible
                RB_GLOBALS.MainMenu.entityMenu:UpdateEyeIcon(guid)
            end
        end
    end)

    local subs = self.BindSubscriptions
    NetChannel.BindProps:SetHandler(function(data)
        for _, info in ipairs(data.BindInfos) do
            local guid = info.Guid
            local parent = info.BindParent
            if RBUtils.IsCamera(parent) then parent = CAMERA_SYMBOL end
            if not parent then BindDatas[guid] = nil goto continue end
            BindDatas[guid] = BindDatas[guid] or {}
            BindDatas[guid].BindParent = parent
            BindDatas[guid].KeepLookingAt = info.KeepLookingAt
            BindDatas[guid].FollowParent = info.FollowParent

            if subs[guid] then
                subs[guid](BindDatas[guid])
            end

            ::continue::
        end

        popupNotif:Show("Bind Update", function (panel)
            for _, info in ipairs(data.BindInfos) do
                local guid = info.Guid
                local parent = info.BindParent
                panel:AddText(string.format("%s => %s", 
                    RBGetName(guid) or guid, 
                    RBGetName(parent) or (parent and parent or "Unbound"
                )))
                panel:AddText("Attributes: " .. (info.KeepLookingAt and "KeepLookingAt " or "") .. (info.FollowParent and "FollowParent" or ""))
            end
        end)
    end)
end

---@param guid GUIDSTRING
---@param callback fun(data:BindInfo)
---@return RBSubscription?
function EntityStore:SubscribeToBindChanges(guid, callback)
    if not guid or guid == "" then
        Error("SubscribeToBindChanges called with invalid guid")
        return nil
    end

    local subs = self.BindSubscriptions
    subs[guid] = callback

    local sub = {}
    local unsub = function()
        subs[guid] = nil
    end

    return { Unsubscribe = unsub, ID = sub }
end

---@param guid string
---@param data EntityData
function EntityStore:AddEntity(guid, data)
    if cachedToRestore[guid] then
        data = cachedToRestore[guid]
        cachedToRestore[guid] = nil
    end

    EntityDatas[guid] = data

    if data.IsScenery then
        data.Icon = RB_ICONS.Scenery
    end

    self:RegisterDisplayName(data.DisplayName or GetDisplayNameForTemplateId(data.TemplateId), guid)
        
    if not self.Tree:Find(guid) then
        if data.Path and #data.Path > 0 and self.Tree:AddPath(data.Path) then
            self.Tree:AddLeaf(guid, "end", data.Path[#data.Path])
        else
            self.Tree:AddLeaf(guid, "end")
        end
    end

    if not EntityDatas[guid].Tags then
        EntityDatas[guid].Tags = {}
    end
end

function EntityStore:RemoveEntity(guid)
    cachedToRestore[guid] = self:GetStoredData(guid)
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
function EntityStore:GetStoredData(guid)
    if not EntityDatas[guid] then
        return nil
    end

    local entity = Ext.Entity.Get(guid) --[[@as EntityHandle]]
    local data = EntityDatas[guid]
    if entity then
        data.CanInteract = entity.CanInteract and true or false
        --data.Visible = not entity.Invisibility
        data.Gravity = not entity.GravityDisabled 
        data.Movable = entity.CanMove and true or false
        data.CanBeLooted = entity.CanBeLooted and true or false
        data.Position = { RBGetPosition(guid) }
        data.Rotation = { RBGetRotation(guid) }
        data.Path = self.Tree:GetPath(guid, true, true)
        
        if EntityHelpers.IsCharacter(guid) then
            data.Gravity = nil
            data.CanBeLooted = nil
            data.Movable = nil
        elseif entity.Scenery then
            data.CanBeLooted = nil
            data.Movable = nil
        end
    end

    return data
end

--- @param guid any
--- @return 'item'|'character'|'scenery'|nil
function EntityStore:GetStoredTemplateType(guid)
    local data = self:GetStoredData(guid)
    if not data then
        return nil
    end
    local template = Ext.Template.GetTemplate(EntityHelpers.TakeTailTemplate(data.TemplateId))
    if not template then
        return nil
    end
    return template.TemplateType
end

function EntityStore:GetStoredDatas(guids)
    local results = {}
    for _, guid in pairs(guids) do
        if EntityDatas[guid] then
            results[guid] = RBUtils.DeepCopy(EntityDatas[guid])
        end
    end
    return results
end

---@return table<GUIDSTRING, EntityData>
function EntityStore:GetAllStored()
    return RBUtils.DeepCopy(EntityDatas)
end

function EntityStore:GetEntity(guid)
    return Ext.Entity.Get(guid)
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
        return data.Tags and table.find(data.Tags, tag)
    end)
end

function EntityStore:FilterByTags(tags)
    return self:Filter(function(guid, data)
        if not data.Tags then
            return false
        end
        for _, tag in pairs(tags) do
            if not table.find(data.Tags, tag) then
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


---@param displayName string
---@param guid GUIDSTRING
---@param discardName string?
---@return string|nil registered
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
        local suf = RBStringUtils.PadNumber(cnt, 3)
        returnName = displayName .. "_" .. suf
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

--- these attributes are not needed for export
local uselessExportAttributes = {
    "Path",
    "Tags",
    "Group",
    "Note",
    "IconTintColor",
    "VisualPreset",
    "Persistent",
}

local uselessSceneryAttributes = {
    "CanInteract",
    "Movable",
    "Visible",
    "Gravity",
    "IsScenery",
    "DisplayName",
    "IsScenery",
    "CanBeLooted",
}

--- @param entData EntityData
function EntityStore:DeleteUselessExportAttributes(entData)
    for _, attr in pairs(uselessExportAttributes) do
        entData[attr] = nil
    end
    if entData.TemplateType == "scenery" then
        for _, attr in pairs(uselessSceneryAttributes) do
            entData[attr] = nil
        end
    end
end

---@param guids GUIDSTRING[]
---@return table<GUIDSTRING, EntityData>
function EntityStore:GetExportCopy(guids)
    local results = {}
    local hostLevel = _C().Level and _C().Level.LevelName or nil
    if not hostLevel then
        Warning("[Realm Builder] GetExportCopy called but host level is nil!")
        return results
    end
    for _, guid in pairs(guids) do
        if EntityDatas[guid] then
            local entity = Ext.Entity.Get(guid)
            if not entity then goto continue end
            local data = RBUtils.DeepCopy(self:GetStoredData(guid)) --[[@as EntityData]]
            local template = Ext.Template.GetTemplate(EntityHelpers.TakeTailTemplate(data.TemplateId))
            if not template then goto continue end
            data.TemplateType = template.TemplateType

            if data.TemplateType == "TileConstruction" then 
                goto continue
            end

            results[guid] = data
            self:DeleteUselessExportAttributes(data)

            data.Position = { RBGetPosition(guid) }
            data.Rotation = { RBGetRotation(guid) }
            data.Scale = { RBGetScale(guid) }

            local hasIcon = template.TemplateType == "character" or template.TemplateType == "item"
            data.Scale = math.min(data.Scale[1], data.Scale[2], data.Scale[3])
            data.DisplayIcon = RBGetIcon(guid)
            data.Icon = hasIcon and template.Icon or nil
            data.LevelName = entity.Level and entity.Level.LevelName or hostLevel
        
            local visualTab = VisualTab.FetchByGuid(guid)
            if data.TemplateType == "character" and template and visualTab then
                data.OverrideVisualParameters = visualTab:ExportModifiedMaterialParams()
    
                if not next(data.OverrideVisualParameters or {}) then
                    data.OverrideVisualParameters = nil
                    goto continue
                end
                data.OriginalVisualUuid = template.CharacterVisualResourceID
                data.UseCustomVisualParameters = true
            elseif (data.TemplateType == "item" or data.TemplateType == "scenery") and template and visualTab then
                local isVisual = Ext.Resource.Get(template.VisualTemplate, "Visual") 
                if isVisual then -- currently only support VisualTemplate override for visual resource
                    data.VisualObjectMaterialOverride = visualTab:ExportObjectEdit()
                    if not next(data.VisualObjectMaterialOverride or {}) then
                        data.VisualObjectMaterialOverride = nil
                        goto continue
                    end
                    data.OriginalVisualUuid = template.VisualTemplate
                    data.UseCustomVisualParameters = true
                    
                    if not data.VisualObjectMaterialOverride then
                        data.UseCustomVisualParameters = nil
                    end
                end
            end

            ::continue::
        end
    end
    return results
end

EntityStore:SetupServerListeners()