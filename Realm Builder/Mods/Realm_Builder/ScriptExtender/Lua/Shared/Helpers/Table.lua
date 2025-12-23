--- @class RBTableUtils
--- @field IsArray fun(t:table|userdata):boolean
--- @field IsArrayOf fun(tbl:table, valueType:"number"|"string"|"boolean"|"table"|"userdata"|"function"|"thread"|"nil"):boolean
--- @field MergeArrays fun(arr1:any[], arr2:any[]):any[]
--- @field CountMap fun(map:any):integer
--- @field ArrayReverse fun(arr:any[]):any[]
--- @field EqualArrays fun(arr1:any[], arr2:any[]):boolean
--- @field ToggleEntry fun(tbl:table, value:any):boolean
--- @field NextFromList fun(list:any[], cur:any):any
RBTableUtils = RBTableUtils or {}

local isTable = function(o)
    return type(o) == "table" or type(o) == "userdata"
end

---@param t table|userdata
---@return boolean
function RBTableUtils.IsArray(t)
    if not isTable(t) then
        return false
    end
    
    local count = 0
    --- @diagnostic disable-next-line
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

function RBTableUtils.IsArrayOfAny(tbl)
    if type(tbl) ~= "table" and type(tbl) ~= "userdata" then
        return false
    end

    for key, v in pairs(tbl) do
        if not tonumber(key) then
            return false
        end
    end

    return true
end


---@param o table
---@param t "number"|"string"|"boolean"|"table"|"userdata"|"function"|"thread"|"nil"
---@return boolean
function RBTableUtils.IsArrayOf(o, t)
    if not RBTableUtils.IsArrayOfAny(o) then
        return false
    end

    for _, v in pairs(o) do
        if type(v) ~= t then
            return false
        end
    end

    return true
end

---@param map any
---@return integer cnt
function RBTableUtils.CountMap(map)
    map = map or {}
    local count = 0
    for _, _ in pairs(map) do
        count = count + 1
    end
    return count
end

function RBTableUtils.ArrayReverse(arr)
    local result = {}
    for i = #arr, 1, -1 do
        table.insert(result, arr[i])
    end
    return result
end

function RBTableUtils.EqualArrays(arr1, arr2)
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


function RBTableUtils.ToggleEntry(tbl, value)
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


--- @generic T
--- @param o T
--- @param f T
function RBTableUtils.RecoverFrom(o, f)
    for k, v in pairs(o) do
        if isTable(v) then
            RBTableUtils.RecoverFrom(v, f[k])
        else
            o[k] = f[k]
        end
    end
end

--- @generic K, V
--- @param inputMap table<K, V>
--- @param comparator fun(a: {Key:K,Value:V}, b: {Key:K,Value:V}): boolean
--- @return table<{Key:K,Value:V}>
function RBTableUtils.MapToSortedArrayByFunc(inputMap, comparator)
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
function RBTableUtils.MapToSortedArrayByKey(inputMap, order)
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
