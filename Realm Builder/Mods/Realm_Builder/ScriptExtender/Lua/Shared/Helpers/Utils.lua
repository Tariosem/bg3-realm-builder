RBUtils = RBUtils or {}

--- @return string
function RBUtils.Uuid_v4()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    local uuid = string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 15) or math.random(8, 11)
        return string.format('%x', v)
    end)
    return uuid
end


---@param object string?
---@return boolean
function RBUtils.IsUuid(object)
    if not object then return false end

    if type(object) ~= "string" then return false end

    if object == GUID_NULL then return false end

    return object:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

function RBUtils.IsUuidIncludingNull(object)
    if not object then return false end

    if type(object) ~= "string" then return false end

    return object:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

---@param major string|number
---@param minor string|number
---@param revision string|number
---@param build string|number
---@return string
function RBUtils.ComputeVersion64(major, minor, revision, build)
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
function RBUtils.ParseVersion64(version64)
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
function RBUtils.BuildVersionString(major, minor, revision, build)
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
function RBUtils.ParseVersionString(versionStr)
    local major, minor, revision, build = versionStr:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    return tonumber(major) or 0, tonumber(minor) or 0, tonumber(revision) or 0, tonumber(build) or 0
end

---@param name any
---@return boolean
function RBUtils.IsValidFolderName(name)
    if type(name) ~= "string" then
        return false
    end

    local safe = name:gsub('[\\/:*?"<>|]', "")
    safe = safe:match("^%s*(.-)%s*$")
    if safe == "" then
        return false
    end

    return true
end

---@param name any
---@return string|'Unnamed'
function RBUtils.ValidateFolderName(name)
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


---@param ... any
---@return number[]
function RBUtils.ToVec4(...)
    local numbers = RBUtils.DeepCopy({ ... })
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
function RBUtils.ToVec4Int(...)
    local numbers = RBUtils.DeepCopy({ ... })
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

function RBUtils.ToVec2(...)
    local numbers = RBUtils.DeepCopy({ ... })
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

function RBUtils.ToVec3(...)
    local numbers = RBUtils.DeepCopy({ ... })
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

function RBUtils.LightCToArray(arr)
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
function RBUtils.DeepCopy(o)
    if type(o) ~= 'table' and type(o) ~= 'userdata' then
        return o
    end

    local copy = {}
    for key, value in pairs(o) do
        copy[key] = RBUtils.DeepCopy(value)
    end

    return copy
end

function RBUtils.IsSerializable(v)
    return type(v) ~= "table" and type(v) ~= "userdata" and type(v) ~= "function" and type(v) ~= "thread"
end

function RBUtils.RequireFiles(folderPath, files)
    if type(folderPath) ~= "string" then
        _P("RequireFiles: folderPath must be a string")
    end
    for _, filename in ipairs(files) do
        if type(filename) ~= "string" then
            _P("RequireFiles: file names must be strings")
        end

        local path = folderPath .. filename .. ".lua"

        Ext.Require(path)
    
        --[[local ok, res = pcall(Ext.Require, path)
        if not ok then
            _P("RequireFiles", "Failed to load " .. path .. ": " .. tostring(res))
        end]]
    end
end

--- @generic K, V
--- @param tbl table<K, V>
--- @param func? fun(a:K, b:K):boolean
--- @return fun(): (K, V)
function RBUtils.SortedPairs(tbl, func)
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

--- return false to filter out
--- @generic K, V
--- @param tbl table<K, V>
--- @param filterFunc fun(a:K, b:V):boolean
--- @param sortFunc? fun(a:K, b:K):boolean
--- @return fun(): (K, V)
function RBUtils.FilteredPairs(tbl, filterFunc, sortFunc)
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

function RBUtils.IsCamera(object)
    if not object or type(object) ~= "string" then return false end
    return object == CAMERA_SYMBOL or string.sub(object, 1, #CAMERA_SYMBOL) == CAMERA_SYMBOL
end

--- get user id from string like " 'CameraSymbol' .. UserID"
function RBUtils.GetCamaraUserID(obj)
    if RBUtils.IsCamera(obj) then
        return tonumber(string.sub(obj, #CAMERA_SYMBOL + 1))
    end
    return nil
end

function RBUtils.IsItemOrCharacterTemplate(templateId)
    if not templateId or type(templateId) ~= "string" then
        return false
    end

    local templateObj = Ext.Template.GetTemplate(RBUtils.TakeTailTemplate(templateId))
    local templateType = templateObj and templateObj.TemplateType or ""
    return templateType == "item" or templateType == "character"
end

---@param func fun(...:any)
---@param delay number ms
---@return function
function RBUtils.Debounce(delay, func)
    local timerId = nil

    return function(...)
        local args = { ... }

        if timerId then
            Ext.Timer.Cancel(timerId)
        end

        timerId = Ext.Timer.WaitForRealtime(delay, function()
            func(table.unpack(args))
            timerId = nil
        end)
    end
end

--- @param doSomething fun()
--- @param check fun():boolean
--- @param timeOutFrame integer?
function RBUtils.WaitUntil(check, doSomething, timeOutFrame)
    timeOutFrame = timeOutFrame or 300

    local frameCount = 0
    local timerId
    timerId = Ext.Events.Tick:Subscribe(function()
        frameCount = frameCount + 1
        local ok, okToDo = pcall(check)
        if not ok then
            Debug("WaitUntil: check function error: " .. tostring(okToDo))
            Ext.Events.Tick:Unsubscribe(timerId)
            return
        end
        if okToDo then
            doSomething()
            Ext.Events.Tick:Unsubscribe(timerId)
        elseif frameCount >= timeOutFrame then
            Ext.Events.Tick:Unsubscribe(timerId)
        end
    end)
end



function RBUtils.GetFormatTime()
    local clockTime = Ext.Timer.ClockTime()
    local y, m, d, h, min, s = clockTime:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    if not y or not m or not d or not h or not min or not s then
        return ""
    end
    return string.format("%04d-%02d-%02d_%02d%02d%02d", tonumber(y), tonumber(m), tonumber(d),
            tonumber(h), tonumber(min), tonumber(s))
end

function RBUtils.GetFormatHMS()
    local clockTime = Ext.Timer.ClockTime()
    local y, m, d, h, min, s = clockTime:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")

    return string.format("%02d:%02d:%02d", tonumber(h), tonumber(min), tonumber(s))
end

--- @param tokens RB_TextToken[]
--- @param wrapPos number?
--- @return RB_TextToken[]
function RBUtils.WrapTextTokens(tokens, wrapPos)
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