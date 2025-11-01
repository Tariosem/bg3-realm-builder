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
--- @param IDContext string?
--- @param defaultValue number
--- @param min number
--- @param max number
--- @param step number
--- @param isInteger? boolean
--- @return ExtuiSliderInt|ExtuiSliderScalar
function AddSliderWithStep(parent, IDContext, defaultValue, min, max, step, isInteger)
    local sliderProxy = {}
    if not IDContext then
        IDContext = Uuid_v4()
    end
    local stepInput = nil
    local slider = nil
    local decreButton = nil
    local increButton = nil
    local sliderPopup = parent:AddPopup(IDContext .. "_SliderPopup")
    sliderPopup.AlwaysAutoResize = false
    step = step or 0.1
    if isInteger then
        stepInput = sliderPopup:AddInputInt("Step", math.floor(step))
        decreButton = AddSliderStepButton(parent, "<", -step, nil, "<")
        slider = SafeAddSliderInt(parent, "", defaultValue or 0, min or 0, max or 100)
        increButton = AddSliderStepButton(parent, ">", step, nil, ">")
    else
        stepInput = sliderPopup:AddInputScalar("Step", step)
        decreButton = AddSliderStepButton(parent, "<", -step, nil, "<")
        slider = parent:AddSlider("", defaultValue or 0, min or 0, max or 100) --[[@as ExtuiSliderScalar]]
        increButton = AddSliderStepButton(parent, ">", step, nil, ">")
    end
    local resetButton = parent:AddButton("Reset")
    decreButton.UserData.Slider = slider
    increButton.UserData.Slider = slider

    local allEles = {decreButton, slider, increButton, resetButton}
    stepInput.IDContext = IDContext .. "_StepInput"
    increButton.IDContext = IDContext .. "_IncreButton"
    slider.IDContext = IDContext .. "_Slider"
    decreButton.IDContext = IDContext .. "_DecreButton"

    slider.UserData = {}
    local ud = slider.UserData
    ud.StepInput = stepInput
    ud.DecreButton = decreButton
    ud.IncreButton = increButton
    ud.Parent = parent
    ud.ResetButton = resetButton
    ud.Step = step

    --decreButton.SameLine = true
    increButton.SameLine = true
    slider.SameLine = true
    --stepInput.SameLine = true

    stepInput.OnChange = function()
        local step = stepInput.Value[1]
        slider.UserData.Step = step
    end

    slider.OnRightClick = function(s)
        sliderPopup:Open()
    end

    resetButton.SameLine = true
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
            elseif k == "SameLine" then
                for _, ele in ipairs(allEles) do
                    ele.SameLine = v
                end
            else
                slider[k] = v
            end
        end
    })

    return sliderProxy
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
        
        local dir = direction == "<" and "<" or ">"
        local factor = 10.0
        if dir == ">" then
            local newMin = Vec4.new(s.Min) * factor
            local newMax = Vec4.new(s.Max) * factor
            s.Min = newMin
            s.Max = newMax
        else
            local newMin = Vec4.new(s.Min) / factor
            local newMax = Vec4.new(s.Max) / factor
            s.Min = newMin
            s.Max = newMax
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

function AddStyleDebugWindow(extui)
    local window = Ext.IMGUI.NewWindow("Style Debugger##" .. Uuid_v4())
    window.Closeable = true
    window.OnClose = function()
        window:Destroy()
    end
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
function AddMiddleAlignTable(parent, label)
    label = label or "MiddleAlignTable"
    local table = parent:AddTable(label .. "##" .. math.random(1, 10000), 3)
    table.ColumnDefs[1] = { WidthStretch = true }
    table.ColumnDefs[2] = { WidthFixed = true }
    table.ColumnDefs[3] = { WidthStretch = true }
    return table
end

function AddLeftAlignTable(parent, label)
    label = label or "LeftAlignTable"
    local table = parent:AddTable(label .. "##" .. math.random(1, 10000), 2)
    table.ColumnDefs[1] = { WidthFixed = true }
    table.ColumnDefs[2] = { WidthStretch = true }
    return table
end

function AddRightAlighTable(parent, label)
    label = label or "RightAlignTable"
    local table = parent:AddTable(label .. "##" .. math.random(1, 10000), 2)
    table.ColumnDefs[1] = { WidthStretch = true }
    table.ColumnDefs[2] = { WidthFixed = true }
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

---@param parent ExtuiTreeParent
function StyleHelpers.AddSelectionTable(parent)
    local tab = parent:AddTable("SelectionTable##" .. Uuid_v4(), 1) --[[@as ExtuiTable]]
    tab.BordersInnerH = true

    local row = tab:AddRow() --[[@as ExtuiTableRow]]

    return tab, row
end