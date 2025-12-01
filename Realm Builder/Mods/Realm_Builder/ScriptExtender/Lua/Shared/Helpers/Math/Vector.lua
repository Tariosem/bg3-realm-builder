--- @class Vec: number[]
--- @field Length fun(self: Vec): number
--- @field Normalize fun(self: Vec): Vec
--- @field Dot fun(self: Vec, b: Vec): number
--- @field Cross fun(self: Vec, b: Vec): Vec
--- @field Sanitize fun(self: Vec, defaultVec: Vec?):Vec
Vector = {}

--- @class Vec3: Vec
--- @field x number
--- @field y number
--- @field z number
--- @field Dot fun(self: Vec3, b: Vec3): number
--- @field Cross fun(self: Vec3, b: Vec3): Vec3
--- @field Inverse fun(self: Vec3): Vec3
--- @field Normalize fun(self: Vec3): Vec3
--- @field Sanitize fun(self: Vec3, defaultVec: Vec3?):Vec3
--- @field new fun(...:any):Vec3
Vec3 = {}

--- @class Vec4: Vec
--- @field x number
--- @field y number
--- @field z number
--- @field w number
--- @field Inverse fun(self: Vec4): Vec4
--- @field Normalize fun(self: Vec4): Vec4
--- @field Dot fun(self: Vec4, b: Vec4): number
--- @field Cross fun(self: Vec4, b: Vec4): Vec4
--- @field Sanitize fun(self: Vec4, defaultVec: Vec4?):Vec4
--- @field new fun(...:any):Vec4
Vec4 = {}

--- @class Vec2: Vec
--- @field x number
--- @field y number
--- @field new fun(...:any):Vec2
Vec2 = {}

AxisIndexMap = { X = 1, Y = 2, Z = 3, W = 4, x = 1, y = 2, z = 3, w = 4 }
IndexAxisMap = { [1] = "X", [2] = "Y", [3] = "Z", [4] = "W" }

Vector.__index = function(t, k)
    if AxisIndexMap[k] then
        return rawget(t, AxisIndexMap[k])
    elseif rawget(t, k) then
        return rawget(t, k)
    else
        return rawget(Vector, k)
    end
end

Vector.__newindex = function(t, k, v)
    if type(k) == "string" and AxisIndexMap[k] then
        rawset(t, AxisIndexMap[k], v)
    elseif type(k) == "number" and k >= 1 then
        rawset(t, k, v)
    else
        Warning("Vec: Attempt to set unknown key: ", k)
    end
end

function Vector.__add(a, b) return Vector.new(Ext.Math.Add(a, b)) end

function Vector.__sub(a, b) return Vector.new(Ext.Math.Sub(a, b)) end

function Vector.__mul(a, b) return Vector.new(Ext.Math.Mul(a, b)) end

function Vector.__div(a, b) return Vector.new(Ext.Math.Div(a, b)) end

function Vector.__unm(a) return Vector.new(Ext.Math.Mul(a, -1)) end

function Vector.__eq(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

function Vector.__tostring(a) return string.format("Vec(%s)", table.concat(a, ", ")) end

function Vector:Length() return Ext.Math.Length(self) end

function Vector:Normalize() return Vector.new(Ext.Math.Normalize(self)) end

function Vector:Dot(b) return Ext.Math.Dot(self, b) end

function Vector:Cross(b) return Vector.new(Ext.Math.Cross(self, b)) end

function Vector:Inverse() return Vector.new(Ext.Math.Inverse(self)) end

function Vector:IsSanitized(limit)
    limit = limit or 1e5
    for i = 1, #self do
        local v = self[i]
        if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge or math.abs(v) > limit then
            return false
        end
    end
    return true
end

function Vector:Sanitize(defaultVec, limit)
    limit = limit or 1e5
    defaultVec = Vector.new(defaultVec or { 0, 0, 0 }, #self)
    for i = 1, #self do
        local v = self[i]
        if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge or math.abs(v) > limit then
            self[i] = defaultVec[i]
        end
    end
    return self
end

function Vector.Add(a, b)
    local newVec = {}
    if type(a) == "table" and type(b) == "table" then
        for i = 1, math.max(#a, #b) do
            newVec[i] = (a[i] or 0) + (b[i] or 0)
        end
    elseif type(a) == "table" and type(b) == "number" then
        for i = 1, #a do
            newVec[i] = a[i] + b
        end
    elseif type(a) == "number" and type(b) == "table" then
        for i = 1, #b do
            newVec[i] = a + b[i]
        end
    elseif type(a) == "number" and type(b) == "number" then
        newVec[1] = a + b
    else
        Warning("Vector.Add: Invalid arguments")
        return Vector.new({ 0, 0, 0 })
    end
    return Vector.new(newVec)
end


function Vector.Sub(a, b)
    local newVec = {}
    if type(a) == "table" and type(b) == "table" then
        for i = 1, math.max(#a, #b) do
            newVec[i] = (a[i] or 0) - (b[i] or 0)
        end
    elseif type(a) == "table" and type(b) == "number" then
        for i = 1, #a do
            newVec[i] = a[i] - b
        end
    elseif type(a) == "number" and type(b) == "table" then
        for i = 1, #b do
            newVec[i] = a - b[i]
        end
    elseif type(a) == "number" and type(b) == "number" then
        newVec[1] = a - b
    else
        Warning("Vector.Sub: Invalid arguments")
        return Vector.new({ 0, 0, 0 })
    end
    return Vector.new(newVec)
end

function Vector.Mul(a, b)
    local newVec = {}
    if type(a) == "table" and type(b) == "table" then
        for i = 1, math.max(#a, #b) do
            newVec[i] = (a[i] or 0) * (b[i] or 0)
        end
    elseif type(a) == "table" and type(b) == "number" then
        for i = 1, #a do
            newVec[i] = a[i] * b
        end
    elseif type(a) == "number" and type(b) == "table" then
        for i = 1, #b do
            newVec[i] = a * b[i]
        end
    elseif type(a) == "number" and type(b) == "number" then
        newVec[1] = a * b
    else
        Warning("Vector.Mul: Invalid arguments")
        return Vector.new({ 0, 0, 0 })
    end
    return Vector.new(newVec)
end

function Vector.Div(a, b)
    local newVec = {}
    if type(a) == "table" and type(b) == "table" then
        for i = 1, math.max(#a, #b) do
            newVec[i] = (a[i] or 0) / (b[i] or 1)
        end
    elseif type(a) == "table" and type(b) == "number" then
        for i = 1, #a do
            newVec[i] = a[i] / b
        end
    elseif type(a) == "number" and type(b) == "table" then
        for i = 1, #b do
            newVec[i] = a / b[i]
        end
    elseif type(a) == "number" and type(b) == "number" then
        newVec[1] = a / b
    else
        Warning("Vector.Div: Invalid arguments")
        return Vector.new({ 0, 0, 0 })
    end
    return Vector.new(newVec)
end

function Vector.Unm(a)
    local newVec = {}
    for i = 1, #a do
        newVec[i] = -a[i]
    end
    return Vector.new(newVec)
end

Vec2.__index = function(t, k)
    if AxisIndexMap[k] then
        return rawget(t, AxisIndexMap[k])
    elseif rawget(t, k) then
        return rawget(t, k)
    else
        return rawget(Vec2, k)
    end
end

Vec2.__newindex = function(t, k, v)
    if type(k) == "string" and AxisIndexMap[k] then
        rawset(t, AxisIndexMap[k], v)
    elseif type(k) == "number" and k >= 1 and k <= 2 then
        rawset(t, k, v)
    else
        Warning("Vec2: Attempt to set unknown key: ", k)
    end
end

function Vec2.__add(a, b) return Vector.Add(a, b) end

function Vec2.__sub(a, b) return Vector.Sub(a, b) end

function Vec2.__mul(a, b) return Vector.Mul(a, b) end

function Vec2.__div(a, b) return Vector.Div(a, b) end

function Vec2.__unm(a) return Vector.Unm(a) end

function Vec2.__tostring(a) return string.format("Vec2(%s)", table.concat(a, ", ")) end

---@param tbl number[]
---@param dim? number
---@return Vec
function Vector.new(tbl, dim)
    dim = dim or #tbl
    for i = 1, dim do
        tbl[i] = tbl[i] or 0
    end
    for i = dim + 1, #tbl do
        tbl[i] = nil
    end
    if dim == 2 then
        return setmetatable(tbl, Vec2) --[[@as Vec2]]
    end

    return setmetatable(tbl, Vector)
end

---@param ... any
---@return Vec3
function Vec3.new(...)
    local args = { ... }

    local tbl = (#args == 1 and type(args[1]) == "table") and args[1] or args

    local wrapped = Vector.new(tbl, 3)

    return wrapped --[[@as Vec3]]
end

---@param ... any
---@return Vec4
function Vec4.new(...)
    local args = { ... }

    local tbl = (#args == 1 and type(args[1]) == "table") and args[1] or args

    local wrapped = Vector.new(tbl, 4)

    return wrapped --[[@as Vec4]]
end

function Vec2.new(...)
    local args = { ... }

    local tbl = (#args == 1 and type(args[1]) == "table") and args[1] or args

    local wrapped = Vector.new(tbl, 2)

    return setmetatable(wrapped, Vec2) --[[@as Vec2]]
end
