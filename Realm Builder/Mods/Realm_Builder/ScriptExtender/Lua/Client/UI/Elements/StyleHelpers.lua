--- @class StyleHelpers
--- @field AddContextMenu fun(parent: ExtuiTreeParent): RB_ContextMenu
--- @field AddSelectableButton fun(parent: ExtuiTreeParent, label: string, onClick: fun(selectable: ExtuiSelectable)): ExtuiSelectable
--- @field SetImguiDisabled fun(extui: ExtuiRenderable, disabled: boolean)
--- @field SetAlphaByBool fun(s: ExtuiRenderable, bool: boolean)
--- @field AddPrefixInput fun(parent: ExtuiTreeParent, prefix: string?, text: string, readOnly: boolean?): ExtuiInputText
--- @field AddReadOnlyAttrTable fun(parent:ExtuiTreeParent, contents:table<string, string>):AttrTable
StyleHelpers = StyleHelpers or {}

---@param parent ExtuiTreeParent|ExtuiStyledRenderable
---@param label string
---@param default number
---@param min number
---@param max number
---@return ExtuiSliderInt
function SafeAddSliderInt(parent, label, default, min, max)
    --- @diagnostic disable-next-line
    return parent:AddSliderInt(label or "", math.floor(default or 0), math.floor(min or 0), math.floor(max or 100))
end

--- @param parent ExtuiTreeParent
--- @param label string
--- @param step number
--- @param slider? ExtuiSliderInt|ExtuiSliderScalar
--- @param direction? '<'|'>'
--- @return ExtuiButton
local function AddSliderStepButton(parent, label, step, slider, direction)
    local button = parent:AddButton(label)
    button.IDContext = Uuid_v4()

    button.UserData = { Slider = slider }

    button.OnClick = function()
        local s = button.UserData.Slider
        if not s then
            return
        end
        local stepValue = s.UserData and s.UserData.Step or (step or 1)
        if direction == "<" then
            stepValue = -stepValue
        end
        local newValue = s.Value[1] + stepValue

        if s.UserData.Clamp then
            if newValue < s.Min[1] then
                newValue = s.Min[1]
            elseif newValue > s.Max[1] then
                newValue = s.Max[1]
            end
        end

        s.Value = { newValue, newValue, newValue, newValue }
        if s.OnChange then
            s:OnChange()
        end
    end

    button.OnRightClick = function()
        local s = button.UserData.Slider --[[@as ExtuiSliderInt|ExtuiSliderScalar]]
        if not s then
            return
        end
        if s.UserData.DisableRightClickSet then
            return
        end

        local dir = direction == "<" and "<" or ">"
        local factor = 10.0

        if s.UserData.IsInteger then
            factor = 10
        end

        if dir == ">" then
            local newMin = Vec4.new(s.Min) * factor
            local newMax = Vec4.new(s.Max) * factor
            if s.UserData.IsInteger then
                newMin = Vec4.new(math.floor(newMin[1]), math.floor(newMin[2]), math.floor(newMin[3]),
                    math.floor(newMin[4]))
                newMax = Vec4.new(math.floor(newMax[1]), math.floor(newMax[2]), math.floor(newMax[3]),
                    math.floor(newMax[4]))
            end
            s.Min = newMin
            s.Max = newMax
        else
            local newMin = Vec4.new(s.Min) / factor
            local newMax = Vec4.new(s.Max) / factor
            if s.UserData.IsInteger then
                newMin = Vec4.new(math.floor(newMin[1]), math.floor(newMin[2]), math.floor(newMin[3]),
                    math.floor(newMin[4]))
                newMax = Vec4.new(math.floor(newMax[1]), math.floor(newMax[2]), math.floor(newMax[3]),
                    math.floor(newMax[4]))
            end
            s.Min = newMin
            s.Max = newMax
        end
    end

    return button
end

--- @class RB_SliderWithStep : ExtuiSliderScalar
--- @field Value number
--- @field Visible boolean
--- @field SameLine boolean
--- @field HideResetButton boolean

--- @param parent ExtuiTreeParent
--- @param IDContext string?
--- @param defaultValue number
--- @param min number
--- @param max number
--- @param step number
--- @param isInteger? boolean
--- @return RB_SliderWithStep
function StyleHelpers.AddSliderWithStep(parent, IDContext, defaultValue, min, max, step, isInteger)
    local sliderProxy = {}
    if not IDContext then
        IDContext = Uuid_v4()
    end
    local stepInput = nil
    local slider = nil
    local decreButton = nil
    local increButton = nil
    step = step or 0.1
    if isInteger then
        step = math.floor(step)
        step = math.max(1, step)
        decreButton = AddSliderStepButton(parent, "<", -step, nil, "<")
        slider = SafeAddSliderInt(parent, "", defaultValue or 0, min or 0, max or 100)
        increButton = AddSliderStepButton(parent, ">", step, nil, ">")
    else
        decreButton = AddSliderStepButton(parent, "<", -step, nil, "<")
        slider = parent:AddSlider("", defaultValue or 0, min or 0, max or 100) --[[@as ExtuiSliderScalar]]
        increButton = AddSliderStepButton(parent, ">", step, nil, ">")
    end
    local resetButton, resetGroup = StyleHelpers.AddResetButton(parent, true)
    decreButton.UserData.Slider = slider
    increButton.UserData.Slider = slider
    decreButton:SetStyle("ItemSpacing", 0, 0)
    increButton:SetStyle("ItemSpacing", 0, 0)
    slider:SetStyle("ItemSpacing", 0, 0)

    local allEles = { decreButton, slider, increButton, resetButton }
    increButton.IDContext = IDContext .. "_IncreButton"
    slider.IDContext = IDContext .. "_Slider"
    decreButton.IDContext = IDContext .. "_DecreButton"

    slider.UserData = {}
    local hideResetBtn = false
    local ud = slider.UserData
    ud.IsInteger = isInteger
    ud.DecreButton = decreButton
    ud.IncreButton = increButton
    ud.Parent = parent
    ud.ResetButton = resetButton
    ud.Step = step
    ud.DisableRightClickSet = false
    ud.Clamp = false

    --decreButton.SameLine = true
    increButton.SameLine = true
    slider.SameLine = true

    --- @param s ExtuiSliderScalar|ExtuiSliderInt
    slider.OnRightClick = function(s)
        if s.UserData.DisableRightClickSet then
            return
        end

        local sliderPopup = parent:AddPopup("SliderPopup##" .. IDContext)
        local alignedTable = StyleHelpers.AddAlignedTable(sliderPopup)
        sliderPopup.IDContext = IDContext .. "_SliderPopup"
        stepInput = isInteger and alignedTable:AddInputInt("Step", math.floor(step)) or alignedTable:AddInputScalar("Step", step)
        stepInput.IDContext = IDContext .. "_StepInput"
        stepInput.OnChange = function(input)
            local val = isInteger and math.floor(input.Value[1]) or input.Value[1]
            s.UserData.Step = val
        end

        max = s.Max[1] or max
        local maxInput = isInteger and alignedTable:AddInputInt("Max", math.floor(max)) or alignedTable:AddInputScalar("Max", max)
        maxInput.IDContext = IDContext .. "_MaxInput"
        maxInput.OnChange = function(input)
            local val = isInteger and math.floor(input.Value[1]) or input.Value[1]
            s.Max = {val, val, val, val}
        end

        min = s.Min[1] or min
        local minInput = isInteger and alignedTable:AddInputInt("Min", math.floor(min)) or alignedTable:AddInputScalar("Min", min)
        minInput.IDContext = IDContext .. "_MinInput"
        minInput.OnChange = function(input)
            local val = isInteger and math.floor(input.Value[1]) or input.Value[1]
            s.Min = {val, val, val, val}
        end

        s.UserData.StepInput = stepInput

        sliderPopup:Open()
        slider.OnRightClick = function ()
            local toFunc = isInteger and ToVec4Int or ToVec4
            stepInput.Value = toFunc(isInteger and math.floor(s.UserData.Step) or s.UserData.Step)
            minInput.Value = toFunc(isInteger and math.floor(s.Min[1]) or s.Min[1])
            maxInput.Value = toFunc(isInteger and math.floor(s.Max[1]) or s.Max[1])
            sliderPopup:Open()
        end
    end

    resetButton.IDContext = IDContext .. "_ResetButton"
    resetButton.OnClick = function()
        slider.Value = ToVec4(defaultValue or 0)
        if slider.OnChange then
            slider:OnChange()
        end
    end

    setmetatable(sliderProxy, {
        __index = function(_, k)
            if k == "Visible" then
                return slider.Visible
            else
                return slider[k]
            end
        end,
        __newindex = function(_, k, v)
            if k == "Visible" then
                for _, ele in ipairs(allEles) do
                    ele.Visible = v
                end
                if hideResetBtn then
                    resetGroup.Visible = false
                end
            elseif k == "SameLine" then
                if v == true then
                    for _, ele in ipairs(allEles) do
                        ele.SameLine = v
                    end
                else
                    for i, ele in ipairs(allEles) do
                        if i == 1 then
                            ele.SameLine = false
                        else
                            ele.SameLine = true
                        end
                    end
                end
            elseif k == "HideResetButton" then
                hideResetBtn = v
                resetGroup.Visible = not v
            elseif k == "Value" then
                local toFunc = isInteger and ToVec4Int or ToVec4
                slider.Value = toFunc(v)
            else
                slider[k] = v
            end
        end
    })

    return sliderProxy
end

function ApplyInfoButtonStyle(button)
    button:SetColor("Button", CONFIG.Misc.InfoButtonColor)
    button:SetColor("ButtonHovered", CONFIG.Misc.InfoButtonHoveredColor)
    button:SetColor("ButtonActive", CONFIG.Misc.InfoButtonActiveColor)
    button:SetColor("Text", CONFIG.Misc.InfoButtonTextColor)
end

---@param button ExtuiButton
function ApplyDangerButtonStyle(button)
    button:SetColor("Button", CONFIG.Misc.DangerButtonColor)
    button:SetColor("ButtonHovered", CONFIG.Misc.DangerButtonHoveredColor)
    button:SetColor("ButtonActive", CONFIG.Misc.DangerButtonActiveColor)
    button:SetColor("Text", CONFIG.Misc.DangerButtonTextColor)
end

--- @param s ExtuiSelectable|ExtuiStyledRenderable
function ApplyDangerSelectableStyle(s)
    s:SetColor("HeaderHovered", CONFIG.Misc.DangerButtonColor)
    s:SetColor("Text", CONFIG.Misc.DangerButtonHoveredColor)
end

function ApplyConfirmButtonStyle(button)
    button:SetColor("Button", CONFIG.Misc.ConfirmButtonColor)
    button:SetColor("ButtonHovered", CONFIG.Misc.ConfirmButtonHoveredColor)
    button:SetColor("ButtonActive", CONFIG.Misc.ConfirmButtonActiveColor)
    button:SetColor("Text", CONFIG.Misc.ConfirmButtonTextColor)
end

--- @param tokens RB_TextToken[]
--- @param wrapPos number?
--- @return RB_TextToken[]
function WrapTextTokens(tokens, wrapPos)
    local wrapped = {}
    local currentLen = 0
    wrapPos = wrapPos or 60

    local function cloneToken(token, text)
        local newToken = {}
        for k, v in pairs(token) do
            newToken[k] = v
        end
        newToken.Text = text
        return newToken
    end

    local function addToken(token, text, newLine)
        local newToken = cloneToken(token, text)
        if newLine then
            currentLen = 0
            newToken.SameLine = false
        else
            newToken.SameLine = currentLen > 0
        end
        table.insert(wrapped, newToken)
        currentLen = currentLen + #text
    end

    for i, token in ipairs(tokens) do
        local text = token.Text or ""

        if token.TooltipRef then
            local tokenLen = #text
            local overflow = (currentLen + tokenLen > wrapPos)
            addToken(token, text, overflow)
        else
            local remaining = text
            while #remaining > 0 do
                local spaceLeft = wrapPos - currentLen

                if spaceLeft <= 0 then
                    currentLen = 0
                    spaceLeft = wrapPos
                end

                if #remaining > spaceLeft then
                    local search = remaining:sub(1, spaceLeft)
                    local breakPos = search:find(" [^ ]*$")
                    if breakPos then
                        local chunk = search:sub(1, breakPos - 1)

                        local nextChar = remaining:sub(breakPos + 1, breakPos + 1)
                        local nextCharInNextToken = false

                        if not nextChar or nextChar == "" then
                            local nextToken = tokens[i + 1]
                            if nextToken and nextToken.Text and #nextToken.Text > 0 then
                                nextChar = nextToken.Text:sub(1, 1)
                                nextCharInNextToken = true
                            end
                        end

                        if nextChar and nextChar:match("[%.,%(%)%[%]%{%}\"'“”‘’]") then
                            local chunk = remaining:sub(1, breakPos) .. nextChar
                            if nextCharInNextToken then
                                local nextToken = tokens[i + 1]
                                nextToken.Text = nextToken.Text:sub(2)
                            else
                                remaining = remaining:sub(breakPos + 2)
                            end

                            addToken(token, chunk)
                            remaining = remaining:sub(breakPos + 2)
                            goto continue_token
                        end

                        if nextChar and nextChar:match("%s") then
                            breakPos = breakPos + 1
                        end

                        if nextChar:match("%s") then
                            breakPos = breakPos + 1
                        end

                        addToken(token, chunk)
                        remaining = remaining:sub(breakPos + 1)
                    else
                        if currentLen > 0 then
                            currentLen = 0
                        else
                            local chunk = remaining:sub(1, spaceLeft)
                            addToken(token, chunk)
                            remaining = remaining:sub(spaceLeft + 1)
                        end
                    end
                else
                    addToken(token, remaining, false)
                    remaining = ""
                end

                ::continue_token::
            end
        end
    end

    return wrapped
end

---@param parent ExtuiTreeParent
---@param label string?
---@return ExtuiTable
---@return ExtuiTableCell
---@return ExtuiTableCell
function AddTwoColTable(parent, label)
    local table = parent:AddTable(label or Uuid_v4(), 2)
    local row = table:AddRow()
    local leftCell = row:AddCell()
    local rightCell = row:AddCell()
    return table, leftCell, rightCell
end

--- @param s ExtuiRenderable
function SetAlphaByBool(s, bool)
    if bool then
        s:SetStyle("Alpha", 1)
    else
        s:SetStyle("Alpha", 0.6)
    end
end

function AddMenuButton(menu, text, onClick, isWindow)
    local label = text
    local button
    if isWindow then
        button = menu:AddItem(label)
        button.OnClick = onClick
    else
        button = menu:AddSelectable(label)
        button.OnClick = function(e)
            onClick()
            e.Selected = false
        end
    end
    return button
end

---@param parent ExtuiTreeParent
---@return ExtuiTableCell, ExtuiTableCell, ExtuiTable -- RightCell, LeftCell, Table
function StyleHelpers.AddRightAlignCell(parent)
    local tab, leftCell, rightCell = AddTwoColTable(parent)
    tab.ColumnDefs[1] = { WidthStretch = true }
    tab.ColumnDefs[2] = { WidthFixed = true }
    return rightCell, leftCell, tab
end

function GetCombo(Combo)
    return Combo.Options[Combo.SelectedIndex + 1]
end

---@param Combo ExtuiCombo
---@param Value string
---@param ifNotFoundAdd? boolean
---@param noTrigger? boolean
function SetCombo(Combo, Value, ifNotFoundAdd, noTrigger)
    for i, v in pairs(Combo.Options) do
        if v == Value then
            -- So the combo index start from 0 but lua table index start from 1. ???
            Combo.SelectedIndex = i - 1
            return
        end
    end
    if ifNotFoundAdd then
        table.insert(Combo.Options, Value)
        Combo.SelectedIndex = #Combo.Options - 1
    end

    if not noTrigger and Combo.OnChange then
        Combo:OnChange()
    end
end

---@param window any
function FocusWindow(window)
    if not IsWindowValid(window) then return end

    window:SetCollapsed(false)
    window:SetFocus()
    window.Open = true
end

--- @param extui ExtuiStyledRenderable
--- @return boolean
function IsFocused(extui)
    if not extui then return false end
    return (extui.StatusFlags & Ext.Enums.GuiItemStatusFlags.Focused) ~= 0
end

--- @param extui ExtuiStyledRenderable
--- @param alpha number?
local function DisableAndSetAlpha(extui, alpha)
    if not extui then return end
    extui.Disabled = true
    extui:SetStyle("Alpha", alpha or 0.6)
end

local function EnableAndSetAlpha(extui)
    if not extui then return end
    extui.Disabled = false
    extui:SetStyle("Alpha", 1)
end

function SetImguiDisabled(extui, disabled)
    if disabled then
        DisableAndSetAlpha(extui)
    else
        EnableAndSetAlpha(extui)
    end
end

function DestroyAllChildren(parent)
    if not parent then return end
    if not parent.Children then
        parent:Destroy()
        return
    end
    for _, child in ipairs(parent.Children) do
        if child.Destroy then
            child:Destroy()
        end
    end
end

function TraverseAllChildren(parent, func)
    if not parent then return end
    if not parent.Children then
        func(parent)
        return
    end
    for _, child in ipairs(parent.Children) do
        func(child)
    end
end


function AddStyleDebugWindow(extui, symbol)
    local readonly = {
        LastSize = true,
        LastPosition = true,
        Handle = true,

    }
    symbol = symbol or ""
    local window = Ext.IMGUI.NewWindow("Style Debugger " .. symbol .. "##" .. Uuid_v4())
    window.Closeable = true
    window.OnClose = function()
        window:Destroy()
    end
    for idon, value in pairs(extui) do
        if readonly[idon] then
            goto continue
        end
        if type(value) == "boolean" then
            ---@diagnostic disable
            window:AddCheckbox(idon).OnChange = function(c)
                extui[idon] = c.Checked
            end
        elseif type(value) == "number" then
            window:AddSliderInt(idon, value, 0, 100).OnChange = function(s)
                extui[idon] = s.Value[1]
            end
        elseif IsArrayOf(value, "number") then
            StyleHelpers.AddNumberSliders(window, idon, function ()
                return type(extui[idon]) == "number" and { extui[idon] } or LightCToArray(extui[idon])
            end, function (v)
                extui[idon] = #v == 1 and v[1] or v
            end, 
            {
                IsInt = math.type(value[1]) == "integer",
            })
        end
        ::continue::
    end

    for colorName, colorValue in pairs(GetAllGuiColorNames()) do
        window:AddColorEdit(colorName).OnChange = function(c)
            extui:SetColor(colorName, c.Color)
        end
    end

    for styleName, styleValue in pairs(GetAllGuiStyleVarNames()) do
        window:AddSlider(styleName).OnChange = function(i)
            i.Components = 2
            extui:SetStyle(styleName, i.Value[1], i.Value[2])
        end
    end
end

local function addLittleSpacer(parent, size)
    size = size or (10 * SCALE_FACTOR)
    local dummy = parent:AddDummy(size, 1)
    dummy.SameLine = true
    return dummy
end


function StyleHelpers.AddResetButton(parent, sameLine) 
    local group = parent:AddGroup("ResetButtonGroup_" .. Uuid_v4())
    group.SameLine = sameLine and true or false

    local button = nil
    button = group:AddImageButton("##ResetButton_" .. Uuid_v4(), RB_ICONS.Arrow_CounterClockwise, IMAGESIZE.FRAME) --[[@as ExtuiImageButton]]

    --button.PositionOffset = { 0, 4 }
    return button, group
end

function StyleHelpers.AddMiddleAlignedImageButton(parent, icon, sameLine)
    local group = parent:AddGroup("MiddleAlignedImageButtonGroup_" .. Uuid_v4())
    group.SameLine = sameLine and true or false
    local button = group:AddImageButton("##MiddleAlignedImageButton_" .. Uuid_v4(), icon, IMAGESIZE.FRAME) --[[@as ExtuiImageButton]]
    return button, group
end

---@param parent ExtuiTreeParent
---@param size number?
---@return ExtuiTableCell
function StyleHelpers.AddIndent(parent, size)
    local table, leftCell, rightCell = AddTwoColTable(parent)
    table.ColumnDefs[1] = { Width = size or (10 * SCALE_FACTOR), WidthFixed = true }
    table.ColumnDefs[2] = { WidthStretch = true }
    table.PreciseWidths = true
    return rightCell
end

function StyleHelpers.AddCenterAlignTable(parent, label)
    label = label or "CenterAlignTable"
    local table = parent:AddTable(label .. "##" .. math.random(1, 10000), 3)
    table.ColumnDefs[1] = { WidthStretch = true }
    table.ColumnDefs[2] = { WidthFixed = true }
    table.ColumnDefs[3] = { WidthStretch = true }
    return table
end

---@param parent ExtuiTreeParent
---@param label string
---@param onClick function
---@return ExtuiSelectable
function AddSelectableButton(parent, label, onClick)
    local button = parent:AddSelectable(label)
    button.IDContext = "SelectableButton_" .. label
    button.Label = label
    button.OnClick = function(s)
        s.Selected = false
        if onClick then
            onClick(s)
        end
    end
    return button
end

--- @class AttrTable : ExtuiTable
--- @field AddNewLine fun(self: AttrTable): ExtuiTableCell, ExtuiTableCell
--- @field SetValue fun(self: AttrTable, name: string, value: string)

---@param parent ExtuiTreeParent
---@param contents table<string, string>
---@return AttrTable
function StyleHelpers.AddReadOnlyAttrTable(parent, contents)
    local tab = parent:AddTable(parent.Label, 2) --[[@as ExtuiTable]]
    tab.BordersInner = true
    tab.ColumnDefs[1] = { WidthFixed = true }
    tab.ColumnDefs[2] = { Width = 900 * SCALE_FACTOR }

    local function addRow(name, value)
        local row = tab:AddRow() --[[@as ExtuiTableRow]]
        local nameCell = row:AddCell()
        nameCell:AddText(name)
        addLittleSpacer(nameCell)

        local valueCell = row:AddCell()
        local input = valueCell:AddInputText("", tostring(value))
        contents[name] = input
        input.Text = tostring(value)
        input.IDContext = "ReadOnlyAttrInput##" .. name
        input.ReadOnly = true
        input.AutoSelectAll = true
    end

    local contents = contents or {}
    for name, value in SortedPairs(contents) do
        addRow(name, value)
    end

    --- @type AttrTable
    local clos = {
        AddNewLine = function()
            local row = tab:AddRow() --[[@as ExtuiTableRow]]
            return row:AddCell(), row:AddCell()
        end,
        SetValue = function(_, name, value)
            local input = contents[name]
            if input then
                input.Text = tostring(value)
            else
                addRow(name, value)
            end
        end
    }

    setmetatable(clos, {
        __index = function(_, k)
            return tab[k]
        end,
        __newindex = function(_, k, v)
            tab[k] = v
        end
    })

    return clos
end

--- @class AlignedTable : ExtuiTreeParent
--- @field AddSliderWithStep fun(self: AlignedTable, label: string, defaultValue: number, min: number, max: number, step: number, isInteger: boolean): ExtuiSliderInt|ExtuiSliderScalar, ExtuiTableCell

---@param parent ExtuiTreeParent
---@return AlignedTable
function StyleHelpers.AddAlignedTable(parent)
    local tab = parent:AddTable(parent.Label, 2) --[[@as ExtuiTable]]
    tab.BordersInnerV = true
    tab.ColumnDefs[1] = { WidthFixed = true }
    tab.ColumnDefs[2] = { Width = 900 * SCALE_FACTOR }

    local clos = {
        AddSliderWithStep = function(_, label, defaultValue, min, max, step, isInteger)
            local row = tab:AddRow() --[[@as ExtuiTableRow]]
            local nameCell = row:AddCell()
            nameCell:AddText(label)
            addLittleSpacer(nameCell)
            local valueCell = row:AddCell()

            return StyleHelpers.AddSliderWithStep(valueCell, "##" .. label .. "Slider", defaultValue,
                min, max, step, isInteger), valueCell
        end,
        AddNearbyCombo = function (_, label)
            local row = tab:AddRow() --[[@as ExtuiTableRow]]
            local nameCell = row:AddCell()
            nameCell:AddText(label)
            addLittleSpacer(nameCell)
            local valueCell = row:AddCell()

            return NearbyCombo.new(valueCell)
        end
    }

    setmetatable(clos, {
        __index = function(_, k)
            if rawget(clos, k) then
                return rawget(clos, k)
            end

            if k:sub(1, 3) == "Add" then
                return function(_, ...)
                    local args = {...}
                    local label = table.remove(args, 1)
                    local row = tab:AddRow() --[[@as ExtuiTableRow]]
                    local nameCell = row:AddCell()
                    nameCell:AddText(label)
                    addLittleSpacer(nameCell)
                    local valueCell = row:AddCell()

                    return valueCell[k](valueCell, "##" .. label .. "Input", table.unpack(args)), valueCell
                end
            end
        end,
        __newindex = function(_, k, v)
            tab[k] = v
        end
    })

    return clos
end

--- @param arrowImage ExtuiImageButton
function StyleHelpers.SetupImageButton(arrowImage)
    ClearAllBorders(arrowImage)
    arrowImage.Tint = arrowImage.Tint or {1, 1, 1, 1}
    arrowImage.OnHoverEnter = function ()
        arrowImage.Tint = {arrowImage.Tint[1], arrowImage.Tint[2], arrowImage.Tint[3], arrowImage.Tint[4] * 0.8}
    end
    arrowImage.OnHoverLeave = function ()
        arrowImage.Tint = {arrowImage.Tint[1], arrowImage.Tint[2], arrowImage.Tint[3], arrowImage.Tint[4] / 0.8}
    end
    arrowImage:SetColor("Button", {0,0,0,0})
    arrowImage:SetColor("ButtonHovered", {0,0,0,0})
    arrowImage:SetColor("ButtonActive", {0,0,0,0})
end

local treeOpenIcon = RB_ICONS.Menu_Down
local treeClosedIcon = RB_ICONS.Menu_Right
local treeOpen = RB_ICON_UV01[treeOpenIcon]
local treeClosed = RB_ICON_UV01[treeClosedIcon]

--- @class RB_UI_Tree : ExtuiTree
--- @field Children RB_UI_Tree[]
--- @field SetOpen fun(self: RB_UI_Tree, isOpen: boolean)
--- @field IsOpen fun(self: RB_UI_Tree): boolean
--- @field AddTree fun(self: RB_UI_Tree, label: string, isOpen: boolean?): RB_UI_Tree
--- @field AddHint fun(self: RB_UI_Tree, hintText: string): ExtuiText
--- @field AddTreeIcon fun(self: RB_UI_Tree, iconPath: string, iconSize?: IMAGESIZE): ExtuiImage
--- @field AddChild fun(self: RB_UI_Tree, child: RB_UI_Tree)
--- @field Destroy fun()
--- @field DestroyChildren fun()
--- @field ToggleAll fun(self: RB_UI_Tree)
--- @field Panel ExtuiGroup
--- @field Indent number
--- @field OnExpand fun()
--- @field OnCollapse fun()

--- @param parent ExtuiTreeParent
--- @param label string
--- @param open boolean?
--- @return RB_UI_Tree
function StyleHelpers.AddTree(parent, label, open)
    if parent.UserData and parent.UserData.Is_RB_UI_Tree then
        return parent:AddTree(label, open)
    end
    label = label or "TreeGroup"
    local uuid = Uuid_v4()
    local panelGroup = parent:AddGroup(label .. "##uuid_" .. uuid)
    
    local children = {}
    local headerGroup = panelGroup:AddGroup(label .. "_TreeHeaderGroup##uuid_" .. uuid)
    local arrowReserved = headerGroup:AddImageButton("##" .. label .. uuid , open and RB_ICONS.Menu_Down or RB_ICONS.Menu_Right, IMAGESIZE.ROW)
    local iconReserved = headerGroup:AddGroup("##" .. label .. "_IconReserved_" .. uuid)
    local selectable = headerGroup:AddSelectable(label .. "##" .. uuid .. "_Selectable")
    local indent = panelGroup:AddDummy(16 * SCALE_FACTOR, 1)
    local panel = panelGroup:AddGroup(label .. "_TreeGroup##uuid_" .. uuid)
    local isFramed = false
    local treeIcon = nil
    panel.Visible = open == true
    panel.SameLine = true
    selectable.SameLine = true
    selectable.AllowItemOverlap = true
    selectable.IDContext = "TreeSelectable__" .. uuid
    iconReserved.SameLine = true
    iconReserved.Visible = false

    local closure = {}
    local expandAll = not panel.Visible 
    local function setOpen(isOpen)
        panel.Visible = isOpen
        arrowReserved.Image = panel.Visible and treeOpen or treeClosed
        if closure.OnExpand and isOpen then
            closure.OnExpand()
        elseif closure.OnCollapse and not isOpen then
            closure.OnCollapse()
        end
    end

    StyleHelpers.SetupImageButton(arrowReserved)
    arrowReserved.OnClick = function()
        if isFramed then
            selectable.Selected = true
        else
            selectable.Selected = false
        end
        setOpen(not panel.Visible)
    end

    local toggleAll = function (sel, syncState)
        if syncState ~= nil then
            expandAll = syncState
        end
        for _, child in ipairs(children) do
            if child.SetOpen then
                child:SetOpen(expandAll)
                child:ToggleAll(expandAll)
            end
        end
        expandAll = not expandAll
    end

    arrowReserved.OnRightClick = function()
        toggleAll()
    end
    selectable.OnRightClick = arrowReserved.OnRightClick
    selectable.OnClick = arrowReserved.OnClick

    closure = {
        __UserData = {
            Is_RB_UI_Tree = true
        },
        ToggleAll = toggleAll,
        Panel = panel,
        Children = children,
        SetOpen = function(_, isOpen)
            setOpen(isOpen)
        end,
        IsOpen = function()
            return panel.Visible
        end,
        AddTree = function(_, label, isOpen)
            local childTree = StyleHelpers.AddTree(panel, label, isOpen)
            table.insert(children, childTree)
            return childTree
        end,
        AddChild = function(_, child)
            if child and child.UserData and child.UserData.Is_RB_UI_Tree then
                table.insert(children, child)
            end
        end,
        AddTreeIcon = function(_, iconName, iconSize)
            treeIcon = iconReserved:AddImageButton("##" .. uuid .. "Tree___Icon", iconName, iconSize or IMAGESIZE.ROW)
            treeIcon.IDContext = "TreeIcon__" .. uuid
            ClearAllBorders(treeIcon)
            treeIcon:SetColor("Button", {0,0,0,0})
            treeIcon:SetColor("ButtonHovered", {0,0,0,0})
            treeIcon:SetColor("ButtonActive", {0,0,0,0})
            iconReserved.Visible = true
            return treeIcon
        end,
        AddHint = function(_, hintText)
            local hint = headerGroup:AddText(hintText)
            hint:SetColor("Text", HexToRGBA("FFAAAAAA"))
            hint.SameLine = true
            hint.Font = "Tiny"
            return hint
        end,
        OnExpand = function() end,
        OnCollapse = function() end,
        Destroy = function()
            panelGroup:Destroy()
        end,
        DestroyChildren = function()
            for i=#children, 1, -1 do
                local child = children[i]
                if child.Destroy then
                    child:Destroy()
                end
                table.remove(children, i)
            end
            DestroyAllChildren(panel)
        end,
        GetStyle = function(_, varName)
            return panelGroup:GetStyle(varName)
        end,
        GetColor = function(_, colorName)
            return panelGroup:GetColor(colorName)
        end,
        SetStyle = function(_, varName, ...)
            panelGroup:SetStyle(varName, ...)
        end,
        SetColor = function(_, colorName, colorValue)
            panelGroup:SetColor(colorName, colorValue)
        end
    }

    selectable.UserData = closure.__UserData

    setmetatable(closure, {
        __index = function(_, k)
            if k == "UserData" then
                return rawget(closure, "__UserData")
            elseif rawget(closure, k) ~= nil then
                return rawget(closure, k)
            elseif k:sub(1, 3) == "Add" then
                return function(_, ...)
                    return panel[k](panel, ...)
                end
            elseif k == "OnExpand" or k == "OnCollapse" then
                return rawget(closure, k)
            elseif k == "Tooltip" then
                return function()
                    return selectable:Tooltip()
                end
            elseif k == "Indent" then
                return indent.Width
            end
            return selectable[k]
        end,
        __newindex = function(_, k, v)
            if k == "SameLine" or k == "Visible" then
                panelGroup[k] = v
                return
            elseif k == "UserData" then
                rawset(closure, "__UserData", v)
                selectable.UserData = v
                treeIcon.UserData = v
                v.Is_RB_UI_Tree = true
                return
            elseif k == "Framed" then
                isFramed = v
                selectable.Selected = v
                return
            elseif k == "Indent" then
                indent.Width = v
                return
            end
            selectable[k] = v
            if treeIcon and not ( k == "Selected" or k == "Highlight") then
                treeIcon[k] = v
            end
        end
    })

    return closure
end

--- @param pBar ExtuiProgressBar
function StyleHelpers.SetNormalProgressBarStyle(pBar)
    pBar:SetStyle("FrameBorderSize", 2)
    pBar:SetColor("PlotHistogram", HexToRGBA("FF397D38"))
    pBar:SetColor("Border", HexToRGBA("FF31BEBE"))
    pBar:SetColor("Text", { 1, 1, 1, 1 })
end

--- @param pBar ExtuiProgressBar
function StyleHelpers.SetWarningProgressBarStyle(pBar)
    pBar:SetStyle("FrameBorderSize", 2)
    pBar:SetColor("PlotHistogram", HexToRGBA("FFFF4444"))
    pBar:SetColor("Border", HexToRGBA("FFFF0000"))
    pBar:SetColor("Text", { 1, 1, 1, 1 })
    GuiAnim.PulseBorder(pBar, 2)
end

--- @class RadioButtonOption
--- @field Name string
--- @field Value integer

--- @class BitmaskRadioButtonsGroup : ExtuiGroup
--- @field OnChange fun(radioBtn: ExtuiRadioButton, value: integer)
--- @field Value integer

--- @param parent ExtuiTreeParent
--- @param options RadioButtonOption[]
--- @param initValue integer
--- @return BitmaskRadioButtonsGroup
function StyleHelpers.AddBitmaskRadioButtons(parent, options, initValue)
    local group = parent:AddGroup(label or "BitmaskRadioButtonsGroup" .. Uuid_v4())
    local value = initValue or 0
    local btns = {}

    local clos = {
        OnChange = function() end
    }

    setmetatable(clos, {
        __index = function(_, k)
            if k == "Value" then
                return value
            else
                return group[k]
            end
        end,
        __newindex = function(_, k, v)
            if k == "Value" then
                value = v
                for i, option in ipairs(options) do
                    local radio = btns[i]
                    if radio then
                        radio.Active = (value & option.Value) ~= 0
                    end
                end
            else
                group[k] = v
            end
        end
    })

    local uuid = Uuid_v4()
    for i, option in ipairs(options) do
        local radio = group:AddRadioButton(option.Name or ("Option" .. i))
        radio.IDContext = "BitmaskRadioButton__" .. option.Name .. "__" .. i .. "__" .. uuid
        radio.Active = initValue and (initValue & option.Value) ~= 0 or false
        radio.OnChange = function(r)
            r.Active = not r.Active
            if r.Active then
                value = value | option.Value
            else
                value = value & (~option.Value)
            end
            if clos.OnChange then
                clos.OnChange(r, value)
            end
        end

        --radio.SameLine = (i > 1 and i % 4 ~= 1)
        btns[i] = radio
    end

    return clos
end

--- @class EnumRadioButtonsGroup :ExtuiGroup
--- @field OnChange fun(radioBtn: ExtuiRadioButton, value: number)
--- @field Value number

--- @param parent ExtuiTreeParent
--- @param options RadioButtonOption[]
--- @param initValue number
--- @return EnumRadioButtonsGroup
function StyleHelpers.AddEnumRadioButtons(parent, options, initValue)
    local group = parent:AddGroup("EnumRadioButtonsGroup" .. Uuid_v4())

    local current = initValue
    local radioButtons = {}
    local closure = {
        OnChange = function() end
    }

    setmetatable(closure, {
        __index = function(_, k)
            if k == "Value" then
                return current
            end
            return group[k]
        end,
        __newindex = function(_, k, v)
            if k == "Value" then
                current = v
                for enumName, radio in pairs(radioButtons) do
                    local enumValue = radio.UserData.EnumValue
                    radio.Active = (current == enumValue)
                end
                return
            end
            group[k] = v
        end
    })

    
    for i, option in ipairs(options) do
        local enumName = option.Name
        local enumValue = option.Value
        local radio = group:AddRadioButton(enumName .. "##_Setter")
        radioButtons[enumName] = radio
        radio.Active = (initValue == enumValue)
        radio.UserData = {
            EnumValue = enumValue
        }
        radio.OnChange = function(r)
            if current == enumValue then
                return
            end
            current = enumValue
            for _, otherRadio in pairs(radioButtons) do
                if otherRadio ~= r then
                    otherRadio.Active = false
                end
            end
            r.Active = true
            closure.OnChange(r, current)
        end
        --radio.SameLine = i > 1 and i % 4 ~= 1
    end

    return closure
end

function SetWarningBorder(extui)
    extui:SetColor("Text", HexToRGBA("FFFF0000"))
    extui:SetColor("Border", HexToRGBA("FFFF4444"))
end

function ClearWarningBorder(extui)
    extui:SetColor("Text", HexToRGBA("FFFFFFFF"))
    extui:SetColor("Border", HexToRGBA("FF888888"))
end

function ApplyWarningButtonStyle(button)
    button:SetColor("Text", HexToRGBA("FFFF0000"))
    button:SetColor("Border", HexToRGBA("FFFF4444"))
    button:SetColor("Button", HexToRGBA("FF470000"))
    button:SetColor("ButtonHovered", HexToRGBA("FF700000"))
    button:SetColor("ButtonActive", HexToRGBA("FF900000"))
end

function ApplyOkButtonStyle(button)
    button:SetColor("Text", HexToRGBA("FFFFFFFF"))
    button:SetColor("Border", HexToRGBA("FF888888"))
    button:SetColor("Button", HexToRGBA("FF004747"))
    button:SetColor("ButtonHovered", HexToRGBA("FF007070"))
    button:SetColor("ButtonActive", HexToRGBA("FF009090"))
end

function ApplyWarningTooltipStyle(tooltip)
    tooltip:SetColor("Text", HexToRGBA("FFFF0000"))
    tooltip:SetColor("Border", HexToRGBA("FFFF4444"))
    tooltip:SetColor("WindowBg", HexToRGBA("FF220000"))
end

function ApplyOkTooltipStyle(tooltip)
    tooltip:SetColor("Text", HexToRGBA("FFFFFFFF"))
    tooltip:SetColor("Border", HexToRGBA("FF888888"))
    tooltip:SetColor("WindowBg", HexToRGBA("FF222222"))
end

--- @param extui ExtuiStyledRenderable
function ClearAllBorders(extui)
    extui:SetColor("Text", HexToRGBA("FFFFFFFF"))
    extui:SetColor("Border", HexToRGBA("00000000"))
    extui:SetStyle("FrameBorderSize", 0)
    extui:SetStyle("WindowBorderSize", 0)
    extui:SetStyle("PopupBorderSize", 0)
    extui:SetStyle("ChildBorderSize", 0)
    extui:SetStyle("TabBorderSize", 0)
end

---@param parent ExtuiTreeParent
---@param settings RB_Mod_ExportSetting
---@return function -- refresh function
function RenderExportSettingPanel(parent, settings)
    local modNameText = parent:AddText("Mod Name*")
    local modNameInput = parent:AddInputText("##MaterialPresetModName")
    local modNameTooltip = modNameInput:Tooltip()

    modNameTooltip:SetColor("Border", {1,0,0,1})
    modNameTooltip:SetStyle("FrameBorderSize", 2)
    modNameTooltip:SetStyle("WindowBorderSize", 2)

    local currentModInternalNameTooltip = modNameTooltip:AddText("Current Mod Internal Name:")
    currentModInternalNameTooltip:SetColor("Text", HexToRGBA("FFFFBC51"))
    local modIntenalNameTooltip = modNameTooltip:AddText(settings.ModName and ValidateFolderName(settings.ModName) or "")
    modIntenalNameTooltip:SetColor("Text", HexToRGBA("FFFFFFFF"))
    modIntenalNameTooltip.SameLine = true

    modNameInput.Hint = "Enter Mod Name..."
    modNameInput:SetStyle("FrameBorderSize", 2)
    modNameInput:SetStyle("WindowBorderSize", 2)
    

    modNameInput.OnChange = Debounce(50, function()
        if ValidateFolderName(modNameInput.Text) ~= 'Unnamed' then
            modIntenalNameTooltip.Label = ValidateFolderName(modNameInput.Text)
            ClearWarningBorder(modNameInput)
            settings.ModName = modNameInput.Text
        else
            modIntenalNameTooltip.Label = "Current Mod Internal Name: Invalid Name"
            SetWarningBorder(modNameInput)
            settings.ModName = ""
            GuiAnim.PulseBorder(modNameInput, 2)
        end
    end)
    modNameInput.Text = settings.ModName or ""
    if modNameInput.Text == "" then
        SetWarningBorder(modNameInput)
    else
        ClearWarningBorder(modNameInput)
    end
    local authorNameText = parent:AddText("Author Name*")
    local authorNameInput = parent:AddInputText("##MaterialPresetAuthorName")
    authorNameInput:SetStyle("FrameBorderSize", 2)
    modNameInput:Tooltip():AddText("CAUTION:"):SetColor("Text", HexToRGBA("FFFF0000"))
    modNameInput:Tooltip():AddText("Special character will be removed from mod internal name."):SetColor("Text", HexToRGBA("FFFFBD4C"))
    modNameInput:Tooltip():AddText("Space will be treated as underscore (_), but display name will remain unchanged."):SetColor("Text", HexToRGBA("FFFFBD4C"))
    modNameInput:Tooltip():AddText("My Mod and My_Mod are considered the same mod name."):SetColor("Text", HexToRGBA("FFFFBD4C"))

    authorNameInput.Hint = "Enter Author Name..."
    authorNameInput.OnChange = Debounce(50, function()
        local newName = authorNameInput.Text
        if newName == "" then
            SetWarningBorder(authorNameInput)
            settings.Author = ""
            GuiAnim.PulseBorder(authorNameInput, 2)
        else
            ClearWarningBorder(authorNameInput)
            settings.Author = authorNameInput.Text
        end
    end)
    authorNameInput.Text = settings.Author or ""

    if authorNameInput.Text == "" then
        SetWarningBorder(authorNameInput)
    else
        ClearWarningBorder(authorNameInput)
    end

    local descriptionText = parent:AddText("Description:")
    local descriptionInput = parent:AddInputText("##MaterialPresetDescription")
    descriptionInput.Hint = "Enter Description..."
    descriptionInput.OnChange = function()
        settings.Description = descriptionInput.Text
    end
    descriptionInput.Multiline = true
    descriptionInput.Text = settings.Description or ""

    local versionText = parent:AddText("Version*")
    local versionInput = parent:AddInputInt("##MaterialPresetVersion")
    versionInput.Components = 4
    versionInput:SetStyle("FrameBorderSize", 2)
    versionInput.OnChange = function()
        local valid = true
        for _, var in pairs(versionInput.Value) do
            if not tonumber(var) or var < 0 then
                valid = false
                SetWarningBorder(versionInput)
                GuiAnim.PulseBorder(versionInput, 2)
            end
        end
        if valid then ClearWarningBorder(versionInput) end
        settings.Version = { versionInput.Value[1], versionInput.Value[2], versionInput.Value[3], versionInput.Value[4] }
    end
    versionInput.Value = { settings.Version[1], settings.Version[2], settings.Version[3], settings.Version[4] }
    ClearWarningBorder(versionInput)

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

--- @param parent ExtuiTreeParent
--- @param label string
--- @param getter fun():number[]
--- @param setter fun(value: number[])
--- @param config { IsInt: boolean, Range: { Min: number, Max: number, Step: number }, IsColor: boolean, OnReset: fun(), ResetValue: number[] }?
--- @return function -- update function
function StyleHelpers.AddNumberSliders(parent, label, getter, setter, config)
    --- @type any[], ExtuiColorEdit
    local sliders, colorPicker = {}, nil
    config = config or {}

    local updateMethod = function ()
        local value = getter()
        if not value then return end

        if type(value) ~= "table" then
            value = { value }
        end

        if config.IsInt then
            for i = 1, #value do
                value[i] = math.floor(value[i])
            end
        end

        for i, slider in ipairs(sliders) do
            slider.Value = ToVec4(value[i])
        end
        if colorPicker then
            colorPicker.Color = {value[1], value[2], value[3], value[4] or 1 }
        end
    end

    local initValue = config.ResetValue or getter()
    if type(initValue) ~= "table" then
        initValue = { initValue }
    end

    if #initValue == 0 then
        return function() end
    end

    local isInt = config.IsInt or false
    local range = config.Range or { Min = -10, Max = 10 , Step = 0.1 }
    local uuid = Uuid_v4()
    local innerTable = parent:AddTable(parent.Label, 2) -- -- Use the same name so tables under the same parent share column widths.
    innerTable.ColumnDefs[1] = { WidthFixed = true }
    innerTable.ColumnDefs[2] = { WidthStretch = true }
    innerTable.BordersInnerV = true

    local row = innerTable:AddRow()
    local displayNameCell = row:AddCell()
    local slidersCell = row:AddCell()
    local selectable = displayNameCell:AddText(label)
    addLittleSpacer(displayNameCell)
    local resetChange = function()
        for i, slider in ipairs(sliders) do
            slider.Value = ToVec4(initValue[i])
        end
        if colorPicker then
            colorPicker.Color = {initValue[1], initValue[2], initValue[3], initValue[4] or 1 }
        end

        setter(initValue)
        if config.OnReset then
            config.OnReset()
        end
    end

    local function renderSliders()
        for i = 1, #initValue do
            local slider = StyleHelpers.AddSliderWithStep(slidersCell, i, initValue[i], range.Min, range.Max, range.Step, isInt)
            slider.OnChange = function()
                local currentValues = {}
                for j, s in ipairs(sliders) do
                    currentValues[j] = s.Value[1]
                end
                if colorPicker then
                    colorPicker.Color = { currentValues[1], currentValues[2], currentValues[3], #initValue == 4 and currentValues[4] or 1 }
                end
                setter(currentValues)
            end
            sliders[i] = slider
        end
    end

    if #initValue >= 3 and #initValue <=4 and not config.IsInt then
        colorPicker = slidersCell:AddColorEdit("##ColorPicker_" .. uuid)
        colorPicker.NoAlpha = #initValue == 3
        colorPicker.AlphaBar = #initValue == 4
        colorPicker.Color = {initValue[1], initValue[2], initValue[3], #initValue == 4 and initValue[4] or 1 }

        colorPicker.OnRightClick = function ()
            resetChange()
        end
        colorPicker.OnChange = function()
            setter({ colorPicker.Color[1], colorPicker.Color[2], colorPicker.Color[3], #initValue == 4 and colorPicker.Color[4] or nil })

            for i, slider in ipairs(sliders) do
                slider.Value = ToVec4(colorPicker.Color[i])
            end
        end
    end

    if not colorPicker or not config.IsColor then
        if colorPicker then colorPicker.Visible = false end
        renderSliders()
    else
        colorPicker.OnRightClick = function()
            if not next(sliders) then
                renderSliders()
                return
            end
            for i, slider in ipairs(sliders) do
                slider.Visible = not slider.Visible
            end
        end
    end
    

    return updateMethod
end

--- @param parent ExtuiTreeParent
--- @param o table<string, any>
--- @param onSet function
--- @return function -- update function
function StyleHelpers.RenderGeneralTableEditor(parent, o, onSet)
    local alignedTable = StyleHelpers.AddAlignedTable(parent)
    local updateFuncs = {}
    for k, v in pairs(o) do
        local updateFunc = nil
        if type(v) == "boolean" then
            local checkbox = alignedTable:AddCheckbox(k, v)
            checkbox.OnChange = function(sel)
                o[k] = sel.Checked
                onSet()
            end
            updateFunc = function()
                checkbox.Checked = o[k]
            end
        elseif type(v) == "number" then
            local slider, _ = alignedTable:AddSliderWithStep(k, v, 0, 100, 1, true)
            slider.OnChange = function(sel)
                o[k] = sel.Value[1]
                onSet()
            end
            updateFunc = function()
                slider.Value = ToVec4(o[k])
            end
        elseif type(v) == "string" then
            local inputText = alignedTable:AddInputText(k, v)
            inputText.OnChange = function(sel)
                o[k] = sel.Text
                onSet()
            end
            updateFunc = function()
                inputText.Text = o[k]
            end
        elseif IsArray(v) then
            updateFunc = StyleHelpers.AddNumberSliders(parent, k, function() return o[k] end,
                function(value)
                    o[k] = value
                    onSet()
                end, { IsInt = true, Range = { Min = 0, Max = 100, Step = 1 }, ResetValue = v })
        else
            Warning("[EntityTab] Unknown server character attribute type for key: " .. tostring(k))
        end
        if updateFunc then
            table.insert(updateFuncs, updateFunc)
        end
    end

    return function()
        for _, f in ipairs(updateFuncs) do
            f()
        end
    end
end