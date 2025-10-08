--- @class Ray
--- @field Origin Vec3
--- @field Direction Vec3
--- @field new fun(origin:Vec3|Vec, direction:Vec3|Vec):Ray
--- @field At fun(self:Ray, t:number):Vec3
--- @field IntersectPlane fun(self:Ray, planePoint:Vec3, planeNormal:Vec3):Hit|nil
--- @field IntersectAABB fun(self:Ray, min:Vec3, max:Vec3):Hit|nil, Hit[]|nil
--- @field IntersectCylinder fun(self:Ray, pos:Vec3, radius:number, height:number, axis:"X"|"Y"|"Z"|Vec3):Hit
Ray = _Class("Ray")

function Ray:__init(origin, direction)
    self.Origin = Vec3.new(origin)
    self.Direction = Vec3.new(direction):Normalize() --[[@as Vec3]]
end

function Ray:At(t)
    return self.Origin + self.Direction * t
end

---@param mat4 Matrix
---@return Vec3 orgin
---@return Vec3 direction
function Ray:ToLocalByMatrix(mat4)
    local invMat = Matrix.new(mat4):Inverse()
    local origin4 = invMat * Vec4.new{self.Origin.x, self.Origin.y, self.Origin.z, 1}
    local dir4 = invMat * Vec4.new{self.Direction.x, self.Direction.y, self.Direction.z, 0}

    local origin = Vec3.new{origin4.x, origin4.y, origin4.z}
    local dir = Vec3.new{dir4.x, dir4.y, dir4.z}:Normalize() --[[@as Vec3]]

    return origin, dir
end

function Ray:ToLocalByPlane(planePoint, planeNormal)
    planeNormal = Vec3.new(planeNormal):Normalize() --[[@as Vec3]]
    planePoint = Vec3.new(planePoint)

    local u, v, w = MakeOrthonormalBasis(planeNormal)

    local originX = Ext.Math.Dot(self.Origin - planePoint, u)
    local originY = Ext.Math.Dot(self.Origin - planePoint, v)
    local originZ = Ext.Math.Dot(self.Origin - planePoint, w)

    local dirX = Ext.Math.Dot(self.Direction, u)
    local dirY = Ext.Math.Dot(self.Direction, v)
    local dirZ = Ext.Math.Dot(self.Direction, w)

    return Vec3.new(originX, originY, originZ), Vec3.new(dirX, dirY, dirZ):Normalize()
end

function Ray:__tostring()
    return string.format("Ray(Origin: %s, Direction: %s)", tostring(self.Origin), tostring(self.Direction))
end

--- @param Other Ray
--- @param noLimit boolean?
--- @return Vec3 C1 -- Closest point on this ray
--- @return Vec3 C2 -- Closest point on Other ray
--- @return number Distance -- Distance between C1 and C2
function Ray:ClosestTTo(Other, noLimit)
    local d1 = self.Direction
    local d2 = Other.Direction
    local r = self.Origin - Other.Origin

    local a = Ext.Math.Dot(d1, d1)
    local e = Ext.Math.Dot(d2, d2)
    local f = Ext.Math.Dot(d2, r)
    local c = Ext.Math.Dot(d1, d2)
    local denom = a * e - c * c

    if math.abs(denom) < 1e-6 then
        local base_point = self.Origin

        local t2 = Ext.Math.Dot(d2, base_point - Other.Origin) / e
        t2 = math.max(t2, 0)
        
        local c1 = base_point
        local c2 = Other:At(t2)
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
    local c2 = Other:At(t)
    local distance = (c1 - c2):Length()

    return c1, c2, distance
end

--- @param planePoint Vec3
--- @param planeNormal Vec3
--- @return Hit|nil
function Ray:IntersectPlane(planePoint, planeNormal)
    planeNormal = Vec3.new(planeNormal):Normalize() --[[@as Vec3]]
    planePoint = Vec3.new(planePoint)

    local denom = Ext.Math.Dot(planeNormal, self.Direction)
    if math.abs(denom) < 1e-6 then return nil end
    local t = Ext.Math.Dot(Ext.Math.Sub(planePoint, self.Origin), planeNormal) / denom
    if t < 0 then --[[Info("Ray:IntersectPlane: Intersection behind ray origin")]] return nil end

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
    if distSqr < innerRadius*innerRadius or distSqr > outerRadius*outerRadius then
        return nil
    end

    return hit
end

--- @param min Vec3
--- @param max Vec3
--- @return Hit|nil, Hit[]|nil
function Ray:IntersectAABB(min, max)
    if not min or not max then return nil end
    local tmin = (min.x - self.Origin.x) / self.Direction.x
    local tmax = (max.x - self.Origin.x) / self.Direction.x
    if tmin > tmax then tmin, tmax = tmax, tmin end

    local tymin = (min.y - self.Origin.y) / self.Direction.y
    local tymax = (max.y - self.Origin.y) / self.Direction.y
    if tymin > tymax then tymin, tymax = tymax, tymin end

    if (tmin > tymax) or (tymin > tmax) then return nil end
    if tymin > tmin then tmin = tymin end
    if tymax < tmax then tmax = tymax end

    local tzmin = (min.z - self.Origin.z) / self.Direction.z
    local tzmax = (max.z - self.Origin.z) / self.Direction.z
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

    local dirLocal = rotation:Inverse():Rotate(self.Direction)
    local originLocal = rotation:Inverse():Rotate(self.Origin - obbCenter)

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
        axis = GLOBAL_COORDINATE[axis] or {0,1,0}
    else
        axis = axis or {0,1,0}
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
    if disc >= 0 and a > 1e-6 then
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
        if math.abs(denom) > 1e-6 then
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
    local discriminant = b * b - 4 * a * c
    if discriminant < 0 then 
        return nil
    else
        local t = (-b - math.sqrt(discriminant)) / (2.0 * a)
        if t < 0 then
            t = (-b + math.sqrt(discriminant)) / (2.0 * a)
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

local PhysicsGroupFlags = Ext.Enums.PhysicsGroupFlags
local PhysicsType = Ext.Enums.PhysicsType

local configurableIntersect = {
    PhysicsType = PhysicsType.Dynamic | PhysicsType.Static,
    PhysicsGroupFlags = PhysicsGroupFlags.Item 
        | PhysicsGroupFlags.Character
        | PhysicsGroupFlags.Scenery
        | PhysicsGroupFlags.VisibleItem,
    PhysicsGroupFlagsExclude = PhysicsGroupFlags.Terrain,
    Function = "RaycastClosest"
}

if GLOBAL_DEBUG_WINDOW then
    local header = GLOBAL_DEBUG_WINDOW:AddCollapsingHeader("Raycast Options")

    local funcCombo = header:AddCombo("Function")
    funcCombo.Options = {"RaycastClosest", "RaycastAll"}
    funcCombo.OnChange = function (ev)
        configurableIntersect.Function = GetCombo(ev)
    end
end

--- @return PhxPhysicsHit
function Ray:IntersectDebug()
    return Ext.Level[configurableIntersect.Function](self.Origin, self.Direction, configurableIntersect.PhysicsType, configurableIntersect.PhysicsGroupFlags, configurableIntersect.PhysicsGroupFlagsExclude, 1)
end

---@param entity EntityHandle|GUIDSTRING
---@return Hit|nil, Hit[]|nil
function Ray:IntersectEntity(entity)
    if type(entity) == "string" then
        entity = Ext.Entity.Get(entity)
    end

    local AABound = entity and entity.Visual and entity.Visual.Visual and entity.Visual.Visual.WorldBound
    if not AABound then return nil end
    return self:IntersectAABB(Vec3.new(AABound.Min), Vec3.new(AABound.Max))
end

function Ray:Debug()
    Post(NetChannel.Visualize, { Type = "Line", Position = self.Origin, EndPosition = self:At(10)})
end



