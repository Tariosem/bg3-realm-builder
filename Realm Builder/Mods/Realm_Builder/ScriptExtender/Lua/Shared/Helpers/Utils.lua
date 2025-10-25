--- @return string
function Uuid_v4()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    local uuid = string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 15) or math.random(8, 11)
        return string.format('%x', v)
    end)
    return uuid
end

---@param str string?
---@return boolean
function IsUuid(str)
    if not str then return false end

    if type(str) ~= "string" then return false end

    if str == GUID_NULL then return false end

    return str:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

function ComputeVersion64(major, minor, revision, build)
    major = tonumber(major) or 0
    minor = tonumber(minor) or 0
    revision = tonumber(revision) or 0
    build = tonumber(build) or 0

    local version = major * 2^48 + minor * 2^32 + revision * 2^16 + build
    return string.format("%d", math.floor(tonumber(version) or 0))
end

function BuildVersionString(major, minor, revision, build)
    return string.format("%d.%d.%d.%d", major, minor, revision, build)
end

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

function SplitBySemicolon(str, trimWhitespace)
    if type(str) ~= "string" then
        return {}
    end
    
    trimWhitespace = trimWhitespace ~= false
    local tokens = {}
    
    for token in str:gmatch("[^;]+") do
        if trimWhitespace then
            token = token:match("^%s*(.-)%s*$")
        end
        
        if token ~= "" then
            table.insert(tokens, token)
        end
    end
    
    return tokens
end

function SplitByComma(str, trimWhitespace)
    if type(str) ~= "string" then
        return {}
    end
    
    trimWhitespace = trimWhitespace ~= false
    local tokens = {}
    
    for token in str:gmatch("[^,]+") do
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

function CountMap(map)
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
    local numbers = DeepCopy({...})
    if #numbers == 1 and type(numbers[1]) == "table" then
        numbers = numbers[1]
    end

    for i = 1, #numbers do
        numbers[i] = tonumber(numbers[i]) or 0
    end

    for i = #numbers + 1, 4 do
        numbers[i] = numbers[1]
    end

    return {numbers[1], numbers[2], numbers[3], numbers[4]}
end

--- @param ... any
--- @return number[]
function ToVec4Int(...)
    local numbers = DeepCopy({...})
    for i = 1, #numbers do
        if type(numbers[i]) ~= "number" then
            numbers[i] = tonumber(numbers[i]) or 0
        end
        numbers[i] = math.floor(numbers[i])
    end
    for i = #numbers + 1, 4 do
        numbers[i] = numbers[1]
    end
    return {numbers[1], numbers[2], numbers[3], numbers[4]}

end

function ToVec2(...)
    local numbers = DeepCopy({...})
    for i = 1, #numbers do
        if type(numbers[i]) ~= "number" then
            numbers[i] = tonumber(numbers[i]) or 0
        end
    end
    for i = #numbers + 1, 2 do
        numbers[i] = numbers[1]
    end
    return {numbers[1], numbers[2]}
end

function ToVec3(...)
    local numbers = DeepCopy({...})
    for i = 1, #numbers do
        if type(numbers[i]) ~= "number" then
            numbers[i] = tonumber(numbers[i]) or 0
        end
    end
    for i = #numbers + 1, 3 do
        numbers[i] = numbers[1]
    end
    return {numbers[1], numbers[2], numbers[3]}
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

function DeepCopy(original)
    if type(original) ~= 'table' then
        return original
    end

    local copy = {}
    for key, value in pairs(original) do
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

function TrimTail(str, count)
    return string.sub(str, 1, #str - count)
end

function TakeTail(str, count)
    return string.sub(str, -count)
end

function GetLastPath(path)
    return path:match("([^/]+)$") or path
end

function ToLowerAlphaOnly(str)
    return string.lower(str):gsub("[^a-z]", "")
end

function Contains(str, substr, caseSensitive)
    local isCaseSensitive = caseSensitive or false
    if type(str) ~= "string" or type(substr) ~= "string" then
        return false
    end
    if not isCaseSensitive then
        str = str:lower()
        substr = substr:lower()
    end
    return string.find(str, substr) ~= nil
end

function MapToSortedArrayByFunc(inputMap, comparator)
    local result = {}
    for k, v in pairs(inputMap) do
        table.insert(result, { Key = k, Value = v })
    end

    table.sort(result, comparator)

    return result
end

--- @param inputMap table
--- @param order any
--- @return table<number, {Key:any, Value:any}>
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
    if formatted:sub(1,1) == "," then
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
    for j=0,n do prevRow[j] = j end
    for i=1,m do
        curRow[0] = i
        for j=1,n do
            local cost = (s:sub(i,i) == t:sub(j,j)) and 0 or 1
            curRow[j] = math.min(prevRow[j]+1, curRow[j-1]+1, prevRow[j-1]+cost)
            if thereshold and curRow[j] > thereshold then return math.huge end
        end
        prevRow, curRow = curRow, prevRow
    end
    return prevRow[n]
end

--- @class RB_FilterOptions
--- @field CaseSensitive boolean?
--- @field Fuzzy boolean?
--- @field MatchAll boolean?
--- @field MinFuzzyLength integer?
--- @field FuzzyThreshold integer?

local function ValidateFilterOptions(opts)
    if type(opts) == "table" then
        opts.CaseSensitive = opts.CaseSensitive or false
        opts.Fuzzy = opts.Fuzzy or false
        opts.MatchAll = opts.MatchAll or false
        opts.MinFuzzyLength = opts.MinFuzzyLength or 3
        opts.FuzzyThreshold = opts.FuzzyThreshold or 12
        return opts
    end

    return {
        CaseSensitive = false,
        Fuzzy = false,
        MatchAll = false,
        MinFuzzyLength = 3,
        FuzzyThreshold = 12,
    }
end

-- God it's brutal out here
--- @param keywords string|table
--- @param items table
--- @param fields table
--- @param options RB_FilterOptions
--- @param candidates? any[]
--- @return table filteredCandidates
function Filter(keywords, items, fields, options, candidates)
    if not keywords or (type(keywords) ~= "string" and type(keywords) ~= "table") then
        return candidates or {}
    end
    local now = Ext.Timer.MonotonicTime()
    local words = type(keywords) == "string" and {keywords} or keywords --[[@as table]]
    local lower = not options.CaseSensitive

    if lower then
        for i, word in ipairs(words) do
            words[i] = word:lower()
        end
    end

    if not candidates then
        candidates = {}
        for k, _ in pairs(items) do
            candidates[k] = true
        end
    end

    options = ValidateFilterOptions(options)

    for candidate in pairs(candidates) do
        local entry = items[candidate]

        if entry then
            local matched = options.MatchAll and true or false
            for _, word in ipairs(words) do
                local wordToMatch = word
                local found = false
                for _, field in ipairs(fields) do
                    local val = entry[field]
                    if val then
                        local text = lower and val:lower() or val
                        if options.Fuzzy and #word >= options.MinFuzzyLength then
                            if Levenshtein(wordToMatch, text, options.FuzzyThreshold) <= options.FuzzyThreshold then
                                found = true
                                break
                            end
                        else
                            if string.find(text, wordToMatch, 1, true) then
                                found = true
                                break
                            end
                        end
                    end
                end
                if options.MatchAll and not found then
                    matched = false
                    break
                elseif not options.MatchAll and found then
                    matched = true
                    break
                end
            end
            if not matched then
                candidates[candidate] = nil
            end
        end
    end
    --Debug("Filter took " .. tostring(Ext.Timer.MonotonicTime() - now) .. " ms, found " .. CountMap(candidates) .. " results")
    return candidates
end

function IsCamera(str)
    if not str or type(str) ~= "string" then return false end
    return str == CameraSymbol or string.sub(str, 1, #CameraSymbol) == CameraSymbol
end

function GetCamaraUserID(str)
    if IsCamera(str) then
        return tonumber(string.sub(str, #CameraSymbol + 1))
    end
    return nil
end

--- Debounce utility function
---@param func fun(...:any)
---@param delay number ms
---@return function
function Debounce(delay, func)
    local lastCall = 0
    local timerId = nil

    return function(...)
        local args = {...}
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