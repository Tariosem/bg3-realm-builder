--- @class ManagerBase
--- @field Data table<string, table>
--- @field CountGroupsAndTags fun(self):table<string, number>, table<string, number>, table<string, string[]>, table<string, string[]>
--- @field AddTagToData fun(self, uuid:string, tag:string)
--- @field RemoveTagFromData fun(self, uuid:string, tag:string)
--- @field ChangeDataGroup fun(self, uuid:string, group:string)
--- @field ChangeDataNote fun(self, uuid:string, note:string)
--- @field Clear fun(self)
--- @field new fun(self):ManagerBase
--- @field populated boolean
--- @field tagIcons table<string, string>
--- @field tagTree TreeTable
--- @field tagMap table<string, table<string, boolean>>
--- @field groupMap table<string, table<string, boolean>>
--- @field groupCount table<string, number>
--- @field tagCount table<string, number>
ManagerBase = _Class("ManagerBase")

function ManagerBase:__init()
    self.Data = {}

    self.tagIcons = {}
    self.tagTree = TreeTable.new()

    self.tagMap = {}
    self.groupMap = {}
    self.groupCount = {}
    self.tagCount = {}

    self.customizationData = {}

    self.populated = false
end

function ManagerBase:ChangeDataGroup(uuid, group)
    if not uuid or uuid == "" then
        return
    end
    if not self.Data[uuid] then
        return
    end

    local originalGroup = nil
    for groupName, uuids in pairs(self.groupMap) do
        if uuids[uuid] then
            originalGroup = groupName
            break
        end
    end

    if group == "" then
        group = nil
    end

    if group ~= group then
        group = nil
    end

    if self.groupCount then
        if originalGroup then
            self.groupCount[originalGroup] = (self.groupCount[originalGroup] or 1) - 1
        end
        if group then
            self.groupCount[group] = (self.groupCount[group] or 0) + 1
        end
    end

    if self.groupMap then
        if originalGroup then
            self.groupMap[originalGroup] = self.groupMap[originalGroup] or {}
            self.groupMap[originalGroup][uuid] = nil
        end
        if group then
            self.groupMap[group] = self.groupMap[group] or {}
            self.groupMap[group][uuid] = true
        end
    end
    
    if self.populated then
        self.customizationData[uuid] = self.customizationData[uuid] or {}
        self.customizationData[uuid].Group = group
    end
end

function ManagerBase:ChangeDataNote(uuid, note)
    if not uuid or uuid == "" then
        return
    end
    if not self.Data[uuid] then
        return
    end
    self.Data[uuid].Note = note

    if self.populated then
        self.customizationData[uuid] = self.customizationData[uuid] or {}
        self.customizationData[uuid].Note = note
    end

end

---@return table<string, number> groupCount
---@return table<string, number> tagCount
---@return table<string, table<string, boolean>> groupMap
---@return table<string, table<string, boolean>> tagMap
function ManagerBase:CountGroupsAndTags(guid)
    self:UpdateTagTree()
    return self.groupCount, self.tagCount, self.groupMap, self.tagMap
end

function ManagerBase:UpdateTagTree()
    for tag, count in pairs(self.tagCount) do
        self.tagTree:SetLeafValue(tag, count)
        if not self.tagTree:Find(tag) then
            self.tagTree:AddLeaf(tag, count, self.tagTree:GetRootKey())
        end
    end
end

function ManagerBase:AddTagToData(uuid, tag)
    if self.tagTree and self.tagTree:Find(tag) and not self.tagTree:IsLeaf(tag) then
        ConfirmPopup:Popup(string.format(GetLoca("The name '%s' is already used as a category. Please choose a different name for the tag."), tag))
        Debug(string.format("[Manager] Cannot add tag '%s' to UUID '%s' because it is a category in the tag hierarchy.", tag, uuid))
        return
    end

    if not uuid or uuid == "" then
        return
    end

    if self:HasTagInData(uuid, tag) then
        return
    end

    if not self.tagTree:Find(tag) then
        self.tagTree:AddLeaf(tag)
    end
    self.tagCount[tag] = (self.tagCount[tag] or 0) + 1
    self.tagMap[tag] = self.tagMap[tag] or {}
    self.tagMap[tag][uuid] = true

    if self.populated then
        self.customizationData[uuid] = self.customizationData[uuid] or {}
        self.customizationData[uuid].Tags = self.customizationData[uuid].Tags or {}
        table.insert(self.customizationData[uuid].Tags, tag)
    end
end

function ManagerBase:ClearTag(tagName)
    if self.tagMap and self.tagMap[tagName] then
        for uuid, _ in pairs(self.tagMap[tagName]) do
            self:RemoveTagFromData(uuid, tagName)
        end
    end
end

function ManagerBase:RenameTag(oldName, newName)
    if not oldName or oldName == "" or not newName or newName == "" then
        return false
    end

    if self.tagMap and self.tagMap[oldName] then
        local suc = self.tagTree:Rename(oldName, newName)
        if not suc then
            Warning(string.format("[Manager] Cannot rename tag '%s' to '%s' ", oldName, newName))
            return false
        end
        self.tagIcons[newName] = self.tagIcons[oldName]
        self.tagIcons[oldName] = nil
        local uuids = {}
        for uuid, _ in pairs(self.tagMap[oldName]) do
            table.insert(uuids, uuid)
        end

        for _, uuid in ipairs(uuids) do
            self:RemoveTagFromData(uuid, oldName)
            self:AddTagToData(uuid, newName)
        end
    end

    return true
end

function ManagerBase:RenameTagCollection(oldName, newName)
    if not oldName or oldName == "" or not newName or newName == "" then
        return false
    end

    local suc = self.tagTree:Rename(oldName, newName)
    if not suc then
        Warning(string.format("[ManagerBase] Cannot rename tag collection '%s' to '%s' because the new name is already used as a category in the tag hierarchy.", oldName, newName))
        return false
    end

    self.tagIcons[newName] = self.tagIcons[oldName]
    self.tagIcons[oldName] = nil

    return true
end

function ManagerBase:AddTagToDataNonCustomization(uuid, tag)
    if self.tagTree and self.tagTree:Find(tag) and not self.tagTree:IsLeaf(tag) then
        ConfirmPopup:Popup(string.format(GetLoca("The name '%s' is already used as a category. Please choose a different name for the tag."), tag))
        Debug(string.format("[ManagerBase] Cannot add tag '%s' to UUID '%s' because it is a category in the tag hierarchy.", tag, uuid))
        return
    end

    if not uuid or uuid == "" then
        return
    end

    if self:HasTagInData(uuid, tag) then
        return
    end

    if not self.Data[uuid] then
        return
    end

    self.tagTree:AddLeaf(tag)
    self.tagCount[tag] = (self.tagCount[tag] or 0) + 1
    self.tagMap[tag] = self.tagMap[tag] or {}
    self.tagMap[tag][uuid] = true
end

function ManagerBase:HasTagInData(uuid, tag)
    if not uuid or uuid == "" then
        return false
    end

    if not self.Data[uuid] then
        return false
    end

    if self.tagMap and self.tagMap[tag] and self.tagMap[tag][uuid] then
        return true
    end

    if self.populated and self.customizationData[uuid] and self.customizationData[uuid].Tags then
        return table.find(self.customizationData[uuid].Tags, tag) ~= nil
    end

    return false
end

function ManagerBase:RemoveTagFromData(uuid, tag)
    if not uuid or uuid == "" then
        Warning("[SearchData] Cannot remove tag, no UUID provided.")
        return
    end

    if not self.Data[uuid] then
        return
    end

    if self.tagCount and self.tagCount[tag] then
        self.tagCount[tag] = math.max((self.tagCount[tag] or 1) - 1, 0)
    end

    if self.tagMap and self.tagMap[tag] then
        self.tagMap[tag][uuid] = nil
        if not next(self.tagMap[tag]) then
            self.tagMap[tag] = nil
            self.tagCount[tag] = nil
            self.tagTree:Remove(tag)
        end
    end

    if self.populated and self.customizationData[uuid] and self.customizationData[uuid].Tags then
        for i, existingTag in ipairs(self.customizationData[uuid].Tags) do
            if existingTag == tag then
                table.remove(self.customizationData[uuid].Tags, i)
                break
            end
        end
    end
end

--- @class RB_FilterSetting
--- @field IncludeTags string[]
--- @field ExcludeTags string[]
--- @field MatchAllTags boolean
--- @field IncludeGroups string[]
--- @field ExcludeGroups string[]
--- @field NoteText string
--- @field SearchField string[]
--- @field Keywords string[]

--- @param Set RB_FilterSetting
--- @return table<string, table>
function ManagerBase:Filter(Set)
    local candidates = {}

    local IncludeTags = Set.IncludeTags or {}
    local ExcludeTags = Set.ExcludeTags or {}
    local IncludeGroups = Set.IncludeGroups or {}
    local ExcludeGroups = Set.ExcludeGroups or {}
    local NoteText = Set.NoteText or ""
    local SearchField = Set.SearchField or {}
    local Keywords = Set.Keywords or {}
    local MatchAllTags = Set.MatchAllTags or false

    if #IncludeTags == 0 and #ExcludeTags == 0 and #IncludeGroups == 0 and #ExcludeGroups == 0 and NoteText == "" and #Keywords == 0 then
        return self.Data
    end

    if #IncludeTags > 0 then
        for _, tag in ipairs(IncludeTags) do
            local tagMap = self.tagMap[tag] or {}
            for uuid, _ in pairs(tagMap) do
                candidates[uuid] = (candidates[uuid] or 0) + 1
            end
        end

        if MatchAllTags then
            for uuid, count in pairs(candidates) do
                if count < #IncludeTags then
                    candidates[uuid] = nil
                end
            end
        end
    else
        for uuid, _ in pairs(self.Data) do
            candidates[uuid] = true
        end
    end

    if #ExcludeTags > 0 then
        for _, tag in ipairs(ExcludeTags) do
            local tagMap = self.tagMap[tag] or {}
            for uuid, _ in pairs(tagMap) do
                candidates[uuid] = nil
            end
        end
    end

    if #IncludeGroups > 0 then
        local groupCandidates = {}
        for _, group in ipairs(IncludeGroups) do
            local groupMap = self.groupMap[group] or {}
            for uuid, _ in pairs(groupMap) do
                groupCandidates[uuid] = true
            end
        end

        if next(candidates) then
            for uuid in pairs(candidates) do
                if not groupCandidates[uuid] then
                    candidates[uuid] = nil
                end
            end
        else
            candidates = groupCandidates
        end
    end

    if #ExcludeGroups > 0 then
        for _, group in ipairs(ExcludeGroups) do
            local groupMap = self.groupMap[group] or {}
            for uuid, _ in pairs(groupMap) do
                candidates[uuid] = nil
            end
        end
    end

    for i, keyword in ipairs(Keywords) do
        Keywords[i] = keyword:lower()
    end

    for uuid, _ in pairs(candidates) do
        local entry = self.Data[uuid]
        if NoteText ~= "" then
            if not entry.Note or entry.Note:lower():find(NoteText:lower()) == nil then
                candidates[uuid] = nil
            end
        end

        if #Keywords > 0 then
            local text = ""
            for _, field in ipairs(SearchField) do
                local value = entry[field]
                if value and type(value) == "string" then
                    text = text .. " " .. value:lower()
                end
            end

            for _, keyword in ipairs(Keywords) do
                if not text:find(keyword, 1, true) then
                    candidates[uuid] = nil
                    break
                end
            end
        end
    end

    local results = {}
    for uuid, _ in pairs(candidates) do
        results[uuid] = self.Data[uuid]
    end

    return results
end


function ManagerBase:ExportCustomizations()
    return self.customizationData
end

--- @param data table<string, {Group:string, Note:string, Tags:string[]}>
function ManagerBase:ImportCustomizations(data)
    if not data then
        return
    end

    for uuid, customData in pairs(data) do
        if customData.Group then
            self:ChangeDataGroup(uuid, customData.Group)
        end
        if customData.Note then
            self:ChangeDataNote(uuid, customData.Note)
        end
        if customData.Tags then
            for _, tag in ipairs(customData.Tags) do
                self:AddTagToData(uuid, tag)
            end
        end
    end
end