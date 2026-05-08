local dyeChannel = NetChannel.Dye

local dragFlag = "RB_ItemDye"

--- @class DyePreset
--- @field Cloth_Primary Vec3
--- @field Cloth_Secondary Vec3
--- @field Cloth_Tertiary Vec3
--- @field Leather_Primary Vec3
--- @field Leather_Secondary Vec3
--- @field Leather_Tertiary Vec3
--- @field Metal_Primary Vec3
--- @field Metal_Secondary Vec3
--- @field Metal_Tertiary Vec3
--- @field Accent_Color Vec3
--- @field Custom_1 Vec3
--- @field Custom_2 Vec3
--- @field Color_01 Vec3
--- @field Color_02 Vec3
--- @field Color_03 Vec3
--- @field Glow_Color Vec3
--- @field DyePresetName DyePresetName

--- @type DyePreset
local params = {
    ["Cloth_Primary"] = { 0.0, 0.0, 0.0 },
    ["Cloth_Secondary"] = { 0.0, 0.0, 0.0 },
    ["Cloth_Tertiary"] = { 0.0, 0.0, 0.0 },
    ["Leather_Primary"] = { 0.0, 0.0, 0.0 },
    ["Leather_Secondary"] = { 0.0, 0.0, 0.0 },
    ["Leather_Tertiary"] = { 0.0, 0.0, 0.0 },
    ["Metal_Primary"] = { 0.0, 0.0, 0.0 },
    ["Metal_Secondary"] = { 0.0, 0.0, 0.0 },
    ["Metal_Tertiary"] = { 0.0, 0.0, 0.0 },
    ["Accent_Color"] = { 0.0, 0.0, 0.0 },
    ["Custom_1"] = { 0.0, 0.0, 0.0 },
    ["Custom_2"] = { 0.0, 0.0, 0.0 },
    ["Color_01"] = { 0.0, 0.0, 0.0 },
    ["Color_02"] = { 0.0, 0.0, 0.0 },
    ["Color_03"] = { 0.0, 0.0, 0.0 },
    ["Glow_Color"] = { 0.0, 0.0, 0.0 },
}

--- @type string[]
local paramOrder = {
    "Accent_Color",
    "Cloth_Primary",
    "Cloth_Secondary",
    "Cloth_Tertiary",
    "Leather_Primary",
    "Leather_Secondary",
    "Leather_Tertiary",
    "Metal_Primary",
    "Metal_Secondary",
    "Metal_Tertiary",
    "Custom_1",
    "Custom_2",
    "Color_01",
    "Color_02",
    "Color_03",
    "Glow_Color",
}

--- @type ItemSlot[]
local equipmentSlots = {
    "Helmet",
    "Cloak",
    "Breast",
    "Gloves",
    "Boots",

    "MeleeMainHand",
    "MeleeOffHand",
    "RangedMainHand",
    "RangedOffHand",

    "Underwear",
    "VanityBody",
    "VanityBoots",

    "MusicalInstrument",
}

--- @param ent EntityHandle
--- @return Visual?
local function getEntVisual(ent)
    return VisualHelpers.GetEntityVisual(ent.Uuid.EntityUuid)
end 

--- @alias DyePresetName string

local Dyer = {
    --- @type table<DyePresetName, DyePreset>
    DyePresets = {

    }
}

local this = Dyer
local dyerFolder = "RB_Dyer/"

function Dyer.LoadFromLocalFile()
    local path = dyerFolder .. "Local.json"
    local content = Ext.IO.LoadFile(path)
    if not content then return nil end
    return Ext.Json.Parse(content)
end

function Dyer.SaveToLocalFile(data)
    local path = dyerFolder .. "Local.json"
    local content = Ext.Json.Stringify(data)
    local ok, err = Ext.IO.SaveFile(path, content)
    if not ok then
        Error("Failed to save Dyer data: " .. tostring(err))
    end
end

--- UI
EventsSubscriber.RegisterOnSessionLoaded(function ()
local DyerWindow = WindowManager.RegisterWindow("generic", "Dyer")
local selectedChar = nil 

DyerWindow.AlwaysAutoResize = true

local matParamCache = {}

--- @param renderable RenderableObject
--- @param paramName string
--- @return boolean
local function renderableHasParameter(renderable, paramName)
    local mat = renderable.ActiveMaterial
    if not mat then return false end
    local matName = mat.MaterialName
    if matParamCache[matName] and matParamCache[matName][paramName] ~= nil then
        return matParamCache[matName][paramName]
    end

    for _, vec3Param in pairs(mat.Material.Parameters.Vector3Parameters) do
        if vec3Param.ParameterName == paramName  then
            matParamCache[matName] = matParamCache[matName] or {}
            matParamCache[matName][paramName] = true
            return true
        end
    end

    return false
end

--- @param ent EntityHandle
--- @param slot ItemSlot
--- @return EntityHandle|nil
local function getEquipment(ent, slot)
    local cEV = ent.ClientEquipmentVisuals
    local slotData = cEV and cEV.Equipment[slot]
    return slotData and slotData.Item
end

--- @param ent EntityHandle
--- @param slot ItemSlot
local function getEquipmentVisualSlot(ent, slot)
    local cEV = ent.ClientEquipmentVisuals
    local slotData = cEV and cEV.Equipment[slot]
    return slotData
end

--- @param ent EntityHandle
--- @param slot ItemSlot
--- @return Visual[]
local function getEquipmentVisuals(ent, slot) 
    local results = {}
    local dummy = DummyHelpers.GetClientVisualDummy(ent.Uuid.EntityUuid)

    if dummy then
        ent = dummy
    end

    local visualSlot = getEquipmentVisualSlot(ent, slot)
    for _, subVisualEnt in pairs(visualSlot and visualSlot.SubVisuals or {}) do
        local subVisual = subVisualEnt.Visual.Visual
        if subVisual then
            table.insert(results, subVisual)
        end
    end
    return results
end

local function getEquipmentFirstVisual(ent, slot)
    local visuals = getEquipmentVisuals(ent, slot)
    return visuals and visuals[1]
end

local function dyeEquipment(ent, slot, paramName, color)
    local aliveEVs = getEquipmentVisuals(ent, slot)
    if not aliveEVs then return end

    local paramIsGlow = paramName == "Glow_Color"
    for _, aliveEV in pairs(aliveEVs) do
        for _, obj in pairs(aliveEV.ObjectDescs or {}) do
            if obj.Renderable then
                local mat = obj.Renderable.ActiveMaterial
                if mat and renderableHasParameter(obj.Renderable, paramName) then
                    mat:SetVector3(paramName, color)
                elseif mat and paramIsGlow and renderableHasParameter(obj.Renderable, "GlowColor") then
                    mat:SetVector3("GlowColor", color)
                end
            end
        end
    end
end

local refreshBtn = DyerWindow:AddButton("Refresh")
local makeEmptyMaterialPreset = DyerWindow:AddButton("Make Empty Material Preset")
local mainTable = DyerWindow:AddTable("Main", 2)
local mainRow = mainTable:AddRow()
local selectionCols = 3
local selectionRows = 6
local selectionImageSize = 64 * SCALE_FACTOR
local expandedImageSize = 96 * SCALE_FACTOR

makeEmptyMaterialPreset.SameLine = true

mainTable.ColumnDefs[1] = { WidthFixed = true, Width = expandedImageSize * selectionCols }
mainTable.ColumnDefs[2] = { WidthStretch = true }

local selection = mainRow:AddCell()
local materialEditor = mainRow:AddCell()

--- @param visual Visual
local function findFirstValidObjectInVisual(visual)
    local renderables = visual and visual.ObjectDescs
    if not renderables then return nil end

    for _, obj in pairs(renderables) do
        if obj.Renderable then
            local mat = obj.Renderable.ActiveMaterial
            for _, vec3Param in pairs(mat.Material.Parameters.Vector3Parameters) do
                if params[vec3Param.ParameterName] then
                    return obj
                end
            end
        end
    end

    return nil
end

--- @param parent ExtuiTable
--- @param name string
--- @param dyePreset DyePreset
--- @return ExtuiSelectable
local function renderDyeEntry(parent, name, dyePreset)
    local row = parent:AddRow()
    local cells = {row:AddCell(), row:AddCell(), row:AddCell()}
    local nameCell = cells[2]
    local inputCell = cells[1]
    local deleteCell = cells[3]
    deleteCell.Visible = parent.Label == "DyeList"

    local colorBlock = inputCell:AddColorEdit("##" .. name, dyePreset.Accent_Color)
    colorBlock.NoInputs = true

    local nameSel = nameCell:AddSelectable(name)

    local deleteBtn = deleteCell:AddImageButton("##Delete" .. name, RB_ICONS.X_Square, IMAGESIZE.ROW)

    local function dragStart(self)
        local data = {
            DyePreset = dyePreset,
        }
        self.UserData = data
        renderDyeEntry(self.DragPreview:AddTable("", 3), name, dyePreset)
    end

    for _, element in pairs({
        nameSel,
        colorBlock
    }) do
        element.CanDrag = true
        element.DragDropType = dragFlag
        element.OnDragStart = dragStart
    end

    deleteBtn.OnClick = function ()
        Dyer.DyePresets[name] = nil
        Dyer.SaveToLocalFile(Dyer.DyePresets)
        row:Destroy()
    end

    return nameSel
end

--- @param parent ExtuiTreeParent
--- @param onClick fun(dyePreset: DyePreset)
local function renderDyesList(parent, onClick)
    parent:AddSeparatorText("Dye Presets"):SetStyle("SeparatorTextAlign", 0.5)
    local listTab = parent:AddTable("DyeList", 3)
    listTab.ColumnDefs[1] = { WidthFixed = true }
    listTab.ColumnDefs[2] = { WidthStretch = true }

    listTab.RowBg = true

    RBUtils.AsyncForEach(Dyer.DyePresets, function(preset, name)
        renderDyeEntry(listTab, name, preset).OnClick = function ()
            onClick(preset)
        end
    end)
end

local curDyerTable = nil
local function refreshDyer() end --[[@as fun(ent: EntityHandle, slot: ItemSlot) ]]
--- @param ent EntityHandle
--- @param slot ItemSlot
function refreshDyer(ent, slot)
    local colorPreset = RBUtils.DeepCopy(params)
    colorPreset.DyePresetName = "Test"
    local parent = materialEditor
    parent.Disabled = false
    local entId = ent.Uuid.EntityUuid
    ImguiHelpers.DestroyAllChildren(parent)

    --- @type fun():EntityHandle
    local getEnt = function ()
        return Ext.Entity.Get(entId) --[[@as EntityHandle]]
    end
    local equipmentVisual = getEquipmentFirstVisual(getEnt(), slot)
    local noVisual = false
    if not equipmentVisual then
        noVisual = true
    end

    local obj = findFirstValidObjectInVisual(equipmentVisual)
    if not obj then
        noVisual = true
    end
    if noVisual then
        local t = parent:AddText("No valid visual found on this equipment slot.")
        t:SetColor("Text", {1, 0.5, 0, 1})
    end

    local topTable = parent:AddTable("Top", 2)
    local topRow = topTable:AddRow()
    local leftCell = topRow:AddCell()
    local rightCell = topRow:AddCell()

    local removeDyeBtn = leftCell:AddButton("Undye")
    local dyeBtn = leftCell:AddButton("Dye")

    local dyeCtxPop = leftCell:AddPopup("DyeContext")
    local dyeCtxMenu = ImguiElements.AddContextMenu(dyeCtxPop, "Dye Options")

    dyeBtn.SameLine = true

    removeDyeBtn.OnClick = function ()
        dyeChannel:SendToServer({
            Guid = getEquipment(ent, slot).Uuid.EntityUuid,
            DyePreset = nil,
        })
        parent.Disabled = true
        Ext.Timer.WaitForRealtime(100, function ()
            refreshDyer(ent, slot)
        end)
    end

    dyeBtn.OnClick = function (_, preset)
        colorPreset = preset or colorPreset
        colorPreset.GlowColor = colorPreset.Glow_Color
        dyeChannel:SendToServer({
            Guid = getEquipment(ent, slot).Uuid.EntityUuid,
            DyePreset = colorPreset,
        })
        parent.Disabled = true
        Ext.Timer.WaitForRealtime(100, function ()
            refreshDyer(ent, slot)
        end)
    end
    local function dyeThis(preset)
        dyeBtn.OnClick(nil, preset)
    end

    dyeBtn.OnRightClick = function ()
        dyeCtxPop:Open()
    end
    dyeCtxMenu:AddItem("Dye All", function (selectable)
        local allSlots = equipmentSlots
        parent.Disabled = true
        for _, s in pairs(allSlots) do
            local equip = getEquipment(ent, s)
            if equip and equip.Uuid then
                dyeChannel:SendToServer({
                    Guid = equip.Uuid.EntityUuid,
                    DyePreset = colorPreset,
                })
            end
        end
        Ext.Timer.WaitForRealtime(100, function ()
            refreshDyer(ent, slot)
        end)
    end)
    dyeCtxMenu:AddItem("Undye All", function (selectable)
        local allSlots = equipmentSlots
        parent.Disabled = true
        for _, s in pairs(allSlots) do
            local equip = getEquipment(ent, s)
            if equip and equip.Uuid then
                dyeChannel:SendToServer({
                    Guid = equip.Uuid.EntityUuid,
                    DyePreset = nil,
                })
            end
        end
        Ext.Timer.WaitForRealtime(100, function ()
            refreshDyer(ent, slot)
        end)
    end)

    local dyeListPop = rightCell:AddPopup("DyeList")
    local nameInput = rightCell:AddInputText("Name##Input")
    local saveBtn = rightCell:AddButton("Save")
    local loadBtn = rightCell:AddButton("Load")

    local charWidth = 20 * SCALE_FACTOR
    local minWidth = charWidth * 5
    nameInput.OnChange = function ()
        if nameInput.EnterReturnsTrue then
            saveBtn.OnClick(nil, false)
            nameInput.SizeHint = { minWidth, 0 }
            return
        end

        local chars = #nameInput.Text
        nameInput.SizeHint = { math.max(chars * charWidth, minWidth), 0 }
    end
    nameInput:OnChange() -- initialize size
    nameInput.EnterReturnsTrue = true

    saveBtn.SameLine = true
    loadBtn.SameLine = true
    saveBtn.OnClick = function (_, overwrite)
        local presetName = nameInput.Text ~= "" and nameInput.Text or "Dye"

        if this.DyePresets[presetName] and not overwrite then
            ConfirmPopup:QuickConfirm(
                "Preset with '" .. presetName .. "' already exists. Do you want to overwrite it?",
                function () saveBtn.OnClick(nil, true) end,
                function () end
            )
            return
        end

        Dyer.DyePresets[presetName] = RBUtils.DeepCopy(colorPreset)
        Dyer.SaveToLocalFile(Dyer.DyePresets)

        nameInput.Text = ""
        ImguiHelpers.DestroyAllChildren(dyeListPop)
        renderDyesList(dyeListPop, dyeThis)
    end

    loadBtn.OnClick = function ()
        ImguiHelpers.DestroyAllChildren(dyeListPop)
        renderDyesList(dyeListPop, dyeThis)
        dyeListPop:Open()
    end

    local dyeTable = parent:AddTable("DyeParams", 2)
    dyeTable.ColumnDefs[1] = { WidthStretch = true }
    dyeTable.ColumnDefs[2] = { WidthFixed = true }
    dyeTable.RowBg = true
    curDyerTable = dyeTable

    local function isDestroyed()
        return dyeTable ~= curDyerTable
    end

    for _, paramName in pairs(paramOrder) do
        local default = params[paramName] or { 0.0, 0.0, 0.0 }
        local row = dyeTable:AddRow()
        local nameCell = row:AddCell()
        local inputCell = row:AddCell()

        local hasParameter = false
        if obj then
            local isParamGlow = paramName == "Glow_Color"
            local renderable = obj and obj.Renderable
            local fetchName = paramName
            hasParameter = renderableHasParameter(renderable, fetchName)
            if not hasParameter then
                hasParameter = isParamGlow and renderableHasParameter(renderable, "GlowColor")
                if hasParameter then
                    fetchName = "GlowColor"
                end
            end
            default = hasParameter and renderable.ActiveMaterial:GetVector3(fetchName) or default
            colorPreset[paramName] = default
        end
        
        local nameSel = nameCell:AddSelectable(paramName:gsub("_", " "))
        local input = inputCell:AddColorEdit("##" .. paramName, default)
        local reset = inputCell:AddImageButton("##Reset " .. paramName, RB_ICONS.Arrow_CounterClockwise, IMAGESIZE.ROW)

        nameSel.OnClick = function ()
            nameSel.Selected = false
        end

        input.PickerHueWheel = true
        input.NoInputs = true
        reset.SameLine = true

        if not hasParameter then
            local t = nameCell:AddText("Maybe Invalid")
            t.SameLine = true
            t.Font = "Tiny"
            t:SetColor("Text", { 1, 0.2, 0, 0.5})
        end

        input.NoAlpha = true

        local shouldStop = false
        --- @type fun(input: ExtuiColorEdit)
        input.OnChange = function (input)
            shouldStop = true
            local newColor = { input.Color[1], input.Color[2], input.Color[3] }
            dyeEquipment(getEnt(), slot, paramName, newColor)
            colorPreset[paramName] = newColor
            nameSel.Highlight = true
        end

        input.OnHoverEnter = function ()
            shouldStop = false
            
            local max = 1
            local min = 0
            local color = { max, max, max }
            local delta = -0.01
            Timer:Every(10, function (timer)
                if shouldStop or isDestroyed() then
                    dyeEquipment(getEnt(), slot, paramName, colorPreset[paramName] or default)
                    shouldStop = false
                    return UNSUBSCRIBE_SYMBOL
                end

                dyeEquipment(getEnt(), slot, paramName, color)
                for i, v in pairs(color) do
                    color[i] = Ext.Math.Clamp(v + delta, min, max)
                end
                if color[1] >= max or color[1] <= min then
                    delta = -delta
                end
            end)
        end

        input.OnHoverLeave = function ()
            shouldStop = true
        end

        reset.OnClick = function ()
            input.Color = {default[1], default[2], default[3], 1}
            dyeEquipment(getEnt(), slot, paramName, default)
            colorPreset[paramName] = default
            nameSel.Highlight = false
        end

        ::continue::
    end
end

local borderField = "FrameBorderSize"
local selectedBorderColor = { 1, 0.6, 0, 1 }
local defaultBorderColor = { 1, 1, 1, 0.5 }

local function refreshSelection()
    selectedChar = _C() --[[@as EntityHandle]]
    local selectedSlot = nil
    if not selectedChar then return end
    if not selectedChar.ClientEquipmentVisuals then return end

    local parent = selection
    ImguiHelpers.DestroyAllChildren(materialEditor)
    ImguiHelpers.DestroyAllChildren(parent)

    local icon = RBGetIcon(selectedChar and selectedChar.Uuid.EntityUuid)
    local name = selectedChar and selectedChar.DisplayName.Name:Get() or "None"
    parent:AddImage(icon, IMAGESIZE.ROW)
    parent:AddText(name).SameLine = true
    local resetVisual = parent:AddImageButton("##Refresh" .. name, RB_ICONS.Arrow_CounterClockwise, IMAGESIZE.ROW)
    resetVisual.OnClick = function ()
        NetChannel.Replicate:SendToServer({
            Guid = selectedChar.Uuid.EntityUuid,
            Field = "GameObjectVisual",
        })
        if selectedSlot then
            refreshDyer(selectedChar, selectedSlot)
        end
    end
    resetVisual:Tooltip():AddText("Refresh visual for this character.")
    resetVisual.SameLine = true

    
    local tab = selection:AddTable("Selection", selectionCols)

    for i=1, selectionCols do
        tab.ColumnDefs[i] = { WidthFixed = true }
    end

    local cells = {} --[[@type table<number, table<number, ExtuiTableCell>> ]]
    for i=1, selectionRows do
        local row = tab:AddRow()
        cells[i] = {}

        for j=1, selectionCols do
            cells[i][j] = row:AddCell()
        end
    end

    --- @type table<ItemSlot, ExtuiTableCell>
    local slotToCell = {
        ["Helmet"] = cells[1][2],
        ["Cloak"] = cells[2][1],
        ["Breast"] = cells[2][2],
        ["Gloves"] = cells[2][3],
        ["Boots"] = cells[3][2],

        ["MeleeMainHand"] = cells[4][1],
        ["MeleeOffHand"] = cells[4][2],
        ["RangedMainHand"] = cells[5][1],
        ["RangedOffHand"] = cells[5][2],

        ["MusicalInstrument"] = cells[4][3],

        ["Underwear"] = cells[5][3],
        ["VanityBody"] = cells[1][2],
        ["VanityBoots"] = cells[2][2],
    }

    local slotMask = {
        ["Normal"] = {
            ["Underwear"] = true,

            ["Helmet"] = true,
            ["Cloak"] = true,
            ["Breast"] = true,
            ["Gloves"] = true,
            ["Boots"] = true,

            ["MeleeMainHand"] = true,
            ["MeleeOffHand"] = true,
            ["RangedMainHand"] = true,
            ["RangedOffHand"] = true,

            ["MusicalInstrument"] = true,
        },
        ["Vanity"] = {
            ["Underwear"] = true,

            ["VanityBody"] = true,
            ["VanityBoots"] = true,

            ["MeleeMainHand"] = true,
            ["MeleeOffHand"] = true,
            ["RangedMainHand"] = true,
            ["RangedOffHand"] = true,

            ["MusicalInstrument"] = true,
        }
    }

    local currentArmorState = selectedChar.ArmorSetState.State
    local currentSlotMask = slotMask[currentArmorState] or slotMask["Normal"]
    local cellControllers = {} --[[@type table<ItemSlot, {Shrink: fun(), Expand: fun()}>> ]]

    for slot, enabled in pairs(currentSlotMask) do
        local item = getEquipment(selectedChar, slot)
        if not item or not (item.Wielding or getEquipmentFirstVisual(selectedChar, slot) ~= nil) or not item.Uuid or not item.Uuid.EntityUuid then
            local hasCell = slotToCell[slot] ~= nil
            if hasCell then
                local cell = slotToCell[slot]
                cell:AddDummy(selectionImageSize, selectionImageSize)
            end
            goto continue --return
        end

        local guid = item.Uuid.EntityUuid
        local thisCell = slotToCell[slot] or tab:AddRow():AddCell()
        local itemIcon = RBGetIcon(item.Uuid.EntityUuid)
        local iconSize = selectionImageSize
        local itemStats = Ext.Stats.Get(item.Data.StatsId)
        local rarity = pcall(function() return itemStats.Rarity end) and itemStats.Rarity or "Common"
        local btn = thisCell:AddImageButton(slot, itemIcon, { iconSize, iconSize })
        local animFps = 90
        local shrinkMs = 200
        local expandMs = 300
        local shrinkWidth = 2
        local expandWidth = 6 * SCALE_FACTOR
        local runningAnim = nil --[[@type RunningAnimation?]]
        local colorAnim = nil --[[@type RunningAnimation?]]
        local rarityColor = RARITY_COLORS[rarity] or RARITY_COLORS.Common
        btn.Background = rarityColor
        local borderColor = rarity == "Common" and defaultBorderColor or ColorUtils.AdjustColor(rarityColor, 0.2)

        thisCell:SetColor("Border", Vector.Lerp(borderColor, selectedBorderColor, 0))
        thisCell:SetColor("Button", rarityColor)
        thisCell:SetColor("ButtonHovered", ColorUtils.AdjustColor(rarityColor, 0.1))
        thisCell:SetColor("ButtonActive", ColorUtils.AdjustColor(rarityColor, -0.05))
        thisCell:SetStyle(borderField, shrinkWidth)

        btn:Tooltip():AddText(item.DisplayName.Name:Get() or guid)

        local function getCur()
            return thisCell:GetStyle(borderField) or 0
        end 

        local function shrink(changeColor)
            if runningAnim then
                runningAnim:Stop()
            end
            
            local curColor = thisCell:GetColor("Border") or borderColor
            runningAnim = AnimateValue(animFps, getCur(), shrinkWidth, shrinkMs, "Linear", function ()
                runningAnim = nil
            end, function (value, t)
                thisCell:SetStyle(borderField, value)
            end)
            colorAnim = AnimateValue(animFps, 0, 1, shrinkMs, "Linear", function ()
                colorAnim = nil
            end, function (value)
                if changeColor then
                    thisCell:SetColor("Border", Vector.Lerp(curColor, borderColor, value))
                end
            end)
        end

        local function expand()
            if runningAnim then
                runningAnim:Stop()
            end

            runningAnim = AnimateValue(animFps, getCur(), expandWidth, expandMs, "Linear", function ()
                runningAnim = nil
            end, function (value, t)
                thisCell:SetStyle(borderField, value)
            end)
        end

        cellControllers[slot] = {
            Shrink = shrink,
            Expand = expand,
        }

        btn.OnClick = function ()
            local lastSlot = selectedSlot
            if lastSlot and cellControllers[lastSlot] then
                cellControllers[lastSlot].Shrink(true)
            end
            expand()
            if colorAnim then colorAnim:Stop() colorAnim = nil end
            thisCell:SetColor("Border", selectedBorderColor)
            refreshDyer(selectedChar, slot)
            selectedSlot = slot

        end

        btn.OnHoverEnter = function ()
            if selectedSlot == slot then return end

            expand()
        end

        btn.OnHoverLeave = function ()
            if selectedSlot == slot then return end

            shrink()
        end

        --btn.CanDrag = true
        btn.DragDropType = dragFlag

        btn.OnDragDrop = function (self, drop)
            local data = drop.UserData and drop.UserData.DyePreset
            if not data then return end
            dyeChannel:SendToServer({
                Guid = guid,
                DyePreset = data,
            })

            if selectedSlot ~= slot then return end
            -- refresh ui if the dye was applied to the currently selected slot
            materialEditor.Disabled = true
            Ext.Timer.WaitForRealtime(100, function ()
                refreshDyer(selectedChar, slot)
            end)
        end

        ::continue::
    end
end

refreshSelection()

refreshBtn.OnClick = function ()
    refreshSelection()
end

makeEmptyMaterialPreset.OnClick = function ()
    local cnt = 120

    --- @type RB_ParameterSet
    local paramSet = {
        {},
        {},
        params,
        {}
    }
    paramSet[3].GlowColor = paramSet[3].Glow_Color

    local matPresetRegion = LSXHelpers.BuildMaterialPresetBank()
    local luaMap = 
[[
return {    
]]
    local makeLuaLine = function(uuid, name)
        luaMap = luaMap .. string.format(
[[
    ["%s"] = "%s",
]],
    uuid, name)
    end
    local finishLuaMap = function()
        luaMap = luaMap ..
[[
}
]]
    end

    for i=1, cnt do
        local presetName = "RB_Dye_Mat_Preset_" .. i
        local uuid = RBUtils.Uuid_v4()
        local matPresetNode = ResourceHelpers.BuildMaterialPresetResourceNode(
            paramSet,
            uuid,
            presetName
        )
        makeLuaLine(uuid, presetName)
        matPresetRegion:AppendChild(matPresetNode)
    end

    finishLuaMap()

    local path = dyerFolder .. "MaterialPresets.lua"
    local ok, err = Ext.IO.SaveFile(path, luaMap)

    local xmlPath = dyerFolder .. "MaterialPresets.lsx"
    local xmlContent = matPresetRegion:Stringify({
        AutoFindRoot = true,
    })
    local ok2, err2 = Ext.IO.SaveFile(xmlPath, xmlContent)
    
    if not ok then
        Error("Failed to save Material Presets Lua map: " .. tostring(err))
    end

    if not ok2 then
        Error("Failed to save Material Presets XML: " .. tostring(err2))
    end

    if ok and ok2 then
        Trace("Successfully created " .. cnt .. " material presets and saved to " .. dyerFolder)
    end
end

NetChannel.ComponentSubscription:SetHandler(function (data, userId)
    if data.Component ~= "ArmorSetState" then return end
    local ent = Ext.Entity.Get(data.Guid)
    if not ent then return end
    local selected = _C() --[[@as EntityHandle]]
    if not selected then return end
    if selected.Uuid.EntityUuid ~= data.Guid then return end

    refreshSelection()
end)

NetChannel.OsirisSubscription:SetHandler(function (data, userId)
    if data.Event ~= "Equipped" and data.Event ~= "Unequipped" then return end
    local item = data.Args[1]
    local character = data.Args[2]
    if not item or not character then return end

    local ent = Ext.Entity.Get(character)
    if not ent then return end

    local selected = _C() --[[@as EntityHandle]]
    if not selected then return end
    if selected.Uuid.EntityUuid ~= character then return end

    refreshSelection()
end)

Ext.Entity.OnCreate("ClientControl", function (entity)
    local cEV = entity.ClientEquipmentVisuals
    if not cEV then return end

    local entId = entity.Uuid.EntityUuid
    local selected = _C() --[[@as EntityHandle]]
    if not selected then return end
    if selected.Uuid.EntityUuid ~= entId then return end

    refreshSelection()
end)

Dyer.DyePresets = Dyer.LoadFromLocalFile() or {}

end)