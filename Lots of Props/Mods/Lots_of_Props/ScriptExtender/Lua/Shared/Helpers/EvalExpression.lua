local exprFuncs = { 
    ["+"] = function(a,b) return a + b end,
    ["-"] = function(a,b) return a - b end,
    ["*"] = function(a,b) return a * b end,
    ["/"] = function(a,b) return a / b end,
    ["^"] = function(a,b) return a ^ b end,
    ["%"] = function(a,b) return a % b end,
}

local exprPriority = {
    ["+"] = 1, ["-"] = 1,
    ["*"] = 2, ["/"] = 2, ["%"] = 2,
    ["^"] = 3,
}

GLOBAL_AVAILABLE_OPERATORS = {
    ["+"] = true,
    ["-"] = true,
    ["*"] = true,
    ["/"] = true,
    ["^"] = true,
    ["%"] = true,
    ["("] = true,
    [")"] = true,
}

--- simple implementation of shunting-yard algorithm to evaluate basic math expressions
--- @param expr string
--- @return number|nil number, string|nil error
function EvalExpression(expr)
    expr = expr:gsub("([%+%-%*/%%%^%(%)])", " %1 ")

    local tokens = {}
    for token in expr:gmatch("%S+") do
        table.insert(tokens, token)
    end

    local outputQueue = {}
    local operatorStack = {}

    for i, token in ipairs(tokens) do
        local num = tonumber(token)
        if num then
            table.insert(outputQueue, num)
        elseif exprFuncs[token] then
            if token == "-" and (i == 1 or tokens[i-1] == "(" or exprFuncs[tokens[i-1]]) then
                table.insert(outputQueue, 0)
            end

            while #operatorStack > 0 do
                local top = operatorStack[#operatorStack]
                local topPri = exprPriority[top] or 0
                local thisPri = exprPriority[token] or 0
                if exprFuncs[top] and (
                    topPri > thisPri or
                    (topPri == thisPri and token ~= "^")
                ) then
                    table.insert(outputQueue, table.remove(operatorStack))
                else
                    break
                end
            end
            table.insert(operatorStack, token)
        elseif token == "(" then
            table.insert(operatorStack, token)
        elseif token == ")" then
            local foundLeft = false
            while #operatorStack > 0 do
                local top = table.remove(operatorStack)
                if top == "(" then
                    foundLeft = true
                    break
                else
                    table.insert(outputQueue, top)
                end
            end
            if not foundLeft then
                return nil, "Mismatched parentheses"
            end
        else
            return nil, "Invalid token: " .. token
        end
    end

    while #operatorStack > 0 do
        local top = table.remove(operatorStack)
        if top == "(" or top == ")" then
            return nil, "Mismatched parentheses"
        end
        table.insert(outputQueue, top)
    end

    local stack = {}
    for _, token in ipairs(outputQueue) do
        if type(token) == "number" then
            table.insert(stack, token)
        elseif exprFuncs[token] then
            if #stack < 2 then return nil, "Missing operands" end
            local b = table.remove(stack)
            local a = table.remove(stack)
            if token == "/" and b == 0 then return nil, "Division by zero" end
            table.insert(stack, exprFuncs[token](a, b))
        end
    end

    if #stack ~= 1 then
        return nil, "Invalid expression"
    end

    return stack[1]
end