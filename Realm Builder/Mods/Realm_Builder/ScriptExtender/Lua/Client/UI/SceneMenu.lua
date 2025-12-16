SCENEMENU_WIDTH = 1000 * SCALE_FACTOR
SCENEMENU_HEIGHT = 1200 * SCALE_FACTOR

local ClientPresetData = {}

local function UpdatePresetDataFromServer(data)
    if not data or not data.Presets then
        Warning("UpdatePresetDataFromServer: Invalid data received")
        return
    end

    for name, presetData in ipairs(data) do
        if not ClientPresetData[name] then
            ClientPresetData[name] = presetData 
        end
    end
end

--- @class SceneData
--- @field PresetType "Relative"|"Absolute"
--- @field Name string
--- @field Level string
--- @field ModList table<string, {Name:string, Author:string}>
--- @field Tree TreeTable
--- @field Description string|nil
--- @field Highlight boolean|nil
--- @field HighlightColor Vec4|nil
--- @field Spawned table<GUIDSTRING, EntityData>

--- @class SceneMenu
--- @field panel ExtuiTabItem
--- @field SavePreset fun(self: SceneMenu, name: string, overwrite: boolean?, candiates: GUIDSTRING[]?)
--- @field sceneDatas table<string, SceneData>
--- @field Add fun(parent: ExtuiTabBar):SceneMenu
SceneMenu = _Class("PresetMenu")

function SceneMenu:__init(parent)
    self.panel = nil
    self.parent = parent

    self.sceneDatas = ClientPresetData
    self.currentPreset = nil

    self.visibleOnly = true
    self.isRelative = true

    self:LoadFromFile()

    return self
end

function SceneMenu:Render()
    self.panel = self.parent:AddTabItem(GetLoca("Scene"))

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

    local presetNameInputKeySub = InputEvents.SubscribeKeyInput({ Key = "RETURN" }, function()
        if saveButton and ImguiHelpers.IsFocused(presetNameInput) then
            saveButton.OnClick()
        end
    end)

    --saveButton.SameLine = true
    tryLoadButton.SameLine = true
    presetNameInput.SameLine = true

    presetNameInput.IDContext = "PresetNameInput"

    local prefix = l2:AddText(GetLoca("Anchor:"))
    prefix:Tooltip():AddText(GetLoca("The anchor object to save relative position and rotation to. If empty, the host character will be used as anchor.")).TextWrapPos = 900 * SCALE_FACTOR

    local selectCombo = NearbyCombo.new(r2)

    self.GetSelectedObject = function ()
        local object = selectCombo:GetSelected()
        if object and object ~= "" then
            return object
        end
        return RBGetHostCharacter()
    end

    local visibleOnlyCheckbox = self.panel:AddCheckbox(GetLoca("Visible Props Only"), self.visibleOnly)
    --local autoSaveCheckbox = self.panel:AddCheckbox(GetLoca("Auto Save To File"), self.autoSave)
    local relativeCheckbox = self.panel:AddCheckbox(GetLoca("Relative"), self.isRelative)

    local attentionImage = self.panel:AddImage(RB_ICONS.Warning, IMAGESIZE.TINY) --[[@as ExtuiImageButton]]
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
            self:SavePreset(presetName, false)
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

    local collapsingTable = ImguiElements.AddCollapsingTable(self.panel, nil, "Presets", { SideBarWidth = 100 * SCALE_FACTOR, MainAreaTitleAlign = 0.45})
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
    local cTTitleButton = cTTitleButtonCell:AddImageButton("ConfigButton", RB_ICONS.Gear, IMAGESIZE.SMALL)
    cTTitleButton:SetColor("Button", {0,0,0,0})

    local previewConfigPopup = cTTitleButtonCell:AddPopup("Config")
    cTTitleButton.OnClick = function()
        previewConfigPopup:Open()
    end

    self.previewImageSize = 64 * SCALE_FACTOR
    self.previewImageSizeSlider = ImguiHelpers.SafeAddSliderInt(previewConfigPopup, "Icon Size", self.previewImageSize, 32, 256)

    self.cellsPadding = { 5 * SCALE_FACTOR, 5 * SCALE_FACTOR }
    self.cellsPaddingSlider = ImguiHelpers.SafeAddSliderInt(previewConfigPopup, "Cell Padding", 1, 0, 20 * SCALE_FACTOR)
    self.cellsPaddingSlider.Components = 2
    self.cellsPaddingSlider.Value = RBUtils.ToVec4Int(self.cellsPadding[1], self.cellsPadding[2])

    self.iconBGcolor = {0, 0, 0, 0.5}
    self.iconBGcolorPicker = previewConfigPopup:AddColorEdit(GetLoca("Icon BG Color"))
    self.iconBGcolorPicker.Color = self.iconBGcolor


    --AddStyleDebugWindow(collapsingTable)

    self:RenderSidebarSelection()
end

--- @return SceneMenu
function SceneMenu:Add(parent)
    local menu = SceneMenu.new(parent)
    menu:Render()
    return menu
end

function SceneMenu:Destroy()
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

function SceneMenu:SavePreset(name, overwrite, candiates)
    if not name or name == "" then
        Error("Preset name cannot be empty.")
        return
    end

    local spawned = {}

    local anchor = self:GetSelectedObject()
    if not anchor or anchor == "" then
        anchor = RBGetHostCharacter()
    end

    local infos = {}
    if candiates then
        infos = EntityStore:GetStoredDatas(candiates)
    else
        infos = EntityStore:GetAllStored()
    end
    if not infos or RBTableUtils.CountMap(infos) == 0 then
        ConfirmPopup:Popup("No props found to save in preset.")
        return
    end

    if self.sceneDatas[name] and not overwrite then
        ConfirmPopup:QuickConfirm(
            string.format(GetLoca("A scene with name : '%s' already exists. Overwrite?"), name),
            function()
                self:SavePreset(name, true, candiates)
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
        entInfo.DisplayName = RBGetName(guid) or entInfo.DisplayName or "Unknown"

        entInfo.Group = entInfo.Group and entInfo.Group ~= "" and entInfo.Group or name

        local pos, rot = nil, nil
        if self.isRelative then
            pos = MathUtils.SaveLocalRelativePosOffset(entInfo.Guid, anchor)
            rot = MathUtils.SaveLocalRelativeRotOffset(entInfo.Guid, anchor)
        else
            pos = {RBGetPosition(entInfo.Guid)}
            rot = {EntityHelpers.GetQuatRotation(entInfo.Guid)}
        end

        entInfo.Position = pos
        entInfo.Rotation = rot
        entInfo.Level = levelName

        local template = EntityHelpers.TakeTailTemplate(entInfo.TemplateId)
        local templateObj = Ext.Template.GetTemplate(template)
        local isVisual = not templateObj and Ext.Resource.Get(entInfo.TemplateId, "Visual")
        if not templateObj and not isVisual then
            Warning("PresetMenu:SavePreset: Template data not found for " .. tostring(entInfo.TemplateId))
            goto continue
        end
        if templateObj and templateObj.TemplateType == "Item" then
            local statObj = Ext.Stats.GetStatsLoadedBefore(templateObj.Stats) --[[@as StatsObject]] 
            if not statObj then
                statObj = Ext.Stats.Get(templateObj.Stats) 
            end
            if statObj and statObj.ModId and not modList[statObj.ModId] then
                local modObj = Ext.Mod.GetMod(statObj.ModId)
                if not modObj then
                    Warning("PresetMenu:SavePreset: Mod data not found for " .. tostring(statObj.ModId))
                end
                local modName = modObj.Info.Name or "Unknown"
                local modAuthor = modObj.Info.Author or "Unknown"
                modList[statObj.ModId] = { Name = modName, Author = modAuthor }
    
            end
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

    local lca = EntityStore.Tree:FindLCA(candiates)

    if not lca then
        lca = TreeTable.GetRootKey()
    end

    local tree = { [lca] = RBUtils.DeepCopy(EntityStore.Tree:Find(lca)) }

    self.sceneDatas[name] = {
        PresetType = self.isRelative and "Relative" or "Absolute",
        Name = name,
        Level = _C().Level.LevelName,
        ModList = modList,
        Spawned = spawned,
        Tree = tree,
    }

    self:SaveToFile(name)

    self:RenderSidebarSelection()
    self:ChangePresentingPreset(name)
end

function SceneMenu:GetUniqueName(baseName)
    local name = baseName
    local index = 1

    while true do
        local exists = false
        for presetName, preset in ipairs(self.sceneDatas) do
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

function SceneMenu:GetAllPresetNames()
    local names = {}
    for name,_ in pairs(self.sceneDatas) do
        table.insert(names, name)
    end
    table.sort(names, function(a, b) return a < b end)
    return names
end

function SceneMenu:CheckModList(name)
    for modId, modName in pairs(self.sceneDatas[name].ModList or {}) do
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

function SceneMenu:LoadPreset(name, isPreview, force)
    if not self.sceneDatas[name] then
        return nil
    end
    local modAllLoaded = force and true or self:CheckModList(name)
    if not modAllLoaded then
        return nil
    end

    if self.sceneDatas[name].PresetType == "Absolute" and self.sceneDatas[name].Level ~= _C().Level.LevelName and not force then
        ConfirmPopup:Popup(
            string.format(GetLoca("This preset was saved in level '%s'. You are currently in level '%s'."), self.sceneDatas[name].Level, _C().Level.LevelName))
        return nil
    end

    local parentObj = self:GetSelectedObject()
    if not parentObj or parentObj == "" then
        parentObj = RBGetHostCharacter()
    end

    local data = RBUtils.DeepCopy(self.sceneDatas[name])
    if data == self.sceneDatas[name] then
        Debug("SceneMenu:LoadPreset: DeepCopy failed, using original data.")
        data = RBUtils.DeepCopy(self.sceneDatas[name])
    end
    if isPreview then
        data.SpawnType = "Preview"
    end
    data.Position = {RBGetPosition(parentObj)}
    data.Rotation = {EntityHelpers.GetQuatRotation(parentObj)}
    Commands.SpawnPreset(data)

    return nil
end

function SceneMenu:DeletePreset(name)
    if not self.sceneDatas[name] then
        Warning("Preset not found: " .. name)
        return false
    end
    self.sceneDatas[name] = nil
    self:SaveToFile(name)

    self.collapsingTable.OnWidthChange = nil

    if self.presentingPreset == name and self.presetInfoWindow then
        self.presetInfoWindow:Destroy()
        self.presetInfoWindow = nil
    end

    self:RenderPresetDetails()
    self:RenderSidebarSelection()

    return true
end

function SceneMenu:ChangePresentingPreset(name)
    local cT = self.collapsingTable
    cT.OnWidthChange = nil

    self:ClearSidebarHighlights()
    self:RenderPresetDetails(name)
    local sidebarBtn = self.presetSideBarButtons[name]
    if sidebarBtn then
        sidebarBtn.Selected = true
    end
    self.presentingPreset = name
end

function SceneMenu:ClearSidebarHighlights()
    if not self.presetSideBarButtons then
        return
    end
    for name, btn in pairs(self.presetSideBarButtons) do
        btn.Highlight = self.sceneDatas[name].Highlight or false
        btn.Selected = false
    end
end

function SceneMenu:SetupContextMenu()
    if self.presetContextMenu then
        self.highLightPicker.Color = self.sceneDatas[self.selectedPreset].HighlightColor or {1,1,1,1}
        self.presetContextMenu:Open()
        return
    end
    local popup = self.panel:AddPopup("PresetInfoContextMenu")
    self.presetContextMenu = popup


    --- @type RB_ContextItem[]
    local contextItems = {
        {
            Label = GetLoca("Spawn"),
            OnClick = function()
                if not self.selectedPreset then return end
                self:LoadPreset(self.selectedPreset)
            end
        },
        {
            Label = GetLoca("Preview"),
            OnClick = function()
                if not self.selectedPreset then return end
                self:LoadPreset(self.selectedPreset, true)
            end
        },
        {
            Label = GetLoca("Highlight"),
            OnClick = function ()
                if not self.selectedPreset then return end
                self.sceneDatas[self.selectedPreset].Highlight = not self.sceneDatas[self.selectedPreset].Highlight
                self:SaveToFile(self.selectedPreset)
                self:RenderSidebarSelection()
            end,
        },
        {
            Label = GetLoca("Delete"),
            OnClick = function()
                if not self.selectedPreset then return end
                ConfirmPopup:DangerConfirm(
                    GetLoca("Are you sure you want to delete preset") .. " '" .. self.selectedPreset .. "'?",
                    function()
                        if self:DeletePreset(self.selectedPreset) then
                        end
                    end,
                    nil
                )
            end,
            Danger = true
        },
    }

    local cm = ImguiElements.AddContextMenu(popup, "Scene")

    cm:AddItems(contextItems)

    local highLightPicker = cm:AddMenu(GetLoca("Highlight Color")):AddColorEdit(GetLoca("Select Highlight Color"))
    self.highLightPicker = highLightPicker
    if self.selectedPreset then
        highLightPicker.Color = self.sceneDatas[self.selectedPreset].HighlightColor or {1,1,1,1}
    else
        highLightPicker.Color = {1,1,1,1}
    end
    highLightPicker.OnChange = function(colorPicker)
        local name = self.selectedPreset
        if not self.selectedPreset then return end
        self.sceneDatas[self.selectedPreset].HighlightColor = highLightPicker.Color
        self.sceneDatas[name].HighlightColor = colorPicker.Color
        local btn = self.presetSideBarButtons[name]
        if btn then
            btn:SetColor("Header", ColorUtils.AdjustColor(self.sceneDatas[name].HighlightColor, -0.05))
            btn:SetColor("HeaderHovered", self.sceneDatas[name].HighlightColor)
        end
        if self.presentingPreset == name and self.presetInfoWindow then
            self.previewTable.BordersOuter = true
            --self.previewTable.RowBg = true
            --self.previewTable:SetColor("TableRowBg", AdjustColor(self.presets[name].HighlightColor, -0.1, -0.1, -0.6))
            self.previewTable:SetColor("TableBorderStrong", self.sceneDatas[name].HighlightColor)
            local title = self.presetInfoWindow.UserData and self.presetInfoWindow.UserData.Title
            if title then
                title:SetColor("Header", ColorUtils.AdjustColor(self.sceneDatas[name].HighlightColor, -0.05))
                title:SetColor("HeaderHovered", self.sceneDatas[name].HighlightColor)
            end
        end
        self:SaveToFile(name)
    end

    popup:Open()
end

function SceneMenu:RenderSidebarSelection()
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
        button:SetStyle("SelectableTextAlign", 0.5, 0)
        self.presetsDescText[name] = button:Tooltip():AddText(self.sceneDatas[name].Description or "")
        if self.presetsDescText[name].Label == "" then
            button:Tooltip():SetStyle("Alpha", 0)
        else
            button:Tooltip():SetStyle("Alpha", 1)
        end

        if self.sceneDatas[name].Highlight then
            button.Highlight = true
        end
        if self.sceneDatas[name].HighlightColor then
            button:SetColor("Header", ColorUtils.AdjustColor(self.sceneDatas[name].HighlightColor, -0.05))
            button:SetColor("HeaderHovered", self.sceneDatas[name].HighlightColor)
        end

        button.OnClick = function()
            self:ChangePresentingPreset(name)
            button.Selected = true
        end

        if name == self.presentingPreset then
            button.Selected = true
        end

        button.OnRightClick = function()
            self.selectedPreset = name
            self:SetupContextMenu()
        end

        self.presetSideBarButtons[name] = button
    end
end

function SceneMenu:RenderPresetDetails(name)
    if self.descKeyInputSub then
        self.descKeyInputSub:Unsubscribe()
        self.descKeyInputSub = nil
    end

    if self.presetInfoWindow then
        self.presetInfoWindow:Destroy()
        self.presetInfoWindow = nil
    end

    if not name or name == "" or not self.sceneDatas[name] then
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

    local presetData = self.sceneDatas[name]

    local title = self.presetInfoWindow:AddSelectable(name)
    title.Selected = true
    title:SetStyle("SelectableTextAlign", 0.5, 0)
    self.presetInfoWindow.UserData = {Title = title}

    if presetData.HighlightColor then
        self.previewTable.BordersOuter = true
        self.previewTable:SetColor("TableBorderStrong", ColorUtils.AdjustColor(presetData.HighlightColor, 0.2))
        title:SetColor("Header", ColorUtils.AdjustColor(presetData.HighlightColor, -0.05))
        title:SetColor("HeaderHovered", presetData.HighlightColor)
    end

    title.OnClick = function()
        self.selectedPreset = name
        self:SetupContextMenu()
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

    local descInputContent = presetData.Description
    local presetDescInput = inputCell:AddInputText("", descInputContent)
    presetDescInput.Hint = GetLoca("Enter a description here...")
    presetDescInput.Multiline = true
    local confirmInputBtn = inputCell:AddButton("<")
    confirmInputBtn.IDContext = "ConfirmPresetDesc"
    StyleHelpers.ApplyInfoButtonStyle(confirmInputBtn)
    confirmInputBtn.SameLine = true
    confirmInputBtn.OnClick = function()
        self.sceneDatas[name].Description = presetDescInput.Text
        if self.presetsDescText[name] and presetDescInput ~= "" then
            self.presetSideBarButtons[name]:Tooltip():SetStyle("Alpha", 1)
            self.presetsDescText[name].Label = presetDescInput.Text
        else
            self.presetSideBarButtons[name]:Tooltip():SetStyle("Alpha", 0)
            self.presetsDescText[name].Label = ""
        end
        self:SaveToFile(name)
    end
    local descInputKeyLisener = InputEvents.SubscribeKeyInput({ Key = "RETURN" }, function()
        if self.presetInfoWindow and ImguiHelpers.IsFocused(presetDescInput) then
            confirmInputBtn.OnClick()
        end
    end)

    self.descKeyInputSub = descInputKeyLisener

    if presetData.ModList ~= nil and next(presetData.ModList) ~= nil then
        local modInfoWarningButton = modInfoCell:AddButton(GetLoca("Mod Info"))
        modInfoWarningButton.SameLine = true
        StyleHelpers.ApplyConfirmButtonStyle(modInfoWarningButton)
        
        local modlist = presetData.ModList
        modInfoWarningButton:Tooltip():AddText(GetLoca("This preset depends on the following mods:"))
        modInfoWarningButton:Tooltip():AddText(GetLoca("(May not be 100% accurate)")).Font = "Tiny"
        for modId, modInfo in RBUtils.SortedPairs(modlist, function (a, b)
            local aV = modlist[a]
            local bV = modlist[b]
            local aName = aV.Name and aV.Name ~= "" and aV.Name or a
            local bName = bV.Name and bV.Name ~= "" and bV.Name or b
            if aName == bName then
                if aV.Author and bV.Author and (aV.Author ~= bV.Author) then
                    return aV.Author < bV.Author
                else
                    return a < b
                end
            else
                return aName < bName
            end
        end) do
            local modName = modInfo.Name
            local modAuthor = modInfo.Author
            local presentInfo = modName and modName ~= "" and modName or modId
            local tooltip = modInfoWarningButton:Tooltip()
            local modInfoText = tooltip:AddBulletText(presentInfo)
            local modText = tooltip:AddText("by")
            local authorText = tooltip:AddText(modAuthor)
            modInfoText.Font = "Large"
            modText.SameLine = true
            authorText.SameLine = true
            if not Ext.Mod.IsModLoaded(modId) then
                modText:SetColor("Text", {1,0,0,1})
                modText.Label = modText.Label .. " (Missing!)"
                StyleHelpers.ApplyDangerButtonStyle(modInfoWarningButton)
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
                header.Image.Size = RBUtils.ToVec2(self.previewImageSize)
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

function SceneMenu:RenderPresetObjectInfo(parent, entInfo, presetName, presetType, path)
    local group = entInfo.Group or presetName
    local tags = entInfo.Tags or {}
    local note = entInfo.Note or ""
    local template = entInfo.TemplateId or "Unknown"
    template = RBStringUtils.TrimTail(template, 37)
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
    local presetData = self.sceneDatas[presetName] or {}

    local tagsText = ""
    if #tags > 0 then
        tagsText = "[" .. table.concat(tags, ", ") .. "]"
    end

    local header = parent:AddImageButton(displayName, RBCheckIcon(GetIconForTemplateId(entInfo.TemplateId)))
    local imageSize = self.previewImageSize or (64 * SCALE_FACTOR)
    header.Image.Size = RBUtils.ToVec2(imageSize)
    header.Background = self.iconBGcolor or RBUtils.ToVec4(0)
    header.Tint = entInfo.IconTintColor or RBUtils.ToVec4(1)
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
    posInput.Value = {RBStringUtils.FormatDecimal(pos[1], 2), RBStringUtils.FormatDecimal(pos[2], 2), RBStringUtils.FormatDecimal(pos[3], 2), 0}

    iconTooltip:AddText(GetLoca("Rotation") .. " :")
    local rotInput = iconTooltip:AddInputScalar("")
    rotInput.IDContext = "RotInput"
    rotInput.SameLine = true
    rotInput.Components = 4
    rotInput.Value = {RBStringUtils.FormatDecimal(rot[1], 2), RBStringUtils.FormatDecimal(rot[2], 2), RBStringUtils.FormatDecimal(rot[3], 2), RBStringUtils.FormatDecimal(rot[4], 2)}

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
            parent = RBGetHostCharacter()
        end

        local fpos, frot = nil, nil
        if presetType == "Absolute" then
            fpos = pos
            frot = rot
        else
            fpos, frot = MathUtils.GetLocalRelativeTransformFromGuid(parent, pos, rot)
        end

        if not fpos or not frot then
            Error("Failed to get final transform for prop: " .. (entInfo.DisplayName or "Unknown"))
            return nil
        end

        local data = {
            Type = "Preview",
            EntInfo = {
                VisualPreset = visualPreset,
                Position = fpos,
                Rotation = frot,
            },
            TemplateId = entInfo.TemplateId,
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
        Commands.SpawnCommand(data.TemplateId, data.EntInfo)
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

function SceneMenu:SaveToFile(presetName)
    local refFilePath = FilePath.GetPresetReferencePath()
    local refData = {}

    for name, preset in pairs(self.sceneDatas) do
        if preset.Name and preset.Name ~= "" then
            refData[name] = {}
        end
    end

    Ext.IO.SaveFile(refFilePath, Ext.Json.Stringify(refData))

    if presetName then
        local presetFilePath = FilePath.GetPresetPath(presetName)
        local presetData = self.sceneDatas[presetName]
        if presetData then
            Ext.IO.SaveFile(presetFilePath, Ext.Json.Stringify(presetData))
        end
    end
end

function SceneMenu:LoadFromFile()
    local refFilePath = FilePath.GetPresetReferencePath()
    local refData = Ext.IO.LoadFile(refFilePath)
    if refData then
        self.sceneDatas = Ext.Json.Parse(refData) or {}
    else
        self.sceneDatas = {}
    end

    for name,_ in pairs(self.sceneDatas) do
        local presetFilePath = FilePath.GetPresetPath(name)
        local presetFile = Ext.IO.LoadFile(presetFilePath)
        if presetFile then
            local presetData = Ext.Json.Parse(presetFile)
            self.sceneDatas[name] = presetData or nil
        else
            Warning("PresetManager: Preset file not found for " .. name)
            self.sceneDatas[name] = nil
        end
    end
    
end

function SceneMenu:TryToLoadFile(presetName)
    if not presetName or presetName == "" then
        return false
    end

    local presetFilePath = FilePath.GetPresetPath(presetName)
    local presetFile = Ext.IO.LoadFile(presetFilePath)
    if not presetFile then
        return false
    end
    local presetContent = Ext.Json.Parse(presetFile)
    if not presetContent or not next(presetContent) then
        return false
    end

    local function savePreset()
        self.sceneDatas[presetName] = Ext.Json.Parse(presetFile) or {}
        local refFilePath = FilePath.GetPresetReferencePath()
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

    if self.sceneDatas[presetName] then
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
