StatsParser = {}

local HIGHLIGHT_COLOR = HexToRGBA("FFFED999")
local DEBUFF_COLOR = HexToRGBA("FFFF4C4C")
local BORDER_COLOR = HexToRGBA("FFFFA43C")

--- @class ParsedString
--- @field name string
--- @field args string[]|nil
--- @field condition string|nil
--- @field effect ParsedString|nil

function StatsParser:ParseString(boostStr)
    local results = {}
    if not boostStr or boostStr == "" then
        return results
    end

    local function split(str)
        local segments = {}
        local current = ""
        local depth = 0
        local i = 1

        if str:find(";") then
            return SplitBySemicolon(str, true)
        end

        while i <= #str do
            local char = str:sub(i, i)
            if char == "(" then
                depth = depth + 1
                current = current .. char
            elseif char == ")" then
                depth = depth - 1
                current = current .. char
            elseif char == "," and depth == 0 then
                local trimmed = current:match("^%s*(.-)%s*$")
                if trimmed ~= "" then
                    table.insert(segments, trimmed)
                end
                current = ""
            else
                current = current .. char
            end
            i = i + 1
        end
        
        local trimmed = current:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
            table.insert(segments, trimmed)
        end
        
        return segments
    end

    local splitPass = split(boostStr)

    for _, expr in ipairs(splitPass) do
        expr = expr:match("^%s*(.-)%s*$")

        if expr == "" then
            goto continue
        end

        local cond, inner = expr:match("^IF%s*%((.*)%)%s*:%s*(.+)$")
        if cond and inner then
            local effect = self:ParseString(inner)
            table.insert(results, {
                name = "IF",
                condition = cond,
                effect = effect[1]
            })
            goto continue
        end

        local func, args = expr:match("^([%w_]+)%s*%((.*)%)$")
        if func then
            local argList = {}
            if args and #args > 0 then
                local depth = 0
                local current = ""
                local i = 1
                while i <= #args do
                    local char = args:sub(i, i)
                    if char == "(" then
                        depth = depth + 1
                        current = current .. char
                    elseif char == ")" then
                        depth = depth - 1
                        current = current .. char
                    elseif char == "," and depth == 0 then
                        local trimmed = current:match("^%s*(.-)%s*$")
                        if trimmed ~= "" then
                            table.insert(argList, trimmed)
                        end
                        current = ""
                    else
                        current = current .. char
                    end
                    i = i + 1
                end
                local trimmed = current:match("^%s*(.-)%s*$")
                if trimmed ~= "" then
                    table.insert(argList, trimmed)
                end
            end
            table.insert(results, { name = func, args = argList })
            goto continue
        end

        local incompleteFunc = expr:match("^([%w_]+)%s*%(.*$")
        if incompleteFunc then
            --Warning("Incomplete boost function (missing closing parenthesis):", expr)
            local argsStart = expr:find("%(")
            if argsStart then
                local argsStr = expr:sub(argsStart + 1)
                local argList = {}
                if #argsStr > 0 then
                    for arg in argsStr:gmatch("[^,]+") do
                        local trimmed = arg:match("^%s*(.-)%s*$")
                        if trimmed ~= "" then
                            table.insert(argList, trimmed)
                        end
                    end
                end
                table.insert(results, { name = incompleteFunc, args = argList })
            else
                table.insert(results, { name = incompleteFunc, args = {} })
            end
            goto continue
        end

        table.insert(results, { name = expr, args = {} })
        --Debug("Unrecognized boost expression:", expr)

        ::continue::
    end
    
    return results
end



function StripLSTags(desc)
    if not desc or desc == "" then return desc end
    return desc:gsub("%b<>", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function ParseLSTextToTokens(input)
    local results = {}
    local lastPos = 1

    for preText, attrs, innerText, endPos in input:gmatch("(.-)<LSTag(.-)>(.-)</LSTag>()") do
        if preText and preText ~= "" then
            table.insert(results, { Text = preText })
        end

        local typeAttr = attrs:match('Type="(.-)"')
        local tooltip  = attrs:match('Tooltip="(.-)"')

        if typeAttr and tooltip and typeAttr ~= "ActionResource" then
            table.insert(results, { Text = innerText, TooltipRef = { Type = typeAttr .. "Data" , Name = tooltip } })
        elseif tooltip then
            table.insert(results, { Text = innerText, Color = HIGHLIGHT_COLOR })
        else
            table.insert(results, { Text = innerText })
        end

        lastPos = endPos
    end

    if lastPos <= #input then
        local remain = input:sub(lastPos)
        if remain ~= "" then
            table.insert(results, { Text = remain })
        end
    end

    for _, token in ipairs(results) do
        if token.Text then
            token.Text = StripLSTags(token.Text)
        end
    end

    return results
end

local function replaceMaxWithBestModifier(expr)
    local abilityMods = {
        StrengthModifier = true,
        DexterityModifier = true,
        ConstitutionModifier = true,
        IntelligenceModifier = true,
        WisdomModifier = true,
        CharismaModifier = true,
    }

    local inside = expr:match("^max%((.+)%)$")
    if not inside then
        return expr
    end

    local mods, count = {}, 0
    for mod in inside:gmatch("([^,]+)") do
        mod = mod:match("^%s*(.-)%s*$")
        mods[mod] = true
        count = count + 1
    end

    for m in pairs(mods) do
        if not abilityMods[m] then
            return expr
        end
    end

    if count >= 6 then
        return "Best Modifier"
    else
        return expr
    end
end

StatsParameterHandler = {
    DealDamage = function(param)
        local damage = param.args[1] or ""
        local damageType = param.args[2] or nil

        local damageColor = DAMAGE_TYPES_COLOR[damageType] or DAMAGE_TYPES_COLOR["Slashing"]
        
        if damage:sub(1, 3) == "max" then
            damage = replaceMaxWithBestModifier(damage)
        end

        local tokens = {
            { Text = string.format("%s", damage), Color = damageColor},
            { Text = string.format(" %s damage", damageType), Color = damageColor}
        }

        if not damageType then
            damageType = param.args[1] or ""
            damageColor = DAMAGE_TYPES_COLOR[damageType] or nil
            tokens = {
                { Text = string.format("%s damage", damageType), Color = damageColor }
            }
        end

        return tokens
    end,

    ApplyStatus = function(param)
        local statusName = param.args[1] or "Unknown"
        local status = Ext.Stats.Get(statusName) --[[@as StatusData]]
        local icon = CheckIcon(status and status.Icon or "Item_Unknown")
        return {
            { Text = "Applies status: " },
            { Text = GetLoca(status and status.DisplayName or statusName), Icon = icon, Tooltip = StatsParser:ParseDesc(status and status.Description or nil, nil, status and status.DescriptionParams)}
        }
    end,

    RegainHitPoints = function(param)
        local amount = param.args[1] or ""
        return {
            { Text = string.format("%s hit points", amount), Color = DAMAGE_TYPES_COLOR["HitPoint"] }
        }
    end,
    
    GainTemporaryHitPoints = function(param)
        local amount = param.args[1] or ""
        return {
            { Text = string.format("%s temporary hit points", amount), Color = DAMAGE_TYPES_COLOR["HitPoint"] }
        }
    end,

    TemporaryHP = function(param)
        local amount = param.args[1] or ""
        return {
            { Text = "Gain " },
            { Text = string.format("%s", amount), Color = DAMAGE_TYPES_COLOR["HitPoint"] },
            { Text = " temporary hit points" }
        }
    end,
    
    Distance = function(param)
        local distance = param.args[1] or ""
        return {
            { Text = string.format("%s meters", distance), Color = HIGHLIGHT_COLOR}
        }
    end,

    StatusImmunity = function(param)
        local statusName = param.args[1] or "Unknown"
        local status = Ext.Stats.Get(statusName) --[[@as StatusData]]
        local icon = CheckIcon(status and status.Icon or "Item_Unknown")
        return {
            { Text = "Immunity to status: " },
            { Text = GetLoca(status and status.DisplayName or statusName), Icon = icon, TooltipRef = { Type = "StatusData", Name = statusName } }
        }
    end,

    Disadvantage = function(param)
        local rollType = param.args[1] or "Unknown"
        local specific = param.args[2] or ""
        local text = specific ~= "" and string.format("Disadvantage on %s (%s)", rollType, specific) 
                                     or string.format("Disadvantage on %s", rollType)
        return {
            { Text = text }
        }
    end,

    SpellCastingAbilityModifier = function(param)
        return {
            { Text = "Spellcasting ability modifier" }
        }
    end,

    DamageReduction = function(param)
        local damageType = param.args[1] or "All"
        local reductionType = param.args[2] or "Flat"
        local amount = param.args[3] or "1"
        
        if damageType == "All" then
            return {
                { Text = "Reduce all damage by " },
                { Text = amount, Color = HIGHLIGHT_COLOR }
            }
        else
            return {
                { Text = string.format("Reduce %s damage by ", damageType) },
                { Text = amount, Color = HIGHLIGHT_COLOR }
            }
        end
    end,

    ClassLevel = function(param)
        local className = param.args[1] or "Unknown"
        return {
            { Text = string.format("%s level", className), Color = HIGHLIGHT_COLOR }
        }
    end,

    WisdomModifier = function(param)
        return {
            { Text = "Wisdom modifier", Color = HIGHLIGHT_COLOR }
        }
    end,

    MainMeleeWeaponDamageType = function(param)
        return {
            { Text = "main melee weapon damage type" }
        }
    end,

    max = function(param)
        local baseText = "max("

        for i, arg in ipairs(param.args or {}) do
            if i > 1 then
                baseText = baseText .. ", "
            end
            baseText = baseText .. arg
        end

        baseText = baseText .. ")"

        return {
            { Text = baseText, Color = HIGHLIGHT_COLOR }
        }
    end,

    Cause = function(param)
        return {
            { Text = "cause", Color = HIGHLIGHT_COLOR }
        }
    end,

    ProficiencyBonus = function(param)
        return {
            { Text = "proficiency bonus", Color = HIGHLIGHT_COLOR }
        }
    end,

}

StatsConditionHandlers = {
    HasPassive = function(args)
        local passiveName = args[1] or "Unknown"
        --- @type PassiveData?
        local passive = GetStatsObjByName(passiveName)
        local icon = nil
        icon = CheckIcon(passive and passive.Icon)
        if icon == "Item_Unknown" then
            icon = nil
        end

        local tokens = {
            { Text = "Has passive: " },
            { Text = StripLSTags(GetLoca(passive and passive.DisplayName or args[1])), Icon = icon, TooltipRef = { Type = "PassiveData", Name = passiveName } }
        }

        return tokens
    end,
    Tagged = function(args)
        --- @type ResourceTag?
        local tagRes = GetStatsObjByName(args[1])
        local icon = nil
        icon = CheckIcon(tagRes and tagRes.Icon or "Item_Unknown")
        local displayName = StripLSTags(tagRes and tagRes.DisplayName:Get() or args[1])
        local description = StripLSTags(tagRes and GetLoca(tagRes.Description or "No description") or "")
        if icon == "Item_Unknown" then
            icon = nil
        end
        local tokens = {
            { Text = "Tagged: " },
            { Text = displayName, Icon = icon, Tooltip = function(parent)
                parent:AddText(description)
            end }
        }

        return tokens
    end,
    CharacterLevelGreaterThan = function(args)
        local level = args[1] or "0"
        local tokens = {
            { Text = string.format("Character level greater than %s", level), Color = HIGHLIGHT_COLOR }
        }
        return tokens
    end,
    HasStatus = function(args)
        local statusName = args[1] or "Unknown"
        local status = Ext.Stats.Get(statusName) --[[@as StatusData]]
        local icon = CheckIcon(status and status.Icon or "Item_Unknown")
        local tokens = {
            { Text = "Has status: " },
            { Text = GetLoca(status and status.DisplayName or args[1]), Icon = icon, TooltipRef = { Type = "StatusData", Name = statusName } }
        }

        return tokens
    end,
    ClassLevelHigherOrEqualThan = function(args)
        local className = args[2] or "Unknown"
        local level = args[1] or "0"
        local tokens = {
            { Text = string.format("%s level >= %s", className, level), Color = HIGHLIGHT_COLOR }
        }
        return tokens
    end,
    HasHPPercentageEqualOrLessThan = function(args)
        local percentage = args[1] or "0"
        local tokens = {
            { Text = string.format("HP percentage <= %s%%", percentage), Color = HIGHLIGHT_COLOR }
        }
        return tokens
    end,
    HasHPPercentageEqualOrMoreThan = function(args)
        local percentage = args[1] or "0"
        local tokens = {
            { Text = string.format("HP percentage >= %s%%", percentage), Color = HIGHLIGHT_COLOR }
        }
        return tokens
    end,
    HasHPPercentageWithoutTemporaryHPEqualOrLessThan = function(args)
        local percentage = args[1] or "0"
        local tokens = {
            { Text = string.format("HP percentage (without temp HP) <= %s%%", percentage), Color = HIGHLIGHT_COLOR }
        }
        return tokens
    end,
    HasAdvantage = function(args)
        return {
            { Text = "Has advantage", Color = HIGHLIGHT_COLOR }
        }
    end,
    HasDisadvantage = function(args)
        return {
            { Text = "Has disadvantage", Color = HIGHLIGHT_COLOR }
        }
    end,
    IsResistantToDamageType = function(args)
        local damageType = args[1] or "Unknown"
        local damageTypeColor = DAMAGE_TYPES_COLOR[damageType] or nil
        local tokens = {
            { Text = "Resistant to ", Color = damageTypeColor },
            { Text = string.format("%s damage", damageType), Color = damageTypeColor }
        }
        return tokens
    end,
    IsImmuneToDamageType = function(args)
        local damageType = args[1] or "Unknown"
        local damageTypeColor = DAMAGE_TYPES_COLOR[damageType] or nil
        local tokens = {
            { Text = "Immune to ", Color = damageTypeColor },
            { Text = string.format("%s damage", damageType), Color = damageTypeColor }
        }
        return tokens
    end,
    IsInSunlight = function(args)
        local tokens = {
            { Text = "In sunlight", Color = HIGHLIGHT_COLOR }
        }
        return tokens
    end,
    IsOffHandSlotEmpty = function(args)
        local tokens = {
            { Text = "Off-hand slot empty", Color = HIGHLIGHT_COLOR }
        }
        return tokens
    end,
    GetItemInEquipmentSlot = function(args)
        local slot = args[1] or "Unknown"
        if slot:sub(1, 14) == "EquipmentSlot." then
            slot = slot:sub(#"EquipmentSlot." + 1)
        end
        local tokens = {
            { Text = string.format("Get slot %s", slot) }
        }
        return tokens
    end,
    HasMaxHPWithoutTemporaryHP = function(args)
        local amount = args[1] or "0"
        local tokens = {
            { Text = string.format("Max HP (without temp HP)"), Color = HIGHLIGHT_COLOR }
        }
        return tokens
    end,
}

local function injectParams(tokens, params, oriParams)
    local output = {}

    for _, token in ipairs(tokens) do
        local text = token.Text or ""

        local lastEnd = 1
        for startIdx, num, endIdx in text:gmatch("()%[([^%]]+)%]()") do
            if startIdx > lastEnd then
                table.insert(output, { Text = text:sub(lastEnd, startIdx-1) })
            end

            local paramIndex = tonumber(num)
            local paramTokens
            if paramIndex and paramIndex > 0 and paramIndex <= #params then
                paramTokens = params[paramIndex]
            else
                paramTokens = params[num]
            end

            if paramTokens then
                if type(paramTokens) == "table" and paramTokens[1] then
                    for _, t in ipairs(paramTokens) do
                        table.insert(output, t)
                    end
                else
                    table.insert(output, { Text = tostring(paramTokens) })
                end
            else
                table.insert(output, { Text = "["..num.."]" })
            end

            lastEnd = endIdx
        end

        if lastEnd <= #text then
            local remain = text:sub(lastEnd)
            if remain ~= "" then
                local tcopy = {}
                for k,v in pairs(token) do tcopy[k] = v end
                tcopy.Text = remain
                table.insert(output, tcopy)
            end
        end
    end

    return output
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
--- @return fun(parent: ExtuiTreeParent, useTextLink: boolean): (ExtuiImageButton|ExtuiImage, ExtuiText|ExtuiTextLink)|fun()
function RenderStatsObject(statsObj, type)
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
        if useTextLink then
            name = parent:AddTextLink(GetLoca(statsObj.DisplayName or "Unknown", "Unknown"))
            refEle = name
        else
            name = parent:AddText(GetLoca(statsObj.DisplayName or "Unknown", "Unknown"))
            refEle = image
        end
        name.SameLine = true


        local tooltipRendered = false
        refEle.OnHoverEnter = function()
            if not tooltipRendered then
                local tooltip = refEle:Tooltip()
                RenderStatsObjectTitle(statsObj, tooltip, type, true)
                tooltipRendered = true
                if type == "SpellData" then
                    renderSpellAttrs(statsObj, tooltip)
                end
            end
        end

        local popupRendered = false
        refEle.OnClick = function()
            if not popupRendered then
                popup = parent:AddPopup((statsObj.DisplayName or "Spell") .. "##" .. Uuid_v4())
                RenderStatsObjectTitle(statsObj, popup, type)
                popupRendered = true
                if type == "SpellData" then
                    renderSpellAttrs(statsObj, popup)
                end
            end

            popup:Open()
        end

        return image, name
    end

    return render
end

local function simpleRenderer(text, bonus)
    local bonusColor = bonus:sub(1,1) == "-" and DEBUFF_COLOR or HIGHLIGHT_COLOR
    if tonumber(bonus) and tonumber(bonus) > 0 then
        bonus = "+" .. bonus
    end
    if text == "Movement" then
        bonus = bonus .. "meters"
    end
    local function render(parent)
        local bulletText = parent:AddBulletText(string.format("%s", text))
        local numbertext = parent:AddText(bonus)
        numbertext.SameLine = true
        numbertext:SetColor("Text", bonusColor)
        return bulletText
    end
    return render
end

local function simpleBulletTextRender(text)
    local function render(parent)
        local bulletText = parent:AddBulletText(string.format("%s", text))
        return bulletText
    end
    return render
end

local function simpleBoostRenderer(boost, text, bonus)
    local text = text or boost.name or "Unknown"
    local bonus = bonus or boost.args[1] or "?"
    return simpleRenderer(text, bonus)
end

local function ablityBoostRenderer(boost)
    local ability = boost.args[1] or "Unknown"

    local bonus = boost.args[2] or "?"
    return simpleRenderer(ability, bonus)
end

StatsBoostHandlers = {}
StatsBoostHandlers = {
    UnlockSpell = function(boost)
        local sd = Ext.Stats.Get(boost.args[1] or "") --[[@as SpellData]]
        local function render(parent, iconSize)
            local bulletText = parent:AddBulletText(GetLoca("Unlock Spell : "))
            RenderStatsObject(sd, "SpellData")(parent)
            return bulletText
        end

        if not sd then
            return function() end
        else
            return render
        end
    end,

    Proficiency = function(boost)
        local prof = boost.args[1] or "Unknown"
        local function render(parent, iconSize)
            local bulletText = parent:AddBulletText(GetLoca("Gain Proficiency : "))
            local icon = "Item_Unknown"
            if LOP_ItemManager then
                icon = LOP_ItemManager.tagIcons[prof] 
            end
            local image = parent:AddImage(icon, ToVec2((iconSize or 32) * SCALE_FACTOR))
            image.SameLine = true
            local name = parent:AddText(GetLoca(prof))
            name.SameLine = true
            return bulletText
        end

        return render
    end,

    WeaponEnchantment = function(boost)
        return simpleBoostRenderer(boost, "Weapon Enchantment")
    end,

    WeaponProperty = function(boost)
        local property = boost.args[1] or "Unknown"
        local function render(parent, iconSize)
            local bulletText = parent:AddBulletText(string.format("Weapon Property: %s", property))
            return bulletText
        end
        return render
    end,

    Ability =  function(boost)
        return ablityBoostRenderer(boost)
    end,

    AC = function(boost)
        return simpleBoostRenderer(boost, "AC")
    end,

    Skill = function(boost)
        return ablityBoostRenderer(boost)
    end,
 
    RollBonus = function(boost)
       return ablityBoostRenderer(boost)
    end,

    Advantage = function(boost)
        local rollType = boost.args[1] or "Unknown"
        local specific = boost.args[2] or ""
        
        local function render(parent)
            local bulletText = parent:AddBulletText("")
            
            local advantageText = parent:AddText("Advantage")
            advantageText.SameLine = true

            parent:AddText(" on ").SameLine = true

            local rollTypeText = parent:AddText(rollType)
            rollTypeText.SameLine = true
            
            if specific ~= "" then
                local specificText = parent:AddText(specific)
                specificText.SameLine = true
                specificText:SetColor("Text", HIGHLIGHT_COLOR)
            else
                

                rollTypeText:SetColor("Text", HIGHLIGHT_COLOR)
            end

            return bulletText
        end
        return render
    end,

    Disadvantage = function(boost)
        local rollType = boost.args[1] or "Unknown"
        local specific = boost.args[2] or ""
        
        local function render(parent)
            local bulletText = parent:AddBulletText("")

            local disadvantageText = parent:AddText("Disadvantage")
            disadvantageText.SameLine = true

            parent:AddText(" on ").SameLine = true

            local rollTypeText = parent:AddText(rollType)
            rollTypeText.SameLine = true

            if specific ~= "" then
                local specificText = parent:AddText(specific)
                specificText.SameLine = true
                specificText:SetColor("Text", DEBUFF_COLOR)
            else
                
                rollTypeText:SetColor("Text", DEBUFF_COLOR)
            end
            
            return bulletText
        end
        return render
    end,

    Resistance = function(boost)
        local damageType = boost.args[1] or "Unknown"
        local damageTypeColor = DAMAGE_TYPES_COLOR[damageType] or nil
        local resistanceType = boost.args[2] or "Resistant"
        local function render(parent, iconSize)
            local bulletText = parent:AddBulletText(string.format("%s to ", resistanceType))
            local damageText = parent:AddText(string.format("%s damage", damageType))
            damageText.SameLine = true
            if damageTypeColor then
                damageText:SetColor("Text", damageTypeColor)
            end
            return bulletText
        end
        return render
    end,

    Initiative = function(boost)
        return simpleBoostRenderer(boost, "Initiative")
    end,

    WeaponDamage = function(boost)
        local damage = boost.args[1] or "1"
        local damageType = boost.args[2] or "Physical"
        local damageTypeColor = DAMAGE_TYPES_COLOR[damageType] or nil
        local function render(parent, iconSize)
            local bulletText = parent:AddBulletText("")
            local damageText = parent:AddText(string.format("+%s %s damage", damage, damageType))
            damageText.SameLine = true
            if damageTypeColor then
                damageText:SetColor("Text", damageTypeColor)
            end
            return bulletText
        end
        return render
    end,

    SpellSaveDC = function(boost)
        return simpleBoostRenderer(boost, "Spell Save DC")
    end,

    CannotBeDisarmed = function(boost)
        return simpleBulletTextRender("Cannot be disarmed")
    end,

    AbilityOverrideMinimum = function(boost)
        local ability = boost.args[1] or "Unknown"
        local minimum = boost.args[2] or "?"
        local function render(parent)
            local bulletText = parent:AddBulletText(string.format("%s increased to %s.", ability, minimum))
            return bulletText
        end
        return render
    end,

    ActionResource = function(boost)
        return ablityBoostRenderer(boost)
    end,

    CarryCapacityMultiplier = function(boost)
        return simpleBoostRenderer(boost, "Carry Capacity", "x" .. (boost.args[1] or "?"))
    end,

    StatusImmunity = function(boost)
        local statusName = boost.args[1] or "Unknown"
        local status = Ext.Stats.Get(statusName) --[[@as StatusData]]
        local icon = CheckIcon(status and status.Icon or "Item_Unknown")

        local function render(parent)
            local bulletText = parent:AddBulletText("Immunity to status:")
            RenderStatsObject(status, "StatusData")(parent)
            return bulletText
        end
        return render
    end,

    WeightCategory = function(boost)
        local modifier = boost.args[1] or "+0"
        local function render(parent, iconSize)
            local bulletText = parent:AddBulletText(string.format("Weight category %s", modifier))
            return bulletText
        end
        return render
    end,

    ScaleMultiplier = function(boost)
        return simpleBoostRenderer(boost, "Scale", "x" .. (boost.args[1] or "?"))
    end,

    JumpMaxDistanceBonus = function(boost)
        return simpleBoostRenderer(boost, "Jump max distance" , (boost.args[1] or "?") .. " meters")
    end,

    ProficiencyBonus = function(boost)
        local rollType = boost.args[1] or "Unknown"
        local ability = boost.args[2] or ""
        local text = ability ~= "" and string.format("Proficiency bonus to %s (%s)", rollType, ability) 
                                   or string.format("Proficiency bonus to %s", rollType)
        local function render(parent)
            local bulletText = parent:AddBulletText(text)
            return bulletText
        end
        return render
    end,

    Tag = function(boost)
        local tag = boost.args[1] or "Unknown"
        local tagRes = GetStatsObjByName(tag)
        local icon = CheckIcon(tagRes and tagRes.Icon or "Item_Unknown")
        local displayName = tagRes and tagRes.DisplayName:Get() or tag
        displayName = StripLSTags(displayName)
        local description = tagRes and GetLoca(tagRes.Description) or ""
        local function render(parent, iconSize)
            local bulletText = parent:AddBulletText(string.format("Tag: %s", displayName))
            local image = nil
            if icon ~= "Item_Unknown" then
                image = parent:AddImage(icon, ToVec2((iconSize or 32) * SCALE_FACTOR))
                image.SameLine = true
            end
            if description and description ~= "" then
                if image then
                    image:Tooltip():AddText(description)
                else
                    bulletText:Tooltip():AddText(description)
                end
            end
            return bulletText
        end
        return render
    end,

    CriticalHit = function(boost)
        local target = boost.args[1] or "Unknown"
        local result = boost.args[2] or "Unknown"
        local frequency = boost.args[3] or "Unknown"

        if target == "AttackTarget" then
            target = "Wearer"
        end

        local function render(parent, iconSize)
            local bulletText = parent:AddBulletText(string.format("Critical hit against %s %s %s", target, frequency, result))
            return bulletText
        end
        return render
    end,

    UnlockInterrupt = function(boost)
        local interrupt = boost.args[1] or "Unknown"
        local interruptStats = Ext.Stats.Get(interrupt) --[[@as InterruptData]]
        local function render(parent)
            local bulletText = parent:AddBulletText(string.format("Unlock reaction:"))
            RenderStatsObject(interruptStats, "InterruptData")(parent)
            return bulletText
        end
        return render
    end,

    AttackSpellOverride = function(boost)
        local spell = boost.args[1] or "Unknown"
        local target = boost.args[2] or "Unknown"
        local spellStats = Ext.Stats.Get(spell) --[[@as SpellData]]
        local targetStats = Ext.Stats.Get(target) --[[@as SpellData]]


        local function render(parent)
            local bulletText = parent:AddBulletText(string.format("Attack spell override: "))
            RenderStatsObject(targetStats, "SpellData")(parent)
            local targetText = parent:AddText(" -> ")
            targetText.SameLine = true
            RenderStatsObject(spellStats, "SpellData")(parent)
            return bulletText
        end
        return render
    end,

    WeaponAttackRollAbilityOverride = function(boost)
        local ability = boost.args[1] or "Unknown"
        local function render(parent)
            local bulletText = parent:AddBulletText(string.format("Use %s for weapon attacks", ability))
            return bulletText
        end
        return render
    end,

    HiddenDuringCinematic = function(boost)
        local function render(parent)
            local bulletText = parent:AddBulletText("Hidden during cinematics")
            return bulletText
        end
        return render
    end,

    ItemReturnToOwner = function(boost)
        return simpleBulletTextRender("Item returns to owner")
    end,

    IF = function(boost)
        if not boost.effect then
            return function() end 
        end

        local conditionTokens = StatsParser:ParseCondition(boost.condition or "Unknown")

        local wrpaedTokens = WrapTextTokens(conditionTokens, 60)

        local effectHandler = StatsBoostHandlers[boost.effect.name]
        if effectHandler then
            local boostRender = effectHandler(boost.effect)
            if boostRender then
                local renderFunc = function(parent)
                    local bulletText = parent:AddBulletText("If ")
                    RenderTokenTexts(parent, wrpaedTokens, true)
                    if boost.Icon then
                        local image = parent:AddImage(boost.Icon, ToVec2(32 * SCALE_FACTOR))
                        image.SameLine = true
                        if boost.Tooltip then
                            boost.Tooltip(image:Tooltip())
                        end
                    elseif boost.Tooltip then
                        boost.Tooltip(bulletText:Tooltip())
                    end

                    parent:AddDummy(20,5)
                    local conditionText = parent:AddText(GetLoca("Then :"))
                    conditionText.SameLine = true

                    local bullet = boostRender(parent)
                    if bullet then
                        bullet.SameLine = true
                    end

                end
                return renderFunc
            end
        end

        return function() end
    end,
}

function StatsParser:ParseParams(descParams)
    --Debug("ParseParams input:", descParams)
    
    local results = self:ParseString(descParams or "")
    --Debug("ParseString results count:", #results)
    
    for i, result in ipairs(results) do
        --Debug("Result", i, ":", result.name, "args:", result.args and table.concat(result.args, ",") or "none")
    end
    
    if #results == 0 then
        return { { { Text = descParams or "" } } }
    end

    local parsed = {}
    local nextIndex = 1

    for _, param in ipairs(results) do
        --Debug("Processing param:", param.name)
        
        local handler = StatsParameterHandler[param.name]
        local numValue = tonumber(param.name)
        
        if numValue then
            --Debug("Storing numeric param", param.name, "at index", numValue)
            parsed[nextIndex] = { { Text = param.name } }
            nextIndex = nextIndex + 1
            goto continue
        end

        if param.name:match("[%+%-%*/]") or param.name:match("Level") or param.name:match("Dex") or param.name:match("Str") then
            parsed[nextIndex] = { { Text = param.name, Color = HIGHLIGHT_COLOR } }
            nextIndex = nextIndex + 1
            goto continue
        end

        if param.name:match("^%d+%%$") then
            parsed[nextIndex] = { { Text = param.name, Color = HIGHLIGHT_COLOR } }
            nextIndex = nextIndex + 1
            goto continue
        end

        if param.name:match("^%d+d%d+$") then
            parsed[nextIndex] = { { Text = param.name, Color = HIGHLIGHT_COLOR } }
            nextIndex = nextIndex + 1
            goto continue
        end

        if param.name:match("^[%+%-]%d+$") then
            parsed[nextIndex] = { { Text = param.name, Color = HIGHLIGHT_COLOR } }
            nextIndex = nextIndex + 1
            goto continue
        end

        if param.name:match("^%d*%.%d+$") then
            parsed[nextIndex] = { { Text = param.name, Color = HIGHLIGHT_COLOR } }
            nextIndex = nextIndex + 1
            goto continue
        end

        if handler then
            local parsedParam = handler(param)
            if parsedParam then
                --Debug("Storing handled param", param.name, "at index", nextIndex)
                parsed[nextIndex] = parsedParam
                nextIndex = nextIndex + 1
            end
        else
            --Warning("No handler for param", param.name)
            --Warning("Storing unknown param", param.name, "at index", nextIndex)
            --Info("Original params string:", descParams)
            parsed[nextIndex] = { { Text = param.name } }
            nextIndex = nextIndex + 1
        end
        ::continue::
    end

    if #parsed == 0 then
        --Debug("No parsed parameters generated.")
        --Warning("No parameters could be parsed from:", descParams)
    else

    end

    return parsed, descParams
end

function StatsParser:ParseCondition(condStr)
    if not condStr or condStr == "" then
        return { { Text = "No condition" } }
    end

    local logicalOps = {
        AND = "AND",
        OR = "OR",
        NOT = "NOT"
    }

    local function tokenize(expr)
        local tokens = {}
        local i = 1
        local len = #expr

        while i <= len do
            local c = expr:sub(i, i)

            if c:match("%s") then
                i = i + 1
            elseif c == "(" or c == ")" or c == "," then
                table.insert(tokens, { Text = c })
                i = i + 1
            else
                local foundOp = false
                for op in pairs(logicalOps) do
                    if expr:sub(i, i + #op - 1):upper() == op then
                        table.insert(tokens, { Text = op:lower() })
                        i = i + #op
                        foundOp = true
                        break
                    end
                end
                
                if not foundOp then
                    local funcMatch = expr:match("^([%w_]+%b())", i)
                    if funcMatch then
                        local parsed = self:ParseString(funcMatch)
                        if #parsed > 0 then
                            local handler = StatsConditionHandlers[parsed[1].name]
                            if handler then
                                local conditionTokens = handler(parsed[1].args or {})
                                for _, t in ipairs(conditionTokens) do
                                    table.insert(tokens, t)
                                end
                            else
                                Warning("No handler for condition:", parsed[1].name)
                                table.insert(tokens, { Text = funcMatch })
                            end
                        else
                            table.insert(tokens, { Text = funcMatch })
                        end
                        i = i + #funcMatch
                    else
                        local word = expr:match("^%w+", i)
                        if word then
                            table.insert(tokens, { Text = word })
                            i = i + #word
                        else
                            table.insert(tokens, { Text = c })
                            i = i + 1
                        end
                    end
                end
            end
        end

        return tokens
    end

    return tokenize(condStr)
end

--- @param desc any
--- @param descRef any
--- @param descParams any
--- @param depth integer?
--- @param isTooltip boolean?
--- @return function 
function StatsParser:ParseDesc(desc, descRef, descParams, depth, isTooltip)
    depth = depth or 1
    if not desc or desc == "" then
        return function() end
    end

    local maxDepth = 11

    --- for sanity 
    if depth >= maxDepth then
        return function(parent)
            parent:AddText("Description overflow")
        end
    end

    local description = ParseLSTextToTokens(GetLoca(desc))

    local params, ori = self:ParseParams(descParams)

    local tokens = injectParams(description, params, ori)

    local function render(parent, wrapPos)
        parent:SetStyle("WindowBorderSize", 2)
        parent:SetColor("Border", HexToRGBA("FFC69800"))
        local wrappedTokens = WrapTextTokens(tokens, wrapPos or 60)

        for _, token in ipairs(wrappedTokens) do
            if token.Icon then
                local icon = token.Icon
                local image = parent:AddImage(icon, ToVec2((token.IconSize or 16) * SCALE_FACTOR))
                image.SameLine = true
            end

            local t = nil
            local image = nil

            if token.TooltipRef then
                
                local statsObj, statsType = GetStatsObjByName(token.TooltipRef.Name)
                
                if CheckIcon(statsObj and statsObj.Icon) ~= "Item_Unknown" then
                    image = parent:AddImage(statsObj.Icon, ToVec2(48 * SCALE_FACTOR))
                end
                t = parent:AddTextLink((token.Text or "") .. "##" .. Uuid_v4())

                

                if statsObj and not isTooltip then
                    local desc = statsObj.Description
                    local descParam = statsType ~= "Tag" and statsObj.DescriptionParams or nil

                    local tooltipRendered = false
                    
                    t.OnHoverEnter = function()
                        if tooltipRendered then
                            return
                        end
                        tooltipRendered = true
                        RenderStatsObjectTitle(statsObj, t:Tooltip(), statsType, true)

                        if statsType == "SpellData" then
                            renderSpellAttrs(statsObj, t:Tooltip())
                        end
                    end

                    if depth < maxDepth - 2 then
                        
                        local popupRendered = false
                        local descPopup = nil

                        t.OnClick = function()
                            if not popupRendered then
                                popupRendered = true
                                descPopup = parent:AddPopup((token.TooltipRef.Name or "Tooltip") .. "##" .. Uuid_v4())
                                RenderStatsObjectTitle(statsObj, descPopup, statsType)

                                if statsType == "SpellData" then
                                    renderSpellAttrs(statsObj, descPopup)
                                end
                            end

                            descPopup:Open()
                        end

                    end
                else
                    t:Tooltip():AddText(""..(token.TooltipRef.Name or ""))
                end

            else
                t = parent:AddText(token.Text or "")
            end

            if token.Color then
                t:SetColor("Text", token.Color)
            end

            if token.Font then
                t.Font = token.Font
            end

            if image then
                image.SameLine = token.SameLine
                t.SameLine = true
            else
                t.SameLine = token.SameLine
            end
        end

    end

    return render
end

local seenBoosts = {}
--- @param Boosts string
function StatsParser:ParseBoosts(Boosts)
    local raw = Boosts or ""

    if not raw or raw == "" then
        return nil
    end

    local parsed = self:ParseString(raw)
    local boosts = {}
    for _, boost in ipairs(parsed) do
        local handler = StatsBoostHandlers[boost.name]
        if handler then
            local boostEntry = handler(boost)
            if boostEntry then
                table.insert(boosts, boostEntry)
            end
            seenBoosts[boost.name] = true
        else
            if not seenBoosts[boost.name] then
                --PrintDivider()
                seenBoosts[boost.name] = true
                --Warning("No handler for boost", boost.name)
                if boost.args and #boost.args > 0 then
                    Warning("With args:", table.concat(boost.args, ", "))
                end
                if boost.condition then
                    Warning("With condition:", boost.condition)
                    Warning("Effect:", boost.effect and boost.effect.name or "nil")
                    Warning("Effect args:", boost.effect and boost.effect.args and table.concat(boost.effect.args, ", ") or "nil")
                end
            end

            local function genericRender(parent)
                parent:AddBulletText(boost.name .. (boost.args and #boost.args > 0 and ("(" .. table.concat(boost.args, ", ") .. ")") or ""))
            end
            
            table.insert(boosts, genericRender)

        end
    end

    if next(boosts) == nil then
        return nil
    end

    return boosts
end

--- @param passives string
function StatsParser:ParsePassives(passives)
    local allRenders = {}

    local splitPass = SplitBySemicolon(passives or "")
    for _, pass in ipairs(splitPass) do
        local statsObj = GetStatsObjByName(pass) --[[@as PassiveData]]
        if statsObj then
            local desc = statsObj.Description
            local descRef = statsObj.DescriptionRef
            local descParams = statsObj.DescriptionParams
            local icon = CheckIcon(statsObj.Icon or "Item_Unknown")

            local renderDesc = self:ParseDesc(desc, descRef, descParams)
            local function render(parent)
                local bulletText = parent:AddBulletText("")
                if icon ~= "Item_Unknown" then
                    local image = parent:AddImage(icon, ToVec2(48 * SCALE_FACTOR))
                    image.SameLine = true
                else
                end
                local name = parent:AddText(StripLSTags(GetLoca(statsObj.DisplayName, pass)))
                name.SameLine = true
                name:SetColor("Text", HexToRGBA("FFFFD06A"))

                local isHidden = TableContains(statsObj.Properties, "IsHidden")
                if isHidden then
                    local hiddenText = parent:AddText(" (Hidden)")
                    name:SetColor("Text", HexToRGBA("FF888888"))
                    hiddenText:SetColor("Text", HexToRGBA("FF888888"))
                    hiddenText.SameLine = true
                end

                --- @type ExtuiTable
                local paraTable = parent:AddTable("ParaTable##"..pass, 2)
                paraTable.ColumnDefs[1] = { Width = 60 * SCALE_FACTOR , FixedWidth = true }
                paraTable.ColumnDefs[2] = { WidthStretch = true }
                local paraRow = paraTable:AddRow()
                local leftCell = paraRow:AddCell()
                local rightCell = paraRow:AddCell()

                renderDesc(rightCell)
            end
            table.insert(allRenders, render)
        else
            local function render(parent, wrapPos)
                local bulletText = parent:AddBulletText("")
                local name = parent:AddText(pass)
                name.SameLine = true
            end

            table.insert(allRenders, render)
        end
    end

    if #allRenders == 0 then
        return nil
    end

    return allRenders
end