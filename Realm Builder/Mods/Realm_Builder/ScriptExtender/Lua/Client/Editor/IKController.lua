local eml = Ext.Math

--- @class IKMovableProxy
--- @field GetWorldTranslate fun(self): vec3
--- @field GetWorldRotation fun(self): quat
--- @field SetWorldTranslate fun(self, pos:vec3)
--- @field SetWorldRotation fun(self, rot:quat)

--- @class IKController
--- @field Target IKMovableProxy
--- @field Joint IKMovableProxy
--- @field Origin IKMovableProxy
--- @field PoleTarget IKMovableProxy
--- @field LengthA number
--- @field LengthB number
--- @field PoleAngle number
--- @field new fun(origin:IKMovableProxy, joint:IKMovableProxy, target:IKMovableProxy, poleTarget:IKMovableProxy, controller:IKMovableProxy?): IKController
IKController = _Class("IKController")

--- @class IKResult
--- @field JointPos vec3
--- @field TargetPos vec3
--- @field PoleDir vec3

--- @param origin IKMovableProxy
--- @param joint IKMovableProxy
--- @param target IKMovableProxy
--- @param poleTarget IKMovableProxy
--- @param controller IKMovableProxy?
function IKController:__init(origin, joint, target, poleTarget, controller)
    self.Target = target
    self.Controller = controller or target
    self.Joint = joint
    self.Origin = origin
    self.PoleTarget = poleTarget

    local originPos = origin:GetWorldTranslate()
    local jointPos = joint:GetWorldTranslate()
    local targetPos = target:GetWorldTranslate()

    self.LengthA = eml.Length(eml.Sub(jointPos, originPos))
    self.LengthB = eml.Length(eml.Sub(targetPos, jointPos))

    self.PoleAngle = 0
end

--- @param originPos vec3
--- @param targetPos vec3
--- @param polePos vec3
--- @param lenA number
--- @param lenB number
--- @param poleAngle number
--- @return IKResult
function IKController.Solve(originPos, targetPos, polePos, lenA, lenB, poleAngle)
    local toTarget = eml.Sub(targetPos, originPos)
    local distC = eml.Length(toTarget)

    distC = math.max(0.0001, math.min(lenA + lenB - 0.0001, distC))
    
    -- law of cosines
    local cosA = (lenA^2 + distC^2 - lenB^2) / (2 * lenA * distC)
    cosA = eml.Clamp(cosA, -1, 1)
    local a = math.acos(cosA)

    local fwd = eml.Div(toTarget, distC)
    
    local toPole = eml.Sub(polePos, originPos)
    local dot = eml.Dot(toPole, fwd)
    local poleDir = eml.Normalize(eml.Sub(toPole, eml.Mul(fwd, dot)))

    if poleAngle ~= 0 then
        local rot = eml.QuatRotateAxisAngle({0,0,0,1}, fwd, poleAngle)
        poleDir = eml.QuatRotate(rot, poleDir)
    end

    fwd = eml.Normalize(fwd)
    poleDir = eml.Normalize(poleDir)

    local jointPos = eml.Add(originPos, eml.Add(eml.Mul(fwd, lenA * math.cos(a)), eml.Mul(poleDir, lenA * math.sin(a))))
    local realTargetPos = eml.Add(jointPos, eml.Normalize(eml.Mul(eml.Sub(targetPos, jointPos), lenB)))

    return {
        JointPos = jointPos,
        TargetPos = realTargetPos,
        PoleDir = poleDir
    }
end

function IKController:Update()
    local originPos = self.Origin:GetWorldTranslate()
    local targetPos = self.Controller:GetWorldTranslate()
    local polePos = self.PoleTarget:GetWorldTranslate()
    local result = IKController.Solve(originPos, targetPos, polePos, self.LengthA, self.LengthB, self.PoleAngle)

    self.Joint:SetWorldTranslate(result.JointPos)
    self.Target:SetWorldTranslate(result.TargetPos)

    local up = result.PoleDir
    local bones = {self.Origin, self.Joint, self.Target}
    local parentsPos = {}
    local childsPos = {}
    for i = 1, #bones - 1 do
        local parent = bones[i]
        local child = bones[i + 1]

        local parentPos = parentsPos[i] or parent:GetWorldTranslate()
        local childPos = childsPos[i] or child:GetWorldTranslate()
        parentsPos[i] = parentPos
        childsPos[i] = childPos

        local fwd = eml.Normalize(eml.Sub(childPos, parentPos))
        local right = eml.Normalize(eml.Cross(up, fwd))
        local realUp = eml.Normalize(eml.Cross(fwd, right))

        local rot = eml.Mat3ToQuat({
            right[1], right[2], right[3], 
            realUp[1], realUp[2], realUp[3],
            fwd[1], fwd[2], fwd[3]
        })

        parent:SetWorldRotation(rot)
    end
end


--#region FABRIKController
--- @class FABRIKController
--- @field Joints IKMovableProxy[]
--- @field Goal IKMovableProxy
--- @field Lengths number[]
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
            return ite
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
        positions[i] = joint:GetWorldTranslate()
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

    for i = 2, #self.Joints do
        self.Joints[i]:SetWorldTranslate(positions[i])
        
        local parent = self.Joints[i-1]
        local dir = eml.Normalize(eml.Sub(positions[i], positions[i-1]))

        local up = {0,1,0}
        if eml.Dot(up, dir) > 0.999 then
            up = {1,0,0}
        end
        local right = eml.Normalize(eml.Cross(up, dir))
        local forward = dir
        local realUp = eml.Normalize(eml.Cross(dir, right))

        local rot = eml.Mat3ToQuat({
            right[1], right[2], right[3], 
            realUp[1], realUp[2], realUp[3],
            forward[1], forward[2], forward[3]
        })

        parent:SetWorldRotation(rot)
    end
end
--#endregion

local function visualizeItem(guid, length)
    local ent = Ext.Entity.Get(guid)
    if not ent then return end

    local visualObj = ent.Visual.Visual.ObjectDescs

    for _, obj in pairs(visualObj) do
        if obj.Renderable.ActiveMaterial.MaterialName == GIZMO_TEXTURE.Z then
            obj.Renderable.ActiveMaterial:SetVector4("Color", {0,0,1,1})
            obj.Renderable:SetWorldScale({1,1,length/0.9 or 1})
        else
            obj.Renderable.ActiveMaterial:SetVector4("Color", {0,0,0,0})
            obj.Renderable:SetWorldScale({0,0,0})
        end
    end
end

local spawnId = RB_PROP_AXIS_FX
local controllerItem = "LOOT_TEST_Toy_Ball_Small_Scratch_10df0443-eef7-4765-be17-ce2dbb8b3eb5"
RegisterConsoleCommand("ik_test", function ()
    local bones = {}
    local playerPos = _C().Transform.Transform.Translate
    local args = {
        spawnId, playerPos[1], playerPos[2], playerPos[3], 0,0, ""
    }

    for i=1,5 do
        if i > 3 then -- poleTarget , controller 
            args[1] = controllerItem
        end
        NetChannel.CallOsiris:RequestToServer({
            Function = "CreateAt",
            Args = args
        }, function (response)
            bones[i] = response[1]
        end)
    end

    local function setupIK()
        local transform = {
            Translate = playerPos,
            Rotate = Quat.Identity(),
            Scale = Vec3(1,1,1)
        }

        local origin = ItemMovableProxy.new(bones[1])
        local joint = ItemMovableProxy.new(bones[2])
        local target = ItemMovableProxy.new(bones[3])
        local poleTarget = ItemMovableProxy.new(bones[4])
        local controller = ItemMovableProxy.new(bones[5])

        --- @type Transform[]
        local transforms = {}
        for i = 1, 5 do
            transforms[i] = RBUtils.DeepCopy(transform)
        end

        local boneLength = 0.9
        transforms[2].Translate = transforms[2].Translate + Vec3(0, boneLength, 0) -- joint
        transforms[3].Translate = transforms[3].Translate + Vec3(0, 2 * boneLength, 0) -- target
        transforms[4].Translate = transforms[4].Translate + Vec3(1 * boneLength, 1 * boneLength, 0) -- pole target
        transforms[5].Translate = transforms[5].Translate + Vec3(0, 3 * boneLength, 0) -- controller

        local proxies = {origin, joint, target, poleTarget, controller}
        for i, proxy in ipairs(proxies) do
            proxy:SetTransform(transforms[i])
        end

        Timer:After(1000, function ()
            for i, bone in pairs(bones) do
                if i > 3 then break end
                visualizeItem(bone, boneLength)
            end
            --- @diagnostic disable-next-line
            local ik = IKController.new(origin, joint, target, poleTarget, controller)

            Timer:Every(100, function ()
                ik:Update()
            end)
        end)
    end

    RBUtils.WaitUntil(function () return #bones == 5 end, function ()
        Timer:After(100, setupIK)
    end)
end)

RegisterConsoleCommand("fabrik_test", function (_, args)
    local parsed = RBStringUtils.Split(args, ",")
    local jointsCnt = math.floor(tonumber(parsed[1]) or 5)
    local iteLimit = math.floor(tonumber(parsed[2]) or 10)
    local bones = {}
    _P("Spawning bones for FABRIK test...")
    _P("Params:")
    _P("Joints count: "..jointsCnt)
    _P("Iteration limit: "..iteLimit)

    local playerPos = _C().Transform.Transform.Translate
    local commandArgs = {
        spawnId, playerPos[1], playerPos[2], playerPos[3], 0,0, ""
    }

    for i=1,jointsCnt do
        if i == jointsCnt then
            commandArgs[1] = controllerItem
        end
        NetChannel.CallOsiris:RequestToServer({
            Function = "CreateAt",
            Args = commandArgs
        }, function (response)
            bones[i] = response[1]
        end)
    end

    local function setupFABRIK()
        _P("Setting up FABRIK controller...")
        local joints = {}
        local transform = {
            Translate = playerPos,
            Rotate = Quat.Identity(),
            Scale = Vec3(1,1,1)
        }

        local boneLength = 0.9
        for i = 1, jointsCnt do
            joints[i] = ItemMovableProxy.new(bones[i])
            local jointTransform = RBUtils.DeepCopy(transform)
            jointTransform.Translate = jointTransform.Translate + Vec3(0, (i - 1) * boneLength, 0)
            joints[i]:SetTransform(jointTransform)
        end

        Timer:After(1000, function ()
            local controller = joints[#joints]
            joints[#joints] = nil
            local fabrik = FABRIKController.new(joints, controller)
            fabrik.IterationLimit = iteLimit

            for i, bone in pairs(bones) do
                if i == jointsCnt then break end
                visualizeItem(bone, boneLength)
            end

            Timer:Every(10, function ()
                fabrik:Update()
            end)

        end)
    end

    RBUtils.WaitUntil(function () return #bones == jointsCnt end, function ()
        Timer:After(100, setupFABRIK)
    end)
end, "Tests FABRIK IK solver with specified joints count and iteration limit. Usage: fabrik_test <jointsCount>,<iterationLimit>")