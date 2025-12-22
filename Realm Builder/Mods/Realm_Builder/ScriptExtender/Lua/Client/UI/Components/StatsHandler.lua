local levelMapUuidCache = {}

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

local function parseNumberText(numberStr)
    local levelMapValueTooltip = nil
    if numberStr:sub(1, #"LevelMapValue") == "LevelMapValue" then
        local statName = numberStr:match("LevelMapValue%((.-)%)")
        local rest = numberStr:sub(#("LevelMapValue(" .. statName .. ")") + 1)
        local lmvObj = nil --[[@as ResourceLevelMap?]]
        if levelMapUuidCache[statName] then
            lmvObj = Ext.StaticData.Get(levelMapUuidCache[statName], "LevelMap")
        else
            local allRes = Ext.StaticData.GetAll("LevelMap")
            for _, res in pairs(allRes) do
                local resObj = Ext.StaticData.Get(res, "LevelMap") --[[@as ResourceLevelMap]]
                levelMapUuidCache[resObj.Name] = res
                if resObj and resObj.Name == statName then
                    lmvObj = resObj
                end
            end
        end

        if lmvObj then
            levelMapValueTooltip = function(parent)
                local function formatVariant(variant)
                    local vtype = type(variant)
                    if vtype == "number" then
                        return tostring(variant)
                    elseif vtype == "userdata" then
                        return tostring(variant.AmountOfDices) .. tostring(variant.DiceValue)
                    else
                        return tostring(variant)
                    end
                end

                if lmvObj.FallbackValue then
                    local fallbackStr = formatVariant(lmvObj.FallbackValue)
                    parent:AddBulletText("Fallback Value: ")
                    local varStr = parent:AddText(fallbackStr)
                    varStr:SetColor("Text", UI_COLORS.HighLight)
                    varStr.SameLine = true
                end

                local mapTable = parent:AddTable("Level Map Values", 2)
                mapTable.ColumnDefs[1] = { WidthFixed = true }
                mapTable.ColumnDefs[2] = { WidthStretch = true }
                mapTable.RowBg = true
                mapTable.Borders = true
                local lasrVar = nil
                for i, variant in ipairs(lmvObj.LevelMaps or {}) do
                    local variantStr = formatVariant(variant)
                    if variantStr == lasrVar then
                        goto continue
                    else
                        lasrVar = variantStr
                    end

                    local row = mapTable:AddRow()
                    local levelCell = row:AddCell()
                    local valueCell = row:AddCell()
                    levelCell:AddText(string.format("Level %d ->", i)):SetColor("Text", { 1, 1, 1, 1 })
                    valueCell:AddText(variantStr):SetColor("Text", UI_COLORS.HighLight)
                    ::continue::
                end
            end
        end
        numberStr = GetLoca("<Progress with level>") .. rest
    end

    if numberStr:sub(1, 3) == "max" then
        numberStr = replaceMaxWithBestModifier(numberStr)
    end


    local token = { Text = numberStr, Tooltip = levelMapValueTooltip }

    return token
end

local function simpleRenderer(text, bonus)
    local bonusColor = bonus:sub(1, 1) == "-" and UI_COLORS.Warning or UI_COLORS.HighLight
    if tonumber(bonus) and tonumber(bonus) > 0 then
        bonus = "+" .. bonus
    end
    if text == "Movement" then
        bonus = bonus .. " meters"
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
    text = text or boost.name or "Unknown"
    bonus = bonus or boost.args[1] or "?"
    return simpleRenderer(text, bonus)
end

local function ablityBoostRenderer(boost)
    local ability = boost.args[1] or "Unknown"

    local bonus = boost.args[2] or "?"
    return simpleRenderer(ability, bonus)
end

--- @type table<string, fun(boost: ParsedString): fun(parent: ExtuiTreeParent): ExtuiBulletText>
local StatsBoostHandlers = {}
StatsBoostHandlers = {
    UnlockSpell = function(boost)
        local sd = Ext.Stats.Get(boost.args[1] or "") --[[@as SpellData]]
        local function render(parent)
            local bulletText = parent:AddBulletText(GetLoca("Unlock Spell : "))
            ImguiElements.RenderStatsObject(sd, "SpellData")(parent)
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
            if RB_GLOBALS.ItemManager then
                icon = RB_GLOBALS.ItemManager.tagIcons[prof]
            end
            local image = parent:AddImage(icon, RBUtils.ToVec2((iconSize or 32) * SCALE_FACTOR))
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

    Ability = function(boost)
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
                specificText:SetColor("Text", UI_COLORS.HighLight)
            else
                rollTypeText:SetColor("Text", UI_COLORS.HighLight)
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
                specificText:SetColor("Text", UI_COLORS.Warning)
            else
                rollTypeText:SetColor("Text", UI_COLORS.Warning)
            end

            return bulletText
        end
        return render
    end,

    Resistance = function(boost)
        local damageType = boost.args[1] or "Unknown"
        local damageTypeColor = DAMAGE_TYPE_COLORS[damageType] or nil
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
        local damageTypeColor = DAMAGE_TYPE_COLORS[damageType] or nil
        local function render(parent)
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
        local icon = RBCheckIcon(status and status.Icon or "Item_Unknown")

        local function render(parent)
            local bulletText = parent:AddBulletText("Immunity to status:")
            ImguiElements.RenderStatsObject(status, "StatusData")(parent)
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
        return simpleBoostRenderer(boost, "Jump max distance", (boost.args[1] or "?") .. " meters")
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
        local tagRes = GetStaticDataByName(tag)
        local icon = RBCheckIcon(tagRes and tagRes.Icon or "Item_Unknown")
        local displayName = tagRes and tagRes.DisplayName:Get() or tag
        displayName = RBStringUtils.StripLSTags(displayName)
        local description = tagRes and GetLoca(tagRes.Description) or ""
        local function render(parent, iconSize)
            local bulletText = parent:AddBulletText(string.format("Tag: %s", displayName))
            local image = nil
            if icon ~= "Item_Unknown" then
                image = parent:AddImage(icon, RBUtils.ToVec2((iconSize or 32) * SCALE_FACTOR))
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

        local function render(parent)
            local bulletText = parent:AddBulletText(string.format("Critical hit against %s %s %s", target, frequency,
                result))
            return bulletText
        end
        return render
    end,

    UnlockInterrupt = function(boost)
        local interrupt = boost.args[1] or "Unknown"
        local interruptStats = Ext.Stats.Get(interrupt) --[[@as InterruptData]]
        local function render(parent)
            local bulletText = parent:AddBulletText(string.format("Unlock reaction:"))
            ImguiElements.RenderStatsObject(interruptStats, "InterruptData")(parent)
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
            ImguiElements.RenderStatsObject(targetStats, "SpellData")(parent)
            local targetText = parent:AddText(" -> ")
            targetText.SameLine = true
            ImguiElements.RenderStatsObject(spellStats, "SpellData")(parent)
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
        if not boost.effects or #boost.effects == 0 then
            return function() end
        end

        local conditionTokens = StatsParser:ParseCondition(boost.condition or "Unknown")

        local wrpaedTokens = RBUtils.WrapTextTokens(conditionTokens, 60)

        local boostRenders = {}
        for _, effect in ipairs(boost.effects or {}) do
            _D(effect)
            local handler = StatsBoostHandlers[effect.name]
            if handler then
                local boostRender = handler(effect)
                if boostRender then
                    table.insert(boostRenders, boostRender)
                end
            else
                Warning("No handler for boost effect:", effect.name)
            end
        end

        --- @param parent ExtuiTreeParent
        local renderFunc = function(parent)
            local tab = parent:AddTable("Conditional Effect", 2)
            tab.BordersInnerV = true
            tab.BordersOuterH = true

            local row = tab:AddRow()

            local conditionCell = row:AddCell()
            local bulletText = conditionCell:AddBulletText("If ")
            ImguiElements.RenderTokenTexts(conditionCell, wrpaedTokens, true)

            if boost.Icon then
                local image = parent:AddImage(boost.Icon, RBUtils.ToVec2(32 * SCALE_FACTOR))
                image.SameLine = true
                if boost.Tooltip then
                    boost.Tooltip(image:Tooltip())
                end
            elseif boost.Tooltip then
                boost.Tooltip(bulletText:Tooltip())
            end

            local boostCell = row:AddCell()
            local conditionText = boostCell:AddText(GetLoca("Then :"))

            for _, boostRender in ipairs(boostRenders) do
                boostRender(boostCell)
            end
        end

        return renderFunc
    end,
}

--- @type table<string, fun(param: ParsedString): RB_TextToken[] >
local StatsParameterHandler = {}
StatsParameterHandler = {
    LevelMapValue = function(param)
        local statName = param.args[1] or "Unknown"
        local lmvObj = Ext.StaticData.GetAll("LevelMap")
        local foundObj = nil --[[@as ResourceLevelMap?]]
        for _, res in pairs(lmvObj) do
            local resObj = Ext.StaticData.Get(res, "LevelMap") --[[@as ResourceLevelMap]]
            if resObj and resObj.Name == statName then
                foundObj = resObj
                break
            end
        end

        local token = parseNumberText("LevelMapValue(" .. statName .. ")")
        token.Color = UI_COLORS.HighLight
        return {
            token
        }
    end,

    DealDamage = function(param)
        local damage = param.args[1] or ""
        local damageType = param.args[2] or nil


        local damageNumberToken = parseNumberText(damage)
        local damageColor = DAMAGE_TYPE_COLORS[damageType] or DAMAGE_TYPE_COLORS["Slashing"]
        damageNumberToken.Color = damageColor

        if damageType == "MainMeleeWeaponDamageType" then
            damageType = "main-hand melee"
        end

        local tokens = {
            damageNumberToken,
            { Text = string.format(" %s damage", damageType), Color = damageColor }
        }

        if not damageType then
            damageType = param.args[1] or ""
            damageColor = DAMAGE_TYPE_COLORS[damageType] or nil
            tokens = {
                { Text = string.format("%s damage", damageType), Color = damageColor }
            }
        end

        return tokens
    end,

    ApplyStatus = function(param)
        local statusName = param.args[1] or "Unknown"
        local status = Ext.Stats.Get(statusName) --[[@as StatusData]]
        local icon = RBCheckIcon(status and status.Icon or "Item_Unknown")
        return {
            { Text = "Applies status: " },
            { Text = GetLoca(status and status.DisplayName or statusName), Icon = icon, Tooltip = StatsParser:ParseDesc(status and status.Description or nil, nil, status and status.DescriptionParams) }
        }
    end,

    RegainHitPoints = function(param)
        local amount = param.args[1] or ""
        local numberToken = parseNumberText(amount)
        numberToken.Color = DAMAGE_TYPE_COLORS["HitPoint"]
        numberToken.Text = numberToken.Text .. " hit points"
        return {
            numberToken,
        }
    end,

    GainTemporaryHitPoints = function(param)
        local amount = param.args[1] or ""
        local numberToken = parseNumberText(amount)
        numberToken.Color = DAMAGE_TYPE_COLORS["HitPoint"]
        numberToken.Text = numberToken.Text .. " temporary hit points"
        return {
            numberToken,
        }
    end,

    TemporaryHP = function(param)
        local amount = param.args[1] or ""
        local numberToken = parseNumberText(amount)
        numberToken.Color = DAMAGE_TYPE_COLORS["HitPoint"]
        return {
            { Text = "Gain " },
            numberToken,
            { Text = " temporary hit points" }
        }
    end,

    Distance = function(param)
        local distance = param.args[1] or ""
        return {
            { Text = string.format("%s meters", distance), Color = UI_COLORS.HighLight }
        }
    end,

    StatusImmunity = function(param)
        local statusName = param.args[1] or "Unknown"
        local status = Ext.Stats.Get(statusName) --[[@as StatusData]]
        local icon = RBCheckIcon(status and status.Icon or "Item_Unknown")
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
                { Text = amount,                 Color = UI_COLORS.HighLight }
            }
        else
            return {
                { Text = string.format("Reduce %s damage by ", damageType) },
                { Text = amount,                                           Color = UI_COLORS.HighLight }
            }
        end
    end,

    ClassLevel = function(param)
        local className = param.args[1] or "Unknown"
        return {
            { Text = string.format("%s level", className), Color = UI_COLORS.HighLight }
        }
    end,

    WisdomModifier = function(param)
        return {
            { Text = "Wisdom modifier", Color = UI_COLORS.HighLight }
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
            { Text = baseText, Color = UI_COLORS.HighLight }
        }
    end,

    Cause = function(param)
        return {
            { Text = "cause", Color = UI_COLORS.HighLight }
        }
    end,

    ProficiencyBonus = function(param)
        return {
            { Text = "proficiency bonus", Color = UI_COLORS.HighLight }
        }
    end,

}

--- @type table<string, fun(args: string[]): RB_TextToken[] >
local StatsConditionHandlers = {}
StatsConditionHandlers = {
    HasPassive = function(args)
        local passiveName = args[1] or "Unknown"
        --- @type PassiveData?
        local passive = Ext.Stats.Get(passiveName)
        local icon = nil
        icon = RBCheckIcon(passive and passive.Icon)
        if icon == "Item_Unknown" then
            icon = nil
        end

        local tokens = {
            { Text = "Has passive: " },
            { Text = RBStringUtils.StripLSTags(GetLoca(passive and passive.DisplayName or args[1])), Icon = icon, TooltipRef = { Type = "PassiveData", Name = passiveName } }
        }

        return tokens
    end,
    Tagged = function(args)
        --- @type ResourceTag?
        local tagRes = GetStaticDataByName(args[1])
        local icon = nil
        icon = RBCheckIcon(tagRes and tagRes.Icon or "Item_Unknown")
        local displayName = RBStringUtils.StripLSTags(tagRes and tagRes.DisplayName:Get() or args[1])
        local description = RBStringUtils.StripLSTags(tagRes and GetLoca(tagRes.Description or "No description") or "")
        if icon == "Item_Unknown" then
            icon = nil
        end
        local tokens = {
            { Text = "Tagged: " },
            {
                Text = displayName,
                Icon = icon,
                Tooltip = function(parent)
                    parent:AddText(description)
                end
            }
        }

        return tokens
    end,
    CharacterLevelGreaterThan = function(args)
        local level = args[1] or "0"
        local tokens = {
            { Text = string.format("Character level greater than %s", level), Color = UI_COLORS.HighLight }
        }
        return tokens
    end,
    HasStatus = function(args)
        local statusName = args[1] or "Unknown"
        local status = Ext.Stats.Get(statusName) --[[@as StatusData]]
        local icon = RBCheckIcon(status and status.Icon or "Item_Unknown")
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
            { Text = string.format("%s level >= %s", className, level), Color = UI_COLORS.HighLight }
        }
        return tokens
    end,
    HasHPPercentageEqualOrLessThan = function(args)
        local percentage = args[1] or "0"
        local tokens = {
            { Text = string.format("HP percentage <= %s%%", percentage), Color = UI_COLORS.HighLight }
        }
        return tokens
    end,
    HasHPPercentageEqualOrMoreThan = function(args)
        local percentage = args[1] or "0"
        local tokens = {
            { Text = string.format("HP percentage >= %s%%", percentage), Color = UI_COLORS.HighLight }
        }
        return tokens
    end,
    HasHPPercentageWithoutTemporaryHPEqualOrLessThan = function(args)
        local percentage = args[1] or "0"
        local tokens = {
            { Text = string.format("HP percentage (without temp HP) <= %s%%", percentage), Color = UI_COLORS.HighLight }
        }
        return tokens
    end,
    HasAdvantage = function(args)
        return {
            { Text = "Has advantage", Color = UI_COLORS.HighLight }
        }
    end,
    HasDisadvantage = function(args)
        return {
            { Text = "Has disadvantage", Color = UI_COLORS.HighLight }
        }
    end,
    IsResistantToDamageType = function(args)
        local damageType = args[1] or "Unknown"
        local damageTypeColor = DAMAGE_TYPE_COLORS[damageType] or nil
        local tokens = {
            { Text = "Resistant to ",                        Color = damageTypeColor },
            { Text = string.format("%s damage", damageType), Color = damageTypeColor }
        }
        return tokens
    end,
    IsImmuneToDamageType = function(args)
        local damageType = args[1] or "Unknown"
        local damageTypeColor = DAMAGE_TYPE_COLORS[damageType] or nil
        local tokens = {
            { Text = "Immune to ",                           Color = damageTypeColor },
            { Text = string.format("%s damage", damageType), Color = damageTypeColor }
        }
        return tokens
    end,
    IsInSunlight = function(args)
        local tokens = {
            { Text = "In sunlight", Color = UI_COLORS.HighLight }
        }
        return tokens
    end,
    IsOffHandSlotEmpty = function(args)
        local tokens = {
            { Text = "Off-hand slot empty", Color = UI_COLORS.HighLight }
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
            { Text = string.format("Max HP (without temp HP)"), Color = UI_COLORS.HighLight }
        }
        return tokens
    end,
}

return {
    StatsBoostHandlers = StatsBoostHandlers,
    StatsParameterHandler = StatsParameterHandler,
    StatsConditionHandlers = StatsConditionHandlers,
}
