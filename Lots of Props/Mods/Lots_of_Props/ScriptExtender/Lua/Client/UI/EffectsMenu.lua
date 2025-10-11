---@diagnostic disable: param-type-mismatch
EFFECTSMENU_WIDTH = 1000 * SCALE_FACTOR
EFFECTSMENU_HEIGHT = 1200 * SCALE_FACTOR

EffectsMenu = _Class("EffectsMenu")

--- @class EffectsMenu
function EffectsMenu:__init(parent)
    self.panel = nil
    self.parent = parent or nil
    self.customEffects = {}
    self.iconBrowser = EffectIconBrowser:Add(LOP_MultiEffectManager, GetLoca("Effects"))
    self.iconBrowser.panel.Open = false
    self.customEffectsTabs = {}
    self.isVisible = false
    self.isAttach = true

    self.selectedTags = {}
    self.selectedGroups = {}
    self.searchNote = ""
    self.nameAscend = true

    self.autoSave = CONFIG.EffectsMenu.autoSave and CONFIG.EffectsMenu.autoSave or false
    self:Load()
end

function EffectsMenu:Render()
    self.isVisible = true

    if self.parent and self.isAttach then
        self.panel = self.parent:AddTabItem(GetLoca("Effects"))
        self.isWindow = false
    else
        self.panel = RegisterWindow("generic", "", GetLoca("Effects Menu"), self)
        self.panel:SetSize({EFFECTSMENU_WIDTH, EFFECTSMENU_HEIGHT})
        self.isWindow = true
    end

    ----------------------------------------------------------
    -------------------- Main Menu Start ---------------------
    ----------------------------------------------------------

    --#region Main Menu

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
        CONFIG.EffectsMenu.autoSave = self.autoSave
    end

    local stopAllOpe = function()
        ConfirmPopup:DangerConfirm(
            GetLoca("Are you sure?"),
            function()
                local data = {
                    Type = "All"
                }
                Post("StopEffect", data)
                local stopStatusData = {
                    Type = "All"
                }
                Post("StopStatus", stopStatusData)
            end,
            nil
        )
    end

    if self.isWindow then
        self.mainMenu = self.panel:AddMainMenu()
        self.fileMenu = self.mainMenu:AddMenu(GetLoca("File"))
        self.debugMenu = self.mainMenu:AddMenu(GetLoca("Debug"))
    else
        local menuTable = self.panel:AddTable("EffectsMenuMainMenuTable", 6)
        local menuRow = menuTable:AddRow()
        local fileCell = menuRow:AddCell()
        local debugCell = menuRow:AddCell()

        local fileOpenBtn = fileCell:AddSelectable(GetLoca("File"))
        local debugOpenBtn = debugCell:AddSelectable(GetLoca("Debug"))
        self.fileMenu = fileCell:AddPopup("FileMenu")
        self.debugMenu = debugCell:AddPopup("DebugMenu")


        fileOpenBtn.OnClick = function(e) self.fileMenu:Open(); fileOpenBtn.Selected = false; end
        debugOpenBtn.OnClick = function(e) self.debugMenu:Open(); debugOpenBtn.Selected = false; end
    end

    local saveButton = AddMenuButton(self.fileMenu, GetLoca("Save Custom Effects"), saveOpe, self.isWindow)
    local loadButton = AddMenuButton(self.fileMenu, GetLoca("Load Custom Effects"), loadOpe, self.isWindow)
    local autoSaveButton
    autoSaveButton = AddMenuButton(self.fileMenu, GetLoca("Auto Save") .. (self.autoSave and "(On)" or "(Off)"), function()
        autoSaveOpe()
        autoSaveButton.Label = GetLoca("Auto Save") .. (self.autoSave and "(On)" or "(Off)")
        SetAlphaByBool(autoSaveButton, self.autoSave)
        SaveConfig("EffectsMenu")
    end, self.isWindow)
    SetAlphaByBool(autoSaveButton, self.autoSave)
    local clearAllButton = AddMenuButton(self.fileMenu, GetLoca("Clear All"), clearAllOpe, self.isWindow)

    local bruteForceDeleteAllButton = AddMenuButton(self.debugMenu, GetLoca("Stop all effects"), stopAllOpe, self.isWindow)
    ApplyDangerSelectableStyle(bruteForceDeleteAllButton)
    ApplyDangerSelectableStyle(clearAllButton)

    --#endregion Main Menu

    ----------------------------------------------------------
    --------------------- Main Menu End ----------------------
    ----------------------------------------------------------

    ----------------------------------------------------------
    -------------------- Utility Start -----------------------
    ----------------------------------------------------------
    
    --#region Utility

    local topTable = self.panel:AddTable("PropsMenuTopTable", 2)

    topTable.ColumnDefs[1] = { WidthStretch = true }
    topTable.ColumnDefs[2] = { WidthStretch = false, WidthFixed = true}

    self.topRow = topTable:AddRow()

    local browserButton = self.topRow:AddCell():AddButton(GetLoca("Effects Browser"))

    ApplyInfoButtonStyle(browserButton)
    self.detachButtonContainer = self.topRow:AddCell()
    self.detachButton = nil
    if self.isAttach then
        self.detachButton = self.detachButtonContainer:AddButton(GetLoca("Detach"))
    else
        self.detachButton = self.detachButtonContainer:AddButton(GetLoca("Attach"))
    end

    browserButton.OnClick = function()
        if self.iconBrowser then
            self.iconBrowser.panel.Open = not self.iconBrowser.panel.Open
        else
            if next(LOP_MultiEffectManager.Data) == nil then
                Error("[Effects Menu] MultiEffectsSearchData is empty, can't open browser")
                return
            end
            self.iconBrowser = EffectIconBrowser:Add(LOP_MultiEffectManager, GetLoca("Effects"))
        end
    end

    browserButton.OnRightClick = function()
        if self.iconBrowser then
            self.iconBrowser:Destroy()
            self.iconBrowser = nil
        end

        self.iconBrowser = EffectIconBrowser:Add(LOP_MultiEffectManager, GetLoca("Effects"))
    end

    self.detachButton.OnClick = function()
        if self.parent then
            self.isAttach = not self.isAttach
            self.isVisible = true
            self:Refresh()
        end
    end

    if self.isWindow then
        self.panel.Closeable = true
        self.panel.OnClose = self.detachButton.OnClick
    end

    --#endregion Utility

    ----------------------------------------------------------
    -------------------- Utility End -------------------------
    ----------------------------------------------------------
    
    local collapsingTable = AddCollapsingTable(self.panel, nil, "Filters", { CollapseDirection = "Right", HoverToExpand = false, Collapsed = true })
    self.customEffectsCollapsingTable = collapsingTable
    local customEffectsContainer = collapsingTable.MainArea
    local optionsContainer = collapsingTable.SideBar

    ----------------------------------------------------------
    ----------------- Custom Effects Start -------------------
    ----------------------------------------------------------

    --#region Custom Effects

    self.customEffectsCell = customEffectsContainer:AddChildWindow("CustomEffectsContainer")

    self:RenderCustomEffects()

    --#endregion Custom Effects

    ----------------------------------------------------------
    ----------------- Custom Effects End ---------------------
    ----------------------------------------------------------
    
    -----------------------------------------------------------
    -------------- Search And other Options Start -------------
    -----------------------------------------------------------
    
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
    local configButton = titleCell:AddButton("=")
    self.customEffectsConfigButton = configButton
    local title = titleCell:AddSeparatorText("Custom Effects")
    self.customEffectsTitle = title
    title.SameLine = true
    title:SetStyle("SeparatorTextAlign", 0.48)

    local configPopup = titleCell:AddPopup("ConfigPopup")
    self.customEffectsConfigPopup = configPopup

    local function renderConfig()
        local columnsSlider = SafeAddSliderInt(configPopup, GetLoca("Columns"), self.customEffectsCols or 4, 1, 20)
        columnsSlider.OnChange = function()
            self.customEffectsCols = columnsSlider.Value[1]
            customEffectsTable.Columns = self.customEffectsCols
        end

        local imageSizeSlider = SafeAddSliderInt(configPopup, GetLoca("Icon Size"), self.customEffectsImageSize or (64 * SCALE_FACTOR) , 16, 256)
        imageSizeSlider.OnChange = function()
            imageSize = imageSizeSlider.Value[1]
            for _, img in pairs(images) do
                img.Image.Size = {imageSize, imageSize}
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
        effectButton.Image.Size = {imageSize, imageSize}
        table.insert(images, effectButton)
        local effectButtonTooltipText = effectButton:Tooltip():AddText(customEffect.Description or customEffect.DisplayName)
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
            effectButton = effectCell:AddImageButton(tab.displayName, tab.icon, ToVec2(imageSize))
            effectButton:Tooltip():AddText(tab.description or tab.displayName)
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

        effectButtonOnClick = function ()
            if tab then
                --_P("[EffectsMenu] Tab for custom effect " .. customEffect.DisplayName .. " already exists, selecting it.")
                tab:Focus()
            else
                tab = CustomEffectTab:Add(displayName, self.panel, customEffect.DisplayName, self.customEffects, customEffect.StatsType)
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

    local createEffectButton = createEffectCell:AddImageButton("CreateCustomEffect", "GenericIcon_Intent_Buff")
    table.insert(images, createEffectButton)
    createEffectButton.Image.Size = {imageSize, imageSize}
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
        fxNames = {},
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
        local filePath = GetCustomEffectPath(effect.DisplayName)
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

    local refFilePath = GetEffectReferencePath()
    local refData = Ext.Json.Stringify(toRef)
    if not Ext.IO.SaveFile(refFilePath, refData) then
        Error("[EffectsMenu] Failed to save custom effects reference file: " .. refFilePath)
        return false
    end
end

function EffectsMenu:ClearRefs()
    local refFilePath = GetEffectReferencePath()
    if not Ext.IO.SaveFile(refFilePath, "{}") then
        Error("[EffectsMenu] Failed to clear custom effects reference file: " .. refFilePath)
        return false
    end
end

function EffectsMenu:ClearRef(name)
    local refFilePath = GetEffectReferencePath()
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
    local refFilePath = GetEffectReferencePath()
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
        local filePath = GetCustomEffectPath(displayName)
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
        DeleteWindow(self.panel)
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
