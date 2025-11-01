PRESETMENU_WIDTH = 1000 * SCALE_FACTOR
PRESETMENU_HEIGHT = 1200 * SCALE_FACTOR

--- @class PropPresetData
--- @field PresetType "Relative"|"Absolute"
--- @field Name string
--- @field Level string
--- @field ModList table<string, {Name:string, Author:string}>
--- @field Tree TreeTable
--- @field Description string|nil
--- @field Highlight boolean|nil
--- @field HighlightColor Vec4|nil

--- @class PresetMenu
--- @field presets table<string, PropPresetData>
PresetMenu = _Class("PresetMenu")

function PresetMenu:__init(parent)
    self.panel = nil
    self.parent = parent

    self.presets = ClientPresetData
    self.currentPreset = nil

    self.visibleOnly = true
    self.autoSave = CONFIG.PresetMenu.autoSave or false
    self.isRelative = true

    self:LoadFromFile()

    return self
end

function PresetMenu:Render()
    self.panel = self.parent:AddTabItem(GetLoca("Presets"))

    local topTable = self.panel:AddTable("topTable", 2) --[[@as ExtuiTable]]
    topTable.ColumnDefs[1] = { WidthFixed = true }
    topTable.ColumnDefs[2] = { WidthStretch = true }
    local row = topTable:AddRow()
    local l1 = row:AddCell()
    local r1 = row:AddCell()
    local l2 = row:AddCell()
    local r2 = row:AddCell()

    local saveButton = l1:AddButton(GetLoca("Save"))
    local presetNameInput = r1:AddInputText("")
    local tryLoadButton = r1:AddButton(GetLoca("Load"))

    local presetNameInputKeySub = SubscribeKeyInput({ Key = "RETURN" }, function()
        if saveButton and IsFocused(presetNameInput) then
            saveButton.OnClick()
        end
    end)

    --saveButton.SameLine = true
    tryLoadButton.SameLine = true
    presetNameInput.SameLine = true

    presetNameInput.IDContext = "PresetNameInput"

    local prefix = l2:AddText(GetLoca("Anchor:"))
    prefix:Tooltip():AddText(GetLoca("The anchor object to save relative position and rotation to. If empty, the host character will be used as anchor.")).TextWrapPos = 900 * SCALE_FACTOR

    r2:AddText("")
    local selectCombo = NearbyCombo.new(r2)
    selectCombo.SameLine = true

    self.GetSelectedObject = function ()
        local object = selectCombo:GetSelected()
        if object and object ~= "" then
            return object
        end
        return CGetHostCharacter()
    end

    local visibleOnlyCheckbox = self.panel:AddCheckbox(GetLoca("Visible Props Only"), self.visibleOnly)
    --local autoSaveCheckbox = self.panel:AddCheckbox(GetLoca("Auto Save To File"), self.autoSave)
    local relativeCheckbox = self.panel:AddCheckbox(GetLoca("Relative"), self.isRelative)

    local attentionImage = self.panel:AddImage(WARNING_ICON)
    attentionImage.OnClick = function(e) e:Destroy() end
    attentionImage.ImageData.Size = IMAGESIZE.TINY

    visibleOnlyCheckbox:Tooltip():AddText(GetLoca("Only save props that are currently visible in the game."))
    relativeCheckbox:Tooltip():AddText(GetLoca("Save props with relative position and rotation to the selected anchor."))

    attentionImage:Tooltip():AddBulletText("Presets only save the visual preset's name, which means you need to save the visual preset first if you want to keep the visual changes.").TextWrapPos = 900 * SCALE_FACTOR
    attentionImage:Tooltip():AddBulletText("If a preset's type is 'Absolute', it will only spawn in the corresponding level.").TextWrapPos = 900 * SCALE_FACTOR
    attentionImage.SameLine = true

    relativeCheckbox.SameLine = true

    visibleOnlyCheckbox.OnChange = function()
        self.visibleOnly = visibleOnlyCheckbox.Checked
    end

    --[[autoSaveCheckbox.OnChange = function()
        self.autoSave = autoSaveCheckbox.Checked
        CONFIG.PresetMenu.autoSave = self.autoSave
        SaveConfig("PresetMenu")
    end]]

    relativeCheckbox.OnChange = function()
        self.isRelative = relativeCheckbox.Checked
    end

    saveButton.OnClick = function()
        local presetName = presetNameInput.Text
        if presetName and presetName ~= "" then
            self:SavePreset(presetName)
            presetNameInput.Text = ""
        else
            --Warning("Preset name cannot be empty.")
        end
    end

    local tryLoadTooltipText = tryLoadButton:Tooltip():AddText("Try to load preset from file with the given name.")
    local tryLoadTimer = nil
    tryLoadButton.OnClick = function()
        if tryLoadTimer then Timer:Cancel(tryLoadTimer) end
        local presetName = presetNameInput.Text
        local suc = self:TryToLoadFile(presetName)
        if not suc then
            tryLoadTooltipText.Label = GetLoca("File not found or empty")
            tryLoadTimer = Timer:After(3000, function ()
                tryLoadTooltipText.Label = "Try to load preset from file with the given name."
            end)
        else
            tryLoadTooltipText.Label = GetLoca("Loaded preset from file")
            tryLoadTimer = Timer:After(3000, function ()
                tryLoadTooltipText.Label = "Try to load preset from file with the given name."
            end)
        end
    end

    local collapsingTable = AddCollapsingTable(self.panel, nil, "Presets", { SideBarWidth = 100 * SCALE_FACTOR, MainAreaTitleAlign = 0.45})
    if collapsingTable then
        self.previewWindow = collapsingTable.MainArea
    else
        Warning("PresetMenu: collapsingTable or MainArea is nil.")
        self.previewWindow = nil
    end
    self.collapsingTable = collapsingTable

    local cTTitleCell = collapsingTable.TitleCell
    local cTTitleTable = cTTitleCell:AddTable("titleTable", 2)
    cTTitleTable.ColumnDefs[1] = { WidthStretch = true }
    cTTitleTable.ColumnDefs[2] = { WidthFixed = true }
    local cTTitleRow = cTTitleTable:AddRow()
    local cTTitleTextCell = cTTitleRow:AddCell()
    local cTTitleButtonCell = cTTitleRow:AddCell()
    cTTitleTextCell:AddSeparatorText(GetLoca("Preset Preview")):SetStyle("SeparatorTextAlign", 0.5, 0)
    local cTTitleButton = cTTitleButtonCell:AddButton("=")

    local previewConfigPopup = cTTitleButtonCell:AddPopup("Config")
    cTTitleButton.OnClick = function()
        previewConfigPopup:Open()
    end

    self.previewImageSize = 64 * SCALE_FACTOR
    self.previewImageSizeSlider = SafeAddSliderInt(previewConfigPopup, "Icon Size", self.previewImageSize, 32, 256)

    self.cellsPadding = { 5 * SCALE_FACTOR, 5 * SCALE_FACTOR }
    self.cellsPaddingSlider = SafeAddSliderInt(previewConfigPopup, "Cell Padding", 1, 0, 20 * SCALE_FACTOR)
    self.cellsPaddingSlider.Components = 2
    self.cellsPaddingSlider.Value = ToVec4Int(self.cellsPadding[1], self.cellsPadding[2])

    self.iconBGcolor = {0, 0, 0, 0.5}
    self.iconBGcolorPicker = previewConfigPopup:AddColorEdit(GetLoca("Icon BG Color"))
    self.iconBGcolorPicker.Color = self.iconBGcolor


    --AddStyleDebugWindow(collapsingTable)

    self:RenderSidebarSelection()
end

function PresetMenu:Add(parent)
    local menu = PresetMenu.new(parent)
    menu:Render()
    return menu
end

function PresetMenu:Destroy()
    self.parent = nil
    if self.panel then
        self.panel:Destroy()
        self.panel = nil
    end
    for _, sub in pairs(self.InitSubs) do
        if sub then
            sub:Unsubscribe()
        end
    end

end

function PresetMenu:SavePreset(name, overwrite)
    if not name or name == "" then
        Error("Preset name cannot be empty.")
        return
    end

    local spawned = {}

    local anchor = self:GetSelectedObject()
    if not anchor or anchor == "" then
        anchor = CGetHostCharacter()
    end

    local infos = EntityStore:GetAll()
    if not infos or CountMap(infos) == 0 then
        ConfirmPopup:Popup("No props found to save in preset.")
        return
    end

    if self.presets[name] and not overwrite then
        ConfirmPopup:QuickConfirm(
            string.format(GetLoca("A preset with name : '%s' already exists. Overwrite?"), name),
            function()
                self:SavePreset(name, true)
            end,
            nil,
            10
        )
        return
    end

    local modList = {}
    for guid, entInfo in pairs(infos) do
        local entity = Ext.Entity.Get(guid)
        if not entity then goto continue end
        local levelName = entity.Level and entity.Level.LevelName or _C().Level.LevelName
        entInfo.DisplayName = GetDisplayNameFromGuid(guid) or entInfo.DisplayName or "Unknown"

        entInfo.Group = entInfo.Group and entInfo.Group ~= "" and entInfo.Group or name

        local pos, rot = nil, nil
        if self.isRelative then
            pos = GetLocalRelativePosOffset(entInfo.Guid, anchor)
            rot = GetLocalRelativeRotOffset(entInfo.Guid, anchor)
        else
            pos = {CGetPosition(entInfo.Guid)}
            rot = {GetQuatRotation(entInfo.Guid)}
        end

        entInfo.Position = pos
        entInfo.Rotation = rot
        entInfo.Level = levelName

        local template = TakeTailTemplate(entInfo.TemplateId)
        local templateData = GetDataFromUuid(template)
        if not templateData then
            Warning("PresetMenu:SavePreset: Template data not found for " .. tostring(entInfo.TemplateId))
            goto continue
        end
        local modId, modName = templateData.ModId, templateData.Mod
        if modId and modId ~= "" and modName and modName ~= "" then
            modList[modId] = { Name = modName , Author = templateData.ModAuthor }
            entInfo.Mod = modName .. " (" .. modId .. ")"
            entInfo.ModId = modId
            entInfo.ModAuthor = templateData.ModAuthor
        end

        if self.visibleOnly then
            if entInfo.Visible then
                spawned[entInfo.Guid] = entInfo
            end
        else
            spawned[entInfo.Guid] = entInfo
        end

        ::continue::
    end

    self.presets[name] = {
        PresetType = self.isRelative and "Relative" or "Absolute",
        Name = name,
        Level = _C().Level.LevelName,
        ModList = modList,
        Spawned = spawned,
        Tree = EntityStore.Tree:ToTable(),
    }

    self:SaveToFile(name)

    self:RenderSidebarSelection()
    self:ChangePresentingPreset(name)
end

function PresetMenu:GetUniqueName(baseName)
    local name = baseName
    local index = 1

    while true do
        local exists = false
        for presetName, preset in ipairs(self.presets) do
            if presetName == name then
                exists = true
                break
            end
        end

        if not exists then
            return name
        end

        index = index + 1
        name = baseName .. " (" .. index .. ")"
    end
end

function PresetMenu:GetAllPresetNames()
    local names = {}
    for name,_ in pairs(self.presets) do
        table.insert(names, name)
    end
    table.sort(names, function(a, b) return a < b end)
    return names
end

function PresetMenu:CheckModList(name)
    for modId, modName in pairs(self.presets[name].ModList or {}) do
        if not Ext.Mod.IsModLoaded(modId) then
            local presentInfo = modName and modName ~= "" and modName or modId
            ConfirmPopup:QuickConfirm(
                string.format(GetLoca("Mod: '%s' is not loaded. Proceed anyway?"), presentInfo),
                function()
                    self:LoadPreset(name, false, true)
                end
            )
            return false
        end
    end
    return true
end

function PresetMenu:LoadPreset(name, isPreview, force)
    if not self.presets[name] then
        return nil
    end
    local modAllLoaded = force and true or self:CheckModList(name)
    if not modAllLoaded then
        return nil
    end

    if self.presets[name].PresetType == "Absolute" and self.presets[name].Level ~= _C().Level.LevelName and not force then
        ConfirmPopup:Popup(
            string.format(GetLoca("This preset was saved in level '%s'. You are currently in level '%s'."), self.presets[name].Level, _C().Level.LevelName))
        return nil
    end

    local data = {
        Name = name,
        Parent = self.GetSelectedObject(),
        PresetData = self.presets[name],
    }
    if isPreview then
        data.Type = "Preview"
    else
        data.Type = "Load"
    end
    if IsCamera(data.Parent) then
        data.Position = {CGetPosition(data.Parent)}
        data.Rotation = {GetQuatRotation(data.Parent)}
    end
    NetChannel.SpawnPreset:SendToServer(data)

    return nil
end

function PresetMenu:DeletePreset(name)
    if not self.presets[name] then
        Warning("Preset not found: " .. name)
        return false
    end
    self.presets[name] = nil
    self:SaveToFile(name)

    self.collapsingTable.OnWidthChange = nil

    if self.presentingPreset == name and self.presetInfoWindow then
        self.presetInfoWindow:Destroy()
        self.presetInfoWindow = nil
    end

    self:RenderPresetInfo()
    self:RenderSidebarSelection()

    return true
end

function PresetMenu:ChangePresentingPreset(name)
    local cT = self.collapsingTable
    cT.OnWidthChange = nil

    self:ClearSidebarHighlights()
    self:RenderPresetInfo(name)
    local sidebarBtn = self.presetSideBarButtons[name]
    if sidebarBtn then
        sidebarBtn.Selected = true
    end
    self.presentingPreset = name
    self.collapsingTable.Collapse()
end

function PresetMenu:ClearSidebarHighlights()
    if not self.presetSideBarButtons then
        return
    end
    for name, btn in pairs(self.presetSideBarButtons) do
        btn.Highlight = self.presets[name].Highlight or false
        btn.Selected = false
    end
end

function PresetMenu:RenderSidebarSelection()
    local ud = self.collapsingTable
    local buttonPanel = self.buttonPanel or ud.SideBar:AddChildWindow("buttonPanel")
    self.buttonPanel = buttonPanel
    self.presetSideBarButtons = self.presetSideBarButtons or {}
    for _, button in pairs(self.presetSideBarButtons) do
        button:Destroy()
    end
    self.presetSideBarButtons = {}
    self.presetsDescText = {}

    local allPresets = self:GetAllPresetNames()

    if self.presetSibeBatTabel then
        self.presetSibeBatTabel:Destroy()
        self.presetSibeBatTabel = nil
    end

    local tempTable = buttonPanel:AddTable("presetButtonTable", 1)
    tempTable.BordersInnerH = true
    self.presetSibeBatTabel = tempTable

    local tempRow = tempTable:AddRow()

    for _, name in ipairs(allPresets) do
        local cell = tempRow:AddCell()
        local button = cell:AddSelectable(name)
        self.presetsDescText[name] = button:Tooltip():AddText(self.presets[name].Description or "")
        if self.presetsDescText[name].Label == "" then
            button:Tooltip():SetStyle("Alpha", 0)
        else
            button:Tooltip():SetStyle("Alpha", 1)
        end

        if self.presets[name].Highlight then
            button.Highlight = true
        end
        if self.presets[name].HighlightColor then
            button:SetColor("Header", AdjustColor(self.presets[name].HighlightColor, -0.05))
            button:SetColor("HeaderHovered", self.presets[name].HighlightColor)
        end

        button.OnClick = function()
            self:ChangePresentingPreset(name)
            button.Selected = true
        end

        if name == self.presentingPreset then
            button.Selected = true
        end

        local popup = cell:AddPopup(name .. "popup")
        local secondPopup = popup:AddPopup(name .. "secondpopup")

        button.OnRightClick = function()
            popup:Open()
            popup:SetStyle("Alpha", 1)
        end

        local borderTable = popup:AddTable("borderTable", 1)
        borderTable.BordersInnerH = true

        local row = borderTable:AddRow()

        local alwaysHighLightBtn = row:AddCell():AddSelectable(GetLoca("Highlight"))
        local setHighLightColorBtn = row:AddCell():AddSelectable(GetLoca("Set Highlight Color"))
        local previewBtn = row:AddCell():AddSelectable(GetLoca("Preview"))
        local loadBtn = row:AddCell():AddSelectable(GetLoca("Spawn"))
        local deleteBtn = row:AddCell():AddSelectable(GetLoca("Delete"))
        ApplyDangerSelectableStyle(deleteBtn)

        deleteBtn.OnClick = function()
            ConfirmPopup:DangerConfirm(
                GetLoca("Are you sure you want to delete preset") .. " '" .. name .. "'?",
                function()
                    if self:DeletePreset(name) then
                    end
                end,
                nil
            )
            deleteBtn.Selected = false
        end

        loadBtn.OnClick = function()
            self:LoadPreset(name)
            loadBtn.Selected = false
        end

        previewBtn.OnClick = function()
            self:LoadPreset(name, true)
            previewBtn.Selected = false
        end

        alwaysHighLightBtn.OnClick = function ()
            self.presets[name].Highlight = not self.presets[name].Highlight
            button.Highlight = self.presets[name].Highlight
            alwaysHighLightBtn.Selected =  self.presets[name].Highlight or false
            self:SaveToFile(name)
        end
        alwaysHighLightBtn.Selected = self.presets[name].Highlight or false

        setHighLightColorBtn.OnClick = function()
            secondPopup:Open()
            setHighLightColorBtn.Selected = true
        end
        setHighLightColorBtn.Selected = true
        setHighLightColorBtn.DontClosePopups = true
        if self.presets[name].HighlightColor then
            setHighLightColorBtn:SetColor("Header", self.presets[name].HighlightColor)
        end

        local colorPicker = secondPopup:AddColorEdit(GetLoca("Highlight Color"))
        colorPicker.Color = self.presets[name].HighlightColor or {1, 1, 0, 1}
        colorPicker.OnChange = function()
            self.presets[name].HighlightColor = colorPicker.Color
            button:SetColor("Header", AdjustColor(self.presets[name].HighlightColor, -0.05))
            button:SetColor("HeaderHovered", self.presets[name].HighlightColor)
            setHighLightColorBtn:SetColor("Header", self.presets[name].HighlightColor)
            if self.presentingPreset == name and self.presetInfoWindow then
                self.previewTable.BordersOuter = true
                --self.previewTable.RowBg = true
                --self.previewTable:SetColor("TableRowBg", AdjustColor(self.presets[name].HighlightColor, -0.1, -0.1, -0.6))
                self.previewTable:SetColor("TableBorderStrong", self.presets[name].HighlightColor)
                local title = self.presetInfoWindow.UserData and self.presetInfoWindow.UserData.Title
                if title then
                    title:SetColor("Header", AdjustColor(self.presets[name].HighlightColor, -0.05))
                    title:SetColor("HeaderHovered", self.presets[name].HighlightColor)
                end
            end
            self:SaveToFile(name)
        end

        self.presetSideBarButtons[name] = button
    end
end

function PresetMenu:RenderPresetInfo(name)
    if self.descKeyInputSub then
        self.descKeyInputSub:Unsubscribe()
        self.descKeyInputSub = nil
    end

    if self.presetInfoWindow then
        self.presetInfoWindow:Destroy()
        self.presetInfoWindow = nil
    end

    if not name or name == "" or not self.presets[name] then
        self.presentingPreset = nil
        return
    end

    --- @type CollapsingTableStyle
    local cT = self.collapsingTable

    --- @type ExtuiTable
    self.previewTable = self.previewTable or self.previewWindow:AddTable("previewTable", 1)
    self.previewRow = self.previewRow or self.previewTable:AddRow()
    self.previewCell = self.previewCell or self.previewRow:AddCell()
    self.previewTable.BordersOuter = false
    self.previewTable.RowBg = false
    --- @type ExtuiWindowBase
    self.presetInfoWindow = self.previewCell:AddChildWindow("name" .. "presetInfo")

    local presetData = self.presets[name]

    local title = self.presetInfoWindow:AddSelectable(name)
    title.Selected = true
    title:SetStyle("SelectableTextAlign", 0.5, 0)
    self.presetInfoWindow.UserData = {Title = title}

    if presetData.HighlightColor then
        self.previewTable.BordersOuter = true
        self.previewTable:SetColor("TableBorderStrong", AdjustColor(presetData.HighlightColor, 0.2))
        title:SetColor("Header", AdjustColor(presetData.HighlightColor, -0.05))
        title:SetColor("HeaderHovered", presetData.HighlightColor)
    end

    local titlePopup = self.presetInfoWindow:AddPopup(name .. "titlepopup")

    local previewBtn = titlePopup:AddSelectable(GetLoca("Preview"))
    local loadBtn = titlePopup:AddSelectable(GetLoca("Spawn"))
    local deleteBtn = titlePopup:AddSelectable(GetLoca("Delete"))
    ApplyDangerSelectableStyle(deleteBtn)

    loadBtn.OnClick = function()
        self:LoadPreset(name)
        loadBtn.Selected = false
    end

    previewBtn.OnClick = function()
        self:LoadPreset(name, true)
        previewBtn.Selected = false
    end

    deleteBtn.OnClick = function()
        ConfirmPopup:DangerConfirm(
            GetLoca("Are you sure you want to delete preset") .. " '" .. name .. "'?",
            function()
                if self:DeletePreset(name) then
                end
            end,
            nil
        )
        deleteBtn.Selected = false
    end

    title.OnClick = function()
        titlePopup:Open()
        title.Selected = true
    end

    title.OnRightClick = title.OnClick

    local presetType = presetData.PresetType == "Relative" and GetLoca("Relative") or GetLoca("Absolute")
    local presetTypeText = self.presetInfoWindow:AddText(GetLoca("Preset Type: ") .. presetType)

    local levelText = self.presetInfoWindow:AddText(GetLoca("Level: ") .. (presetData.Level or "Unknown"))

    local lowTable = self.presetInfoWindow:AddTable("lowTable", 2)
    lowTable.ColumnDefs[1] = { WidthStretch = true }
    lowTable.ColumnDefs[2] = { WidthFixed = true }
    local lowRow = lowTable:AddRow()
    local inputCell = lowRow:AddCell()
    local modInfoCell = lowRow:AddCell()

    local descInputContent = GetLoca("Enter a description here...")
    if presetData.Description ~= nil and presetData.Description ~= "" then
        descInputContent = presetData.Description
    end
    local presetDescInput = inputCell:AddInputText("")
    presetDescInput.Hint = descInputContent
    local confirmInputBtn = inputCell:AddButton("<")
    confirmInputBtn.IDContext = "ConfirmPresetDesc"
    ApplyInfoButtonStyle(confirmInputBtn)
    confirmInputBtn.SameLine = true
    confirmInputBtn.OnClick = function()
        self.presets[name].Description = presetDescInput.Text
        if self.presetsDescText[name] and presetDescInput ~= "" then
            self.presetSideBarButtons[name]:Tooltip():SetStyle("Alpha", 1)
            self.presetsDescText[name].Label = presetDescInput.Text
        else
            self.presetSideBarButtons[name]:Tooltip():SetStyle("Alpha", 0)
            self.presetsDescText[name].Label = ""
        end
        self:SaveToFile(name)
    end
    local descInputKeyLisener = SubscribeKeyInput({ Key = "RETURN" }, function()
        if self.presetInfoWindow and IsFocused(presetDescInput) then
            confirmInputBtn.OnClick()
        end
    end)

    self.descKeyInputSub = descInputKeyLisener

    if presetData.ModList ~= nil and next(presetData.ModList) ~= nil then
        local sorted = MapToSortedArrayByFunc(presetData.ModList, function (a, b)
            if type(a.Value) == "string" then
                return a.Value < b.Value    
            end
            return a.Value.Name < b.Value.Name
        end)
        local modInfoWarningButton = modInfoCell:AddButton(GetLoca("Mod Info"))
        modInfoWarningButton.SameLine = true
        ApplyConfirmButtonStyle(modInfoWarningButton)
        
        modInfoWarningButton:Tooltip():AddText(GetLoca("This preset depends on the following mods:"))
        modInfoWarningButton:Tooltip():AddText(GetLoca("(May not be 100% accurate)")).Font = "Tiny"
        for _, value in ipairs(sorted or {}) do
            local modId = value.Key
            local modName = value.Value.Name
            local modAuthor = value.Value.Author
            local presentInfo = modName and modName ~= "" and modName or modId
            local tooltip = modInfoWarningButton:Tooltip()
            local modInfo = tooltip:AddBulletText(presentInfo)
            local modText = tooltip:AddText("by")
            local authorText = tooltip:AddText(modAuthor)
            modInfo.Font = "Large"
            modText.SameLine = true
            authorText.SameLine = true
            if not Ext.Mod.IsModLoaded(modId) then
                modText:SetColor("Text", CONFIG.Misc.DangerButtonHoveredColor)
                modText.Label = modText.Label .. " (Missing!)"
                ApplyDangerButtonStyle(modInfoWarningButton)
            end
        end
    end

    local entInfoWindow = self.presetInfoWindow

    local propsTree = TreeTable.FromTableStatic(presetData.Tree)
    local propsInfos = presetData.Spawned or {}

    local rootTable = entInfoWindow:AddTable("EntityTable", self.lastCols or 10)
    rootTable:SetStyle("CellPadding", self.cellsPadding[1], self.cellsPadding[2])
    local rootRow = rootTable:AddRow()

    local propHeaders = {}

    cT.OnWidthChange = function(newWidth)
        local windowWidth = entInfoWindow.LastSize[1]
        if not windowWidth or windowWidth == 0 then
            return
        end
        local maxCols = math.floor((windowWidth - 20 * SCALE_FACTOR) / (self.previewImageSize + self.cellsPadding[1] + 20 * SCALE_FACTOR))
        if maxCols < 1 then
            maxCols = 1
        end
        if rootTable then
            rootTable.Columns = maxCols
        end
        self.lastCols = maxCols
    end

    self.previewImageSizeSlider.OnChange = function()
        self.previewImageSize = self.previewImageSizeSlider.Value[1]
        for _, header in ipairs(propHeaders) do
            if header and header.Image then
                header.Image.Size = ToVec2(self.previewImageSize)
            end
        end
        cT.OnWidthChange()
    end

    self.cellsPaddingSlider.OnChange = function()
        self.cellsPadding = { self.cellsPaddingSlider.Value[1], self.cellsPaddingSlider.Value[2] }
        if rootTable then
            rootTable:SetStyle("CellPadding", self.cellsPadding[1], self.cellsPadding[2])
        end
        cT.OnWidthChange()
    end

    self.iconBGcolorPicker.OnChange = function()
        self.iconBGcolor = self.iconBGcolorPicker.Color
        for _, header in ipairs(propHeaders) do
            if header then
                header.Background = self.iconBGcolor
            end
        end
    end

    local propsRow = rootTable:AddRow()

    for guid, entInfo in pairs(propsInfos) do
        local cell = propsRow:AddCell()
        local header = self:RenderPresetObjectInfo(cell, entInfo, name, presetData.PresetType, propsTree:GetPath(guid, true, true))
        table.insert(propHeaders, header)
    end

    entInfoWindow:AddText("Click to spawn preview, right-click to spawn.").TextWrapPos = 950 * SCALE_FACTOR
end

function PresetMenu:RenderPresetObjectInfo(parent, entInfo, presetName, presetType, path)
    local group = entInfo.Group or presetName
    local tags = entInfo.Tags or {}
    local note = entInfo.Note or ""
    local template = entInfo.TemplateId or "Unknown"
    template = TrimTail(template, 37)
    if template == "" then
        template = entInfo.TemplateId
    end
    local displayName = entInfo.DisplayName or "Unknown"
    local guid = entInfo.Guid or "Unknown"
    local pos = entInfo.Position or {0, 0, 0}
    local rot = entInfo.Rotation or {0, 0, 0, 1}
    local visible = entInfo.Visible and GetLoca("Visible") or GetLoca("Hidden")
    local gravity = entInfo.Gravity and GetLoca("On") or GetLoca("Off")
    local persistent = entInfo.Persistent and GetLoca("Yes") or GetLoca("No")
    local canInteract = entInfo.CanInteract and GetLoca("Yes") or GetLoca("No")
    local movable = entInfo.Movable and GetLoca("Yes") or GetLoca("No")
    local visualPreset = entInfo.VisualPreset or ""
    local presetData = self.presets[presetName] or {}

    local tagsText = ""
    if #tags > 0 then
        tagsText = "[" .. table.concat(tags, ", ") .. "]"
    end

    local header = parent:AddImageButton(displayName, GetIconForTemplateId(entInfo.TemplateId))
    local imageSize = self.previewImageSize or (64 * SCALE_FACTOR)
    header.Image.Size = ToVec2(imageSize)
    header.Background = self.iconBGcolor or ToVec4(0)
    header.Tint = entInfo.IconTintColor or ToVec4(1)
    local iconTooltip = header:Tooltip()

    local function addSe()
        iconTooltip:AddSeparator():SetColor("Separator", {0.3, 0.3, 0.3, 1})
    end

    local pathText = table.concat(path or {}, "/")
    local finalDisplayName = (pathText ~= "" and pathText .. " / " or "") .. displayName
    local displayNameText = iconTooltip:AddSelectable(finalDisplayName)
    displayNameText.Highlight = true
    displayNameText:SetStyle("SelectableTextAlign", 0.5, 0)

    local templateText = iconTooltip:AddText(GetLoca("Template: ") .. template)
    templateText.TextWrapPos = 950 * SCALE_FACTOR

    if entInfo.Mod and entInfo.Mod ~= "" then
        local modText = iconTooltip:AddText(GetLoca("Mod: ") .. entInfo.Mod)
        modText.TextWrapPos = 950 * SCALE_FACTOR
    end

    local visualPresetText = iconTooltip:AddText(GetLoca("Visual Preset: ") .. (visualPreset ~= "" and visualPreset or GetLoca("None")))

    local groupText = iconTooltip:AddText(GetLoca("Group: ") .. group)


    if tagsText ~= "" then
        local tagsLabel = iconTooltip:AddText(GetLoca("Tags: ") .. tagsText)
        --tagsLabel.TextWrapPos = 950 * SCALE_FACTOR
    end

    if note ~= "" then
        local noteLabel = iconTooltip:AddText(GetLoca("Note: ") .. note)
        noteLabel.TextWrapPos = 950 * SCALE_FACTOR
    end

    addSe()

    iconTooltip:AddText(GetLoca("Position") .. " :")
    local posInput = iconTooltip:AddInputScalar("")
    posInput.IDContext = "PosInput"
    posInput.SameLine = true
    posInput.Components = 3
    posInput.Value = {FormatDecimal(pos[1], 2), FormatDecimal(pos[2], 2), FormatDecimal(pos[3], 2), 0}

    iconTooltip:AddText(GetLoca("Rotation") .. " :")
    local rotInput = iconTooltip:AddInputScalar("")
    rotInput.IDContext = "RotInput"
    rotInput.SameLine = true
    rotInput.Components = 4
    rotInput.Value = {FormatDecimal(rot[1], 2), FormatDecimal(rot[2], 2), FormatDecimal(rot[3], 2), FormatDecimal(rot[4], 2)}

    addSe()

    local visibleText = iconTooltip:AddText(GetLoca("Visibility: ") .. visible)

    local gravityText = iconTooltip:AddText(GetLoca("Gravity: ") .. gravity)

    local persistentText = iconTooltip:AddText(GetLoca("Persistent: ") .. persistent)

    local canInteractText = iconTooltip:AddText(GetLoca("Can Interact: ") .. canInteract)

    local movableText = iconTooltip:AddText(GetLoca("Movable: ") .. movable)

    local function checkLevel()
        if presetData.PresetType == "Absolute" and presetData.Level and presetData.Level ~= "" and presetData.Level ~= _C().Level.LevelName then
            Warning("This prop was saved in level '" .. presetData.Level .. "'. It may not spawn correctly in the current level '" .. _C().Level.LevelName .. "'.")
            return false
        end
        return true
    end

    local function packData()
        if not checkLevel() then return nil end
        local parent = self:GetSelectedObject()
        if not parent or parent == "" then
            parent = CGetHostCharacter()
        end

        local fpos, frot = nil, nil
        if presetType == "Absolute" then
            fpos = pos
            frot = rot
        else
            fpos, frot = GetLocalRelativeTransform(parent, pos, rot)
        end

        if not fpos or not frot then
            Error("Failed to get final transform for prop: " .. (entInfo.DisplayName or "Unknown"))
            return nil
        end

        local data = {
            Type = "Preview",
            EntInfo = {
                VisualPreset = visualPreset,
            },
            TemplateId = entInfo.TemplateId,
            Positon = fpos,
            Rotation = frot,
        }
        return data
    end

    local function preview()
        local data = packData()
        if not data then return end
        NetChannel.Spawn:RequestToServer(data, function (response) end)
    end

    local function load()
        local data = packData()
        if not data then return end
        Commands.SpawnCommand(data.TemplateId, data.Positon, data.Rotation, data.EntInfo)
    end


    header.OnClick = function()
        if not entInfo.ModId or Ext.Mod.IsModLoaded(entInfo.ModId) then
            preview()
        else
            ConfirmPopup:QuickConfirm(
                string.format(GetLoca("Mod: '%s' is not loaded. Proceed anyway?"), entInfo.Mod and entInfo.Mod ~= "" and entInfo.Mod or entInfo.ModId),
                function()
                    preview()
                end
            )
        end
    end

    header.OnRightClick = function()
        if not entInfo.ModId or Ext.Mod.IsModLoaded(entInfo.ModId) then
            load()
        else
            ConfirmPopup:QuickConfirm(
                string.format(GetLoca("Mod: '%s' is not loaded. Proceed anyway?"), entInfo.Mod and entInfo.Mod ~= "" and entInfo.Mod or entInfo.ModId),
                function()
                    load()
                end
            )
        end
    end

    --info.TextWrapPos = 950 * SCALE_FACTOR
    return header
end

function PresetMenu:SaveToFile(presetName)
    local refFilePath = GetPresetReferencePath()
    local refData = {}

    for name, preset in pairs(self.presets) do
        if preset.Name and preset.Name ~= "" then
            refData[name] = {}
        end
    end

    Ext.IO.SaveFile(refFilePath, Ext.Json.Stringify(refData))

    if presetName then
        local presetFilePath = GetPresetPath(presetName)
        local presetData = self.presets[presetName]
        if presetData then
            Ext.IO.SaveFile(presetFilePath, Ext.Json.Stringify(presetData))
        end
    end
end

function PresetMenu:LoadFromFile()
    local refFilePath = GetPresetReferencePath()
    local refData = Ext.IO.LoadFile(refFilePath)
    if refData then
        self.presets = Ext.Json.Parse(refData) or {}
    else
        self.presets = {}
    end

    for name,_ in pairs(self.presets) do
        local presetFilePath = GetPresetPath(name)
        local presetFile = Ext.IO.LoadFile(presetFilePath)
        if presetFile then
            local presetData = Ext.Json.Parse(presetFile)
            self.presets[name] = presetData or nil
        else
            Warning("PresetManager: Preset file not found for " .. name)
            self.presets[name] = nil
        end
    end
    
end

function PresetMenu:TryToLoadFile(presetName)
    if not presetName or presetName == "" then
        return false
    end

    local presetFilePath = GetPresetPath(presetName)
    local presetFile = Ext.IO.LoadFile(presetFilePath)
    if not presetFile then
        return false
    end
    local presetContent = Ext.Json.Parse(presetFile)
    if not presetContent or not next(presetContent) then
        return false
    end

    local function savePreset()
        self.presets[presetName] = Ext.Json.Parse(presetFile) or {}
        local refFilePath = GetPresetReferencePath()
        local refData = {}
        local refFile = Ext.IO.LoadFile(refFilePath)
        if refFile then
            refData = Ext.Json.Parse(refFile) or {}
        end
        if not refData[presetName] then
            refData[presetName] = {}
            Ext.IO.SaveFile(refFilePath, Ext.Json.Stringify(refData))
        end
        self:RenderSidebarSelection()
    end

    if self.presets[presetName] then
        ConfirmPopup:QuickConfirm(
            string.format(GetLoca("A preset with name : '%s' already exists. Overwrite?"), presetName),
            function()
                savePreset()
            end,
            nil,
            10
        )
    else
        savePreset()
    end

    return true
end
