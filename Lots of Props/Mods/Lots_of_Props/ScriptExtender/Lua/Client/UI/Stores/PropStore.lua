local PropDatas = {}
local BindDatas = {}
local GuidToDisplayName = {}
local DisplayNameToGuid = {}

local propNameBlacklist = {
    ["Group Analog Stick"] = true,
    ["Camera"] = true,
}

PropStore = {
    Tree = TreeTable.new()
}

--- @class PropData
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

--- @class PropStore
--- @field AddProp fun(self:PropStore, guid:string, data:PropData)
--- @field RemoveProp fun(self:PropStore, guid:string)
--- @field SetProp fun(self:PropStore, guid:string, data:PropData)
--- @field GetProp fun(self:PropStore, guid:string):PropData
--- @field GetProps fun(self:PropStore, guids:string[]):table<string, PropData>
--- @field GetAll fun(self:PropStore):table<string, PropData>
--- @field CountGroupAndTag fun(self:PropStore): (table<string, number>, table<string, number>)
--- @field Filter fun(self:PropStore, fn:fun(guid:string, data:PropData):boolean):table<string, PropData>
--- @field FilterByTag fun(self:PropStore, tag:string):table<string, PropData>
--- @field FilterByTags fun(self:PropStore, tags:string[]):table<string, PropData>
--- @field FilterByGroup fun(self:PropStore, group:string):table<string, PropData>
--- @field SearchByNote fun(self:PropStore, keyword:string):table<string, PropData>
--- @field GetDisplayNameFromGuid fun(self:PropStore, guid:string):string|nil
--- @field GetGuidFromDisplayName fun(self:PropStore, displayName:string):string
--- @field RegisterDisplayName fun(self:PropStore, displayName:string, guid?:string, discardName?:string):string
--- @field RemoveDisplayName fun(self:PropStore, displayName:string)
--- @field GetAllDisplayNames fun(self:PropStore):string[]

setmetatable(PropStore, {
    __index = function(t, k)
        return rawget(t, k) or PropDatas[k]
    end,
    __newindex = function(t, k, v)
        if type(k) == "string" and type(v) ~= "function" then
            PropDatas[k] = v
        else
            rawset(t, k, v)
        end
    end
})

function PropStore:SetupServerListeners()

    local popupNotif = Notification.new("Lots of Props")
    popupNotif.Pivot = {0.5, 0.1}
    popupNotif.FlickToDismiss = true

    ClientSubscribe(NetMessage.ServerProps, function(data)
        if #data == 0 then
            return
        end

        local list = {}
        for _, prop in ipairs(data) do
            if not PropDatas[prop.Guid] then
                self:AddProp(prop.Guid, prop)
                --Debug("New Prop", prop)
                table.insert(list, prop.Guid)
            end
        end
        LOPMenu:NewPropAdded(list)
    end)

    ClientSubscribe(NetMessage.DeletedProps, function(data)
        if #data == 0 then
            return
        end

        for _, guid in ipairs(data) do
            if guid ~= nil and guid ~= "" then
                PropStore:RemoveProp(guid)
            end
        end
        LOPMenu:PropDeleted(data)
    end)

    ClientSubscribe(NetMessage.AttributeChanged, function(data)
        for _,guid in pairs(data.Guid) do
            if PropDatas[guid] then
                for k, v in pairs(data) do
                    if k ~= "Guid" and type(v) == "boolean" then
                        PropDatas[guid][k] = v
                    end
                end
            end
        end

        LOPMenu.propsMenu:UpdateList()
    end)

    ClientSubscribe(NetMessage.BindProps, function (data)
        for _, info in ipairs(data.BindInfos) do
            local guid = info.Guid
            local parent = info.BindParent
            if IsCamera(parent) then parent = CameraSymbol end
            if not parent then BindDatas[guid] = nil goto continue end
            BindDatas[guid] = BindDatas[guid] or {}
            BindDatas[guid].BindParent = parent
            BindDatas[guid].KeepLookingAt = info.KeepLookingAt
            BindDatas[guid].NotFollowParent = info.NotFollowParent
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
                panel:AddText("Attributes: " .. (info.KeepLookingAt and "KeepLookingAt " or "") .. (info.NotFollowParent and "NotFollowParent" or ""))
            end
        end)

    end)
end

---@param guid string
---@param data PropData
function PropStore:AddProp(guid, data)

    PropDatas[guid] = data

    self:RegisterDisplayName(GetDisplayNameForTemplateId(data.TemplateId), guid)

    if not self.Tree:Find(guid) then
        if data.Path then
            if self.Tree:AddPath(data.Path) then
                self.Tree:AddLeaf(guid, "end", data.Path[#data.Path])
            else
                self.Tree:AddLeaf(guid, "end")
            end
        end
    end

    if not PropDatas[guid].Tags then
        PropDatas[guid].Tags = {}
    end
end

function PropStore:RemoveProp(guid)
    self.Tree:Remove(guid)
    self:RemoveDisplayName(PropDatas[guid] and PropDatas[guid].DisplayName)
    PropDatas[guid] = nil
end

function PropStore:SetProp(guid, data)
    for k, v in pairs(data) do
        if PropDatas[guid] then
            PropDatas[guid][k] = v
        end
    end
end

--- @param guid string
--- @return PropData|nil
function PropStore:GetProp(guid)
    return PropDatas[guid]
end

function PropStore:GetProps(guids)
    local results = {}
    for _, guid in pairs(guids) do
        if PropDatas[guid] then
            results[guid] = PropDatas[guid]
        end
    end
    return results
end

function PropStore:GetAll()
    return DeepCopy(PropDatas)
end

function PropStore:CountGroupAndTag()
    local groupCnt = {}
    local tagsCnt = {}
    for _, data in pairs(PropDatas) do
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

---@param fn fun(guid:string, data:PropData):boolean
---@return table<string, PropData>
function PropStore:Filter(fn)
    local results = {}
    for guid, data in pairs(PropDatas) do
        if fn(guid, data) then
            results[guid] = data
        end
    end
    return results
end

function PropStore:FilterByTag(tag)
    return self:Filter(function(guid, data)
        return data.Tags and TableContains(data.Tags, tag)
    end)
end

function PropStore:FilterByTags(tags)
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

function PropStore:FilterByGroup(group)
    return self:Filter(function(guid, data)
        return data.Group == group
    end)
end

function PropStore:SearchByNote(keyword)
    return self:Filter(function(guid, data)
        return data.Note and string.find(string.lower(data.Note), string.lower(keyword), 1, true) ~= nil
    end)
end

function PropStore:RegisterDisplayName(displayName, guid, discardName)
    if not displayName or displayName == "" then
        return
    end

    self:RemoveDisplayName(discardName)

    if propNameBlacklist[displayName] then
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
        PropDatas[guid].DisplayName = returnName
    else
        Warning("[Lots of Props] RegisterDisplayName called without guid for name: " .. returnName)
        return
    end

    return returnName
end

function PropStore:RemoveDisplayName(displayName)
    if not displayName or displayName == "" then
        return
    end

    if DisplayNameToGuid[displayName] then
        local guid = DisplayNameToGuid[displayName]
        DisplayNameToGuid[displayName] = nil
        GuidToDisplayName[guid] = nil
    end
end

function PropStore:GetAllDisplayNames()
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
function PropStore:GetPropNameFromGuid(guid)
    if GuidToDisplayName[guid] then
        return GuidToDisplayName[guid]
    end
    return nil
end

function PropStore:GetGuidFromPropName(displayName)
    if DisplayNameToGuid[displayName] then
        return DisplayNameToGuid[displayName]
    end
    return nil
end

function PropStore:GetBindParent(guid)
    return BindDatas[guid] and BindDatas[guid].BindParent or nil
end

--- @param guid GUIDSTRING
--- @return BindInfo|nil
function PropStore:GetBindInfo(guid)
    return BindDatas[guid] or {}
end

function PropStore:BuildDisplayNameToTemplateTree()
    local tree = TreeTable.new()
    
    return tree
end

function PropStore:RestoreTreeListFromTable()


end

PropStore:SetupServerListeners()

Ext.RegisterConsoleCommand("PropStore", function (cmd, ...)
    local args = {...}
    if #args == 0 then
        _P("[Lots of Props] Usage: <list|count|dump|get <guid>>")
        return
    end

    local action = args[1]:lower()
    if action == "list" then
        local cnt = 0
        for guid, data in pairs(PropStore:GetAll()) do
            cnt = cnt + 1
            _P(string.format("%d. %s - %s", cnt, guid, data.DisplayName or "No Name"))
        end
        _P(string.format("[Lots of Props] Total %d props in store.", cnt))
    elseif action == "count" then
        local groupCnt, tagsCnt = PropStore:CountGroupAndTag()
        _P("[Lots of Props] Group Counts:")
        for group, cnt in pairs(groupCnt) do
            _P(string.format(" - %s: %d", group, cnt))
        end
        _P("[Lots of Props] Tag Counts:")
        for tag, cnt in pairs(tagsCnt) do
            _P(string.format(" - %s: %d", tag, cnt))
        end
    elseif action == "dump" then
        _D(PropStore:GetAll())
    elseif action == "get" then
        if #args < 2 then
            _P("[Lots of Props] Usage: LOP_PropStore get <guid>")
            return
        end
        local guid = args[2]
        local data = PropStore:GetProp(guid)
        if data then
            _D(data)
        else
            _P(string.format("[Lots of Props] No prop found with GUID %s", guid))
        end
    else
        _P("[Lots of Props] Unknown action: " .. action)
    end
end)