--- @class TemplateExportMenu
--- @field ExportDatas table<string, EntityData>
TemplateExportMenu = {}
TemplateExportMenu.__index = TemplateExportMenu

--- @class RB_MapMod_Pack   
--- @field Author string
--- @field ModName string
--- @field Description string
--- @field Version number[]

--- @param entDatas table<string, EntityData>
function TemplateExportMenu.new(entDatas)
    local o = {}

    o.ExportDatas = entDatas
    o.isValid = true

    setmetatable(o, TemplateExportMenu)

    o:Render()
end

function TemplateExportMenu:Render()
    local panel = WindowManager.RegisterWindow("generic", "Realm Builder - Template Exporter", "Template Exporter", self)
    panel.Closeable = true

    panel.OnClose = function()
        self.isValid = false
        WindowManager.DeleteWindow(panel)
    end

    local exportSettings = {
        Author = "",
        ModName = "",
        Description = "",
        Version = { 1, 0, 0, 0 },
        Entities = self.ExportDatas,
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
    local refreshExportPanel = ImguiElements.RenderExportSettingPanel(childWin:AddCollapsingHeader("Export Setting"), exportSettings)

    local function isExportable()
        refreshExportPanel()
        return
            exportSettings.ModName ~= nil and exportSettings.ModName ~= "" and
            exportSettings.Author ~= nil and exportSettings.Author ~= ""
    end

    local exportTT = nil
    exportButton.OnHoverEnter = function(btn)
        if not isExportable() then
            StyleHelpers.ApplyWarningButtonStyle(btn)
            StyleHelpers.SetWarningBorder(btn)
            GuiAnim.PulseBorder(btn, 2)
            if exportTT then
                exportTT:Destroy()
                exportTT = nil
            end
            StyleHelpers.ApplyWarningTooltipStyle(btn:Tooltip())
            exportTT = btn:Tooltip():AddText("Please fill in all required export settings before exporting.")
            return
        end

        StyleHelpers.ApplyOkButtonStyle(btn)
        StyleHelpers.ClearWarningBorder(btn)
        if exportTT then
            exportTT:Destroy()
            exportTT = nil
        end
        StyleHelpers.ApplyOkTooltipStyle(btn:Tooltip())
        exportTT = btn:Tooltip():AddText("Export templates to mod folder.")
    end

    exportButton.OnClick = function(btn)
        if not isExportable() then
            StyleHelpers.SetWarningBorder(btn)
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

    panel:AddDummy(150,1)
    local visualizeAllBtn = panel:AddButton("Visualize All Export Entries") --[[@as ExtuiButton ]]
    visualizeAllBtn.SameLine = true
    visualizeAllBtn.Size = {-150, 0}

    visualizeAllBtn.OnClick = function()
        local thread = nil
        local function spawnFunc()
            for guid, entry in pairs(self.ExportDatas) do
                self:VisualizeExportEntry(guid, -1)
                local templateObj = Ext.Template.GetTemplate(EntityHelpers.TakeTailTemplate(entry.TemplateId))
                if templateObj.TemplateType == "scenery" then
                    Timer:Ticks(30, function (timerID)
                        if not thread then return end
                        local ok, msg = coroutine.resume(thread)
                        if not ok then
                            Error("Failed to visualize all export entries: " .. tostring(msg))
                        end
                    end)
                    coroutine.yield()
                end
            end
            Timer:After(5000, function (timerID)
                self:ClearVisualizations()
            end)
            if not self.isValid then return end
            ImguiHelpers.SetImguiDisabled(visualizeAllBtn, false)
        end

        thread = coroutine.create(spawnFunc)
        ImguiHelpers.SetImguiDisabled(visualizeAllBtn, true)
        local suc, msg = coroutine.resume(thread)
        if not suc then
            ImguiHelpers.SetImguiDisabled(visualizeAllBtn, false)
            Error("Failed to visualize all export entries: " .. tostring(msg))
        end
    end

    local exportTable = panel:AddTable("Entities to Export", 1)

    local row = exportTable:AddRow()

    --- @type table<string, { UserData: RB_UI_Tree }>
    local typeCells = {}

    local function renderTemplateTypes(templateType)
        local cell = typeCells[templateType] --[[@type ExtuiTableCell ]]

        local typeTab = cell.UserData:AddTable(templateType .. " Entities", 1)
        local typeRow = typeTab:AddRow()

        local ents = filtered[templateType]
        for guid, entData in RBUtils.SortedPairs(ents, function(a, b)
            local nameA = ents[a].DisplayName or ents[a].TemplateId
            local nameB = ents[b].DisplayName or ents[b].TemplateId
            return nameA < nameB
        end) do
            local treeChild = self:RenderTemplateEntry(typeRow:AddCell(), entData)
            if treeChild then
                cell.UserData:AddChild(treeChild)
            end
        end
    end

    for _, templateType in ipairs(allTemplateTypes) do
        local cell = row:AddCell()
        local templateSelectable = ImguiElements.AddTree(cell, string.upper(templateType))
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
    local templateObj = Ext.Template.GetTemplate(EntityHelpers.TakeTailTemplate(entData.TemplateId))
    if not templateObj then
        Warning("[TemplateExportMenu] Failed to get template object for template ID: " .. tostring(entData.TemplateId))
        return nil
    end
    local header = ImguiElements.AddTree(cell, entData.DisplayName or templateObj.Name or entData.TemplateId)
    header:AddTreeIcon(entData.DisplayIcon, IMAGESIZE.SMALL)
    local attrTable = header:AddTable("Attributes", 2)
    header.SameLine = true

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
        Level = true,
    }

    local sceneryAttrs = {
        AllowCameraMovement = true,
        WalkOn = true,
        WalkThrough = true,
        CanClimbOn = true,
        CanShootThrough = true,
        CanSeeThrough = true,
        IsBlocker = true,
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
                input.Value = RBUtils.ToVec4(value)
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

        if entData.TemplateType == 'scenery' then
            for k, v in pairs(sceneryAttrs) do
                local attrRow = attrTable:AddRow()
                local keyCell = attrRow:AddCell()
                local valueCell = attrRow:AddCell()

                keyCell:AddText(k .. ":")

                local cB = valueCell:AddCheckbox("##" .. k .. entData.Guid)
                cB.Checked = entData[k] or false
                cB.OnChange = function(cb)
                    entData[k] = cb.Checked
                end
            end
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

            for attrName, defaultValue in RBUtils.SortedPairs(cached) do
                local attRow = configTab:AddRow()
                local attrKeyCell = attRow:AddCell()
                local attrValueCell = attRow:AddCell()

                attrKeyCell:AddText(attrName .. ":")

                if type(defaultValue) == "table" then
                    local slider = attrValueCell:AddSlider("##" .. attrName .. entData.Guid)
                    slider.Components = #defaultValue
                    slider.Value = RBUtils.ToVec4(defaultValue)
                    slider.Max = {10, 10, 10, 10}
                    slider.Min = {0, 0, 0, 0}
                    slider.OnChange = function(sld)
                        local newValue = {}
                        local v = sld.Value
                        for i = 1, #defaultValue do
                            newValue[i] = v[i]
                        end
                        cached[attrName] = newValue
                    end
                    local resetBtn = ImguiElements.AddResetButton(attrValueCell, true)
                    resetBtn.OnClick = function()
                        slider.Value = RBUtils.ToVec4(defaultValue)
                        cached[attrName] = defaultValue
                    end
                else
                    local slider = ImguiElements.AddSliderWithStep(attrValueCell, "##" .. attrName .. entData.Guid, defaultValue, 0, 120, 1)
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
    header.OnClick = function()
        header.Selected = false
        self:VisualizeExportEntry(entData.Guid)
    end
    header.OnRightClick = function()
        ImguiHelpers.SetImguiDisabled(header, not header.Disabled)
        header:SetOpen(not header.Disabled)
        attrTable.Visible = not header.Disabled

        if header.Disabled then
            entData.ExcludeFromExport = true
        else
            entData.ExcludeFromExport = false
        end
    end

    return header
end

function TemplateExportMenu:VisualizeExportEntry(uuid, duration)
    local entry = self.ExportDatas[uuid]
    if not entry then
        Warning("[TemplateExportMenu] Failed to find export entry for UUID: " .. tostring(uuid))
        return
    end

    local vec3Scale = {1, 1, 1}
    if type(entry.Scale) == "table" then
        vec3Scale = entry.Scale
    else
        vec3Scale = {entry.Scale, entry.Scale, entry.Scale}
    end
    
    NetChannel.Spawn:RequestToServer({
        TemplateId = entry.TemplateId,
        EntInfo = {
            Position = entry.Position,
            Rotation = entry.Rotation,
            Scale = vec3Scale
        },
        Duration = duration,
        Type = 'Preview'
    }, function (response)
        if not response.Guid then
            Warning("[TemplateExportMenu] Failed to spawn preview entity for template ID: " .. tostring(entry.TemplateId))
            return
        end
        if duration and duration < 0 then
            self.visualizations = self.visualizations or {}
            table.insert(self.visualizations, response.Guid)
        end
    end)
end

function TemplateExportMenu:ClearVisualizations()
    NetChannel.Delete:SendToServer({
        Guid = self.visualizations
    })
end

local function throwExportError(message, exportSettings, progressCallback, co)
    local stack = co and debug.traceback(co, message) or debug.traceback(message)
    Error(stack)
    progressCallback(-1, message)
    local time = RBUtils.GetFormatTime()
    local suc = Ext.IO.SaveFile(FilePath.GetMapModLogPath(time),
        Ext.Json.Stringify({
            Time = Ext.Timer.ClockTime(),
            Message = message,
            ModPack = exportSettings,
            Stack = stack,
        }, { Beautify = true, StringifyInternalTypes = true }))
    if not suc then
        Warning("Failed to save export error log file at " .. FilePath.GetMapModLogPath(time))
    end
end

function TemplateExportMenu:ExportToMod(exportSettings, progressCallback)
    local co = coroutine.create(function()
        self:__export(exportSettings, progressCallback)
    end)

    local suc, msg = coroutine.resume(co)
    if not suc then
        throwExportError("Export failed: " .. tostring(msg), exportSettings, progressCallback, co)
    end
end

---@param exportSettings table<string, any>
---@param progressCallback fun(progress:number, message:string)
function TemplateExportMenu:__export(exportSettings, progressCallback)
    local thread = coroutine.running()
    local startTime = Ext.Timer.MonotonicTime()
    local customVisualCnt = 0
    local toExport = {} --[[@type table<string, EntityData> ]]
    local toBuildCustomVisuals = {} --[[@type table<string, EntityData> ]]

    local function isValidTemplateId(templateId)
        return templateId and templateId ~= "" and Ext.Template.GetTemplate(EntityHelpers.TakeTailTemplate(templateId)) ~= nil
    end

    for guid, entData in pairs(exportSettings.Entities) do
        if not entData.ExcludeFromExport and isValidTemplateId(entData.TemplateId) then
            toExport[guid] = entData
            if entData.UseCustomVisualParameters then
                customVisualCnt = customVisualCnt + 1
                toBuildCustomVisuals[guid] = entData
            end
        end
    end

    local exportCnt = RBTableUtils.CountMap(toExport)

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
    local lastYieldTime = Ext.Timer.MicrosecTime()
    local yieldInterval = 1 -- ms
    local suc = true

    local function throwError(message)
        Error(debug.traceback(message))
        throwExportError(message, exportSettings, progressCallback)
    end

    local function yield()
        if Ext.Timer.MicrosecTime() - lastYieldTime < yieldInterval then return end
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
            return
        end
        yield()
    end

    local modInternalName = RBUtils.ValidateFolderName(exportSettings.ModName)
    local modUuid = nil
    local modCache = FilePath.GetMapModCachePath()
    local file = Ext.IO.LoadFile(modCache)
    local modCachedUuids = Ext.Json.Parse(file or "{}")
    modUuid = modCachedUuids[modInternalName]

    if not modUuid then
        modUuid = RBUtils.Uuid_v4()
        modCachedUuids[modInternalName] = modUuid
        suc = Ext.IO.SaveFile(modCache, Ext.Json.Stringify(modCachedUuids))
        if not suc then
            throwError("Failed to save mod cache file at " .. modCache)
            return
        end
    end

    -- export mod meta.lsx
    local modMetaNode = LSXHelpers.BuildModMeta(modUuid, exportSettings.ModName, modInternalName,
        exportSettings.Author, exportSettings.Version, exportSettings.Description)

    local modMetaPath = FilePath.GetMapModMetaPath(modInternalName)
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

        local locPath = FilePath.GetMapModLocalizationPath(modInternalName, "English")
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
        local templateObj = Ext.Template.GetTemplate(EntityHelpers.TakeTailTemplate(entData.TemplateId))
        local baseName = templateObj.Name or "Template"
        templateNameCnt[baseName] = (templateNameCnt[baseName] or 0) + 1
        intenalNameMap[guid] = modInternalName .. "_" .. baseName .. "_" .. RBStringUtils.PadNumber(templateNameCnt[baseName], 3) 
    end

    --- map of original material id -> generated material id -> param set
    local matIdToParams = {} --[[@type table<string, table<string, RB_ParameterSet>> ]]
    local templateToVisual = {} -- origin template -> generated rootTemplateId ->  linkId -> materialId
    for guid, entData in pairs(toBuildCustomVisuals) do
        local overrideVisualID = RBUtils.Uuid_v4()
        local internalName = intenalNameMap[guid]

        if entData.TemplateType == "character" then
            -- for character, simply build material preset and apply to character visual
            local presetUuid = RBUtils.Uuid_v4()
            local presetInternalName = internalName .. "_CharacterPreset_" .. presetUuid

            --- build preset resource
            local presetBank = LSXHelpers.BuildMaterialPresetBank()
            local presetNode = ResourceHelpers.BuildMaterialPresetResourceNode(entData.OverrideVisualParameters,
                presetUuid, presetInternalName)
            if not presetNode then
                throwError("Failed to build character preset resource for entity " .. entData.DisplayName)
                return
            end
            presetBank:AppendChild(presetNode)
            local presetPath = FilePath.GetCharacterPresetPath(modInternalName, presetUuid)
            saveFile(presetPath, presetNode:Stringify({ AutoFindRoot = true }))

            --- build visual resource
            local visualInternalName = internalName .. "_CharacterVisual_" .. overrideVisualID
            local bank = LSXHelpers.BuildCharacterVisualBank()
            local visualNode = ResourceHelpers.BuildCharacterVisualResource(entData.OriginalVisualUuid,
                overrideVisualID, visualInternalName, { [""] = presetUuid })
            bank:AppendChild(visualNode)
            if not visualNode then
                throwError("Failed to build character visual resource for entity " .. entData.DisplayName)
                return
            end
            local visualPath = FilePath.GetCharacterVisualPath(modInternalName, overrideVisualID)
            saveFile(visualPath, bank:Stringify({ AutoFindRoot = true }))

            entData.OverrideVisualUuid = overrideVisualID
        

        elseif entData.TemplateType == "item" or entData.TemplateType == "scenery" then
            --- for item and scenery, we need to build visual with material overrides and root template
            local vres = Ext.Resource.Get(entData.OriginalVisualUuid, "Visual") --[[@as ResourceVisualResource ]]
            if vres then
                --- map of object link id -> override params
                local overrideLinkIdToParams = entData.VisualObjectMaterialOverride or {}
                
                local linkIdToMatId = {} -- map of object link id -> material id (original or generated)
                local matResToBuild = {} --[[@type table<string, { OriginalMatId: string, Params: RB_ParameterSet }>> ]]
                for _,objDesc in pairs(vres.Objects or {}) do
                    local linkId = objDesc.ObjectID
                    linkIdToMatId[linkId] = objDesc.MaterialID -- default to original material id
                    local paramSet = overrideLinkIdToParams[linkId]
                    if paramSet then -- we have override params for this link id
                        local existingOriMatIdToParams = matIdToParams[objDesc.MaterialID]
                    
                        local generated = nil
                        if existingOriMatIdToParams then
                            --- check if existing generated material params match
                            --- if match, reuse existing generated material id
                            for generatedId, otherParamSet in pairs(existingOriMatIdToParams) do
                                if MaterialParamUtils.SameParamSet(otherParamSet, paramSet) then
                                    generated = generatedId
                                    break
                                end
                                yield()
                            end
                        else
                            matIdToParams[objDesc.MaterialID] = {}
                            existingOriMatIdToParams = matIdToParams[objDesc.MaterialID]
                        end
                        if generated then
                            --- reuse existing
                            linkIdToMatId[linkId] = generated
                        else
                            --- create new
                            generated = RBUtils.Uuid_v4()
                            existingOriMatIdToParams[generated] = paramSet
                            matResToBuild[generated] = {
                                OriginalMatId = objDesc.MaterialID,
                                Params = paramSet,
                            }
                            linkIdToMatId[linkId] = generated
                        end

                    end
                end

                for overrideMatId, matData in pairs(matResToBuild) do
                    local oriMat = matData.OriginalMatId
                    local overrideParams = matData.Params
                    local matInternalName = internalName .. "_MatOverride_" .. overrideMatId
                    local matBank = LSXHelpers.BuildMaterialBank()
                    local matResource = ResourceHelpers.BuildMaterialResource(oriMat, overrideMatId, overrideParams,
                        matInternalName)
                    matBank:AppendChild(matResource)
                    if not matResource then
                        throwError("Failed to build item material override resource for original material " .. oriMat)
                    return
                end

                if templateToVisual[entData.TemplateId] then
                    for customTemplate, linkIdToMat in pairs(templateToVisual[entData.TemplateId]) do
                        local match = true
                        for linkId, matId in pairs(linkIdToMatId) do
                            if linkIdToMat[linkId] ~= matId then
                                match = false
                                break
                            end
                        end
                        if match then
                            -- reuse existing template
                            entData.TemplateId = customTemplate
                            overrideVisualID = entData.OverrideVisualUuid
                            goto continue
                        end
                    end
                end

                local matPath = FilePath.GetItemPresetPath(modInternalName, overrideMatId)
                    saveFile(matPath, matBank:Stringify({ AutoFindRoot = true }))
                end

                --- build visual resource
                local visualInternalName = internalName .. "_ItemVisual_" .. overrideVisualID
                local visualBank = LSXHelpers.BuildVisualBank()
                local visual = ResourceHelpers.BuildVisualResource(vres, overrideVisualID,
                    visualInternalName, linkIdToMatId)
                visualBank:AppendChild(visual)
                local visualPath = FilePath.GetItemVisualPath(modInternalName, overrideVisualID)
                saveFile(visualPath, visualBank:Stringify({ AutoFindRoot = true }))

                --- build root template with visual override
                local overrideTemplateID = RBUtils.Uuid_v4()
                local overrideTemplateInternalName = internalName .. "_VisualTemplate"
                local rootTemplate = LSXHelpers.BuildRootTemplate(entData.TemplateId, overrideTemplateID,
                    overrideTemplateInternalName, { VisualTemplate = overrideVisualID })

                local overrideTemplatePath = FilePath.GetRootTemplatePath(modInternalName, overrideTemplateID)
                --- @diagnostic disable-next-line
                saveFile(overrideTemplatePath, rootTemplate:Stringify({ AutoFindRoot = true }))

                --- set override template id
                entData.TemplateId = overrideTemplateInternalName .. "_" .. overrideTemplateID
                templateToVisual[entData.TemplateId] = templateToVisual[entData.TemplateId] or {}
                templateToVisual[entData.TemplateId][entData.TemplateId] = linkIdToMatId
            else
                Warning("Failed to get original visual resource for entity " .. entData.DisplayName ..
                    " with visual UUID " .. tostring(entData.OriginalVisualUuid))
            end

            
        end
        entData.OverrideVisualUuid = overrideVisualID
        ::continue::
        advance("Exporting custom visual for " .. entData.DisplayName .. "...")
    end

    -- export templates
    
    for guid, entData in pairs(toExport) do
        local levelName = entData.LevelName

        local templateInternalName = intenalNameMap[guid]
        local templatePath = FilePath.GetTemplatePath(modInternalName, levelName, guid, entData.TemplateType)
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
            local otherPath = FilePath.GetTemplatePath(modInternalName, levelName, other.Uuid, other.TemplateType)
            saveFile(otherPath, other.XMLNode:Stringify({ AutoFindRoot = true }))
        end

        advance("Exporting template " .. entData.TemplateType .. " - " .. (entData.DisplayName or entData.TemplateId) .. "...")
    end

    if progressCallback then
        progressCallback(100, "Export complete!")
    end

    Debug("Template export completed in " .. tostring(Ext.Timer.MonotonicTime() - startTime) .. " ms.")
end
