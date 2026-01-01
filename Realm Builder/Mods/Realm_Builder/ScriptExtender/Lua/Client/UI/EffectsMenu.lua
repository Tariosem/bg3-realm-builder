local EFFECTSMENU_WIDTH = 1000 * SCALE_FACTOR
local EFFECTSMENU_HEIGHT = 1200 * SCALE_FACTOR

--- @class EffectsMenu
--- @field customEffects RB_CustomEffectData[]
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
        self.panel = WindowManager.RegisterWindow("generic", "Effects Menu")
        self.panel:SetSize({ EFFECTSMENU_WIDTH, EFFECTSMENU_HEIGHT })
        self.isWindow = true
    end

    local saveOpe = function()
        self:Save()
    end

    local loadOpe = function()
        self:Load()
        self:RenderCustomEffects(self.customEffectsChildWin)
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

    local childWin = self.panel:AddChildWindow("EffectsMenuPanelChildWindow")
    self.customEffectsChildWin = childWin

    self:RenderCustomEffects(childWin)
end

--- @param parent ExtuiTreeParent
function EffectsMenu:RenderCustomEffects(parent)
    if not parent then return end
    ImguiHelpers.DestroyAllChildren(parent)
    local customEffectsTable = parent:AddTable("CustomEffectsTable", self.customEffectsCols or 4)
    local imageSize = IMAGESIZE.MEDIUM

    local function renderPlusSquare() end
    local customEffectsRow = customEffectsTable:AddRow()
    local function refreshCustomEffects()
        ImguiHelpers.DestroyAllChildren(customEffectsRow)

        local sortedUuid = {}
        local sortCache = {}
        for uuid, entry in pairs(self.customEffects) do
            sortCache[uuid] = entry.DisplayName
            table.insert(sortedUuid, uuid)
        end
        table.sort(sortedUuid, function(a, b)
            return sortCache[a] < sortCache[b]
        end)

        for _, uuid in ipairs(sortedUuid) do
            local entry = self.customEffects[uuid]
            if not entry then goto continue end

            local effectCell = customEffectsRow:AddCell()
            local existingTab = self.customEffectsTabs[uuid]

            local function tabOnChange()
                if self.autoSave then
                    self:Save(uuid)
                end
                refreshCustomEffects()
            end

            if existingTab then
                existingTab.OnChange = tabOnChange
            end

            local effectButton = effectCell:AddImageButton("##CustomEffectButton_" .. entry.Uuid, entry.Icon, imageSize)
            effectButton:Tooltip():AddText(entry.DisplayName or "Unknown Effect")

            effectButton.OnClick = function()
                local tab = existingTab
                if tab then
                    tab:Focus()
                    return
                end

                if entry.StatsType == "SpellData" then
                    --- @diagnostic disable-next-line
                    tab = SpellTab:Add(entry)
                elseif entry.StatsType == "StatusData" then
                    --- @diagnostic disable-next-line
                    tab = StatusTab:Add(entry)
                else
                    tab = CustomEffectTab:Add(entry)
                end
                tab.OnChange = tabOnChange
                self.customEffectsTabs[uuid] = tab
            end

            ::continue::
        end

        renderPlusSquare()
    end

    --- Create
    function renderPlusSquare()
        local createEffectCell = customEffectsRow:AddCell()
        local createEffectButton = createEffectCell:AddImageButton("##CreateCustomEffect", RB_ICONS.Plus_Square, imageSize)

        createEffectButton.OnClick = function()
            local createPopup = createEffectCell:AddPopup("createPopup")
            local ctxMenu = ImguiElements.AddContextMenu(createPopup, "Create A Blank Effect")
            ctxMenu:AddItem("New Effect", function()
                local newName, entry = self:RegisterNewEntry(GetLoca("New Effect"))
                local tab = CustomEffectTab:Add(entry)
                self.customEffectsTabs[newName] = tab
                refreshCustomEffects()
            end)

            ctxMenu:AddItem("New Spell", function()
                local uuid, entry = self:RegisterNewEntry(GetLoca("New Spell"))
                entry.Icon = "GenericIcon_Intent_Damage"
                entry.StatsType = "SpellData"

                for effectType, _ in pairs(Enums.SpellEffectType) do
                    entry.Effects[effectType] = {}
                end

                --- @diagnostic disable-next-line
                local tab = SpellTab:Add(entry)
                self.customEffectsTabs[uuid] = tab
                refreshCustomEffects()
            end)

            ctxMenu:AddItem("New Status", function()
                local uuid, entry = self:RegisterNewEntry(GetLoca("New Status"))
                entry.Icon = "PassiveFeature_CosmicOmen"
                entry.StatsType = "StatusData"

                for effectType, _ in pairs(Enums.StatusEffectType) do
                    entry.Effects[effectType] = {}
                end

                --- @diagnostic disable-next-line
                local tab = StatusTab:Add(entry)
                self.customEffectsTabs[uuid] = tab
                refreshCustomEffects()
            end)

            createEffectButton.OnClick = function ()
                createPopup:Open()
            end
            createPopup:Open()
        end
    end

    refreshCustomEffects()
end

function EffectsMenu:RegisterNewEntry(basename)
    local uuid = RBUtils.Uuid_v4()

    --- @type RB_CustomEffectData
    local entry = {
        DisplayName = basename or "New Effect",
        Uuid = uuid,
        Description = "",
        Icon = "GenericIcon_Intent_Utility",
        Effects = {},
        Note = "",
        Group = "",
        Tags = {},
    }

    self.customEffects[uuid] = entry
    return uuid, entry
end

function EffectsMenu:Save(uuid)
    if not self.customEffects or next(self.customEffects) == nil then
        Warning("[EffectsMenu] No custom effects to save.")
        return false
    end

    local toSave = {}

    if not uuid then
        for effectId, effect in pairs(self.customEffects) do
            toSave[effectId] = self.customEffects[effectId]
        end
    else
        if not self.customEffects[uuid] then
            return false
        end
        toSave[uuid] = self.customEffects[uuid]
    end

    for name, effect in pairs(toSave) do
        if not effect then goto continue end
        local filePath = FilePath.GetCustomEffectPath(effect.DisplayName .. "_" .. effect.Uuid)
        local jsonData = Ext.Json.Stringify(effect)
        if not Ext.IO.SaveFile(filePath, jsonData) then
            Error("[EffectsMenu] Failed to save custom effect: " .. effect.DisplayName)
            return false
        end
        ::continue::
    end

    local toRef = {}
    for _, effect in pairs(self.customEffects) do
        toRef[effect.Uuid] = effect.DisplayName
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

function EffectsMenu:ClearRef(uuid)
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
    toRef[uuid] = nil
    local newRefData = Ext.Json.Stringify(toRef)
    if not Ext.IO.SaveFile(refFilePath, newRefData) then
        Error("[EffectsMenu] Failed to clear custom effect reference from file: " .. refFilePath)
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
    for uuid, displayName in pairs(toRef) do
        local fileName = displayName .. "_" .. uuid
        local filePath = FilePath.GetCustomEffectPath(fileName)
        local jsonData = Ext.IO.LoadFile(filePath)
        if jsonData then
            local effect = Ext.Json.Parse(jsonData)
            if effect then
                self.customEffects[effect.Uuid] = effect
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
            self:RenderCustomEffects(self.customEffectsChildWin)
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
    for uuid, tab in pairs(self.customEffectsTabs) do
        if tab then
            tab.OnChange = nil
        end
    end

    if self.isWindow then
        WindowManager.DeleteWindow(self.panel)
    else
        if self.panel then
            self.panel:Destroy()
        end
    end

    self.panel = nil
    self.isVisible = false
end

function EffectsMenu:Destroy()
    self:Collapsed()
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
