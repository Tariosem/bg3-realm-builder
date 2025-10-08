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
--- @param IDContext string?
--- @param defaultValue number
--- @param min number
--- @param max number
--- @param step number
--- @param isInteger? boolean
--- @return ExtuiSliderInt|ExtuiSliderScalar
function AddSliderWithStep(parent, IDContext, defaultValue, min, max, step, isInteger)
    if not IDContext then
        IDContext = Uuid_v4()
    end
    local stepInput = nil
    local slider = nil
    local decreButton = nil
    local increButton = nil
    step = step or 0.1
    if isInteger then
        stepInput = parent:AddInputInt("", step)
        decreButton = AddSliderStepButton(parent, "<", -step, nil, "<")
        slider = SafeAddSliderInt(parent, "", defaultValue or 0, min or 0, max or 100)
        increButton = AddSliderStepButton(parent, ">", step, nil, ">")
    else
        stepInput = parent:AddInputScalar("", step)
        decreButton = AddSliderStepButton(parent, "<", -step, nil, "<")
        slider = parent:AddSlider("", defaultValue or 0, min or 0, max or 100) --[[@as ExtuiSliderScalar]]
        increButton = AddSliderStepButton(parent, ">", step, nil, ">")
    end
    local resetButton = parent:AddButton("Reset")
    decreButton.UserData.Slider = slider
    increButton.UserData.Slider = slider

    slider.UserData = { Step = step }

    stepInput.IDContext = IDContext .. "_StepInput"
    increButton.IDContext = IDContext .. "_IncreButton"
    slider.IDContext = IDContext .. "_Slider"
    decreButton.IDContext = IDContext .. "_DecreButton"

    local ud = slider.UserData
    ud.StepInput = stepInput
    ud.DecreButton = decreButton
    ud.IncreButton = increButton
    ud.Parent = parent

    decreButton.SameLine = true
    increButton.SameLine = true
    slider.SameLine = true
    --stepInput.SameLine = true

    stepInput.ItemWidth = 50 * SCALE_FACTOR

    stepInput:Tooltip():AddText(GetLoca("Step"))

    stepInput.OnChange = function()
        local step = stepInput.Value[1]
        slider.UserData.Step = step
    end

    resetButton.SameLine = true
    resetButton.IDContext = IDContext .. "_ResetButton"
    resetButton.OnClick = function()
        slider.Value = ToVec4(defaultValue or 0)
        if slider.OnChange then
            slider:OnChange()
        end
    end

    return slider
end

--- @param parent ExtuiTreeParent
--- @param label string
--- @param step number
--- @param slider? ExtuiSliderInt|ExtuiSliderScalar
--- @param direction? '<'|'>'
--- @return ExtuiButton
function AddSliderStepButton(parent, label, step, slider, direction)
    local button = parent:AddButton(label)
    button.IDContext = Uuid_v4()

    button.UserData = { Step = step or 1, Slider = slider }

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
        s.Value = { newValue, newValue, newValue, newValue }
        if s.OnChange then
            s:OnChange()
        end
    end

    return button
end

function AddWarningIcon(parent, text)
    local image = parent:AddImage(WARNING_ICON)
    image.ImageData.Size = ToVec2(32 * SCALE_FACTOR)
    image.SameLine = true
    image:Tooltip():AddText(text)
    image.OnClick = function(i)
        i:Destroy()
    end
    return image
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

function ApplyDefaultSeparatorStyle(s)
    s:SetColor("Separator", { 0.6, 0.6, 0.6, 1 })
end

function WrapTextTokens(tokens, wrapPos)
    local wrappedTokens = {}
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

    for _, token in ipairs(tokens) do
        local text = token.Text or ""

        if token.TooltipRef then
            local tokenLen = #text

            if currentLen > 0 and currentLen + tokenLen > wrapPos then
                currentLen = 0
            end

            local newToken = cloneToken(token, text)
            newToken.SameLine = currentLen > 0

            table.insert(wrappedTokens, newToken)
            currentLen = currentLen + tokenLen
        else
            local pos = 1
            local shortSkipCnt = 0

            while pos <= #text do
                local spaceLeft = wrapPos - currentLen

                if spaceLeft <= 0 then
                    currentLen = 0
                    spaceLeft = wrapPos
                end

                local remainingText = text:sub(pos)
                local chunk

                if #remainingText <= spaceLeft then
                    chunk = remainingText
                    pos = #text + 1
                else
                    local searchArea = remainingText:sub(1, spaceLeft)
                    local bestBreak = nil

                    for i = #searchArea, 1, -1 do
                        local char = searchArea:sub(i, i)
                        if char:match("%s") then
                            local nextChar = remainingText:sub(i + 1, i + 1)
                            if not nextChar:match("[%.%,%!%?%;%:]") then
                                bestBreak = i
                                break
                            end
                        end
                    end

                    if bestBreak and bestBreak > 1 then
                        chunk = searchArea:sub(1, bestBreak - 1)
                        pos = pos + bestBreak

                        while pos <= #text and text:sub(pos, pos):match("%s") do
                            pos = pos + 1
                        end
                    else
                        if currentLen > 0 then
                            currentLen = 0
                            goto continue
                        else
                            chunk = remainingText
                            pos = #text + 1
                        end
                    end
                end

                if chunk and chunk ~= "" then
                    local newToken = cloneToken(token, chunk)
                    newToken.SameLine = currentLen > 0

                    if #newToken.Text <= 1 and shortSkipCnt < 1 then
                        newToken.SameLine = true
                        shortSkipCnt = shortSkipCnt + 1
                    else
                        shortSkipCnt = 0
                    end

                    table.insert(wrappedTokens, newToken)
                    currentLen = currentLen + #chunk
                end

                ::continue::
            end
        end
    end

    return wrappedTokens
end

function RenderTokenTexts(parent, tokens, firstAlwaysSameLine)
    local elements = {}
    for _, token in ipairs(tokens) do
        local text = token.Text or ""
        local icon = nil
        local statsName = nil
        local statsType = nil
        local statsObj = nil
        if token.TooltipRef then
            statsName = token.TooltipRef.Name
            statsObj = Ext.Stats.Get(statsName)
            statsType = token.TooltipRef.Type
        end
        
        if token.Icon and not token.TooltipRef then
            icon = parent:AddImage(token.Icon)
            icon.ImageData.Size = ToVec2(32 * SCALE_FACTOR)
        end

        local label = nil

        if token.TooltipRef and statsObj then
            local statsObjRenderfunc = RenderStatsObject(statsObj, statsType)
            _,label = statsObjRenderfunc(parent, true)
        else
            label = parent:AddText(text)
        end

        if token.Font then label.Font = token.Font end
        if token.Color then
            label:SetColor("Text", token.Color)
        end
        if token.Style then
            for styleVar, styleVal in pairs(token.Style) do
                label:SetStyle(styleVar, styleVal)
            end
        end
        if token.Tooltip then
            if icon then
                token.Tooltip(icon:Tooltip())
            else
                token.Tooltip(label:Tooltip())
            end
        end

        label.SameLine = token.SameLine == true
        if firstAlwaysSameLine then
            label.SameLine = true
            if icon then
                icon.SameLine = true
            end
            firstAlwaysSameLine = false
        end
        if #text <= 5 then
            label.SameLine = true
        end
        table.insert(elements, label)
    end
    return elements
end

function AddSimpleTextWrap(parent, text, num)
    local i = 1
    num = math.floor(num or 100)
    local len = #text
    --- @type ExtuiText[]
    local texts = {}
    while i <= len do
        local j = math.min(i + num - 1, len)
        local chunk = string.sub(text, i, j)

        if j < len and chunk:match("[%w]$") and string.sub(text, j + 1, j + 1):match("[%w]") then
            local back = chunk:find("([%s%p])[^%s%p]*$")
            if back then
                j = i + back - 1
                chunk = string.sub(text, i, j)
            end
        end

        table.insert(texts, parent:AddText(chunk))

        i = j + 1
        while i <= len and string.sub(text, i, i):match("%s") do
            i = i + 1
        end
    end

    local function destroy()
        for _, t in ipairs(texts) do
            t:Destroy()
        end
    end

    --- @param guiColor GuiColor
    --- @param vec4 table
    local function setColor(sef, guiColor, vec4)
        for _, t in ipairs(texts) do
            t:SetColor(guiColor, vec4)
        end
    end

    --- @param guiStyleVar GuiStyleVar
    --- @param a1 number
    --- @param a2 number
    local function setStyle(sef, guiStyleVar, a1, a2)
        for _, t in ipairs(texts) do
            t:SetStyle(guiStyleVar, a1, a2)
        end
    end

    local function Font(sef, name)
        for _, t in ipairs(texts) do
            t.Font = name
        end
    end

    local function Visible(sef, bool)
        for _, t in ipairs(texts) do
            t.Visible = bool
        end
    end

    local function sameLine(sef, bool)
        texts[1].SameLine = bool
    end

    return { Destroy = destroy, SetColor = setColor, SetStyle = setStyle, Font = Font, Visible = Visible, SameLine =
    sameLine, Texts = texts }
end

---@param parent ExtuiTreeParent
---@param prefix string?
---@param text string
---@param readOnly boolean?
---@return ExtuiInputText
function AddPrefixInput(parent, prefix, text, readOnly)
    if prefix and prefix ~= "" then parent:AddText(prefix) end
    local input = parent:AddInputText("", text or "")
    input.SameLine = true
    input.ReadOnly = readOnly == true
    input.AutoSelectAll = readOnly == true
    return input
end

function AddReadOnlyInput(parent, label, text)
    local input = parent:AddInputText(label, text or "")
    input.ReadOnly = true
    input.AutoSelectAll = true
    return input
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

function AddRightAlignCell(parent)
    local table, leftCell, rightCell = AddTwoColTable(parent)
    table.ColumnDefs[1] = { WidthStretch = true }
    table.ColumnDefs[2] = { WidthFixed = true }
    return rightCell, leftCell
end

function SafeDestroy(extui)
    if extui then extui:Destroy() end
    return nil
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
function DisableAndSetAlpha(extui, alpha)
    if not extui then return end
    extui.Disabled = true
    extui:SetStyle("Alpha", alpha or 0.6)
end

function EnableAndSetAlpha(extui)
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

function DestroyAllChilds(parent)
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

local created = false

function AddStyleDebugWindow(extui)
    if created then return end
    created = true

    local window = RegisterWindow("generic", "debug", "IDONTKNOW")
    for idon, value in pairs(extui) do
        if type(value) == "boolean" then
            ---@diagnostic disable
            window:AddCheckbox(idon).OnChange = function(c)
                extui[idon] = c.Checked
            end
        end
        if type(value) == "number" then
            window:AddSliderInt(idon, value, 0, 100).OnChange = function(s)
                extui[idon] = s.Value[1]
            end
        end
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

function RenderStickSlider(parent, label, onChange)
    local decBtn = AddSliderStepButton(parent, "<", -1)
    local slider = parent:AddSlider("", 0, -1, 1)
    decBtn.UserData.Slider = slider
    local incBtn = AddSliderStepButton(parent, ">", 1, slider)
    slider.IDContext = "StickSlider_" .. label
    local text = parent:AddText(label)
    text.SameLine = true
    decBtn.SameLine = true
    slider.SameLine = true
    incBtn.SameLine = true

    slider.ItemWidth = 400 * SCALE_FACTOR
    slider.OnChange = function(s)
        local v = tonumber(s.Value[1])
        if onChange then
            onChange(v)
        end
        s.Value = {0, 0, 0, 0}
    end

    return slider, text
end

function RenderObjectNumberValueInput(parent, label, obj, field, min, max, incstep, decstep, onChange)
    local decBtn = AddSliderStepButton(parent, "<", -(decstep or 1))
    --- @type ExtuiInputScalar
    local input = parent:AddInputScalar("", obj and obj[field] or 0)
    decBtn.UserData.Slider = input
    local incBtn = AddSliderStepButton(parent, ">", incstep, input)
    input.IDContext = "ObjectNumberValueInput_" .. label
    input.SameLine = true
    incBtn.SameLine = true

    input:Tooltip():AddText(label)

    input.ItemWidth = 100 * SCALE_FACTOR
    input.OnChange = function(i)
        local v = tonumber(i.Value[1]) or 0
        v = math.max(min or -math.huge, v)
        v = math.min(max or math.huge, v)

        if obj and field then
            obj[field] = v
        end
        if onChange then
            onChange(v)
        end
        i.Value = ToVec4(v)
    end

    return input, decBtn
end

---@param parent ExtuiTreeParent
---@param size number?
---@return ExtuiTableCell
function AddIndent(parent, size)
    local table, leftCell, rightCell = AddTwoColTable(parent)
    table.ColumnDefs[1] = { Width = size or (10 * SCALE_FACTOR), WidthFixed = true }
    table.ColumnDefs[2] = { WidthStretch = true }
    table.PreciseWidths = true
    return rightCell
end

---@param parent ExtuiTreeParent
---@return ExtuiTable
function AddMiddleAlignTable(parent)
    local table = parent:AddTable(Uuid_v4(), 3)
    table.ColumnDefs[1] = { WidthStretch = false, WidthFixed = true }
    table.ColumnDefs[2] = { WidthStretch = true }
    table.ColumnDefs[3] = { WidthStretch = false, WidthFixed = true }
    return table
end

function AddRightAlighTable(parent)
    local table = parent:AddTable(Uuid_v4(), 2)
    table.ColumnDefs[1] = { WidthStretch = true }
    table.ColumnDefs[2] = { WidthStretch = false, WidthFixed = true }
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
        if onClick then
            onClick(s)
        end
        s.Selected = false
    end
    return button
end

---@param parent ExtuiTreeParent
---@param label any
---@param color any
---@param onChange any
---@return unknown
function AddSimpleColorPicker(parent, label, color, onChange)
    local colorPicker = parent:AddColorEdit(label)
    colorPicker.Color = color or {1, 1, 1, 1}
    colorPicker.IDContext = "SimpleColorPicker_" .. label
    colorPicker.OnChange = function(c)
        if onChange then
            onChange(c.Color)
        end
    end
    return colorPicker
end