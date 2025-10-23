MATERIALPRESET_DRAGDROP_TYPE = "MaterialPreset"

--- @class MaterialPresetData
--- @field DisplayName string
--- @field UIColor number[]
--- @field Parameters table<1|2|3|4, table<string, any>>

--- @class RB_CCAModCache
--- @field ModName string
--- @field ModuleUUID string
--- @field AuthorName string
--- @field Description string
--- @field Version vec4
--- @field MaterialPresets table<string, MaterialPresetData[]>

--- @class MaterialPresetsMenu
--- @field isVisible boolean
--- @field panel ExtuiWindow
--- @field CustomMaterialPresets table<string, MaterialPresetData>
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

    self.cachedMods = {} --- @type table<string, RB_CCAModCache>

    self.CustomMaterialPresets = {}

    self.isVisible = true
    self:RenderPresetsList()
end

function MaterialPresetsMenu:RenderPresetsList()
    if not self.panel then return end

    local customMPHeader = self.panel:AddCollapsingHeader("Custom Material Presets")

    self:RenderCustomMaterialPresets(customMPHeader)

    local ccPresetsHeader = self.panel:AddCollapsingHeader("Character Creation Material Presets")

    self:RenderCCMaterialPresets(ccPresetsHeader)

end

function MaterialPresetsMenu:RenderCustomMaterialPresets(header)
    local cT = AddCollapsingTable(header, nil, "Export", { CollapseDirection = "Right", SideBarWidth = 600 })
    cT.Table.BordersInnerV = true

    local mainList = cT.MainArea
    local workshopList = cT.SideBar

    local mainWindow = mainList:AddChildWindow("MainMaterialPresets")
    local mainTable = mainWindow:AddTable("MaterialPresets", 10)

    local namePrior = false
    local comparator = function(a,b)
        if namePrior then
            local aName = a.DisplayName or ""
            local bName = b.DisplayName or ""
            return aName < bName
        end

        return colorPresetComparator(a,b, a.DisplayName or "", b.DisplayName or "")
    end

    local row = mainTable:AddRow()
    local nameToCells = {}

    local function renderAllCustomPresets()
        local presetsList = {}
        for _,preset in pairs(self.CustomMaterialPresets) do
            table.insert(presetsList, preset)
        end

        table.sort(presetsList, comparator)

        for _,preset in ipairs(presetsList) do
            local cell = row:AddCell()
            local colorBox = self:RenderCustomColorBox(preset, cell)

        end
    end

    renderAllCustomPresets()

    self.UpdateCustomMaterialPresetsList = function ()
        nameToCells = {}
        row:Destroy()
        row = mainTable:AddRow()
        renderAllCustomPresets()
    end

    local sortButton = cT.TitleCell:AddButton("Hue##CustomPresetSort")
    local stooltip = sortButton:Tooltip():AddText("Sort presets by Hue")

    sortButton.OnClick = function ()
        nameToCells = {}
        namePrior = not namePrior
        row:Destroy()
        row = mainTable:AddRow()
        renderAllCustomPresets()
        stooltip.Label = namePrior and "Sort presets by Name" or "Sort presets by Hue"
        sortButton.Label = namePrior and "Name##CustomPresetSort" or "Hue##CustomPresetSort"
    end


    self:SetupWorklist(workshopList)
end

---@param parent ExtuiTreeParent
---@param ccaModPack RB_CCAModCache?
function MaterialPresetsMenu:SetupWorklist(parent, ccaModPack)
    local modName = ccaModPack and ccaModPack.ModName or ""
    local authorName = ccaModPack and ccaModPack.AuthorName or ""
    local description = ccaModPack and ccaModPack.Description or ""
    local version = ccaModPack and ccaModPack.Version or {1,0,0,0}
    local selectedMPs = ccaModPack and ccaModPack.MaterialPresets or {
        CharacterCreationEyeColors = {},
        CharacterCreationHairColors = {},
        CharacterCreationSkinColors = {},
    }

    local function quickCheckIfExportable()
        if not modName or modName == "" then
            return false
        end

        if not authorName or authorName == "" then
            return false
        end

        if #selectedMPs.CharacterCreationEyeColors == 0 and
           #selectedMPs.CharacterCreationHairColors == 0 and
           #selectedMPs.CharacterCreationSkinColors == 0 then
            return false
        end

        return true
    end

    local function refreshSelectedList()
        -- declaration
    end

    local modNameText = parent:AddText("Mod Name:")

    local modNameInput = parent:AddInputText("##MaterialPresetModName")
    modNameInput.Hint = "Enter Mod Name..."

    modNameInput.OnChange = function ()
        modName = modNameInput.Text
    end

    local authorNameText = parent:AddText("Author Name:")
    local authorNameInput = parent:AddInputText("##MaterialPresetAuthorName")
    authorNameInput.Hint = "Enter Author Name..."
    authorNameInput.OnChange = function ()
        authorName = authorNameInput.Text
    end

    local descriptionText = parent:AddText("Description:")
    local descriptionInput = parent:AddInputText("##MaterialPresetDescription")
    descriptionInput.Hint = "Enter Description..."
    descriptionInput.OnChange = function ()
        description = descriptionInput.Text
    end

    local versionText = parent:AddText("Version (Major.Minor.Revision.Build):")
    local versionInput = parent:AddInputInt("##MaterialPresetVersion")
    versionInput.Components = 4
    versionInput.OnChange = function ()
        version = { versionInput.Value[1], versionInput.Value[2], versionInput.Value[3], versionInput.Value[4] }
    end


    local importBtn = nil --[[@type ExtuiSelectable]]
    local importTT = nil --[[@type ExtuiText]]

    importBtn = AddSelectableButton(parent, "Import", function (sel)
        local fileContent = MaterialPresetsMenu:ImportFromFile(modName)
        Timer:After(100, function ()
            importBtn:SetStyle("Alpha", 1)
            importBtn:SetColor("Text", HexToRGBA("FFFFFFFF"))
        end)

        if not fileContent then
            importTT.Label = "Failed to import material presets: Mod '" .. modName .. "' not found in CCA_Cache."
            importBtn:SetColor("Text", HexToRGBA("FFFF0000"))
            GuiAnim.Vibrate(importBtn)
            return
        end
        authorName = fileContent.AuthorName or ""
        description = fileContent.Description or ""
        version = fileContent.Version or {1,0,0,0}
        selectedMPs = fileContent.MaterialPresets or {
            CharacterCreationEyeColors = {},
            CharacterCreationHairColors = {},
            CharacterCreationSkinColors = {},
        }
        modNameInput.Text = modName
        authorNameInput.Text = authorName
        descriptionInput.Text = description
        versionInput.Value = { version[1] or 1, version[2] or 0, version[3] or 0, version[4] or 0 }
        refreshSelectedList()

        importTT.Label = "Imported material presets from mod '" .. modName .. "'."
        importBtn:SetColor("Text", HexToRGBA("FF00CCCC"))
    end)
    importTT = importBtn:Tooltip():AddText("Import by mod name from Realm_Builder/CC_Mod_Cache/")

    local exportBtn = nil --[[@type ExtuiSelectable]]
    local exportTT = nil --[[@type ExtuiText]]
    exportBtn = AddSelectableButton(parent, "Export", function (sel)
        if not quickCheckIfExportable() then
            GuiAnim.Vibrate(exportBtn)
            exportTT.Label = "Cannot export material presets: Missing required information."
            Warning("Cannot export material presets: Missing required information.")
            return
        end

        exportTT.Label = "Exported material presets to mod '" .. modName .. "'."
        MaterialPresetsMenu:ExportToMod(modName, authorName, description, version, selectedMPs)
    end)
    exportTT = exportBtn:Tooltip():AddText("Export material presets to Realm_Builder/CC_Mods/")

    exportBtn.OnHoverEnter = function ()
        if not quickCheckIfExportable() then
            exportBtn:SetStyle("Alpha", 0.5)
            exportBtn:SetColor("Text", HexToRGBA("FFFF0000"))
        else
            exportBtn:SetStyle("Alpha", 1)
            exportBtn:SetColor("Text", HexToRGBA("FF00CCCC"))
        end
    end

    local selectedList = parent:AddChildWindow("SelectedMaterialPresets")

    selectedList:AddSeparatorText("Eye Color Presets")
    local eyeTab = selectedList:AddTable("EyeColorPresets", 1)

    selectedList:AddSeparatorText("Hair Color Presets")
    local hairTab = selectedList:AddTable("HairColorPresets", 1)

    selectedList:AddSeparatorText("Skin Color Presets")
    local skinTab = selectedList:AddTable("SkinColorPresets", 1)

    local allTabs = {
        CharacterCreationEyeColors = eyeTab,
        CharacterCreationHairColors = hairTab,
        CharacterCreationSkinColors = skinTab,
    }
    local allRows = {}

    function refreshSelectedList()
        for key,tab in pairs(allTabs) do
            if allRows[key] then
                allRows[key]:Destroy()
            end
            local row = allTabs[key]:AddRow()
            allRows[key] = row
            for _,preset in pairs(selectedMPs[key]) do
                local cell = row:AddCell()
                local colorBox = cell:AddColorEdit("##" .. preset.DisplayName)
                local nameInput = cell:AddInputText("##" .. preset.DisplayName .. "NameInput", preset.DisplayName)
                colorBox.Color = preset.UIColor
                colorBox.NoInputs = true
                colorBox.CanDrag = true
                colorBox.DragDropType = MATERIALPRESET_DRAGDROP_TYPE

                colorBox.UserData = {
                    Parameters = preset.Parameters,
                }

                nameInput.SameLine = true
                nameInput.Hint = "Preset Name..."
                nameInput.OnChange = function ()
                    if nameInput.Text ~= "" then
                        preset.DisplayName = nameInput.Text
                    end
                end

                colorBox.OnChange = function ()
                    preset.UIColor = colorBox.Color
                end

                local managePopup = cell:AddPopup("ManageSelectedPresetPopup##" .. preset.DisplayName)
                colorBox.OnRightClick = function ()
                    managePopup:Open()
                end

                colorBox.OnDragStart = function (sel)
                    local colorPreview = colorBox.DragPreview:AddColorEdit("##PreviewColorBox")
                    colorPreview.Color = preset.UIColor
                    colorPreview.NoInputs = true
                    colorBox.DragPreview:AddText(preset.DisplayName).SameLine = true
                end

                colorBox.OnDragDrop = function (sel, drop)
                    if drop.UserData and drop.UserData.Parameters then
                        preset.Parameters = DeepCopy(drop.UserData.Parameters or {})
                        if drop.UserData.UIColor then
                            preset.UIColor = DeepCopy(drop.UserData.UIColor or {1,1,1,1})
                            colorBox.Color = preset.UIColor
                        end
                        local tooltip = colorBox:Tooltip():AddText(" Overwrite Preset Parameters with Dropped Preset ")
                        Timer:After(5000, function ()
                            tooltip:Destroy()
                        end)
                    end
                end

                local selectTable = managePopup:AddTable("ManageSelectedPresetTable", 1)
                local selectRow = selectTable:AddRow()
                local deleteBtn = AddSelectableButton(selectRow:AddCell(), "Remove Preset##" .. preset.DisplayName, function (sel)
                    for i,p in ipairs(selectedMPs[key]) do
                        if p == preset then
                            table.remove(selectedMPs[key], i)
                            break
                        end
                    end
                    refreshSelectedList()
                end)
                ApplyDangerSelectableStyle(deleteBtn)

                local openMatMixerBtn = AddSelectableButton(selectRow:AddCell(), "Open in Material Mixer##" .. preset.DisplayName, function (sel)
                    local materialMixer = MaterialMixerTab.new(preset.Parameters)
                    materialMixer:Render()
                end)
            end

            local emptyBox = row:AddCell():AddColorEdit("Add##EmptyBox " .. key)
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

                    table.insert(selectedMPs[key], presetData)
                    refreshSelectedList()
                end
            end
 
        end
    end

    refreshSelectedList()
end

--- simply load from CCA_Cache folder
---@param modName string
---@return RB_CCAModCache?
function MaterialPresetsMenu:ImportFromFile(modName)
    modName = modName:gsub("%s+", "_")

    if self.cachedMods and self.cachedMods[modName] then
        return self.cachedMods[modName]
    end

    local filePath = RealmPaths.GetCCAModCachePath(modName)

    local jsonStr = Ext.IO.LoadFile(filePath)

    if not jsonStr then
        Warning("ImportFromFile: Failed to load CCA mod cache file at " .. filePath)
        return nil
    end

    local cacheFile = Ext.Json.Parse(jsonStr) --- @type RB_CCAModCache

    self.cachedMods[modName] = cacheFile

    return cacheFile
end

---@param modName string
---@param authorName string
---@param description string
---@param version vec4
---@param selectedMPs table<string, MaterialPresetData[]>
function MaterialPresetsMenu:ExportToMod(modName, authorName, description, version, selectedMPs)
    local startTime = Ext.Timer.MonotonicTime() 
    local suc = true

    local modInternalName = modName:gsub("%s+", "_")
    local internalNames = {}
    for _,presets in pairs(selectedMPs) do
        for _,preset in pairs(presets) do
            internalNames[preset] = preset.DisplayName:gsub("%s+", "_")
        end
    end

    -- prefer reusing the existing ModuleUUID, so the game recognizes this as the same mod.
    local imported = self:ImportFromFile(modName) --[[@as RB_CCAModCache]]
    local isUuid = IsUuid(imported and imported.ModuleUUID or nil)

    local modUuid = isUuid and imported.ModuleUUID or Uuid_v4()

    --- build mods metalsx first
    local metaLsx = LSXHelpers.BuildModMeta(modUuid, modName, modInternalName, authorName, version, description)
    local mataFilePath = RealmPaths.GetCCAModMetaPath(modInternalName)

    suc = Ext.IO.SaveFile(mataFilePath, metaLsx:Stringify({ Indent = 4 }))

    if not suc then
        Warning("ExportToMod: Failed to save mod meta file at " .. mataFilePath)
    end

    --- build localization file first because CC presets need it
    
    local names = {}

    for presetType, presets in pairs(selectedMPs) do
        for _,preset in pairs(presets) do
            if preset.DisplayName then
                table.insert(names, preset.DisplayName)
            end
        end
    end

    local locaLsx, handleToString, stringToHandle = LSXHelpers.GenerateLocalization(names, 1)

    local locaFilePath = RealmPaths.GetCCALocalizationPath(modInternalName, "English") -- currently assume English only

    suc = Ext.IO.SaveFile(locaFilePath, locaLsx)

    if not suc then
        Warning("ExportToMod: Failed to save localization file at " .. locaFilePath)
    end

    --- build material presets file first because CC presets need it
    
    local cheapName = {
        CharacterCreationEyeColors = "_EyeColor_",
        CharacterCreationHairColors = "_HairColor_",
        CharacterCreationSkinColors = "_SkinColor_",
    }


    local matPresetUuids = {}
    for presetType, presets in pairs(selectedMPs) do
        if #presets == 0 then goto continue end
        local materialPresetBank = LSXHelpers.BuildMaterialPresetBank()

        for i,presetData in pairs(presets) do
            local uuid = Uuid_v4()
            matPresetUuids[presetData] = uuid
            local internalName = modInternalName .. cheapName[presetType] .. internalNames[presetData]
            local presetNode = LSXHelpers.BuildMaterialPresetResourceNode(presetData.Parameters, uuid, internalName)

            materialPresetBank:AppendChild(presetNode)
        end

        local matPresetFile = RealmPaths.GetCCAMaterialPresetsFile(presetType, modInternalName)
        if not matPresetFile then
            Warning("ExportToMod: Failed to get material presets file path for preset type " .. tostring(presetType))
            goto continue
        end

        suc = Ext.IO.SaveFile(matPresetFile, materialPresetBank:Stringify({ Indent = 4, AutoFindRoot = true }))

        if not suc then
            Warning("ExportToMod: Failed to save material presets file at " .. matPresetFile)
        end

        ::continue::
    end

    --- build Character Creation Presets file
    
    for presetType, presets in pairs(selectedMPs) do
        if #presets == 0 then goto continue end
        local ccaPresetNode = LSXHelpers.BuildCCAPresetsRegionNode(presetType, presets)

        for i, presetData in pairs(presets) do
            local internalName = modInternalName .. cheapName[presetType] .. internalNames[presetData]
            local matPresetUuid = matPresetUuids[presetData]
            local ccaPresetUuid = Uuid_v4()

            local presetNode = LSXHelpers.BuildCCAPresetNode(stringToHandle[presetData.DisplayName], internalName, presetData.UIColor, matPresetUuid, ccaPresetUuid, presetType)

            ccaPresetNode:AppendChild(presetNode)
        end

        local ccaFilePath = RealmPaths.GetCCAPresetsFile(presetType, modInternalName)
        if not ccaFilePath then
            Warning("ExportToMod: Failed to get CCA presets file path for preset type " .. tostring(presetType))
            goto continue
        end

        suc = Ext.IO.SaveFile(ccaFilePath, ccaPresetNode:Stringify({ Indent = 4, AutoFindRoot = true }))

        if not suc then
            Warning("ExportToMod: Failed to save CCA presets file at " .. ccaFilePath)
        end

        ::continue::
    end

    local endTime = Ext.Timer.MonotonicTime()

    Debug("ExportToMod: Exported to mod '" .. modName .. "' in " .. tostring(endTime - startTime) .. " ms,")

    --- unserialize xml is possible but for sanity we just save a json cache file

    local cacheFile = {
        ModName = modName,
        AuthorName = authorName,
        Description = description,
        Version = version,
        MaterialPresets = selectedMPs,
        ModuleUUID = modUuid,
    }
    local jsonStr = Ext.Json.Stringify(cacheFile, { Indent = 4 })
    local filePath = RealmPaths.GetCCAModCachePath(modInternalName)

    suc = Ext.IO.SaveFile(filePath, jsonStr)

    self.cachedMods[modInternalName] = cacheFile

    if not suc then
        Warning("ExportToMod: Failed to save CCA mod cache file at " .. filePath)
    end
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

function MaterialPresetsMenu:RenderCustomColorBox(preset, parent)
    local colorBox = parent:AddColorEdit("##" .. preset.DisplayName)
    colorBox.Color = preset.UIColor
    colorBox:Tooltip():AddText(preset.DisplayName or "Unnamed Preset")
    colorBox.NoInputs = true
    colorBox.CanDrag = true
    colorBox.DragDropType = MATERIALPRESET_DRAGDROP_TYPE

    local managePopup = parent:AddPopup("ManagePresetPopup##" .. preset.DisplayName)

    colorBox.OnDragStart = function (sel)
        local previewColorBox = colorBox.DragPreview:AddColorEdit("##PreviewColorBox")
        previewColorBox.Color = preset.UIColor
        previewColorBox.NoInputs = true
        colorBox.DragPreview:AddText(preset.DisplayName).SameLine = true
        if sel.UserData then return end
        sel.UserData = {
            DisplayName = preset.DisplayName,
            UIColor = preset.UIColor,
            Parameters = preset.Parameters,
            SuccessApply = false,
        }
    end

    colorBox.OnDragDrop = function (drop)
        colorBox.Color = preset.UIColor
    end

    colorBox.OnRightClick = function ()
        colorBox.Color = preset.UIColor
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

    colorBox.OnChange = function ()
        preset.UIColor = colorBox.Color
    end

    local selectTable = managePopup:AddTable("ManagePresetTable", 1)
    selectTable.BordersInnerH = true
    local selectRow = selectTable:AddRow()

    local openMatMixerBtn = AddSelectableButton(selectRow:AddCell(), "Open in Material Mixer##" .. preset.DisplayName, function (sel)
        local materialMixer = MaterialMixerTab.new(preset.Parameters)
        materialMixer:Render()
    end)

    local deleteBtn = AddSelectableButton(selectRow:AddCell(), "Delete Preset##" .. preset.DisplayName, function (sel)
        self.CustomMaterialPresets[preset.DisplayName] = nil
        self:UpdateCustomMaterialPresetsList()
    end)
    ApplyDangerSelectableStyle(deleteBtn)

    local renameBtn = AddSelectableButton(selectRow:AddCell(), "Rename Preset##" .. preset.DisplayName, function (sel)
        local renamePopup = parent:AddPopup("RenamePresetPopup##" .. preset.DisplayName) --[[@as ExtuiPopup]]
        
        local renameInput = renamePopup:AddInputText("##RenamePresetInput", preset.DisplayName)
        renameInput.Hint = "Enter new preset name ..."

        renamePopup:Open()

        local function destoryRenamePopup()
            --- @diagnostic disable-next-line
            if renamePopup then renamePopup:Destroy() renamePopup = nil end
        end

        local enterConfirmSub = SubscribeKeyInput({ Key = "RETURN" }, function (e)
            local ok, isFocus = pcall(IsFocused, renameInput)
            if not ok then destoryRenamePopup() return UNSUBSCRIBE_SYMBOL end

            if e.Key == "RETURN" and isFocus then
                local newName = renameInput.Text
                if newName and newName ~= "" and newName ~= preset.DisplayName and not self.CustomMaterialPresets[newName] then
                    -- Rename
                    self.CustomMaterialPresets[newName] = preset
                    self.CustomMaterialPresets[preset.DisplayName] = nil
                    preset.DisplayName = newName
                    self:UpdateCustomMaterialPresetsList()
                end
                destoryRenamePopup()
                return UNSUBSCRIBE_SYMBOL
            end
        end)

        Timer:After(1000, function()
            local focusTimer = Timer:EveryFrame(function ()
                if not renamePopup then return UNSUBSCRIBE_SYMBOL end
                local ok, isFocus = pcall(IsFocused, renamePopup)
                if not ok then destoryRenamePopup() return UNSUBSCRIBE_SYMBOL end

                if not isFocus then
                    enterConfirmSub:Unsubscribe()
                    destoryRenamePopup()
                else
                end
            end)
        end)

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

--- @param mat {Parameters: table<string, any>, GetPreviewColor: fun(self): vec4}
function MaterialPresetsMenu:SaveMaterialPreset(mat)
    if not mat then return end

    local parameters = DeepCopy(mat.Parameters)
    
    local newName = "New Preset"

    local cnt = 1
    while self.CustomMaterialPresets[newName] do
        cnt = cnt + 1
        newName = newName .. " (" .. tostring(cnt) .. ")" 
    end

    self.CustomMaterialPresets[newName] = {
        DisplayName = newName,
        UIColor = mat:GetPreviewColor(),
        Parameters = parameters,
    }

    self:UpdateCustomMaterialPresetsList()
end


MaterialPresetsMenu:Render()