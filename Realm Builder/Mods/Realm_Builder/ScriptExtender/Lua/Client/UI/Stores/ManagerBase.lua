--- @class RB_CategorizableObject
--- @field Group string
--- @field Tags string[]
--- @field Note string

--- @class ManagerBase
--- @field Data table<string, table>
--- @field CountGroupsAndTags fun(self):table<string, number>, table<string, number>, table<string, string[]>, table<string, string[]>
--- @field AddTagToData fun(self, uuid:string, tag:string)
--- @field RemoveTagFromData fun(self, uuid:string, tag:string)
--- @field ChangeDataGroup fun(self, uuid:string, group:string)
--- @field ChangeDataNote fun(self, uuid:string, note:string)
--- @field CheckHostValidEquipmentVisual fun(self, guid:string)
--- @field Clear fun(self)
--- @field new fun(self):ManagerBase
--- @field populated boolean
--- @field tagIcons table<string, string>
--- @field tagTree TreeTable
ManagerBase = _Class("ManagerBase")

function ManagerBase:__init()
    self.Data = {}

    self.tagIcons = {}
    self.tagTree = TreeTable.new()

    self.populated = false
end

function ManagerBase:ChangeDataGroup(uuid, group)
    if not uuid or uuid == "" then
        return
    end
    if not self.Data[uuid] then
        return
    end
    self.Data[uuid].Group = group
end

function ManagerBase:ClearGroup(group)
    if not group or group == "" then return end
    for uuid, entry in pairs(self.Data) do
        if entry.Group == group then
            entry.Group = ""
        end
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
end

---@return table<string, number> groupCount
---@return table<string, number> tagCount
---@return table<string, string[]> groupMap
---@return table<string, string[]> tagMap
function ManagerBase:CountGroupsAndTags(guid)
    if self.CheckHostValidEquipmentVisual then
        self:CheckHostValidEquipmentVisual(guid)
    end
    local groupCount = {}
    local tagCount = {}
    local groupMap = {}
    local tagMap = {}

    for uuid, entry in pairs(self.Data) do
        if entry.Group and entry.Group ~= "" then
            groupCount[entry.Group] = (groupCount[entry.Group] or 0) + 1
            groupMap[entry.Group] = groupMap[entry.Group] or {}
            groupMap[entry.Group][#groupMap[entry.Group] + 1] = uuid
        end
        if entry.Tags then
            for _, tag in ipairs(entry.Tags) do
                if tag ~= "" then
                    tagCount[tag] = (tagCount[tag] or 0) + 1
                    tagMap[tag] = tagMap[tag] or {}
                    tagMap[tag][#tagMap[tag] + 1] = uuid
                end
            end
        end
    end

    for tag, cnt in pairs(tagCount) do
        self.tagTree:SetLeafValue(tag, cnt)
    end

    return groupCount, tagCount, groupMap, tagMap
end

function ManagerBase:AddTagToData(uuid, tag)
    if self.tagTree and self.tagTree:Find(tag) and not self.tagTree:IsLeaf(tag) then
        ConfirmPopup:Popup(string.format(GetLoca("The name '%s' is already used as a category. Please choose a different name for the tag."), tag))
        return
    end


    if not uuid or uuid == "" then
        return
    end
    if not self.Data[uuid] then
        return
    end
    if not self.Data[uuid].Tags then
        self.Data[uuid].Tags = {}
    end
    if not table.contains(self.Data[uuid].Tags, tag) then
        table.insert(self.Data[uuid].Tags, tag)
    else
    end
end

function ManagerBase:RemoveTagFromData(uuid, tag)
    if not uuid or uuid == "" then
        Warning("[SearchData] Cannot remove tag, no UUID provided.")
        return
    end

    if not self.Data[uuid] then
        return
    end
    if not self.Data[uuid].Tags then
        return
    end
    for i, t in ipairs(self.Data[uuid].Tags) do
        if t == tag then
            table.remove(self.Data[uuid].Tags, i)
            return
        end
    end
end

function ManagerBase:ClearTag(tag)
    for uuid, entry in pairs(self.Data) do
        if entry.Tags then
            for i, t in ipairs(entry.Tags) do
                if t == tag then
                    table.remove(entry.Tags, i)
                    break
                end
            end
        end
    end
end