--- @class VectorBase: number[]
Vector = {}

--- @class VecMethods<T>: VectorBase
--- @field Length fun(self: T): number
--- @field Normalize fun(self: T): T
--- @field Dot fun(self: T, b: T): number
--- @field Cross fun(self: T, b: T): T
--- @field Sanitize fun(self: T, defaultVec: T?): T
--- @field Inverse fun(self: T): T
--- @field Lerp fun(self: T, b: T, t: number): T
--- @field Add fun(self: T, b: T|number): T
--- @field Sub fun(self: T, b: T|number): T
--- @field Mul fun(self: T, b: T|number): T
--- @field Div fun(self: T, b: T|number): T
--- @field Unm fun(self: T): T

--- @class Vec2: VecMethods<Vec2>
--- @field x number
--- @field y number
--- @field xy Vec2
--- @operator add(Vec2|number): Vec2
--- @operator sub(Vec2|number): Vec2
--- @operator mul(Vec2|number): Vec2
--- @operator div(Vec2|number): Vec2
--- @operator unm(): Vec2
--- @operator call(...): Vec2
--- @field new fun(...): Vec2
Vec2 = {}

--- @class Vec3: VecMethods<Vec3>
--- @field x number
--- @field y number
--- @field z number
--- @field xy Vec2
--- @field xz Vec2
--- @field yz Vec2
--- @field xyz Vec3
--- @operator add(Vec3|number): Vec3
--- @operator sub(Vec3|number): Vec3
--- @operator mul(Vec3|number): Vec3
--- @operator div(Vec3|number): Vec3
--- @operator unm(): Vec3
--- @operator call(...): Vec3
--- @field new fun(...): Vec3
Vec3 = {}

--- @class Vec4: VecMethods<Vec4>
--- @field x number
--- @field y number
--- @field z number
--- @field w number
--- @field xy Vec2
--- @field xz Vec2
--- @field xw Vec2
--- @field yz Vec2
--- @field yw Vec2
--- @field zw Vec2
--- @field xyz Vec3
--- @field xyw Vec3
--- @field xzw Vec3
--- @field yzw Vec3
--- @field xyzw Vec4
--- @operator add(Vec4|number): Vec4
--- @operator sub(Vec4|number): Vec4
--- @operator mul(Vec4|number): Vec4
--- @operator div(Vec4|number): Vec4
--- @operator unm(): Vec4
--- @operator call(...): Vec4
--- @field new fun(...): Vec4
Vec4 = {}

--- @class Vec: VecMethods<Vec>
--- @operator add(Vec|number): Vec
--- @operator sub(Vec|number): Vec
--- @operator mul(Vec|number): Vec
--- @operator div(Vec|number): Vec
--- @operator unm(): Vec
--- @operator call(...): Vec
--- @field new fun(...): Vec
Vec = {}

--- @alias AxisIndexMap {X: 1, Y: 2, Z: 3, W: 4, x: 1, y: 2, z: 3, w: 4}
local axisIndexMap = {
    x = 1,
    y = 2,
    z = 3,
    w = 4,

    X = 1,
    Y = 2,
    Z = 3,
    W = 4,
}

--- @alias IndexAxisMap {[1]: "x", [2]: "y", [3]: "z", [4]: "w"}
local indexAxisMap = {
    [1] = "x",
    [2] = "y",
    [3] = "z",
    [4] = "w"
}

Vector.__index = function (t, k)
    local v = rawget(t, k)
    if v then return v end
    v = rawget(Vector, k)
    if v then return v end
    if type(k) ~= "string" then return nil end

    k = k:lower() --[[@as string]]
    local nums = {}
    for ci=1, #k do
        local idx = axisIndexMap[k:sub(ci, ci)]
        if idx then nums[#nums + 1] = rawget(t, idx) or 0 else return nil end
    end
    return #nums == 1 and nums[1] or Vector.new(nums)
end

Vector.__newindex = function (t, k, v)
    if type(k) ~= "string" then rawset(t, k, v) return end
    
    k = k:lower() --[[@as string]]
    local indices = {}
    for ci=1, #k do
        local idx = axisIndexMap[k:sub(ci, ci)]
        if idx then indices[#indices + 1] = idx else rawset(t, k, v) return end
    end
    for i, idx in ipairs(indices) do
        rawset(t, idx, v[i] or 0)
    end
end

AxisIndexMap = setmetatable({}, {__index = function(t, k) return axisIndexMap[k] end}) --[[@as AxisIndexMap]]
IndexAxisMap = setmetatable({}, {__index = function(t, k) return indexAxisMap[k] end}) --[[@as IndexAxisMap]]

function Vector.__add(a, b)   return Vector.Add(a, b) end
function Vector.__sub(a, b)   return Vector.Sub(a, b) end
function Vector.__mul(a, b)   return Vector.Mul(a, b) end
function Vector.__div(a, b)   return Vector.Div(a, b) end
function Vector.__unm(a)      return Vector.Unm(a) end
function Vector.__call(_, ...) return Vector.anew(...) end
function Vector.__tostring(a) return string.format("Vec%d(%s)", #a, table.concat(a, ", ")) end

function Vector:Length()
    if #self == 3 or #self == 4 then return Ext.Math.Length(self) end
    local sum = 0
    for i = 1, #self do sum = sum + self[i]^2 end
    return math.sqrt(sum)
end

function Vector:Normalize()
    if #self == 3 or #self == 4 then return Vector.new(Ext.Math.Normalize(self)) end
    local l = self:Length()
    return setmetatable(self:Div(l ~= 0 and l or 1), Vector)
end

function Vector:Inverse()
    local res = {}
    for i = 1, #self do res[i] = -self[i] end
    return setmetatable(res, Vector)
end

function Vector:Dot(b)
    if #self == #b and (#self == 3 or #self == 4) then return Ext.Math.Dot(self, b) end
    local res = 0
    for i = 1, #self do res = res + self[i] * (b[i] or 0) end
    return setmetatable(res, Vector)
end

function Vector:Cross(b)
    if #self == 3 and #b == 3 then return Vector.new(Ext.Math.Cross(self, b)) end
    Warning("Cross product is only defined for 3D vectors")
    return Vector.new({0,0,0}, 3)
end

function Vector.Lerp(a, b, t)
    local res = {}
    for i = 1, #a do res[i] = a[i] + ((b[i] or 0) - a[i]) * t end
    return setmetatable(res, Vector)
end

function Vector.Add(a, b)
    local res = {}
    local isNumB = type(b) == "number"
    for i = 1, #a do res[i] = a[i] + (isNumB and b or (b[i] or 0)) end
    return setmetatable(res, Vector)
end

function Vector.Sub(a, b)
    local res = {}
    local isNumB = type(b) == "number"
    for i = 1, #a do res[i] = a[i] - (isNumB and b or (b[i] or 0)) end
    return setmetatable(res, Vector)
end

function Vector.Mul(a, b)
    local res = {}
    local isNumB = type(b) == "number"
    for i = 1, #a do res[i] = a[i] * (isNumB and b or (b[i] or 1)) end
    return setmetatable(res, Vector)
end

function Vector.Div(a, b)
    local res = {}
    local isNumB = type(b) == "number"
    for i = 1, #a do res[i] = a[i] / (isNumB and b or (b[i] or 1)) end
    return setmetatable(res, Vector)
end

function Vector.Unm(a)
    local res = {}
    for i = 1, #a do res[i] = -a[i] end
    return setmetatable(res, Vector)
end

---@param tbl number[]
---@param dim? number
---@return any
function Vector.new(tbl, dim)
    dim = dim or #tbl
    
    local obj = {}
    local mt = Vector --[[@as any]]
    if dim == 3 then mt = Vec3 elseif dim == 4 then mt = Vec4 end
    for i = 1, dim do obj[i] = tbl[i] or 0 end
    return setmetatable(obj, mt)
end

function Vector.anew(...)
    local args = {...}
    local dim = #args
    local obj = {}
    for i = 1, dim do obj[i] = args[i] or 0 end
    return setmetatable(obj, Vector)
end

function Vec2.new(...)
    local args = {...}
    if #args == 1 and type(args[1]) == "table" then
        return setmetatable({args[1][1] or 0, args[1][2] or 0}, Vector) --[[@as Vec2]]
    else
        return setmetatable({args[1] or 0, args[2] or 0}, Vector) --[[@as Vec2]]
    end
end

Vec3.__add = function(a, b) return setmetatable(Ext.Math.Add(a, b), Vec3) end
Vec3.__sub = function(a, b) return setmetatable(Ext.Math.Sub(a, b), Vec3) end
Vec3.__mul = function(a, b) return setmetatable(Ext.Math.Mul(a, b), Vec3) end
Vec3.__div = function(a, b) return setmetatable(Ext.Math.Div(a, b), Vec3) end
Vec3.__unm = function(a) return setmetatable(Ext.Math.Mul(a, -1), Vec3) end
Vec3.__tostring = function(a) return string.format("Vec3(%s)", table.concat(a, ", ")) end
Vec3.__call = function(_, ...) return Vec3.new(...) end
Vec3.__index = Vector.__index

function Vec3.new(...)
    local args = {...}
    if #args == 1 and type(args[1]) == "table" then
        return setmetatable({args[1][1] or 0, args[1][2] or 0, args[1][3] or 0}, Vec3) --[[@as Vec3]]
    else
        return setmetatable({args[1] or 0, args[2] or 0, args[3] or 0}, Vec3) --[[@as Vec3]]
    end
end

Vec4.__add = function(a, b) return setmetatable(Ext.Math.Add(a, b), Vec4) end
Vec4.__sub = function(a, b) return setmetatable(Ext.Math.Sub(a, b), Vec4) end
Vec4.__mul = function(a, b) return setmetatable(Ext.Math.Mul(a, b), Vec4) end
Vec4.__div = function(a, b) return setmetatable(Ext.Math.Div(a, b), Vec4) end
Vec4.__unm = function(a) return setmetatable(Ext.Math.Mul(a, -1), Vec4) end
Vec4.__tostring = function(a) return string.format("Vec4(%s)", table.concat(a, ", ")) end
Vec4.__call = function(_, ...) return Vec4.new(...) end
Vec4.__index = Vector.__index

function Vec4.new(...)
    local args = {...}
    if #args == 1 and type(args[1]) == "table" then
        return setmetatable({args[1][1] or 0, args[1][2] or 0, args[1][3] or 0, args[1][4] or 0}, Vec4) --[[@as Vec4]]
    else
        return setmetatable({args[1] or 0, args[2] or 0, args[3] or 0, args[4] or 0}, Vec4) --[[@as Vec4]]
    end
end

Vec2 = setmetatable(Vec2, Vector)
Vec3 = setmetatable(Vec3, Vector)
Vec4 = setmetatable(Vec4, Vector)