local JOINT_TEMPLATE         = '6506b2c7-7227-4122-a38e-ab5a40a55377'
local JOINT_TEMPLATE_CAPSULE = 'c8bf9d2a-533e-4531-b91c-fedda5972599'
local SOFTBODY_RESOURCE      = "0c36a889-a3bd-6ebb-1137-e6ebb6acc6f2"

local testSphere             = Ext.Level.TestSphere
local raycastAll             = Ext.Level.RaycastAll

--- @param center Vec3
--- @param radius number
--- @return PhxPhysicsHitAll
local function testSphereSoftBody(center, radius)
    --- @diagnostic disable-next-line
    return testSphere(center, radius, "Dynamic", "Group08", 0)
end

--- @param from Vec3
--- @param to Vec3
--- @return PhxPhysicsHitAll
local function raycastSoftBody(from, to)
    --- @diagnostic disable-next-line
    return raycastAll(from, to, "Dynamic", "Group08", 0)
end

local enums = Ext.Enums
local eml = Ext.Math
local add = eml.Add
local sub = eml.Sub
local mul = eml.Mul

--- @param t Transform
--- @return Transform
local function copyTransform(t)
    return {
        Translate = { t.Translate[1] or 0, t.Translate[2] or 0, t.Translate[3] or 0 },
        RotationQuat = { t.RotationQuat[1] or 0, t.RotationQuat[2] or 0, t.RotationQuat[3] or 0, t.RotationQuat[4] or 0 },
        Scale = { t.Scale[1] or 0, t.Scale[2] or 0, t.Scale[3] or 0 },
    }
end

--- @param t Transform
--- @return string
local function stringifyTransform(t)
    return string.format("Translate: (%f, %f, %f),\n RotationQuat: (%f, %f, %f, %f),\n Scale: (%f, %f, %f)",
        t.Translate[1] or 0, t.Translate[2] or 0, t.Translate[3] or 0,
        t.RotationQuat[1] or 0, t.RotationQuat[2] or 0, t.RotationQuat[3] or 0, t.RotationQuat[4] or 0,
        t.Scale[1] or 0, t.Scale[2] or 0, t.Scale[3] or 0)
end

--- @param a Transform
--- @param b Transform
--- @return Transform
local function transformMul(a, b)
    return {
        Translate = add(a.Translate, eml.Mul(eml.QuatRotate(a.RotationQuat, b.Translate), a.Scale)),
        RotationQuat = eml.QuatMul(a.RotationQuat, b.RotationQuat),
        Scale = mul(a.Scale, b.Scale),
    }
end

--- @param ent EntityHandle
--- @return RenderableObject
local function safeGetFirstObject(ent)
    return ent and ent.Visual and ent.Visual.Visual and ent.Visual.Visual.ObjectDescs and
        ent.Visual.Visual.ObjectDescs[1] and ent.Visual.Visual.ObjectDescs[1].Renderable or {}
end

--- @param uuid string
--- @param transform Transform
local function setItemServerTransform(uuid, transform)
    NetChannel.SetTransform:SendToServer({
        Guid = uuid,
        Transforms = {
            [uuid] = transform,
        }
    })
end

local tickSubId = 0 --[[@as integer]]
local tickSubFns = {} --[[@type table<integer, function>]]

local localTickSub = Ext.Events.Tick:Subscribe(function()
    for id, fn in pairs(tickSubFns) do
        fn()
    end
end)

--- @class WaitResult<F>
--- @field OnComplete fun(result:F)

--- @param transform Transform
--- @return WaitResult<GUIDSTRING[]>
local function spawnBoneGizmo(transform)
    local r = {
        OnComplete = function() end
    }

    NetChannel.CallOsiris:RequestToServer({
        Function = "CreateAt",
        Args = {
            JOINT_TEMPLATE, transform.Translate[1], transform.Translate[2], transform.Translate[3], 0, 0, ""
        }
    }, function(response)
        r.OnComplete(response)
    end)

    return r
end

local individualSub = true

--- @param fn function
local function subTick(fn)
    if individualSub then
        return Ext.Events.Tick:Subscribe(fn)
    end

    tickSubId = tickSubId + 1
    tickSubFns[tickSubId] = fn
    return tickSubId
end

--- @param id integer
local function unsubTick(id)
    if individualSub then
        Ext.Events.Tick:Unsubscribe(id)
        return
    end

    tickSubFns[id] = nil
end

--- @param ticks integer
--- @param callback function
local function onTicks(ticks, callback)
    local count = 0
    local listener
    listener = subTick(function(e)
        count = count + 1
        if count >= ticks then
            unsubTick(listener)
            callback(e)
        end
    end)
end

--#region Skeleton Definitions
--- @type table<SupportedSkeletons, SkeletonDefine>
local allSkeletons = Ext.Require("Client/Editor/SkeletonDefine.lua")

local normie_skeleton = allSkeletons[SUPPORTED_SKELETONS.NormieSkeleton]
local normie_tail_skeleton = allSkeletons[SUPPORTED_SKELETONS.NormieTailSkeleton]

--- @param base SkeletonDefine
--- @param toMerge SkeletonDefine
--- @return SkeletonDefine merged new
local function mergeSkeletons(base, toMerge)
    local merged = {}
    for k, v in pairs(base) do
        merged[k] = v
    end
    for k, v in pairs(toMerge) do
        merged[k] = v
    end
    return merged
end

--- @param skeleton SkeletonDefine
--- @return BoneName? rootBoneName
local function findRootBone(skeleton)
    for name, v in pairs(skeleton) do
        if not v.Parent then return name end
    end

    return nil
end
--#endregion

--- @class TransformMap<T>
--- @field Translate T
--- @field RotationQuat T
--- @field Scale T

--- @alias BoneDirtyMark TransformMap<boolean>

--- @type TransformMap<string>
local gngenome_var_suffix = {
    Translate = "_Trans",
    RotationQuat = "_Rot",
    Scale = "_Scale",
}

--#region BoneProxy
--- @class BoneProxy : RB_MovableProxy
--- @field guid string
--- @field name BoneName
--- @field skeleton SkeletonProxy
--- @field indices TransformMap<integer>
--- @field new fun(guid: string, boneName: string, skeleton: SkeletonProxy): BoneProxy
local BoneProxy = {}

--- @param guid string
--- @param boneName string
--- @param skeleton SkeletonProxy
function BoneProxy.new(guid, boneName, skeleton)
    local self = setmetatable({}, { __index = BoneProxy })
    self.guid = guid
    self.name = boneName
    self.skeleton = skeleton
    self.Priority = skeleton.depthMap[boneName] or 0

    self.indices = {
        Translate = skeleton.nameIndexMap[boneName .. gngenome_var_suffix.Translate],
        RotationQuat = skeleton.nameIndexMap[boneName .. gngenome_var_suffix.RotationQuat],
        Scale = skeleton.nameIndexMap[boneName .. gngenome_var_suffix.Scale],
    }
    return self
end

function BoneProxy:IsValid()
    return true
end

function BoneProxy:GetParent()
    local parent = self.skeleton.skeletonDef[self.name].Parent

    local parentProxy = parent and self.skeleton.bones[parent]

    return parentProxy
end

function BoneProxy:GetTransform()
    local ent = Ext.Entity.Get(self.skeleton.guid)
    if not ent then error("Entity not found") end

    local dummy = ent.HasDummy and ent.HasDummy.Entity
    if not dummy then
        local gizmoEnt = Ext.Entity.Get(self.guid)
        if gizmoEnt then
            local gizmoObject = gizmoEnt.Visual and gizmoEnt.Visual.Visual and gizmoEnt.Visual.Visual.ObjectDescs and
                gizmoEnt.Visual.Visual.ObjectDescs[1] and gizmoEnt.Visual.Visual.ObjectDescs[1].Renderable
            if gizmoObject and gizmoObject.WorldTransform then
                return copyTransform(gizmoObject.WorldTransform)
            end
        end
        error("Dummy not found")
    end

    if not dummy.AnimationBlueprint or not dummy.AnimationBlueprint or not dummy.AnimationBlueprint.Instance then
        error("Animation blueprint instance not found")
    end
    local instanceVars = dummy.AnimationBlueprint.Instance.Variables

    return copyTransform(self.skeleton:GetBoneTransform(self.name, instanceVars))
end

function BoneProxy:GetWorldRotation()
    return self:GetTransform().RotationQuat
end

function BoneProxy:GetWorldTranslate()
    return self:GetTransform().Translate
end

function BoneProxy:GetWorldScale()
    return self:GetTransform().Scale
end

function BoneProxy:GetWorldBoundingBox()
    local gizmoEnt = Ext.Entity.Get(self.guid)
    if not gizmoEnt then error("Gizmo entity not found") end

    local visual = gizmoEnt.Visual and gizmoEnt.Visual.Visual
    if not visual then error("Gizmo visual not found") end

    return visual.WorldBound
end

--- @param transform Transform
function BoneProxy:SetTransform(transform)
    local current = self.skeleton.setBoneRequest[self.name] or {}
    if transform.Translate then
        current.Translate = transform.Translate
    end
    if transform.RotationQuat then
        current.RotationQuat = transform.RotationQuat
    end
    if transform.Scale then
        current.Scale = transform.Scale
    end
    self.skeleton.setBoneRequest[self.name] = current
end

function BoneProxy:SetWorldRotation(quat)
    self:SetTransform({
        RotationQuat = quat,
    })
end

function BoneProxy:SetWorldTranslate(pos)
    self:SetTransform({
        Translate = pos,
    })
end

function BoneProxy:SetWorldScale(scale)
    self:SetTransform({
        Scale = scale,
    })
end

--- @param e ExtuiTreeParent
function BoneProxy:Render(e)
    local ownerEnt = Ext.Entity.Get(self.skeleton.guid)
    if not ownerEnt then e:AddText("Unknown Owner: " .. self.name) return end

    local icon = RBGetIcon(ownerEnt.Uuid.EntityUuid)
    local name = ownerEnt.DisplayName.Name:Get()

    e:AddImage(icon, IMAGESIZE.ROW)
    e:AddText(name .. " - " .. self.name).SameLine = true
end
--#endregion BoneProxy

--#region SkeletonProxy
--- @class SkeletonProxy
--- public fields
--- @field ShallowColor vec4
--- @field DeepColor vec4
--- @field GizmoScale number
--- private
--- @field guid string
--- @field skeletonDef SkeletonDefine
--- bone hierarchy cache
--- @field rootBone BoneName
--- @field depthMap table<BoneName, integer>
--- @field childrenMap table<BoneName, BoneName[]>
--- @field flatttenedBoneList BoneName[] -- bone list sorted from shallow to deep, used for update order
--- genome variable maps
--- @field indexNameMap table<integer, GenomeVariableName>
--- @field nameIndexMap table<GenomeVariableName, integer>
--- bone transform
--- @field bones table<BoneName, BoneProxy>
--- @field boneDirty table<BoneName, BoneDirtyMark>
--- @field boneGizmos table<BoneName, GUIDSTRING> -- bone name to gizmo guid
--- @field setBoneRequest table<BoneName, Transform>
--- @field initialized boolean
--- static methods
--- @field new fun(guid: string, skeletonDef: SkeletonDefine): SkeletonProxy
--- @field BuildChildrenMap fun(skeletonDef: SkeletonDefine): table<BoneName, BoneName[]>
--- @field FindRootBone fun(skeletonDef: SkeletonDefine): BoneName?
--- @field BuildBoneDepthMap fun(rootBone: BoneName, childrenMap: table<BoneName, BoneName[]>): table<BoneName, integer>
--- @field FlattenBoneList fun(rootBone: BoneName, childrenMap: table<BoneName, BoneName[]>, result: BoneName[]): BoneName[]
--- methods
--- @field BuildBoneHierarchy fun(self: SkeletonProxy)
--- @field BuildBoneGizmos fun(self: SkeletonProxy)
--- @field BuildGenome fun(self: SkeletonProxy)
--- @field HitTest fun(self: SkeletonProxy): table<BoneName, Transform>
--- @field OnGizmoReady fun(self: SkeletonProxy)
--- @field DirtyBone fun(self: SkeletonProxy, boneName: BoneName)
--- @field DoTransform fun(self: SkeletonProxy)
--- @field UpdateGizmoTransform fun(self: SkeletonProxy, boneName: BoneName, transform: Transform)
--- @field GetBoneTransform fun(self: SkeletonProxy, boneName: BoneName, instanceVars: GnGenomeVariant[]): Transform
--- @field UpdateChildrenTransform fun(self: SkeletonProxy, parentBone: BoneName, instanceVars: GnGenomeVariant[])
--- @field StartUpdate fun(self: SkeletonProxy)
--- @field StopUpdate fun(self: SkeletonProxy)
--- @field Update fun(self: SkeletonProxy)
--- @field NeedUpdate fun(self: SkeletonProxy)
--- @field Destroy fun(self: SkeletonProxy)
--- @field UpdateAll fun(self: SkeletonProxy)
--- @field DumpAll fun(self: SkeletonProxy)
local SkeletonProxy = {}

--- @param skeletonDef SkeletonDefine
--- @return table<BoneName, BoneName[]> parent to children map
function SkeletonProxy.BuildChildrenMap(skeletonDef)
    local map = {}
    for boneName, boneDef in pairs(skeletonDef) do
        if not boneDef.Parent then goto continue end
        map[boneDef.Parent] = map[boneDef.Parent] or {}
        table.insert(map[boneDef.Parent], boneName)

        ::continue::
    end
    return map
end

--- @param skeletonDef SkeletonDefine
--- @return BoneName? root bone name
function SkeletonProxy.FindRootBone(skeletonDef)
    for boneName, boneDef in pairs(skeletonDef) do
        if not boneDef.Parent then return boneName end
    end

    return nil
end

--- @param rootBone BoneName
--- @param childrenMap table<BoneName, BoneName[]>
--- @return table<BoneName, integer> bone depth map
function SkeletonProxy.BuildBoneDepthMap(rootBone, childrenMap)
    local depthMap = { [rootBone] = 0 }
    local stack = { rootBone }
    while #stack > 0 do
        local current = table.remove(stack, 1)
        local children = childrenMap[current]
        if children then
            for _, child in pairs(children) do
                depthMap[child] = (depthMap[current] or 0) + 1
                table.insert(stack, child)
            end
        end
    end

    return depthMap
end

--- @param rootBone BoneName
--- @param childrenMap table<BoneName, BoneName[]>
--- @param result BoneName[] flattened bone list sorted from shallow to deep
--- @return BoneName[] flattened bone list sorted from shallow to deep
function SkeletonProxy.FlattenBoneList(rootBone, childrenMap, result)
    table.insert(result, rootBone)
    local children = childrenMap[rootBone]
    if children then
        for _, child in pairs(children) do
            SkeletonProxy.FlattenBoneList(child, childrenMap, result)
        end
    end

    return result
end

--- @alias SortedBoneEntry {[1]: BoneName, [2]: integer}

--- @param guid string
--- @param skeletonDef SkeletonDefine
function SkeletonProxy.new(guid, skeletonDef)
    local self = setmetatable({}, { __index = SkeletonProxy })
    self.guid = guid
    self.skeletonDef = skeletonDef

    self:BuildBoneHierarchy()

    self.boneDirty = {}
    self.bones = {}
    self.boneGizmos = {}
    self.setBoneRequest = {}

    self:BuildGenome()
    return self
end

function SkeletonProxy:BuildBoneHierarchy()
    self.rootBone = self.FindRootBone(self.skeletonDef) or error("Root bone not found")
    self.childrenMap = self.BuildChildrenMap(self.skeletonDef) or error("Failed to build children map")
    self.depthMap = self.BuildBoneDepthMap(self.rootBone, self.childrenMap) or error("Failed to build bone depth map")
    self.flatttenedBoneList = self.FlattenBoneList(self.rootBone, self.childrenMap, {}) or error("Failed to flatten bone list")
end

function SkeletonProxy:BuildGenome()
    local ent = Ext.Entity.Get(self.guid)
    if not ent then error("Entity not found") end

    local dummy = ent.HasDummy and ent.HasDummy.Entity
    if not dummy then error("Dummy not found") end

    local dummySoftbodyRes = dummy.Visual.Visual.Attachments[1].Visual.VisualResource.SoftbodyResourceID
    if dummySoftbodyRes ~= SOFTBODY_RESOURCE then
        dummy.Visual.Visual.Attachments[1].Visual.VisualResource.SoftbodyResourceID = SOFTBODY_RESOURCE
    end

    local resourceVars = dummy.AnimationBlueprint.Resource.Blueprints[1].Variables

    self.indexNameMap = {}
    self.nameIndexMap = {}
    for i, v in pairs(resourceVars) do
        if not v.Name or v.Name == "" then goto continue end
        self.indexNameMap[i] = v.Name
        self.nameIndexMap[v.Name] = i
        ::continue::
    end

    self:BuildBoneGizmos()
end

--- @return table<string, Transform>
function SkeletonProxy:HitTest()
    local ownerEnt = Ext.Entity.Get(self.guid)
    if not ownerEnt then error("Entity not found") end

    local dummy = ownerEnt.HasDummy and ownerEnt.HasDummy.Entity
    if not dummy then error("Dummy not found") end

    dummy.Visual.Visual.Attachments[1].Visual.VisualResource.SoftbodyResourceID = SOFTBODY_RESOURCE

    local bb = dummy.Visual.Visual.WorldBound
    local center = add(bb.Min, mul(sub(bb.Max, bb.Min), 0.5))
    local radius = eml.Length(sub(bb.Max, bb.Min)) * 0.5 + 1
    local hits = testSphereSoftBody(center, radius)

    --- @type table<BoneName, Transform>
    local boneTransforms = {}

    for _, s in pairs(hits.Shapes) do
        local boneName = s.Name
        if not boneName or not self.skeletonDef[boneName] then goto continue end

        boneTransforms[boneName] = {
            Translate = s.Translate,
            RotationQuat = s.Rotation,
            Scale = s.Scale,
        }

        ::continue::
    end

    return boneTransforms
end

--- @param a vec4
--- @param b vec4
--- @param t number
--- @return vec4
local function vectorLerp(a, b, t)
    return {
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t,
        a[4] + (b[4] - a[4]) * t,
    }
end

--- @param transform Transform
--- @return mat4
local function buildMatrix(transform)
    return eml.Mul(
        eml.BuildScale(transform.Scale), 
        eml.Mul(
            eml.QuatToMat4(transform.RotationQuat), 
            eml.BuildTranslation(transform.Translate)
        )
    )
end

--- @param boneDef BoneDefine
--- @param transform Transform
--- @param parentTransform Transform
local function buildLocalTransform(boneDef, transform, parentTransform)
    local worldDeltaP = sub(transform.Translate, parentTransform.Translate)
    local parentQuatInv = eml.QuatInverse(parentTransform.RotationQuat)
    local localPosOffset = eml.QuatRotate(parentQuatInv, worldDeltaP)
    local localQuatOffset = eml.QuatMul(parentQuatInv, transform.RotationQuat)
    local localScale = eml.Div(transform.Scale, parentTransform.Scale)

    local localMatrix = buildMatrix({
        Translate = localPosOffset,
        RotationQuat = localQuatOffset,
        Scale = localScale,
    })

    boneDef.Position = localPosOffset
    boneDef.Rotation = localQuatOffset
    boneDef.Scale = localScale
    boneDef.LocalMatrix = localMatrix
end

function SkeletonProxy:BuildBoneGizmos()
    self:Destroy()
    local cnt = 0
    local spawnedCnt = 0
    local boneTransforms = self:HitTest()

    local shallowColor = self.ShallowColor or { 1, 0, 0, 1 }
    local deepColor = self.DeepColor or { 0.5, 1, 0.5, 1 }
    local colorCache = {}

    local maxDepth = 0
    for _, depth in pairs(self.depthMap) do
        if depth > maxDepth then maxDepth = depth end
    end

    local function getColorByDepth(depth)
        if colorCache[depth] then return colorCache[depth] end
        if maxDepth == 0 then return shallowColor end
        local color = vectorLerp(shallowColor, deepColor, depth / maxDepth)
        colorCache[depth] = color
        return color
    end

    for boneName, transform in pairs(boneTransforms) do
        local parent = self.skeletonDef[boneName].Parent
        if parent then
            local boneDef = self.skeletonDef[boneName]
            local parentTransform = boneTransforms[parent]

            buildLocalTransform(boneDef, transform, parentTransform)
        end

        spawnBoneGizmo(transform).OnComplete = function(result)
            spawnedCnt = spawnedCnt + 1
            self.boneGizmos[boneName] = result[1]
            self.bones[boneName] = BoneProxy.new(result[1], boneName, self)

            Ext.Timer.WaitForRealtime(1000, function ()
                local ent = Ext.Entity.Get(result[1])
                if not ent or not ent.Visual then return end

                local obj = safeGetFirstObject(ent)
                obj.ActiveMaterial:SetVector4("Color", getColorByDepth(self.depthMap[boneName] or 0))
            end)

            if spawnedCnt == cnt then
                self:OnGizmoReady()
            end
        end
        cnt = cnt + 1
    end
end

function SkeletonProxy:RebuildBoneLocalTransforms()
    local boneTranforms = self:HitTest()
    for boneName, transform in pairs(boneTranforms) do
        local parent = self.skeletonDef[boneName].Parent
        if parent then
            local boneDef = self.skeletonDef[boneName]
            local parentTransform = boneTranforms[parent]

            buildLocalTransform(boneDef, transform, parentTransform)
        end
    end
    self:DirtyBone(self.rootBone)
end

function SkeletonProxy:RecolorGizmos()
    local shallowColor = self.ShallowColor or { 1, 0, 0, 1 }
    local deepColor = self.DeepColor or { 0.5, 0, 0.5, 1 }
    local colorCache = {}

    local maxDepth = 0
    for _, depth in pairs(self.depthMap) do
        if depth > maxDepth then maxDepth = depth end
    end

    local function getColorByDepth(depth)
        if colorCache[depth] then return colorCache[depth] end
        if maxDepth == 0 then return shallowColor end
        local color = vectorLerp(shallowColor, deepColor, depth / maxDepth)
        colorCache[depth] = color
        return color
    end

    for boneName, gizmo in pairs(self.boneGizmos) do
        local ent = Ext.Entity.Get(gizmo)
        if not ent or not ent.Visual then return end

        local obj = safeGetFirstObject(ent)
        obj.ActiveMaterial:SetVector4("Color", getColorByDepth(self.depthMap[boneName] or 0))
    end
end

local function getActiveCamera()
    local ents = Ext.Entity.GetAllEntitiesWithComponent("Camera")
    for _, ent in pairs(ents) do
        if ent.Camera and ent.Camera.Active then
            return ent
        end
    end

    return nil
end

function SkeletonProxy:RescaleGizmos()
    local camera = getActiveCamera()
    if not camera then return end

    local camPos = camera.Transform.Transform.Translate
    local toScale = self.GizmoScale or 0.5

    local scaleByDistance = function (pos)
        local dist = eml.Length(sub(pos, camPos))
        local scale = eml.Clamp(dist * toScale, 0.1, 1)
        return { scale, scale, scale }
    end

    for boneName, gizmo in pairs(self.boneGizmos) do
        local ent = Ext.Entity.Get(gizmo)
        if not ent or not ent.Visual then return end

        local obj = safeGetFirstObject(ent)
        if not obj.WorldTransform then return end
        local gizmoPos = obj.WorldTransform.Translate
        obj.WorldTransform.Scale = scaleByDistance(gizmoPos)
    end
end

function SkeletonProxy:OnGizmoReady()
    self.initialized = true
    self:StartUpdate()
end

--- @param boneName BoneName
function SkeletonProxy:DirtyBone(boneName)
    local stack = { boneName }

    while #stack > 0 do
        local current = table.remove(stack, 1)
        self.boneDirty[current] = {
            Translate = true,
            RotationQuat = true,
            Scale = true,
        }

        local children = self.childrenMap[current]
        if not children then goto continue end

        for _, child in pairs(children) do
            table.insert(stack, child)
        end

        ::continue::
    end
end

function SkeletonProxy:DoTransform()
    local ent = Ext.Entity.Get(self.guid)
    if not ent then error("Entity not found") end

    local dummy = ent.HasDummy and ent.HasDummy.Entity
    if not dummy then error("Dummy not found") end

    local instanceVars = dummy.AnimationBlueprint.Instance.Variables
    if not instanceVars then error("Instance variables not found") end

    if not next(self.setBoneRequest) then return end

    local worldBaseTransform = dummy.Visual.Visual.WorldTransform

    --- update from shallow to deep
    for _, boneName in ipairs(self.flatttenedBoneList) do
        if not self.setBoneRequest[boneName] then goto continue end

        local gizmo = self.boneGizmos[boneName]
        local parent = self.skeletonDef[boneName].Parent --[[@as string]]
        local toTransform = self.setBoneRequest[boneName]
        local indices = self.bones[boneName].indices
        local dirtyMark = {
            Translate = toTransform.Translate == nil,
            RotationQuat = toTransform.RotationQuat == nil,
            Scale = toTransform.Scale == nil,
        }

        local gizmoEnt = Ext.Entity.Get(gizmo)
        if not gizmoEnt then goto continue end

        local gizmoObject = gizmoEnt.Visual and gizmoEnt.Visual.Visual and gizmoEnt.Visual.Visual.ObjectDescs and
            gizmoEnt.Visual.Visual.ObjectDescs[1] and gizmoEnt.Visual.Visual.ObjectDescs[1].Renderable
        if not gizmoObject then goto continue end
        
        local gizmoTransform = gizmoObject.WorldTransform

        --- what bone transform would be if the bone has no instance variables
        --- @type Transform
        local oriTransform = worldBaseTransform

        if parent ~= nil then
            local parentTransform = self:GetBoneTransform(parent, instanceVars)
            local boneDef = self.skeletonDef[boneName]
            local scaledOffset = mul(boneDef.Position or {0, 0, 0}, parentTransform.Scale)
            local rotatedOffset = eml.QuatRotate(parentTransform.RotationQuat, scaledOffset)

            oriTransform = {
                Translate = add(parentTransform.Translate, rotatedOffset),
                RotationQuat = eml.QuatMul(parentTransform.RotationQuat, boneDef.Rotation or {0, 0, 0, 1}),
                Scale = mul(parentTransform.Scale, boneDef.Scale or {1, 1, 1}),
            }
        end

        --- @type TransformMap<string>
        local instanceVarTypes = {
            Translate = instanceVars[indices.Translate].Type,
            RotationQuat = instanceVars[indices.RotationQuat].Type,
            Scale = instanceVars[indices.Scale].Type,
        }

        if toTransform.Translate then
            -- toTranslate = oriTranslate + oriRotate * (localTranslate * oriScale)
            -- localTranslate = oriRotate^-1 * (toTranslate - oriTranslate) / oriScale

            instanceVars[indices.Translate] = {
                Value = eml.Div(eml.QuatRotate(eml.QuatInverse(oriTransform.RotationQuat), sub(toTransform.Translate, oriTransform.Translate)), oriTransform.Scale),
                Type = instanceVarTypes.Translate,
            }
        else
            toTransform.Translate = gizmoTransform.Translate
        end

        if toTransform.RotationQuat then
            -- toRotation = oriRotation * localRotation
            -- localRotation = oriRotation^-1 * toRotation

            instanceVars[indices.RotationQuat] = {
                Value = eml.QuatMul(eml.QuatInverse(oriTransform.RotationQuat), toTransform.RotationQuat),
                Type = instanceVarTypes.RotationQuat,
            }
        else
            toTransform.RotationQuat = gizmoTransform.RotationQuat
        end

        if toTransform.Scale then
            instanceVars[indices.Scale] = {
                Value = eml.Div(toTransform.Scale, oriTransform.Scale),
                Type = instanceVarTypes.Scale,
            }
        else
            toTransform.Scale = gizmoTransform.Scale
        end

        gizmoObject.WorldTransform = toTransform
        setItemServerTransform(gizmoEnt.Uuid.EntityUuid, toTransform)

        if self.boneDirty[boneName] then -- already dirtied by parent bone, just update the dirty mark
            self.boneDirty[boneName] = dirtyMark
        else
            self:DirtyBone(boneName)
            self.boneDirty[boneName] = nil -- since it's the shallowest to change, there will be no parent change to cause its other transform dirty, so just set to nil
        end

        ::continue::
    end

    self.setBoneRequest = {}
    self:NeedUpdate()
end

function SkeletonProxy:UpdateGizmoTransform(boneName, transform)
    local gizmoEnt = Ext.Entity.Get(self.boneGizmos[boneName])
    if not gizmoEnt then error("Gizmo entity not found for bone: " .. boneName) end

    local gizmoObject = gizmoEnt.Visual and gizmoEnt.Visual.Visual and gizmoEnt.Visual.Visual.ObjectDescs and
        gizmoEnt.Visual.Visual.ObjectDescs[1] and gizmoEnt.Visual.Visual.ObjectDescs[1].Renderable
    if not gizmoObject then error("Gizmo renderable object not found for bone: " .. boneName) end

    gizmoObject.WorldTransform = transform
    setItemServerTransform(gizmoEnt.Uuid.EntityUuid, transform)
end

--- @param boneName BoneName
--- @param instanceVars GnGenomeVariant[]
function SkeletonProxy:GetBoneTransform(boneName, instanceVars)
    if not boneName or not self.skeletonDef[boneName] then
        error("Bone not found: " .. tostring(boneName))
    end

    if not self.boneDirty[boneName] then
        local gizmo = self.boneGizmos[boneName]
        if not gizmo then error("Gizmo not found for bone: " .. boneName) end

        local gizmoEnt = Ext.Entity.Get(gizmo)
        if not gizmoEnt or not gizmoEnt.Visual or not gizmoEnt.Visual.Visual then error("Gizmo entity visual not found for bone: " .. boneName) end

        local renderable = gizmoEnt.Visual.Visual.ObjectDescs and gizmoEnt.Visual.Visual.ObjectDescs[1] and gizmoEnt.Visual.Visual.ObjectDescs[1].Renderable
        if not renderable then error("Gizmo renderable object not found for bone: " .. boneName) end

        return renderable.WorldTransform
    end

    local parent = self.skeletonDef[boneName].Parent
    local parentTransform = nil
    if parent ~= nil then
        parentTransform = self:GetBoneTransform(parent, instanceVars)
    else
        local ent = Ext.Entity.Get(self.guid)
        if not ent then error("Entity not found") end

        local dummy = ent.HasDummy and ent.HasDummy.Entity
        if not dummy then error("Dummy not found") end

        parentTransform = dummy.Visual.Visual.WorldTransform
    end
    
    -- base local transform + animation transform without instance variable
    local boneDef = self.skeletonDef[boneName]
    local indices = self.bones[boneName].indices
    --- @type Transform 
    local localTransform = {
        Translate = instanceVars[indices.Translate].Value,
        RotationQuat = instanceVars[indices.RotationQuat].Value,
        Scale = instanceVars[indices.Scale].Value,
    }

    local scaledOffset = mul(boneDef.Position or {0, 0, 0}, parentTransform.Scale)
    local rotatedOffset = eml.QuatRotate(parentTransform.RotationQuat, scaledOffset)
    local curPos = add(parentTransform.Translate, rotatedOffset)
    curPos = add(curPos, eml.QuatRotate(parentTransform.RotationQuat, localTransform.Translate))

    local curRot = eml.QuatMul(parentTransform.RotationQuat, boneDef.Rotation or {0, 0, 0, 1})
    curRot = eml.QuatMul(curRot, localTransform.RotationQuat)

    local curScale = mul(parentTransform.Scale, boneDef.Scale or {1, 1, 1})
    curScale = mul(curScale, localTransform.Scale)

    local currentTransform = {
        Translate = curPos,
        RotationQuat = curRot,
        Scale = curScale,
    }

    self:UpdateGizmoTransform(boneName, currentTransform)
    self.boneDirty[boneName] = nil

    return currentTransform
end

--- @param parentBone BoneName
--- @param instanceVars GnGenomeVariant[]
function SkeletonProxy:UpdateChildrenTransform(parentBone, instanceVars)
    local children = self.childrenMap[parentBone]
    if not children then return end

    local parentTransform = self:GetBoneTransform(parentBone, instanceVars)

    for _, current in ipairs(children) do
        if not self.skeletonDef[current] then goto continue end
        if not self.bones[current] then goto continue end
        local currentBoneDef = self.skeletonDef[current]
        local indices = self.bones[current].indices

        local rotatedOffset = eml.QuatRotate(parentTransform.RotationQuat, currentBoneDef.Position)
        local currentTranslate = add(parentTransform.Translate, rotatedOffset)
        local currentRotationQuat = eml.QuatMul(parentTransform.RotationQuat, currentBoneDef.Rotation)

        --- @type Transform
        local currentTransform = {
            Translate = currentTranslate,
            RotationQuat = currentRotationQuat,
            Scale = parentTransform.Scale,
        }

        local instanceVarTransform = {
            Translate = instanceVars[indices.Translate].Value,
            RotationQuat = instanceVars[indices.RotationQuat].Value,
            Scale = instanceVars[indices.Scale].Value,
        }

        currentTransform.Translate = add(currentTransform.Translate,
            eml.QuatRotate(currentTransform.RotationQuat, instanceVarTransform.Translate))
        currentTransform.RotationQuat = eml.QuatMul(currentTransform.RotationQuat, instanceVarTransform.RotationQuat)
        currentTransform.Scale = mul(currentTransform.Scale, instanceVarTransform.Scale)

        self:UpdateGizmoTransform(current, currentTransform)
        self.boneDirty[current] = nil

        self:UpdateChildrenTransform(current, instanceVars)
        ::continue::
    end
end

function SkeletonProxy:StartUpdate()
    self:StopUpdate()
    self:DirtyBone(self.rootBone)
    self:NeedUpdate()
    self.updater = subTick(function()
        local owner = Ext.Entity.Get(self.guid)
        if not self.initialized then return end
        if not owner or not owner.HasDummy or not owner.HasDummy.Entity then return end

        local ownerDummy = owner.HasDummy.Entity
        if not ownerDummy.AnimationBlueprint or not ownerDummy.AnimationBlueprint.Instance or not ownerDummy.AnimationBlueprint.Instance.Variables then return end

        if self.needUpdate > 0 then
            self:Update()
        end

        self:DoTransform()
    end)
end

function SkeletonProxy:StopUpdate()
    self.boneDirty = {}
    if self.updater then
        unsubTick(self.updater)
        self.updater = nil
    end
end

function SkeletonProxy:NeedUpdate()
    self.needUpdate = 60
end

function SkeletonProxy:Update()
    local boneTransforms = self:HitTest()
    for boneName, dirty in pairs(self.boneDirty) do
        if not boneTransforms[boneName] then goto continue end

        local boneTransform = boneTransforms[boneName]
        local ent = Ext.Entity.Get(self.boneGizmos[boneName])
        if not ent or not ent.Visual or not ent.Visual.Visual or not ent.Visual.Visual.ObjectDescs or not ent.Visual.Visual.ObjectDescs[1] or not ent.Visual.Visual.ObjectDescs[1].Renderable then
            goto continue
        end
        local gizmoWorldTransform = ent.Visual.Visual.ObjectDescs[1].Renderable.WorldTransform


        for transformType, isDirty in pairs(dirty) do
            boneTransform[transformType] = isDirty and boneTransform[transformType] or gizmoWorldTransform
                [transformType]
        end

        ent.Visual.Visual.ObjectDescs[1].Renderable.WorldTransform = boneTransform
        setItemServerTransform(ent.Uuid.EntityUuid, boneTransform)
        ::continue::
    end
    self.needUpdate = self.needUpdate - 1
    if self.needUpdate <= 0 then
        self.boneDirty = {}
    end
end

function SkeletonProxy:UpdateAll()
    local boneTransforms = self:HitTest()
    for boneName, transform in pairs(boneTransforms) do
        local ent = Ext.Entity.Get(self.boneGizmos[boneName])
        if not ent then goto continue end

        safeGetFirstObject(ent).WorldTransform = transform
        setItemServerTransform(ent.Uuid.EntityUuid, transform)
        ::continue::
    end
end

function SkeletonProxy:ResetAll()
    local ent = Ext.Entity.Get(self.guid)
    if not ent then error("Entity not found") end

    local dummy = ent.HasDummy and ent.HasDummy.Entity
    if not dummy then error("Dummy not found") end

    local instanceVars = dummy.AnimationBlueprint.Instance.Variables
    if not instanceVars then error("Instance variables not found") end

    --- @type Transform
    local originalOffset = {
        Translate = { 0, 0, 0 },
        RotationQuat = { 0, 0, 0, 1 },
        Scale = { 1, 1, 1 },
    }

    for boneName, bone in pairs(self.bones) do
        local indices = bone.indices
        instanceVars[indices.Translate] = {
            Value = originalOffset.Translate,
            Type = instanceVars[indices.Translate].Type,
        }
        instanceVars[indices.RotationQuat] = {
            Value = originalOffset.RotationQuat,
            Type = instanceVars[indices.RotationQuat].Type,
        }
        instanceVars[indices.Scale] = {
            Value = originalOffset.Scale,
            Type = instanceVars[indices.Scale].Type,
        }
        self.boneDirty[boneName] = {
            Translate = true,
            RotationQuat = true,
            Scale = true,
        }
    end
    self:NeedUpdate()
end

function SkeletonProxy:DumpAll()
    local ent = Ext.Entity.Get(self.guid)
    if not ent then error("Entity not found") end

    local dummy = ent.HasDummy and ent.HasDummy.Entity
    if not dummy then error("Dummy not found") end

    local instanceVars = dummy.AnimationBlueprint.Instance.Variables
    if not instanceVars then error("Instance variables not found") end

    for boneName, _ in pairs(self.bones) do
        local translateVar = instanceVars[self.nameIndexMap[boneName .. gngenome_var_suffix.Translate]].Value
        local rotationVar = instanceVars[self.nameIndexMap[boneName .. gngenome_var_suffix.RotationQuat]].Value
        local scaleVar = instanceVars[self.nameIndexMap[boneName .. gngenome_var_suffix.Scale]].Value
        translateVar = translateVar and string.format("(%f, %f, %f)", translateVar[1], translateVar[2], translateVar[3]) or
            "nil"
        rotationVar = rotationVar and
            string.format("(%f, %f, %f, %f)", rotationVar[1], rotationVar[2], rotationVar[3], rotationVar[4]) or "nil"
        scaleVar = scaleVar and string.format("(%f, %f, %f)", scaleVar[1], scaleVar[2], scaleVar[3]) or "nil"

        print(string.format("Bone: %s", boneName))
        print(string.format("  Translate: %s", tostring(translateVar)))
        print(string.format("  RotationQuat: %s", tostring(rotationVar)))
        print(string.format("  Scale: %s", tostring(scaleVar)))
    end
end

--- @param bones BoneName[]
--- @return SortedBoneEntry[] -- shallow to deep
function SkeletonProxy:SortBoneByDepth(bones)
    local depthMap = self.depthMap
    local sortedBones = {}
    for _, boneName in ipairs(bones) do
        table.insert(sortedBones, { boneName, depthMap[boneName] or 0 })
    end
    table.sort(sortedBones, function(a, b) return a[2] < b[2] end)
    return sortedBones
end

function SkeletonProxy:Destroy()
    self:StopUpdate()
    for boneName, gizmo in pairs(self.boneGizmos) do
        NetChannel.CallOsiris:RequestToServer({
            Function = "RequestDelete",
            Args = { gizmo }
        }, function(response)

        end)
        self.bones[boneName].IsValid = function() return false end
    end
    self.bones = {}
    self.boneGizmos = {}
    self.initialized = false
end
--#endregion

--- @param ent EntityHandle
--- @return VisualAttachment? attachment with Tail slot
local function findTailAttachment(ent)
    for _, attachment in pairs(ent.Visual.Visual.Attachments) do
        if attachment.Visual and attachment.Visual.VisualResource and attachment.Visual.VisualResource.SkeletonSlot == "Tail" then
            return attachment
        end
    end
    return nil
end

local function initSkeletonProxy()
    local window = WindowManager.RegisterWindow("generic", "BONEEEE")
    window.Visible = true

    window:AddButton("Destroy All").OnClick = function()
        local allEntites = Ext.Entity.GetAllEntitiesWithComponent("GameObjectVisual")
        for _, ent in pairs(allEntites) do
            if ent.GameObjectVisual.RootTemplateId == JOINT_TEMPLATE or GIZMO_ITEM_IDS[ent.GameObjectVisual.RootTemplateId] then
                NetChannel.CallOsiris:RequestToServer({
                    Function = "RequestDelete",
                    Args = { ent.Uuid.EntityUuid }
                }, function(response)
                end)
            end
        end
    end

    local debug = window:AddButton("Debug")

    local originSpringResourceID = {}
    local disableStringBtn = window:AddButton("Disable Tail Spring")
    disableStringBtn.OnClick = function(e)
        local ent = _C()
        if not ent then error("Entity not found") end
        local entId = ent.Uuid.EntityUuid

        local tailAttachment = findTailAttachment(ent)
        if not tailAttachment then error("Tail attachment not found") end

        local skeleton = tailAttachment.Visual.SkeletonSlots[1].Skeleton

        local skeletonId = skeleton.ID
        local skeletonResource = Ext.Resource.Get(skeletonId, "Skeleton") --[[@as ResourceSkeletonResource]]

        if not originSpringResourceID[entId] then
            originSpringResourceID[entId] = skeletonResource.SpringResourceID
        end

        if skeletonResource.SpringResourceID == '' then
            skeletonResource.SpringResourceID = originSpringResourceID[entId]
            e.Label = "Disable Tail Spring"
        else
            skeletonResource.SpringResourceID = ''
            e.Label = "Enable Tail Spring"
        end
    end

    do
        local ent = _C()
        if not ent then goto continue end
        local entId = ent.Uuid.EntityUuid

        local tailAttachment = findTailAttachment(ent)
        if not tailAttachment then error("Tail attachment not found") end

        local skeleton = tailAttachment.Visual.SkeletonSlots[1].Skeleton

        local skeletonId = skeleton.ID
        local skeletonResource = Ext.Resource.Get(skeletonId, "Skeleton") --[[@as ResourceSkeletonResource]]

        originSpringResourceID[entId] = skeletonResource.SpringResourceID
        disableStringBtn.Label = skeletonResource.SpringResourceID == '' and "Enable Tail Spring" or
            "Disable Tail Spring"
        ::continue::
    end

    debug.OnClick = function()
        local c = _C()
        if not c or not c.HasDummy then return end
        local dummy = c.HasDummy.Entity

        dummy.Visual.Visual.Attachments[1].Visual.VisualResource.SoftbodyResourceID = SOFTBODY_RESOURCE

        onTicks(30, function()
            local parent = window:AddGroup("Skeleton Debug##" .. c.Uuid.EntityUuid)
            local merged = mergeSkeletons(normie_skeleton, normie_tail_skeleton)
            local skeletonProxy = SkeletonProxy.new(c.Uuid.EntityUuid, merged)

            function skeletonProxy:OnGizmoReady()
                SkeletonProxy.OnGizmoReady(self)

                for boneName, gizmo in pairs(self.boneGizmos) do
                    MovableProxy.RegisterSpecial(gizmo, self.bones[boneName])
                end
            end

            parent:AddColorEdit("Shallow Color", skeletonProxy.ShallowColor or { 1, 0, 0 }).OnChange = function(e)
                skeletonProxy.ShallowColor = e.Color
                skeletonProxy:RecolorGizmos()
            end

            parent:AddColorEdit("Deep Color", skeletonProxy.DeepColor or { 0.5, 1, 0.5 }).OnChange = function(e)
                skeletonProxy.DeepColor = e.Color
                skeletonProxy:RecolorGizmos()
            end

            parent:AddButton("Rebuild Local Transforms").OnClick = function()
                skeletonProxy:RebuildBoneLocalTransforms()
            end

            parent:AddButton("Start Updating").OnClick = function()
                skeletonProxy:StartUpdate()
            end

            local symmetry = false
            parent:AddCheckbox("Symmetry", symmetry).OnChange = function(e)
                symmetry = e.Checked
            end

            local indexSelect = false
            parent:AddCheckbox("Index Select", indexSelect).OnChange = function(e)
                indexSelect = e.Checked
            end

            parent:AddButton("Reset All").OnClick = function()
                skeletonProxy:ResetAll()
            end

            parent:AddButton("Dump All").OnClick = function()
                skeletonProxy:DumpAll()
            end

            parent:AddButton("Update All").OnClick = function()
                skeletonProxy:UpdateAll()
            end

            parent:AddButton("Destroy").OnClick = function()
                skeletonProxy:Destroy()
                parent:Destroy()
            end

            local root = findRootBone(merged)

            --- @type string[]
            local stack = { root }
            --- @type table<string, RB_UI_Tree>
            local parentParent = {}

            --- @param parent ExtuiTreeParent
            --- @param name string
            --- @return RB_UI_Tree
            local function addTree(parent, name)
                local tree = ImguiElements.AddTree(parent, name)
                return tree
            end

            while #stack > 0 do
                local current = table.remove(stack, 1)
                local parentElement = parentParent[current] or parent

                local children = skeletonProxy.childrenMap[current]
                local uiElement = nil --[[@as ExtuiStyledRenderable?]]
                if children and #children > 0 then
                    table.sort(children, function(a, b) return a < b end)
                    local tree = addTree(parentElement, current)
                    for _, child in pairs(children) do
                        table.insert(stack, child)
                        parentParent[child] = tree
                    end
                    uiElement = tree
                else
                    local selectable = parentElement:AddSelectable(current)
                    selectable.OnClick = function(e)
                        e.Selected = false
                    end
                    uiElement = selectable
                end

                uiElement.OnHoverEnter = function(e)
                    if skeletonProxy.bones[current] then return end
                    e:Destroy()
                end

                uiElement.OnRightClick = function(e)
                    local boneSet = { [current] = true }

                    if indexSelect then
                        local prefix, numStr, suffix = current:match("^([%a_]+)(%d+)(_[%a%d_]+)$")

                        if prefix and numStr and suffix then
                            local idx = tonumber(numStr)
                            while true do
                                local boneName = prefix .. idx .. suffix

                                if skeletonProxy.bones[boneName] then
                                    boneSet[boneName] = true
                                elseif idx > 1 then
                                    break
                                end
                                idx = idx + 1
                            end
                        end
                    end

                    if symmetry then
                        local found = {}
                        for bone, _ in pairs(boneSet) do
                            local symmetricBone = bone:gsub("_L", "_R")
                            if symmetricBone == bone then
                                symmetricBone = bone:gsub("_R", "_L")
                            end
                            if symmetricBone ~= bone and skeletonProxy.bones[symmetricBone] then
                                found[symmetricBone] = true
                            end
                        end
                        for symmetricBone, _ in pairs(found) do
                            boneSet[symmetricBone] = true
                        end
                    end

                    --- @type BoneName[]
                    local boneList = {}
                    for bone, _ in pairs(boneSet) do
                        table.insert(boneList, bone)
                    end

                    local sortedBones = skeletonProxy:SortBoneByDepth(boneList)

                    --- @type BoneProxy[]
                    local boneProxies = {}
                    for _, bone in pairs(sortedBones) do
                        table.insert(boneProxies, skeletonProxy.bones[bone[1]])
                    end

                    RB_GLOBALS.TransformEditor:Select(boneProxies)
                end

                ::continue::
            end

            local ik_test = ImguiElements.AddTree(parent, "IK Test")

            ik_test:AddButton("Spawn Tail IK Target").OnClick = function()
                local parent = ik_test:AddGroup("Tail IK Target")
                parent:AddSeparatorText("Tail IK ")
                local tailNameTemplate = "Tail%d_M"

                --- @type BoneProxy[]
                local tailJoints = {}

                local idx = 0
                while true do
                    local boneName = string.format(tailNameTemplate, idx)
                    if not merged[boneName] then break end
                    table.insert(tailJoints, skeletonProxy.bones[boneName])
                    idx = idx + 1
                end

                local endBone = tailJoints[#tailJoints]
                local tailFABRIK = nil --[[@as FABRIKController?]]

                spawnBoneGizmo(endBone:GetTransform()).OnComplete = function(result)
                    Ext.Timer.WaitForRealtime(1000, function()
                        local goal = ItemMovableProxy.new(result[1])

                        tailFABRIK = FABRIKController.new(tailJoints, goal)
                        tailFABRIK.UpdatePosition = false
                        tailFABRIK.UpdateRotation = true
                        tailFABRIK.UpdateRotationRelatively = true

                        function goal:OnTransformChanged(transform)
                            tailFABRIK:Update()
                        end

                        RB_GLOBALS.TransformEditor:Select({ goal })
                    end)
                end

                parent:AddButton("Sync").OnClick = function(e)
                    if not tailFABRIK then return end
                    local points = tailFABRIK.debugPoints
                    for i, point in pairs(points) do
                        local ent = Ext.Entity.Get(point)
                        if ent and ent.Visual and ent.Visual.Visual and ent.Visual.Visual.ObjectDescs and ent.Visual.Visual.ObjectDescs[1] and ent.Visual.Visual.ObjectDescs[1].Renderable then
                            local transform = skeletonProxy:GetBoneTransform(tailJoints[i].name,
                                Ext.Entity.Get(skeletonProxy.guid).HasDummy.Entity.AnimationBlueprint.Instance.Variables)
                            local toScale = 0.9/tailFABRIK.Lengths[i]
                            transform.Scale = { toScale, toScale, toScale }
                            ent.Visual.Visual.ObjectDescs[1].Renderable.WorldTransform = transform
                            ent.Visual.Visual.ObjectDescs[2].Renderable.WorldTransform = transform
                            ent.Visual.Visual.ObjectDescs[3].Renderable.WorldTransform = transform
                        end
                    end
                end
            end

            local armIKBones = {
                "Shoulder",
                "Elbow",
                "Wrist",
            }

            local legIKBones = {
                "Hip",
                "Knee",
                "Ankle",
            }

            local twoBoneIKBones = {
                Arm = armIKBones,
                Leg = legIKBones,
            }

            --- @param part "Arm" | "Leg"
            --- @param leftOrRight "L" | "R"
            local function setupTwoBoneIK(part, leftOrRight)
                --- @type BoneProxy[]
                local bones = {}
                local suffix = "_" .. leftOrRight
                local isLeft = leftOrRight == "L"
                for _, boneName in pairs(twoBoneIKBones[part]) do
                    local fullBoneName = boneName .. suffix
                    if skeletonProxy.bones[fullBoneName] then
                        table.insert(bones, skeletonProxy.bones[fullBoneName])
                    else
                        print(string.format("Bone %s not found, skipping IK setup", fullBoneName))
                        return
                    end
                end

                local poleTargetTransform = bones[2]:GetTransform()
                poleTargetTransform.Translate = add(poleTargetTransform.Translate, { 0, 0, -0.1 })

                local controllerTransform = bones[3]:GetTransform()

                --- @type RB_MovableProxy?
                local controller = nil
                --- @type RB_MovableProxy?
                local poleTarget = nil

                local poleColor = isLeft and { 1, 0, 1, 1 } or { 1, 1, 0, 1 }
                local controllerColor = isLeft and { 0, 1, 1, 1 } or { 1, 0, 1, 1 }

                local function setupIK()
                    if not controller or not poleTarget then return end
                    local ikController = TwoBoneIKController.new(bones[1], bones[2], bones[3], poleTarget, controller)
                    ikController.IsLeft = isLeft
                    ikController.UpdateRotationRelatively = true

                    ikController.PoleAngle = part == "Leg" and math.pi or 0
                    ikController.UpdateRotation = true
                    ikController.UpdatePosition = false

                    function controller:SetTransform(transform)
                        --- @diagnostic disable-next-line
                        ItemMovableProxy.SetTransform(self, transform)

                        ikController:Update()
                        bones[3]:SetWorldRotation(transform.RotationQuat)
                    end

                    function poleTarget:SetTransform(transform)
                        --- @diagnostic disable-next-line
                        ItemMovableProxy.SetTransform(self, transform)

                        ikController:Update()
                    end

                    RB_GLOBALS.TransformEditor:Select({ controller })
                    local parent = ik_test:AddGroup(string.format("%s %s IK", leftOrRight, part))
                    parent:AddSeparatorText(string.format("%s %s IK", leftOrRight, part))
                    parent:AddSlider("Pole Angle##" .. controller.Guid, math.deg(ikController.PoleAngle), 0, 360).OnChange = function(e)
                        ikController.PoleAngle = math.rad(e.Value[1])
                        ikController:Update()
                    end
                    parent:AddButton("Controller##" .. controller.Guid).OnClick = function()
                        RB_GLOBALS.TransformEditor:Select({ controller })
                    end
                    parent:AddButton("Pole Target##" .. poleTarget.Guid).OnClick = function()
                        RB_GLOBALS.TransformEditor:Select({ poleTarget })
                    end

                    parent:AddButton("Sync").OnClick = function(e)
                        local points = ikController.debugPoints
                        local origin = bones[1]:GetTransform()
                        local joint = bones[2]:GetTransform()

                        MovableProxy.CreateByGuid(points[1]):SetTransform(origin)
                        MovableProxy.CreateByGuid(points[2]):SetTransform(joint)
                    end
                end

                spawnBoneGizmo(controllerTransform).OnComplete = function(result)
                    Ext.Timer.WaitForRealtime(1000, function()
                        controller = MovableProxy.CreateByGuid(result[1])
                        if not controller then error("Failed to create controller proxy") end

                        local visual = Ext.Entity.Get(controller.Guid).Visual
                        if visual then
                            visual.Visual.ObjectDescs[1].Renderable.ActiveMaterial:SetVector4("Color", controllerColor)
                        end

                        setItemServerTransform(result[1], copyTransform(controllerTransform))
                        setupIK()
                    end)
                end

                spawnBoneGizmo(poleTargetTransform).OnComplete = function(result)
                    Ext.Timer.WaitForRealtime(1000, function()
                        poleTarget = MovableProxy.CreateByGuid(result[1])
                        if not poleTarget then error("Failed to create pole target proxy") end

                        local visual = Ext.Entity.Get(poleTarget.Guid).Visual
                        if visual then
                            visual.Visual.ObjectDescs[1].Renderable.ActiveMaterial:SetVector4("Color", poleColor)
                        end

                        setupIK()
                    end)
                end
            end

            ik_test:AddButton("Spawn Arm IK R").OnClick = function(e)
                setupTwoBoneIK("Arm", "R")
            end

            ik_test:AddButton("Spawn Arm IK L").OnClick = function(e)
                setupTwoBoneIK("Arm", "L")
            end

            ik_test:AddButton("Spawn Leg IK R").OnClick = function(e)
                setupTwoBoneIK("Leg", "R")
            end

            ik_test:AddButton("Spawn Leg IK L").OnClick = function(e)
                setupTwoBoneIK("Leg", "L")
            end
        end)
    end



    debug:OnClick()
end

Ext.Events.SessionLoaded:Subscribe(function()
    initSkeletonProxy()
end)