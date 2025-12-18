MathUtils = MathUtils or {}

--- @param position Vec3
--- @param rotationQuat quat
--- @param scale Vec3
--- @return number[]
function MathUtils.BuildModelMatrix(position, rotationQuat, scale)
    local rotationMat = Matrix.new(Ext.Math.QuatToMat4(rotationQuat))
    local translateMat = Matrix.new(Ext.Math.BuildTranslation(position))
    local scaleMat = Matrix.new(Ext.Math.BuildScale(scale))
    return translateMat * rotationMat * scaleMat
end

---@param transform Transform
---@return number[]
function MathUtils.BuildModelMatrixFromTransform(transform)
    local transalte = Vec3.new(transform.Translate)
    local rotation = transform.RotationQuat
    local scale = Vec3.new(transform.Scale)

    return MathUtils.BuildModelMatrix(transalte, rotation, scale)
end

local LHCS_AXES = {
    X = {1, 0, 0},
    Y = {0, 1, 0},
    Z = {0, 0, 1},
    x = {1, 0, 0},
    y = {0, 1, 0},
    z = {0, 0, 1},
}

local LHCS = {}

setmetatable(LHCS, {
    __index = function(t, k)
        if LHCS_AXES[k] then
            return Vec3.new(LHCS_AXES[k])
        else
            return nil
        end
    end,
    __newindex = function(t, k, v)
        Error("Attempt to modify read-only table LHCS")
    end
})

--- @type {X: Vec3, Y: Vec3, Z: Vec3}
GLOBAL_COORDINATE = LHCS

---@param quat vec4
---@param axis "X"|"Y"|"Z"
---@return vec4 Flipped
function MathUtils.FlipAxis(quat, axis)
    if not quat or #quat ~= 4 then
        Error("Invalid quaternion: " .. tostring(quat))
        return quat
    end
    local ax = Vec3.new(GLOBAL_COORDINATE[axis:upper()])
    if not ax then
        Error("Invalid axis: " .. tostring(axis))
        return quat
    end
    local flipped = Ext.Math.QuatRotateAxisAngle(quat, ax, math.pi)
    return Ext.Math.Normalize(flipped)
end

function MathUtils.GetCenterPosition(uuids)
    local positions = {}
    if type(uuids) == "string" then
        uuids = {uuids}
    end
    
    for _, uuid in ipairs(uuids) do
        local x, y, z = RBGetPosition(uuid)
        if x and y and z then
            table.insert(positions, {x, y, z})
        else
            Warning("Invalid position for UUID: " .. tostring(uuid))
        end
    end

    if #positions == 0 then
        return nil, nil, nil
    end

    local sum = positions[1]
    for i = 2, #positions do
        sum = Ext.Math.Add(sum, positions[i])
    end
    
    local center = Ext.Math.Div(sum, #positions)
    return center[1], center[2], center[3]
end

--- @param direction Vec3
--- @param up? Vec3
--- @param alignedAxis? TransformAxis|Vec3
--- @return quat
function MathUtils.DirectionToQuat(direction, up, alignedAxis)
    direction = Ext.Math.Normalize(direction)
    up = up and Ext.Math.Normalize(up) or GLOBAL_COORDINATE.Y
    alignedAxis = alignedAxis and type(alignedAxis) == "string" and alignedAxis:upper() or alignedAxis or "Z"

    if math.abs(Ext.Math.Dot(direction, up)) > 0.999 then
        up = GLOBAL_COORDINATE.X
        if math.abs(Ext.Math.Dot(direction, up)) > 0.999 then
            up = GLOBAL_COORDINATE.Z
        end
    end

    local right, realUp = {}, {}
    local forward = direction
    right = Ext.Math.Normalize(Ext.Math.Cross(up, forward))
    realUp = Ext.Math.Normalize(Ext.Math.Cross(forward, right))

    local mat = {
        right[1], right[2], right[3],
        realUp[1], realUp[2], realUp[3],
        direction[1], direction[2], direction[3],
    }

    local quat = Ext.Math.Mat3ToQuat(mat)

    if alignedAxis ~= "Z" then
        if alignedAxis == "X" then
            quat = Ext.Math.QuatRotateAxisAngle(quat, GLOBAL_COORDINATE.Y, -math.pi/2)
        elseif alignedAxis == "Y" then
            quat = Ext.Math.QuatRotateAxisAngle(quat, GLOBAL_COORDINATE.X, math.pi/2)
        elseif type(alignedAxis) == "table" and #alignedAxis == 3 then
            local targetForward = Ext.Math.Normalize(alignedAxis)
            local currentForward = GLOBAL_COORDINATE.Z
            
            local axis = Ext.Math.Cross(currentForward, targetForward)
            local axisLength = Ext.Math.Length(axis)
            
            if axisLength > 1e-10 then
                axis = Ext.Math.Normalize(axis)
                local dot = Ext.Math.Dot(currentForward, targetForward)
                local angle = Ext.Math.Atan2(axisLength, dot)       
                quat = Ext.Math.QuatRotateAxisAngle(quat, axis, angle)
            end
        else
            Warning("Invalid forwardAxis: " .. tostring(alignedAxis))
        end
    end

    return Quat.new(Ext.Math.QuatNormalize(quat))
end

--- @param quat quat
--- @return Vec3 euler in degrees
function MathUtils.QuatToEuler(quat)
    local globalAxes = {
        X = GLOBAL_COORDINATE.X,
        Y = GLOBAL_COORDINATE.Y,
        Z = GLOBAL_COORDINATE.Z,
    }
    local euler = {0, 0, 0}
    for i, axis in pairs({"X", "Y", "Z"}) do
        local rotatedAxis = Ext.Math.QuatRotate(quat, globalAxes[axis])

        local referenceAxis
        if axis == "X" then
            referenceAxis = GLOBAL_COORDINATE.Z
        elseif axis == "Y" then
            referenceAxis = GLOBAL_COORDINATE.X
        else -- Z
            referenceAxis = GLOBAL_COORDINATE.Y
        end
        
        referenceAxis = {referenceAxis[1], referenceAxis[2], referenceAxis[3]}
        rotatedAxis = {rotatedAxis[1], rotatedAxis[2], rotatedAxis[3]}

        euler[i] = Ext.Math.Angle(referenceAxis, rotatedAxis)
    end

    return euler
end

--- @param point Vec2
--- @param rectMin Vec2
--- @param rectMax Vec2
function MathUtils.IsInRect(point, rectMin, rectMax)
    local minX = math.min(rectMin[1], rectMax[1])
    local maxX = math.max(rectMin[1], rectMax[1])
    local minY = math.min(rectMin[2], rectMax[2])
    local maxY = math.max(rectMin[2], rectMax[2])

    return point[1] >= minX and point[1] <= maxX and point[2] >= minY and point[2] <= maxY
end

--- @param childUuid string
--- @param parentUuid string
--- @return number[]|nil relativePosition
function MathUtils.SaveLocalRelativePosOffset(childUuid, parentUuid)
    local childPos = {RBGetPosition(childUuid)}
    local parentPos = {RBGetPosition(parentUuid)}
    local pqx, pqy, pqz, pqw = EntityHelpers.GetQuatRotation(parentUuid)

    if not childPos[1] or not childPos[2] or not childPos[3] or
       not parentPos[1] or not parentPos[2] or not parentPos[3] or
       not pqx or not pqy or not pqz or not pqw then
        return nil
    end

    local delta = Ext.Math.Sub(childPos, parentPos)
    local parentRotInv = Ext.Math.QuatInverse({pqx, pqy, pqz, pqw})
    local localOffset = Ext.Math.QuatRotate(parentRotInv, delta)

    return localOffset
end

--- @param childUuid string
--- @param parentUuid string
--- @return number[]|nil relativeRotation
function MathUtils.SaveLocalRelativeRotOffset(childUuid, parentUuid)
    local cqx, cqy, cqz, cqw = EntityHelpers.GetQuatRotation(childUuid)
    local pqx, pqy, pqz, pqw = EntityHelpers.GetQuatRotation(parentUuid)

    if not cqx or not cqy or not cqz or not cqw or not pqx or not pqy or not pqz or not pqw then
        --Error("Failed to get rotation")
        return nil
    end

    local parentRotInv = Ext.Math.QuatInverse({pqx, pqy, pqz, pqw})
    local relativeQuat = Ext.Math.QuatMul(parentRotInv, {cqx, cqy, cqz, cqw})

    return relativeQuat
end

function MathUtils.SaveLocalRelativeTransform(pivotTransform, worldPos, worldQuat, worldScale)
    if not pivotTransform or not worldPos or not worldQuat then return end
    local px, py, pz = pivotTransform.Translate[1], pivotTransform.Translate[2], pivotTransform.Translate[3]
    local pqx, pqy, pqz, pqw = pivotTransform.RotationQuat[1], pivotTransform.RotationQuat[2], pivotTransform.RotationQuat[3], pivotTransform.RotationQuat[4]

    if not px or not py or not pz or not pqx or not pqy or not pqz or not pqw then
        --Error("Failed to get pivot position or rotation")
        return nil, nil
    end

    local delta = Ext.Math.Sub(worldPos, {px, py, pz})
    local parentRotInv = Ext.Math.QuatInverse({pqx, pqy, pqz, pqw})
    local localOffset = Ext.Math.QuatRotate(parentRotInv, delta)

    local relativeQuat = Ext.Math.QuatMul(parentRotInv, worldQuat)
    relativeQuat = Ext.Math.QuatNormalize(relativeQuat)

    return {
        Translate = {localOffset[1], localOffset[2], localOffset[3]},
        RotationQuat = {relativeQuat[1], relativeQuat[2], relativeQuat[3], relativeQuat[4]},
        Scale = worldScale or {1, 1, 1}
    }
end

--- @param parentUuid string
--- @param posOffset number[]
--- @param rotOffset number[]
--- @return Vec3|nil finalPosition
--- @return Quat|nil finalRotation
function MathUtils.GetLocalRelativeTransformFromGuid(parentUuid, posOffset, rotOffset)
    if not parentUuid then
        Error("Missing parent UUID")
        return nil, nil
    end

    local px, py, pz = RBGetPosition(parentUuid)
    local pqx, pqy, pqz, pqw = EntityHelpers.GetQuatRotation(parentUuid)
    local psx, psy, psz = RBGetScale(parentUuid)

    if not px or not py or not pz or not pqx or not pqy or not pqz or not pqw then
        --Error("Failed to get parent position or rotation")
        return nil, nil
    end

    return MathUtils.GetLocalRelativeTransform(
        {
            Translate = {px, py, pz},
            RotationQuat = {pqx, pqy, pqz, pqw},
            Scale = {psx, psy, psz}
        },
        posOffset,
        rotOffset
    )
end

--- @param transfrom Transform
--- @param posOffset Vec3
--- @param rotOffset Quat
--- @return Vec3|nil finalPosition
--- @return Quat|nil finalRotation
function MathUtils.GetLocalRelativeTransform(transfrom, posOffset, rotOffset)
    local px, py, pz = transfrom.Translate[1], transfrom.Translate[2], transfrom.Translate[3]
    local pqx, pqy, pqz, pqw = transfrom.RotationQuat[1], transfrom.RotationQuat[2], transfrom.RotationQuat[3], transfrom.RotationQuat[4]
    local psx, psy, psz = transfrom.Scale[1], transfrom.Scale[2], transfrom.Scale[3]

    if not px or not py or not pz or not pqx or not pqy or not pqz or not pqw then
        --Error("Failed to get parent position or rotation")
        return nil, nil
    end

    local rotatedOffset = Ext.Math.QuatRotate({pqx, pqy, pqz, pqw}, posOffset)
    local finalPosition = {
        px + rotatedOffset[1] * psx,
        py + rotatedOffset[2] * psy,
        pz + rotatedOffset[3] * psz,
    }
    local finalQuat = Ext.Math.QuatMul({pqx, pqy, pqz, pqw}, rotOffset)
    finalQuat = Ext.Math.QuatNormalize(finalQuat)

    return finalPosition, finalQuat
end

--- @param childUuid string
--- @param parentUuid string
--- @return quat lookAtQuat
function MathUtils.LookAtParent(childUuid, parentUuid)
    local cx, cy, cz = RBGetPosition(childUuid)
    local px, py, pz = RBGetPosition(parentUuid)
    local up = Ext.Math.QuatRotate({RBGetRotation(childUuid)}, GLOBAL_COORDINATE.Y)

    if not cx or not cy or not cz or not px or not py or not pz then
        --Warning("Failed to get position")
        return Quat.Identity()
    end

    local direction = Ext.Math.Normalize({px - cx, py - cy, pz - cz})
    if Ext.Math.Length(direction) < 0.001 then
        --Warning("Direction vector too small")
        return Quat.Identity()
    end

    local quat = MathUtils.DirectionToQuat(direction, up)
    return quat
end

--- @param pivot vec3
--- @param targetTransform Transform
--- @param axis Vec3
--- @param angleRad number
--- @return Transform newTransform
function MathUtils.RotateAroundPivot(pivot, targetTransform, axis, angleRad)
    local pivotPos = Vec3.new(pivot)
    local targetPos = Vec3.new(targetTransform.Translate)

    local toTarget = Ext.Math.Sub(targetPos, pivotPos)
    local rotatedOffset = Ext.Math.QuatRotate(Ext.Math.QuatRotateAxisAngle(Quat.Identity(), axis, angleRad), toTarget)
    local newPos = Ext.Math.Add(pivotPos, rotatedOffset)

    local targetRotQuat = Quat.new(targetTransform.RotationQuat)
    local rotationQuat = Ext.Math.QuatRotateAxisAngle(Quat.Identity(), axis, angleRad)
    local newRotQuat = Ext.Math.QuatMul(rotationQuat, targetRotQuat)
    newRotQuat = Ext.Math.QuatNormalize(newRotQuat)

    return {
        Translate = {newPos[1], newPos[2], newPos[3]},
        RotationQuat = {newRotQuat[1], newRotQuat[2], newRotQuat[3], newRotQuat[4]},
        Scale = {targetTransform.Scale[1], targetTransform.Scale[2], targetTransform.Scale[3]},
    }
end

--- @param pivot vec3
--- @param targetTransform Transform
--- @param rotationQuat quat
--- @return Transform newTransform
function MathUtils.RotateAroundPivotQuat(pivot, targetTransform, rotationQuat)
    local pivotPos = pivot
    local targetPos = targetTransform.Translate

    local toTarget = Ext.Math.Sub(targetPos, pivotPos)
    local rotatedOffset = Ext.Math.QuatRotate(rotationQuat, toTarget)
    local newPos = Ext.Math.Add(pivotPos, rotatedOffset)

    local targetRotQuat = Quat.new(targetTransform.RotationQuat)
    local newRotQuat = Ext.Math.QuatMul(rotationQuat, targetRotQuat)
    newRotQuat = Ext.Math.QuatNormalize(newRotQuat)

    return {
        Translate = {newPos[1], newPos[2], newPos[3]},
        RotationQuat = {newRotQuat[1], newRotQuat[2], newRotQuat[3], newRotQuat[4]},
        --Scale = {targetTransform.Scale[1], targetTransform.Scale[2], targetTransform.Scale[3]},
    }
end

--- @param pivot vec3
--- @param targetTransform Transform
--- @param scaleVec Vec3
--- @return Transform newTransform
function MathUtils.ScaleAroundPivot(pivot, targetTransform, scaleVec)
    local pivotPos = Vec3.new(pivot)
    local targetPos = Vec3.new(targetTransform.Translate)
    local targetScale = Vec3.new(targetTransform.Scale)

    local toTarget = Ext.Math.Sub(targetPos, pivotPos)
    local scaledOffset = Ext.Math.Mul(Ext.Math.Div(toTarget, targetScale), scaleVec)
    local newPos = Ext.Math.Add(pivotPos, scaledOffset)

    return {
        Translate = {newPos[1], newPos[2], newPos[3]},
        RotationQuat = targetTransform.RotationQuat,
        Scale = {scaleVec[1], scaleVec[2], scaleVec[3]},
    }
end

--- @param point Vec3
--- @param boxMin Vec3
--- @param boxMax Vec3
function MathUtils.IsInBoundingBox(point, boxMin, boxMax)
    return point[1] >= boxMin[1] and point[1] <= boxMax[1] and
           point[2] >= boxMin[2] and point[2] <= boxMax[2] and
           point[3] >= boxMin[3] and point[3] <= boxMax[3]
end