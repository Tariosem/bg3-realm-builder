local eml = Ext.Math

local add = eml.Add
local sub = eml.Sub
local normalize = eml.Normalize
local cross = eml.Cross
local dot = eml.Dot

local function lookAt(targetPos, originPos, up)
    local forward = normalize(sub(targetPos, originPos))

    if dot(forward, up) > 0.999 then
        up = math.abs(forward[1]) < 0.1 and {1,0,0} or {0,0,1}
    end

    local right = normalize(cross(up, forward))
    local realUp = normalize(cross(forward, right))

    return eml.Mat3ToQuat({
        right[1], right[2], right[3], 
        realUp[1], realUp[2], realUp[3],
        forward[1], forward[2], forward[3]
    })
end

--- bone orientation in the model is different from the forward direction used for lookAt 
--- need to apply a fixed rotation to align them
--- and it's mirrored for left and right side, so also need to flip the rotation for left side
--- or just update rotation relatively
local fixQuat = eml.QuatRotateAxisAngle({0,0,0,1}, {0,0,1}, math.rad(90))
fixQuat = eml.QuatRotateAxisAngle(fixQuat, {0,1,0}, math.rad(-90))

local fixQuatLeft = eml.QuatRotateAxisAngle(fixQuat, {0,0,1}, math.rad(180))

local function applyFix(quat, isLeft)
    return eml.QuatMul(quat, isLeft and fixQuatLeft or fixQuat)
end

--[[
--- @class IKMovableProxy
--- @field GetWorldTranslate fun(self): vec3
--- @field GetWorldRotation fun(self): quat
--- @field SetWorldTranslate fun(self, pos:vec3)
--- @field SetWorldRotation fun(self, rot:quat)
]]

local commandArgs = {
    RB_PROP_AXIS_FX, 0,0,0, 0,0, ""
}
--- @param pos vec3
--- @param onComplete fun(guid:GUIDSTRING)
local function drawPoint(pos, onComplete)
    commandArgs[2] = pos[1]
    commandArgs[3] = pos[2]
    commandArgs[4] = pos[3]
    NetChannel.CallOsiris:RequestToServer({
        Function = "CreateAt",
        Args = commandArgs
    }, function (response)
        onComplete(response[1])
    end)
end

--- @alias IKMovableProxy RB_MovableProxy

--- @class IKControllerBase
--- @field UpdatePosition boolean
--- @field UpdateRotation boolean
--- @field UpdateRotationRelatively boolean
--- @field debugPoints table<number, GUIDSTRING>

--- @class TwoBoneIKController : IKControllerBase
--- @field Target IKMovableProxy
--- @field Joint IKMovableProxy
--- @field Origin IKMovableProxy
--- @field PoleTarget IKMovableProxy
--- @field LengthA number
--- @field LengthB number
--- @field PoleAngle number -- in radians
--- @field Controller IKMovableProxy
--- @field IsLeft boolean
--- @field Update fun(self)
--- @field Solve fun(originPos:vec3, targetPos:vec3, polePos:vec3, lenA:number, lenB:number, poleAngle:number): IKResult
--- @field new fun(origin:IKMovableProxy, joint:IKMovableProxy, target:IKMovableProxy, poleTarget:IKMovableProxy, controller:IKMovableProxy?): TwoBoneIKController
TwoBoneIKController = {}

--- @class IKResult
--- @field JointPos vec3
--- @field TargetPos vec3
--- @field PoleDir vec3

--- @param origin IKMovableProxy
--- @param joint IKMovableProxy
--- @param target IKMovableProxy
--- @param poleTarget IKMovableProxy
--- @param controller IKMovableProxy?
function TwoBoneIKController.new(origin, joint, target, poleTarget, controller)
    local self = setmetatable({}, {__index = TwoBoneIKController})
    self.Target = target
    self.Controller = controller or target
    self.Joint = joint
    self.Origin = origin
    self.PoleTarget = poleTarget
    self.UpdatePosition = false
    self.UpdateRotation = true
    self.UpdateRotationRelatively = true

    self.debugPoints = {}

    local originPos = origin:GetWorldTranslate()
    local jointPos = joint:GetWorldTranslate()
    local targetPos = target:GetWorldTranslate()

    self.LengthA = eml.Length(eml.Sub(jointPos, originPos))
    self.LengthB = eml.Length(eml.Sub(targetPos, jointPos))

    self.PoleAngle = 0
    return self
end

--- @param originPos vec3
--- @param targetPos vec3
--- @param polePos vec3
--- @param lenA number
--- @param lenB number
--- @param poleAngle number
--- @return IKResult
function TwoBoneIKController.Solve(originPos, targetPos, polePos, lenA, lenB, poleAngle)
    local toTarget = eml.Sub(targetPos, originPos)
    local distC = eml.Length(toTarget)

    distC = math.max(0.0001, math.min(lenA + lenB - 0.0001, distC))

    -- law of cosines
    local cosA = (lenA^2 + distC^2 - lenB^2) / (2 * lenA * distC)
    cosA = eml.Clamp(cosA, -1, 1)
    local a = math.acos(cosA)

    local fwd = eml.Div(toTarget, distC)

    local toPole = eml.Sub(polePos, originPos)
    local dP = eml.Dot(toPole, fwd)
    local poleDir = eml.Normalize(eml.Sub(toPole, eml.Mul(fwd, dP)))

    if poleAngle ~= 0 then
        local rot = eml.QuatRotateAxisAngle({0,0,0,1}, fwd, poleAngle)
        poleDir = eml.QuatRotate(rot, poleDir)
    end

    fwd = eml.Normalize(fwd)
    poleDir = eml.Normalize(poleDir)

    local jointPos = eml.Add(originPos, eml.Add(eml.Mul(fwd, lenA * math.cos(a)), eml.Mul(poleDir, lenA * math.sin(a))))
    local realTargetPos = eml.Add(jointPos, eml.Mul(eml.Normalize(eml.Sub(targetPos, jointPos)), lenB))

    return {
        JointPos = jointPos,
        TargetPos = realTargetPos,
        PoleDir = poleDir
    }
end

function TwoBoneIKController:Update()
    local originTransform = self.Origin:GetTransform()
    local poleTransform = self.PoleTarget:GetTransform()
    local goalTransform = self.Controller:GetTransform()

    local result = TwoBoneIKController.Solve(originTransform.Translate, goalTransform.Translate, poleTransform.Translate, self.LengthA, self.LengthB, self.PoleAngle)

    if self.UpdatePosition then
        self.Joint:SetWorldTranslate(result.JointPos)
        self.Target:SetWorldTranslate(result.TargetPos)
    end

    if not self.UpdateRotation then return end

    local p1 = result.PoleDir
    local p2 = normalize(sub(result.TargetPos, originTransform.Translate))
    local up = normalize(cross(p2, p1))

    if self.UpdateRotationRelatively then
        local jointTransform = self.Joint:GetTransform()
        local targetTransform = self.Target:GetTransform()

        local fwdA = normalize(sub(jointTransform.Translate, originTransform.Translate))
        local fwdB = normalize(sub(targetTransform.Translate, jointTransform.Translate))

        local newFwdA = normalize(sub(result.JointPos, originTransform.Translate))

        local deltaRotA = eml.QuatFromToRotation(fwdA, newFwdA)
        local originRot = eml.QuatMul(deltaRotA, originTransform.RotationQuat)

        self.Origin:SetWorldRotation(originRot)

        local newFwdB = normalize(sub(result.TargetPos, result.JointPos))

        local deltaRotB = eml.QuatFromToRotation(fwdB, newFwdB)
        local jointRot = eml.QuatMul(deltaRotB, jointTransform.RotationQuat)

        self.Joint:SetWorldRotation(jointRot)

        return
    end

    local originRot = lookAt(result.JointPos, originTransform.Translate, up)
    local jointRot = lookAt(result.TargetPos, result.JointPos, up)

    originRot = applyFix(originRot, self.IsLeft)
    jointRot = applyFix(jointRot, self.IsLeft)

    self.Origin:SetWorldRotation(originRot)
    self.Joint:SetWorldRotation(jointRot)
end

function TwoBoneIKController:RegetLength()
    local originPos = self.Origin:GetWorldTranslate()
    local jointPos = self.Joint:GetWorldTranslate()
    local targetPos = self.Target:GetWorldTranslate()

    self.LengthA = eml.Length(eml.Sub(jointPos, originPos))
    self.LengthB = eml.Length(eml.Sub(targetPos, jointPos))
end

--#region FABRIKController
--- @class FABRIKController : IKControllerBase
--- @field Joints IKMovableProxy[]
--- @field Goal IKMovableProxy
--- @field Lengths number[]
--- @field IterationLimit number
--- @field IterationThreshold number
--- @field Solve fun(positions:vec3[], lengths:number[], targetPos:vec3, originPos:vec3, threshold:number, iterationLimit:number): number?
--- @field Update fun(self)
--- @field new fun(joints:IKMovableProxy[], targetProxy:IKMovableProxy?): FABRIKController
FABRIKController = {}

--- @param joints IKMovableProxy[]
--- @param goal IKMovableProxy?
function FABRIKController.new(joints, goal)
    local self = setmetatable({}, {__index = FABRIKController})
    self.Joints = joints
    self.Goal = goal or joints[#joints]
    self.Lengths = {}
    self.IterationLimit = 10
    self.IterationThreshold = 0.01
    self.UpdatePosition = false
    self.UpdateRotation = true
    self.UpdateRotationRelatively = true

    self.debugPoints = {}

    for i, joint in ipairs(joints) do
        drawPoint(joint:GetWorldTranslate(), function (guid)
            self.debugPoints[i] = guid
        end)
    end

    for i = 1, #joints - 1 do
        local p = joints[i]:GetWorldTranslate()
        local c = joints[i + 1]:GetWorldTranslate()
        self.Lengths[i] = eml.Length(eml.Sub(c, p))
    end

    return self
end


--- @param positions vec3[]
--- @param lengths number[]
--- @param targetPos vec3
function FABRIKController.ForwardReaching(positions, lengths, targetPos)
    positions[#positions] = targetPos

    for i = #positions - 1, 1, -1 do
        local dir = eml.Normalize(eml.Sub(positions[i], positions[i+1]))
        positions[i] = eml.Add(positions[i+1], eml.Mul(dir, lengths[i]))
    end
end

--- @param positions vec3[]
--- @param lengths number[]
--- @param originPos vec3
function FABRIKController.BackwardReaching(positions, lengths, originPos)
    positions[1] = originPos

    for i = 1, #positions - 1 do
        local dir = eml.Normalize(eml.Sub(positions[i+1], positions[i]))
        positions[i+1] = eml.Add(positions[i], eml.Mul(dir, lengths[i]))
    end
end

--- @param positions vec3[]
--- @param lengths number[] 
--- @param targetPos vec3
--- @param originPos vec3
--- @param threshold number
--- @param iterationLimit number
--- @return number? iterations used or nil if failed to converge
function FABRIKController.Solve(positions, lengths, targetPos, originPos, threshold, iterationLimit)
    local ite = 0
    while ite < iterationLimit do
        local endEffector = positions[#positions]
        if eml.Length(eml.Sub(endEffector, targetPos)) <= threshold then
            return ite -- converged
        end
        
        FABRIKController.ForwardReaching(positions, lengths, targetPos)
        FABRIKController.BackwardReaching(positions, lengths, originPos)
        ite = ite + 1
    end

    return nil
end

function FABRIKController:Update()
    local originPos = self.Joints[1]:GetWorldTranslate()
    local goalPos = self.Goal:GetWorldTranslate()
    --- @type Vec3[]
    local positions = {}
    for i, joint in ipairs(self.Joints) do
        local transform = joint:GetTransform()
        positions[i] = transform.Translate
    end

    local toGoal = eml.Sub(goalPos, originPos)
    local totalLength = 0
    for _, len in ipairs(self.Lengths) do totalLength = totalLength + len end

    if eml.Length(toGoal) > totalLength then -- unreachable, stretch towards the goal
        local dir = eml.Normalize(toGoal)
        for i = 2, #positions do
            positions[i] = eml.Add(positions[i-1], eml.Mul(dir, self.Lengths[i-1]))
        end
    else
        FABRIKController.Solve(positions, self.Lengths, goalPos, originPos, self.IterationThreshold, self.IterationLimit)
    end

    --- @param i integer
    --- @param transform Transform
    local function updateDebugPoint(i, transform)
        local scale = self.Lengths[i-1]/0.9 or 1
        local scale = {scale, scale, scale}
        if self.debugPoints[i] then
            NetChannel.SetTransform:RequestToServer({
                Guid = self.debugPoints[i],
                Transforms = {
                    [self.debugPoints[i]] = transform,
                }
            }, function (response)
                local visual = Ext.Entity.Get(self.debugPoints[i - 1]).Visual
                if visual and visual.Visual.ObjectDescs then
                    for _, object in pairs(visual.Visual.ObjectDescs) do
                        object.Renderable:SetWorldScale(scale)
                    end
                end
            end)
        end
    end

    local up = {0,-1,0}
    --- @type table<integer, Transform>
    local boneTransformCache = {}
    for i = 2, #self.Joints do
        if self.UpdatePosition then
            self.Joints[i]:SetWorldTranslate(positions[i])
        end

        if not self.UpdateRotation then goto continue end

        local parent = self.Joints[i-1]

        if self.UpdateRotationRelatively then
            boneTransformCache[i - 1] = boneTransformCache[i - 1] or parent:GetTransform()
            local parentTransform = boneTransformCache[i - 1]
            boneTransformCache[i] = boneTransformCache[i] or self.Joints[i]:GetTransform()
            local jointTransform = boneTransformCache[i]

            local fwdA = eml.Normalize(eml.Sub(jointTransform.Translate, parentTransform.Translate))
            local newFwdA = eml.Normalize(eml.Sub(positions[i], positions[i-1]))

            local deltaRotA = eml.QuatFromToRotation(fwdA, newFwdA)
            local parentRot = eml.QuatMul(deltaRotA, parentTransform.RotationQuat)

            parent:SetWorldRotation(parentRot)

            if self.debugPoints and self.debugPoints[i - 1] then
                updateDebugPoint(i - 1, {Translate = positions[i - 1], RotationQuat = parentRot})
            end
   
            goto continue
        end
        
        local rot = lookAt(positions[i], positions[i-1], up)

        rot = eml.QuatMul(rot, fixQuat)
        rot = eml.QuatRotateAxisAngle(rot, {1,0,0}, math.rad(-90))

        parent:SetWorldRotation(rot)

        if self.debugPoints and self.debugPoints[i - 1] then
            updateDebugPoint(i - 1, {Translate = positions[i - 1], RotationQuat = rot})
        end
        ::continue::
    end
end
--#endregion