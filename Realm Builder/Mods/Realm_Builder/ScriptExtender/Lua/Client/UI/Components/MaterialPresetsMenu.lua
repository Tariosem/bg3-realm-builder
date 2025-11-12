MATERIALPRESET_DRAGDROP_TYPE = "MaterialPreset"

--- @alias MaterialPresetExportType "CharacterCreationEyeColors"|"CharacterCreationHairColors"|"CharacterCreationSkinColors"

--- @class MaterialPresetData
--- @field DisplayName string
--- @field UIColor number[]
--- @field Parameters table<1|2|3|4, table<string, any>>
--- @field Deleted boolean -- temp dirty tag

--- @class CCMOD_FolderDefinition
--- @field ExportType MaterialPresetExportType
--- @field UIColor vec4

--- @class RB_Mod_ExportSetting
--- @field ModName string
--- @field Author string
--- @field Description string
--- @field Version vec4

--- @class CCMod_Pack : RB_Mod_ExportSetting
--- @field ModuleUUID string
--- @field FolderDefinitions table<string, CCMOD_FolderDefinition> -- folder name -> definition
--- @field Folders table<string, table<string, any>> -- folder name -> preset GUID -> any
--- @field MaterialPresets table<string, MaterialPresetData[]>

--- @alias CCMod_Reference { ModuleUUID: string, Versions: table<string, any>, Cache: table<string, CCMod_Pack> } -- version -> CCMod_Pack

--- @class MaterialPresetsMenu
--- @field isVisible boolean
--- @field panel ExtuiWindow
--- @field cachedMods table<string, CCMod_Reference>
--- @field UpdateCustomMaterialPresetsList fun(self:MaterialPresetsMenu)
--- @field SaveMaterialPreset fun(self:MaterialPresetsMenu, mat:MaterialEditor)
--- @field RenderPresetColorBox fun(self:MaterialPresetsMenu, preset:ResourceCharacterCreationColor, parent:ExtuiTreeParent):ExtuiColorEdit
--- @field RenderCustomColorBox fun(self:MaterialPresetsMenu, preset:MaterialPresetData, parent:ExtuiTreeParent):ExtuiColorEdit
--- @field RenderCCPresetList fun(self:MaterialPresetsMenu, presetName:string, parent:ExtuiTreeParent)
MaterialPresetsMenu = MaterialPresetsMenu or {}

local exportColor = HexToRGBA("C553898D")
local disabledColor = HexToRGBA("C5323232")

local difineToDisplay = {
    CharacterCreationEyeColors = "Eye Color",
    CharacterCreationHairColors = "Hair Color",
    CharacterCreationSkinColors = "Skin Color",
}

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

function MaterialPresetsMenu:Render(parent)
    if self.isVisible then return end
    self.cachedMods = {} --- @type table<string, table<string, CCMod_Pack>>

    self.isVisible = true
    self:LoadSaveFromCache()
end

function MaterialPresetsMenu:RenderCCPresetsLib(parent)
    if not parent then return end
    self:RenderCCMaterialPresets(parent)
end

function MaterialPresetsMenu:RenderCustomMaterialPresets(par)
    local workshopPanel = par

    local pack = self:SetupWorkspace(workshopPanel)

    local function renderOn(parent)
        self:SetupWorkspace(parent, pack)
    end

    return renderOn
end

---@param parent ExtuiTreeParent
---@param ccaModPack CCMod_Pack?
function MaterialPresetsMenu:SetupWorkspace(parent, ccaModPack, notRenderImport)
    local infoTab = AddCollapsingTable(parent, nil, nil, { SideBarWidth = 400 * SCALE_FACTOR })

    local infoLeft = infoTab.SideBar
    local infoRight = infoTab.MainArea
    infoTab.Table.Borders = true

    infoTab.BordersInnerV = true

    local exportCell = infoLeft
    local presetTabCell = infoRight

    --- @type CCMod_Pack
    local exportSettings = ccaModPack or {
        ModName = "",
        Author = "",
        Description = "",
        Version = { 1, 0, 0, 0 },
        Folders = {},
        FolderDefinitions = {},
        MaterialPresets = {},
    }

    local presetHeaders = {}
    local function checkIfExportable()
        if not exportSettings.ModName or exportSettings.ModName == "" then return false, "no mod name" end
        if not exportSettings.Author or exportSettings.Author == "" then return false, "no author" end
        if CountMap(exportSettings.Folders) == 0 then return false, "no folders defined" end

        for _, version in pairs(exportSettings.Version) do
            if not tonumber(version) or version < 0 then
                return false, "invalid version number"
            end
        end

        for folderName, _ in pairs(exportSettings.Folders) do
            if not exportSettings.FolderDefinitions[folderName].ExportType then
                if presetHeaders[folderName] then
                    local header = presetHeaders[folderName]
                    GuiAnim.Vibrate(header)
                    SetWarningBorder(header)
                    GuiAnim.PulseBorder(header, 2)
                end
                return false, "folder '" .. folderName .. "' has no export type defined"
            else
                if presetHeaders[folderName] then
                    ClearWarningBorder(presetHeaders[folderName])
                end
            end
        end

        for i = #(exportSettings.MaterialPresets), 1, -1 do
            local preset = exportSettings.MaterialPresets[i]

            if preset.Deleted then
                table.remove(exportSettings.MaterialPresets, i)
            end
        end

        return true
    end

    local function rerenderFolders() end

    local refreshExport = RenderExportSettingPanel(exportCell, exportSettings)

    local refreshImport = function () end
    if not notRenderImport then
        local importWindow = exportCell:AddChildWindow("ImportCCAWindow")
        refreshImport = self:RenderImportSection(importWindow, exportSettings, function()
            Debug("MaterialPresetsMenu: Refreshing export settings after CCA import.")
            refreshExport()
            rerenderFolders()
        end)
    end

    local topOpeTab = infoTab.TitleCell:AddTable("PresetTypesTopTab", 2)
    topOpeTab.ColumnDefs[1] = { WidthStretch = true }
    topOpeTab.ColumnDefs[2] = { WidthFixed = true }

    local topRow = topOpeTab:AddRow()

    local leftCell, rightCell = topRow:AddCell(), topRow:AddCell()

    local progressBar = leftCell:AddProgressBar("ss##ExportProgressBar") --[[@as ExtuiProgressBar]]
    progressBar.SameLine = true

    StyleHelpers.SetNormalProgressBarStyle(progressBar)
    local exportBtn = nil --[[@type ExtuiButton]]
    local exportTT = nil --[[@type ExtuiText]]
    exportBtn = rightCell:AddButton("Export")
    exportBtn:SetStyle("FrameBorderSize", 2)

    exportBtn.OnClick = function(sel)
        local exportable, reason = checkIfExportable()

        if not exportable then
            exportBtn.OnHoverEnter()
            refreshExport()
            GuiAnim.Vibrate(exportBtn)
            exportTT.Label = "Cannot export material presets: " .. reason
            return
        end

        progressBar.Value = 0
        StyleHelpers.SetNormalProgressBarStyle(progressBar)
        parent.Disabled = true -- disable UI during export, avoid unexpected interactions
        self:ExportToMod(exportSettings, function(progress, message)
            exportTT.Label = "Exporting Material Presets... " ..
                tostring(progress) .. "% " .. (message and (" - " .. message) or "")

            if progress > 0 then
                progressBar.Value = progress / 100
                progressBar.Overlay = message or ""

                if progress >= 100 then
                    refreshImport()
                    parent.Disabled = false -- re-enable UI after export
                end
            elseif progress < 0 then
                progressBar.Value = 1
                progressBar.Overlay = message and (" - " .. message) or ""
                StyleHelpers.SetWarningProgressBarStyle(progressBar)

                parent.Disabled = false
            end
        end)
    end

    exportBtn.OnRightClick = function ()
        local exportable, reason = checkIfExportable()

        if not exportable then
            exportBtn.OnHoverEnter()
            refreshExport()
            GuiAnim.Vibrate(exportBtn)
            exportTT.Label = "Cannot export material presets: " .. reason
            return
        end

        self:SaveModCache(exportSettings)
        self:SaveModCacheRef()
    end

    local exportTooltip = exportBtn:Tooltip()
    exportTooltip:SetStyle("FrameBorderSize", 2)
    exportTooltip:SetStyle("WindowBorderSize", 2)
    exportTT = exportBtn:Tooltip():AddText("Click: Export material presets to Realm_Builder/CC_Mods/\nRight Click: Save to CCA Cache for Importing Later")

    exportBtn.OnHoverEnter = function()
        local exportable, reason = checkIfExportable()
        if not exportable then
            refreshExport()
            ApplyWarningTooltipStyle(exportTooltip)
            exportTT.Label = "Cannot export material presets: " .. reason
            ApplyWarningButtonStyle(exportBtn)
        else
            ApplyOkTooltipStyle(exportTooltip)
            exportTT.Label = "Click: Export material presets to Realm_Builder/CC_Mods/\nRight Click: Save to CCA Cache for Importing Later"
            ApplyOkButtonStyle(exportBtn)
        end
    end

    local presetWin = presetTabCell:AddChildWindow("PresetsTableWindow")
    local presetTab = presetWin:AddTable("PresetFolderParentTab", 1)
    presetTab.BordersInner = true
    presetTab.RowBg = true

    rerenderFolders = self:RenderFolderPanel(presetTab, presetHeaders, exportSettings)
    rerenderFolders()

    return exportSettings
end

local function makeFolderDisplay(open, folderName, preseType)
    local label = (open and "[-]" or "[+]") .. " " .. folderName .. " "
    if preseType then
        label = label .. " (" .. (difineToDisplay[preseType] or "Undefined") .. ")"
    else
        label = label .. " (Undefined)"
    end
    return label .. "##MaterialPresetFolderHeader_" .. folderName
end

--- @param row ExtuiTableRow
--- @param color any
local function setRowColor(row, color)
    --row:SetColor("TableRowBg", color)
    --row:SetColor("TableRowBgAlt", color)
    row:SetColor("TableRowBg", AdjustColor(color, -0.2, -0.2, -0.4))
    row:SetColor("TableRowBgAlt", AdjustColor(color, -0.2, -0.2, -0.4))
    row:SetColor("TableHeaderBg", AdjustColor(color, -0.2, nil, -0.5))
end

function MaterialPresetsMenu:RenderFolderPanel(presetTab, presetHeaders, exportSettings)
    local presetRows = {}
    local openedFolders = {}
    local newFolderRow = nil

    local rerender
    function rerender()
        for _, row in pairs(presetRows or {}) do
            row:Destroy()
        end
        if newFolderRow then
            newFolderRow:Destroy()
            newFolderRow = nil
        end
        presetRows = {}
        for k, header in pairs(presetHeaders or {}) do
            presetHeaders[k] = nil
        end

        local sorted = {}
        for folderName, _ in pairs(exportSettings.Folders) do
            table.insert(sorted, folderName)
        end
        table.sort(sorted)
        local refreshFolderList = {}
        for _, folderName in pairs(sorted) do
            local folderRow
            folderRow = self:RenderFolderRow(presetTab, folderName, openedFolders, presetHeaders, exportSettings, refreshFolderList, function ()
                presetRows[folderName]:Destroy()
                presetRows[folderName] = nil
            end)
            presetRows[folderName] = folderRow
        end

        newFolderRow = presetTab:AddRow()
        local newFolderCell = newFolderRow:AddCell()
        local createFolderBtn = newFolderCell:AddButton("+ New Folder##CreateMaterialPresetFolderBtn")

        createFolderBtn.OnClick = function()
            local folderName = "merged"
            local suffix = 1
            while exportSettings.Folders[folderName] do
                suffix = suffix + 1
                folderName = "merged" .. tostring(suffix)
            end
            exportSettings.Folders[folderName] = {}
            exportSettings.FolderDefinitions[folderName] = {}
            openedFolders[folderName] = true
            rerender()
        end
    end

    return rerender
end

--- @param presetTab ExtuiTable
--- @param folderName string
--- @param openedFolders table<string, boolean>
--- @param presetHeaders table<string, ExtuiColorEdit>
--- @param exportSettings CCMod_Pack
--- @param refreshFolderList table<string, fun()>
--- @param onDelete fun()
--- @return ExtuiTableRow
function MaterialPresetsMenu:RenderFolderRow(presetTab, folderName, openedFolders, presetHeaders, exportSettings, refreshFolderList, onDelete)
    local folderObj = exportSettings.Folders[folderName]
    local folderRow = presetTab:AddRow()
    local folderCell = folderRow:AddCell()
    local folderColorBox = folderCell:AddColorEdit("##FolderColorBox_" .. folderName) --[[@as ExtuiColorEdit]]
    local folderDef = exportSettings.FolderDefinitions[folderName]
    local folderHeader = folderCell:AddSelectable(makeFolderDisplay(openedFolders[folderName], folderName,
        folderDef.ExportType)) --[[@as ExtuiSelectable]]
    presetHeaders[folderName] = folderColorBox

    folderColorBox:SetStyle("FrameBorderSize", 2)
    if folderDef.ExportType then
        ClearWarningBorder(presetHeaders[folderName])
        setRowColor(folderRow, exportColor)
    else
        SetWarningBorder(presetHeaders[folderName])
        setRowColor(folderRow, disabledColor)
    end

    folderColorBox.NoInputs = true
    folderColorBox.CanDrag = true
    folderColorBox.DragDropType = MATERIALPRESET_DRAGDROP_TYPE
    folderColorBox.Color = folderDef.UIColor or { 0.5, 0.5, 0.5, 1 }
    folderColorBox.OnChange = function()
        folderDef.UIColor = folderColorBox.Color
        setRowColor(folderRow, folderDef.UIColor)
    end

    if folderDef.UIColor then
        setRowColor(folderRow, folderDef.UIColor)
    end

    folderColorBox.OnDragStart = function()
        folderColorBox.UserData = {
            UIColor = folderColorBox.Color,
        }
        local pb = folderColorBox.DragPreview:AddColorEdit("##FolderColorBoxDragPreview_" .. folderName)
        pb.NoInputs = true
        pb.Color = folderColorBox.Color
    end

    folderHeader.SameLine = true

    local folderManagePopup = folderCell:AddPopup("MaterialPresetFolderManagePopup_" .. folderName)
    local folderTable = AddIndent(folderCell):AddTable("FolderTable_" .. folderName, 3)
    folderTable.Visible = openedFolders[folderName] or false
    folderTable.UserData = {}
    folderTable.UserData.Header = folderHeader

    folderHeader.OnClick = function()
        folderHeader.Selected = false
        folderTable.Visible = not folderTable.Visible
        openedFolders[folderName] = folderTable.Visible
        folderHeader.Label = makeFolderDisplay(folderTable.Visible, folderName, folderDef.ExportType)
    end

    folderHeader.OnRightClick = function()
        folderManagePopup:Open()
    end

    local function refreshFolder() end
    folderHeader.UserData = {
        Opened = openedFolders,
        Delete = function()
            local toDelete = {}
            for guid, _ in pairs(folderObj) do
                table.insert(toDelete, guid)
            end
            for _, guid in pairs(toDelete) do
                exportSettings.MaterialPresets[guid] = nil
            end
            exportSettings.Folders[folderName] = nil
            exportSettings.FolderDefinitions[folderName] = nil
            refreshFolderList[folderName] = nil
            folderCell:Destroy()
            onDelete()
        end,
        Update = function(newName)
            newName = newName or folderName
            refreshFolderList[newName] = refreshFolderList[folderName]
            presetHeaders[newName] = presetHeaders[folderName]
            folderName = newName
            folderHeader.Label = makeFolderDisplay(openedFolders[folderName], folderName, folderDef.ExportType)
            if folderDef.ExportType then
                --setRowColor(folderRow, exportColor)
                ClearWarningBorder(presetHeaders[newName])
            end
        end,
    }

    folderHeader.DragDropType = MATERIALPRESET_DRAGDROP_TYPE
    folderHeader.OnDragDrop = function(sel, drop)
        if drop.UserData and drop.UserData.Parameters then
            local guid = drop.UserData.Uuid
            if folderObj[guid] then
                -- already in this folder
                return
            end

            -- in this workspace, move to this folder
            if drop.UserData.Uuid and exportSettings.MaterialPresets[drop.UserData.Uuid] then
                -- remove from old folder
                local oldFolder = nil
                for fName, fObj in pairs(exportSettings.Folders) do
                    if fObj[drop.UserData.Uuid] then
                        oldFolder = fName
                        break
                    end
                end
                exportSettings.Folders[oldFolder][drop.UserData.Uuid] = nil
                exportSettings.Folders[folderName][drop.UserData.Uuid] = "end"
                if refreshFolderList[oldFolder] then
                    refreshFolderList[oldFolder]()
                end

                refreshFolder()
                return
            end

            -- not in this workspace, create new preset in this folder
            guid = Uuid_v4()
            local newPreset = {
                DisplayName = drop.UserData.DisplayName or "Unnamed Preset",
                UIColor = DeepCopy(drop.UserData.UIColor or { 1, 1, 1, 1 }),
                Parameters = DeepCopy(drop.UserData.Parameters or {}),
            }

            exportSettings.MaterialPresets[guid] = newPreset
            folderObj[guid] = "end"
            refreshFolder()
        end
    end
    folderColorBox.OnDragDrop = folderHeader.OnDragDrop

    self:RenderFolderManagePopup(folderManagePopup, folderName, folderHeader, exportSettings)
    refreshFolder = self:RenderFolder(folderTable, folderObj, exportSettings.MaterialPresets, folderName)
    refreshFolderList[folderName] = refreshFolder

    return folderRow
end

function MaterialPresetsMenu:LoadSaveFromCache()
    local locStr = Ext.IO.LoadFile(RealmPath.GetCCAModCacheRefPath())
    local cache = locStr and Ext.Json.Parse(locStr) or {}
    self.cachedMods = {}

    for modName, modData in pairs(cache or {}) do
        self.cachedMods[modName] = {
            ModuleUUID = modData.ModuleUUID,
            Versions = {},
            Cache = {},
        }
        for version, _ in pairs(modData.Versions or {}) do
            self.cachedMods[modName].Versions[version] = true
        end
    end
end

---@param parent ExtuiTreeParent
---@param exportSettings CCMod_Pack
---@param onImportComplete fun()
function MaterialPresetsMenu:RenderImportSection(parent, exportSettings, onImportComplete)
    local openedTrees = {}
    local refreshCached

    local function import(modName, version)
        local ccaModPack = self:ImportFromFile(modName, version)
        if not ccaModPack then
            self.cachedMods[modName].Cache[version] = nil
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
        exportSettings.Folders = DeepCopy(ccaModPack.Folders or {})
        exportSettings.FolderDefinitions = DeepCopy(ccaModPack.FolderDefinitions or {})

        Debug("MaterialPresetsMenu: Imported CCA mod pack for mod " .. modName .. " version " .. version)
        onImportComplete()
    end

    local setupVersionPopups
    local function renderVersionTable(group, modName, versions)
        local sortedVersions = {}

        for version,_ in pairs(versions) do
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
            
            local versionPopup = nil
            versionSel.OnClick = function()
                versionSel.Selected = false
                if not versionPopup then
                    versionPopup = setupVersionPopups(cell, modName, version)
                end
                versionPopup:Open()
            end
            versionSel.OnRightClick = function()
                versionSel.Selected = false
                if not versionPopup then
                    versionPopup = setupVersionPopups(cell, modName, version)
                end
                versionPopup:Open()
            end
        end
    end

    function setupVersionPopups(cell, modName, version)
        local versionPopup = cell:AddPopup("ImportCCAModVersionPopup_" .. modName .. "_" .. version)
        local selectTable = versionPopup:AddTable("ImportCCAModVersionSelectTable_" .. modName .. "_" .. version, 1)
        selectTable.BordersInnerH = true
        local selectRow = selectTable:AddRow()

        local importBtnCell = selectRow:AddCell()
        local importBtn = AddSelectableButton(importBtnCell, "Import##ImportCCAModVersionBtn_" .. modName .. "_" .. version, function ()
            import(modName, version)
        end)
        importBtn:Tooltip():SetStyle("WindowBorderSize", 2)
        importBtn:Tooltip():SetColor("Border", HexToRGBA("FFFF0000"))
        importBtn:Tooltip():AddText("CAUTION:"):SetColor("Text", HexToRGBA("FFFF0000"))
        importBtn:Tooltip():AddText("This will overwrite your current workspace settings!"):SetColor("Text", HexToRGBA("FFFFFFFF"))

        local deleteBtnCell = selectRow:AddCell()
        local deleteBtn = AddSelectableButton(deleteBtnCell, "Delete##DeleteCCAModVersionBtn_" .. modName .. "_" .. version, function ()
            if not self.cachedMods[modName] then return end
            self.cachedMods[modName].Versions[version] = nil
            self.cachedMods[modName].Cache[version] = nil
            self:SaveModCacheRef()
            refreshCached()
        end)
        ApplyDangerSelectableStyle(deleteBtn)

        local openInAnotherEditorBtnCell = selectRow:AddCell()
        local openInAnotherEditorBtn = AddSelectableButton(openInAnotherEditorBtnCell, "Open in Another Editor##OpenInCCACCMVersionBtn_" .. modName .. "_" .. version, function ()
            local ccaModPack = self:ImportFromFile(modName, version)
            if not ccaModPack then
                self.cachedMods[modName].Cache[version] = nil
                self:SaveModCacheRef()
                refreshCached()
                Warning("Failed to import CCA mod pack for mod " .. modName .. " version " .. version)
                return
            end
            ccaModPack = DeepCopy(ccaModPack)
            local versionStr = ccaModPack and BuildVersionString(ccaModPack.Version[1], ccaModPack.Version[2], ccaModPack.Version[3], ccaModPack.Version[4]) or version
            local newWindow = RegisterWindow("generic", ccaModPack.ModName .. " - " .. versionStr, "Character Creation Material Editor", nil, nil, { 1200 * SCALE_FACTOR, 900 * SCALE_FACTOR })
            newWindow.Closeable = true
            newWindow.OnClose = function()
                DeleteWindow(newWindow)
            end
            self:SetupWorkspace(newWindow, ccaModPack, true)
        end)

        return versionPopup
    end

    function refreshCached()
        DestroyAllChildren(parent)

        local cache = nil

        cache = self.cachedMods
        _D(cache)

        if not cache then
            cache = {}
        end

        local sortedModNames = {}
        for modName, _ in pairs(cache) do
            if CountMap(cache[modName].Versions) == 0 then
                cache[modName] = nil
                self.cachedMods[modName] = nil
            else
                table.insert(sortedModNames, modName)
            end
        end
        table.sort(sortedModNames)

        for _, modName in ipairs(sortedModNames) do
            local versions = cache[modName].Versions
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

            modNameSel.OnHoverEnter = function()
                renderVersionTable(group, modName, versions)
                modNameSel.OnHoverEnter = nil
            end
        end
    end

    refreshCached()

    return refreshCached
end

---@param popup ExtuiPopup
---@param folderName string
---@param folderSel ExtuiSelectable
---@param exportSettings CCMod_Pack
function MaterialPresetsMenu:RenderFolderManagePopup(popup, folderName, folderSel, exportSettings)
    local borderTab = popup:AddTable("##MaterialPresetFolderManagePopupBorderTable_" .. folderName, 1)
    borderTab.ColumnDefs[1] = { WidthFixed = true, Width = 600 * SCALE_FACTOR }
    local row = borderTab:AddRow()
    borderTab.BordersInnerH = true

    local renameCell = row:AddCell()
    local renameInput = renameCell:AddInputText("##MaterialPresetFolderRenameInput_" .. folderName)
    local confirmBtn = renameCell:AddButton("<##MaterialPresetFolderRenameBtn_" .. folderName)
    local warnText = renameCell:AddText("A folder with this name already exists.")
    warnText:SetColor("Text", HexToRGBA("FFFF0000"))
    warnText.Visible = false
    local exportTypeCombo = row:AddCell():AddCombo("##MaterialPresetFolderExportTypeCombo_" .. folderName)
    local deleteBtn = row:AddCell():AddButton("Delete Folder##MaterialPresetFolderDeleteBtn_" .. folderName)

    exportTypeCombo.Options = {
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
        ["CharacterCreationEyeColors"] = 1,
        ["CharacterCreationHairColors"] = 2,
        ["CharacterCreationSkinColors"] = 3,
    }

    local folderDef = exportSettings.FolderDefinitions[folderName]
    if folderDef.ExportType then
        exportTypeCombo.SelectedIndex = typeToIndex[folderDef.ExportType] - 1
    end
    exportTypeCombo.OnChange = function()
        local index = exportTypeCombo.SelectedIndex + 1
        folderDef.ExportType = indexToType[index]

        folderSel.UserData.Update()
    end

    confirmBtn.SameLine = true
    ApplyInfoButtonStyle(confirmBtn)
    renameInput.Hint = "Folder Name..."
    renameInput.Text = folderName

    renameInput:SetStyle("FrameBorderSize", 2)
    renameInput:SetColor("Text", HexToRGBA("FFFFFFFF"))
    renameInput:SetColor("Border", HexToRGBA("FF888888"))
    renameInput.OnChange = Debounce(50, function()
        local newName = renameInput.Text
        if not IsValidName(newName) then
            SetWarningBorder(renameInput)
            GuiAnim.PulseBorder(renameInput, 2)
            return
        end

        if exportSettings.Folders[newName] and newName ~= folderName then
            SetWarningBorder(renameInput)
            GuiAnim.PulseBorder(renameInput, 2)

            warnText.Visible = true
            Timer:After(1000, function(timerID)
                pcall(function()
                    warnText.Visible = false
                end)
            end)
            return
        end

        ClearWarningBorder(renameInput)
    end)

    local function rename() end
    confirmBtn.OnClick = function()
        rename()
    end
    function rename()
        local newName = renameInput.Text
        if newName == folderName then return end

        if not IsValidName(newName) then return end

        newName = newName:gsub("%s", "_")
        if exportSettings.Folders[newName] then
            SetWarningBorder(renameInput)
            GuiAnim.PulseBorder(renameInput, 2)
            warnText.Visible = true
            Timer:After(1000, function(timerID)
                pcall(function()
                    warnText.Visible = false
                end)
            end)
            Warning("A folder with the name '" .. newName .. "' already exists.")
            return
        end

        local opened = folderSel.UserData.Opened
        opened[newName] = opened[folderName]
        opened[folderName] = nil
        exportSettings.Folders[newName] = exportSettings.Folders[folderName]
        exportSettings.FolderDefinitions[newName] = exportSettings.FolderDefinitions[folderName]
        exportSettings.Folders[folderName] = nil
        exportSettings.FolderDefinitions[folderName] = nil

        folderSel.UserData.Update(newName)
        renameInput.Text = newName
    end

    ApplyDangerButtonStyle(deleteBtn)
    deleteBtn.OnClick = function()
        folderSel.UserData.Delete()
    end
end

local folderNameComparator = function(a, b)
    return a.DisplayName < b.DisplayName
end

local folderColorComparator = function(a, b)
    return colorPresetComparator(a, b, a.DisplayName, b.DisplayName)
end

local folderColComparator = {
    ["Name"] = folderNameComparator,
    ["Color"] = folderColorComparator,
}

---@param parentTab ExtuiTable
---@param folderObj table<string, any>
---@param matPresets table<string, MaterialPresetData>
function MaterialPresetsMenu:RenderFolder(parentTab, folderObj, matPresets)
    parentTab.ShowHeader = true

    --- @type ExtuiColumnDefinition
    parentTab.ColumnDefs[1] = { WidthFixed = true, Name = "Color" }
    parentTab.ColumnDefs[2] = { WidthStretch = true, Name = "Name" }
    parentTab.ColumnDefs[3] = { WidthFixed = true }

    local function refreshFolderList() end
    local comparator = function(a, b)
        local apre = matPresets[a]
        local bpre = matPresets[b]

        return folderNameComparator(apre, bpre)
    end

    parentTab.Sortable = true
    parentTab.OnSortChanged = function()
        local sortSpec = parentTab.Sorting[1]
        local colIndex = sortSpec.ColumnIndex + 1
        local colDef = parentTab.ColumnDefs[colIndex].Name
        local colComparator = folderColComparator[colDef] or folderNameComparator
        comparator = function(a, b)
            local apre = matPresets[a]
            local bpre = matPresets[b]

            if sortSpec.Direction == "Ascending" then
                return colComparator(apre, bpre)
            else
                return colComparator(bpre, apre)
            end
        end

        refreshFolderList()
    end

    local rows = {}
    function refreshFolderList()
        for _, row in pairs(rows) do
            row:Destroy()
        end
        rows = {}
        local guids = {}
        for guid, _ in pairs(folderObj) do
            table.insert(guids, guid)
        end

        table.sort(guids, comparator)

        for _, guid in pairs(guids) do
            local row = self:RenderExportPresetRow(parentTab, matPresets[guid], guid, function()
                folderObj[guid] = nil
                matPresets[guid] = nil
                rows[guid] = nil
            end)
            rows[guid] = row
        end
    end

    refreshFolderList()

    return refreshFolderList
end

---@param parentTab ExtuiTable
---@param obj MaterialPresetData
---@param onDelete fun()
function MaterialPresetsMenu:RenderExportPresetRow(parentTab, obj, uuid, onDelete)
    local row = parentTab:AddRow()

    local uiColorCell = row:AddCell()
    local nameCell = row:AddCell()
    local manageCell = row:AddCell()

    local colorBox = uiColorCell:AddColorEdit("##" .. obj.DisplayName)
    local nameInput = nameCell:AddInputText("##" .. obj.DisplayName .. "NameInput", obj.DisplayName)
    local manageBtn = manageCell:AddButton("···##" .. obj.DisplayName)

    colorBox.Color = obj.UIColor
    colorBox.NoInputs = true
    colorBox.CanDrag = true
    colorBox.DragDropType = MATERIALPRESET_DRAGDROP_TYPE
    nameInput.SameLine = true
    nameInput.Hint = "Preset Name..."
    nameInput:SetStyle("FrameBorderSize", 2)
    nameInput.OnChange = function()
        if nameInput.Text ~= "" then
            obj.DisplayName = nameInput.Text
        end
    end
    ClearWarningBorder(nameInput)

    colorBox.OnChange = function()
        obj.UIColor = colorBox.Color
    end

    local managePopup = manageCell:AddPopup("ManageSelectedPresetPopup##" .. obj.DisplayName)
    colorBox.OnRightClick = function()
        managePopup:Open()
    end

    colorBox.OnDragStart = function(sel)
        sel.UserData = {
            Parameters = obj.Parameters,
            UIColor = obj.UIColor,
            DisplayName = obj.DisplayName,
            Uuid = uuid,
        }
        local colorPreview = sel.DragPreview:AddColorEdit("##PreviewColorBox")
        colorPreview.Color = obj.UIColor
        colorPreview.NoInputs = true
        sel.DragPreview:AddText(obj.DisplayName).SameLine = true
    end

    colorBox.OnDragDrop = function(sel, drop)
        sel.UserData = sel.UserData or {}
        if drop.UserData and drop.UserData.Uuid then
            local header = parentTab.UserData.Header
            if header then
                header.OnDragDrop(header, drop)
                return
            end
        end

        if drop.UserData and drop.UserData.Parameters then
            obj.Parameters = DeepCopy(drop.UserData.Parameters or {})
            if drop.UserData.UIColor then
                local oriColor = DeepCopy(obj.UIColor)
                obj.UIColor = DeepCopy(drop.UserData.UIColor or { 1, 1, 1, 1 })
                colorBox.Color = obj.UIColor
                if EqualArrays(oriColor, obj.UIColor) then
                    GuiAnim.FlashColor(colorBox)
                else
                    GuiAnim.Blend(colorBox, oriColor, obj.UIColor)
                end
            else
                GuiAnim.FlashColor(colorBox)
            end
            return
        end

        if drop.UserData and drop.UserData.UIColor then
            local oriColor = DeepCopy(obj.UIColor)
            obj.UIColor = DeepCopy(drop.UserData.UIColor or { 1, 1, 1, 1 })
            colorBox.Color = obj.UIColor
            GuiAnim.Blend(colorBox, oriColor, obj.UIColor)
            return
        end
    end

    nameInput.DragDropType = MATERIALPRESET_DRAGDROP_TYPE
    nameInput.CanDrag = true
    nameInput.OnDragStart = colorBox.OnDragStart
    nameInput.OnDragDrop = colorBox.OnDragDrop

    row.DragDropType = MATERIALPRESET_DRAGDROP_TYPE
    row.CanDrag = true
    row.OnDragStart = colorBox.OnDragStart
    row.OnDragDrop = colorBox.OnDragDrop

    manageBtn.OnClick = function(btn)
        managePopup:Open()
    end

    local selectTable = managePopup:AddTable("ManageSelectedPresetTable", 1)
    selectTable.BordersInnerH = true
    local selectRow = selectTable:AddRow()
    local deleteBtn = AddSelectableButton(selectRow:AddCell(), "Remove Preset##" .. obj.DisplayName, function(sel)
        obj.Deleted = true
        onDelete()
        row:Destroy()
    end)

    ApplyDangerSelectableStyle(deleteBtn)

    local openMatMixerBtn = AddSelectableButton(selectRow:AddCell(), "Material Mixer ##" .. obj.DisplayName,
        function(sel)
            local materialMixer = MaterialMixerTab.new(obj.Parameters)
            materialMixer:Render()
        end)

    return row
end

--- simply load from CCA_Cache folder
---@param modName string
---@param version vec4|string
---@return CCMod_Pack?
function MaterialPresetsMenu:ImportFromFile(modName, version)
    modName = modName:gsub("%s+", "_")
    local versionStr = type(version) == "table" and BuildVersionString(version[1], version[2], version[3], version[4]) or
        tostring(version)

    if self.cachedMods and self.cachedMods[modName] and self.cachedMods[modName].Cache then
        local cachedMod = self.cachedMods[modName].Cache[versionStr]
        if cachedMod then
            return cachedMod
        end
    end

    local moduleID = self.cachedMods and self.cachedMods[modName] and self.cachedMods[modName].ModuleUUID or nil 
    local filePath = RealmPath.GetCCAModCachePath(moduleID, version)

    local jsonStr = Ext.IO.LoadFile(filePath)

    if not jsonStr then
        Warning("ImportFromFile: Failed to load CCA mod cache file at " .. filePath)
        return nil
    end

    local cacheFile = Ext.Json.Parse(jsonStr) --- @type CCMod_Pack

    if not cacheFile or not cacheFile.MaterialPresets then
        Warning("ImportFromFile: Invalid CCA mod cache file at " .. filePath)
        return nil
    end

    self.cachedMods[modName].Cache[versionStr] = cacheFile

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

---@param modPack CCMod_Pack
---@param progressCallback fun(progress:number, message:string?)
function MaterialPresetsMenu:__exportToMod(modPack, progressCallback)
    local startTime = Ext.Timer.MonotonicTime()
    local suc = true

    local lastYieldTime = startTime
    -- capture the export coroutine so callbacks can check/resume the correct coroutine
    local exportThread = coroutine.running()
    progressCallback = progressCallback or function(progress, message)
        Debug("MaterialPresetsMenu: ExportToMod Progress: " .. tostring(progress) .. "% " .. (message and (" - " .. message) or ""))
    end

    local displayModName = modPack.ModName or "Unnamed Mod"
    local modInternalName = ValidateFolderName(displayModName)
    local authorName = modPack.Author
    local description = modPack.Description
    local version = modPack.Version
    local matPresets = modPack.MaterialPresets
    local folders = modPack.Folders or {}
    local existUuid = modPack.ModuleUUID --[[@type GUIDSTRING?]]
    local folderDefs = modPack.FolderDefinitions or {}

    local presetCnt = CountMap(matPresets)
    local folderCnt = CountMap(folders)

    if not existUuid and self.cachedMods and self.cachedMods[modInternalName] then
        existUuid = self.cachedMods[modInternalName].ModuleUUID
    end

    local actionCnt =
        1 +         -- meta.lsx
        1 +         -- localization.xml
        presetCnt + -- building material preset resource nodes
        folderCnt + -- saving material preset banks
        presetCnt + -- building character creation color
        3 +         -- saveing character creation color
        1 +         -- save mod cache file
        1           -- save mod cache ref file

    local progress = 0
    local progressStep = 100 / actionCnt

    local yieldThreshold = 5 -- ms

    local function throwError(message)
        progress = -1
        Warning("MaterialPresetsMenu: ExportToMod Error: " .. message)
        progressCallback(progress, message)
        local running = coroutine.running()
        if running and running == exportThread then
            coroutine.yield()
        end
    end

    local function yieldyield()
        if Ext.Timer.MonotonicTime() - lastYieldTime < yieldThreshold then return end

        local thread = exportThread
        Timer:Ticks(5, function()
            if thread and coroutine.status(thread) == "suspended" then
                local sucr, err = coroutine.resume(thread)
                if not sucr then
                    throwError("ExportToMod: Error resuming coroutine: " .. tostring(err))
                    Ext.Debug.DumpStack()
                end
            else
                Warning("MaterialPresetsMenu: ExportToMod coroutine not in suspended state after yield, cannot resume.")
            end
        end)
        coroutine.yield()
        lastYieldTime = Ext.Timer.MonotonicTime()
    end

    local function advance(message)
        --Debug("MaterialPresetsMenu: Current Export Progress: " .. tostring(progress) .. "% " .. (message and (" - " .. message) or ""))
        progress = progress + progressStep
        progressCallback(math.min(progress, 100), message)
        yieldyield()
    end

    local function saveFile(path, string)
        suc = Ext.IO.SaveFile(path, string)
        if not suc then throwError("ExportToMod: Failed to save file at " .. path) end
        yieldyield()
    end

    local function completeAdvance(message)
        Debug("MaterialPresetsMenu: Export Complete: " ..
            tostring(progress) .. "% " .. (message and (" - " .. message) or ""))
        progress = 100
        progressCallback(progress, message)
    end

    if not IsUuid(existUuid) then
        existUuid = nil
    end

    -- sanitize mod internal name
    local internalNames = {}
    for _, preset in pairs(matPresets) do
        internalNames[preset] = preset.DisplayName:gsub("%s+", "_")
    end

    -- prefer reusing the existing ModuleUUID, so the game recognizes this as the same mod.
    local modUuid = existUuid and existUuid or Uuid_v4()
    modPack.ModuleUUID = modUuid

    --- build mod meta.lsx first
    local metaLsx = LSXHelpers.BuildModMeta(modUuid, displayModName, modInternalName, authorName, version, description)
    local mataFilePath = RealmPath.GetCCAModMetaPath(modInternalName)

    saveFile(mataFilePath, metaLsx:Stringify({ Indent = 4 }))
    advance("Saved mod meta file.")

    --- build localization file first because CC presets need it
    local names = {}

    for _, preset in pairs(matPresets) do
        if preset.DisplayName and not preset.Disabled then
            table.insert(names, preset.DisplayName)
        end
    end

    local locaLsx, stringToHandles = LSXHelpers.GenerateLocalization(names, 1)

    local locaFilePath = RealmPath.GetCCALocalizationPath(modInternalName, "English") -- currently assume English only

    saveFile(locaFilePath, locaLsx)
    advance("Saved localization file.")

    --- build material presets file first because CC presets need it
    local cheapName = {
        CharacterCreationEyeColors = "_EyeColor_",
        CharacterCreationHairColors = "_HairColor_",
        CharacterCreationSkinColors = "_SkinColor_",
    }

    local banks = {}
    local matPresetDefs = {}

    -- build material preset banks
    for folderName, folderObj in pairs(folders) do
        local bank = LSXHelpers.BuildMaterialPresetBank()
        banks[folderName] = bank
        for presetGuid, _ in pairs(folderObj) do
            local preset = matPresets[presetGuid]
            local presetType = folderDefs[folderName] and folderDefs[folderName].ExportType
            if not presetType then throwError("ExportToMod: No preset type defined for folder '" .. folderName .. "'") end
            matPresetDefs[presetGuid] = presetType

            local internalName = modInternalName .. cheapName[presetType] .. internalNames[preset]
            local presetNode = ResourceHelpers.BuildMaterialPresetResourceNode(preset.Parameters, presetGuid, internalName)

            bank:AppendChild(presetNode)

            advance("Building material preset banks resource nodes...")
        end
    end

    -- export material preset banks
    for folderName, bank in pairs(banks) do
        local def = folderDefs[folderName]
        if bank:CountChildren() > 0 then
            local presetType = def.ExportType
            local matPresetFile = RealmPath.GetCCAMaterialPresetsFile(presetType, modInternalName, folderName) --[[@as string]]

            saveFile(matPresetFile, bank:Stringify({ Indent = 4, AutoFindRoot = true }))
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
        ccaDefNode[presetType] = LSXHelpers.BuildCCColorRegionNode(presetType)
    end

    -- cheap way to identify dragonborn skin types
    local dragonbornPrefixes = {
        "acc_",
        "sk_",
        "sc_"
    }

    local function checkIfDragonbornSkinType(paramName)
        for _,prefix in pairs(dragonbornPrefixes) do
            if StartWith(paramName, prefix) then
                return true
            end
        end
        return false
    end

    local function checkParamsIsDragonbornSkinType(params)
        for paramType,par in pairs(params) do
            for paramName,_ in pairs(par) do
                if checkIfDragonbornSkinType(paramName) then
                    return true
                end
            end
        end
        return false
    end

    for uuid, preset in pairs(matPresets) do
        local presetType = matPresetDefs[uuid]
        local ccaPresetNode = ccaDefNode[presetType]

        local internalName = modInternalName .. cheapName[presetType] .. internalNames[preset]
        local ccaPresetUuid = Uuid_v4()

        local handle = table.remove(stringToHandles[preset.DisplayName]) -- use one handle per preset

        local presetNode = LSXHelpers.BuildCCColorNode(handle, internalName, preset.UIColor, uuid, ccaPresetUuid, presetType)
        ccaPresetNode:AppendChild(presetNode)
        
        if presetType == "CharacterCreationSkinColors" then
            local isDragonbornSkinType = checkParamsIsDragonbornSkinType(preset.Parameters)
            if isDragonbornSkinType then
                local dragonbornAttr = LSXHelpers.AttrNode("SkinType", "FixedString", "Dragonborn")
                presetNode:AppendChild(dragonbornAttr)
            end
        end

        advance("Building CCA presets definition...")
    end

    -- export CC presets definition file
    for presetType, def in pairs(ccaDefNode) do
        if def:CountChildren() > 0 then
            local ccaFilePath = RealmPath.GetCCAPresetsFile(presetType, modInternalName) --[[@as string]]

            saveFile(ccaFilePath, def:Stringify({ Indent = 4, AutoFindRoot = true }))
        end
        advance("Saving CCA presets definition...")
    end

    local endTime = Ext.Timer.MonotonicTime()
    Debug("ExportToMod: Exported to mod '" .. modInternalName .. "' in " .. tostring(endTime - startTime) .. " ms,")

    --- unserialize xml is possible but for sanity we just save a json cache file
    suc = self:SaveModCache(modPack)
    if not suc then
        throwError("ExportToMod: Failed to save CCA mod cache file at " ..
            RealmPath.GetCCAModCachePath(modInternalName, version))
    end

    advance("Saved CCA mod cache file.")

    suc = self:SaveModCacheRef()
    if not suc then throwError("ExportToMod: Failed to save CCA mod cache reference file.") end
    advance("Saved CCA mod cache reference file.")

    completeAdvance("Export complete !")
end

---@param modPack CCMod_Pack
---@return boolean
function MaterialPresetsMenu:SaveModCache(modPack)
    local cacheFile = DeepCopy(modPack)
    local modInternalName = modPack.ModName:gsub("%s+", "_")
    local version = modPack.Version
    local moduleID = modPack.ModuleUUID
    local jsonStr = Ext.Json.Stringify(cacheFile, { Indent = 4 })
    local filePath = RealmPath.GetCCAModCachePath(moduleID, version)

    self.cachedMods[modInternalName] = self.cachedMods[modInternalName] or {}
    self.cachedMods[modInternalName].ModuleUUID = moduleID
    self.cachedMods[modInternalName].Cache = self.cachedMods[modInternalName].Cache or {}
    local versionStr = type(version) == "table" and BuildVersionString(version[1], version[2], version[3], version[4]) or
        tostring(version)
    self.cachedMods[modInternalName].Cache[versionStr] = cacheFile
    self.cachedMods[modInternalName].Versions = self.cachedMods[modInternalName].Versions or {}
    self.cachedMods[modInternalName].Versions[versionStr] = {
        MaterialPresetCount = CountMap(cacheFile.MaterialPresets or {}),
    }

    return Ext.IO.SaveFile(filePath, jsonStr)
end

function MaterialPresetsMenu:SaveModCacheRef(modUuid)
    local allRefs = {}
    for modName, modCache in pairs(self.cachedMods) do
        local versions = {}
        allRefs[modName] = {
            ModuleUUID = modUuid or modCache.ModuleUUID,
            Versions = versions,
        }
        for version, cache in pairs(modCache.Cache) do
            versions[version] = {
                MaterialPresetCount = CountMap(cache.MaterialPresets or {}),
            }
        end
    end

    return Ext.IO.SaveFile(RealmPath.GetCCAModCacheRefPath(), Ext.Json.Stringify(allRefs, { Indent = 4 }))
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

    searchInput.OnChange = Debounce(10, function()
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
