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
    local data = self.dataManager:ExportCustomizations()

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

    if changes.Customizations then
        self.dataManager:ImportCustomizations(changes.Customizations)
    end

    if changes.TagHierarchy then
        self.dataManager.tagTree:FromTable((changes.TagHierarchy))
    end
    --Info("Changes loaded successfully.")
end