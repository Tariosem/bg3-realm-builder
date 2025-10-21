MATERIALPRESET_DRAGDROP_TYPE = "MaterialPreset"

MaterialPresetsMenu = MaterialPresetsMenu or {}

local function colorPresetComparator(a,b)
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
        local aName = a.DisplayName and a.DisplayName:Get() or ""
        local bName = b.DisplayName and b.DisplayName:Get() or ""
        return aName < bName
    end
end

function MaterialPresetsMenu:Render()
    if self.isVisible then return end

    self.panel = RegisterWindow("generic", "Material Presets", "Menu", self)
    self.panel.Closeable = true

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
    local cT = AddCollapsingTable(header, nil, "Recent", { CollapseDirection = "Right" })
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

        return colorPresetComparator(a,b)
    end

    


end

function MaterialPresetsMenu:SetupWorklist()

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
        colorBox.Color = preset.UIColor
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
        if namePrior then
            local aName = a.DisplayName and a.DisplayName:Get() or ""
            local bName = b.DisplayName and b.DisplayName:Get() or ""
            return aName < bName
        end

        return colorPresetComparator(a,b)
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

--- @param mat MaterialEditor
function MaterialPresetsMenu:SaveMaterialPreset(mat)
    if not mat then return end

    local parameters = DeepCopy(mat.Parameters)
    
    local newName 

end

MaterialPresetsMenu:Render()