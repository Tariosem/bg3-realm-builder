--- @class Vec
--- @field Length fun(self: Vec): number
--- @field Normalize fun(self: Vec): Vec
--- @field Rotate fun(self: Vec, axis: string, angle: number): Vec
--- @field Dot fun(self: Vec, b: Vec): number
--- @field Cross fun(self: Vec, b: Vec): Vec
Vector = {}

--- @class Vec3: Vec
--- @field x number
--- @field y number
--- @field z number
Vec3 = {}

--- @class Vec4: Vec
--- @field x number
--- @field y number
--- @field z number
--- @field w number
Vec4 = {}

--- @class Vec2: Vec
--- @field x number
--- @field y number
Vec2 = {}

AxisIndexMap = {X=1, Y=2, Z=3, W=4, x=1, y=2, z=3, w=4}
IndexAxisMap = { [1]="X", [2]="Y", [3]="Z", [4]="W" }

Vector.__index = function(t, k)
    if AxisIndexMap[k] then return rawget(t, AxisIndexMap[k])
    elseif rawget(t, k) then return rawget(t, k)
    else return rawget(Vector, k) end
end

Vector.__newindex = function(t, k, v)
    if type(k) == "string" and AxisIndexMap[k] then
        rawset(t, AxisIndexMap[k], v)
    elseif type(k) == "number" and k >= 1 then
        rawset(t, k, v)
    else Warning("Vec: Attempt to set unknown key: ", k) end
end

function Vector.__add(a, b) return Vector.new(Ext.Math.Add(a, b)) end
function Vector.__sub(a, b) return Vector.new(Ext.Math.Sub(a, b)) end
function Vector.__mul(a, b) return Vector.new(Ext.Math.Mul(a, b)) end
function Vector.__div(a, b) return Vector.new(Ext.Math.Div(a, b)) end
function Vector.__unm(a)    return Vector.new(Ext.Math.Mul(a, -1)) end
function Vector.__tostring(a) return string.format("Vec(%s)", table.concat(a, ", ")) end

function Vector:Length() return Ext.Math.Length(self) end
function Vector:Normalize() return Vector.new(Ext.Math.Normalize(self)) end
function Vector:Rotate(axis, angle) return Vector.new(Ext.Math.Rotate(self, axis, angle), #self) end
function Vector:Dot(b) return Ext.Math.Dot(self, b) end
function Vector:Cross(b) return Vector.new(Cross(self, b)) end
function Vector:Inverse() return Vector.new(Ext.Math.Inverse(self)) end

Vec2.__index = function(t, k)
    if AxisIndexMap[k] then return rawget(t, AxisIndexMap[k])
    elseif rawget(t, k) then return rawget(t, k)
    else return rawget(Vec2, k) end
end

Vec2.__newindex = function(t, k, v)
    if type(k) == "string" and AxisIndexMap[k] then
        rawset(t, AxisIndexMap[k], v)
    elseif type(k) == "number" and k >= 1 and k <= 2 then
        rawset(t, k, v)
    else Warning("Vec2: Attempt to set unknown key: ", k) end
end

function Vec2.__add(a, b) return Vector.new({a[1] + b[1], a[2] + b[2]}, 2) end
function Vec2.__sub(a, b) return Vector.new({a[1] - b[1], a[2] - b[2]}, 2) end
function Vec2.__mul(a, b)
    if type(b) == "number" then
        return Vector.new({a[1] * b, a[2] * b}, 2)
    elseif type(b) == "table" and #b == 2 then
        return Vector.new({a[1] * b[1], a[2] * b[2]}, 2)
    else
        Warning("Vec2: Invalid multiplication")
        return Vector.new({0, 0}, 2)
    end
end

function Vec2.__div(a, b)
    if type(b) == "number" then
        return Vec2.new({a[1] / b, a[2] / b})
    elseif type(b) == "table" and #b == 2 then
        return Vec2.new({a[1] / b[1], a[2] / b[2]})
    else
        Warning("Vec2: Invalid division")
        return Vector.new({0, 0}, 2)
    end
end

function Vec2.__unm(a)    return Vector.new({-a[1], -a[2]}, 2) end
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
    local args = {...}

    local tbl = (#args == 1 and type(args[1]) == "table") and args[1] or args

    local wrapped = Vector.new(tbl, 3)

    return wrapped --[[@as Vec3]]
end

---@param ... any
---@return Vec4
function Vec4.new(...)
    local args = {...}

    local tbl = (#args == 1 and type(args[1]) == "table") and args[1] or args

    local wrapped = Vector.new(tbl, 4)

    return wrapped --[[@as Vec4]]
end

function Vec2.new(...)
    local args = {...}

    local tbl = (#args == 1 and type(args[1]) == "table") and args[1] or args

    local wrapped = Vector.new(tbl, 2)

    return setmetatable(wrapped, Vec2) --[[@as Vec2]]
end