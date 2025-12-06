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
    button:SetColor("Button", CONFIG.Misc.InfoButtonColor)
    button:SetColor("ButtonHovered", CONFIG.Misc.InfoButtonHoveredColor)
    button:SetColor("ButtonActive", CONFIG.Misc.InfoButtonActiveColor)
    button:SetColor("Text", CONFIG.Misc.InfoButtonTextColor)
end

---@param button ExtuiButton
function StyleHelpers.ApplyDangerButtonStyle(button)
    button:SetColor("Button", CONFIG.Misc.DangerButtonColor)
    button:SetColor("ButtonHovered", CONFIG.Misc.DangerButtonHoveredColor)
    button:SetColor("ButtonActive", CONFIG.Misc.DangerButtonActiveColor)
    button:SetColor("Text", CONFIG.Misc.DangerButtonTextColor)
end

--- @param s ExtuiSelectable|ExtuiStyledRenderable
function StyleHelpers.ApplyDangerSelectableStyle(s)
    s:SetColor("HeaderHovered", CONFIG.Misc.DangerButtonColor)
    s:SetColor("Text", CONFIG.Misc.DangerButtonHoveredColor)
end

function StyleHelpers.ApplyConfirmButtonStyle(button)
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


function StyleHelpers.SetWarningBorder(extui)
    extui:SetColor("Text", HexToRGBA("FFFF0000"))
    extui:SetColor("Border", HexToRGBA("FFFF4444"))
end

function StyleHelpers.ClearWarningBorder(extui)
    extui:SetColor("Text", HexToRGBA("FFFFFFFF"))
    extui:SetColor("Border", HexToRGBA("FF888888"))
end

function StyleHelpers.ApplyWarningButtonStyle(button)
    button:SetColor("Text", HexToRGBA("FFFF0000"))
    button:SetColor("Border", HexToRGBA("FFFF4444"))
    button:SetColor("Button", HexToRGBA("FF470000"))
    button:SetColor("ButtonHovered", HexToRGBA("FF700000"))
    button:SetColor("ButtonActive", HexToRGBA("FF900000"))
end

function StyleHelpers.ApplyOkButtonStyle(button)
    button:SetColor("Text", HexToRGBA("FFFFFFFF"))
    button:SetColor("Border", HexToRGBA("FF888888"))
    button:SetColor("Button", HexToRGBA("FF004747"))
    button:SetColor("ButtonHovered", HexToRGBA("FF007070"))
    button:SetColor("ButtonActive", HexToRGBA("FF009090"))
end

function StyleHelpers.ApplyWarningTooltipStyle(tooltip)
    tooltip:SetColor("Text", HexToRGBA("FFFF0000"))
    tooltip:SetColor("Border", HexToRGBA("FFFF4444"))
    tooltip:SetColor("WindowBg", HexToRGBA("FF220000"))
end

function StyleHelpers.ApplyOkTooltipStyle(tooltip)
    tooltip:SetColor("Text", HexToRGBA("FFFFFFFF"))
    tooltip:SetColor("Border", HexToRGBA("FF888888"))
    tooltip:SetColor("WindowBg", HexToRGBA("FF222222"))
end

--- @param extui ExtuiStyledRenderable
function StyleHelpers.ClearAllBorders(extui)
    extui:SetColor("Text", HexToRGBA("FFFFFFFF"))
    extui:SetColor("Border", HexToRGBA("00000000"))
    extui:SetStyle("FrameBorderSize", 0)
    extui:SetStyle("WindowBorderSize", 0)
    extui:SetStyle("PopupBorderSize", 0)
    extui:SetStyle("ChildBorderSize", 0)
    extui:SetStyle("TabBorderSize", 0)
end

function StyleHelpers.ApplyWarningTooitipStyle(tooltip)
    tooltip:SetColor("Text", HexToRGBA("FFFF0000"))
    tooltip:SetColor("Border", HexToRGBA("FFFF4444"))
    tooltip:SetColor("WindowBg", HexToRGBA("FF220000"))
    tooltip:SetStyle("FrameBorderSize", 2)
    tooltip:SetStyle("WindowBorderSize", 2)
    tooltip:SetStyle("PopupBorderSize", 2)
    tooltip:SetStyle("ChildBorderSize", 2)
end

