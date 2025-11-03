--- @class TemplateExportMenu
--- @field ExportDatas table<string, EntityData>
TemplateExportMenu = {}
TemplateExportMenu.__index = TemplateExportMenu

--- @param entDatas table<string, EntityData>
function TemplateExportMenu.new(entDatas)
    local o = {}

    o.ExportDatas = entDatas

    setmetatable(o, TemplateExportMenu)

    o:Render()
end

function TemplateExportMenu:Render()
    local panel = RegisterWindow("generic", "Realm Builder - Template Exporter", "Template Exporter", self)
    panel.Closeable = true

    panel.OnClose = function()
        DeleteWindow(panel)
    end

    local exportSettings = {
        Author = "",
        ModName = "",
        Description = "",
    }

    local topBar = panel:AddTable("Top Bar", 2)
    topBar.ColumnDefs[1] = { WidthStretch = true }
    topBar.ColumnDefs[2] = { WidthFixed = true }
    local topRow = topBar:AddRow()
    local progressCell = topRow:AddCell()
    local exportCell = topRow:AddCell()

    local progressBar = progressCell:AddProgressBar("Export Progress") --[[@as ExtuiProgressBar ]]
    local exportButton = exportCell:AddButton("Export")

    local function isExportable()
        return
            exportSettings.ModName ~= nil and exportSettings.ModName ~= "" and
            exportSettings.Author ~= nil and exportSettings.Author ~= ""
    end

    local exportTT = nil
    exportButton.OnHoverEnter = function(btn)
        if not isExportable() then
            ApplyWarningButtonStyle(btn)
            SetWarningBorder(btn)
            GuiAnim.PulseBorder(btn, 2)
            if exportTT then
                exportTT:Destroy()
                exportTT = nil
            end
            ApplyWarningTooltipStyle(btn:Tooltip())
            exportTT = btn:Tooltip():AddText("Please fill in all required export settings before exporting.")
            return
        end

        ApplyOkButtonStyle(btn)
        ClearWarningBorder(btn)
        if exportTT then
            exportTT:Destroy()
            exportTT = nil
        end
        ApplyOkTooltipStyle(btn:Tooltip())
        exportTT = btn:Tooltip():AddText("Export templates to mod folder.")
    end

    exportButton.OnClick = function(btn)
        if not isExportable() then
            SetWarningBorder(btn)
            GuiAnim.PulseBorder(btn, 2)
            return
        end
        panel.Disabled = true
        self:ExportToMod(exportSettings, function(progress, message)
            if progress < 0 then
                progressBar.Value = 0
                progressBar.Overlay = message
                panel.Disabled = false

                progressBar:SetColor("FrameBg", HexToRGBA("FFFF0000"))
                progressBar:SetColor("Text", HexToRGBA("FFFFFFFF"))

                return
            end
            progressBar.Value = progress/100
            progressBar.Overlay = string.format("%.2f%% - %s", progress, message)
            if progress >= 100 then
                panel.Disabled = false
            end
        end)
    end

    local childWin = panel:AddChildWindow("Export Options")

    self:RenderExportSettings(childWin, exportSettings)

    self:RenderExportEntities(childWin)
end

--- @param panel ExtuiTreeParent
--- @param exportSettings any
function TemplateExportMenu:RenderExportSettings(panel, exportSettings)
    local exportHeader = panel:AddCollapsingHeader("Export Settings")
    local tab = exportHeader:AddTable("Export Settings", 1)
    tab.BordersOuter = true
    local row = tab:AddRow()

    local modName = row:AddCell()
    modName:AddText("Mod Name:")
    local modNameInput = modName:AddInputText("")
    modNameInput.Hint = "Enter mod name ..."
    modNameInput.OnChange = Debounce(50, function(input)
        if not CheckNameValidity(input.Text) then
            SetWarningBorder(input)
            GuiAnim.PulseBorder(input, 2)
            return
        end

        exportSettings.ModName = input.Text
        ClearWarningBorder(input)
    end)
    modNameInput:OnChange()

    local authorCell = row:AddCell()
    authorCell:AddText("Author Name:")
    local authorInput = authorCell:AddInputText("")
    authorInput.Hint = "Enter author name ..."
    authorInput.OnChange = Debounce(50, function(input)
        if input.Text == "" then
            SetWarningBorder(input)
            GuiAnim.PulseBorder(input, 2)
            return
        end
        exportSettings.Author = input.Text
        ClearWarningBorder(input)
    end)
    authorInput:OnChange()

    local descCell = row:AddCell()
    descCell:AddText("Description:")
    local descInput = descCell:AddInputText("")
    descInput.Multiline = true
    descInput.Hint = "Enter mod description ..."
    descInput.OnChange = function(input)
        exportSettings.Description = input.Text
    end

    local versionCell = row:AddCell()
    versionCell:AddText("Version:")
    local versionInput = versionCell:AddInputInt("")
    versionInput.Components = 4
    versionInput.OnChange = function(input)
        local v = input.Value
        exportSettings.Version = { v[1], v[2], v[3], v[4] }
    end
end

function TemplateExportMenu:RenderExportEntities(panel)
    local filtered = {}
    for guid, entData in pairs(self.ExportDatas) do
        local templateType = entData.TemplateType
        filtered[templateType] = filtered[templateType] or {}
        filtered[templateType][guid] = entData
    end

    local allTemplateTypes = {}
    for templateType, ents in pairs(filtered) do
        table.insert(allTemplateTypes, templateType)
    end
    table.sort(allTemplateTypes)

    local exportTable = panel:AddTable("Entities to Export", 1)

    local row = exportTable:AddRow()

    local typeCells = {}

    local function renderTemplateTypes(templateType)
        local cell = typeCells[templateType] --[[@type ExtuiTableCell ]]

        local typeTab = cell.UserData:AddTable(templateType .. " Entities", 1)
        local typeRow = typeTab:AddRow()

        local ents = filtered[templateType]
        for guid, entData in pairs(ents) do
            self:RenderTemplateEntry(typeRow:AddCell(), entData)
        end
    end

    for _, templateType in ipairs(allTemplateTypes) do
        local cell = row:AddCell()
        local templateSelectable = cell:AddTree(string.upper(templateType))
        templateSelectable.OnExpand = function()
            renderTemplateTypes(templateType)
            templateSelectable.OnExpand = nil
        end
        cell.UserData = templateSelectable
        typeCells[templateType] = cell
    end
end

--- @param cell ExtuiTableCell
--- @param entData EntityData
function TemplateExportMenu:RenderTemplateEntry(cell, entData)
    local icon = cell:AddImageButton("##" .. entData.Guid .. "icon", CheckIcon(entData.Icon), IMAGESIZE.SMALL)
    local header = cell:AddTree(entData.DisplayName or "Unnamed")
    local attrTable = header:AddTable("Attributes", 2)
    header.SameLine = true

    icon.OnClick = function()
        SetImguiDisabled(header, not header.Disabled)
        SetAlphaByBool(icon, not header.Disabled)
        header:SetOpen(not header.Disabled)
        attrTable.Visible = not header.Disabled

        if header.Disabled then
            entData.ExcludeFromExport = true    
        else
            entData.ExcludeFromExport = false
        end
    end
    icon:Tooltip():AddText("Click to exclude this entity from export.")

    attrTable.RowBg = true
    attrTable.SizingFixedSame = true
    attrTable.ColumnDefs[1] = { WidthFixed = true }
    attrTable.ColumnDefs[2] = { WidthStretch = true }

    local readonlyAttrs = {
        TemplateType = true,
        Guid = true,
        Icon = true,
        Position = true,
        Rotation = true,
        Scale = true,
    }
    local ignoreAttrs = {
        TemplateType = true,
    }

    local attrOrder = {
        "TemplateType",
        "TemplateId",
        "Guid",
        "DisplayName",
        "LevelName",
        "Icon",
        "Position",
        "Rotation",
        "Scale",
    }

    local allAttrs = {}
    for key, value in pairs(entData) do
        table.insert(allAttrs, key)
    end
    table.sort(allAttrs, function(a, b)
        local aIndex = table.find(attrOrder, a) or (#attrOrder + 1)
        local bIndex = table.find(attrOrder, b) or (#attrOrder + 1)
        return aIndex < bIndex
    end)

    local function renderAttr()
        for _, key in ipairs(allAttrs) do
            if ignoreAttrs[key] then
                goto continue
            end
            local value = entData[key]
            local attrRow = attrTable:AddRow()
            local keyCell = attrRow:AddCell()
            local valueCell = attrRow:AddCell()

            keyCell:AddText(key .. ":")

            local vT = type(value)
            if vT == "boolean" then
                local cB = valueCell:AddCheckbox("##" .. key .. entData.Guid)
                cB.Checked = value
                cB.OnChange = function(cb)
                    entData[key] = cb.Checked
                end
            elseif vT == "number" or vT == "string" then
                local input = valueCell:AddInputText("##" .. key .. entData.Guid)
                input.Text = tostring(value)
                input.ReadOnly = readonlyAttrs[key] or false
                input.OnChange = function(inp)
                    entData[key] = vT == "number" and (tonumber(inp.Text) or 0) or inp.Text
                end
            elseif vT == "table" then
                local vCnt = #value
                local input = valueCell:AddInputScalar("##" .. key .. entData.Guid)
                input.Components = vCnt
                input.Value = ToVec4(value)
                input.ReadOnly = readonlyAttrs[key] or false

                input.OnChange = function(inp)
                    local newValue = {}
                    local v = inp.Value
                    for i = 1, vCnt do
                        newValue[i] = v[i]
                    end
                    entData[key] = newValue
                end
            end
            if key == "DisplayName" then
                local useCustomNameCB = keyCell:AddCheckbox("##" .. entData.Guid .. "_useCustomName")
                useCustomNameCB.SameLine = true
                useCustomNameCB:Tooltip():AddText(
                    "Use custom display name for this entity when exported.\n If unchecked, the default name from the template will be used.")
                useCustomNameCB.OnChange = function(cb)
                    if not cb.Checked then
                        entData.UseCustomName = false
                    else
                        entData.UseCustomName = true
                    end
                end
            elseif key == "Gravity" then
                local disableUntilMovedCB = valueCell:AddCheckbox("##" .. entData.Guid .. "_disableUntilMoved")
                disableUntilMovedCB.SameLine = true
                disableUntilMovedCB:Tooltip():AddText(
                    "Disable gravity until the entity is moved by the player.")
                disableUntilMovedCB.OnChange = function(cb)
                    if not cb.Checked then
                        entData.DisableGravityUntilMoved = false
                    else
                        entData.DisableGravityUntilMoved = true
                    end
                end
            end

            ::continue::
        end
    end

    header.OnExpand = function()
        renderAttr()
        header.OnExpand = nil
    end
end

function TemplateExportMenu:ExportToMod(exportSettings, progressCallback)
    local co = coroutine.create(function()
        self:__export(exportSettings, progressCallback)
    end)

    local suc, msg = coroutine.resume(co)
    if not suc then
        Error("Export failed: " .. tostring(msg))
    end
end

---@param exportSettings any
---@param progressCallback fun(progress:number, message:string)
function TemplateExportMenu:__export(exportSettings, progressCallback)
    local thread = coroutine.running()
    local startTime = Ext.Timer.MonotonicTime()
    local toExport = {}
    for guid, entData in pairs(self.ExportDatas) do
        if not entData.ExcludeFromExport then
            toExport[guid] = entData
        end
    end
    local exportCnt = CountMap(toExport)

    local actCnt =
        1 +         -- build meta.lsx
        1 +         -- build localizaion
        exportCnt -- export templates

    progressCallback = progressCallback or function(num, msg)
        Debug(string.format("Export Progress: %.2f%% - %s", num, msg))
    end

    local progressStep = 100 / actCnt
    local currentProgress = 0
    local lastYieldTime = Ext.Timer.MonotonicTime()
    local yieldInterval = 5 -- ms
    local suc = true

    local function throwError(message)
        if progressCallback then
            progressCallback(-1, message)
        end
        Error(message)
        coroutine.yield()
    end

    local function yield()
        if Ext.Timer.MonotonicTime() - lastYieldTime < yieldInterval then return end
        Timer:Ticks(5, function(timerID)
            local suc, msg = coroutine.resume(thread)
            if not suc then
                throwError(msg)
            end
        end)
        coroutine.yield()
    end

    local function advance(message)
        currentProgress = currentProgress + progressStep
        if progressCallback then
            progressCallback(currentProgress, message)
        end
        yield()
    end
    
    local modInternalName = exportSettings.ModName:gsub("%s+", "_"):upper()
    local modUuid = nil
    local modCache = RealmPaths.GetMapModCachePath()
    local file = Ext.IO.LoadFile(modCache)
    if file then
        modUuid = Ext.Json.Parse(file)[modInternalName]
    end

    if not modUuid then
        modUuid = Uuid_v4()
        local modCacheData = {}
        if file then
            modCacheData = Ext.Json.Parse(file)
        end
        modCacheData[modInternalName] = modUuid
        suc = Ext.IO.SaveFile(modCache, Ext.Json.Stringify(modCacheData))
        if not suc then
            throwError("Failed to save mod cache file at " .. modCache)
        end
    end

    -- export mod meta.lsx

    local modMetaNode = LSXHelpers.BuildModMeta(exportSettings.Uuid or Uuid_v4(), exportSettings.ModName, modInternalName,
        exportSettings.Author, exportSettings.Version, exportSettings.Description)

    local modMetaPath = RealmPaths.GetMapModMetaPath(modInternalName)
    suc = Ext.IO.SaveFile(modMetaPath, modMetaNode:Stringify({ AutoFindRoot = true }))
    if not suc then throwError("Failed to save mod meta file at " .. modMetaPath) end
    advance("Building mod meta...")

    -- export localization
    local needNames = {}
    local nameToGuids = {}
    local guidToHandle = {}
    for guid, entData in pairs(toExport) do
        if entData.UseCustomName then
            table.insert(needNames, entData.DisplayName)
            nameToGuids[entData.DisplayName] = nameToGuids[entData.DisplayName] or {}
            table.insert(nameToGuids[entData.DisplayName], guid)
        end
    end

    if #needNames < 1 then
        advance("No localization needed.")
    else
        local locFile, stringToHandles = LSXHelpers.GenerateLocalization(needNames, 1)

        local locPath = RealmPaths.GetMapModLocalizationPath(modInternalName, "English")
        suc = Ext.IO.SaveFile(locPath, locFile)
        if not suc then throwError("Failed to save localization file at " .. locPath) end

        for name, guids in pairs(nameToGuids) do
            local handle = table.remove(stringToHandles[name])
            local guid = table.remove(guids)
            guidToHandle[guid] = handle
        end
        advance("Building localization...")
    end
    
    -- export templates
    local templateNameCnt = {}
    local function padNumber(num, size)
        local s = tostring(num)
        return string.format("%0" .. size .. "d", tonumber(s))
    end
    for guid, entData in pairs(toExport) do
        local templateName = TrimTail(entData.TemplateId, 37)
        templateNameCnt[templateName] = (templateNameCnt[templateName] or 0) + 1

        local levelName = entData.LevelName
        if not levelName then
            throwError("Entity " .. guid .. " is missing LevelName attribute.")
        end

        local templateInternalName = modInternalName ..
            "_" .. templateName .. "_" .. padNumber(templateNameCnt[templateName], 3)
        local templatePath = RealmPaths.GetTemplatePath(modInternalName, levelName, guid, entData.TemplateType)
        if not templatePath then
            throwError("Failed to get template path for entity " .. guid)
            return 
        end

        local templateNode = LSXHelpers.BuildTemplate(guid, entData, templateInternalName, guidToHandle[guid])
        if not templateNode then
            throwError("Failed to build template for entity " .. guid)
            return 
        end

        suc = Ext.IO.SaveFile(templatePath, templateNode:Stringify({ AutoFindRoot = true }))
        if not suc then
            throwError("Failed to save template file at " .. templatePath)
        end

        advance("Exporting template " .. entData.DisplayName .. "...")
    end

    if progressCallback then
        progressCallback(100, "Export complete.")
    end

    Debug("Template export completed in " .. tostring(Ext.Timer.MonotonicTime() - startTime) .. " ms.")
end
