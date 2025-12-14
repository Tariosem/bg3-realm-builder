local EFFECTSMENU_WIDTH = 1000 * SCALE_FACTOR
local EFFECTSMENU_HEIGHT = 1200 * SCALE_FACTOR

EffectsMenu = _Class("EffectsMenu")

--- @class EffectsMenu
function EffectsMenu:__init(parent)
    self.panel = nil
    self.parent = parent or nil
    self.customEffects = {}
    self.customEffectsTabs = {}
    self.isVisible = false
    self.isAttach = true

    self.selectedTags = {}
    self.selectedGroups = {}
    self.searchNote = ""
    self.nameAscend = true

    self.autoSave = RBUICONFIG.EffectMenu.autoSave and RBUICONFIG.EffectMenu.autoSave or false
    self:Load()
end

function EffectsMenu:Render()
    self.isVisible = true

    if self.parent and self.isAttach then
        self.panel = self.parent:AddTabItem(GetLoca("Effects"))
        self.isWindow = false
    else
        self.panel = WindowManager.RegisterWindow("generic", GetLoca("Effects"), "Effects Menu", self)
        self.panel:SetSize({ EFFECTSMENU_WIDTH, EFFECTSMENU_HEIGHT })
        self.isWindow = true
    end

    local saveOpe = function()
        self:Save()
    end

    local loadOpe = function()
        self:Load()
        self:RenderCustomEffects()
    end

    local clearAllOpe = function()
        self:ClearAll()
    end

    local autoSaveOpe = function()
        self.autoSave = not self.autoSave
        RBUICONFIG.EffectMenu.autoSave = self.autoSave
    end

    local stopAllOpe = function()
        ConfirmPopup:DangerConfirm(
            GetLoca("Are you sure?"),
            function()
                NetChannel.StopStatus:SendToServer({ Type = "All" })
                NetChannel.StopEffect:SendToServer({ Type = "All" })
            end,
            nil
        )
    end

    local detachCell = nil
    if self.isWindow then
        self.mainMenu = self.panel:AddMainMenu()
        self.fileMenu = self.mainMenu:AddMenu(GetLoca("File")) --[[@as ExtuiMenu]]
        self.debugMenu = self.mainMenu:AddMenu(GetLoca("Debug")) --[[@as ExtuiMenu]]
    else

        local menuTable = self.panel:AddTable("EffectsMenuMainMenuTable", 6)
        local menuRow = menuTable:AddRow()
        local fileCell = menuRow:AddCell()
        local debugCell = menuRow:AddCell()
        detachCell = menuRow:AddCell()

        local fileOpenBtn = fileCell:AddSelectable(GetLoca("File"))
        local debugOpenBtn = debugCell:AddSelectable(GetLoca("Debug"))
        self.fileMenu = fileCell:AddPopup("FileMenu")
        self.debugMenu = debugCell:AddPopup("DebugMenu")


        fileOpenBtn.OnClick = function(e)
            --- @diagnostic disable-next-line
            self.fileMenu:Open()
            fileOpenBtn.Selected = false
        end
        debugOpenBtn.OnClick = function(e)
            --- @diagnostic disable-next-line
            self.debugMenu:Open()
            debugOpenBtn.Selected = false
        end
    end

    local saveButton = ImguiElements.AddMenuButton(self.fileMenu, GetLoca("Save Custom Effects"), saveOpe, self.isWindow)
    local loadButton = ImguiElements.AddMenuButton(self.fileMenu, GetLoca("Load Custom Effects"), loadOpe, self.isWindow)
    local autoSaveButton
    autoSaveButton = ImguiElements.AddMenuButton(self.fileMenu, GetLoca("Auto Save") .. (self.autoSave and "(On)" or "(Off)"),
        function()
            autoSaveOpe()
            autoSaveButton.Label = GetLoca("Auto Save") .. (self.autoSave and "(On)" or "(Off)")
            StyleHelpers.SetAlphaByBool(autoSaveButton, self.autoSave)
            UIConfig.SaveConfig("EffectsMenu")
        end, self.isWindow)
    StyleHelpers.SetAlphaByBool(autoSaveButton, self.autoSave)
    local clearAllButton = ImguiElements.AddMenuButton(self.fileMenu, GetLoca("Clear All"), clearAllOpe, self.isWindow)

    local bruteForceDeleteAllButton = ImguiElements.AddMenuButton(self.debugMenu, GetLoca("Stop all effects"), stopAllOpe,
        self.isWindow)
    StyleHelpers.ApplyDangerSelectableStyle(bruteForceDeleteAllButton)
    StyleHelpers.ApplyDangerSelectableStyle(clearAllButton)

    if detachCell then
        local detachButton = ImguiElements.AddSelectableButton(detachCell, GetLoca("Detach"), function()
            if not self.parent then return end
            self.isAttach = not self.isAttach
            self:Refresh()
        end)
    end

    if self.isWindow then
        self.panel.Closeable = true
        self.panel.OnClose = function()
            if not self.parent then return end
            self.isAttach = true
            self:Refresh()
        end
    end


    local collapsingTable = ImguiElements.AddCollapsingTable(self.panel, nil, "Filters",
        { CollapseDirection = "Right", HoverToExpand = false, Collapsed = true })
    self.customEffectsCollapsingTable = collapsingTable
    local customEffectsContainer = collapsingTable.MainArea
    local optionsContainer = collapsingTable.SideBar


    self.customEffectsCell = customEffectsContainer:AddChildWindow("CustomEffectsContainer")

    self:RenderCustomEffects()


    local searchCell = optionsContainer:AddChildWindow("SearchOptions")

    searchCell:AddText("This part is not implemented yet").TextWrapPos = collapsingTable.SideBarWidth + 80
end

function EffectsMenu:RenderCustomEffects()
    if self.customEffectsWindow then
        self.customEffectsWindow:Destroy()
        self.customEffectsWindow = nil
    end

    if self.customEffectsConfigButton then
        self.customEffectsConfigButton:Destroy()
        self.customEffectsConfigButton = nil
    end

    if self.customEffectsTitle then
        self.customEffectsTitle:Destroy()
        self.customEffectsTitle = nil
    end

    if self.customEffectsConfigPopup then
        self.customEffectsConfigPopup:Destroy()
        self.customEffectsConfigPopup = nil
    end

    self.customEffectsWindow = self.customEffectsCell:AddChildWindow("CustomEffects")

    local customEffectsTable = self.customEffectsWindow:AddTable("CustomEffectsTable", self.customEffectsCols or 4)
    local imageSize = self.customEffectsImageSize or (64 * SCALE_FACTOR)
    local images = {}
    local titleCell = self.customEffectsCollapsingTable.TitleCell
    local configButton = titleCell:AddImageButton("ConfigButton", RB_ICONS.Gear, IMAGESIZE.SMALL)
    configButton:SetColor("Button", { 0, 0, 0, 0 })
    self.customEffectsConfigButton = configButton
    local title = titleCell:AddSeparatorText("Custom Effects")
    self.customEffectsTitle = title
    title.SameLine = true
    title:SetStyle("SeparatorTextAlign", 0.48)

    local configPopup = titleCell:AddPopup("ConfigPopup")
    self.customEffectsConfigPopup = configPopup

    local function renderConfig()
        local columnsSlider = ImguiHelpers.SafeAddSliderInt(configPopup, GetLoca("Columns"), self.customEffectsCols or 4, 1, 20)
        columnsSlider.OnChange = function()
            self.customEffectsCols = columnsSlider.Value[1]
            customEffectsTable.Columns = self.customEffectsCols
        end

        local imageSizeSlider = ImguiHelpers.SafeAddSliderInt(configPopup, GetLoca("Icon Size"),
            self.customEffectsImageSize or (64 * SCALE_FACTOR), 16, 256)
        imageSizeSlider.OnChange = function()
            imageSize = imageSizeSlider.Value[1]
            for _, img in pairs(images) do
                img.Image.Size = { imageSize, imageSize }
            end
            self.customEffectsImageSize = imageSize
        end
    end

    renderConfig()

    configButton.OnClick = function()
        configPopup:Open()
    end

    local customEffectsRow = customEffectsTable:AddRow("CustomEffectsRow")

    local sortedNames = {}
    for displayName, _ in pairs(self.customEffects) do
        table.insert(sortedNames, displayName)
    end
    table.sort(sortedNames, function(a, b)
        if self.nameAscend then
            return a < b
        else
            return a > b
        end
    end)

    for i, displayName in pairs(sortedNames) do
        local customEffect = self.customEffects[displayName]
        if not customEffect then goto continue end
        local effectCell = customEffectsRow:AddCell()
        local effectButton = effectCell:AddImageButton(customEffect.DisplayName, customEffect.Icon)
        local effectNameText = effectCell:AddText(customEffect.DisplayName)
        effectButton.Image.Size = { imageSize, imageSize }
        table.insert(images, effectButton)
        local effectButtonTooltipText = effectButton:Tooltip():AddText(customEffect.Description or
        customEffect.DisplayName)
        local tab = self.customEffectsTabs[displayName] or nil

        local function effectButtonOnClick() end

        local function effectTabOnChange()
            --_P("[EffectsMenu] Tab for custom effect " .. customEffect.DisplayName .. " changed, updating button.")
            if not tab or not tab.isExist then
                --_P("[EffectsMenu] Tab for custom effect " .. customEffect.DisplayName .. " is invalid, removing button.")
                self:ClearRef(displayName)
                self.customEffects[displayName] = nil
                self:RenderCustomEffects()
                return
            end
            local newName = self:RegisterNewName(displayName, tab.displayName)
            displayName = newName
            tab.displayName = newName
            effectButton:Destroy()
            effectButton = effectCell:AddImageButton(tab.displayName, tab.icon, RBUtils.ToVec2(imageSize))
            effectButton:Tooltip():AddText(tab.description or tab.displayName or "")
            effectButton.OnClick = effectButtonOnClick
            effectNameText:Destroy()
            effectNameText = effectCell:AddText(tab.displayName)
            self.customEffects[displayName].DisplayName = newName
            self.customEffects[displayName].Icon = tab.icon
            self.customEffects[displayName].Note = tab.Note
            self.customEffects[displayName].Group = tab.Group
            self.customEffects[displayName].Tags = tab.Tags
            self.customEffects[displayName].Description = tab.description
            if self.autoSave then
                self:Save(displayName)
            end
        end

        effectButtonOnClick = function()
            if tab then
                --_P("[EffectsMenu] Tab for custom effect " .. customEffect.DisplayName .. " already exists, selecting it.")
                tab:Focus()
            else
                tab = CustomEffectTab:Add(displayName, self.panel, customEffect.DisplayName, self.customEffects,
                    customEffect.StatsType)
                if tab then
                    self.customEffectsTabs[displayName] = tab
                    tab.OnChange = effectTabOnChange
                    tab:Focus()
                else
                    --Error("[EffectsMenu] Failed to create tab for custom effect " .. customEffect.DisplayName)
                end
            end
        end

        if tab then
            tab.OnChange = effectTabOnChange
            self.customEffectsTabs[displayName] = tab
        else
            --Error("[EffectsMenu] Failed to create tab for custom effect " .. customEffect.DisplayName)
        end

        effectButton.OnClick = effectButtonOnClick

        ::continue::
    end

    --- Create

    local createEffectCell = customEffectsRow:AddCell()

    local createEffectButton = createEffectCell:AddImageButton("CreateCustomEffect", RB_ICONS.Plus_Square)
    table.insert(images, createEffectButton)
    createEffectButton.Image.Size = { imageSize, imageSize }
    createEffectButton:Tooltip():AddText(GetLoca("Create a new blank effect"))

    local createPopup = createEffectCell:AddPopup("createPopup")

    local spellButton = createPopup:AddSelectable(GetLoca("Spell"))
    local statusButton = createPopup:AddSelectable(GetLoca("Status"))
    local effectButton = createPopup:AddSelectable(GetLoca("Effects"))
    spellButton:Tooltip():AddText("Targets")
    statusButton:Tooltip():AddText("Plays in a loop")
    effectButton:Tooltip():AddText("More customizable, but hidden on party members in photo mode")

    createEffectButton.OnClick = function()
        createPopup:Open()
    end

    effectButton.OnClick = function()
        local newName = self:RegisterNewEntry()
        local tab = CustomEffectTab:Add(newName, self.panel, self.customEffects[newName].DisplayName, self.customEffects)
        self.customEffectsTabs[newName] = tab
        self:RenderCustomEffects()
    end

    spellButton.OnClick = function()
        local newName = self:RegisterNewEntry(GetLoca("New Spell"))
        self.customEffects[newName].Icon = "GenericIcon_Intent_Damage"
        local tab = SpellTab:Add(newName, self.panel, self.customEffects[newName].DisplayName, self.customEffects)
        self.customEffectsTabs[newName] = tab
        self.customEffects[newName].StatsType = "SpellData"
        self:RenderCustomEffects()
    end

    statusButton.OnClick = function()
        local newName = self:RegisterNewEntry(GetLoca("New Status"))
        self.customEffects[newName].Icon = "PassiveFeature_CosmicOmen"
        local tab = StatusTab:Add(newName, self.panel, self.customEffects[newName].DisplayName, self.customEffects)
        self.customEffectsTabs[newName] = tab
        self.customEffects[newName].StatsType = "StatusData"
        self:RenderCustomEffects()
    end
end

function EffectsMenu:RegisterNewEntry(basename)
    local entry = {
        DisplayName = self:GetNewName(basename),
        Icon = "GenericIcon_Intent_Utility",
        FxNames = {},
        Note = "",
        Group = "",
        Tags = {},
    }
    self.customEffects[entry.DisplayName] = entry
    return entry.DisplayName
end

function EffectsMenu:RegisterNewName(oldName, newName)
    if oldName == newName then
        return oldName
    end

    if not self.customEffects[oldName] then
        Error("[EffectsMenu] Old name " .. oldName .. " not found in customEffects table")
        return nil
    end

    local availableName = newName
    local cnt = 1
    while self.customEffects[availableName] do
        cnt = cnt + 1
        availableName = newName .. " (" .. cnt .. ")"
    end

    self.customEffects[availableName] = self.customEffects[oldName]
    self.customEffects[availableName].DisplayName = availableName
    self.customEffects[oldName] = nil

    return availableName
end

function EffectsMenu:GetNewName(basename)
    local name = basename or GetLoca("New Effect")
    local cnt = 1
    while self.customEffects[name] do
        cnt = cnt + 1
        name = basename .. " (" .. cnt .. ")"
    end
    return name
end

function EffectsMenu:Save(diaplayName)
    if not self.customEffects or next(self.customEffects) == nil then
        Warning("[EffectsMenu] No custom effects to save.")
        return false
    end

    local toSave = {}

    if not diaplayName then
        for name, effect in pairs(self.customEffects) do
            toSave[name] = self.customEffects[name]
        end
    else
        if not self.customEffects[diaplayName] then
            return false
        end
        toSave[diaplayName] = self.customEffects[diaplayName]
    end


    for name, effect in pairs(toSave) do
        if not effect then goto continue end
        local filePath = FilePath.GetCustomEffectPath(effect.DisplayName)
        local jsonData = Ext.Json.Stringify(effect)
        if not Ext.IO.SaveFile(filePath, jsonData) then
            Error("[EffectsMenu] Failed to save custom effect: " .. effect.DisplayName)
            return false
        end
        ::continue::
    end

    local toRef = {}
    for _, effect in pairs(self.customEffects) do
        toRef[effect.DisplayName] = {}
    end

    local refFilePath = FilePath.GetEffectReferencePath()
    local refData = Ext.Json.Stringify(toRef)
    if not Ext.IO.SaveFile(refFilePath, refData) then
        Error("[EffectsMenu] Failed to save custom effects reference file: " .. refFilePath)
        return false
    end
end

function EffectsMenu:ClearRefs()
    local refFilePath = FilePath.GetEffectReferencePath()
    if not Ext.IO.SaveFile(refFilePath, "{}") then
        Error("[EffectsMenu] Failed to clear custom effects reference file: " .. refFilePath)
        return false
    end
end

function EffectsMenu:ClearRef(name)
    local refFilePath = FilePath.GetEffectReferencePath()
    local refData = Ext.IO.LoadFile(refFilePath)
    if not refData then
        --Warning("[EffectsMenu] No custom effects reference file found at: " .. refFilePath)
        return false
    end

    local toRef = Ext.Json.Parse(refData)
    if not toRef then
        Error("[EffectsMenu] Failed to parse custom effects reference file: " .. refFilePath)
        return false
    end
    local effect = self.customEffects[name]
    if not effect then
        return false
    end

    if toRef[effect.DisplayName] then
        toRef[effect.DisplayName] = nil
    else
        --Warning("[EffectsMenu] No reference found for custom effect: " .. effect.DisplayName)
        return false
    end

    local newRefData = Ext.Json.Stringify(toRef)
    if not Ext.IO.SaveFile(refFilePath, newRefData) then
        Error("[EffectsMenu] Failed to save custom effects reference file: " .. refFilePath)
        return false
    end

    return true
end

function EffectsMenu:Load()
    local refFilePath = FilePath.GetEffectReferencePath()
    local refData = Ext.IO.LoadFile(refFilePath)
    if not refData then
        --Warning("[EffectsMenu] No custom effects reference file found at: " .. refFilePath)
        return
    end

    local toRef = Ext.Json.Parse(refData)
    if not toRef then
        Error("[EffectsMenu] Failed to parse custom effects reference file: " .. refFilePath)
        return
    end

    self.customEffects = {}
    for displayName, _ in pairs(toRef) do
        local filePath = FilePath.GetCustomEffectPath(displayName)
        local jsonData = Ext.IO.LoadFile(filePath)
        if jsonData then
            local effect = Ext.Json.Parse(jsonData)
            if effect then
                self.customEffects[effect.DisplayName] = effect
            else
                Error("[EffectsMenu] Failed to parse custom effect file: " .. filePath)
            end
        else
            Warning("[EffectsMenu] Custom effect file not found: " .. filePath)
        end
    end
end

function EffectsMenu:ClearAll()
    ConfirmPopup:DangerConfirm(
        GetLoca("Are you sure?"),
        function()
            for name, tab in pairs(self.customEffectsTabs) do
                if tab then
                    tab:Destroy()
                end
            end
            self.customEffects = {}
            self:RenderCustomEffects()
            self:ClearRefs()
        end,
        nil
    )
end

function EffectsMenu:Add(parent)
    local instance = EffectsMenu.new(parent)
    instance:Render()
    return instance
end

function EffectsMenu:Collapsed()
    if self.customEffectsWindow then
        self.customEffectsWindow:Destroy()
        self.customEffectsWindow = nil
    end

    if self.customEffectsConfigButton then
        self.customEffectsConfigButton:Destroy()
        self.customEffectsConfigButton = nil
    end

    if self.customEffectsTitle then
        self.customEffectsTitle:Destroy()
        self.customEffectsTitle = nil
    end

    if self.customEffectsConfigPopup then
        self.customEffectsConfigPopup:Destroy()
        self.customEffectsConfigPopup = nil
    end


    if self.isWindow then
        WindowManager.DeleteWindow(self.panel)
    else
        if self.panel then
            self.panel:Destroy()
        end
    end

    self.panel = nil

    self.customEffectsTabs = {}

    self.isVisible = false
end

function EffectsMenu:Destroy()
    self:Collapsed()
    if self.iconBrowser then
        self.iconBrowser:Destroy()
        self.iconBrowser = nil
    end
    self.parent = nil
    self.customEffects = {}
    for _, tab in pairs(self.customEffectsTabs) do
        if tab then
            tab:Destroy()
        end
    end
    self.customEffectsTabs = {}
    self.isVisible = false
end

function EffectsMenu:Refresh()
    self:Collapsed()
    self:Render()
end
