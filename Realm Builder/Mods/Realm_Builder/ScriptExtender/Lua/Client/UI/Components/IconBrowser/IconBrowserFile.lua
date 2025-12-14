function IconBrowser:SaveTagHierarchy()
    if not self.dataManager.tagTree then
        Error("No tag hierarchy to save.")
        return
    end

    local treeData = self.dataManager.tagTree:ToTable()

    self:SaveToFile("TagHierarchy", treeData)
end

function IconBrowser:SaveChanges()
    local data = self.dataManager:ExportCustomizations()

    if not data or type(data) ~= "table" then
        Error("No changes to save.")
        return
    end

    self:SaveToFile("Customizations", data)
end

function IconBrowser:LoadChanges()
    local data = Ext.IO.LoadFile(FilePath.GetBrowserSettingPath(self.displayName))
    if not data or data == "" then
        --Error("Failed to load changes: " .. tostring(data))
        return
    end

    local changes = Ext.Json.Parse(data)
    if not changes or type(changes) ~= "table" then
        Error("Invalid changes format.")
        return
    end

    if changes.Settings then
        local settings = changes.Settings
        self.lastPosition = settings.LastPosition or self.lastPosition
        self.lastSize = settings.LastSize or self.lastSize
        self.iconWidth = settings.IconWidth or self.iconWidth
        self.iconPR = settings.IconPerRow or self.iconPR
        self.iconPC = settings.IconPerColumn or self.iconPC
        self.cellsPadding = settings.CellsPadding or self.cellsPadding
        self.AutoSave = settings.AutoSave or self.AutoSave
        self.iconButtonBgColor = settings.ButtonBgColor or self.iconButtonBgColor
        self.browserBackgroundColor = settings.BackgroundColor or self.browserBackgroundColor
    end

    if changes.Customizations then
        self.dataManager:ImportCustomizations(changes.Customizations)
    end

    if changes.TagHierarchy then
        self.dataManager.tagTree:FromTable(changes.TagHierarchy)
    end
end

function IconBrowser:SaveToConfig()
    self.lastPosition = self.panel.LastPosition
    self.lastSize = self.panel.LastSize
    local setting = {}
    setting.IconWidth = self.iconWidth
    setting.IconPerRow = self.iconPR
    setting.IconPerColumn = self.iconPC
    setting.CellsPadding = self.cellsPadding
    setting.AutoSave = self.AutoSave
    setting.ButtonBgColor = self.iconButtonBgColor
    setting.LastPosition = self.lastPosition
    setting.LastSize = self.lastSize
    self:SaveToFile("Settings", setting)
end

function IconBrowser:SaveToFile(field, content)
    local filePath = FilePath.GetBrowserSettingPath(self.displayName)

    local fileContent = Ext.IO.LoadFile(filePath)
    if not fileContent or fileContent == "" then
        fileContent = "{}"
    end

    local parsed = Ext.Json.Parse(fileContent)
    if not parsed then
        Warning("Failed to parse existing browser settings file. Overwriting.")
        parsed = {}
    end

    parsed[field] = content

    local ok = Ext.IO.SaveFile(filePath, Ext.Json.Stringify(parsed))
    if not ok then
        Error("Failed to save browser settings to file: " .. tostring(filePath))
    end

    return ok
end