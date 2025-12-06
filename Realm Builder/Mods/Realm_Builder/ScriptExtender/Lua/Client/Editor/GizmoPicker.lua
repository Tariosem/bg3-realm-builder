local PICKER_CONSTANTS = {}

PICKER_CONSTANTS.BOUNDING_SPHERE = {
    Radius = 1.1
}

PICKER_CONSTANTS.CENTER_SPHERE = {
    Radius = 0.1
}

PICKER_CONSTANTS.TRANSLATE_PLANE_SQUARE = {
    Inner = 0.4,
    HalfSize = 0.8
}

PICKER_CONSTANTS.TRANSLATE_AXIS_BB = {
    HalfSize = 0.03,
    Length = 1.1,
}

PICKER_CONSTANTS.SCALE_AXIS_BB = {
    HalfSize = 0.03,
    Length = 0.9,
}

PICKER_CONSTANTS.ROTATE_RING = {
    InnerRadius = 0.55,
    OuterRadius = 0.65
}

RegisterDebugWindow("Gizmo Picker Constants", function(panel)
    for partName,part in pairs(PICKER_CONSTANTS) do
        local partTree = ImguiElements.AddTree(panel, partName)
        ImguiElements.AddGeneralTableEditor(partTree, part, function ()
        end)
    end
end)

--- @class GizmoPickerHitPart
--- @field Name string
--- @field Priority number -- Lower number = higher priority
--- @field PreferMode TransformEditorMode -- Optional preferred mode for this part，used in "Transform" mode
--- @field Mode table<TransformEditorMode, boolean> -- Modes this part is active in
--- @field Axis table<TransformAxis, boolean> -- Axes this part is associated with
--- @field HitTest fun(picker: GizmoPicker, localRay: Ray):Hit? -- localRay is in gizmo local space
--- @field UpdateScale fun(picker: GizmoPicker, scale: number)

local AxisIndexMap = AxisIndexMap
local axisNames = { "X", "Y", "Z" }
local localOrigin = Vec3.new(0, 0, 0)

local makeCenterSphere = function()
    local centerSphereRadius = PICKER_CONSTANTS.CENTER_SPHERE.Radius
    return {
        Name = "CenterSphere",
        Priority = 0,
        PreferMode = "Scale",
        Mode = { Translate = true, Scale = true },
        Axis = { X = true, Y = true, Z = true },
        ---@param picker GizmoPicker
        ---@param localRay Ray
        HitTest = function(picker, localRay)
            return localRay:IntersectSphere(localOrigin, centerSphereRadius)
        end,
        UpdateScale = function(picker, scale)
            centerSphereRadius = PICKER_CONSTANTS.CENTER_SPHERE.Radius * scale
        end,
    }
end

--- @param axis TransformAxis
--- @return GizmoPickerHitPart
local function makeTranslateBB(axis)
    local idx = AxisIndexMap[axis]
    local halfSize = PICKER_CONSTANTS.TRANSLATE_AXIS_BB.HalfSize
    local max = Vec3.new(halfSize, halfSize, halfSize)
    local min = -max
    max[idx] = PICKER_CONSTANTS.TRANSLATE_AXIS_BB.Length
    return {
        Name = "TranslateAxis" .. axis,
        Priority = 2,
        PreferMode = "Translate",
        Mode = { Translate = true },
        Axis = { [axis] = true },
        ---@param picker GizmoPicker
        ---@param localRay Ray
        HitTest = function(picker, localRay)
            return localRay:IntersectAABB(min, max)
        end,
        UpdateScale = function(picker, scale)
            halfSize = PICKER_CONSTANTS.TRANSLATE_AXIS_BB.HalfSize * scale
            max = Vec3.new(halfSize, halfSize, halfSize)
            min = -max
            max[idx] = PICKER_CONSTANTS.TRANSLATE_AXIS_BB.Length * scale
        end,
    }
end

--- @param axis TransformAxis
--- @return GizmoPickerHitPart
local makeScaleBB = function(axis)
    local idx = AxisIndexMap[axis]
    local halfSize = PICKER_CONSTANTS.SCALE_AXIS_BB.HalfSize
    local max = Vec3.new(halfSize, halfSize, halfSize)
    local min = -max
    max[idx] = PICKER_CONSTANTS.SCALE_AXIS_BB.Length
    return {
        Name = "ScaleAxis" .. axis,
        Priority = 1,
        PreferMode = "Scale",
        Mode = { Scale = true },
        Axis = { [axis] = true },
        ---@param picker GizmoPicker
        ---@param localRay Ray
        HitTest = function(picker, localRay)
            return localRay:IntersectAABB(min, max)
        end,
        UpdateScale = function(picker, scale)
            halfSize = PICKER_CONSTANTS.SCALE_AXIS_BB.HalfSize * scale
            max = Vec3.new(halfSize, halfSize, halfSize)
            min = -max
            max[idx] = PICKER_CONSTANTS.SCALE_AXIS_BB.Length * scale
        end,
    }
end

local function makePlaneSquare(axis)
    local normal = GLOBAL_COORDINATE[axis]
    local halfSize = PICKER_CONSTANTS.TRANSLATE_PLANE_SQUARE.HalfSize
    local inner = PICKER_CONSTANTS.TRANSLATE_PLANE_SQUARE.Inner
    local hitAxes = {}
    for _, a in pairs(axisNames) do
        if a ~= axis then
            hitAxes[a] = true
        end
    end
    --- @type GizmoPickerHitPart
    return {
        Name = "PlaneSquare" .. axis,
        Priority = 3,
        PreferMode = "Translate",
        Mode = { Translate = true, Scale = true },
        Axis = hitAxes,
        ---@param picker GizmoPicker
        ---@param localRay Ray
        HitTest = function(picker, localRay)
            local hit = localRay:IntersectPlane(localOrigin, normal, true)
            if not hit or not hit.Position then return nil end

            local dist = hit.Position --[[@as Vec3]]

            for a, _ in pairs(hitAxes) do
                local val = dist[a]
                if val < 0 then
                    return nil
                end

                if val > halfSize or val < inner then
                    return nil
                end
            end

            return hit
        end,
        UpdateScale = function(picker, scale)
            halfSize = PICKER_CONSTANTS.TRANSLATE_PLANE_SQUARE.HalfSize * scale
            inner = PICKER_CONSTANTS.TRANSLATE_PLANE_SQUARE.Inner * scale
        end,
    }
end

local function makeRotateRing(axis)
    local innerRadius = PICKER_CONSTANTS.ROTATE_RING.InnerRadius
    local outerRadius = PICKER_CONSTANTS.ROTATE_RING.OuterRadius
    local normal = GLOBAL_COORDINATE[axis]
    --- @type GizmoPickerHitPart
    return {
        Name = "RotateRing" .. axis,
        Priority = 2,
        PreferMode = "Rotate",
        Mode = { Rotate = true },
        Axis = { [axis] = true },
        ---@param picker GizmoPicker
        ---@param localRay Ray
        HitTest = function(picker, localRay)
            return localRay:IntersectRing(
                localOrigin,
                normal,
                innerRadius,
                outerRadius
            )
        end,
        UpdateScale = function(picker, scale)
            innerRadius = PICKER_CONSTANTS.ROTATE_RING.InnerRadius * scale
            outerRadius = PICKER_CONSTANTS.ROTATE_RING.OuterRadius * scale
        end,
    }
end

--- @class GizmoPicker
--- @field Gizmo TransformGizmo
--- @field Position Vec3
--- @field Rotation Quat
--- @field Scale number
--- @field HitParts GizmoPickerHitPart[]
--- @field new fun(gizmo: TransformGizmo): GizmoPicker
--- @field GetTransform fun(self: GizmoPicker): (Vec3?, Quat?)
--- @field GetAxes fun(self: GizmoPicker, origin: Vec3?, rotation: Quat?): table<TransformAxis, Vec3>
--- @field Hit fun(self: GizmoPicker, ray: Ray): (GizmoPickerHit|nil)
--- @field HitRotationTorus fun(self: GizmoPicker, ray: Ray): (Hit|nil)
--- @field ClosestTTo fun(self: GizmoPicker, ray: Ray, normal: Vec3): Vec3
--- @field ClosestAxis fun(self: GizmoPicker, ray: Ray): TransformAxis
--- @field ClosestPlane fun(self: GizmoPicker, ray: Ray): (TransformAxis|nil, Hit|nil)
--- @field HitPlaneByAxes fun(self: GizmoPicker, ray: Ray, axes: table<TransformAxis, boolean>): (Hit|nil, number|nil)
--- @field HitPlanePerpToAxis fun(self: GizmoPicker, ray: Ray, axis: TransformAxis|Vec3): (Hit|nil)
--- @field ProjectPointOnPlane fun(self: GizmoPicker, point: Vec3, planeNormal: Vec3): (Vec3|nil)
GizmoPicker = _Class("GizmoPicker")

function GizmoPicker:__init(gizmo, position, rotation)
    self.Gizmo = gizmo
    self.Position = position or Vec3.new({ 0, 0, 0 })
    self.Rotation = rotation or Quat.new({ 0, 0, 0, 1 })
    self.Scale = 1.0

    self.HitParts = { makeCenterSphere() }
    for _, axis in pairs(axisNames) do
        self.HitParts[#self.HitParts + 1] = makeTranslateBB(axis)
        self.HitParts[#self.HitParts + 1] = makeScaleBB(axis)
        self.HitParts[#self.HitParts + 1] = makeRotateRing(axis)
        self.HitParts[#self.HitParts + 1] = makePlaneSquare(axis)
    end
    table.sort(self.HitParts, function(a, b)
        return a.Priority < b.Priority
    end)
end

function GizmoPicker:UpdateParamsByScale()
    for _, part in pairs(self.HitParts) do
        if part.UpdateScale then
            part.UpdateScale(self, self.Scale)
        end
    end
end

function GizmoPicker:SetTransform(pos, rot, scale)
    self.Position = pos or self.Position
    self.Rotation = rot or self.Rotation
    self.Scale = scale or self.Scale

    self:UpdateParamsByScale()

    self.axesDirty = true
end

--- @return Vec3|nil, Quat|nil
function GizmoPicker:GetTransform()
    return self.Position, self.Rotation
end

function GizmoPicker:GetAxes(origin, rotation)
    if not self.axesDirty and self.axes then
        return self.axes
    end
    local axisX = GLOBAL_COORDINATE.X
    local axisY = GLOBAL_COORDINATE.Y
    local axisZ = GLOBAL_COORDINATE.Z
    if not origin or not rotation then
        origin, rotation = self:GetTransform()
    end
    if rotation then
        axisX = rotation:Rotate(GLOBAL_COORDINATE.X)
        axisY = rotation:Rotate(GLOBAL_COORDINATE.Y)
        axisZ = rotation:Rotate(GLOBAL_COORDINATE.Z)
    end

    self.axes = self.axes or {}
    self.axes.X = axisX
    self.axes.Y = axisY
    self.axes.Z = axisZ
    self.axesDirty = false
    return {
        X = axisX,
        Y = axisY,
        Z = axisZ,
    }
end

--- @class GizmoPickerHit
--- @field Axis table<TransformAxis, boolean>
--- @field HitMode TransformEditorMode
--- @field Hit Hit

--- @param ray Ray -- in world space
--- @return GizmoPickerHit|nil
function GizmoPicker:Hit(ray)
    local mode = self.Gizmo and self.Gizmo.Mode or "Translate"

    local origin, rotation = self:GetTransform()

    if not origin or not rotation then
        Warning("GizmoPicker:Hit: No transform found")
        return nil
    end

    -- Check Sphere first
    local gizmoSphereHit = ray:IntersectSphere(origin, self.Scale * PICKER_CONSTANTS.BOUNDING_SPHERE.Radius)
    if not gizmoSphereHit or not gizmoSphereHit.Position then return nil end

    local localRay = ray:ToLocal({
        Translate = origin,
        RotationQuat = rotation,
    })

    local isUniformMode = mode == "Transform"
    local bestHit = {
        Hit = {}
    }
    for _, part in pairs(self.HitParts) do
        if isUniformMode or part.Mode[mode] then
            local hit = part.HitTest(self, localRay)
            if hit and hit.Position and hit:IsCloserThan(bestHit.Hit) then
                local returnMode = mode
                if isUniformMode then
                    returnMode = part.PreferMode
                end
                bestHit = {
                    Axis = part.Axis,
                    HitMode = returnMode,
                    Hit = hit,
                }
            end
        end
    end

    -- since this function is only used for hovering and clicking, there is no need to transform the hit back to world space
    --[[if bestHit.Hit.Position then
        bestHit.Hit = bestHit.Hit:Transform({
            Translate = origin,
            RotationQuat = rotation,
        })
    end]]

    return bestHit.Hit.Position and bestHit or nil
end

---@param ray Ray
---@param axis TransformAxis
---@return Vec3 -- Closest point on axis to ray
function GizmoPicker:ClosestPointOnAxis(ray, axis)
    local origin, rotation = self:GetTransform()
    local axisMap = self:GetAxes(origin, rotation)
    local dir = axisMap[axis]
    if not dir or not origin then
        Warning("GizmoPicker:ClosestPointOnAxis: Invalid axis: ", tostring(axis))
        return origin or Vec3.new(0, 0, 0)
    end

    local gizmoRay = Ray.new(origin, dir)
    local closestPoint = gizmoRay:ClosestTTo(ray, true)

    return closestPoint or origin
end

--- @param ray Ray
--- @param normal Vec3
--- @return Vec3
function GizmoPicker:ClosestTTo(ray, normal)
    local origin, rotation = self:GetTransform()
    if not origin or not rotation then return ray.Origin end
    local otherRay = Ray.new(origin, normal)
    local closestPoint = ray:ClosestTTo(otherRay, true)
    return closestPoint or ray.Origin
end

--- @param ray Ray
--- @param normal Vec3
--- @return Hit|nil
function GizmoPicker:HitPlaneByNormal(ray, normal)
    local origin, rotation = self:GetTransform()
    if not origin or not rotation then return nil end

    local planeNormal = normal
    if not planeNormal then
        Warning("GizmoPicker:HitPlaneByNormal: Invalid normal provided", normal)
        return nil
    end

    local hit = ray:IntersectPlane(origin, planeNormal, true)
    if not hit or not hit.Position then return nil end

    return hit
end

---@param ray Ray
---@param axes table<'X' | 'Y' | 'Z', boolean>
---@return Hit|nil
function GizmoPicker:HitPlaneByAxes(ray, axes)
    local origin, rotation = self:GetTransform()
    if not origin or not rotation then return nil end

    local planeNormal = nil
    local axis1 = nil
    local axis2 = nil
    local axisMap = self:GetAxes()
    for axis, _ in pairs(axes) do
        if not axis1 then
            axis1 = axisMap[axis]
        elseif not axis2 then
            axis2 = axisMap[axis]
            break
        end
    end

    if not axis1 or not axis2 then
        Warning("GizmoPicker:HitPlaneByAxes: Invalid axes provided", axes)
        return nil
    end

    planeNormal = Ext.Math.Cross(axis1, axis2)
    if not planeNormal then
        Warning("GizmoPicker:HitPlaneByAxes: Failed to calculate plane normal", axes)
        return nil
    end

    local hit = ray:IntersectPlane(origin, planeNormal, true)
    if not hit or not hit.Position then return nil end

    return hit
end

---@param ray Ray
---@param axis TransformAxis
---@return Hit|nil
function GizmoPicker:HitPlanePerpToAxis(ray, axis)
    if type(axis) == "table" and #axis == 3 then
        return self:HitPlaneByNormal(ray, axis)
    end

    local axes = { X = true, Y = true, Z = true }
    axes[axis] = nil

    if not axes.X and not axes.Y and not axes.Z then
        Warning("GizmoPicker:HitPlanePerpToAxis: Invalid axis: ", tostring(axis))
        return nil
    end
    return self:HitPlaneByAxes(ray, axes)
end

function GizmoPicker:ClosestPlane(ray)
    local perpAxis = nil
    local closestHit = nil
    for _, axis in pairs({ "X", "Y", "Z" }) do
        local hit = self:HitPlanePerpToAxis(ray, axis)
        if not closestHit or (hit and hit:IsCloserThan(closestHit)) then
            closestHit = hit
            perpAxis = axis
        end
    end
    return perpAxis, closestHit
end

function GizmoPicker:ClosestAxis(ray)
    local origin, rotation = self:GetTransform()
    if not origin or not rotation then return "X" end

    local axes = self:GetAxes(origin, rotation)
    local closestAxis = nil
    local closestDist = math.huge
    for axis, dir in pairs(axes) do
        --- @diagnostic disable-next-line
        local pointOnAxis = self:ClosestPointOnAxis(ray, axis)
        local dist = Ext.Math.Distance(pointOnAxis, origin)
        if dist < closestDist then
            closestDist = dist
            closestAxis = axis
        end
    end

    return closestAxis or "X"
end

function GizmoPicker:ProjectPointOnPlane(point, planeNormal)
    local origin, rotation = self:GetTransform()
    if not origin or not rotation then return nil end
    local toPoint = point - origin
    local distance = Ext.Math.Dot(toPoint, planeNormal)
    return point - planeNormal * distance
end

--- @param point Vec3
--- @param axis TransformAxis
--- @return Vec3|nil
function GizmoPicker:ProjectPointOnPlanePerpToAxis(point, axis)
    local axes = self:GetAxes()

    local planeNormal = axes[axis]
    if not planeNormal then
        Warning("GizmoPicker:ProjectPointOnPlanePerpToAxis: Failed to calculate plane normal", axes)
        return nil
    end

    return self:ProjectPointOnPlane(point, planeNormal)
end
