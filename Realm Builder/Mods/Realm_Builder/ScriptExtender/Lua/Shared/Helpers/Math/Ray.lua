--- @class Ray
--- @field Origin Vec3
--- @field Direction Vec3
--- @field new fun(origin:Vec3|Vec, direction:Vec3|Vec):Ray
--- @field At fun(self:Ray, t:number):Vec3
--- @field Transform fun(self:Ray, transform:Transform):Ray
--- @field IntersectPlane fun(self:Ray, planePoint:Vec3, planeNormal:Vec3, includeBehind?:boolean):Hit|nil
--- @field IntersectAABB fun(self:Ray, min:Vec3, max:Vec3):Hit|nil, Hit[]|nil
--- @field IntersectOBB fun(self:Ray, obbCenter:Vec3, halfsizes:Vec3, rotation:Quat):Hit|nil, Hit[]|nil
--- @field IntersectSphere fun(self:Ray, center:Vec3, radius:number):Hit|nil
--- @field IntersectRing fun(self:Ray, planePoint:Vec3, planeNormal:Vec3, innerRadius:number, outerRadius:number):Hit|nil
--- @field IntersectCylinder fun(self:Ray, pos:Vec3, radius:number, height:number, axis:"X"|"Y"|"Z"|Vec3):Hit
Ray = _Class("Ray")

function Ray:__init(origin, direction)
    self.Origin = Vec3.new(origin)
    self.Direction = Vec3.new(direction):Normalize() --[[@as Vec3]]
end

function Ray:At(t)
    return self.Origin + self.Direction * t
end

function Ray:__tostring()
    return string.format("Ray(Origin: %s, Direction: %s)", tostring(self.Origin), tostring(self.Direction))
end

function Ray:__eq(other)
    return self.Origin == other.Origin and self.Direction == other.Direction
end

---@param transform Transform
---@return Ray
function Ray:Transform(transform)
    local translate = transform.Translate
    local rotation = transform.RotationQuat
    local newOrigin = rotation * self.Origin + translate
    local newDirection = rotation * self.Direction
    return Ray.new(newOrigin, newDirection)
end

---@param pivotTransform Transform
---@return Ray
function Ray:ToLocal(pivotTransform)
    local invRot = pivotTransform.RotationQuat:Inverse()
    local localOrigin = invRot:Rotate(self.Origin - pivotTransform.Translate)
    local localDirection = invRot:Rotate(self.Direction)
    return Ray.new(localOrigin, localDirection)
end

--- @param other Ray
--- @param noLimit boolean? -- If true, don't clamp t values to be >= 0
--- @return Vec3 C1 -- Closest point on this ray
--- @return Vec3 C2 -- Closest point on Other ray
--- @return number Distance -- Distance between C1 and C2
function Ray:ClosestTTo(other, noLimit)
    local d1 = self.Direction
    local d2 = other.Direction
    local r = self.Origin - other.Origin

    local a = Ext.Math.Dot(d1, d1)
    local e = Ext.Math.Dot(d2, d2)
    local f = Ext.Math.Dot(d2, r)
    local c = Ext.Math.Dot(d1, d2)
    local denom = a * e - c * c

    if math.abs(denom) < EPSILON then
        local base_point = self.Origin

        local t2 = Ext.Math.Dot(d2, base_point - other.Origin) / e
        t2 = math.max(t2, 0)
        
        local c1 = base_point
        local c2 = other:At(t2)
        local distance = (c1 - c2):Length()
        
        return c1, c2, distance
    end

    local b = Ext.Math.Dot(d1, r)

    local s = (c * f - e * b) / denom
    local t = (a * f - c * b) / denom

    if not noLimit then
        s = math.max(0, s)
        t = math.max(0, t)
    end
    
    local c1 = self:At(s)
    local c2 = other:At(t)
    local distance = (c1 - c2):Length()

    return c1, c2, distance
end

--- @param planePoint Vec3
--- @param planeNormal Vec3
--- @param includeBehind boolean?
--- @return Hit|nil
function Ray:IntersectPlane(planePoint, planeNormal, includeBehind)
    planeNormal = Vec3.new(planeNormal):Normalize() --[[@as Vec3]]
    planePoint = Vec3.new(planePoint)

    local denom = Ext.Math.Dot(planeNormal, self.Direction)
    if math.abs(denom) < EPSILON then
        --Info("Ray:IntersectPlane: Parallel, no intersection")
        if math.abs(Ext.Math.Dot(planeNormal, self.Origin - planePoint)) < EPSILON then
            return Hit.new(
                self.Origin,
                planeNormal,
                0,
                nil
            )
        end
        return nil
    end
    local t = Ext.Math.Dot(Ext.Math.Sub(planePoint, self.Origin), planeNormal) / denom
    if t < 0 then
        if not includeBehind then
            --Info("Ray:IntersectPlane: Intersection behind ray origin")
            return nil
        end
        local hitPos = self:At(t)
        return Hit.new(
            hitPos,
            planeNormal,
            t,
            nil
        )
    end

    --Info("Ray:IntersectPlane: Hit at distance ", t)

    return Hit.new(
        self:At(t),
        planeNormal,
        t,
        nil
    )
end

--- @param planePoint Vec3
--- @param planeNormal Vec3
--- @param innerRadius number
--- @param outerRadius number
--- @return Hit?
function Ray:IntersectRing(planePoint, planeNormal, innerRadius, outerRadius)
    local hit = self:IntersectPlane(planePoint, planeNormal)
    if not hit then return nil end

    local toHit = hit.Position - planePoint
    local distSqr = Ext.Math.Dot(toHit, toHit)
    if distSqr < innerRadius*innerRadius or distSqr > outerRadius*outerRadius then return nil end

    return hit
end

--- @param min Vec3
--- @param max Vec3
--- @return Hit|nil, Hit[]|nil
function Ray:IntersectAABB(min, max)
    if not min or not max then return nil end
    local tmin = (min[1] - self.Origin[1]) / self.Direction[1]
    local tmax = (max[1] - self.Origin[1]) / self.Direction[1]
    if tmin > tmax then tmin, tmax = tmax, tmin end

    local tymin = (min[2] - self.Origin[2]) / self.Direction[2]
    local tymax = (max[2] - self.Origin[2]) / self.Direction[2]
    if tymin > tymax then tymin, tymax = tymax, tymin end

    if (tmin > tymax) or (tymin > tmax) then return nil end
    if tymin > tmin then tmin = tymin end
    if tymax < tmax then tmax = tymax end

    local tzmin = (min[3] - self.Origin[3]) / self.Direction[3]
    local tzmax = (max[3] - self.Origin[3]) / self.Direction[3]
    if tzmin > tzmax then tzmin, tzmax = tzmax, tzmin end

    if (tmin > tzmax) or (tzmin > tmax) then return nil end
    if tzmin > tmin then tmin = tzmin end
    if tzmax < tmax then tmax = tzmax end

    local otherHit = {}
    table.insert(otherHit, Hit.new(
        self:At(tmax),
        nil,
        tmax,
        nil
    ))

    return Hit.new(
        self:At(tmin),
        nil,
        tmin,
        nil
    ),
    otherHit
end

---@param obbCenter Vec3
---@param halfsizes Vec3
---@param rotation Quat
---@return Hit|nil
---@return Hit[]|nil
function Ray:IntersectOBB(obbCenter, halfsizes, rotation)
    obbCenter = Vec3.new(obbCenter)
    halfsizes = Vec3.new(halfsizes)
    rotation = Quat.new(rotation)

    local invRot = rotation:Inverse()
    local dirLocal = invRot:Rotate(self.Direction)
    local originLocal = invRot:Rotate(self.Origin - obbCenter)

    local rayLocal = Ray.new(originLocal, dirLocal)
    local negaHalfsize = -halfsizes --[[@as Vec3]]
    local hit, otherHits = rayLocal:IntersectAABB(negaHalfsize, halfsizes)
    if hit then
        hit.Position = rotation:Rotate(hit.Position) + obbCenter
        if otherHits then
            for _,h in ipairs(otherHits) do
                h.Position = rotation:Rotate(h.Position) + obbCenter
            end
        end
    end
    return hit, otherHits
end

---@param pos vec3
---@param radius number
---@param height number
---@param axis "X" | "Y" | "Z" | vec3
---@return Hit
function Ray:IntersectCylinder(pos, radius, height, axis)
    if type(axis) == "string" then
        axis = GLOBAL_COORDINATE[axis] or GLOBAL_COORDINATE.Y
    else
        axis = axis or GLOBAL_COORDINATE.Y
    end
    axis = Vec3.new(axis):Normalize()

    local oc = self.Origin - pos
    local d = self.Direction

    local dDotA = Ext.Math.Dot(d, axis)
    local oDotA = Ext.Math.Dot(oc, axis)

    local dPerp = d - dDotA * axis
    local oPerp = oc - oDotA * axis

    local a = Ext.Math.Dot(dPerp, dPerp)
    local b = 2 * Ext.Math.Dot(oPerp, dPerp)
    local c = Ext.Math.Dot(oPerp, oPerp) - radius*radius

    local closestHit = Hit.None()

    local disc = b*b - 4*a*c
    if disc >= 0 and a > EPSILON then
        local sqrtDisc = math.sqrt(disc)
        for _,t in ipairs{(-b - sqrtDisc)/(2*a), (-b + sqrtDisc)/(2*a)} do
            if t >= 0 then
                local p = self:At(t)
                local hProj = Ext.Math.Dot(p - pos, axis)
                if math.abs(hProj) <= height*0.5 then
                    if t < closestHit.Distance then
                        closestHit = Hit.new(
                            p,
                            nil,
                            t,
                            nil
                        )
                    end
                end
            end
        end
    end

    for _,sign in ipairs{1,-1} do
        local capCenter = pos + axis * (sign * height * 0.5)
        local denom = Ext.Math.Dot(d, axis)
        if math.abs(denom) > EPSILON then
            local t = Ext.Math.Dot(capCenter - self.Origin, axis) / denom
            if t >= 0 then
                local p = self:At(t)
                if Ext.Math.Length(p - capCenter) <= radius then
                    if t < closestHit.Distance then
                        closestHit = Hit.new(
                            p,
                            axis * sign,
                            t,
                            nil
                        )
                    end
                end
            end
        end
    end

    return closestHit
end

--- @param center Vec3
--- @param radius number
--- @return Hit|nil
function Ray:IntersectSphere(center, radius)
    center = Vec3.new(center)
    radius = radius or 1.0
    local oc = self.Origin - center
    local a = Ext.Math.Dot(self.Direction, self.Direction)
    local b = 2.0 * Ext.Math.Dot(oc, self.Direction)
    local c = Ext.Math.Dot(oc, oc) - radius * radius
    local disc = b * b - 4 * a * c
    if disc < 0 then
        return nil
    else
        local t = (-b - math.sqrt(disc)) / (2.0 * a)
        if t < 0 then
            t = (-b + math.sqrt(disc)) / (2.0 * a)
        end
        if t < 0 then return nil end
        return Hit.new(
            self:At(t),
            nil,
            t,
            nil
        )
    end
end

---@param entity EntityHandle|GUIDSTRING
---@return Hit|nil, Hit[]|nil
function Ray:IntersectEntity(entity)
    if type(entity) == "string" then
        entity = Ext.Entity.Get(entity) --[[@as EntityHandle]]
    end

    local AABound = entity and entity.Visual and entity.Visual.Visual and entity.Visual.Visual.WorldBound
    if not AABound then return nil end
    return self:IntersectAABB(Vec3.new(AABound.Min), Vec3.new(AABound.Max))
end

function Ray:Debug()
    NetChannel.Visualize:RequestToServer({
        Type = "Line",
        Position = self.Origin,
        EndPosition = self:At(10),
        Duration = 3000,
    }, function(response)
    end)
end



