function IconBrowser:SaveLibChanges(uuid, field, value, isdelete)
    local isDelete = isdelete or false

    if not self.changedLib[uuid] then
        self.changedLib[uuid] = {}
        self.changedLib[uuid].TemplateName = self.searchData[uuid].TemplateName or ""
    end
    self.changedLib[uuid].TemplateName = self.searchData[uuid].TemplateName or ""

    local originalField = self.searchData[uuid] and self.searchData[uuid][field]
    local isArrayField = type(originalField) == "table"

    if not isDelete then
        if isArrayField then
            if self.changedLib[uuid][field] == nil then
                self.changedLib[uuid][field] = {}
            end

            if type(self.changedLib[uuid][field]) ~= "table" then
                self.changedLib[uuid][field] = {}
            end

            if not table.contains(self.changedLib[uuid][field], value) then
                table.insert(self.changedLib[uuid][field], value)
            end
        else
            self.changedLib[uuid][field] = value
        end
    else
        if isArrayField then
            if self.changedLib[uuid][field] and type(self.changedLib[uuid][field]) == "table" then
                local index = table.indexOf(self.changedLib[uuid][field], value)
                if index then
                    table.remove(self.changedLib[uuid][field], index)

                    if #self.changedLib[uuid][field] == 0 then
                        self.changedLib[uuid][field] = nil
                    end
                end
            end
        else
            self.changedLib[uuid][field] = nil
        end
    end

    if next(self.changedLib[uuid]) == nil then
        self.changedLib[uuid] = nil
    end

    if self.autoSave then
        self:SaveChanges()
    end
end

function IconBrowser:SaveTagHierarchy()
    if not self.dataManager.tagTree then
        Error("No tag hierarchy to save.")
        return
    end

    local treeData = self.dataManager.tagTree:ToTable()

    local savedata = Ext.Json.Stringify(treeData)
    local toSave = {}
    local fileContent = Ext.IO.LoadFile(GetModPath(self.displayName))
    local success = true
    if not fileContent or fileContent == "" then
        toSave.TagHierarchy = treeData
    else
        local existingData = Ext.Json.Parse(fileContent)
        if type(existingData) ~= "table" then
            existingData = {}
        end
        toSave = existingData
        toSave.TagHierarchy = treeData
    end

    success = Ext.IO.SaveFile(GetModPath(self.displayName), Ext.Json.Stringify(toSave))

    if success then
        --Info("Tag hierarchy saved successfully.")
    else
        Error("Failed to save tag hierarchy.")
    end
end

function IconBrowser:SaveChanges()
    if next(self.changedLib) == nil then
        Info("No changes to save.")
        return
    end

    local data = self.changedLib

    if not data or type(data) ~= "table" then
        Error("No changes to save.")
        return
    end

    local toSave = {}

    local fileContent = Ext.IO.LoadFile(GetModPath(self.displayName))
    if fileContent and fileContent ~= "" then
        local existingData = Ext.Json.Parse(fileContent)
        if type(existingData) ~= "table" then
            existingData = {}
        end
        toSave = existingData
        toSave.Customizations = data
    else
        toSave.Customizations = data
    end

    local savedata = Ext.Json.Stringify(toSave)

    local ok = Ext.IO.SaveFile(GetModPath(self.displayName), savedata)
    if ok then
        --Info("Changes saved successfully.")
    else
        Error("Failed to save changes: ")
    end
end

function IconBrowser:LoadChanges()
    local data = Ext.IO.LoadFile(GetModPath(self.displayName))
    if not data or data == "" then
        --Error("Failed to load changes: " .. tostring(data))
        return
    end

    local changes = Ext.Json.Parse(data)
    if not changes or type(changes) ~= "table" then
        Error("Invalid changes format.")
        return
    end

    self.changedLib = changes.Customizations or {}

    for uuid, fields in pairs(self.changedLib) do

        for field, value in pairs(fields) do
            self.searchData[uuid] = self.searchData[uuid] or {}
            if type(self.searchData[uuid][field]) == "table" then
                if type(value) == "table" then
                    for _, v in ipairs(value) do
                        if not table.contains(self.searchData[uuid][field], v) then
                            table.insert(self.searchData[uuid][field], v)
                        end
                    end
                else
                    if not table.contains(self.searchData[uuid][field], value) then
                        table.insert(self.searchData[uuid][field], value)
                    end
                end
            else
                self.searchData[uuid][field] = value
            end
        end

        ::continue::
    end

    if changes.TagHierarchy then
        self.dataManager.tagTree:FromTable((changes.TagHierarchy))
    end
    --Info("Changes loaded successfully.")
end