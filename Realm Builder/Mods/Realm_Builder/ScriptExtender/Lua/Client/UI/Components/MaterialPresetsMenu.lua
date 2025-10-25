MATERIALPRESET_DRAGDROP_TYPE = "MaterialPreset"

--- @class MaterialPresetData
--- @field DisplayName string
--- @field UIColor number[]
--- @field Parameters table<1|2|3|4, table<string, any>>
--- @field ExportType "CharacterCreationEyeColors"|"CharacterCreationHairColors"|"CharacterCreationSkinColors"
--- @field Disabled boolean -- if true, preset will not be exported, but still be saved
--- @field Deleted boolean -- temp tag, won't be saved

--- @class RB_CCMod_Pack
--- @field ModName string
--- @field ModuleUUID string
--- @field Author string
--- @field Description string
--- @field Version vec4
--- @field MaterialPresets table<string, MaterialPresetData[]>

--- @class MaterialPresetsMenu
--- @field isVisible boolean
--- @field panel ExtuiWindow
--- @field cachedMods table<string, table<string, RB_CCMod_Pack>>
--- @field modUuids table<string, string>
--- @field UpdateCustomMaterialPresetsList fun(self:MaterialPresetsMenu)
--- @field SaveMaterialPreset fun(self:MaterialPresetsMenu, mat:MaterialEditor)
--- @field RenderPresetColorBox fun(self:MaterialPresetsMenu, preset:ResourceCharacterCreationColor, parent:ExtuiTreeParent):ExtuiColorEdit
--- @field RenderCustomColorBox fun(self:MaterialPresetsMenu, preset:MaterialPresetData, parent:ExtuiTreeParent):ExtuiColorEdit
--- @field RenderCCPresetList fun(self:MaterialPresetsMenu, presetName:string, parent:ExtuiTreeParent)
MaterialPresetsMenu = MaterialPresetsMenu or {}

local function colorPresetComparator(a, b, aName, bName)
    local aR, aG, aB = a.UIColor[1], a.UIColor[2], a.UIColor[3]
    local bR, bG, bB = b.UIColor[1], b.UIColor[2], b.UIColor[3]
    local aH, aS, aV = RGBtoHSV(aR, aG, aB)
    local bH, bS, bV = RGBtoHSV(bR, bG, bB)

    if aH ~= bH then
        return aH < bH
    elseif aS ~= bS then
        return aS < bS
    elseif aV ~= bV then
        return aV < bV
    else
        return aName < bName
    end
end

function MaterialPresetsMenu:Render()
    if self.isVisible then return end

    self.panel = RegisterWindow("generic", "Material Presets", "Menu", self)
    self.panel.Closeable = true

    self.cachedMods = {} --- @type table<string, table<string, RB_CCMod_Pack>>
    self.modUuids = {}   --- @type table<string, string>

    self.isVisible = true
    self:LoadSaveFromCache()
    self:RenderPresetsList()
end

function MaterialPresetsMenu:RenderPresetsList()
    if not self.panel then return end

    self:RenderCustomMaterialPresets()

    local ccPresetsHeader = self.panel:AddCollapsingHeader("Character Creation Material Presets")

    self:RenderCCMaterialPresets(ccPresetsHeader)
end

function MaterialPresetsMenu:RenderCustomMaterialPresets()
    local workshopWindow = RegisterWindow("generic", "Material Presets Workshop", "Export Menu", self)

    self:SetupWorkspace(workshopWindow)
end

---@param parent ExtuiTreeParent
---@param ccaModPack RB_CCMod_Pack?
function MaterialPresetsMenu:SetupWorkspace(parent, ccaModPack)
    local infoTab = parent:AddTable("MaterialPresetsWorkspaceTable", 2)
    local mainRow = infoTab:AddRow()

    infoTab.Resizable = true

    local infoLeft = mainRow:AddCell()
    local infoRight = mainRow:AddCell()

    infoTab.BordersInnerV = true

    local exportCell = infoLeft
    local presetTabCell = infoRight

    --- @type RB_CCMod_Pack
    local exportSettings = ccaModPack or {
        ModName = "",
        Author = "",
        Description = "",
        Version = { 1, 0, 0, 0 },
        MaterialPresets = {},
    }

    local function checkIfExportable()
        if not exportSettings.ModName or exportSettings.ModName == "" then return false, "no mod name" end
        if not exportSettings.Author or exportSettings.Author == "" then return false, "no author" end
        if #(exportSettings.MaterialPresets) == 0 then return false, "no presets" end

        for _, version in pairs(exportSettings.Version) do
            if not tonumber(version) or version < 0 then
                return false, "invalid version number"
            end
        end

        for i = #(exportSettings.MaterialPresets), 1, -1 do
            local preset = exportSettings.MaterialPresets[i]

            if preset.Deleted then
                table.remove(exportSettings.MaterialPresets, i)
                goto continue
            end

            if not preset.Disabled then
                if not preset.DisplayName or preset.DisplayName == "" then
                    return false, "preset with no name"
                end
                if not preset.ExportType or preset.ExportType == "" then
                    return false, preset.DisplayName .. " preset with no export type"
                end
            end

            ::continue::
        end

        return true
    end

    local function refreshSelectedList()
        -- declaration
    end

    local refreshExport = self:RenderExportSettingPanel(exportCell, exportSettings)

    local importWindow = exportCell:AddChildWindow("ImportCCAWindow")
    local refreshImport = self:RenderImportCCASection(importWindow, exportSettings, function()
        Debug("MaterialPresetsMenu: Refreshing export settings after CCA import.")
        refreshExport()
        refreshSelectedList()
    end)

    local topOpeTab = presetTabCell:AddTable("PresetTypesTopTab", 2)
    topOpeTab.ColumnDefs[1] = { WidthStretch = true }
    topOpeTab.ColumnDefs[2] = { WidthFixed = true }

    local topRow = topOpeTab:AddRow()

    local leftCell, rightCell = topRow:AddCell(), topRow:AddCell()

    local namePrior = false
    local sortButton = leftCell:AddButton("Hue##ExportPresetSort")
    local progressBar = leftCell:AddProgressBar("ss##ExportProgressBar") --[[@as ExtuiProgressBar]]

    progressBar.SameLine = true
    progressBar:SetStyle("FrameBorderSize", 2)

    progressBar:SetColor("PlotHistogram", HexToRGBA("FF397D38"))
    progressBar:SetColor("Border", HexToRGBA("FF31BEBE"))
    progressBar:SetColor("Text", { 1, 1, 1, 1 })

    local stooltip = sortButton:Tooltip():AddText("Sort presets by Hue")

    sortButton.OnClick = function()
        namePrior = not namePrior
        refreshSelectedList()
        stooltip.Label = namePrior and "Sort presets by Name" or "Sort presets by Hue"
        sortButton.Label = namePrior and "Name##ExportPresetSort" or "Hue##ExportPresetSort"
    end

    local exportBtn = nil --[[@type ExtuiButton]]
    local exportTT = nil --[[@type ExtuiText]]
    exportBtn = rightCell:AddButton("Export")
    exportBtn:SetStyle("FrameBorderSize", 2)

    exportBtn.OnClick = function(sel)
        local exportable, reason = checkIfExportable()

        if not exportable then
            refreshExport()
            GuiAnim.Vibrate(exportBtn)
            exportTT.Label = "Cannot export material presets: " .. reason
            return
        end

        progressBar.Value = 0
        progressBar:SetColor("PlotHistogram", HexToRGBA("FF397D38"))
        progressBar:SetColor("Border", HexToRGBA("FF2EB5B5"))
        infoTab.Disabled = true -- disable UI during export, avoid unexpected interactions
        self:ExportToMod(exportSettings, function(progress, message)
            exportTT.Label = "Exporting Material Presets... " .. tostring(progress) .. "% " .. (message and (" - " .. message) or "")

            if progress > 0 then
                progressBar.Value = progress / 100
                progressBar.Overlay = message or ""

                if progress == 100 then
                    refreshImport()
                    infoTab.Disabled = false -- re-enable UI after export
                end
            elseif progress < 0 then
                progressBar.Value = 1
                progressBar.Overlay = message and (" - " .. message) or ""
                progressBar:SetColor("PlotHistogram", HexToRGBA("FF910000"))
                progressBar:SetColor("Border", HexToRGBA("FFFF4444"))

                infoTab.Disabled = false
            end
        end)
    end

    exportTT = exportBtn:Tooltip():AddText(
        "Click: Export material presets to Realm_Builder/CC_Mods/\nRight Click: Save to CCA Cache for Importing Later")

    exportBtn.OnHoverEnter = function()
        local exportable, reason = checkIfExportable()
        if not exportable then
            refreshExport()
            exportTT.Label = "Cannot export material presets: " .. reason
            exportBtn:SetColor("Text", HexToRGBA("FFFF0000"))
            exportBtn:SetColor("Border", HexToRGBA("FFFF4444"))
            exportBtn:SetColor("Button", HexToRGBA("FF470000"))
            exportBtn:SetColor("ButtonHovered", HexToRGBA("FF700000"))
            exportBtn:SetColor("ButtonActive", HexToRGBA("FF900000"))
        else
            exportTT.Label = "Export material presets to Realm_Builder/CC_Mods/"
            exportBtn:SetColor("Text", HexToRGBA("FF00CCCC"))
            exportBtn:SetColor("Border", HexToRGBA("FF2EB5B5"))
            exportBtn:SetColor("Button", HexToRGBA("FF004747"))
            exportBtn:SetColor("ButtonHovered", HexToRGBA("FF007070"))
            exportBtn:SetColor("ButtonActive", HexToRGBA("FF009090"))
        end
    end

    local presetTab = presetTabCell:AddChildWindow("PresetsTableWindow"):AddTable("PresetTypesTab", 4)

    presetTab.RowBg = true
    presetTab.Borders = true
    presetTab.ShowHeader = true

    --- @type ExtuiColumnDefinition
    presetTab.ColumnDefs[1] = { WidthFixed = true, Name = "Color" }
    presetTab.ColumnDefs[2] = { WidthStretch = true, Name = "Name" }
    presetTab.ColumnDefs[3] = { WidthStretch = true, Name = "Type" }
    presetTab.ColumnDefs[4] = { WidthFixed = true }

    local allRows = {} --- @type ExtuiTableRow[]

    function refreshSelectedList()
        for _, r in pairs(allRows) do
            r:Destroy()
        end
        allRows = {}

        local mPs = exportSettings.MaterialPresets

        table.sort(mPs, function(a, b)
            if namePrior then
                return a.DisplayName < b.DisplayName
            end

            return colorPresetComparator(a, b, a.DisplayName, b.DisplayName)
        end)

        for i = 1, #(mPs) do
            local preset = mPs[i]
            local r
            r = self:RenderExportPresetRow(presetTab, preset, function()
                for j = 1, #(mPs) do
                    if mPs[j] == preset then
                        table.remove(mPs, j)
                        break
                    end
                end
                for k, row in pairs(allRows) do
                    if row == r then
                        table.remove(allRows, k)
                        break
                    end
                end
            end)
            table.insert(allRows, r)
        end

        local tailRow = presetTab:AddRow()
        tailRow:SetColor("TableRowBg", HexToRGBA("25464646"))
        tailRow:SetColor("TableRowBgAlt", HexToRGBA("1B464646"))
        table.insert(allRows, tailRow)
        local emptyBox, addText = tailRow:AddCell():AddColorEdit("##dropPreset"),
        tailRow:AddCell():AddText("<- Drop here")
        emptyBox.Color = { 0, 0, 0, 0 }
        emptyBox.NoInputs = true
        emptyBox.NoPicker = true

        emptyBox:Tooltip():AddText("Drop Material Preset Here to Add to list")

        emptyBox.CanDrag = true
        emptyBox.DragDropType = MATERIALPRESET_DRAGDROP_TYPE

        emptyBox.OnDragDrop = function(sel, drop)
            if drop.UserData and drop.UserData.Parameters then
                local presetData = {
                    DisplayName = drop.UserData.DisplayName or "Unnamed Preset",
                    UIColor = DeepCopy(drop.UserData.UIColor or { 1, 1, 1, 1 }),
                    Parameters = DeepCopy(drop.UserData.Parameters or {}),
                }
                if not next(presetData.Parameters) then
                    Warning("Failed to add preset to selected list: No parameters found.")
                    return
                end

                table.insert(mPs, presetData)
                refreshSelectedList()
            end
        end
    end

    refreshSelectedList()
end

local function setWarningBorder(extui)
    extui:SetColor("Text", HexToRGBA("FFFF0000"))
    extui:SetColor("Border", HexToRGBA("FFFF4444"))
end

local function clearWarningBorder(extui)
    extui:SetColor("Text", HexToRGBA("FFFFFFFF"))
    extui:SetColor("Border", HexToRGBA("FF888888"))
end

local function checkNameValidity(name)
    -- simple check: no special characters
    if name:match("[^%w_%s%-]") then
        return false
    end
    if name == "" then
        return false
    end
    return true
end

---@param parent ExtuiTreeParent
---@param settings RB_CCMod_Pack
function MaterialPresetsMenu:RenderExportSettingPanel(parent, settings)
    local modNameText = parent:AddText("Mod Name:")
    local modNameInput = parent:AddInputText("##MaterialPresetModName")
    modNameInput.Hint = "Enter Mod Name..."
    modNameInput:SetStyle("FrameBorderSize", 2)

    modNameInput.OnChange = Debounce(50, function()
        if checkNameValidity(modNameInput.Text) then
            clearWarningBorder(modNameInput)
            settings.ModName = modNameInput.Text
            
        else
            setWarningBorder(modNameInput)
            settings.ModName = ""
            GuiAnim.PulseBorder(modNameInput, 2)
        end
    end)
    modNameInput.Text = settings.ModName or ""
    if modNameInput.Text == "" then
        setWarningBorder(modNameInput)
    end
    local authorNameText = parent:AddText("Author Name:")
    local authorNameInput = parent:AddInputText("##MaterialPresetAuthorName")
    authorNameInput:SetStyle("FrameBorderSize", 2)
    modNameInput:Tooltip():AddText("CAUTION:")
    modNameInput:Tooltip():AddText("Special character are not allowed.")
    modNameInput:Tooltip():AddText("Space will be treated as underscore (_), but display name will remain unchanged.")

    authorNameInput.Hint = "Enter Author Name..."
    authorNameInput.OnChange = Debounce(50, function()
        local newName = authorNameInput.Text
        if not checkNameValidity(newName) then
            setWarningBorder(authorNameInput)
            settings.Author = ""
            GuiAnim.PulseBorder(authorNameInput, 2)
        else
            clearWarningBorder(authorNameInput)
            settings.Author = authorNameInput.Text
        end
    end)
    authorNameInput.Text = settings.Author or ""

    if authorNameInput.Text == "" then
        setWarningBorder(authorNameInput)
    end

    local descriptionText = parent:AddText("Description:")
    local descriptionInput = parent:AddInputText("##MaterialPresetDescription")
    descriptionInput.Hint = "Enter Description..."
    descriptionInput.OnChange = function()
        settings.Description = descriptionInput.Text
    end
    descriptionInput.Multiline = true
    descriptionInput.Text = settings.Description or ""

    local versionText = parent:AddText("Version:")
    local versionInput = parent:AddInputInt("##MaterialPresetVersion")
    versionInput.Components = 4
    versionInput:SetStyle("FrameBorderSize", 2)
    versionInput.OnChange = function()
        local valid = true
        for _, var in pairs(versionInput.Value) do
            if not tonumber(var) or var < 0 then
                valid = false
                setWarningBorder(versionInput)
                GuiAnim.PulseBorder(versionInput, 2)
            end
        end
        if valid then clearWarningBorder(versionInput) end
        settings.Version = { versionInput.Value[1], versionInput.Value[2], versionInput.Value[3], versionInput.Value[4] }
    end
    versionInput.Value = { settings.Version[1], settings.Version[2], settings.Version[3], settings.Version[4] }
    clearWarningBorder(versionInput)

    local function refresh()
        modNameInput.Text = settings.ModName or ""
        authorNameInput.Text = settings.Author or ""
        descriptionInput.Text = settings.Description or ""
        versionInput.Value = { settings.Version[1], settings.Version[2], settings.Version[3], settings.Version[4] }
        authorNameInput.OnChange()
        modNameInput.OnChange()
        versionInput.OnChange()
    end

    return refresh
end

function MaterialPresetsMenu:LoadSaveFromCache()
    local locStr = Ext.IO.LoadFile(RealmPaths.GetCCAModCacheRefPath())
    local cache = locStr and Ext.Json.Parse(locStr) or {}
    self.cachedMods = cache or {}

    for modName, versions in pairs(self.cachedMods) do
        for version, modPack in pairs(versions) do
            if modPack.ModuleUUID and IsUuid(modPack.ModuleUUID) then
                self.modUuids[modName] = modPack.ModuleUUID
                break
            end
        end
    end
end

---@param parent ExtuiTreeParent
---@param exportSettings RB_CCMod_Pack
---@param onImportComplete fun()
function MaterialPresetsMenu:RenderImportCCASection(parent, exportSettings, onImportComplete)
    local openedTrees = {}
    local refreshCached

    function refreshCached()
        DestroyAllChilds(parent)

        local cache = nil

        cache = self.cachedMods

        if not cache then
            cache = {}
        end

        for modName, versions in pairs(cache) do
            local modNameSel = parent:AddSelectable((openedTrees[modName] and "[-]" or "[+]") .. modName .. "##ImportCCAMod_" .. modName) --[[@as ExtuiSelectable]]
            local group = AddIndent(parent:AddGroup("ImportCCAModGroup_" .. modName))
            group.Visible = openedTrees[modName] or false

            modNameSel.OnClick = function()
                modNameSel.Selected = false
            
                group.Visible = not group.Visible
                modNameSel.Label = (group.Visible and "[-]" or "[+]") .. modName .. "##ImportCCAMod_" .. modName
                openedTrees[modName] = group.Visible
                modNameSel.Highlight = group.Visible
            end

            local sortedVersions = {}

            for version, _ in pairs(versions) do
                table.insert(sortedVersions, version)
            end

            table.sort(sortedVersions, function(a, b)
                local aMajor, aMinor, aPatch, aBuild = a:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")
                local bMajor, bMinor, bPatch, bBuild = b:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")

                local av64 = ComputeVersion64(aMajor, aMinor, aPatch, aBuild)
                local bv64 = ComputeVersion64(bMajor, bMinor, bPatch, bBuild)
                return av64 > bv64
            end)

            local versionTable = group:AddTable("ImportCCAModVersionTable_" .. modName, 1)
            versionTable.BordersInnerH = true
            local row = versionTable:AddRow()
            for _, version in ipairs(sortedVersions) do
                local cell = row:AddCell()
                local versionSel = cell:AddSelectable("Version " .. version .. "##ImportCCAModVersion_" .. modName .. "_" .. version)
                versionSel.OnClick = function()
                    versionSel.Selected = false
                    local ccaModPack = self:ImportFromFile(modName, version)
                    if not ccaModPack then
                        self.cachedMods[modName][version] = nil
                        self:SaveModCacheRef()

                        refreshCached()
                        Warning("Failed to import CCA mod pack for mod " .. modName .. " version " .. version)
                        return
                    end

                    exportSettings.ModName = ccaModPack.ModName or ""
                    exportSettings.Author = ccaModPack.Author or ""
                    exportSettings.Description = ccaModPack.Description or ""
                    exportSettings.Version = ccaModPack.Version or { 1, 0, 0, 0 }
                    exportSettings.MaterialPresets = DeepCopy(ccaModPack.MaterialPresets or {})
                    exportSettings.ModuleUUID = ccaModPack.ModuleUUID


                    Debug("MaterialPresetsMenu: Imported CCA mod pack for mod " .. modName .. " version " .. version)

                    onImportComplete()
                end
            end
        end
    end

    refreshCached()

    return refreshCached
end

local exportColor = HexToRGBA("C553898D")
local disabledColor = HexToRGBA("C5323232")

---@param parentTab ExtuiTable
---@param obj MaterialPresetData
---@param onDelete fun()
function MaterialPresetsMenu:RenderExportPresetRow(parentTab, obj, onDelete)
    local row = parentTab:AddRow()

    local uiColorCell = row:AddCell()
    local nameCell = row:AddCell()
    local typeCell = row:AddCell()
    local manageCell = row:AddCell()

    local colorBox = uiColorCell:AddColorEdit("##" .. obj.DisplayName)
    local nameInput = nameCell:AddInputText("##" .. obj.DisplayName .. "NameInput", obj.DisplayName)
    local typeCombo = typeCell:AddCombo("##" .. obj.DisplayName .. "TypeCombo")
    local manageBtn = manageCell:AddButton("···##" .. obj.DisplayName)

    colorBox.Color = obj.UIColor
    colorBox.NoInputs = true
    colorBox.CanDrag = true
    colorBox.DragDropType = MATERIALPRESET_DRAGDROP_TYPE

    colorBox.UserData = {
        Parameters = obj.Parameters,
        UIColor = obj.UIColor,
        DisplayName = obj.DisplayName,
    }

    nameInput.SameLine = true
    nameInput.Hint = "Preset Name..."
    nameInput.OnChange = function()
        if nameInput.Text ~= "" then
            obj.DisplayName = nameInput.Text
        end
    end

    colorBox.OnChange = function()
        obj.UIColor = colorBox.Color
    end

    local managePopup = manageCell:AddPopup("ManageSelectedPresetPopup##" .. obj.DisplayName)
    colorBox.OnRightClick = function()
        managePopup:Open()
    end

    colorBox.OnDragStart = function(sel)
        local colorPreview = colorBox.DragPreview:AddColorEdit("##PreviewColorBox")
        colorPreview.Color = obj.UIColor
        colorPreview.NoInputs = true
        colorBox.DragPreview:AddText(obj.DisplayName).SameLine = true
    end

    colorBox.OnDragDrop = function(sel, drop)
        if drop.UserData and drop.UserData.Parameters then
            obj.Parameters = DeepCopy(drop.UserData.Parameters or {})
            if drop.UserData.UIColor then
                local oriColor = DeepCopy(obj.UIColor)
                obj.UIColor = DeepCopy(drop.UserData.UIColor or { 1, 1, 1, 1 })
                colorBox.Color = obj.UIColor
                colorBox.UserData.UIColor = obj.UIColor
                GuiAnim.Blend(colorBox, oriColor, obj.UIColor)
            else
                GuiAnim.FlashColor(colorBox)
            end
        end
    end

    local typeOptions = {
        GetLoca("Eye Color"),
        GetLoca("Hair Color"),
        GetLoca("Skin Color"),
    }
    local indexToType = {
        [1] = "CharacterCreationEyeColors",
        [2] = "CharacterCreationHairColors",
        [3] = "CharacterCreationSkinColors",
    }
    local typeToIndex = {
        ["CharacterCreationEyeColors"] = 0,
        ["CharacterCreationHairColors"] = 1,
        ["CharacterCreationSkinColors"] = 2,
    }

    typeCombo.Options = typeOptions
    typeCombo.OnChange = function()
        local index = typeCombo.SelectedIndex + 1
        obj.ExportType = indexToType[index]
        row:SetColor("TableRowBg", exportColor)
        row:SetColor("TableRowBgAlt", exportColor)
    end

    if obj.ExportType then
        typeCombo.SelectedIndex = typeToIndex[obj.ExportType]
        row:SetColor("TableRowBg", exportColor)
        row:SetColor("TableRowBgAlt", exportColor)
    else
        row:SetColor("TableRowBg", disabledColor)
        row:SetColor("TableRowBgAlt", disabledColor)
    end

    manageBtn.OnClick = function(btn)
        managePopup:Open()
    end

    local selectTable = managePopup:AddTable("ManageSelectedPresetTable", 1)
    local selectRow = selectTable:AddRow()
    local deleteBtn = AddSelectableButton(selectRow:AddCell(), "Remove Preset##" .. obj.DisplayName, function(sel)
        obj.Deleted = true
        onDelete()
        row:Destroy()
    end)
    ApplyDangerSelectableStyle(deleteBtn)

    local openMatMixerBtn = AddSelectableButton(selectRow:AddCell(), "Material Cocktail ##" .. obj.DisplayName,
        function(sel)
            local materialMixer = MaterialMixerTab.new(obj.Parameters)
            materialMixer:Render()
        end)

    return row
end

--- simply load from CCA_Cache folder
---@param modName string
---@param version vec4|string
---@return RB_CCMod_Pack?
function MaterialPresetsMenu:ImportFromFile(modName, version)
    modName = modName:gsub("%s+", "_")
    local versionStr = type(version) == "table" and
        (tostring(version[1]) .. "." .. tostring(version[2]) .. "." .. tostring(version[3]) .. "." .. tostring(version[4])) or
        tostring(version)

    if self.cachedMods and self.cachedMods[modName] then
        local cachedMod = self.cachedMods[modName][versionStr]
        if cachedMod and cachedMod.MaterialPresets then
            return cachedMod
        end
    end

    local filePath = RealmPaths.GetCCAModCachePath(modName, version)

    local jsonStr = Ext.IO.LoadFile(filePath)

    if not jsonStr then
        Warning("ImportFromFile: Failed to load CCA mod cache file at " .. filePath)
        return nil
    end

    local cacheFile = Ext.Json.Parse(jsonStr) --- @type RB_CCMod_Pack

    self.cachedMods[modName] = self.cachedMods[modName] or {}
    self.cachedMods[modName][versionStr] = cacheFile

    return cacheFile
end

function MaterialPresetsMenu:ExportToMod(modPack, progressCallback)
    local threadFunc = function()
        self:__exportToMod(modPack, progressCallback)
    end

    local thread = coroutine.create(threadFunc)

    local ok, err = coroutine.resume(thread)
    if not ok then
        Warning("Error starting export coroutine: " .. tostring(err))
    end
end

--- CAUTION: This function yields periodically and must be called inside a coroutine
---@param modPack RB_CCMod_Pack
---@param progressCallback fun(progress:number, message:string?)
function MaterialPresetsMenu:__exportToMod(modPack, progressCallback)
    local startTime = Ext.Timer.MonotonicTime()
    local suc = true

    local lastYieldTime = startTime
    progressCallback = progressCallback or function(progress, message)
        Debug("MaterialPresetsMenu: ExportToMod Progress: " ..
            tostring(progress) .. "% " .. (message and (" - " .. message) or ""))
    end

    local modName = modPack.ModName
    local authorName = modPack.Author
    local description = modPack.Description
    local version = modPack.Version
    local matPresets = modPack.MaterialPresets
    local existUuid = modPack.ModuleUUID --[[@type GUIDSTRING?]]

    if not existUuid and self.modUuids[modName] then
        existUuid = self.modUuids[modName]
    end

    local actionCnt =
        1 +           -- meta.lsx
        1 +           -- localization.xml
        #matPresets + -- building material preset resource nodes
        3 +           -- saving material preset banks
        #matPresets + -- building character creation color definitions
        3 +           -- saveing character creation color definitions
        1 +           -- save mod cache file
        1             -- save mod cache ref file

    local progress = 0
    local progressStep = 100 / actionCnt

    local yieldThreshold = 5 -- ms
    local function throwError(message)
        progress = -1
        Warning("MaterialPresetsMenu: ExportToMod Error: " .. message)
        progressCallback(progress, message)
        local running = coroutine.running()
        if running then
            coroutine.close(running)
        end
    end

    local function yieldyield()
        if Ext.Timer.MonotonicTime() - lastYieldTime < yieldThreshold then return end

        local thread = coroutine.running()
        _P("MaterialPresetsMenu: ExportToMod yielding to avoid blocking...")
        Timer:Ticks(5, function()
            if coroutine.status(thread) == "suspended" then
                _P("MaterialPresetsMenu: ExportToMod resuming coroutine after yield.")
                local sucr, err = coroutine.resume(thread)
                if not sucr then
                    throwError("ExportToMod: Error resuming coroutine after yield: " .. tostring(err))
                end
            else
                Warning("MaterialPresetsMenu: ExportToMod coroutine not in suspended state after yield, cannot resume.")
            end
        end)
        coroutine.yield()
        lastYieldTime = Ext.Timer.MonotonicTime()
    end

    local function advance(message)
        Debug("MaterialPresetsMenu: Current Export Progress: " ..
            tostring(progress) .. "% " .. (message and (" - " .. message) or ""))
        progress = progress + progressStep
        progressCallback(math.min(progress, 100), message)
        yieldyield()
    end

    local function completeAdvance(message)
        Debug("MaterialPresetsMenu: Export Complete: " .. tostring(progress) .. "% " .. (message and (" - " .. message) or ""))
        progress = 100
        progressCallback(progress, message)
    end

    if not IsUuid(existUuid) then
        existUuid = nil
    end

    -- sanitize mod internal name
    local modInternalName = modName:gsub("%s+", "_")
    local internalNames = {}
    for _, preset in pairs(matPresets) do
        internalNames[preset] = preset.DisplayName:gsub("%s+", "_")
    end

    -- prefer reusing the existing ModuleUUID, so the game recognizes this as the same mod.
    local modUuid = existUuid and existUuid or Uuid_v4()

    --- build mod meta.lsx first
    local metaLsx = LSXHelpers.BuildModMeta(modUuid, modName, modInternalName, authorName, version, description)
    local mataFilePath = RealmPaths.GetCCAModMetaPath(modInternalName)

    suc = Ext.IO.SaveFile(mataFilePath, metaLsx:Stringify({ Indent = 4 }))
    if not suc then throwError("ExportToMod: Failed to save mod meta file at " .. mataFilePath) end
    advance("Saved mod meta file.")

    --- build localization file first because CC presets need it progress:
    local names = {}

    for _, preset in pairs(matPresets) do
        if preset.DisplayName and not preset.Disabled then
            table.insert(names, preset.DisplayName)
        end
    end

    local locaLsx, stringToHandles = LSXHelpers.GenerateLocalization(names, 1)

    local locaFilePath = RealmPaths.GetCCALocalizationPath(modInternalName, "English") -- currently assume English only

    suc = Ext.IO.SaveFile(locaFilePath, locaLsx)
    if not suc then throwError("ExportToMod: Failed to save localization file at " .. locaFilePath) end
    advance("Saved localization file.")

    --- build material presets file first because CC presets need it
    local cheapName = {
        CharacterCreationEyeColors = "_EyeColor_",
        CharacterCreationHairColors = "_HairColor_",
        CharacterCreationSkinColors = "_SkinColor_",
    }

    local banks = {
        CharacterCreationEyeColors = LSXHelpers.BuildMaterialPresetBank(),
        CharacterCreationHairColors = LSXHelpers.BuildMaterialPresetBank(),
        CharacterCreationSkinColors = LSXHelpers.BuildMaterialPresetBank(),
    }

    local matPresetUuids = {}

    -- build material preset banks
    for _, preset in pairs(matPresets) do
        local presetType = preset.ExportType
        local materialPresetBank = banks[presetType]

        local uuid = Uuid_v4()
        matPresetUuids[preset] = uuid
        local internalName = modInternalName .. cheapName[presetType] .. internalNames[preset]
        local presetNode = LSXHelpers.BuildMaterialPresetResourceNode(preset.Parameters, uuid, internalName)

        materialPresetBank:AppendChild(presetNode)

        advance("Building material preset banks resource nodes...")
    end

    -- export material preset banks
    for presetType, bank in pairs(banks) do
        if bank:CountChildren() > 0 then
            local matPresetFile = RealmPaths.GetCCAMaterialPresetsFile(presetType, modInternalName) --[[@as string]]

            suc = Ext.IO.SaveFile(matPresetFile, bank:Stringify({ Indent = 4, AutoFindRoot = true }))
            if not suc then throwError("ExportToMod: Failed to save material preset bank at " .. matPresetFile) end
        end

        advance("Saving material preset banks...")
    end

    --- build Character Creation Presets definition
    --- @type table<string, LSXNode>
    local ccaDefNode = {
        CharacterCreationEyeColors = {},
        CharacterCreationHairColors = {},
        CharacterCreationSkinColors = {},
    }

    for presetType, _ in pairs(ccaDefNode) do
        ccaDefNode[presetType] = LSXHelpers.BuildCCAPresetsRegionNode(presetType)
    end

    for _, preset in pairs(matPresets) do
        local presetType = preset.ExportType
        local ccaPresetNode = ccaDefNode[presetType]

        local internalName = modInternalName .. cheapName[presetType] .. internalNames[preset]
        local matPresetUuid = matPresetUuids[preset]
        local ccaPresetUuid = Uuid_v4()

        local topHanlde = #stringToHandles[preset.DisplayName]
        local handle = stringToHandles[preset.DisplayName][topHanlde]
        table.remove(stringToHandles[preset.DisplayName], topHanlde) -- use up one handle per preset

        local presetNode = LSXHelpers.BuildCCAPresetNode(handle, internalName, preset.UIColor, matPresetUuid,
            ccaPresetUuid, presetType)

        ccaPresetNode:AppendChild(presetNode)

        advance("Building CCA presets definition...")
    end

    -- export CC presets definition file

    for presetType, def in pairs(ccaDefNode) do
        if def:CountChildren() > 0 then
            local ccaFilePath = RealmPaths.GetCCAPresetsFile(presetType, modInternalName) --[[@as string]]

            suc = Ext.IO.SaveFile(ccaFilePath, def:Stringify({ Indent = 4, AutoFindRoot = true }))
            if not suc then throwError("ExportToMod: Failed to save CCA presets definition at " .. ccaFilePath) end
        end
        advance("Saving CCA presets definition...")
    end

    

    local endTime = Ext.Timer.MonotonicTime()
    Debug("ExportToMod: Exported to mod '" .. modName .. "' in " .. tostring(endTime - startTime) .. " ms,")

    --- unserialize xml is possible but for sanity we just save a json cache file
    suc = self:SaveModCache(modName, authorName, description, version, matPresets, modInternalName, modUuid)
    if not suc then throwError("ExportToMod: Failed to save CCA mod cache file at " .. RealmPaths.GetCCAModCachePath(modInternalName, version)) end

    advance("Saved CCA mod cache file.")

    suc = self:SaveModCacheRef()
    if not suc then throwError("ExportToMod: Failed to save CCA mod cache reference file.") end

    advance("Saved CCA mod cache reference file.")

    completeAdvance("Export complete.")
end

function MaterialPresetsMenu:SaveModCache(modName, authorName, description, version, matPresets, modInternalName, modUuid)
    local cacheFile = {
        ModName = modName,
        Author = authorName,
        Description = description,
        Version = version,
        MaterialPresets = matPresets,
        ModuleUUID = modUuid,
    }
    cacheFile = DeepCopy(cacheFile)
    local jsonStr = Ext.Json.Stringify(cacheFile, { Indent = 4 })
    local filePath = RealmPaths.GetCCAModCachePath(modInternalName, version)

    self.cachedMods[modInternalName] = self.cachedMods[modInternalName] or {}
    self.cachedMods[modInternalName][BuildVersionString(version[1], version[2], version[3], version[4])] = cacheFile

    return Ext.IO.SaveFile(filePath, jsonStr)
end

function MaterialPresetsMenu:SaveModCacheRef()
    local allRefs = {}
    for modName, modCache in pairs(self.cachedMods) do
        allRefs[modName] = {}
        for version, cache in pairs(modCache) do
            allRefs[modName][version] = {
                ModuleUUID = cache.ModuleUUID,
            }
        end
    end

    return Ext.IO.SaveFile(RealmPaths.GetCCAModCacheRefPath(), Ext.Json.Stringify(allRefs, { Indent = 4 }))
end

function MaterialPresetsMenu:RenderCCMaterialPresets(header)
    local cca = {
        "CharacterCreationEyeColor",
        "CharacterCreationHairColor",
        "CharacterCreationSkinColor",
    }
    local headers = {} --[[@type table<string, ExtuiTree> ]]

    for _, presetKey in ipairs(cca) do
        local field = header:AddTree(presetKey) --[[@as ExtuiTree]]
        headers[presetKey] = field
        field:SetOpen(false)
    end

    for presetName, field in pairs(headers) do
        field.OnHoverEnter = function()
            MaterialPresetsMenu:RenderCCPresetList(presetName, field)
            field.OnHoverEnter = nil
        end
    end
end

---@param preset ResourceCharacterCreationColor
---@param parent ExtuiTreeParent
---@return ExtuiColorEdit
function MaterialPresetsMenu:RenderPresetColorBox(preset, parent)
    local colorBox = parent:AddColorEdit("##" .. preset.ResourceUUID)
    local managePopup = parent:AddPopup("ManagePresetPopup##" .. preset.ResourceUUID)
    colorBox.Color = preset.UIColor
    colorBox:Tooltip():AddText(preset.DisplayName and preset.DisplayName:Get() or "Unnamed Preset")
    colorBox.NoInputs = true
    colorBox.NoPicker = true
    colorBox.CanDrag = true
    colorBox.DragDropType = MATERIALPRESET_DRAGDROP_TYPE

    colorBox.OnDragStart = function(sel)
        local previewColorBox = colorBox.DragPreview:AddColorEdit("##PreviewColorBox")
        previewColorBox.Color = preset.UIColor
        previewColorBox.NoInputs = true
        colorBox.DragPreview:AddText(preset.DisplayName and preset.DisplayName:Get() or "Unnamed Preset").SameLine = true
        if not preset.ResourceUUID then return end
        if sel.UserData then return end
        local presetProxy = MaterialPresetProxy.new(preset.MaterialPresetUUID)
        if not presetProxy then
            Warning("RenderPresetColorBox: Failed to create MaterialPresetProxy for preset UUID: " ..
                tostring(preset.MaterialPresetUUID))
            return
        end
        sel.UserData = {
            Parameters = presetProxy.Parameters,
            MaterialProxy = presetProxy,
            PresetProxy = presetProxy,
            UIColor = preset.UIColor,
            DisplayName = preset.DisplayName and preset.DisplayName:Get() or "Unnamed Preset",
            SuccessApply = false,
        }
    end

    colorBox.OnDragDrop = function(drop)
        colorBox.Color = preset.UIColor
    end

    colorBox.OnRightClick = function()
        managePopup:Open()
    end

    colorBox.OnHoverEnter = function()
        colorBox.Color = preset.UIColor
        colorBox:SetStyle("FrameBorderSize", 2)
        colorBox:SetColor("Border", HexToRGBA("FFFFD500"))
    end

    colorBox.OnHoverLeave = function()
        colorBox:SetStyle("FrameBorderSize", 0)
        colorBox:SetColor("Border", HexToRGBA("FFFFFFFF"))
    end

    local manageTab = managePopup:AddTable("ManagePresetTable", 1)
    local manageRow = manageTab:AddRow()
    manageTab.BordersInnerH = true

    local openMatMixerBtn = AddSelectableButton(manageRow:AddCell(), "Open in Material Mixer##" .. preset.ResourceUUID,
        function(sel)
            local presetProxy = MaterialPresetProxy.new(preset.MaterialPresetUUID)
            if not presetProxy then
                Warning("RenderPresetColorBox: Failed to create MaterialPresetProxy for preset UUID: " ..
                    tostring(preset.MaterialPresetUUID))
                return
            end
            local materialMixer = MaterialMixerTab.new(presetProxy.Parameters)
            materialMixer:Render()
        end)

    return colorBox
end

function MaterialPresetsMenu:RenderCCPresetList(presetName, parent)
    local cT = AddCollapsingTable(parent, nil, "Recent", { CollapseDirection = "Right" })
    cT.Table.BordersInnerV = true

    local mainList = cT.MainArea
    local recentList = cT.SideBar

    local mainWindow = mainList:AddChildWindow("MainCCPresets")
    local mainTable = mainWindow:AddTable("CCPresets", 10)
    local titleCell = cT.TitleCell

    local titleTable = titleCell:AddTable("CCTitleTable", 2)
    local titleRow = titleTable:AddRow()
    local leftSearchCell = titleRow:AddCell()
    local rightHueSearchCell = titleRow:AddCell()
    titleTable.ColumnDefs[1] = { WidthStretch = true }
    titleTable.ColumnDefs[2] = { WidthFixed = true }

    local maxRecent = 100
    local recentTable = recentList:AddTable("RecentCCPresets", 4)
    local recentRow = recentTable:AddRow()

    local recentQueue = {}

    local row = mainTable:AddRow()

    local allResId = Ext.StaticData.GetAll(presetName) --[[@as table<string>]]

    local allRes = {} --[[@type ResourceCharacterCreationColor[] ]]
    for _, resId in ipairs(allResId) do
        local res = Ext.StaticData.Get(resId, presetName) --[[@as ResourceCharacterCreationColor]]
        table.insert(allRes, res)
    end
    local namePrior = false
    local Comparator = function(a, b)
        local aName = a.DisplayName and a.DisplayName:Get() or ""
        local bName = b.DisplayName and b.DisplayName:Get() or ""
        if namePrior then
            return aName < bName
        end

        return colorPresetComparator(a, b, aName, bName)
    end

    table.sort(allRes, Comparator)

    local uuidToCells = {}

    local function renderAllResources()
        for _, res in ipairs(allRes) do
            local cell = row:AddCell()
            local colorBox = self:RenderPresetColorBox(res, cell)

            colorBox.OnDragEnd = function(sel)
                Timer:Ticks(1, function()
                    if sel.UserData and sel.UserData.SuccessApply then
                        -- Add to recent
                        table.insert(recentQueue, 1, res)

                        -- Remove duplicates
                        local seen = {}
                        local uniqueRecent = {}
                        for _, recent in ipairs(recentQueue) do
                            if not seen[recent.ResourceUUID] then
                                table.insert(uniqueRecent, recent)
                                seen[recent.ResourceUUID] = true
                            end
                        end
                        recentQueue = uniqueRecent

                        -- Trim to maxRecent
                        while #recentQueue > maxRecent do
                            table.remove(recentQueue, #recentQueue)
                        end

                        -- Refresh
                        recentTable:Destroy()
                        recentTable = recentList:AddTable("RecentCCPresets", 4)
                        recentRow = recentTable:AddRow()
                        for _, recent in ipairs(recentQueue) do
                            local recentCell = recentRow:AddCell()
                            self:RenderPresetColorBox(recent, recentCell)
                        end
                    end

                    sel.UserData.SuccessApply = false
                end)
            end

            uuidToCells[res.ResourceUUID] = cell
        end
    end

    renderAllResources()

    local sortButton = leftSearchCell:AddButton("Hue##CCPresetSort")
    local stooltip = sortButton:Tooltip():AddText("Sort presets by Hue")

    sortButton.OnClick = function()
        uuidToCells = {}
        namePrior = not namePrior
        table.sort(allRes, Comparator)
        row:Destroy()
        row = mainTable:AddRow()
        renderAllResources()
        stooltip.Label = namePrior and "Sort presets by Name" or "Sort presets by Hue"
        sortButton.Label = namePrior and "Name##CCPresetSort" or "Hue##CCPresetSort"
    end

    local searchInput = leftSearchCell:AddInputText("##CCPresetSearch")
    searchInput.Hint = "Search Presets..."
    searchInput.SameLine = true

    local debounceTimer = nil

    searchInput.OnChange = function()
        if debounceTimer then
            Timer:Cancel(debounceTimer)
            debounceTimer = nil
        end

        debounceTimer = Timer:Ticks(10, function()
            if not searchInput.Text or searchInput.Text == "" then
                for uuid, cell in pairs(uuidToCells) do
                    cell.Visible = true
                end
                return
            end

            local searchText = string.lower(searchInput.Text)
            for _, res in ipairs(allRes) do
                local cell = uuidToCells[res.ResourceUUID]
                if string.find(string.lower(res.DisplayName and res.DisplayName:Get() or ""), searchText, 1, true) then
                    cell.Visible = true
                else
                    cell.Visible = false
                end
            end
        end)
    end

    local hueInput = rightHueSearchCell:AddColorEdit("##CCPresetHueSearch")
    hueInput.Color = { 1, 0, 0, 1 }
    hueInput.NoInputs = true
    hueInput.NoPicker = false
    hueInput:Tooltip():AddText("Filter by Hue, right click to reset.")
    hueInput.DisplayRGB = true
    hueInput.InputRGB = false
    hueInput.PickerHueWheel = true

    hueInput.OnChange = function()
        local r1, g1, b1 = hueInput.Color[1], hueInput.Color[2], hueInput.Color[3]
        local h1, s1, v1 = RGBtoHSV(r1, g1, b1)

        for _, res in ipairs(allRes) do
            local cell = uuidToCells[res.ResourceUUID]
            local r2, g2, b2 = res.UIColor[1], res.UIColor[2], res.UIColor[3]
            local h2, s2, v2 = RGBtoHSV(r2, g2, b2)

            local hueDiff = math.abs(h1 - h2)
            if hueDiff > 0.05 then
                cell.Visible = false
            else
                cell.Visible = true
            end
        end
    end

    hueInput.OnRightClick = function()
        hueInput.Color = { 1, 0, 0, 1 }
        for uuid, cell in pairs(uuidToCells) do
            cell.Visible = true
        end
    end

    cT.OnWidthChange = function()
        local mTW = mainWindow.LastSize[1]
        local cols = math.floor(mTW / 55 * SCALE_FACTOR)
        if cols < 1 then cols = 1 end
        mainTable.Columns = math.floor(cols)
    end

    Timer:Ticks(10, function()
        cT.OnWidthChange()
    end)

    parent.OnExpand = function()
        cT.OnWidthChange()
    end
end

MaterialPresetsMenu:Render()
