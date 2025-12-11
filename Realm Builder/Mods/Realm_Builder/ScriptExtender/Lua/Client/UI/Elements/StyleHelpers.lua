--- @class StyleHelpers
--- @field ApplyInfoButtonStyle fun(button:ExtuiButton)
--- @field ApplyDangerButtonStyle fun(button:ExtuiButton)
--- @field ApplyDangerSelectableStyle fun(s:ExtuiSelectable|ExtuiStyledRenderable)
--- @field ApplyConfirmButtonStyle fun(button:ExtuiButton)
--- @field SetAlphaByBool fun(s:ExtuiRenderable, bool:boolean)
--- @field SetNormalProgressBarStyle fun(pBar:ExtuiProgressBar)
--- @field SetWarningProgressBarStyle fun(pBar:ExtuiProgressBar)
--- @field SetWarningBorder fun(extui:ExtuiStyledRenderable)
--- @field ClearWarningBorder fun(extui:ExtuiStyledRenderable)
--- @field ApplyWarningButtonStyle fun(button:ExtuiButton)
--- @field ApplyOkButtonStyle fun(button:ExtuiButton)
--- @field ApplyWarningTooltipStyle fun(tooltip:ExtuiStyledRenderable)
--- @field ClearAllBorders fun(extui:ExtuiStyledRenderable)
--- @field ApplyWarningTooitipStyle fun(tooltip:ExtuiStyledRenderable)
StyleHelpers = StyleHelpers or {}

function StyleHelpers.ApplyInfoButtonStyle(button)
    button:SetColor("Button", UICONFIG.Misc.InfoButtonColor)
    button:SetColor("ButtonHovered", UICONFIG.Misc.InfoButtonHoveredColor)
    button:SetColor("ButtonActive", UICONFIG.Misc.InfoButtonActiveColor)
    button:SetColor("Text", UICONFIG.Misc.InfoButtonTextColor)
end

---@param button ExtuiButton
function StyleHelpers.ApplyDangerButtonStyle(button)
    button:SetColor("Button", UICONFIG.Misc.DangerButtonColor)
    button:SetColor("ButtonHovered", UICONFIG.Misc.DangerButtonHoveredColor)
    button:SetColor("ButtonActive", UICONFIG.Misc.DangerButtonActiveColor)
    button:SetColor("Text", UICONFIG.Misc.DangerButtonTextColor)
end

--- @param s ExtuiSelectable|ExtuiStyledRenderable
function StyleHelpers.ApplyDangerSelectableStyle(s)
    s:SetColor("HeaderHovered", UICONFIG.Misc.DangerButtonColor)
    s:SetColor("Text", UICONFIG.Misc.DangerButtonHoveredColor)
end

function StyleHelpers.ApplyConfirmButtonStyle(button)
    button:SetColor("Button", UICONFIG.Misc.ConfirmButtonColor)
    button:SetColor("ButtonHovered", UICONFIG.Misc.ConfirmButtonHoveredColor)
    button:SetColor("ButtonActive", UICONFIG.Misc.ConfirmButtonActiveColor)
    button:SetColor("Text", UICONFIG.Misc.ConfirmButtonTextColor)
end

--- @param s ExtuiRenderable
function StyleHelpers.SetAlphaByBool(s, bool)
    if bool then
        s:SetStyle("Alpha", 1)
    else
        s:SetStyle("Alpha", 0.6)
    end
end

--- @param pBar ExtuiProgressBar
function StyleHelpers.SetNormalProgressBarStyle(pBar)
    pBar:SetStyle("FrameBorderSize", 2)
    pBar:SetColor("PlotHistogram", ColorUtils.HexToRGBA("FF397D38"))
    pBar:SetColor("Border", ColorUtils.HexToRGBA("FF31BEBE"))
    pBar:SetColor("Text", { 1, 1, 1, 1 })
end

--- @param pBar ExtuiProgressBar
function StyleHelpers.SetWarningProgressBarStyle(pBar)
    pBar:SetStyle("FrameBorderSize", 2)
    pBar:SetColor("PlotHistogram", ColorUtils.HexToRGBA("FFFF4444"))
    pBar:SetColor("Border", ColorUtils.HexToRGBA("FFFF0000"))
    pBar:SetColor("Text", { 1, 1, 1, 1 })
    GuiAnim.PulseBorder(pBar, 2)
end


function StyleHelpers.SetWarningBorder(extui)
    extui:SetColor("Text", ColorUtils.HexToRGBA("FFFF0000"))
    extui:SetColor("Border", ColorUtils.HexToRGBA("FFFF4444"))
end

function StyleHelpers.ClearWarningBorder(extui)
    extui:SetColor("Text", ColorUtils.HexToRGBA("FFFFFFFF"))
    extui:SetColor("Border", ColorUtils.HexToRGBA("FF888888"))
end

function StyleHelpers.ApplyWarningButtonStyle(button)
    button:SetColor("Text", ColorUtils.HexToRGBA("FFFF0000"))
    button:SetColor("Border", ColorUtils.HexToRGBA("FFFF4444"))
    button:SetColor("Button", ColorUtils.HexToRGBA("FF470000"))
    button:SetColor("ButtonHovered", ColorUtils.HexToRGBA("FF700000"))
    button:SetColor("ButtonActive", ColorUtils.HexToRGBA("FF900000"))
end

function StyleHelpers.ApplyOkButtonStyle(button)
    button:SetColor("Text", ColorUtils.HexToRGBA("FFFFFFFF"))
    button:SetColor("Border", ColorUtils.HexToRGBA("FF888888"))
    button:SetColor("Button", ColorUtils.HexToRGBA("FF004747"))
    button:SetColor("ButtonHovered", ColorUtils.HexToRGBA("FF007070"))
    button:SetColor("ButtonActive", ColorUtils.HexToRGBA("FF009090"))
end

function StyleHelpers.ApplyWarningTooltipStyle(tooltip)
    tooltip:SetColor("Text", ColorUtils.HexToRGBA("FFFF0000"))
    tooltip:SetColor("Border", ColorUtils.HexToRGBA("FFFF4444"))
    tooltip:SetColor("WindowBg", ColorUtils.HexToRGBA("FF220000"))
end

function StyleHelpers.ApplyOkTooltipStyle(tooltip)
    tooltip:SetColor("Text", ColorUtils.HexToRGBA("FFFFFFFF"))
    tooltip:SetColor("Border", ColorUtils.HexToRGBA("FF888888"))
    tooltip:SetColor("WindowBg", ColorUtils.HexToRGBA("FF222222"))
end

--- @param extui ExtuiStyledRenderable
function StyleHelpers.ClearAllBorders(extui)
    extui:SetColor("Text", ColorUtils.HexToRGBA("FFFFFFFF"))
    extui:SetColor("Border", ColorUtils.HexToRGBA("00000000"))
    extui:SetStyle("FrameBorderSize", 0)
    extui:SetStyle("WindowBorderSize", 0)
    extui:SetStyle("PopupBorderSize", 0)
    extui:SetStyle("ChildBorderSize", 0)
    extui:SetStyle("TabBorderSize", 0)
end

function StyleHelpers.ApplyWarningTooitipStyle(tooltip)
    tooltip:SetColor("Text", ColorUtils.HexToRGBA("FFFF0000"))
    tooltip:SetColor("Border", ColorUtils.HexToRGBA("FFFF4444"))
    tooltip:SetColor("WindowBg", ColorUtils.HexToRGBA("FF220000"))
    tooltip:SetStyle("FrameBorderSize", 2)
    tooltip:SetStyle("WindowBorderSize", 2)
    tooltip:SetStyle("PopupBorderSize", 2)
    tooltip:SetStyle("ChildBorderSize", 2)
end

