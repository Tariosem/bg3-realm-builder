StatsParser = {}

local StatsHandler = Ext.Require("Client/UI/Components/StatsHandler.lua")

local StatsParameterHandler = StatsHandler.StatsParameterHandler
local StatsConditionHandlers = StatsHandler.StatsConditionHandlers
local StatsBoostHandlers = StatsHandler.StatsBoostHandlers

--- @class ParsedString
--- @field name string
--- @field args string[]|nil
--- @field condition string|nil
--- @field effect ParsedString|nil
--- @field effects ParsedString[]|nil

function StatsParser:ParseString(boostStr)
    local results = {}
    if not boostStr or boostStr == "" then
        return results
    end

    local function split(toSplit)
        local segments = {}
        local current = ""
        local depth = 0
        local i = 1

        if toSplit:find(";") then
            return SplitBySemicolon(toSplit, true)
        end

        while i <= #toSplit do
            local char = toSplit:sub(i, i)
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


    local sameCondition = {}
    for _, expr in ipairs(splitPass) do
        expr = expr:match("^%s*(.-)%s*$")

        if expr == "" then
            goto continue
        end

        local cond, inner = expr:match("^IF%s*%((.*)%)%s*:%s*(.+)$")
        if cond and inner then
            local effect = self:ParseString(inner)
            if not sameCondition[cond] then
                table.insert(results, {
                    name = "IF",
                    condition = cond,
                    effects = { table.unpack(effect) }
                })
                sameCondition[cond] = #results
            else
                local existing = results[sameCondition[cond]]
                table.insert(existing.effects, table.unpack(effect))
            end
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

        if handler then
            local parsedParam = handler(param)
            if parsedParam then
                --Debug("Storing handled param", param.name, "at index", nextIndex)
                parsed[nextIndex] = parsedParam
                nextIndex = nextIndex + 1
            end

            goto continue
        end

        --Warning("No handler for param", param.name)
        --Warning("Storing unknown param", param.name, "at index", nextIndex)
        --Info("Original params string:", descParams)
        parsed[nextIndex] = { { Text = param.name, Color = HIGHLIGHT_COLOR } }
        nextIndex = nextIndex + 1
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

        RenderTokenTexts(parent, wrappedTokens)
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
        local statsObj = Ext.Stats.Get(pass) --[[@as PassiveData]]
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

                local isHidden = table.find(statsObj.Properties, "IsHidden")
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