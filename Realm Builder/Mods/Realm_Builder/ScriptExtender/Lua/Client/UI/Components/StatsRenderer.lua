--- @class RB_TextToken
--- @field Text string
--- @field Color vec4|nil
--- @field Font string|nil
--- @field Style table<string, any>|nil
--- @field Icon string|nil
--- @field TooltipRef {Name: string, Type: string}|nil -- Stat object reference
--- @field Tooltip fun(tooltip: ExtuiTooltip)|nil a function that adds tooltip content



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

        local statImage = nil
        if token.TooltipRef and statsObj then
            local statsObjRenderfunc = RenderStatsObject(statsObj, statsType)
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

        if statImage then
            statImage.SameLine = token.SameLine == true
            label.SameLine = true
        else
            label.SameLine = token.SameLine == true
        end
        
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
