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
--- @field cachedMods table<string, RB_CCMod_Pack>
--- @field UpdateCustomMaterialPresetsList fun(self:MaterialPresetsMenu)
--- @field SaveMaterialPreset fun(self:MaterialPresetsMenu, mat:MaterialEditor)
--- @field RenderPresetColorBox fun(self:MaterialPresetsMenu, preset:ResourceCharacterCreationColor, parent:ExtuiTreeParent):ExtuiColorEdit
--- @field RenderCustomColorBox fun(self:MaterialPresetsMenu, preset:MaterialPresetData, parent:ExtuiTreeParent):ExtuiColorEdit
--- @field RenderCCPresetList fun(self:MaterialPresetsMenu, presetName:string, parent:ExtuiTreeParent)
MaterialPresetsMenu = MaterialPresetsMenu or {}

local function colorPresetComparator(a,b, aName, bName)
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

    self.cachedMods = {} --- @type table<string, RB_CCMod_Pack>

    self.isVisible = true
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

    infoTab.ColumnDefs[1] = { WidthStretch = true }
    infoTab.ColumnDefs[2] = { WidthFixed = true }

    infoTab.BordersInnerV = true

    --- @type RB_CCMod_Pack
    local exportSettings = ccaModPack or { 
        ModName = "",
        Author = "",
        Description = "",
        Version = {1,0,0,0},
        MaterialPresets = {},
    }

    local function checkIfExportable()
        if not exportSettings.ModName or exportSettings.ModName == "" then return false, "no mod name" end
        if not exportSettings.Author or exportSettings.Author == "" then return false, "no author" end
        if #(exportSettings.MaterialPresets) == 0 then return false, "no presets" end

        for i=#(exportSettings.MaterialPresets),1,-1 do
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
                    return false, preset.DisplayName .. "preset with no export type"
                end
            end

            ::continue::
        end

        return true
    end

    local function refreshSelectedList()
        -- declaration
    end

    local exportCell = mainRow:AddCell()
    local refreshExport = self:RenderExportSettingPanel(exportCell, exportSettings)

    local importWindow = exportCell:AddChildWindow("ImportCCAWindow")
    local refreshImport = self:RenderImportCCASection(importWindow, exportSettings, function ()
        refreshExport()
        refreshSelectedList()
    end)
    
    local presetTabCell = mainRow:AddCell()

    local topOpeTab = presetTabCell:AddTable("PresetTypesTopTab", 2)
    topOpeTab.ColumnDefs[1] = { WidthStretch = true }
    topOpeTab.ColumnDefs[2] = { WidthFixed = true }

    local topRow = topOpeTab:AddRow()

    local leftCell,rightCell = topRow:AddCell(), topRow:AddCell()

    local namePrior = false
    local sortButton = leftCell:AddButton("Hue##ExportPresetSort")
    local stooltip = sortButton:Tooltip():AddText("Sort presets by Hue")

    sortButton.OnClick = function ()
        namePrior = not namePrior
        refreshSelectedList()
        stooltip.Label = namePrior and "Sort presets by Name" or "Sort presets by Hue"
        sortButton.Label = namePrior and "Name##ExportPresetSort" or "Hue##ExportPresetSort"
    end

    local saveButton = rightCell:AddButton("Save")
    saveButton.OnClick = function (sel)
        if not checkIfExportable() then
            GuiAnim.Vibrate(saveButton)
            return
        end

        local modName = exportSettings.ModName
        local authorName = exportSettings.Author
        local description = exportSettings.Description
        local version = exportSettings.Version
        local matPresets = DeepCopy(exportSettings.MaterialPresets)
        local uuid = exportSettings.ModuleUUID or Uuid_v4()

        if not IsUuid(uuid) then
            uuid = Uuid_v4()
        end

        self:SaveModCache(modName, authorName, description, version, matPresets, modName:gsub("%s+", "_"), uuid)

        Debug("MaterialPresetsMenu: Saved material presets to cache.")
    end

    local exportBtn = nil --[[@type ExtuiButton]]
    local exportTT = nil --[[@type ExtuiText]]
    exportBtn = rightCell:AddButton("Export") 
    
    exportBtn.OnClick = function (sel)        
        local exportable, reason = checkIfExportable()

        if not exportable then
            GuiAnim.Vibrate(exportBtn)
            exportTT.Label = "Cannot export material presets: " .. reason
            return
        end

        MaterialPresetsMenu:ExportToMod(exportSettings)
        refreshImport()
    end

    exportTT = exportBtn:Tooltip():AddText("Export material presets to Realm_Builder/CC_Mods/")

    exportBtn.OnHoverEnter = function ()
        if not checkIfExportable() then
            exportBtn:SetStyle("Alpha", 0.5)
            exportBtn:SetColor("Text", HexToRGBA("FFFF0000"))
            exportBtn:SetColor("Button", HexToRGBA("88FF0000"))
        else
            exportBtn:SetStyle("Alpha", 1)
            exportBtn:SetColor("Text", HexToRGBA("FF00CCCC"))
            exportBtn:SetColor("Button", HexToRGBA("8800CCCC"))
        end
    end

    local presetTab = presetTabCell:AddTable("PresetTypesTab", 5)

    presetTab.RowBg = true
    presetTab.Borders = true

    presetTab.ColumnDefs = {
        { WidthFixed = true },
        { WidthFixed = true },
        { WidthStretch = true },
        { WidthFixed = true },
        { WidthFixed = true },
    }

    local displayRow = presetTab:AddRow()

    displayRow:AddCell():AddText("Export")
    displayRow:AddCell():AddText("UI Color")
    displayRow:AddCell():AddText("Display Name")
    displayRow:AddCell():AddText("Export Type")
    displayRow:AddCell():AddText("Manage")
    
    local presetRow = presetTab:AddRow()

    local allRows = {} --- @type ExtuiTableRow[]

    function refreshSelectedList()
        for _,r in pairs(allRows) do
            r:Destroy()
        end

        local mPs = exportSettings.MaterialPresets

        table.sort(mPs, function (a, b)
            if namePrior then
                return a.DisplayName < b.DisplayName
            end

            return colorPresetComparator(a,b, a.DisplayName, b.DisplayName)
        end)

        for _,preset in pairs(mPs) do
            local r = self:RenderExportPresetRow(presetTab, preset)
            table.insert(allRows, r)
        end

        local emptyBox = presetRow:AddCell():AddColorEdit("Add##EmptyBox ")
        emptyBox.Color = {0,0,0,0}
        emptyBox.NoInputs = true
        emptyBox.NoPicker = true

        emptyBox:Tooltip():AddText("Drop Material Preset Here to Add to list")

        emptyBox.CanDrag = true
        emptyBox.DragDropType = MATERIALPRESET_DRAGDROP_TYPE

        emptyBox.OnDragDrop = function (sel, drop)
            if drop.UserData and drop.UserData.Parameters then
                local presetData = {
                    DisplayName = drop.UserData.DisplayName or "Unnamed Preset",
                    UIColor = DeepCopy(drop.UserData.UIColor or {1,1,1,1}),
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

---@param parent ExtuiTreeParent
---@param settings RB_CCMod_Pack
function MaterialPresetsMenu:RenderExportSettingPanel(parent, settings)
    local modNameText = parent:AddText("Mod Name:")
    local modNameInput = parent:AddInputText("##MaterialPresetModName")
    modNameInput.Hint = "Enter Mod Name..."

    modNameInput.OnChange = function ()
        settings.ModName = modNameInput.Text
    end
    modNameInput.Text = settings.ModName or ""

    local authorNameText = parent:AddText("Author Name:")
    local authorNameInput = parent:AddInputText("##MaterialPresetAuthorName")
    authorNameInput.Hint = "Enter Author Name..."
    authorNameInput.OnChange = function ()
        settings.Author = authorNameInput.Text
    end
    authorNameInput.Text = settings.Author or ""

    local descriptionText = parent:AddText("Description:")
    local descriptionInput = parent:AddInputText("##MaterialPresetDescription")
    descriptionInput.Hint = "Enter Description..."
    descriptionInput.OnChange = function ()
        settings.Description = descriptionInput.Text
    end
    descriptionInput.Multiline = true
    descriptionInput.Text = settings.Description or ""

    local versionText = parent:AddText("Version:")
    local versionInput = parent:AddInputInt("##MaterialPresetVersion")
    versionInput.Components = 4
    versionInput.OnChange = function ()
        settings.Version = { versionInput.Value[1], versionInput.Value[2], versionInput.Value[3], versionInput.Value[4] }
    end
    versionInput.Value = { settings.Version[1], settings.Version[2], settings.Version[3], settings.Version[4] }

    local function refresh()
        modNameInput.Text = settings.ModName or ""
        authorNameInput.Text = settings.Author or ""
        descriptionInput.Text = settings.Description or ""
        versionInput.Value = { settings.Version[1], settings.Version[2], settings.Version[3], settings.Version[4] }
    end

    return refresh
end

---@param parent ExtuiTreeParent
---@param exportSettings RB_CCMod_Pack
---@param onImportComplete fun()
function MaterialPresetsMenu:RenderImportCCASection(parent, exportSettings, onImportComplete)
    local importText = parent:AddText("Import Character Creation Material Presets from existing CCA Mods:")

    local openedTrees = {}
    local function refreshCached()
        DestroyAllChilds(parent)

        local cache = nil

        if not next(self.cachedMods) then
            local locStr = Ext.IO.LoadFile(RealmPaths.GetCCAModCacheRefPath())
            cache = locStr and Ext.Json.Parse(locStr) or {}
        else
            cache = self.cachedMods
        end

        if not cache then
            Debug("Warning: No cached CCA mods found for import.")
            cache = {}
        end

        for modName,versions in pairs(cache) do
            local modNameSel = parent:AddSelectable((openedTrees[modName] and "[-]" or "[+]") .. modName .. "##ImportCCAMod_" .. modName)
            local group = parent:AddGroup("ImportCCAModGroup_" .. modName)
            group.Visible = openedTrees[modName] or false

            modNameSel.OnClick = function ()
                group.Visible = not group.Visible
                modNameSel.Label = (group.Visible and "[-]" or "[+]") .. modName .. "##ImportCCAMod_" .. modName
                openedTrees[modName] = group.Visible
            end

            for version,_ in pairs(versions) do
                local versionSel = group:AddSelectable("Version " .. version .. "##ImportCCAModVersion_" .. modName .. "_" .. version)
                versionSel.OnClick = function ()
                    local ccaModPack = self:ImportFromFile(modName, version)
                    if not ccaModPack then
                        Warning("Failed to import CCA mod pack for mod " .. modName .. " version " .. version)
                        return
                    end

                    exportSettings = DeepCopy(ccaModPack)

                    onImportComplete()
                end
            end

        end
    end

    refreshCached()

    return refreshCached
end

---@param parentTab ExtuiTable
---@param obj MaterialPresetData
function MaterialPresetsMenu:RenderExportPresetRow(parentTab, obj)
    local row = parentTab:AddRow()
    local confirmCell = row:AddCell()
    local uiColorCell = row:AddCell()
    local nameCell = row:AddCell()
    local typeCell = row:AddCell()
    local manageCell = row:AddCell()

    local confirmExportCheck = confirmCell:AddCheckbox("##ConfirmExport" .. obj.DisplayName)
    local colorBox = uiColorCell:AddColorEdit("##" .. obj.DisplayName)
    local nameInput = nameCell:AddInputText("##" .. obj.DisplayName .. "NameInput", obj.DisplayName)
    local typeCombo = typeCell:AddCombo("##" .. obj.DisplayName .. "TypeCombo")
    local manageBtn = manageCell:AddButton("···##" .. obj.DisplayName)

    confirmExportCheck.Checked = not obj.Disabled
    confirmExportCheck.OnChange = function ()
        obj.Disabled = not confirmExportCheck.Checked
        row:SetColor("TableRowBg", obj.Disabled and HexToRGBA("FF323232") or HexToRGBA("FFD6FFB1"))
        row:SetColor("TableRowBgAlt", obj.Disabled and HexToRGBA("FF313131") or HexToRGBA("FFD6FFB1"))
    end

    colorBox.Color = obj.UIColor
    colorBox.NoInputs = true
    colorBox.CanDrag = true
    colorBox.DragDropType = MATERIALPRESET_DRAGDROP_TYPE

    colorBox.UserData = {
        Parameters = obj.Parameters,
    }

    nameInput.SameLine = true
    nameInput.Hint = "Preset Name..."
    nameInput.OnChange = function ()
        if nameInput.Text ~= "" then
            obj.DisplayName = nameInput.Text
        end
    end

    colorBox.OnChange = function ()
        obj.UIColor = colorBox.Color
    end

    local managePopup = manageCell:AddPopup("ManageSelectedPresetPopup##" .. obj.DisplayName)
    colorBox.OnRightClick = function ()
        managePopup:Open()
    end

    colorBox.OnDragStart = function (sel)
        local colorPreview = colorBox.DragPreview:AddColorEdit("##PreviewColorBox")
        colorPreview.Color = obj.UIColor
        colorPreview.NoInputs = true
        colorBox.DragPreview:AddText(obj.DisplayName).SameLine = true
    end

    colorBox.OnDragDrop = function (sel, drop)
        if drop.UserData and drop.UserData.Parameters then
            obj.Parameters = DeepCopy(drop.UserData.Parameters or {})
            if drop.UserData.UIColor then
                obj.UIColor = DeepCopy(drop.UserData.UIColor or {1,1,1,1})
                colorBox.Color = obj.UIColor
            end
            local tooltip = colorBox:Tooltip():AddText(" Overwrite Preset Parameters with Dropped Preset ")
            Timer:After(5000, function ()
                tooltip:Destroy()
            end)
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

    --- combo index start from 0, lua table start from 1

    typeCombo.Options = typeOptions
    typeCombo.OnChange = function ()
        local index = typeCombo.SelectedIndex + 1
        obj.ExportType = indexToType[index]
    end
    if obj.ExportType then
        typeCombo.SelectedIndex = typeToIndex[obj.ExportType]
    end

    manageBtn.OnClick = function (btn)
        managePopup:Open()
    end

    local selectTable = managePopup:AddTable("ManageSelectedPresetTable", 1)
    local selectRow = selectTable:AddRow()
    local deleteBtn = AddSelectableButton(selectRow:AddCell(), "Remove Preset##" .. obj.DisplayName, function (sel)
        obj.Deleted = true
        row:Destroy()
    end)
    ApplyDangerSelectableStyle(deleteBtn)

    local openMatMixerBtn = AddSelectableButton(selectRow:AddCell(), "Material Cocktail ##" .. obj.DisplayName, function (sel)
        local materialMixer = MaterialMixerTab.new(obj.Parameters)
        materialMixer:Render()
    end)

end

--- simply load from CCA_Cache folder
---@param modName string
---@param version vec4|string
---@return RB_CCMod_Pack?
function MaterialPresetsMenu:ImportFromFile(modName, version)
    modName = modName:gsub("%s+", "_")
    local versionStr = type(version) == "string" and version or BuildVersionString(version)

    if self.cachedMods and self.cachedMods[modName] then
        local cachedMod = self.cachedMods[modName][versionStr]
        if cachedMod then
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

---@param modPack RB_CCMod_Pack
function MaterialPresetsMenu:ExportToMod(modPack)
    local startTime = Ext.Timer.MonotonicTime() 
    local suc = true

    local modName = modPack.ModName
    local authorName = modPack.Author
    local description = modPack.Description
    local version = modPack.Version
    local matPresets = modPack.MaterialPresets
    local existUuid = modPack.ModuleUUID --[[@type GUIDSTRING?]]

    if not IsUuid(existUuid) then
        existUuid = nil
    end

    -- sanitize mod internal name

    local modInternalName = modName:gsub("%s+", "_")
    local internalNames = {}
    for _,preset in pairs(matPresets) do
        internalNames[preset] = preset.DisplayName:gsub("%s+", "_")
    end

    -- prefer reusing the existing ModuleUUID, so the game recognizes this as the same mod. 

    local modUuid = existUuid and existUuid or Uuid_v4()

    --- build mod meta.lsx first
    local metaLsx = LSXHelpers.BuildModMeta(modUuid, modName, modInternalName, authorName, version, description)
    local mataFilePath = RealmPaths.GetCCAModMetaPath(modInternalName)

    suc = Ext.IO.SaveFile(mataFilePath, metaLsx:Stringify({ Indent = 4 }))

    if not suc then
        Warning("ExportToMod: Failed to save mod meta file at " .. mataFilePath)
    end

    --- build localization file first because CC presets need it
    
    local names = {}

    for _, preset in pairs(matPresets) do
        if preset.DisplayName and not preset.Disabled then
            table.insert(names, preset.DisplayName)
        end
    end

    local locaLsx, stringToHandles = LSXHelpers.GenerateLocalization(names, 1)

    local locaFilePath = RealmPaths.GetCCALocalizationPath(modInternalName, "English") -- currently assume English only

    suc = Ext.IO.SaveFile(locaFilePath, locaLsx)

    if not suc then Warning("ExportToMod: Failed to save localization file at " .. locaFilePath) end

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
        if preset.Disabled then goto continue end
        local presetType = preset.ExportType
        local materialPresetBank = banks[presetType]

        local uuid = Uuid_v4()
        matPresetUuids[preset] = uuid
        local internalName = modInternalName .. cheapName[presetType] .. internalNames[preset]
        local presetNode = LSXHelpers.BuildMaterialPresetResourceNode(preset.Parameters, uuid, internalName)

        materialPresetBank:AppendChild(presetNode)

        ::continue::
    end

    -- export material preset banks

    for presetType, bank in pairs(banks) do
        if bank:CountChildren() == 0 then goto continue end
        local matPresetFile = RealmPaths.GetCCAMaterialPresetsFile(presetType, modInternalName) --[[@as string]]

        suc = Ext.IO.SaveFile(matPresetFile, bank:Stringify({ Indent = 4, AutoFindRoot = true }))

        if not suc then Warning("ExportToMod: Failed to save material presets file at " .. matPresetFile) end

        ::continue::
    end

    --- build Character Creation Presets definition
    
    --- @type table<string, LSXNode>
    local ccaDefNode = {
        CharacterCreationEyeColors = {},
        CharacterCreationHairColors = {},
        CharacterCreationSkinColors = {},
    }

    for presetType,_ in pairs(ccaDefNode) do
        ccaDefNode[presetType] = LSXHelpers.BuildCCAPresetsRegionNode(presetType)
    end
    
    for _, preset in pairs(matPresets) do
        if preset.Disabled then goto continue end
        local presetType = preset.ExportType
        local ccaPresetNode = ccaDefNode[presetType]

        local internalName = modInternalName .. cheapName[presetType] .. internalNames[preset]
        local matPresetUuid = matPresetUuids[preset]
        local ccaPresetUuid = Uuid_v4()

        local topHanlde = #stringToHandles[preset.DisplayName]
        local handle = stringToHandles[preset.DisplayName][topHanlde]
        table.remove(stringToHandles[preset.DisplayName], topHanlde) -- use up one handle per preset

        local presetNode = LSXHelpers.BuildCCAPresetNode(handle, internalName, preset.UIColor, matPresetUuid, ccaPresetUuid, presetType)

        ccaPresetNode:AppendChild(presetNode)

        ::continue::
    end

    -- export CC presets definition file

    for presetType, def in pairs(ccaDefNode) do
        if def:CountChildren() == 0 then goto continue end
        local ccaFilePath = RealmPaths.GetCCAPresetsFile(presetType, modInternalName) --[[@as string]]

        suc = Ext.IO.SaveFile(ccaFilePath, def:Stringify({ Indent = 4, AutoFindRoot = true }))

        if not suc then Warning("ExportToMod: Failed to save CCA presets file at " .. ccaFilePath) end
        ::continue::
    end

    local endTime = Ext.Timer.MonotonicTime()

    Debug("ExportToMod: Exported to mod '" .. modName .. "' in " .. tostring(endTime - startTime) .. " ms,")

    --- unserialize xml is possible but for sanity we just save a json cache file

    self:SaveModCache(modName, authorName, description, version, matPresets, modInternalName, modUuid)
end

function MaterialPresetsMenu:SaveModCache(modName, authorName, description, version, matPresets, modInternalName, modUuid)
    local cacheFile = {
        ModName = modName,
        AuthorName = authorName,
        Description = description,
        Version = version,
        MaterialPresets = matPresets,
        ModuleUUID = modUuid,
    }
    cacheFile = DeepCopy(cacheFile)
    local jsonStr = Ext.Json.Stringify(cacheFile, { Indent = 4 })
    local filePath = RealmPaths.GetCCAModCachePath(modInternalName, version)

    local suc = Ext.IO.SaveFile(filePath, jsonStr)

    self.cachedMods[modInternalName] = self.cachedMods[modInternalName] or {}
    self.cachedMods[modInternalName][BuildVersionString(version)] = cacheFile

    if not suc then
        Warning("ExportToMod: Failed to save CCA mod cache file at " .. filePath)
    end

    self:CreateCacheRefs()
end

function MaterialPresetsMenu:CreateCacheRefs()
    local allRefs = {}

    for modName,modCache in pairs(self.cachedMods) do
        allRefs[modName] = {}
        for version,cache in pairs(modCache) do
            allRefs[modName][version] = {
                ModuleUUID = cache.ModuleUUID,
                MaterialPresetCount = #cache.MaterialPresets,
            }
        end
    end

    Ext.IO.SaveFile(RealmPaths.GetCCAModCacheRefPath(), Ext.Json.Stringify(allRefs, { Indent = 4 }))
end

function MaterialPresetsMenu:RenderCCMaterialPresets(header)

    local cca = {
        "CharacterCreationEyeColor",
        "CharacterCreationHairColor",
        "CharacterCreationSkinColor",
    }
    local headers = {} --[[@type table<string, ExtuiTree> ]]

    for _,presetKey in ipairs(cca) do
        local field = header:AddTree(presetKey) --[[@as ExtuiTree]]
        headers[presetKey] = field
        field:SetOpen(false)
    end

    for presetName, field in pairs(headers) do
        field.OnHoverEnter = function ()
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

    colorBox.OnDragStart = function (sel)
        local previewColorBox = colorBox.DragPreview:AddColorEdit("##PreviewColorBox")
        previewColorBox.Color = preset.UIColor
        previewColorBox.NoInputs = true
        colorBox.DragPreview:AddText(preset.DisplayName and preset.DisplayName:Get() or "Unnamed Preset").SameLine = true
        if not preset.ResourceUUID then return end
        if sel.UserData then return end
        local presetProxy = MaterialPresetProxy.new(preset.MaterialPresetUUID)
        if not presetProxy then 
            Warning("RenderPresetColorBox: Failed to create MaterialPresetProxy for preset UUID: " .. tostring(preset.MaterialPresetUUID))
            return
        end
        sel.UserData = {
            Parameters = presetProxy.Parameters,
            MaterialProxy = presetProxy,
            PresetProxy = presetProxy,
            SuccessApply = false,
        }
    end

    colorBox.OnDragDrop = function (drop)
        colorBox.Color = preset.UIColor
    end

    colorBox.OnRightClick = function ()
        managePopup:Open()
    end

    colorBox.OnHoverEnter = function ()
        colorBox.Color = preset.UIColor
        colorBox:SetStyle("FrameBorderSize", 2)
        colorBox:SetColor("Border", HexToRGBA("FFFFD500"))
    end

    colorBox.OnHoverLeave = function ()
        colorBox:SetStyle("FrameBorderSize", 0)
        colorBox:SetColor("Border", HexToRGBA("FFFFFFFF"))
    end

    local manageTab = managePopup:AddTable("ManagePresetTable", 1)
    local manageRow = manageTab:AddRow()
    manageTab.BordersInnerH = true

    local openMatMixerBtn = AddSelectableButton(manageRow:AddCell(), "Open in Material Mixer##" .. preset.ResourceUUID, function (sel)
        local presetProxy = MaterialPresetProxy.new(preset.MaterialPresetUUID)
        if not presetProxy then Warning("RenderPresetColorBox: Failed to create MaterialPresetProxy for preset UUID: " .. tostring(preset.MaterialPresetUUID)) return end
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
    for _,resId in ipairs(allResId) do
        local res = Ext.StaticData.Get(resId, presetName) --[[@as ResourceCharacterCreationColor]]
        table.insert(allRes, res)
    end
    local namePrior = false
    local Comparator = function(a,b)
        local aName = a.DisplayName and a.DisplayName:Get() or ""
        local bName = b.DisplayName and b.DisplayName:Get() or ""
        if namePrior then
            return aName < bName
        end

        return colorPresetComparator(a,b, aName, bName)
    end

    table.sort(allRes, Comparator)

    local uuidToCells = {}

    local function renderAllResources()
        for _,res in ipairs(allRes) do
            local cell = row:AddCell()
            local colorBox = self:RenderPresetColorBox(res, cell)

            colorBox.OnDragEnd = function (sel)
                Timer:Ticks(1, function()
                    if sel.UserData and sel.UserData.SuccessApply then
                        -- Add to recent
                        table.insert(recentQueue, 1, res)

                        -- Remove duplicates
                        local seen = {}
                        local uniqueRecent = {}
                        for _,recent in ipairs(recentQueue) do
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
                        for _,recent in ipairs(recentQueue) do
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

    sortButton.OnClick = function ()
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

    searchInput.OnChange = function ()
        if debounceTimer then
            Timer:Cancel(debounceTimer)
            debounceTimer = nil
        end
        
        debounceTimer = Timer:Ticks(10, function ()
            if not searchInput.Text or searchInput.Text == "" then
                for uuid, cell in pairs(uuidToCells) do
                    cell.Visible = true
                end
                return
            end

            local searchText = string.lower(searchInput.Text)
            for _,res in ipairs(allRes) do
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
    hueInput.Color = {1, 0, 0, 1}
    hueInput.NoInputs = true
    hueInput.NoPicker = false
    hueInput:Tooltip():AddText("Filter by Hue, right click to reset.")
    hueInput.DisplayRGB = true
    hueInput.InputRGB = false
    hueInput.PickerHueWheel = true

    hueInput.OnChange = function ()
        local r1, g1, b1 = hueInput.Color[1], hueInput.Color[2], hueInput.Color[3]
        local h1, s1, v1 = RGBtoHSV(r1, g1, b1)

        for _,res in ipairs(allRes) do
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

    hueInput.OnRightClick = function ()
        hueInput.Color = {1, 0, 0, 1}
        for uuid, cell in pairs(uuidToCells) do
            cell.Visible = true
        end
    end

    cT.OnWidthChange = function ()
        local mTW = mainWindow.LastSize[1]
        local cols = math.floor(mTW / 55 * SCALE_FACTOR)
        if cols < 1 then cols = 1 end
        mainTable.Columns = math.floor(cols)
    end

    Timer:Ticks(10, function ()
        cT.OnWidthChange()
    end)

    parent.OnExpand = function ()
        cT.OnWidthChange()
    end
end

MaterialPresetsMenu:Render()