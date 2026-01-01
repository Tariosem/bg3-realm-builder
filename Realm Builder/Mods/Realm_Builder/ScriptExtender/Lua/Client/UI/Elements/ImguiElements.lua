--- @class ImguiElements
--- @field AddSliderWithStep fun(parent: ExtuiTreeParent, IDContext: string?, defaultValue: number, min: number, max: number, step: number, isInteger?: boolean): RB_SliderWithStep
--- @field AddMenuButton fun(menu: ExtuiMenu|ExtuiTreeParent, text: string, onClick: function, isWindow: boolean): ExtuiMenuItem|ExtuiSelectable
--- @field AddRightAlignCell fun(parent: ExtuiTreeParent): (ExtuiTableCell, ExtuiTableCell, ExtuiTable) -- RightCell, LeftCell, Table
--- @field AddNumberSliders fun(parent: ExtuiTreeParent, label: string, getter: fun():number[], setter: fun(value: number[]), config: { IsInt: boolean, Range: { Min: number, Max: number, Step: number }, IsColor: boolean, OnReset: fun(), ResetValue: number[] }?): function
--- @field RenderExportSettingPanel fun(parent: ExtuiTreeParent, settings: RB_Mod_ExportSetting): function
--- @field AddBitmaskRadioButtons fun(parent: ExtuiTreeParent, options: RadioButtonOption[], initValue: integer): EnumRadioButtonsGroup
--- @field AddTree fun(parent: ExtuiTreeParent, label: string, open?: boolean): RB_UI_Tree
--- @field AddAlignedTable fun(parent: ExtuiTreeParent): AlignedTable
--- @field AddTwoColTable fun(parent: ExtuiTreeParent): (ExtuiTable, ExtuiTableCell, ExtuiTableCell) -- Table, LeftCell, RightCell
--- @field AddResetButton fun(parent: ExtuiTreeParent, sameLine?: boolean): (ExtuiImageButton, ExtuiGroup) -- Button, Group
--- @field AddCollapsingTable fun(parent: ExtuiTreeParent, mainAreaTitle: string, sideBarTitle?: string, opts?: CollapsingTableStyle): CollapsingTableStyle
ImguiElements = ImguiElements or {}

local function addLittleSpacer(parent, size)
    size = size or (10 * SCALE_FACTOR)
    local dummy = parent:AddDummy(size, 1)
    dummy.SameLine = true
    return dummy
end

--- @param parent ExtuiTreeParent
--- @param label string
--- @param step number
--- @param slider? ExtuiSliderInt|ExtuiSliderScalar
--- @param direction? '<'|'>'
--- @return ExtuiButton
local function AddSliderStepButton(parent, label, step, slider, direction)
    local button = parent:AddButton(label)
    button.IDContext = RBUtils.Uuid_v4()

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
function ImguiElements.AddSliderWithStep(parent, IDContext, defaultValue, min, max, step, isInteger)
    local sliderTable = {}
    if not IDContext then
        IDContext = RBUtils.Uuid_v4()
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
        slider = ImguiHelpers.SafeAddSliderInt(parent, "", defaultValue or 0, min or 0, max or 100)
        increButton = AddSliderStepButton(parent, ">", step, nil, ">")
    else
        decreButton = AddSliderStepButton(parent, "<", -step, nil, "<")
        slider = parent:AddSlider("", defaultValue or 0, min or 0, max or 100) --[[@as ExtuiSliderScalar]]
        increButton = AddSliderStepButton(parent, ">", step, nil, ">")
    end
    local resetButton, resetGroup = ImguiElements.AddResetButton(parent, true)
    decreButton.UserData.Slider = slider
    increButton.UserData.Slider = slider
    decreButton:SetStyle("ItemSpacing", 0)
    increButton:SetStyle("ItemSpacing", 0)
    slider:SetStyle("ItemSpacing", 0)

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
        local alignedTable = ImguiElements.AddAlignedTable(sliderPopup)
        sliderPopup.IDContext = IDContext .. "_SliderPopup"
        stepInput = isInteger and alignedTable:AddInputInt("Step", math.floor(step)) or
            alignedTable:AddInputScalar("Step", step)
        stepInput.IDContext = IDContext .. "_StepInput"
        stepInput.OnChange = function(input)
            local val = isInteger and math.floor(input.Value[1]) or input.Value[1]
            s.UserData.Step = val
        end

        max = s.Max[1] or max
        local maxInput = isInteger and alignedTable:AddInputInt("Max", math.floor(max)) or
            alignedTable:AddInputScalar("Max", max)
        maxInput.IDContext = IDContext .. "_MaxInput"
        maxInput.OnChange = function(input)
            local val = isInteger and math.floor(input.Value[1]) or input.Value[1]
            s.Max = { val, val, val, val }
        end

        min = s.Min[1] or min
        local minInput = isInteger and alignedTable:AddInputInt("Min", math.floor(min)) or
            alignedTable:AddInputScalar("Min", min)
        minInput.IDContext = IDContext .. "_MinInput"
        minInput.OnChange = function(input)
            local val = isInteger and math.floor(input.Value[1]) or input.Value[1]
            s.Min = { val, val, val, val }
        end

        local allInputs = { stepInput, minInput, maxInput }
        for _, input in ipairs(allInputs) do
            input.ItemWidth = 250 * SCALE_FACTOR
        end

        s.UserData.StepInput = stepInput

        sliderPopup:Open()
        slider.OnRightClick = function()
            local toFunc = isInteger and RBUtils.ToVec4Int or RBUtils.ToVec4
            stepInput.Value = toFunc(isInteger and math.floor(s.UserData.Step) or s.UserData.Step)
            minInput.Value = toFunc(isInteger and math.floor(s.Min[1]) or s.Min[1])
            maxInput.Value = toFunc(isInteger and math.floor(s.Max[1]) or s.Max[1])
            sliderPopup:Open()
        end
    end

    resetButton.IDContext = IDContext .. "_ResetButton"
    resetButton.OnClick = function()
        slider.Value = RBUtils.ToVec4(defaultValue or 0)
        if slider.OnChange then
            slider:OnChange()
        end
    end

    setmetatable(sliderTable, {
        __index = slider,
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
            else
                slider[k] = v
            end
        end
    })

    return sliderTable
end

function ImguiElements.AddMenuButton(menu, text, onClick, isWindow)
    local label = text
    local button
    if isWindow then
        menu = menu --[[@as ExtuiMenu]]
        button = menu:AddItem(label)
        button.OnClick = onClick
    else
        button = menu:AddSelectable(label) --[[@as ExtuiSelectable]]
        button.OnClick = function(e)
            onClick()
            e.Selected = false
        end
    end
    return button
end

---@param parent ExtuiTreeParent
---@return ExtuiTableCell, ExtuiTableCell, ExtuiTable -- RightCell, LeftCell, Table
function ImguiElements.AddRightAlignCell(parent)
    local tab, leftCell, rightCell = ImguiElements.AddTwoColTable(parent)
    tab.ColumnDefs[1] = { WidthStretch = true }
    tab.ColumnDefs[2] = { WidthFixed = true }
    return rightCell, leftCell, tab
end

---@param parent ExtuiTreeParent
---@param settings RB_Mod_ExportSetting
---@return function -- refresh function
function ImguiElements.RenderExportSettingPanel(parent, settings)
    local modNameText = parent:AddText("Mod Name*")
    local modNameInput = parent:AddInputText("##MaterialPresetModName")
    local modNameTooltip = modNameInput:Tooltip()

    modNameTooltip:SetColor("Border", { 1, 0, 0, 1 })
    modNameTooltip:SetStyle("FrameBorderSize", 2)
    modNameTooltip:SetStyle("WindowBorderSize", 2)

    local currentModInternalNameTooltip = modNameTooltip:AddText("Current Mod Internal Name:")
    currentModInternalNameTooltip:SetColor("Text", ColorUtils.HexToRGBA("FFFFBC51"))
    local modIntenalNameTooltip = modNameTooltip:AddText(settings.ModName and
        RBUtils.ValidateFolderName(settings.ModName) or "")
    modIntenalNameTooltip:SetColor("Text", ColorUtils.HexToRGBA("FFFFFFFF"))
    modIntenalNameTooltip.SameLine = true

    modNameInput.Hint = "Enter Mod Name..."
    modNameInput:SetStyle("FrameBorderSize", 2)
    modNameInput:SetStyle("WindowBorderSize", 2)


    modNameInput.OnChange = RBUtils.Debounce(50, function()
        if RBUtils.ValidateFolderName(modNameInput.Text) ~= 'Unnamed' then
            modIntenalNameTooltip.Label = RBUtils.ValidateFolderName(modNameInput.Text)
            StyleHelpers.ClearWarningBorder(modNameInput)
            settings.ModName = modNameInput.Text
        else
            modIntenalNameTooltip.Label = "Invalid Name"
            StyleHelpers.SetWarningBorder(modNameInput)
            settings.ModName = ""
            GuiAnim.PulseBorder(modNameInput, 2)
        end
    end)
    modNameInput.Text = settings.ModName or ""
    if modNameInput.Text == "" then
        StyleHelpers.SetWarningBorder(modNameInput)
    else
        StyleHelpers.ClearWarningBorder(modNameInput)
    end
    local authorNameText = parent:AddText("Author Name*")
    local authorNameInput = parent:AddInputText("##MaterialPresetAuthorName")
    authorNameInput:SetStyle("FrameBorderSize", 2)
    local modNameTooltip = modNameInput:Tooltip()
    modNameTooltip:AddText("CAUTION:"):SetColor("Text", ColorUtils.HexToRGBA("FFFF0000"))
    modNameTooltip:AddText("Special character will be removed from mod internal name."):SetColor("Text",
        ColorUtils.HexToRGBA("FFFFBD4C"))
    modNameTooltip:AddText("Space will be treated as underscore (_), but display name will remain unchanged.")
        :SetColor("Text", ColorUtils.HexToRGBA("FFFFBD4C"))
    modNameTooltip:AddText("My Mod and My_Mod are considered the same mod name."):SetColor("Text",
        ColorUtils.HexToRGBA("FFFFBD4C"))

    authorNameInput.Hint = "Enter Author Name..."
    authorNameInput.OnChange = RBUtils.Debounce(50, function()
        local newName = authorNameInput.Text
        if newName == "" then
            StyleHelpers.SetWarningBorder(authorNameInput)
            settings.Author = ""
            GuiAnim.PulseBorder(authorNameInput, 2)
        else
            StyleHelpers.ClearWarningBorder(authorNameInput)
            settings.Author = authorNameInput.Text
        end
    end)
    authorNameInput.Text = settings.Author or ""

    if authorNameInput.Text == "" then
        StyleHelpers.SetWarningBorder(authorNameInput)
    else
        StyleHelpers.ClearWarningBorder(authorNameInput)
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
                StyleHelpers.SetWarningBorder(versionInput)
                GuiAnim.PulseBorder(versionInput, 2)
            end
        end
        if valid then StyleHelpers.ClearWarningBorder(versionInput) end
        settings.Version = { versionInput.Value[1], versionInput.Value[2], versionInput.Value[3], versionInput.Value[4] }
    end
    versionInput.Value = { settings.Version[1], settings.Version[2], settings.Version[3], settings.Version[4] }
    StyleHelpers.ClearWarningBorder(versionInput)

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
function ImguiElements.AddNumberSliders(parent, label, getter, setter, config)
    --- @type any[], ExtuiColorEdit
    local sliders, colorPicker = {}, nil
    config = config or {}

    local updateMethod = function()
        local value = getter()
        if not value then return end

        if type(value) ~= "table" then
            value = { value }
        end

        for i, slider in ipairs(sliders) do
            slider.Value = { value[i], value[i], value[i], value[i] }
        end
        if colorPicker then
            colorPicker.Color = { value[1], value[2], value[3], value[4] or 1 }
        end
    end

    local initValue = config.ResetValue or getter()
    if type(initValue) ~= "table" then
        initValue = { initValue }
    end
    local initCnt = #initValue

    if initCnt == 0 then
        return function() end
    end

    local isInt = config.IsInt or false
    local range = config.Range or { Min = -10, Max = 10, Step = 0.1 }
    local uuid = RBUtils.Uuid_v4()
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
            slider.Value = { initValue[i], initValue[i], initValue[i], initValue[i] }
        end
        if colorPicker then
            colorPicker.Color = { initValue[1], initValue[2], initValue[3], initValue[4] or 1 }
        end

        setter(initValue)
        if config.OnReset then
            config.OnReset()
        end
    end

    local function renderSliders()
        for i = 1, initCnt do
            local slider = ImguiElements.AddSliderWithStep(slidersCell, tostring(i), initValue[i], range.Min, range.Max,
                range.Step,
                isInt)
            slider.OnChange = function()
                local currentValues = {}
                for j, s in ipairs(sliders) do
                    currentValues[j] = s.Value[1]
                end
                if colorPicker then
                    colorPicker.Color = { currentValues[1], currentValues[2], currentValues[3], initCnt == 4 and
                    currentValues[4] or 1 }
                end
                setter(currentValues)
            end
            sliders[i] = slider
            slider.HideResetButton = colorPicker and true or false
        end
    end

    if initCnt >= 3 and initCnt <= 4 and not config.IsInt then
        colorPicker = slidersCell:AddColorEdit("##ColorPicker_" .. uuid)
        colorPicker.NoAlpha = initCnt == 3
        colorPicker.AlphaBar = initCnt == 4
        colorPicker.Color = { initValue[1], initValue[2], initValue[3], initCnt == 4 and initValue[4] or 1 }
        local resetBtn = ImguiElements.AddResetButton(slidersCell, true)
        resetBtn.OnClick = function()
            resetChange()
        end

        colorPicker.OnRightClick = function()
            resetChange()
        end
        colorPicker.OnChange = function()
            setter({ colorPicker.Color[1], colorPicker.Color[2], colorPicker.Color[3], initCnt == 4 and
            colorPicker.Color[4] or nil })

            for i, slider in ipairs(sliders) do
                slider.Value = RBUtils.ToVec4(colorPicker.Color[i])
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
--- @param ignoreKeys table<any, boolean>?
--- @return function -- update function
function ImguiElements.AddGeneralTableEditor(parent, o, onSet, ignoreKeys)
    local updateFuncs = {}
    for k, v in RBUtils.SortedPairs(o) do
        if ignoreKeys and ignoreKeys[k] then
            goto continue
        end
        k = tostring(k)
        if k:sub(1, 1) == "_" then
            --skip private variables
            goto continue
        end
        local updateFunc = ImguiElements.AddEditorByGetter(parent, k,
            function() return o[k] end,
            function(newValue)
                o[k] = newValue
                if onSet then
                    onSet(k, newValue)
                end
            end)
        if updateFunc then
            table.insert(updateFuncs, updateFunc)
        end
        ::continue::
    end

    return function()
        for _, f in ipairs(updateFuncs) do
            f()
        end
    end
end

--- comment
--- @param parent ExtuiTreeParent
--- @param label string
--- @param getter fun():any
--- @param setter fun(any:any)
--- @return function? updater
function ImguiElements.AddEditorByGetter(parent, label, getter, setter)
    local alignedTable = ImguiElements.AddAlignedTable(parent)
    local initValue = getter()

    local updateFunc = nil
    if type(initValue) == "boolean" then
        local checkbox = alignedTable:AddCheckbox(label, initValue)
        checkbox.OnChange = function(sel)
            setter(sel.Checked)
        end
        updateFunc = function()
            checkbox.Checked = getter()
        end
    elseif type(initValue) == "number" then
        local slider, _ = alignedTable:AddSliderWithStep(label, initValue, 0, 100, 1, math.type(initValue) == "integer")
        slider.OnChange = function(sel)
            setter(sel.Value[1])
        end
        updateFunc = function()
            slider.Value = RBUtils.ToVec4(getter)
        end
    elseif type(initValue) == "string" then
        local inputText = alignedTable:AddInputText(label, initValue)
        inputText.OnChange = function(sel)
            setter(sel.Text)
        end
        updateFunc = function()
            inputText.Text = getter()
        end
    elseif RBTableUtils.IsArray(initValue) then
        updateFunc = ImguiElements.AddNumberSliders(parent, label, getter, setter,
            {
                IsInt = math.type(initValue[1]) == "integer",
                Range = { Min = 0, Max = 100, Step = 1 },
                ResetValue =
                    initValue
            })
    else
        --skip
    end

    return updateFunc
end

function ImguiElements.AddResetButton(parent, sameLine)
    local group = parent:AddGroup("ResetButtonGroup_" .. RBUtils.Uuid_v4())
    group.SameLine = sameLine and true or false

    local button = nil
    button = group:AddImageButton("##ResetButton_" .. RBUtils.Uuid_v4(), RB_ICONS.Arrow_CounterClockwise, IMAGESIZE
        .FRAME) --[[@as ExtuiImageButton]]

    --button.PositionOffset = { 0, 4 }
    return button, group
end

function ImguiElements.AddImageButton(parent, icon, sameLine)
    local group = parent:AddGroup("MiddleAlignedImageButtonGroup_" .. RBUtils.Uuid_v4())
    group.SameLine = sameLine and true or false
    local button = group:AddImageButton("##MiddleAlignedImageButton_" .. RBUtils.Uuid_v4(), icon, IMAGESIZE.FRAME) --[[@as ExtuiImageButton]]
    return button, group
end

---@param parent ExtuiTreeParent
---@param size number?
---@return ExtuiGroup
function ImguiElements.AddIndent(parent, size)
    local _, rightGroup = parent:AddDummy(size or (10 * SCALE_FACTOR), 1),
        parent:AddGroup("IndentGroup_" .. RBUtils.Uuid_v4())
    rightGroup.SameLine = true
    return rightGroup
end

function ImguiElements.AddCenterAlignTable(parent, label)
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
function ImguiElements.AddSelectableButton(parent, label, onClick)
    local button = parent:AddSelectable(label) --[[@as ExtuiSelectable]]
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
---@param label string
---@param icon string
---@return ExtuiStyledRenderable
function ImguiElements.AddImageSelectable(parent, label, icon)
    local group = parent:AddGroup(label)

    local imgBtn = group:AddImageButton("##" .. label .. "_ImgBtn", icon, IMAGESIZE.FRAME) --[[@as ExtuiImageButton]]
    local selectable = group:AddSelectable(label .. "##" .. "_Selectable") --[[@as ExtuiSelectable]]

    imgBtn.OnHoverLeave = function()
        selectable.Highlight = false
    end
    imgBtn.OnHoverEnter = function()
        selectable.Highlight = true
    end
    selectable.SameLine = true

    selectable.OnClick = function ()
        selectable.Selected = false
    end

    local obj = {
    }

    local keys = {
        OnClick = true,
        OnRightClick = true,
    }

    setmetatable(obj, {
        __newindex = function (t, k, v)
            if keys[k] then
                imgBtn[k] = v
                selectable[k] = function ()
                    selectable.Selected = false
                    v(selectable)
                end
            elseif k == "OnHoverEnter" or k == "OnHoverLeave" then
                local originFunc = imgBtn[k]
                imgBtn[k] = function(...)
                    if originFunc then
                        originFunc(...)
                    end
                    v(...)
                end
                originFunc = selectable[k]
                selectable[k] = function(...)
                    if originFunc then
                        originFunc(...)
                    end
                    v(...)
                end
            else
                group[k] = v
            end
        end
    })

    return obj

end

--- @class AttrTable : ExtuiTable
--- @field AddNewLine fun(self: AttrTable, label:string): ExtuiTableCell
--- @field SetValue fun(self: AttrTable, name: string, value: string)

---@param parent ExtuiTreeParent
---@param contents table<string, string>
---@return AttrTable
function ImguiElements.AddReadOnlyAttrTable(parent, contents)
    local tab = parent:AddTable(parent.Label, 2) --[[@as ExtuiTable]]
    tab.BordersInnerV = true
    tab.ColumnDefs[1] = { WidthFixed = true }
    tab.ColumnDefs[2] = { WidthStretch = true }

    local clampWidth = 1200 * SCALE_FACTOR
    local textWidth = 20
    local inputs = {}

    local function updateAllLengths()
        local maxLen = 0
        for name, input in pairs(inputs) do
            if #input.Text > maxLen then
                maxLen = #input.Text
            end
        end
        local totalWidth = (textWidth * maxLen + 50) * SCALE_FACTOR
        if totalWidth > clampWidth then
            totalWidth = clampWidth
        end
        for name, input in pairs(inputs) do
            input.SizeHint = { totalWidth, 0 }
        end
    end

    local function addRow(name, value)
        if type(value) == "table" then
            value = table.concat(value, ",")
        end
        local valueStr = tostring(value)
        if not valueStr or valueStr == "nil" or valueStr == "" then
            return
        end

        local row = tab:AddRow() --[[@as ExtuiTableRow]]
        local nameCell = row:AddCell()
        nameCell:AddText(name)
        addLittleSpacer(nameCell)

        local valueCell = row:AddCell()
        local input = valueCell:AddInputText("", valueStr) --[[@as ExtuiInputText]]
        inputs[name] = input
        input.Text = tostring(value)
        input.IDContext = "ReadOnlyAttrInput##" .. name
        input.ReadOnly = true
        input.AutoSelectAll = true
    end

    for name, value in RBUtils.SortedPairs(contents) do
        addRow(name, value)
    end
    updateAllLengths()

    --- @type AttrTable
    local clos = {
        AddNewLine = function(_, name)
            local row = tab:AddRow() --[[@as ExtuiTableRow]]
            local nameCell = row:AddCell()
            nameCell:AddText(name)
            addLittleSpacer(nameCell)
            local valueCell = row:AddCell()
            return valueCell
        end,
        SetValue = function(_, name, value)
            local input = inputs[name]
            if input then
                input.Text = tostring(value)
            else
                addRow(name, value)
            end
            updateAllLengths()
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
--- @field AddNearbyCombo fun(self: AlignedTable, label: string): NearbyCombo
--- @field AddNewLine fun(self: AlignedTable, label: string): ExtuiTableCell

---@param parent ExtuiTreeParent
---@return AlignedTable
function ImguiElements.AddAlignedTable(parent)
    local tab = parent:AddTable(parent.Label, 2) --[[@as ExtuiTable]]
    tab.BordersInnerV = true
    tab.ColumnDefs[1] = { WidthFixed = true }
    tab.ColumnDefs[2] = { WidthStretch = true }

    local row = tab:AddRow() --[[@as ExtuiTableRow]]
    local clos = {
        AddSliderWithStep = function(_, label, defaultValue, min, max, step, isInteger)
            --local row = tab:AddRow() --[[@as ExtuiTableRow]]
            local nameCell = row:AddCell()
            nameCell:AddText(label)
            addLittleSpacer(nameCell)
            local valueCell = row:AddCell()

            return ImguiElements.AddSliderWithStep(valueCell, "##" .. label .. "Slider", defaultValue,
                min, max, step, isInteger), valueCell
        end,
        AddNearbyCombo = function(_, label)
            --local row = tab:AddRow() --[[@as ExtuiTableRow]]
            local nameCell = row:AddCell()
            nameCell:AddText(label)
            addLittleSpacer(nameCell)
            local valueCell = row:AddCell()

            return NearbyCombo.new(valueCell)
        end,
        AddNewLine = function(_, label)
            --local row = tab:AddRow() --[[@as ExtuiTableRow]]
            local nameCell = row:AddCell()
            nameCell:AddText(label)
            addLittleSpacer(nameCell)
            local valueCell = row:AddCell()
            return valueCell
        end,
    }

    setmetatable(clos, {
        __index = function(_, k)
            if rawget(clos, k) then
                return rawget(clos, k)
            end

            if k:sub(1, 3) == "Add" then
                return function(_, ...)
                    local args = { ... }
                    local label = table.remove(args, 1) or ""
                    --local row = tab:AddRow() --[[@as ExtuiTableRow]]
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

---@param parent ExtuiTreeParent
---@param label string?
---@return ExtuiTable
---@return ExtuiTableCell
---@return ExtuiTableCell
function ImguiElements.AddTwoColTable(parent, label)
    local table = parent:AddTable(label or RBUtils.Uuid_v4(), 2)
    local row = table:AddRow()
    local leftCell = row:AddCell()
    local rightCell = row:AddCell()
    return table, leftCell, rightCell
end

function ImguiElements.AddStyleDebugWindow(extui, symbol)
    local readonly = {
        LastSize = true,
        LastPosition = true,
        Handle = true,

    }
    symbol = symbol or ""
    local window = Ext.IMGUI.NewWindow("Style Debugger " .. symbol .. "##" .. RBUtils.Uuid_v4())
    window.Closeable = true
    window.OnClose = function()
        window:Destroy()
    end
    ImguiElements.AddGeneralTableEditor(window, extui, function()
    end, readonly)

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
