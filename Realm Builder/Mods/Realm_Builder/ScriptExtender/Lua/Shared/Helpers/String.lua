RBStringUtils = RBStringUtils or {}

---@param desc string
---@return string, integer
function RBStringUtils.StripLSTags(desc)
    if not desc or desc == "" then return desc, 0 end
    return desc:gsub("%b<>", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

function RBStringUtils.EndsWith(str, pattern)
    if type(str) ~= "string" or type(pattern) ~= "string" then
        return false
    end
    return str:sub(-#pattern) == pattern
end

--- @param input string
--- @param trimWhitespace boolean?
--- @return string[]
function RBStringUtils.SplitBySemicolon(input, trimWhitespace)
    if type(input) ~= "string" then
        return {}
    end

    trimWhitespace = trimWhitespace ~= false
    local tokens = {}

    for token in input:gmatch("[^;]+") do
        if trimWhitespace then
            token = token:match("^%s*(.-)%s*$")
        end

        if token ~= "" then
            table.insert(tokens, token)
        end
    end

    return tokens
end

--- @param input string
--- @param trimWhitespace true
--- @return string[]
function RBStringUtils.SplitByComma(input, trimWhitespace)
    if type(input) ~= "string" then
        return {}
    end

    trimWhitespace = trimWhitespace ~= false
    local tokens = {}

    for token in input:gmatch("[^,]+") do
        if trimWhitespace then
            token = token:match("^%s*(.-)%s*$")
        end

        if token ~= "" then
            table.insert(tokens, token)
        end
    end

    return tokens
end

--- @param input string
--- @param separator string
--- @param trimWhitespace boolean?
--- @return string[]
function RBStringUtils.SplitByString(input, separator, trimWhitespace)
    if type(input) ~= "string" or type(separator) ~= "string" then
        return {}
    end

    trimWhitespace = trimWhitespace ~= false
    local tokens = {}
    local pattern = "([^" .. separator .. "]+)"

    for token in input:gmatch(pattern) do
        if trimWhitespace then
            token = token:match("^%s*(.-)%s*$")
        end

        if token ~= "" then
            table.insert(tokens, token)
        end
    end

    return tokens
end

--- @param input string
--- @return string[]
function RBStringUtils.SplitBySpace(input)
    if not input or type(input) ~= "string" then
        return {}
    end
    local result = {}

    input = input:match("^%s*(.-)%s*$")

    for word in input:gmatch("%S+") do
        table.insert(result, word)
    end

    return result
end

--- @param obj string
--- @param prefix string
--- @return boolean
function RBStringUtils.StartWith(obj, prefix)
    if type(obj) ~= "string" or type(prefix) ~= "string" then
        return false
    end
    return string.sub(obj, 1, #prefix) == prefix
end


function RBStringUtils.PadSuffix(str, len)
    local toPad = len - #str
    if toPad > 0 then
        return str .. string.rep(" ", toPad)
    end
    return str
end

function RBStringUtils.PadPrefix(str, len)
    local toPad = len - #str
    if toPad > 0 then
        return string.rep(" ", toPad) .. str
    end
    return str
end

--- @param obj string
--- @param count integer
--- @return string
function RBStringUtils.TrimTail(obj, count)
    if not obj or type(obj) ~= "string" then return obj end
    return string.sub(obj, 1, #obj - count)
end

--- @param obj string
--- @param count integer
--- @return string
function RBStringUtils.TakeTail(obj, count)
    return string.sub(obj, -count)
end

--- @param path string
--- @return string
function RBStringUtils.GetLastPath(path)
    return path:match("([^/]+)$") or path
end

--- @param obj string
--- @return string, integer
function RBStringUtils.ToLowerAlphaOnly(obj)
    return string.lower(obj):gsub("[^a-z]", "")
end

--- @param num number
--- @param size integer
--- @return string
function RBStringUtils.PadNumber(num, size)
    local s = tostring(num)
    return string.format("%0" .. size .. "d", tonumber(s))
end


---@param num number|string
---@param n integer
---@return number|nil
function RBStringUtils.FormatDecimal(num, n)
    local toFormat = tonumber(num)
    if toFormat == nil or n == nil then
        return nil
    end

    local multiplier = 10 ^ n
    return math.floor(toFormat * multiplier + 0.5) / multiplier
end

--- @param num number|string
--- @return string
function RBStringUtils.FormatThousand(num)
    local toFormat = tonumber(num)
    if not toFormat then
        return tostring(num)
    end
    local sign = ""
    if toFormat < 0 then
        sign = "-"
        toFormat = math.abs(toFormat)
    end
    local int, dec = tostring(toFormat):match("^(%d+)(%.%d+)?$")
    int = int or tostring(toFormat)
    dec = dec or ""
    local formatted = int:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if formatted:sub(1, 1) == "," then
        formatted = formatted:sub(2)
    end
    return sign .. formatted .. (dec or "")
end

---@param s string
---@param t string
---@param thereshold integer|nil
---@return integer
function RBStringUtils.Levenshtein(s, t, thereshold)
    local m, n = #s, #t
    if thereshold and math.abs(m - n) > thereshold then return math.huge end
    if m == 0 then return n end
    if n == 0 then return m end
    local prevRow, curRow = {}, {}
    for j = 0, n do prevRow[j] = j end
    for i = 1, m do
        curRow[0] = i
        for j = 1, n do
            local cost = (s:sub(i, i) == t:sub(j, j)) and 0 or 1
            curRow[j] = math.min(prevRow[j] + 1, curRow[j - 1] + 1, prevRow[j - 1] + cost)
            if thereshold and curRow[j] > thereshold then return math.huge end
        end
        prevRow, curRow = curRow, prevRow
    end
    return prevRow[n]
end

function RBStringUtils.GetPathBeforeData(fullPath)
    local dataIndex = string.find(fullPath, "Data\\")
    if dataIndex then
        return string.sub(fullPath, 1, dataIndex - 1)
    end
    return ""
end