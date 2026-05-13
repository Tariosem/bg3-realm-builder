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

--- @alias DyePresetName string

local Dyer = {
    --- @type table<DyePresetName, DyePreset>
    DyePresets = {

    }
}

local this = Dyer
local dyerFolder = "RB_Dyer/"

--- @return table<DyePresetName, DyePreset>|nil
function Dyer.LoadFromLocalFile()
    local path = dyerFolder .. "Local.json"
    local content = Ext.IO.LoadFile(path)
    if not content then return nil end
    return Ext.Json.Parse(content)
end

--- @param data table<DyePresetName, DyePreset>
function Dyer.SaveToLocalFile(data)
    local path = dyerFolder .. "Local.json"
    local content = Ext.Json.Stringify(data)
    local ok, err = Ext.IO.SaveFile(path, content)
    if not ok then
        Error("Failed to save Dyer data: " .. tostring(err))
    end
end

--#region UI
EventsSubscriber.RegisterOnSessionLoaded(function ()
local DyerWindow = WindowManager.RegisterWindow("generic", "Dyer")
local selectedChar = nil 

DyerWindow.AlwaysAutoResize = true
DyerWindow.Visible = false


--#region declare
local function refreshSelection() end
local function refreshDyer(ent, slot) end
--#endregion

InputEvents.SubscribeKeyInput({
    Key = "D",
}, function (e)
    if not e.Pressed then return end
    if not e.Modifiers or Enums.SDLKeyModifier.LAlt ~= e.Modifiers then return end

    refreshSelection()
    DyerWindow.Visible = not DyerWindow.Visible
end)

local matParamCache = {}

--- @param c1 vec3
--- @param c2 vec3
--- @return boolean
local function isSameColor(c1, c2)
    return c1[1] == c2[1] and c1[2] == c2[2] and c1[3] == c2[3]
end

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

--- @param ent EntityHandle
--- @param slot ItemSlot
--- @return Visual?
local function getEquipmentFirstVisual(ent, slot)
    local visuals = getEquipmentVisuals(ent, slot)
    return visuals and visuals[1]
end

--- @param ent EntityHandle
--- @param slot ItemSlot
--- @param paramName string
--- @param color vec3
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

--- @param ent EntityHandle
--- @param slot ItemSlot
--- @param dyePreset DyePreset
local function dyeEquipmentWithPreset(ent, slot, dyePreset)
    DummyHelpers.GetClientVisualDummy(ent.Uuid.EntityUuid, {entity = ent})
    
    for _, subVisualEnt in pairs(ent.ClientEquipmentVisuals and ent.ClientEquipmentVisuals.Equipment and ent.ClientEquipmentVisuals.Equipment[slot] and ent.ClientEquipmentVisuals.Equipment[slot].SubVisuals or {}) do
        for _, obj in pairs(subVisualEnt.Visual and subVisualEnt.Visual.Visual and subVisualEnt.Visual.Visual.ObjectDescs or {}) do
            if obj.Renderable then
                for paramName, color in pairs(dyePreset) do
                    if paramName ~= "DyePresetName" then
                        if obj.Renderable.ActiveMaterial and renderableHasParameter(obj.Renderable, paramName) then
                            obj.Renderable.ActiveMaterial:SetVector3(paramName, color)
                        elseif obj.Renderable.ActiveMaterial and paramName == "Glow_Color" and renderableHasParameter(obj.Renderable, "GlowColor") then
                            obj.Renderable.ActiveMaterial:SetVector3("GlowColor", color)
                        end
                    end
                end
            end
        end
    end
end

--- @param from DyePreset
--- @param to DyePreset
local function copyPreset(from, to)
    for k, v in pairs(from) do
        if k ~= "DyePresetName" then
            to[k] = v
        end
    end
end

local refreshBtn = DyerWindow:AddButton("Refresh")
local makeEmptyMaterialPreset = DyerWindow:AddButton("Make Empty Material Preset")
local mainTable = DyerWindow:AddTable("Main", 3)
local mainRow = mainTable:AddRow()
local selectionCols = 3
local selectionRows = 6
local selectionImageSize = 64 * SCALE_FACTOR
local expandedImageSize = 96 * SCALE_FACTOR

makeEmptyMaterialPreset.SameLine = true

mainTable.ColumnDefs[1] = { WidthFixed = true, Width = expandedImageSize * selectionCols }
mainTable.ColumnDefs[2] = { WidthStretch = true }
mainTable.ColumnDefs[3] = { WidthStretch = true }

local selection = mainRow:AddCell()
local materialEditor = mainRow:AddCell()
local dyeList = mainRow:AddCell()

--- @param visual Visual?
--- @return VisualObjectDesc?
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
--- @return ExtuiSelectable, fun()
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

    local renameInput = nameCell:AddInputText("##Rename" .. name)
    renameInput.SameLine = true
    renameInput.Visible = false

    local deleteBtn = deleteCell:AddImageButton("##Delete" .. name, RB_ICONS.X_Square, IMAGESIZE.ROW)

    local function dragStart(self)
        self.UserData = { DyePreset = dyePreset }
        renderDyeEntry(self.DragPreview:AddTable("", 3), name, dyePreset)
    end

    local charWidth = 20 * SCALE_FACTOR
    local minWidth = charWidth * 10
    local renameStart = function ()
        nameSel.Visible = false
        renameInput.Visible = true
        renameInput.Text = name
        renameInput.EnterReturnsTrue = true
        renameInput.SizeHint = { math.max(charWidth * #name, minWidth), 0 }
    end

    --- @param self ExtuiInputText
    local renameEnd = function (self)
        local newName = self.Text
        if newName ~= "" and newName ~= name then
            Dyer.DyePresets[newName] = Dyer.DyePresets[name]
            Dyer.DyePresets[name] = nil
            Dyer.SaveToLocalFile(Dyer.DyePresets)
            nameSel.Label = newName
            name = newName
        end
        nameSel.Visible = true
        renameInput.Visible = false
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
        ConfirmPopup:QuickConfirm("Delete Dye Preset" .. name .. "?", function ()
            Dyer.DyePresets[name] = nil
            Dyer.SaveToLocalFile(Dyer.DyePresets)
            row:Destroy()
        end)
    end

    renameInput.OnChange = function (self)
        if self.EnterReturnsTrue then
            renameEnd(self)
            return
        end

        renameInput.SizeHint = { math.max(charWidth * #self.Text, minWidth), 0 }
    end

    return nameSel, renameStart
end

local curPage = 1
local pageSize = 10
local pageDirty = true
local lastSearchTerm = ""
local pages = {} --- @type {Preset: DyePreset, Name: string}[]

--- @param key string
local function repopulatePage(key)
    key = key:lower() or ""
    pages = {}
    for name, preset in pairs(Dyer.DyePresets) do
        if name:lower():find(key) then
            table.insert(pages, {Preset = preset, Name = name})
        end
    end

    table.sort(pages, function (a, b)
        return a.Name < b.Name
    end)

    pageDirty = false
end

--- @param colorPreset DyePreset
--- @param ent EntityHandle
--- @param slot ItemSlot
--- @param refreshFns table<string, fun()>
local function refreshDyeList(colorPreset, ent, slot, refreshFns)
    local parent = dyeList

    local cnt = RBTableUtils.CountMap(Dyer.DyePresets)
    local maxPage = math.ceil(cnt / pageSize)
    curPage = math.min(curPage, maxPage)

    if pageDirty then
        repopulatePage(lastSearchTerm)
    end

    local page = {} --- @type {Preset: DyePreset, Name: string}[]
    local pageStart = (curPage - 1) * pageSize + 1
    local pageEnd = math.min(pageStart + pageSize - 1, #pages)
    for i=pageStart, pageEnd do
        table.insert(page, pages[i])
    end

    ImguiHelpers.DestroyAllChildren(parent)

    parent:AddSeparatorText("Dye Presets"):SetStyle("SeparatorTextAlign", 0.5)
    local pageFnTable = parent:AddTable("PageFn", 3)
    local listTab = parent:AddTable("DyeList", 3)
    listTab.ColumnDefs[1] = { WidthFixed = true }
    listTab.ColumnDefs[2] = { WidthStretch = true }
    listTab.ColumnDefs[3] = { WidthFixed = true }
    pageFnTable.ColumnDefs[1] = { WidthFixed = true }
    pageFnTable.ColumnDefs[2] = { WidthStretch = true }
    pageFnTable.ColumnDefs[3] = { WidthFixed = true }
    local pageFnRow = pageFnTable:AddRow()

    

    --- @type ExtuiTableCell[]
    local pageCells = {pageFnRow:AddCell(), pageFnRow:AddCell(), pageFnRow:AddCell()}

    pageCells[1]:AddText(string.format("Page %d / %d", curPage, maxPage))
    local searchInput = pageCells[2]:AddInputText("##SearchDyePresets")
    local prevBtn = pageCells[3]:AddButton("<")
    local nextBtn = pageCells[3]:AddButton(">")
    nextBtn.SameLine = true

    prevBtn.OnClick = function()  curPage = math.max(curPage - 1, 1) refreshDyeList(colorPreset, ent, slot, refreshFns) end
    nextBtn.OnClick = function()  curPage = math.min(curPage + 1, maxPage) refreshDyeList(colorPreset, ent, slot, refreshFns) end

    searchInput.EnterReturnsTrue = true
    searchInput.Text = lastSearchTerm
    searchInput.OnChange = function (e)
        if searchInput.EnterReturnsTrue then
            lastSearchTerm = e.Text
            pageDirty = true
            refreshDyeList(colorPreset, ent, slot, refreshFns)
            return
        end
    end

    listTab.RowBg = true

    RBUtils.AsyncForEach(page, function(entry)
        local sel, renameStart = renderDyeEntry(listTab, entry.Name, entry.Preset)
        sel.OnClick = function ()
            dyeEquipmentWithPreset(ent, slot, entry.Preset)
            for _, fn in pairs(refreshFns) do
                fn()
            end
        end
        sel.OnClick = RBUtils.DoubleClick(sel.OnClick, renameStart)
        sel.OnHoverEnter = function ()
            dyeEquipmentWithPreset(ent, slot, entry.Preset)
        end
        sel.OnHoverLeave = function ()
            dyeEquipmentWithPreset(ent, slot, colorPreset)
        end
    end)
end

---@param parent ExtuiTreeParent
---@param colorPreset DyePreset
---@param ent EntityHandle
---@param slot ItemSlot
---@param resetFns table<string, fun()>
---@param refreshFns table<string, fun()>
local function renderDyeManager(parent, colorPreset, ent, slot, resetFns, refreshFns)
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
        if preset then copyPreset(preset, colorPreset) end
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

    local saveBtn = rightCell:AddButton("Save")
    local resetAllBtn = rightCell:AddButton("Reset All")

    resetAllBtn.SameLine = true

    saveBtn.OnClick = function (_)
        local presetName = "Dye "

        local cnt = 1
        while this.DyePresets[presetName .. cnt] do
            cnt = cnt + 1
        end

        Dyer.DyePresets[presetName .. cnt] = RBUtils.DeepCopy(colorPreset)
        Dyer.SaveToLocalFile(Dyer.DyePresets)
        
        refreshDyeList(colorPreset, ent, slot, refreshFns)
    end
    refreshDyeList(colorPreset, ent, slot, refreshFns)

    resetAllBtn.OnClick = function ()
        for _, fn in pairs(resetFns) do
            fn()
        end
    end
end

--- @type vec3[]
local colorPalette = {
    {1, 0, 0},
    {0, 1, 0},
    {0, 0, 1},
    {1, 1, 0},
    {1, 0, 1},
    {0, 1, 1},
    {1, 1, 1},
    {0.5, 0.5, 0.5},
    {0.25, 0.25, 0.25},
}

local curDyerTable = nil
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
    
    local colorPalettePanel = parent:AddGroup("Palette")

    local resetFns = {}
    local refreshFns = {}
    renderDyeManager(parent, colorPreset, ent, slot, resetFns, refreshFns)

    local function renderPalette()
        ImguiHelpers.DestroyAllChildren(colorPalettePanel)
        for i, c in pairs(colorPalette) do
            local input = colorPalettePanel:AddColorEdit("##Palette" .. i, c)
            input.NoInputs = true
            input.Color = { c[1], c[2], c[3], 1 }
            input.NoPicker = true
            input.SameLine = (i - 1) % 9 ~= 0 -- 9 per row, lua table start at 1
        end
    end

    local function addToPalette(color)
        table.insert(colorPalette, 1, color)
        while (#colorPalette >= 10) do
            table.remove(colorPalette)
        end
        renderPalette()
    end

    renderPalette()

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

        input.OnRightClick = function ()
            local toAdd = { input.Color[1], input.Color[2], input.Color[3] }
            addToPalette(toAdd)
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
        resetFns[paramName] = reset.OnClick
        refreshFns[paramName] = function ()
            local aliveObj = findFirstValidObjectInVisual(getEquipmentFirstVisual(getEnt(), slot))
            if aliveObj and renderableHasParameter(aliveObj.Renderable, paramName) then
                local current = aliveObj.Renderable.ActiveMaterial:GetVector3(paramName)
                if not current then return end
                input.Color = { current[1], current[2], current[3], 1 }
                colorPreset[paramName] = { current[1], current[2], current[3] }
                nameSel.Highlight = not isSameColor(current, default) 
            end
        end
        ::continue::
    end
end

local borderField = "FrameBorderSize"
local selectedBorderColor = { 1, 0.6, 0, 1 }
local defaultBorderColor = { 1, 1, 1, 0.5 }

function refreshSelection()
    selectedChar = _C() --[[@as EntityHandle]]
    local selectedSlot = nil
    if not selectedChar then return end
    if not selectedChar.ClientEquipmentVisuals then return end

    local parent = selection
    parent.Disabled = false
    ImguiHelpers.DestroyAllChildren(materialEditor)
    ImguiHelpers.DestroyAllChildren(parent)

    local icon = RBGetIcon(selectedChar and selectedChar.Uuid.EntityUuid)
    local name = selectedChar and selectedChar.DisplayName.Name:Get() or "None"
    parent:AddImage(icon, IMAGESIZE.ROW)
    parent:AddText(name).SameLine = true
    local resetVisual = parent:AddImageButton("##Refresh" .. name, RB_ICONS.Arrow_CounterClockwise, IMAGESIZE.ROW)
    resetVisual.OnClick = function ()
        parent.Disabled = true
        NetChannel.Replicate:SendToServer({
            Guid = selectedChar.Uuid.EntityUuid,
            Field = "GameObjectVisual",
        })
        if selectedSlot then
            Ext.Timer.WaitForRealtime(100, function ()
                parent.Disabled = false
                refreshDyer(selectedChar, selectedSlot)
            end)
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
        if not item
            or not (item.Wielding or getEquipmentFirstVisual(selectedChar, slot) ~= nil)
            or not item.Uuid 
            or not item.Uuid.EntityUuid
        then
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
local debounceRefresh = RBUtils.Debounce(100, refreshSelection)

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

    debounceRefresh()
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

    debounceRefresh()
end)

--- @param entity EntityHandle
Ext.Entity.OnCreate("ClientControl", function (entity)
    if entity.UserReservedFor and entity.UserReservedFor.UserID ~= 1 then return end

    debounceRefresh()
end)

Dyer.DyePresets = Dyer.LoadFromLocalFile() or {}

end)
--#endregion