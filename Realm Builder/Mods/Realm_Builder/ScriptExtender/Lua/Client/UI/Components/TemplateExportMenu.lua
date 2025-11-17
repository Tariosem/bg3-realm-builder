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
        Version = { 1, 0, 0, 0 },
    }

    local topBar = panel:AddTable("Top Bar", 2)
    topBar.ColumnDefs[1] = { WidthStretch = true }
    topBar.ColumnDefs[2] = { WidthFixed = true }
    local topRow = topBar:AddRow()
    local progressCell = topRow:AddCell()
    local exportCell = topRow:AddCell()

    local progressBar = progressCell:AddProgressBar("Export Progress") --[[@as ExtuiProgressBar ]]
    StyleHelpers.SetNormalProgressBarStyle(progressBar)
    local exportButton = exportCell:AddButton("Export")

    local childWin = panel:AddChildWindow("Export Options")
    local refreshExportPanel = RenderExportSettingPanel(childWin:AddCollapsingHeader("Export Setting"), exportSettings)

    local function isExportable()
        refreshExportPanel()
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
        StyleHelpers.SetNormalProgressBarStyle(progressBar)
        self:ExportToMod(exportSettings, function(progress, message)
            if progress < 0 then
                progressBar.Value = 0
                progressBar.Overlay = message
                panel.Disabled = false

                StyleHelpers.SetWarningProgressBarStyle(progressBar)

                return
            end
            progressBar.Value = progress / 100
            progressBar.Overlay = string.format("%.2f%% - %s", progress, message)
            if progress >= 100 then
                panel.Disabled = false
            end
        end)
    end

    self:RenderExportEntities(childWin)
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
        for guid, entData in SortedPairs(ents, function(a, b)
            local nameA = ents[a].DisplayName or ents[a].TemplateId
            local nameB = ents[b].DisplayName or ents[b].TemplateId
            return nameA < nameB
        end) do
            local treeChild = self:RenderTemplateEntry(typeRow:AddCell(), entData)
            cell.UserData:AddChild(treeChild)
        end
    end

    for _, templateType in ipairs(allTemplateTypes) do
        local cell = row:AddCell()
        local templateSelectable = StyleHelpers.AddTree(cell, string.upper(templateType))
        templateSelectable.OnExpand = function()
            renderTemplateTypes(templateType)
            templateSelectable.OnExpand = function () end
        end
        cell.UserData = templateSelectable
        typeCells[templateType] = cell
    end
end

--- @param cell ExtuiTableCell
--- @param entData EntityData
function TemplateExportMenu:RenderTemplateEntry(cell, entData)
    local templateObj = Ext.Template.GetTemplate(entData.TemplateId)
    local icon = cell:AddImageButton("##" .. entData.Guid .. "icon", entData.DisplayIcon, IMAGESIZE.SMALL)
    local header = StyleHelpers.AddTree(cell, entData.DisplayName or templateObj.Name or entData.TemplateId)
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
    }
    local ignoreAttrs = {
        TemplateType = true,
        OriginalVisualUuid = true,
        OverrideVisualParameters = true,
        OverrideVisualUuid = true,
        VisualObjectMaterialOverride = true,
        ExcludeFromExport = true,
        DisplayIcon = true,
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
                    "Disable gravity until the entity is moved.")
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

        if entData.TemplateType == "character" then
            local wanderConfigRow = attrTable:AddRow()
            local wanderConfigCell = wanderConfigRow:AddCell():AddText("Wander Config:")
            local wanderConfigValueCell = wanderConfigRow:AddCell()

            local cached = {
                Extents = entData.WanderConfig and entData.WanderConfig.Extents or {10, 5, 10},
                WanderMin = entData.WanderConfig and entData.WanderConfig.WanderMin or 5,
                WanderMax = entData.WanderConfig and entData.WanderConfig.WanderMax or 10,
                SleepMin = entData.WanderConfig and entData.WanderConfig.SleepMin or 2,
                SleepMax = entData.WanderConfig and entData.WanderConfig.SleepMax or 5,
            }
            local editWanderButton = wanderConfigValueCell:AddCheckbox("Enable Wandering")
            local visualizeBtn = wanderConfigValueCell:AddButton("Visualize Wander Area")
            local configTab = wanderConfigValueCell:AddTable("Wander Config Table", 2)
            configTab.Borders = true
            configTab.RowBg = true
            configTab.Visible = entData.WanderConfig ~= nil
            configTab.ColumnDefs[1] = { WidthFixed = true }
            configTab.ColumnDefs[2] = { WidthStretch = true }
            configTab.SizingFixedSame = true

            editWanderButton.OnChange = function(sel)
                if not sel.Checked then
                    entData.WanderConfig = nil
                    configTab.Visible = false
                    visualizeBtn.Visible = false
                else
                    entData.WanderConfig = cached
                    configTab.Visible = true
                    visualizeBtn.Visible = true
                end
            end
            editWanderButton:OnChange()

            visualizeBtn.SameLine = true
            visualizeBtn.OnClick = function()
                local pos = Vec3.new(entData.Position)
                local extents = Vec3.new(cached.Extents)
                local min = pos - extents
                local max = pos + extents

                NetChannel.Visualize:RequestToServer({
                    Type = "OBB",
                    Position = pos,
                    Rotation = entData.Rotation,
                    HalfSizes = extents,
                    Duration = 5000,
                }, function (response)
                    
                end)
            end

            for attrName, defaultValue in SortedPairs(cached) do
                local attRow = configTab:AddRow()
                local attrKeyCell = attRow:AddCell()
                local attrValueCell = attRow:AddCell()

                attrKeyCell:AddText(attrName .. ":")

                if type(defaultValue) == "table" then
                    local slider = attrValueCell:AddSlider("##" .. attrName .. entData.Guid)
                    slider.Components = #defaultValue
                    slider.Value = ToVec4(defaultValue)
                    slider.OnChange = function(sld)
                        local newValue = {}
                        local v = sld.Value
                        for i = 1, #defaultValue do
                            newValue[i] = v[i]
                        end
                        cached[attrName] = newValue
                    end
                    local resetBtn = attrValueCell:AddButton("Reset")
                    resetBtn.SameLine = true
                    resetBtn.OnClick = function()
                        slider.Value = ToVec4(defaultValue)
                        cached[attrName] = defaultValue
                    end
                else
                    local slider = StyleHelpers.AddSliderWithStep(attrValueCell, "##" .. attrName .. entData.Guid, defaultValue, 0, 120, 1)
                    slider.OnChange = function(sld)
                        cached[attrName] = sld.Value[1]
                    end
                end
            end
        end
    end

    header.OnExpand = function()
        renderAttr()
        header.OnExpand = function() end
    end

    return header
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
    local customVisualCnt = 0
    local toExport = {} --[[@type table<string, EntityData> ]]
    local toBuildCustomVisuals = {} --[[@type table<string, EntityData> ]]
    for guid, entData in pairs(self.ExportDatas) do
        if not entData.ExcludeFromExport then
            toExport[guid] = entData
            if entData.UseCustomVisualParameters then
                customVisualCnt = customVisualCnt + 1
                toBuildCustomVisuals[guid] = entData
            end
        end
    end
    local exportCnt = CountMap(toExport)

    local actCnt =
        1 +               -- build meta.lsx
        1 +               -- build localizaion
        customVisualCnt + -- export custom visuals
        exportCnt         -- export templates

    progressCallback = progressCallback or function(num, msg)
        Debug(string.format("Export Progress: %.2f%% - %s", num, msg))
    end

    local progressStep = 100 / actCnt
    local currentProgress = 0
    local lastYieldTime = Ext.Timer.MonotonicTime()
    local yieldInterval = 5 -- ms
    local suc = true

    local function throwError(message)
        Ext.OnNextTick(function ()
    
            progressCallback(-1, message)
        end)
        Error(message)
        coroutine.yield()
    end

    local function yield()
        if Ext.Timer.MonotonicTime() - lastYieldTime < yieldInterval then return end
        Ext.OnNextTick(function()
            local msg
            suc, msg = coroutine.resume(thread)
            if not suc then
                progressCallback(-1, "Export failed: " .. tostring(msg))
                Error("Export failed: " .. tostring(msg))
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

    local function saveFile(path, content)
        suc = Ext.IO.SaveFile(path, content)
        if not suc then
            throwError("Failed to save file at " .. path)
        end
        yield()
    end

    local modInternalName = ValidateFolderName(exportSettings.ModName)
    local modUuid = nil
    local modCache = RealmPath.GetMapModCachePath()
    local file = Ext.IO.LoadFile(modCache)
    local modCachedUuids = Ext.Json.Parse(file or "{}")
    modUuid = modCachedUuids[modInternalName]

    if not modUuid then
        modUuid = Uuid_v4()
        modCachedUuids[modInternalName] = modUuid
        suc = Ext.IO.SaveFile(modCache, Ext.Json.Stringify(modCachedUuids))
        if not suc then
            throwError("Failed to save mod cache file at " .. modCache)
        end
    end

    -- export mod meta.lsx
    local modMetaNode = LSXHelpers.BuildModMeta(modUuid, exportSettings.ModName, modInternalName,
        exportSettings.Author, exportSettings.Version, exportSettings.Description)

    local modMetaPath = RealmPath.GetMapModMetaPath(modInternalName)
    saveFile(modMetaPath, modMetaNode:Stringify({ AutoFindRoot = true }))
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

        local locPath = RealmPath.GetMapModLocalizationPath(modInternalName, "English")
        saveFile(locPath, locFile)

        for name, guids in pairs(nameToGuids) do
            local handle = table.remove(stringToHandles[name])
            local guid = table.remove(guids)
            guidToHandle[guid] = handle
        end
        advance("Building localization...")
    end

    -- export custom visuals

    local intenalNameMap = {}
    local templateNameCnt = {}

    for guid, entData in pairs(toExport) do
        local baseName = TrimTail(entData.TemplateId, 37)
        templateNameCnt[baseName] = (templateNameCnt[baseName] or 0) + 1
        intenalNameMap[guid] = modInternalName .. "_" .. baseName .. "_" .. PadNumber(templateNameCnt[baseName], 3) 
    end

    for guid, entData in pairs(toBuildCustomVisuals) do
        local overrideVisualID = Uuid_v4()
        local internalName = intenalNameMap[guid]
        if entData.TemplateType == "character" then
            local presetUuid = Uuid_v4()
            local presetInternalName = internalName .. "_CharacterPreset_" .. presetUuid

            --- build preset resource
            local presetBank = LSXHelpers.BuildMaterialPresetBank()
            local presetNode = ResourceHelpers.BuildMaterialPresetResourceNode(entData.OverrideVisualParameters,
                presetUuid, presetInternalName)
            presetBank:AppendChild(presetNode)
            local presetPath = RealmPath.GetCharacterPresetPath(modInternalName, presetUuid)
            saveFile(presetPath, presetNode:Stringify({ AutoFindRoot = true }))

            --- build visual resource
            local visualInternalName = internalName .. "_CharacterVisual_" .. overrideVisualID
            local bank = LSXHelpers.BuildCharacterVisualBank()
            local visualNode = ResourceHelpers.BuildCharacterVisualResource(entData.OriginalVisualUuid,
                overrideVisualID, visualInternalName, { [""] = presetUuid })
            bank:AppendChild(visualNode)
            local visualPath = RealmPath.GetCharacterVisualPath(modInternalName, overrideVisualID)
            saveFile(visualPath, bank:Stringify({ AutoFindRoot = true }))

            entData.OverrideVisualUuid = overrideVisualID
        elseif entData.TemplateType == "item" or entData.TemplateType == "scenery" then
            local matOverrideMap = {}

            --- build material resource we need
            for oriMat, overrideParams in pairs(entData.VisualObjectMaterialOverride or {}) do
                local overrideMat = Uuid_v4()
                matOverrideMap[oriMat] = overrideMat
                local matInternalName = internalName .. "_MatOverride_" .. overrideMat
                local matBank = LSXHelpers.BuildMaterialBank()
                local matResource = ResourceHelpers.BuildMaterialResource(oriMat, overrideMat, overrideParams,
                    matInternalName)
                matBank:AppendChild(matResource)
                if not matResource then
                    throwError("Failed to build item material override resource for original material " .. oriMat)
                    return
                end

                local matPath = RealmPath.GetItemPresetPath(modInternalName, overrideMat)
                saveFile(matPath, matBank:Stringify({ AutoFindRoot = true }))
            end

            --- build visual resource
            local visualInternalName = internalName .. "_ItemVisual_" .. overrideVisualID
            local visualBank = LSXHelpers.BuildVisualBank()
            local visual = ResourceHelpers.BuildVisualResource(entData.OriginalVisualUuid, overrideVisualID,
                visualInternalName, matOverrideMap)
            visualBank:AppendChild(visual)
            local visualPath = RealmPath.GetItemVisualPath(modInternalName, overrideVisualID)
            saveFile(visualPath, visualBank:Stringify({ AutoFindRoot = true }))

            --- build root template with visual override
            local overrideTemplateID = Uuid_v4()
            local overrideTemplateInternalName = internalName .. "_VisualTemplate"
            local rootTemplate = LSXHelpers.BuildRootTemplate(entData.TemplateId, overrideTemplateID,
                overrideTemplateInternalName, { VisualTemplate = overrideVisualID })

            local overrideTemplatePath = RealmPath.GetRootTemplatePath(modInternalName, overrideTemplateID)
            --- @diagnostic disable-next-line
            saveFile(overrideTemplatePath, rootTemplate:Stringify({ AutoFindRoot = true }))

            --- set override template id
            entData.TemplateId = overrideTemplateInternalName .. "_" .. overrideTemplateID
        end
        entData.OverrideVisualUuid = overrideVisualID
        advance("Exporting custom visual for " .. entData.DisplayName .. "...")
    end

    -- export templates
    
    for guid, entData in pairs(toExport) do
        local levelName = entData.LevelName

        local templateInternalName = intenalNameMap[guid]
        local templatePath = RealmPath.GetTemplatePath(modInternalName, levelName, guid, entData.TemplateType)
        if not templatePath then
            throwError("Failed to get template path for entity " .. guid)
            return
        end

        local templateNode, others = LSXHelpers.BuildTemplate(guid, entData, templateInternalName, guidToHandle[guid])
        if not templateNode then
            throwError("Failed to build template for entity " .. guid)
            return
        end

        saveFile(templatePath, templateNode:Stringify({ AutoFindRoot = true }))

        for _, other in ipairs(others or {}) do
            local otherPath = RealmPath.GetTemplatePath(modInternalName, levelName, other.Uuid, other.TemplateType)
            saveFile(otherPath, other.LSXNode:Stringify({ AutoFindRoot = true }))
        end

        advance("Exporting template " .. entData.DisplayName .. "...")
    end

    if progressCallback then
        progressCallback(100, "Export complete.")
    end

    Debug("Template export completed in " .. tostring(Ext.Timer.MonotonicTime() - startTime) .. " ms.")
end
