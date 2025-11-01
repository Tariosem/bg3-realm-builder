--- @class RB_TextToken
--- @field Text string
--- @field Color vec4|nil
--- @field Font string|nil
--- @field Style table<GuiStyleVar, vec2|number>?
--- @field Icon string|nil
--- @field SameLine boolean|nil
--- @field TooltipRef {Name: string, Type: string}|nil -- Stat object reference
--- @field Tooltip fun(tooltip: ExtuiTooltip)|nil -- a function that adds tooltip content

local punctuations = {
    [","] = true,
    ["."] = true,
    [";"] = true,
    [":"] = true,
    ["!"] = true,
    ["?"] = true,
}

function RenderTokenTexts(parent, tokens, firstAlwaysSameLine)
    local elements = {}

    local oneCharEndurance = true
    for i, token in ipairs(tokens) do
        local text = token.Text or ""

        --- dirty fix for punctuation at start of text
        if not token.SameLine and #text > 1 and punctuations[text:sub(1,1)] then
            local firstChar = text:sub(1,1)
            local textRest = text:sub(2)
            local labelPunc = parent:AddText(firstChar)
            labelPunc.SameLine = true
            text = textRest
        end
        
        local icon = nil
        local statsName = nil
        local statsType = nil
        local statsObj = nil
        if token.TooltipRef then
            statsName = token.TooltipRef.Name
            statsObj = Ext.Stats.Get(statsName) --[[ @type StatsObject ]]
            statsType = token.TooltipRef.Type
        end
        
        if token.Icon and not token.TooltipRef then
            icon = parent:AddImage(token.Icon)
            icon.ImageData.Size = ToVec2(32 * SCALE_FACTOR)
        end

        local label = nil

        local statImage = nil
        if token.TooltipRef and statsObj then
            local statsObjRenderfunc = RenderStatsObject(statsObj, statsType, text)
            statImage,label = statsObjRenderfunc(parent, true)
        else
            label = parent:AddText(text)
        end

        if token.Font then label.Font = token.Font end
        if token.Color then
            label:SetColor("Text", token.Color)
        end
        if token.Style then
            for styleVar, styleVal in pairs(token.Style) do
                styleVal = type(styleVal) == "number" and styleVal or ToVec2(styleVal)
                label:SetStyle(styleVar, styleVal[1], styleVal[2])
            end
        end
        if token.Tooltip then
            if icon then
                token.Tooltip(icon:Tooltip())
            else
                token.Tooltip(label:Tooltip())
            end
        end

        if statImage then
            statImage.SameLine = token.SameLine == true
            label.SameLine = true
        else
            label.SameLine = token.SameLine
        end
        
        if firstAlwaysSameLine and i == 1 then
            label.SameLine = true
            if icon then
                icon.SameLine = true
            end
            firstAlwaysSameLine = false
        end

        if #token.Text == 1 and oneCharEndurance then
            label.SameLine = true
            oneCharEndurance = false
        else
            oneCharEndurance = true
        end

        table.insert(elements, label)
    end
    return elements
end


---@param statsObj StatsObject
---@param parent ExtuiTreeParent
---@param type any
---@param isTooltip any
local function RenderStatsObjectTitle(statsObj, parent, type, isTooltip)
    local descRender = StatsParser:ParseDesc(statsObj.Description or nil, nil, statsObj.DescriptionParams, nil, isTooltip)

    local displayName = GetLoca(statsObj.DisplayName or "Unknown", "Unknown")
    local icon = CheckIcon(statsObj.Icon or "Item_Unknown")
    local table = parent:AddTable(statsObj.DisplayName or "Unknown", 2)
    table.ColumnDefs[1] = { WidthStretch = true }
    table.ColumnDefs[2] = { FixedWidth = true }
    local tableRow = table:AddRow()
    local nameCell = tableRow:AddCell()
    local iconCell = tableRow:AddCell()

    local title = nameCell:AddText(displayName)
    title:SetColor("Text", HIGHLIGHT_COLOR)

    if type == "SpellData" then
        local spellLevel = statsObj.Level == 0 and "Cantrips" or GetLoca("Level ") .. tostring(statsObj.Level or "?")
        local spellSchool = statsObj.SpellSchool --[[ @type string ]]
        if spellSchool == "None" then
            spellLevel = "Class Actions"
            spellSchool = ""
        else
            spellSchool = spellSchool .. " Spell"
        end

        local subTitle = string.format("%s %s", spellLevel, spellSchool)
        local subTitleText = nameCell:AddText(subTitle)
        subTitleText:SetColor("Text", SUBTITLE_COLOR)
    end

    local image = iconCell:AddImage(icon, ToVec2(64 * SCALE_FACTOR))

    image.OnHoverEnter = function()
        local tooltip = image:Tooltip()
        local rawInfoTab = tooltip:AddTable("Raw Info", 2)
        local rawInfoRow = rawInfoTab:AddRow()
        for k, v in pairs(statsObj) do
            local keyCell = rawInfoRow:AddCell()
            keyCell:AddText(tostring(k))
            local valCell = rawInfoRow:AddCell()
            valCell:AddText(tostring(v))
        end
        image.OnHoverEnter = nil
    end

    local rightContent = AddIndent(parent, 2 * SCALE_FACTOR)
    descRender(rightContent)
    parent:SetStyle("WindowBorderSize", 2)
    parent:SetColor("Border", BORDER_COLOR)

end

---@param spellData any
---@param parent ExtuiTreeParent
local function renderSpellAttrs(spellData, parent)
    if not spellData then return end

    local first = false

    if spellData.Range and spellData.Range ~= 0 then
        parent:AddText("Range: " .. spellData.Range .. " meters ").SameLine = first
        first = true
    end

    if spellData.TooltipAttackSave and spellData.TooltipAttackSave ~= "" then
        local saves = SplitBySemicolon(spellData.TooltipAttackSave, true)
        if #saves > 0 then
            for _, save in ipairs(saves) do
                if save:find("Attack") then
                    parent:AddText("Attack Roll ").SameLine = first
                else
                    parent:AddText(save .. " Save  ").SameLine = first
                end
                first = true
            end
        end
    end

    if spellData.Cooldown and spellData.Cooldown ~= "None" then
        parent:AddText("Cooldown: " .. spellData.Cooldown).SameLine = first
        first = true
    end

    if spellData["Memory Cost"] and spellData["Memory Cost"] ~= 0 then
        parent:AddText("Memory Cost: " .. spellData["Memory Cost"]).SameLine = first
        first = true
    end

    if spellData["Magic Cost"] and spellData["Magic Cost"] ~= 0 then
        parent:AddText("Magic Cost: " .. spellData["Magic Cost"]).SameLine = first
        first = true
    end

    local purpleTable = parent:AddTable("Spell Attributes", 1)
    local purpleRow = purpleTable:AddRow()
    local purpleCell = purpleRow:AddCell()
    purpleTable.RowBg = true
    purpleTable.Borders = true
    purpleTable:SetColor("TableRowBg", HexToRGBA("FF352B3F"))
    purpleTable:SetColor("TableBorderStrong", HexToRGBA("FF6A4C93"))

    if spellData.UseCosts and spellData.UseCosts ~= "" then
        local costs = SplitBySemicolon(spellData.UseCosts, true)
        if #costs > 0 then
            for i, cost in ipairs(costs) do
                if cost:sub(1, 15) == "SpellSlotsGroup" then
                    cost = " Level " .. TakeTail(cost, 1) .. " Spell Slot" 
                elseif cost:sub(1, 16) == "WarlockSpellSlot" then
                    cost = " Warlock Spell Slot"
                end

                purpleCell:AddText(cost .. " ").SameLine = i ~= 1
            end
        end
    end

    --parent:AddText("Spell type: " .. (spellData.SpellType or "Unknown"))

end

--- @param statsObj StatsObject
--- @param type any
--- @param nameOverride string|nil
--- @return fun(parent: ExtuiTreeParent, useTextLink: boolean): (ExtuiImageButton|ExtuiImage, ExtuiText|ExtuiTextLink)|fun()
function RenderStatsObject(statsObj, type, nameOverride)
    if not statsObj then
        return function() end
    end

    local icon = CheckIcon(statsObj.Icon or "Item_Unknown")
    
    local function render(parent, useTextLink)
        --- @type ExtuiImageButton
        local image = nil
        if useTextLink then
            image = parent:AddImage(icon, ToVec2(38 * SCALE_FACTOR))
        else
            image = parent:AddImageButton(Uuid_v4(), icon, ToVec2(38 * SCALE_FACTOR))
        end
        image:SetColor("Button", ToVec4(0))
        image.SameLine = true
        local popup = nil
        local name = nil
        local refEle = nil
        local displayName = nameOverride or GetLoca(statsObj.DisplayName) or "Unknown"
        if useTextLink then
            name = parent:AddTextLink(displayName)
            name.IDContext = Uuid_v4()
            refEle = name
        else
            name = parent:AddText(displayName)
            refEle = image
        end
        name.SameLine = true

        refEle.OnHoverEnter = function()
            local tooltip = refEle:Tooltip()
            RenderStatsObjectTitle(statsObj, tooltip, type, true)
            if type == "SpellData" then
                renderSpellAttrs(statsObj, tooltip)
            end
            refEle.OnHoverEnter = nil
        end

        refEle.OnClick = function()
            popup = parent:AddPopup((statsObj.DisplayName or "Spell") .. "##" .. Uuid_v4())
            RenderStatsObjectTitle(statsObj, popup, type)

            if type == "SpellData" then
                renderSpellAttrs(statsObj, popup)
            end

            popup:Open()
            
            refEle.OnClick = function ()
                popup:Open()
            end
        end

        return image, name
    end

    return render
end