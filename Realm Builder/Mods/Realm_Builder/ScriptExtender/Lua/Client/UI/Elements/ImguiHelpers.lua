--- @class ImguiHelpers
--- @field SafeAddSliderInt fun(parent: ExtuiTreeParent|ExtuiStyledRenderable, label: string, default: number, min: number, max: number): ExtuiSliderInt
--- @field GetCombo fun(Combo: ExtuiCombo): string
--- @field SetCombo fun(Combo: ExtuiCombo, Value: string, ifNotFoundAdd?: boolean, noTrigger?: boolean)
--- @field FocusWindow fun(window: any)
--- @field IsFocused fun(extui: ExtuiStyledRenderable): boolean
--- @field SetImguiDisabled fun(extui: ExtuiStyledRenderable, disabled: boolean)
--- @field DestroyAllChildren fun(parent: ExtuiTreeParent)
--- @field TraverseAllChildren fun(parent: ExtuiTreeParent): fun(): (integer?, ExtuiStyledRenderable?)
--- @field CreateRadioButtonOptionFromEnum fun(enumType: string): RadioButtonOption[]
--- @field CreateRadioButtonOptionFromBitmask fun(enumType: string): RadioButtonOption[]
--- @field SetupImageButton fun(arrowImage: ExtuiImageButton)
ImguiHelpers = ImguiHelpers or {}

---@param parent ExtuiTreeParent|ExtuiStyledRenderable
---@param label string
---@param default number
---@param min number
---@param max number
---@return ExtuiSliderInt
function ImguiHelpers.SafeAddSliderInt(parent, label, default, min, max)
    --- @diagnostic disable-next-line
    return parent:AddSliderInt(label or "", math.floor(default or 0), math.floor(min or 0), math.floor(max or 100))
end

--- @param arrowImage ExtuiImageButton
--- @param tooltipText string?
function ImguiHelpers.SetupImageButton(arrowImage, tooltipText)
    StyleHelpers.ClearAllBorders(arrowImage)
    arrowImage.Tint = arrowImage.Tint or { 1, 1, 1, 1 }
    
    arrowImage.OnHoverEnter = function()
        arrowImage.Tint = { arrowImage.Tint[1], arrowImage.Tint[2], arrowImage.Tint[3], arrowImage.Tint[4] * 0.8 }
    end
    if tooltipText then
        local notAddedTooltip = true --[[@type boolean?]]
        arrowImage.OnHoverEnter = function()
            arrowImage.Tint = { arrowImage.Tint[1], arrowImage.Tint[2], arrowImage.Tint[3], arrowImage.Tint[4] * 0.8 }
            if notAddedTooltip then
                ImguiHelpers.Tooltip(tooltipText)
                notAddedTooltip = nil
            end
        end
    end
    arrowImage.OnHoverLeave = function()
        arrowImage.Tint = { arrowImage.Tint[1], arrowImage.Tint[2], arrowImage.Tint[3], arrowImage.Tint[4] / 0.8 }
    end
    arrowImage:SetColor("Button", { 0, 0, 0, 0 })
    arrowImage:SetColor("ButtonHovered", { 0, 0, 0, 0 })
    arrowImage:SetColor("ButtonActive", { 0, 0, 0, 0 })
end

--- @param c ExtuiCombo
--- @return string
function ImguiHelpers.GetCombo(c)
    return c.Options[c.SelectedIndex + 1]
end

---@param c ExtuiCombo
---@param Value string
---@param ifNotFoundAdd? boolean
---@param noTrigger? boolean
function ImguiHelpers.SetCombo(c, Value, ifNotFoundAdd, noTrigger)
    for i, v in pairs(c.Options) do
        if v == Value then
            -- So the combo index start from 0 but lua table index start from 1. ???
            c.SelectedIndex = i - 1
            break
        end
    end
    if ifNotFoundAdd then
        table.insert(c.Options, Value)
        c.SelectedIndex = #c.Options - 1
    end

    if not noTrigger and c.OnChange then
        c:OnChange()
    end
end

---@param window ExtuiWindow
function ImguiHelpers.FocusWindow(window)
    window:SetCollapsed(false)
    window:SetFocus()
    window.Open = true
end

local focusFlag = Ext.Enums.GuiItemStatusFlags.Focused
--- @param extui ExtuiStyledRenderable
--- @return boolean
function ImguiHelpers.IsFocused(extui)
    if not extui then return false end
    return (extui.StatusFlags & focusFlag) ~= 0
end

--- @param extui ExtuiStyledRenderable
--- @param disabled boolean
function ImguiHelpers.SetImguiDisabled(extui, disabled)
    if not extui then return end
    extui.Disabled = disabled
    extui:SetStyle("Alpha", disabled and 0.6 or 1)
end

--- @param parent ExtuiTreeParent
function ImguiHelpers.DestroyAllChildren(parent)
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

--- @param parent ExtuiTreeParent
--- @return fun(): (integer?, ExtuiStyledRenderable?)
function ImguiHelpers.TraverseAllChildren(parent)
    local children = parent.Children

    local iterator = 1

    return function ()
        local child = children[iterator]
        if child then
            iterator = iterator + 1
            return iterator, child
        end
        return nil
    end
end

--- @param enumType string
--- @return RadioButtonOption[]
function ImguiHelpers.CreateRadioButtonOptionFromEnum(enumType)
    local enum = Ext.Enums[enumType]
    if not enum then
        Warning("Enum type " .. enumType .. " not found!")
        return {}
    end

    local options = {}
    for name, value in pairs(enum) do
        if type(name) == "string" then
            table.insert(options, {
                Label = name,
                Value = value.Value
            })
        end
    end
    table.sort(options, function(a, b)
        return a.Value < b.Value
    end)
    return options
end

function ImguiHelpers.CreateRadioButtonOptionFromBitmask(enumType)
    local enum = Ext.Enums[enumType]
    if not enum then
        Warning("Enum type " .. enumType .. " not found!")
        return {}
    end

    local options = {}
    for name, value in pairs(enum) do
        if type(name) == "string" then
            table.insert(options, {
                Label = name,
                Value = value.__Value
            })
        end
    end
    table.sort(options, function(a, b)
        return a.Value < b.Value
    end)
    return options
end