--- @class IKController
--- @field Target RB_MovableProxy
--- @field Joint RB_MovableProxy
--- @field Origin RB_MovableProxy
--- @field PoleTarget RB_MovableProxy
--- @field LengthA number
--- @field LengthB number
--- @field PoleAngle number
--- @field new fun(origin:RB_MovableProxy, joint:RB_MovableProxy, target:RB_MovableProxy, poleTarget:RB_MovableProxy): IKController
IKController = _Class("IKController")



function IKController:__init(origin, joint, target, poleTarget)
    self.Target = target
    self.Joint = joint
    self.Origin = origin
    self.PoleTarget = poleTarget

    local originPos = origin:GetWorldTranslate()
    local jointPos = joint:GetWorldTranslate()
    local targetPos = target:GetWorldTranslate()

    self.LengthA = (jointPos - originPos):Length()
    self.LengthB = (targetPos - jointPos):Length()
    self.PoleAngle = 0
end

function IKController:SolveIK()
    local originPos = self.Origin:GetWorldTranslate()
    local targetPos = self.Target:GetWorldTranslate()
    local polePos = self.PoleTarget:GetWorldTranslate()

    local toTarget = targetPos - originPos
    local distC = toTarget:Length()
    local lenA = self.LengthA
    local lenB = self.LengthB

    distC = math.max(0.0001, math.min(lenA + lenB - 0.0001, distC))
    
    local cosAlpha = (lenA^2 + distC^2 - lenB^2) / (2 * lenA * distC)
    cosAlpha = math.max(-1, math.min(1, cosAlpha))
    local alpha = math.acos(cosAlpha)

    local fwd = toTarget / distC
    
    local toPole = polePos - originPos
    local dot = toPole:Dot(fwd)
    local poleDir = (toPole - fwd * dot):Normalize()

    local poleAngle = self.PoleAngle or 0

    if poleAngle ~= 0 then
        local rot = Ext.Math.QuatRotateAxisAngle(Quat.Identity(), fwd, poleAngle)
        poleDir = Quat.Rotate(rot, poleDir)
    end

    local jointPos = originPos + (fwd * (lenA * math.cos(alpha))) + (poleDir * (lenA * math.sin(alpha)))
    
    return jointPos, poleDir
end

function IKController:Update()
    local jointPos, poleDir = self:SolveIK()
    self.Joint:SetWorldTranslate(jointPos)

    local up = poleDir
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

        local rot = MathUtils.LookAt(parentPos, childPos, up)
        parent:SetWorldRotation(rot)
    end
end

--- @class FABRIKController
--- @field Joints RB_MovableProxy[]
--- @field Goal RB_MovableProxy
--- @field Lengths number[]
--- @field new fun(joints:RB_MovableProxy[], targetProxy:RB_MovableProxy?): FABRIKController
FABRIKController = _Class("FABRIKController")

--- @param joints RB_MovableProxy[]
--- @param targetProxy RB_MovableProxy?
function FABRIKController:__init(joints, targetProxy)
    self.Joints = joints
    self.Goal = targetProxy or joints[#joints]
    self.Lengths = {}
    self.IterationLimit = 10
    self.IterationThreshold = 0.01

    for i = 1, #joints - 1 do
        local p = joints[i]:GetWorldTranslate()
        local c = joints[i + 1]:GetWorldTranslate()
        self.Lengths[i] = (c - p):Length()
    end
end

function FABRIKController:ForwardReaching(positions, targetPos)
    positions[#positions] = targetPos

    for i = #positions - 1, 1, -1 do
        local dir = (positions[i] - positions[i+1]):Normalize()
        positions[i] = positions[i+1] + dir * self.Lengths[i]
    end
end

function FABRIKController:BackwardReaching(positions, originPos)
    positions[1] = originPos

    for i = 1, #positions - 1 do
        local dir = (positions[i+1] - positions[i]):Normalize()
        positions[i+1] = positions[i] + dir * self.Lengths[i]
    end
end

function FABRIKController:Update()
    local originPos = self.Joints[1]:GetWorldTranslate()
    local goalPos = self.Goal:GetWorldTranslate()
    local positions = {}
    for i, joint in ipairs(self.Joints) do
        positions[i] = joint:GetWorldTranslate()
    end

    local toGoal = goalPos - originPos
    local totalLength = 0
    for _, len in ipairs(self.Lengths) do totalLength = totalLength + len end

    if toGoal:Length() > totalLength then
        local dir = toGoal:Normalize()
        for i = 2, #positions do
            positions[i] = positions[i-1] + dir * self.Lengths[i-1]
        end
    else
        local ite = 0
        while (positions[#positions] - goalPos):Length() > self.IterationThreshold
              and ite < self.IterationLimit do
            
            self:ForwardReaching(positions, goalPos)
            self:BackwardReaching(positions, originPos)
            ite = ite + 1
        end
    end

    for i = 2, #self.Joints do
        self.Joints[i]:SetWorldTranslate(positions[i])
        
        local parent = self.Joints[i-1]
        local dir = (positions[i] - positions[i-1]):Normalize()
        local rot = MathUtils.DirectionToQuat(dir, Vec3(0,1,0))
        parent:SetWorldRotation(rot)
    end
end

local spawnId = RB_PROP_AXIS_FX
local grabble = "LOOT_TEST_Toy_Ball_Small_Scratch_10df0443-eef7-4765-be17-ce2dbb8b3eb5"
RegisterConsoleCommand("ik_test", function ()
    local bones = {}
    local lines = {}
    local playerPos = _C().Transform.Transform.Translate
    local args = {
        spawnId, playerPos[1], playerPos[2], playerPos[3], 0,0, ""
    }

    for i=1,4 do
        if i == 4 then
            args[1] = grabble
        end
        NetChannel.CallOsiris:RequestToServer({
            Function = "CreateAt",
            Args = args
        }, function (response)
            bones[i] = response[1]
        end)
    end

    local function setupIK()
        _D(bones)
        local transform = {
            Translate = playerPos,
            Rotate = Quat.Identity(),
            Scale = Vec3(1,1,1)
        }

        local origin = ItemMovableProxy.new(bones[1])
        local joint = ItemMovableProxy.new(bones[2])
        local target = ItemMovableProxy.new(bones[3])
        local poleTarget = ItemMovableProxy.new(bones[4])

        --- @type Transform[]
        local transforms = {}
        for i = 1, 4 do
            transforms[i] = RBUtils.DeepCopy(transform)
        end

        transforms[2].Translate = transforms[2].Translate + Vec3(0, 1, 0)
        transforms[3].Translate = transforms[3].Translate + Vec3(0, 2, 0)
        transforms[4].Translate = transforms[4].Translate + Vec3(1, 1, 0)

        local proxies = {origin, joint, target, poleTarget}
        for i, proxy in ipairs(proxies) do
            proxy:SetTransform(transforms[i])
        end

        for i = 1, 2 do
            local form = proxies[i]
            local to = proxies[i + 1]
            NetChannel.Visualize:RequestToServer({
                Type = "Line",
                Position = form:GetWorldTranslate(),
                EndPosition = to:GetWorldTranslate(),
                Duration = -1,
            }, function (response)
                lines[i] = response[1]
            end)
        end


        local ik = IKController.new(origin, joint, target, poleTarget)
        ik.LengthA = 1
        ik.LengthB = 1
        ik.PoleAngle = 0

        Timer:Every(10, function ()
            ik:Update()

            local originPos = origin:GetWorldTranslate()
            local jointPos = joint:GetWorldTranslate()
            local targetPos = target:GetWorldTranslate()
            local line1Dir = (originPos - jointPos):Normalize()
            local line2Dir = (jointPos - targetPos):Normalize()

            local line1Quat = MathUtils.DirectionToQuat(line1Dir, Vec3(0,1,0))
            local line2Quat = MathUtils.DirectionToQuat(line2Dir, Vec3(0,1,0))

            local line1Scale = Vec3(0.1,0.1,(jointPos - originPos):Length() / 10)
            local line2Scale = Vec3(0.1,0.1,(targetPos - jointPos):Length() / 10)

            NetChannel.SetTransform:SendToServer({
                Guid = lines,
                Transforms = {
                    [lines[1]] = {
                        Translate = originPos,
                        RotationQuat = line1Quat,
                        Scale = line1Scale
                    },
                    [lines[2]] = {
                        Translate = jointPos,
                        RotationQuat = line2Quat,
                        Scale = line2Scale
                    }
                }
            })

        end)
    end

    RBUtils.WaitUntil(function () return #bones == 4 end, function ()
        Timer:After(100, setupIK)
    end)
end)

RegisterConsoleCommand("fabrik_test", function(cmd, args)
    local args = RBStringUtils.Split(args, ",")
    local jointsCnt = tonumber(args[1]) or 5
    local iteLimit = tonumber(args[2]) or 20
    local bones = {}
    _P("Spawning bones for FABRIK test...")
    _P("Params:")
    _P("Joints count: "..jointsCnt)
    _P("Iteration limit: "..iteLimit)

    local playerPos = _C().Transform.Transform.Translate
    local args = {
        spawnId, playerPos[1], playerPos[2], playerPos[3], 0,0, ""
    }

    for i=1,jointsCnt do
        if i == jointsCnt then
            args[1] = grabble
        end
        NetChannel.CallOsiris:RequestToServer({
            Function = "CreateAt",
            Args = args
        }, function (response)
            bones[i] = response[1]
        end)
    end

    local function setupFABRIK()
        local joints = {}
        local transform = {
            Translate = playerPos,
            Rotate = Quat.Identity(),
            Scale = Vec3(1,1,1)
        }

        for i = 1, jointsCnt do
            joints[i] = ItemMovableProxy.new(bones[i])
            local jointTransform = RBUtils.DeepCopy(transform)
            jointTransform.Translate = jointTransform.Translate + Vec3(0, (i - 1) * 0.9, 0)
            joints[i]:SetTransform(jointTransform)
        end

        local lines = {}
        for i = 1, jointsCnt - 2 do
            local form = joints[i]
            local to = joints[i + 1]
            NetChannel.Visualize:RequestToServer({
                Type = "Line",
                Position = form:GetWorldTranslate(),
                EndPosition = to:GetWorldTranslate(),
                Duration = -1,
            }, function (response)
                lines[i] = response[1]
            end)
        end

        Timer:After(1000, function ()
            local controller = joints[#joints]
            joints[#joints] = nil
            local fabrik = FABRIKController.new(joints, controller)
            fabrik.IterationLimit = iteLimit
            

            Timer:Every(10, function ()
                fabrik:Update()

                for i = 1, jointsCnt - 2 do
                    local originPos = joints[i]:GetWorldTranslate()
                    local targetPos = joints[i + 1]:GetWorldTranslate()
                    local dir = (targetPos - originPos):Normalize()
                    local rot = MathUtils.DirectionToQuat(dir, Vec3(0,1,0), "Z")
                    local scale = Vec3(0.1,0.1,(targetPos - originPos):Length() / 10)

                    NetChannel.SetTransform:SendToServer({
                        Guid = lines[i],
                        Transforms = {
                            [lines[i]] = {
                                Translate = targetPos,
                                RotationQuat = rot,
                                Scale = scale
                            }
                        }
                    })
                end
            end)
        end)
    end

    RBUtils.WaitUntil(function () return #bones == jointsCnt end, function ()
        Timer:After(100, setupFABRIK)
    end)
end)