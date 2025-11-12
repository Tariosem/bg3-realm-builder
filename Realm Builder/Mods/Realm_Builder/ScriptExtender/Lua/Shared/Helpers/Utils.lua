--- @return string
function Uuid_v4()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    local uuid = string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 15) or math.random(8, 11)
        return string.format('%x', v)
    end)
    return uuid
end

---@param object string?
---@return boolean
function IsUuid(object)
    if not object then return false end

    if type(object) ~= "string" then return false end

    if object == GUID_NULL then return false end

    return object:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

---@param major string|number
---@param minor string|number
---@param revision string|number
---@param build string|number
---@return string
function ComputeVersion64(major, minor, revision, build)
    major = tonumber(major) or 0
    minor = tonumber(minor) or 0
    revision = tonumber(revision) or 0
    build = tonumber(build) or 0

    local version = (major & 0xFF) << 55
        | (minor & 0xFF) << 47
        | (revision & 0xFFFF) << 31
        | (build & 0x7FFFFFFF)

    return string.format("%d", version)
end

---@param version64 string|number
---@return number major
---@return number minor
---@return number revision
---@return number build
function ParseVersion64(version64)
    local versionNum = tonumber(version64) or 0
    local major = (versionNum >> 55) & 0xFF
    local minor = (versionNum >> 47) & 0xFF
    local revision = (versionNum >> 31) & 0xFFFF
    local build = versionNum & 0x7FFFFFFF

    return major, minor, revision, build
end

---@param major string|number
---@param minor string|number
---@param revision string|number
---@param build string|number
---@return string
function BuildVersionString(major, minor, revision, build)
    major = tonumber(major) or 0
    minor = tonumber(minor) or 0
    revision = tonumber(revision) or 0
    build = tonumber(build) or 0

    return string.format("%d.%d.%d.%d", major, minor, revision, build)
end

---@param versionStr string
---@return number major
---@return number minor
---@return number revision
---@return number build
function ParseVersionString(versionStr)
    local major, minor, revision, build = versionStr:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    return tonumber(major) or 0, tonumber(minor) or 0, tonumber(revision) or 0, tonumber(build) or 0
end

function StripLSTags(desc)
    if not desc or desc == "" then return desc end
    return desc:gsub("%b<>", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

---@param t table
---@return boolean
function IsArray(t)
    if type(t) ~= "table" then
        return false
    end
    local count = 0
    for k, _ in pairs(t) do
        if type(k) ~= "number" then
            return false
        end
        count = count + 1
    end
    for i = 1, count do
        if t[i] == nil then
            return false
        end
    end
    return true
end

function IsValidName(name)
    -- simple check: no special characters
    if name:match("[^%w_%s%-]") then
        return false
    end
    if name == "" then
        return false
    end
    return true
end

---@param name any
---@return string|'Unnamed'
function ValidateFolderName(name)
    if type(name) ~= "string" then
        return "Unnamed"
    end

    local safe = name:gsub('[\\/:*?"<>|]', "")
    safe = safe:match("^%s*(.-)%s*$")
    if safe == "" then
        return "Unnamed"
    end

    safe = safe:gsub("%s+", "_")
    return safe
end

function TableMerge(dest, src)
    for k, v in pairs(src) do
        dest[k] = v
    end
end

function TableContains(tbl, value)
    if type(tbl) ~= "table" then
        tbl = LightCToArray(tbl)
    end

    if type(tbl) ~= "table" then
        return false
    end

    if tbl[value] then
        return true
    end

    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function MergeArrays(arr1, arr2)
    for _, v in ipairs(arr2) do
        table.insert(arr1, v)
    end
    return arr1
end

function SplitBySemicolon(input, trimWhitespace)
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
function SplitByComma(input, trimWhitespace)
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
function SplitByString(input, separator, trimWhitespace)
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

function SplitBySpace(input)
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

function StartWith(obj, prefix)
    if type(obj) ~= "string" or type(prefix) ~= "string" then
        return false
    end
    return string.sub(obj, 1, #prefix) == prefix
end

function CountMap(map)
    map = map or {}
    local count = 0
    for _, _ in pairs(map) do
        count = count + 1
    end
    return count
end

function ArrayReverse(arr)
    local result = {}
    for i = #arr, 1, -1 do
        table.insert(result, arr[i])
    end
    return result
end

function EqualArrays(arr1, arr2)
    if #arr1 ~= #arr2 then
        return false
    end
    for i = 1, #arr1 do
        if arr1[i] ~= arr2[i] then
            return false
        end
    end
    return true
end

---@param ... any
---@return number[]
function ToVec4(...)
    local numbers = DeepCopy({ ... })
    if #numbers == 1 and type(numbers[1]) == "table" then
        numbers = numbers[1]
    end

    for i = 1, #numbers do
        numbers[i] = tonumber(numbers[i]) or 0
    end

    for i = #numbers + 1, 4 do
        numbers[i] = numbers[1]
    end

    return { numbers[1], numbers[2], numbers[3], numbers[4] }
end

--- @param ... any
--- @return number[]
function ToVec4Int(...)
    local numbers = DeepCopy({ ... })
    for i = 1, #numbers do
        if type(numbers[i]) ~= "number" then
            numbers[i] = tonumber(numbers[i]) or 0
        end
        numbers[i] = math.floor(numbers[i])
    end
    for i = #numbers + 1, 4 do
        numbers[i] = numbers[1]
    end
    return { numbers[1], numbers[2], numbers[3], numbers[4] }
end

function ToVec2(...)
    local numbers = DeepCopy({ ... })
    for i = 1, #numbers do
        if type(numbers[i]) ~= "number" then
            numbers[i] = tonumber(numbers[i]) or 0
        end
    end
    for i = #numbers + 1, 2 do
        numbers[i] = numbers[1]
    end
    return { numbers[1], numbers[2] }
end

function ToVec3(...)
    local numbers = DeepCopy({ ... })
    for i = 1, #numbers do
        if type(numbers[i]) ~= "number" then
            numbers[i] = tonumber(numbers[i]) or 0
        end
    end
    for i = #numbers + 1, 3 do
        numbers[i] = numbers[1]
    end
    return { numbers[1], numbers[2], numbers[3] }
end

function LightCToArray(arr)
    if arr == nil then
        return {}
    end

    local result = {}
    for _, v in ipairs(arr) do
        table.insert(result, v)
    end
    return result
end

--- @generic T
--- @param o T
--- @return T
function DeepCopy(o)
    if type(o) ~= 'table' then
        return o
    end

    local copy = {}
    for key, value in pairs(o) do
        copy[key] = DeepCopy(value)
    end

    return copy
end

function ToggleEntry(tbl, value)
    if type(tbl) ~= "table" then
        return false
    end
    for i, v in ipairs(tbl) do
        if v == value then
            table.remove(tbl, i)
            return false
        end
    end
    table.insert(tbl, value)
    return true
end

function RequireFiles(folderPath, files)
    if type(folderPath) ~= "string" then
        _P("RequireFiles: folderPath must be a string")
    end
    for _, filename in ipairs(files) do
        if type(filename) ~= "string" then
            _P("RequireFiles: file names must be strings")
        end

        local path = folderPath .. filename .. ".lua"

        local ok, res = pcall(Ext.Require, path)
        if not ok then
            _P("RequireFiles", "Failed to load " .. path .. ": " .. tostring(res))
        end
    end
end

function TrimTail(obj, count)
    if not obj or type(obj) ~= "string" then return obj end
    return string.sub(obj, 1, #obj - count)
end

function TakeTail(obj, count)
    return string.sub(obj, -count)
end

function GetLastPath(path)
    return path:match("([^/]+)$") or path
end

function ToLowerAlphaOnly(obj)
    return string.lower(obj):gsub("[^a-z]", "")
end

function PadNumber(num, size)
    local s = tostring(num)
    return string.format("%0" .. size .. "d", tonumber(s))
end

function Contains(obj, substr, caseSensitive)
    local isCaseSensitive = caseSensitive or false
    if type(obj) ~= "string" or type(substr) ~= "string" then
        return false
    end
    if not isCaseSensitive then
        obj = obj:lower()
        substr = substr:lower()
    end
    return string.find(obj, substr) ~= nil
end

--- @generic K, V
--- @param inputMap table<K, V>
--- @param comparator fun(a: {Key:K,Value:V}, b: {Key:K,Value:V}): boolean
--- @return table<{Key:K,Value:V}>
function MapToSortedArrayByFunc(inputMap, comparator)
    local result = {}
    for k, v in pairs(inputMap) do
        table.insert(result, { Key = k, Value = v })
    end

    table.sort(result, comparator)

    return result
end

--- @generic K, V
--- @param inputMap table<K, V>
--- @param order "asc"|"desc"
--- @return table<{Key:K,Value:V}>
function MapToSortedArrayByKey(inputMap, order)
    local result = {}
    for k, v in pairs(inputMap) do
        table.insert(result, { Key = k, Value = v })
    end

    table.sort(result, function(a, b)
        if order == "desc" then
            return a.Key > b.Key
        else
            return a.Key < b.Key
        end
    end)

    return result
end

--- @generic K, V
--- @param tbl table<K, V>
--- @param func? fun(a:K, b:K):boolean
--- @return fun(): (K, V)
function SortedPairs(tbl, func)
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end

    table.sort(keys, function(a, b)
        if func then
            return func(a, b) and true or false
        else
            return a < b
        end
    end)

    local i = 0
    return function()
        i = i + 1
        local key = keys[i]
        if key then
            return key, tbl[key]
        end
    end
end

--- @generic K, V
--- @param tbl table<K, V>
--- @param filterFunc fun(a:K, b:V):boolean
--- @param sortFunc? fun(a:K, b:K):boolean
--- @return fun(): (K, V)
function FilteredPairs(tbl, filterFunc, sortFunc)
    local keys = {}
    for k in pairs(tbl) do
        if filterFunc(k, tbl[k]) then
            table.insert(keys, k)
        end
    end

    table.sort(keys, function(a, b)
        if sortFunc then
            return sortFunc(a, b) and true or false
        else
            return a < b
        end
    end)

    local i = 0
    return function()
        i = i + 1
        local key = keys[i]
        if key then
            return key, tbl[key]
        end
    end
end

---@param num number|string
---@param n integer
---@return number|nil
function FormatDecimal(num, n)
    local toFormat = tonumber(num)
    if toFormat == nil or n == nil then
        return nil
    end

    local multiplier = 10 ^ n
    return math.floor(toFormat * multiplier + 0.5) / multiplier
end

--- @param num number|string
--- @return string
function FormatThousand(num)
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
function Levenshtein(s, t, thereshold)
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

function IsCamera(object)
    if not object or type(object) ~= "string" then return false end
    return object == CameraSymbol or string.sub(object, 1, #CameraSymbol) == CameraSymbol
end

function GetCamaraUserID(obj)
    if IsCamera(obj) then
        return tonumber(string.sub(obj, #CameraSymbol + 1))
    end
    return nil
end

---@param func fun(...:any)
---@param delay number ms
---@return function
function Debounce(delay, func)
    local lastCall = 0
    local timerId = nil

    return function(...)
        local args = { ... }
        local now = Ext.Timer.MonotonicTime()

        if timerId then
            Ext.Timer.Cancel(timerId)
        end

        timerId = Ext.Timer.WaitForRealtime(delay, function()
            func(table.unpack(args))
            timerId = nil
        end)
    end
end
