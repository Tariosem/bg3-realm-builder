local PICKER_INTERSERCTION_PARAMS = {}
local PICKER_CONSTANTS = {}

PICKER_CONSTANTS.CENTER_SPHERE = {
    Radius = 0.1
}

PICKER_CONSTANTS.CENTER_BB = {
    HalfSizes = {0.1, 0.1, 0.1}
}

PICKER_CONSTANTS.TRANSLATE_PLANE_SQUARE = {
    Inner = 0,
    HalfSize = 0.4
}

PICKER_CONSTANTS.TRANSLATE_AXIS_CYLINDER = {
    Radius = 0.03,
    Height = 1.5
}

PICKER_CONSTANTS.TRANSLATE_AXIS_BB = {
    HalfSizes = {0.03, 0.03, 0.45}
}

PICKER_CONSTANTS.ROTATE_CYLINDER = {
    Radius = 1,
    Height = 0.05
}

PICKER_CONSTANTS.ROTATE_BB = {
    HalfSizes = {1.0, 0.05, 1.0}
}

PICKER_CONSTANTS.ROTATE_RING = {
    InnerRadius = 0.55,
    OuterRadius = 0.65
}

PICKER_INTERSERCTION_PARAMS = DeepCopy(PICKER_CONSTANTS)

if GLOBAL_DEBUG_WINDOW then
    local header = GLOBAL_DEBUG_WINDOW:AddCollapsingHeader("Gizmo Picker Constants")
    for name,constant in pairs(PICKER_CONSTANTS) do
        local node = header:AddTree(name)
        for k,v in pairs(constant) do
            if type(v) ~= "number" then 
                for i=1,#v do
                    local vecName = k .. "[" .. i .. "]"
                    local slider = AddSliderWithStep(node, vecName, v[i], 0.01, 10, 0.01)
                    slider.SameLine = true
                    slider.OnChange = function (s)
                        constant[k][i] = s.Value[1]
                    end
                end
            else
                local name = node:AddText(k .. ": " .. tostring(v))
                local slider = AddSliderWithStep(node, k, v, 0.01, 10, 0.01)
                slider.SameLine = true
                slider.OnChange = function (s)
                    constant[k] = s.Value[1]
                end
            end
        end
    end
    GLOBAL_DEBUG_WINDOW.Open = true
end

local function UpdateConstansByScale(scale)
    local apply = scale

    for name,constant in pairs(PICKER_INTERSERCTION_PARAMS) do
        local base = PICKER_CONSTANTS[name]
        for k,v in pairs(constant) do
            if type(v) ~= "number" then 
                for i=1,#v do
                    constant[k][i] = base[k][i] * (apply or 1)
                end
            else
                constant[k] = base[k] * (apply or 1)
            end
        end
    end
end

--- @class GizmoPicker
--- @field Gizmo Gizmo
--- @field new fun(gizmo: Gizmo): GizmoPicker
--- @field GetTransform fun(self: GizmoPicker): (Vec3?, Quat?, table<'X'|'Y'|'Z'|'Visual', AABound>?)
--- @field GetAxes fun(self: GizmoPicker, origin: Vec3?, rotation: Quat?): table<'X'|'Y'|'Z', Vec3>
--- @field Hit fun(self: GizmoPicker, ray: Ray): (GizmoPickerHit|nil)
--- @field HitRotationTorus fun(self: GizmoPicker, ray: Ray): (Hit|nil)
--- @field ClosestPointOnAxis fun(self: GizmoPicker, ray: Ray, axis: 'X' | 'Y' | 'Z'): (Vec3|nil)
--- @field HitPlaneByAxes fun(self: GizmoPicker, ray: Ray, axes: table<'X' | 'Y' | 'Z', boolean>): (Hit|nil, number|nil)
--- @field HitPlanePerpToAxis fun(self: GizmoPicker, ray: Ray, axis: 'X' | 'Y' | 'Z'): (Hit|nil)
GizmoPicker = _Class("GizmoPicker")

function GizmoPicker:__init(gizmo, position, rotation)
    self.Gizmo = gizmo
    self.Position = position or Vec3.new({0,0,0})
    self.Rotation = rotation or Quat.new({0,0,0,1})
    self.AABB = nil
    self.Scale = 1.0
end

--- @return Vec3|nil, Quat|nil
function GizmoPicker:GetTransform()
    UpdateConstansByScale(self.Scale)

    return self.Position, self.Rotation
end

function GizmoPicker:GetAxes(origin, rotation)
    local space = self.Gizmo.Space or "World"
    local axisX = GLOBAL_COORDINATE.X
    local axisY = GLOBAL_COORDINATE.Y
    local axisZ = GLOBAL_COORDINATE.Z
    if space ~= "World" then
        if not origin or not rotation then
            origin, rotation = self:GetTransform()
        end
        if rotation then
            axisX = rotation:Rotate(GLOBAL_COORDINATE.X)
            axisY = rotation:Rotate(GLOBAL_COORDINATE.Y)
            axisZ = rotation:Rotate(GLOBAL_COORDINATE.Z)
        end
    else
        axisX = Vec3.new(axisX)
        axisY = Vec3.new(axisY)
        axisZ = Vec3.new(axisZ)
    end
    return {
        X = axisX,
        Y = axisY,
        Z = axisZ,
    }
end

--- @class GizmoPickerHit
--- @field Axis table<'X' | 'Y' | 'Z', boolean>
--- @field Hit Hit

--- @param ray Ray
--- @return GizmoPickerHit|nil
function GizmoPicker:Hit(ray)
    local mode = self.Gizmo and self.Gizmo.Mode or "Translate"

    local origin, rotation = self:GetTransform()
    if not origin or not rotation then Warning("GizmoPicker:Hit: No transform found") return nil end

    local params = PICKER_INTERSERCTION_PARAMS

    -- Check AABB first
    local aabb = self.AABB or {Min=Vec3.new(-1,-1,-1), Max=Vec3.new(1,1,1)}
    local gizmoAABBHit = ray:IntersectAABB(aabb.Min, aabb.Max)
    if not gizmoAABBHit or not gizmoAABBHit.Position then return nil end

    local axes = self:GetAxes(origin, rotation)
    --- @diagnostic disable-next-line
    if mode == "Rotate" then return self:HitRotationTorus(ray, origin, rotation, axes) end

    -- Check center OBBs next
    local closestHit = nil
    local hitAxes = nil
    local centerHalfSizes = Vec3.new(params.CENTER_BB.HalfSizes)
    if self.Gizmo.Mode == "Scale" then
        centerHalfSizes = centerHalfSizes * 3
    end

    local centerHit = ray:IntersectOBB(origin, centerHalfSizes, rotation)
    if centerHit and centerHit.Position then
        hitAxes = {X=true, Y=true, Z=true}
        closestHit = centerHit
    end

    -- Check axis OBBs next
    for axis,dir in pairs(axes) do
        local axisCenter = origin + dir * params.TRANSLATE_AXIS_BB.HalfSizes[3]
        local obbRotation = DirectionToQuat(dir)
        local halfSizes = Vec3.new(params.TRANSLATE_AXIS_BB.HalfSizes)

        local hit = ray:IntersectOBB(axisCenter, halfSizes, obbRotation)
        if hit and hit.Position then
            if hit:IsCloserThan(closestHit) then
                hitAxes = {[axis]=true}
                closestHit = hit
            end
        end
    end

    -- Check plane squares last
    local planeAxes = {
        {X=true,Y=true},
        {Y=true,Z=true},
        {X=true,Z=true}
    }
    for _,plane in pairs(planeAxes) do
        local planeHit = self:HitPlaneByAxes(ray, plane)
        local halfSize = params.TRANSLATE_PLANE_SQUARE.HalfSize
        if planeHit and planeHit.Position then
            local dist = planeHit.Position - origin
            local localPos = Vec3.new(
                Ext.Math.Dot(dist, axes.X),
                Ext.Math.Dot(dist, axes.Y),
                Ext.Math.Dot(dist, axes.Z)
            )

            local halfSize = params.TRANSLATE_PLANE_SQUARE.HalfSize
            local inner = params.TRANSLATE_PLANE_SQUARE.Inner
            for axis,_ in pairs(plane) do
                if localPos[axis] < 0 then
                    goto continue
                end

                if localPos[axis] > halfSize or localPos[axis] < inner then
                    goto continue
                end
            end

            if planeHit and planeHit.Position then
                if planeHit:IsCloserThan(closestHit) then
                    closestHit = planeHit
                    hitAxes = plane
                end
                
            end
        end

        ::continue::
    end

    return closestHit and {
        Axis = hitAxes,
        Hit = closestHit
    } or nil
end

--- @param ray Ray
--- @return GizmoPickerHit|nil
function GizmoPicker:HitRotationTorus(ray, origin, rotation, axes)
    -- Check rotation torus next
    local closest = nil
    local closestAxis = nil
    for axis,dir in pairs(axes) do
        local params = PICKER_INTERSERCTION_PARAMS.ROTATE_RING
        local hit = ray:IntersectRing(origin, dir, params.InnerRadius, params.OuterRadius)
        --local hit = ray:IntersectTorus(origin, ROTATE_TORUS.MajorRadius, ROTATE_TORUS.MinorRadius, dir) I give up
        if hit and hit.Position then
            if hit:IsCloserThan(closest) then
                closest = hit
                closestAxis = axis
            end
        end
    end

    return closest and {
        Axis = {[closestAxis]=true},
        Hit = closest
    } or nil
end

---@param ray Ray
---@param axis 'X' | 'Y' | 'Z'
---@return Vec3 -- Closest point on axis to ray
function GizmoPicker:ClosestPointOnAxis(ray, axis)
    local origin, rotation = self:GetTransform()
    local axisMap = self:GetAxes(origin, rotation)
    local dir = axisMap[axis]
    if not dir or not origin then
        Warning("GizmoPicker:ClosestPointOnAxis: Invalid axis: ", tostring(axis))
        return self.Position
    end
    
    local gizmoRay = Ray.new(origin, dir)
    local closestPoint = gizmoRay:ClosestTTo(ray, true)

    return closestPoint
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

    local hit = ray:IntersectPlane(origin, planeNormal)
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
    for axis,_ in pairs(axes) do
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

    return self:HitPlaneByNormal(ray, planeNormal)
end

---@param ray Ray
---@param axis 'X' | 'Y' | 'Z'
---@return Hit|nil
function GizmoPicker:HitPlanePerpToAxis(ray, axis)
    local axes = {}
    if axis == "X" then
        axes = {Y=true, Z=true}
    elseif axis == "Y" then
        axes = {X=true, Z=true}
    elseif axis == "Z" then
        axes = {X=true, Y=true}
    else
        Warning("GizmoPicker:HitPlanePerpToAxis: Invalid axis: ", tostring(axis))
        return nil
    end
    return self:HitPlaneByAxes(ray, axes)
end