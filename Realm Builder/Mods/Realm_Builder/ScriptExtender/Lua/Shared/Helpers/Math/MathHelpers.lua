-- I hate linear algebra

--- @param position Vec3
--- @param rotationQuat quat
--- @param scale Vec3
--- @return number[]
function BuildModelMatrix(position, rotationQuat, scale)
    local rotationMat = Matrix.new(Ext.Math.QuatToMat4(rotationQuat))
    local translateMat = Matrix.new(Ext.Math.BuildTranslation(position))
    local scaleMat = Matrix.new(Ext.Math.BuildScale(scale))
    return translateMat * rotationMat * scaleMat
end

---@param transform Transform
---@return number[]
function BuildModelMatrixFromTransform(transform)
    local transalte = Vec3.new(transform.Translate)
    local rotation = transform.RotationQuat
    local scale = Vec3.new(transform.Scale)

    return BuildModelMatrix(transalte, rotation, scale)
end

LHCS = {
    X = {1, 0, 0},
    Y = {0, 1, 0},
    Z = {0, 0, 1},
}

for k, v in pairs(LHCS) do
    LHCS[k] = Vec3.new(v)
end

GLOBAL_COORDINATE = LHCS

--- make orthonormal basis from a normal vector
---@param n Vec3
---@return number[] u
---@return number[] v
---@return number[] n
function MakeOrthonormalBasis(n)
    local a
    if n[1] < 0.9 then
        a = GLOBAL_COORDINATE.X
    else
        a = GLOBAL_COORDINATE.Y
    end
    local u = Ext.Math.Cross(a, n)
    if Ext.Math.Length(u) < 0.001 then
        a = GLOBAL_COORDINATE.Y
        u = Ext.Math.Cross(a, n)
    end
    u = Ext.Math.Normalize(u)

    local v = Ext.Math.Cross(n, u)

    return u, v, n
end

---@param quat vec4
---@param axis "X"|"Y"|"Z"
---@return vec4 Flipped
function FlipAxis(quat, axis)
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

function GetCenterPosition(uuids)
    local positions = {}
    if type(uuids) == "string" then
        uuids = {uuids}
    end
    
    for _, uuid in ipairs(uuids) do
        local x, y, z = CGetPosition(uuid)
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
--- @param forwardAxis? TransformAxis|Vec3
--- @return quat
function DirectionToQuat(direction, up, forwardAxis)
    direction = Ext.Math.Normalize(direction)
    up = up and Ext.Math.Normalize(up) or GLOBAL_COORDINATE.Y
    forwardAxis = forwardAxis and type(forwardAxis) == "string" and forwardAxis:upper() or forwardAxis or "Z"

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

    if forwardAxis ~= "Z" then
        if forwardAxis == "X" then
            quat = Ext.Math.QuatRotateAxisAngle(quat, GLOBAL_COORDINATE.Y, -math.pi/2)
        elseif forwardAxis == "Y" then
            quat = Ext.Math.QuatRotateAxisAngle(quat, GLOBAL_COORDINATE.X, math.pi/2)
        elseif type(forwardAxis) == "table" and #forwardAxis == 3 then
            local targetForward = Ext.Math.Normalize(forwardAxis)
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
            Warning("Invalid forwardAxis: " .. tostring(forwardAxis))
        end
    end

    return Quat.new(Ext.Math.QuatNormalize(quat))
end

--- @param quat quat
--- @return Vec3 euler in degrees
function QuatToEuler(quat)
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

        euler[i] = Ext.Math.Angle(referenceAxis, rotatedAxis)
    end

    return euler
end

--- @param point Vec2
--- @param rectMin Vec2
--- @param rectMax Vec2
function IsInRect(point, rectMin, rectMax)
    local minX = math.min(rectMin.x, rectMax.x)
    local maxX = math.max(rectMin.x, rectMax.x)
    local minY = math.min(rectMin.y, rectMax.y)
    local maxY = math.max(rectMin.y, rectMax.y)

    return point.x >= minX and point.x <= maxX and point.y >= minY and point.y <= maxY
end

--- @param childUuid string
--- @param parentUuid string
--- @return number[]|nil relativePosition
function SaveLocalRelativePosOffset(childUuid, parentUuid)
    local childPos = {CGetPosition(childUuid)}
    local parentPos = {CGetPosition(parentUuid)}
    local pqx, pqy, pqz, pqw = GetQuatRotation(parentUuid)

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
function SaveLocalRelativeRotOffset(childUuid, parentUuid)
    local cqx, cqy, cqz, cqw = GetQuatRotation(childUuid)
    local pqx, pqy, pqz, pqw = GetQuatRotation(parentUuid)

    if not cqx or not cqy or not cqz or not cqw or not pqx or not pqy or not pqz or not pqw then
        --Error("Failed to get rotation")
        return nil
    end

    local parentRotInv = Ext.Math.QuatInverse({pqx, pqy, pqz, pqw})
    local relativeQuat = Ext.Math.QuatMul(parentRotInv, {cqx, cqy, cqz, cqw})

    return relativeQuat
end


--- @param parentUuid string
--- @param posOffset number[]
--- @param rotOffset number[]
--- @return Vec3|nil finalPosition
--- @return Quat|nil finalRotation
function GetLocalRelativeTransformFromGuid(parentUuid, posOffset, rotOffset)
    if not parentUuid then
        Error("Missing parent UUID")
        return nil, nil
    end

    local px, py, pz = CGetPosition(parentUuid)
    local pqx, pqy, pqz, pqw = GetQuatRotation(parentUuid)
    local psx, psy, psz = CGetScale(parentUuid)

    if not px or not py or not pz or not pqx or not pqy or not pqz or not pqw then
        --Error("Failed to get parent position or rotation")
        return nil, nil
    end

    return GetLocalRelativeTransform(
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
function GetLocalRelativeTransform(transfrom, posOffset, rotOffset)
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
function LookAtParent(childUuid, parentUuid)
    local cx, cy, cz = CGetPosition(childUuid)
    local px, py, pz = CGetPosition(parentUuid)
    local up = Ext.Math.QuatRotate({CGetRotation(childUuid)}, GLOBAL_COORDINATE.Y)

    if not cx or not cy or not cz or not px or not py or not pz then
        --Warning("Failed to get position")
        return Quat.Identity()
    end

    local direction = Ext.Math.Normalize({px - cx, py - cy, pz - cz})
    if Ext.Math.Length(direction) < 0.001 then
        --Warning("Direction vector too small")
        return Quat.Identity()
    end

    local quat = DirectionToQuat(direction, up)
    return quat
end

--- @param pivot vec3
--- @param targetTransform Transform
--- @param axis Vec3
--- @param angleRad number
--- @return Transform newTransform
function RotateAroundPivot(pivot, targetTransform, axis, angleRad)
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

function ScaleAroundPivot(pivot, targetTransform, scaleVec)
    local pivotPos = Vec3.new(pivot)
    local targetPos = Vec3.new(targetTransform.Translate)

    local toTarget = Ext.Math.Sub(targetPos, pivotPos)
    local scaledOffset = {
        toTarget[1] * scaleVec[1],
        toTarget[2] * scaleVec[2],
        toTarget[3] * scaleVec[3],
    }
    local newPos = Ext.Math.Add(pivotPos, scaledOffset)

    return {
        Translate = {newPos[1], newPos[2], newPos[3]},
        RotationQuat = targetTransform.RotationQuat,
        Scale = {scaleVec[1], scaleVec[2], scaleVec[3]},
    }
end

function IsInBoundingBox(point, boxMin, boxMax)
    return point[1] >= boxMin[1] and point[1] <= boxMax[1] and
           point[2] >= boxMin[2] and point[2] <= boxMax[2] and
           point[3] >= boxMin[3] and point[3] <= boxMax[3]
end