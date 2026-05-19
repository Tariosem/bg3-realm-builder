--- @class Realm_Builder.Utils
--- @field Uuid_v4 fun():string
--- @field MakeTranslatedHandle fun():string
--- @field IsUuid fun(object:string?):boolean
--- @field IsUuidIncludingNull fun(object:string?):boolean
--- @field IsUuidShape fun(object:string?):boolean
--- @field ComputeVersion64 fun(major:string|number, minor:string|number, revision:string|number, build:string|number):string
--- @field ParseVersion64 fun(version64:string|number): (number, number, number, number)
--- @field BuildVersionString fun(major:string|number, minor:string|number, revision:string|number, build:string|number):string
--- @field ParseVersionString fun(versionStr:string): (number, number, number, number)
--- @field IsValidFolderName fun(name:any):boolean
--- @field ValidateFolderName fun(name:any):string
--- @field ToVec4 fun(...:any):number[]
--- @field ToVec4Int fun(...:any):number[]
--- @field ToVec2 fun(...:any):number[]
--- @field ToVec3 fun(...:any):number[]
--- @field LightCToArray fun<T>(arr:T[]):T[]
--- @field DeepCopy fun<T>(o:T):T
--- @field IsSerializable fun(v:any):boolean
--- @field RequireFiles fun(folderPath:string, files:string[])
--- @field SortedPairs fun<K, V>(tbl:table<K, V>, func?:fun(a:K, b:K):boolean): fun(): (K, V)
--- @field FilteredPairs fun<K, V>(tbl:table<K, V>, filterFunc:fun(key:K, value:V):boolean, sortFunc:fun(key:K, value:K):boolean): fun(): (K, V)
--- @field IsCamera fun(object:string?):boolean
--- @field GetCamaraUserID fun(obj:string):number?
--- @field IsItemOrCharacterTemplate fun(templateId:string):boolean
--- @field Debounce fun(delay:number, func:fun(...:any)):fun(...:any)
--- @field WaitUntil fun(check:fun(frameCnt:integer):boolean, callback:fun(), fallback:fun()?, timeOutFrame:integer?)
--- @field DoubleClick fun(onClick:fun(...:any), onDoubleClick:fun(...:any), interval?:number):fun(...:any)
--- @field GetFormatTime fun():string
--- @field GetFormatHMS fun():string
--- @field WrapTextTokens fun(tokens:RB_TextToken[], wrapPos?:number):RB_TextToken[]
--- @field EntitiesToUUIDs fun(entities:EntityHandle[]):string[]
--- @field AsyncForEach fun<K, V>(t:table<K, V>, func:fun(value:V, key:K, processedCount:number):any, waitFor:number?, yieldAfter:number?):AsyncForEachResult
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

---@return string
function RBUtils.MakeTranslatedHandle()
    local template = "hxxxxxxxxgxxxxgxxxxgxxxxgxxxxxxxxxxx"
    local handle = template:gsub("x", function()
        return string.format("%x", math.random(0, 15))
    end)

    return handle
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

function RBUtils.IsUuidShape(o)
    if not o then return false end

    if type(o) ~= "string" then return false end

    return o:match("^%w%w%w%w%w%w%w%w%-%w%w%w%w%-%w%w%w%w%-%w%w%w%w%-%w%w%w%w%w%w%w%w%w%w%w%w$") ~= nil
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
--- @param filterFunc fun(key:K, value:V):boolean
--- @param sortFunc? fun(key:K, value:K):boolean
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

--- get user id from string like " <CameraSymbol> .. UserID"
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

--- @param callback fun()
--- @param check fun(frameCnt:integer):boolean
--- @param timeOutFrame integer?
--- @param fallback fun()?
function RBUtils.WaitUntil(check, callback, fallback, timeOutFrame)
    timeOutFrame = timeOutFrame or 300

    local frameCount = 0
    local timerId
    timerId = Ext.Events.Tick:Subscribe(function()
        frameCount = frameCount + 1
        local ok, okToDo = pcall(check, frameCount)
        if not ok then
            Debug("WaitUntil: check function error: " .. tostring(okToDo))
            Ext.Events.Tick:Unsubscribe(timerId)
            return
        end
        if okToDo then
            callback()
            Ext.Events.Tick:Unsubscribe(timerId)
        elseif frameCount >= timeOutFrame then
            Ext.Events.Tick:Unsubscribe(timerId)
            if fallback then
                fallback()
            end
        end
    end)
end

--- @param onClick fun(...)
--- @param onDoubleClick fun(...)
--- @param interval number?
--- @return fun(...)
function RBUtils.DoubleClick(onClick, onDoubleClick, interval)
    interval = interval or 400
    local lastClickTime = 0

    return function(...)
        local currentTime = Ext.Utils.MonotonicTime()
        if currentTime - lastClickTime <= interval then
            onDoubleClick(...)
            lastClickTime = 0
        else
            onClick(...)
            lastClickTime = currentTime
        end
    end
end



--- @return string -- file name friendly time stamp
function RBUtils.GetFormatTime()
    local clockTime = Ext.Timer.ClockTime()
    local y, m, d, h, min, s = clockTime:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    if not y or not m or not d or not h or not min or not s then
        return ""
    end
    return string.format("%04d-%02d-%02d_%02d-%02d-%02d", tonumber(y), tonumber(m), tonumber(d),
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

--- @param entities EntityHandle[]
function RBUtils.EntitiesToUUIDs(entities)
    local uuids = {}
    for i, entity in ipairs(entities) do
        if type(entity) == "string" then
            table.insert(uuids, entity)
        elseif type(entity) == "table" and entity.Uuid and entity.Uuid.EntityUuid then
            local uuid = entity.Uuid.EntityUuid
            table.insert(uuids, uuid)
        end
    end
    return uuids
end

--- @class AsyncForEachResult
--- @field results table
--- @field isComplete boolean
--- @field errors {key:any, error:any}[]
--- @field OnComplete fun(results:table, errors:any[])
--- @field WaitFor number
--- @field YieldAfter number

--- @generic K, V
--- @param t table<K, V>
--- @param func fun(value:V, key:K, processedCount:number):any
--- @param waitFor number?
--- @param yieldAfter number?
--- @return AsyncForEachResult
function RBUtils.AsyncForEach(t, func, waitFor, yieldAfter)
    local returnObj = {
        results = {},
        isComplete = false,
        errors = {},
        OnComplete = function() end,
        WaitFor = waitFor or 100, -- ms, default 100ms
        YieldAfter = yieldAfter or 1, -- ms threshold to yield, default 1ms.
    }

    local processed = 0
    local last = Ext.Timer.MonotonicTime()

    local thread
    thread = coroutine.create(function()
        for k, v in pairs(t) do
            local ok, result = pcall(func, v, k, processed)
            if ok then
                returnObj.results[k] = result
            else
                table.insert(returnObj.errors, { key = k, error = result })
            end

            processed = processed + 1
            if Ext.Timer.MonotonicTime() - last >= returnObj.YieldAfter then
                Timer:After(returnObj.WaitFor, function()
                    if coroutine.status(thread) ~= "dead" then
                        local ok, err = coroutine.resume(thread)
                        if not ok then
                            _P("AsyncForEach error: " .. tostring(err))
                        end
                    end
                end)
                coroutine.yield()
                last = Ext.Timer.MonotonicTime()
            end
        end

        returnObj.isComplete = true
        returnObj.OnComplete(returnObj.results, returnObj.errors)
    end)

    local ok, err = coroutine.resume(thread)
    if not ok then
        _P("AsyncForEach error: " .. tostring(err))
    end
    return setmetatable({}, {
        __index = function(t, k)
            return returnObj[k]
        end,
        __newindex = function(t, k, v)
            if k == "OnComplete" and type(v) == "function" then
                returnObj.OnComplete = v
            elseif (k == "WaitFor" or k == "YieldAfter") and type(v) == "number" then
                returnObj[k] = v
            else 
                _P("Attempt to set invalid property on AsyncForEach result: " .. tostring(k))
            end
        end
    })
end