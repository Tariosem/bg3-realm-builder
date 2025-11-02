--- @class Hit
--- @field Position Vec3|nil
--- @field Normal Vec3|nil
--- @field Distance number
--- @field Target any|nil
--- @field new fun(position?: Vec3, normal?: Vec3, distance?: number, target?: any): Hit
Hit = _Class("Hit")

function Hit:__init(position, normal, distance, target)
    self.Position = position and Vec3.new(position) or nil
    self.Normal   = normal and Vec3.new(normal) or nil
    self.Distance = distance or math.huge
    self.Target   = target
end

function Hit:__tostring()
    return string.format(
        "Hit(Position=%s, Normal=%s, Distance=%.2f, Target=%s)",
        tostring(self.Position),
        tostring(self.Normal),
        self.Distance,
        tostring(self.Target)
    )
end

function Hit.None()
    return Hit.new(nil, nil, math.huge, nil)
end

function Hit:IsCloserThan(other)
    if not other then return true end
    return self.Distance < (other and other.Distance or math.huge)
end

---@param other Hit
---@return Vec3 ?
function Hit:__sub(other)
    if self.Position and other.Position then
        local delta = self.Position - other.Position
        return delta
    end
    return nil
end
