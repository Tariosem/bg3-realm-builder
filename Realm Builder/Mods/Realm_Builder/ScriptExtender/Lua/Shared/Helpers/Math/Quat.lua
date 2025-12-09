--- @alias quat Quat

--- @class Quat
--- @field x number
--- @field y number
--- @field z number
--- @field w number
--- @field Inverse fun(self: Quat): Quat
--- @field Normalize fun(self: Quat): Quat
--- @field Rotate fun(self: Quat, v: Vec3): Vec3
--- @field Rotate fun(self: Quat, v: Vec4): Vec4
--- @field ToEuler fun(self: Quat): Vec3
--- @field Identity Quat
Quat = Quat or {}

Quat.__index = function(t, k)
    if AxisIndexMap[k] then return rawget(t, AxisIndexMap[k])
    elseif rawget(t, k) then return rawget(t, k)
    else return rawget(Quat, k) end
end

Quat.__mul = function(a, b)
    if type(b) == "table" and #b == 4 then
        return Quat.new(Ext.Math.QuatMul(a, b))
    elseif type(b) == "table" and #b == 3 then
        return Vec3.new(Ext.Math.QuatRotate(a, b))
    else
        Warning("Quat: Invalid multiplication with table of size " .. tostring(#b))
        return Quat.Identity()
    end
end

Quat.__tostring = function(a) return string.format("Quat(%s)", table.concat(a, ", ")) end

function Quat.Identity() return Quat.new(0,0,0,1) end
function Quat:Inverse() return Quat.new(Ext.Math.QuatInverse(self)) end
function Quat:Normalize() return Quat.new(Ext.Math.QuatNormalize(self)) end
function Quat:Rotate(v) return Vec3.new(Ext.Math.QuatRotate(self, v)) end
function Quat:ToEuler() return MathUtils.QuatToEuler(self) end

function Quat:Sanitize(default, limit)
    default = Quat.new(default or {0, 0, 0, 1})
    for i = 1, 4 do
        local v = self[i]
        if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge or v > limit or v < -limit then
            self = default
            break
        end
    end
    return self
end

--- @param ... number|number[]|Quat
--- @return Quat
function Quat.new(...)
    local args = {...}
    local t

    if #args == 1 then
        local v = args[1]

        if getmetatable(v) == Quat then
            t = {v[1], v[2], v[3], v[4]}

        elseif type(v) == "table" and #v == 4 then
            t = {v[1], v[2], v[3], v[4]}
        end

    elseif #args == 4 then
        t = {args[1], args[2], args[3], args[4]}
    end

    if not t then
        --Warning("WrapQuat: invalid args")
        t = Quat.Identity()
    end

    return setmetatable(t, Quat) --[[@as Quat]]
end

function Quat.FromEuler(euler)
    if #euler ~= 3 then
        Warning("WrapQuatFromEuler: Invalid table length, expected 3 got "..tostring(#euler))
        return Quat.Identity()
    end
    return Quat.new(Ext.Math.QuatFromEuler(euler))
end

function Quat.FromTo(fromVec, toVec)
    if #fromVec ~= 3 or #toVec ~= 3 then
        Warning("Quat.FromTo: Invalid vector length, expected 3 got "..tostring(#fromVec)..", "..tostring(#toVec))
        return Quat.Identity()
    end
    return Quat.new(Ext.Math.QuatFromToRotation(fromVec, toVec))
end

Quat.IsQuat = true