--- @class Gizmo
--- @field Editor TransformEditor
--- @field Mode TransformEditorMode
--- @field Space TransformEditorSpace
--- @field SelectedAxis table<TransformAxis, boolean> | nil
--- @field HoveredAxis table<TransformAxis, boolean> | nil
--- @field StartHit Hit | nil
--- @field IsDragging boolean
--- @field Guid Guid -- Gizmo entity guid
--- @field Picker GizmoPicker
--- @field Subscription table<string, LOPSubscription>
--- @field Timers table<string, TimerID>
--- @field new fun(editor: TransformEditor): Gizmo
--- @field OnDragStart fun(self: Gizmo)
--- @field OnDragTranslate fun(self: Gizmo, delta: Vec3)
--- @field OnDragRotate fun(self: Gizmo, delta: { Angle:number, Axis:Vec3 })
--- @field OnDragScale fun(self: Gizmo, delta: Vec3)
--- @field OnDragEnd fun(self: Gizmo)
Gizmo = _Class("Gizmo")

function Gizmo:__init(editor)
    self.Editor = editor
    self.Mode = "Translate"
    self.Space = "World"
    self.SelectedAxis = nil
    self.HoveredAxis = nil
    self.DisableHover = false
    self.StartHit = nil
    self.Guid = nil
    self.Targets = {}
    self.Picker = GizmoPicker.new(self)
    self.Subscription = {}
    self.Timers = {}

    self.ServerListener = ClientSubscribe(NetMessage.ServerGizmo, function (data)
        if data.Guid then
            if self.Guid then self:DeleteItem() end
            self.Guid = data.Guid
            self:SetupLiseners()
        end
        if data.Clear then
            self.Guid = nil
        end
    end)

end

function Gizmo:EmptyDrag()
    if self.Mode == "Rotate" then
        self:OnDragRotate({ Angle = 0, Axis = Vec3.new{0,0,0} })
    elseif self.Mode == "Translate" then
        self:OnDragTranslate(Vec3.new{0,0,0})
    else
        self:OnDragScale(Vec3.new{1,1,1})
    end
end

function Gizmo:SetScale(scale)
    GizmoVisualizer.GizmoScale = scale
end

function Gizmo:SetTarget(targets)
    if not targets or #targets == 0 then
        self:DeleteItem()
        self.Targets = {}
        return
    end

    self.Targets = targets
    if not self.Guid then
        self:CreateItem()
    end
end

function Gizmo:UpdatePicker()
    local target = self.Targets and self.Targets[1]
    if not target or not EntityExists(target) then
        --Warning("Gizmo:UpdatePicker: No valid target to stick to")
        return
    end

    local x, y, z = CGetPosition(target)
    local rx, ry, rz, rw = table.unpack(Quat.Identity)

    if self.Space == "View" then
        rx, ry, rz, rw = GetCameraRotation()
    elseif self.Space == "Parent" then
        local parent = PropStore:GetBindParent(target)
        if parent and EntityExists(parent) then
            rx, ry, rz, rw = CGetRotation(parent)
        else
        end
    elseif self.Space == "Local" then
        rx, ry, rz, rw = CGetRotation(target)
    end

    if not x or not y or not z or not rx or not ry or not rz or not rw then
        --Warning("Gizmo:UpdatePicker: Failed to get gizmo position or rotation")
        return
    end

    local pos = Vec3.new({x, y, z})
    self.Picker.Position = pos
    self.Picker.Rotation = Quat.new{rx, ry, rz, rw}
    local scale = GizmoVisualizer:UpdateScale(self.Guid)
    self.Picker.Scale = scale
    self.Picker.AABB = { Min = pos - {scale, scale, scale}, Max = pos + {scale, scale, scale} }
end

function Gizmo:StartDragging(mouseRay, hit)
    mouseRay = mouseRay or ScreenToWorldRay()
    if not mouseRay then Warning("Gizmo:DragStart: Failed to get mouse ray") return end
    hit = hit or self.Picker:Hit(mouseRay, self.Space)
    self.IsDragging = true
    if hit and hit.Axis then
        self.SelectedAxis = hit.Axis
    else
        self.SelectedAxis = { X = true, Y = true, Z = true }
        if self.Mode == "Rotate" then
            local closestAxis = self.Picker:ClosestPlane(mouseRay)
            self.SelectedAxis = { [closestAxis] = true }
        end
    end
    self.HoveredAxis = nil
    self.StartHit = self:GetHit(mouseRay)
    
    self:OnDragStart()
    self:SetupDragging()
    self:DragVisualize()
end

function Gizmo:RestartDragging(mouseRay, axes)
    mouseRay = mouseRay or ScreenToWorldRay()
    axes = axes or DeepCopy(self.SelectedAxis) or { X = true, Y = true, Z = true }

    if self.Mode == Enums.TransformEditorMode.Rotate and CountMap(axes) ~= 1 then
        axes = { [next(axes)]= true }
    end

    self:StopWithoutCallbacks()
    self:Hide()

    self.SelectedAxis = axes
    self.HoveredAxis = nil
    self.IsDragging = true
    self.StartHit = self:GetHit(mouseRay)
    self:SetupDragging()
    self:DragVisualize()
end

function Gizmo:SetupLiseners()
    self:StopListeners()

    self.Subscription["LockAxis"] = SubscribeKeyInput({}, function (e)
        if not self.IsDragging then return end
        if e.Event ~= "KeyDown" or not e.Pressed or e.Repeat then return end

        local mouseRay = ScreenToWorldRay()
        if not mouseRay then Warning("Gizmo:LockAxis: Failed to get mouse ray") return end
    
        if not GLOBAL_COORDINATE[e.Key] then return end

        local axisToLock = tostring(e.Key):sub(1,1):upper()

        local axes = { X = true, Y = true, Z = true }
        if self.SelectedAxis and self.SelectedAxis[axisToLock] and CountMap(self.SelectedAxis) == 1 then
        elseif e.Modifiers == "LShift" or e.Modifiers == "RShift" then
            axes[axisToLock] = nil
        else
            axes = { [axisToLock] = true }
        end
        
        self:RestartDragging(mouseRay, axes)
    end)


    self.Subscription["MMBLockAxis"] = SubscribeMouseInput({}, function (e)
        if not self.IsDragging then return end
        if not e.Pressed or tonumber(e.Button) ~= 2 then return end

        local mouseRay = ScreenToWorldRay()
        if not mouseRay then Warning("Gizmo:MMBLockAxis: Failed to get mouse ray") return end
    
        local axisToLock = self.Picker:ClosestPlane(mouseRay)

        if self.SelectedAxis and self.SelectedAxis[axisToLock] and CountMap(self.SelectedAxis) == 1 then  return end

        local axes = { [axisToLock] = true }

        self:RestartDragging(mouseRay, axes)
    end)

    self.Subscription["DragStart"] = SubscribeMouseInput({}, function (e)
        if e.Button == 1 and e.Pressed and self.Picker and not self.IsDragging then
            local mouseRay = ScreenToWorldRay()
            if not mouseRay then Warning("Gizmo:DragStart: Failed to get mouse ray") return end
            local hit = self.Picker:Hit(mouseRay)
            if not hit or not hit.Axis then return end
            self:StartDragging(mouseRay, hit)
        end
    end)

    self.Subscription["DragCancel"] = SubscribeMouseInput({}, function (e)
        if not self.IsDragging then return end
        if e.Pressed and tonumber(e.Button) == 3 then
            self:EmptyDrag()
            self:StopDragging()
        end
    end)

    self.Subscription["DragEnd"] = SubscribeMouseInput({}, function (e)
        if not self.IsDragging then return end
        if e.Button == 1 and not e.Pressed then
            self:StopDragging()
        end
    end)

    self.Timers["DetectHover"] = Timer:EveryFrame(function (timerID)
        if self.IsDragging or not self.Picker then return end
        local mouseRay = ScreenToWorldRay()
        if not mouseRay then Warning("Gizmo:DetectHover: Failed to get mouse ray") return end

        self:UpdatePicker()
        local hit = self.Picker:Hit(mouseRay, self.Space)
        if hit and hit.Axis then
            self.HoveredAxis = hit.Axis
        else
            self.HoveredAxis = nil
            if false then
                local planeHit = self.Picker:HitPlaneByNormal(mouseRay, mouseRay.Direction)
                if not planeHit or not planeHit.Position then
                    Warning("Gizmo:DetectHover: No plane hit detected")
                else
                end
            end
        end
        self:Visualize()
    end)

    
    self.Timers["Stick"] = Timer:EveryFrame(function (timerID)
        if not self.Guid then return end
        local target = self.Targets and self.Targets[1]
        if not target or not EntityExists(target) then return end
        local pos = {CGetPosition(target)}
        local rot = Quat.Identity
        if self.Space == "Local" then
            rot = {CGetRotation(target)}
        elseif self.Space == "Parent" then
            local parent = PropStore:GetBindParent(target)
            if parent then
                rot = {CGetRotation(parent)}
            end
        elseif self.Space == "View" then
            rot = {GetCameraRotation()}
        end
        if not rot or #rot ~= 4 then
            rot = Quat.Identity
        end
        Post(NetChannel.SetTransform, {
            Guid = self.Guid,
            Transforms = {
                [self.Guid] = {
                    Translate = pos,
                    RotationQuat = rot,
                }
            }
        })
    end)
end

function Gizmo:DeleteItem()
    local guid = self.Guid
    Post(NetChannel.Delete, { Guid = guid })
end

function Gizmo:CreateItem()
    if self.Guid then
        self:DeleteItem()
    end

    local data = {
        GizmoType = self.Mode,
    }
    Post(NetChannel.ManageGizmo, data)
end

function Gizmo:SetMode(mode)
    if not Enums.TransformEditorMode[mode] then
        Warning("Gizmo:SetMode: Invalid mode '"..tostring(mode).."'")
        return
    end
    if mode and mode ~= self.Mode then
        local ifRestart = self.IsDragging
        if self.IsDragging then
            self:EmptyDrag()
            --self:StopWithoutCallbacks()
        end

        self.Mode = mode
        self:DeleteItem()
        self:CreateItem()
        if ifRestart then
            self:RestartDragging()
        end
    end
end

function Gizmo:SetSpace(space)
    if not Enums.TransformEditorSpace[space] then
        Warning("Gizmo:SetSpace: Invalid space '"..tostring(space).."'")
        return
    end
    if self.IsDragging then
        Warning("Gizmo:SetSpace: Cannot change space while dragging")
        return
    end
    if space and space ~= self.Space then
        self.Space = space
    end
end

local lastDraw = 0

--- @param ray Ray
function Gizmo:GetHit(ray)
    local cnt = CountMap(self.SelectedAxis or {})
    if cnt == 0 then Debug("No Axis") return nil end

    local hit = nil
    if self.Mode == "Rotate" then
        local axis = nil
        for a,_ in pairs(self.SelectedAxis) do axis = a end
        hit = self.Picker:HitPlanePerpToAxis(ray, axis)

        local origin = self.Picker.Position

        if hit and hit.Position and self.Visualizations and #self.Visualizations > 0 then
            local dir = hit.Position - origin
            local quat = DirectionToQuat(dir, Ext.Math.QuatRotate(self.Picker.Rotation, GLOBAL_COORDINATE.Y), axis)
            local newest = self.Visualizations[#self.Visualizations]
            for _,guid in ipairs(self.Visualizations or {}) do
                GizmoVisualizer:VisualizeRotateSymbol(guid, axis)
            end
            local pos = self.Picker.Position
            Post(NetChannel.SetTransform, {
                Guid = newest,
                Transforms = {
                    [newest] = {
                        Translate = pos,
                        RotationQuat = quat,
                    }
                }
            })
        end
    else
        if cnt == 1 then
            local axis = nil
            for a,_ in pairs(self.SelectedAxis) do axis = a end
            -- https://underdisc.net/blog/6_gizmos/index.html
            local p = self.Picker:ClosestPointOnAxis(ray, axis)
            hit = Hit.new(p, nil, (p - ray.Origin):Length(), nil)
    
        elseif cnt == 2 then
            hit = self.Picker:HitPlaneByAxes(ray, self.SelectedAxis)

        elseif cnt == 3 then
            local normal = GetCameraForward()
            if self.StartHit then
                hit = ray:IntersectPlane(self.StartHit.Position, normal)    
            else
                hit = self.Picker:HitPlaneByNormal(ray, normal)
            end
        end
        for _,guid in pairs(self.Visualizations or {}) do
            self:Visualize(guid)
        end
    end

    if Ext.Timer.MonotonicTime() - lastDraw > 1000 and hit and hit.Position then
        lastDraw = Ext.Timer.MonotonicTime()
        hit.Normal = hit.Normal or GLOBAL_COORDINATE.Y
        Post(NetChannel.Visualize, { Type = "Point", Position = hit.Position, Rotation = DirectionToQuat(hit.Normal)})
    end
    if not hit or not hit.Position then
        return Hit.new(self.Picker.Position, nil, 0, nil)
    end

    return hit
end

local function CalcRotationChange(startDir, dir, axis, origin)
    local dot = startDir:Dot(dir)
    dot = Ext.Math.Clamp(dot, -1, 1)
    local angle = math.acos(dot)
    
    local cross = startDir:Cross(dir)
    if cross:Dot(axis) < 0 then
        angle = -angle
    end
    
    return angle --WrapQuat(Ext.Math.QuatRotateAxisAngle(Quat.Identity, axis, angle))
end

--- @param startHit Hit
--- @param hit Hit
--- @param selectedAxes table<TransformAxis, boolean>
--- @param origin Vec3
--- @return number
local function CalcScaleChange(startHit, hit, selectedAxes, axes, origin)
    local sV = startHit.Position - origin
    local eV = hit.Position - origin
    local cnt = CountMap(selectedAxes or {})
    local eps = 1e-4
    if cnt == 0 then return 1.0 end

    if cnt == 1 then
        local axisKey = nil
        for a,_ in pairs(selectedAxes) do axisKey = a end
        local axisVec = axes[axisKey]
        local sProj = sV:Dot(axisVec)
        local eProj = eV:Dot(axisVec)
        if math.abs(sProj) < eps then
            Warning("Gizmo: CalcScaleChange: start projection too small, cannot scale along single axis")
            return 1.0
        end
        return eProj / sProj
    elseif cnt == 2 then
        -- scale in plane: use lengths in the two-axis plane
        local a1,a2 = nil,nil
        for a,_ in pairs(selectedAxes) do
            if not a1 then a1 = a else a2 = a end
        end
        local axis1 = axes[a1]
        local axis2 = axes[a2]
        local s1 = sV:Dot(axis1); local s2 = sV:Dot(axis2)
        local e1 = eV:Dot(axis1); local e2 = eV:Dot(axis2)
        local sLen = math.sqrt(s1*s1 + s2*s2)
        local eLen = math.sqrt(e1*e1 + e2*e2)
        if math.abs(sLen) < eps then
            Warning("Gizmo: CalcScaleChange: start plane length too small, cannot scale in plane")
            return 1.0
        end
        return eLen / sLen
    else
        local sLen = sV:Length()
        local eLen = eV:Length()
        if math.abs(sLen) < eps then
            Warning("Gizmo: CalcScaleChange: start length too small, cannot scale")
            return 1.0
        end
        return eLen / sLen
    end
end

--- @param ray Ray
--- @return Vec3|number|nil
function Gizmo:GetDelta(ray)
    local hit = self:GetHit(ray)
    if not hit or not hit.Position then return nil end
    local startHit = self.StartHit
    if not startHit then Warning("Gizmo:GetDelta: No start hit recorded") return nil end

    local axes = self.Picker:GetAxes()
    local gizmoOrigin = Vec3.new(self.Picker.Position)
    local delta = nil
    if self.Mode == "Translate" then
        local worlddelta = hit.Position - startHit.Position
        delta = worlddelta
        if self.Space == "Local" or self.Space == "Parent" then
            -- reverse rotate delta by picker rotation
            -- let editor handle local translation
            local rot = Quat.new(self.Picker.Rotation)
            delta = rot:Inverse():Rotate(worlddelta)
        end
    elseif self.Mode == "Rotate" then
        local axis = next(self.SelectedAxis or {})
        if not axis then Warning("Gizmo:GetDelta: No axis selected for rotation") return nil end

        local startDir = (startHit.Position - gizmoOrigin):Normalize()
        local dir = (hit.Position - gizmoOrigin):Normalize()

        local axisVec = axes[axis]

        -- current raw angle (radians) between startDir and dir around axisVec
        local curAngle = CalcRotationChange(startDir, dir, axisVec, gizmoOrigin)

        if self.Space == "Local" or self.Space == "Parent" then
            -- same as above
            local rot = Quat.new(self.Picker.Rotation)
            axisVec = rot:Inverse():Rotate(axes[axis])
        end

        self._rotLastAngle = self._rotLastAngle or curAngle
        self._rotAccum = self._rotAccum or 0

        local diff = curAngle - self._rotLastAngle

        -- Unwrap the diff to be within (-pi, pi] to handle wrap-around
        if diff > math.pi then
            diff = diff - 2 * math.pi
        elseif diff <= -math.pi then
            diff = diff + 2 * math.pi
        end

        self._rotAccum = self._rotAccum + diff

        self._rotLastAngle = curAngle

        delta = { Angle = self._rotAccum, Axis = axisVec }

    elseif self.Mode == "Scale" then
        delta = Vec3.new{1,1,1}
        local scaleValue = CalcScaleChange(startHit, hit, self.SelectedAxis, axes, gizmoOrigin)

        local scaleVec = Vec3.new{1,1,1}
        for axis,_ in pairs(self.SelectedAxis or {}) do
            if axis == "X" then
                scaleVec[1] = scaleValue
            elseif axis == "Y" then
                scaleVec[2] = scaleValue
            elseif axis == "Z" then
                scaleVec[3] = scaleValue
            end
        end

        delta = scaleVec
        GizmoVisualizer.ScaleMultiplier = scaleVec
    end
        
    return delta
end

function Gizmo:SetupDragging()
    if self.Visualizations and #self.Visualizations > 0 then
        Post(NetChannel.Delete, { Guid = self.Visualizations })
    end

    self.Visualizations = {}
    local requests = 0
    local pickerPos = Vec3.new(self.Picker.Position)
    local pickerRot = Quat.new(self.Picker.Rotation)
    local requestId = Uuid_v4()
    local receive = ClientSubscribe("Visualization", function (data)
        if not data.RequestId or data.RequestId ~= requestId then return end
        for _,guid in pairs(data.Guid or {}) do
            table.insert(self.Visualizations, guid)
            ::continue::
        end
        if #self.Visualizations >= requests then
            return UNSUBSCRIBE_SYMBOL
        end
    end)
    if self.Mode == "Rotate" then
        local axis = nil
        for a,_ in pairs(self.SelectedAxis) do axis = a end
        local mouseRay = ScreenToWorldRay()
        if not mouseRay then Warning("Gizmo:SetupDragging: Failed to get mouse ray") return end
        local hit = self:GetHit(mouseRay)
        if not hit then hit = Hit.new(pickerPos, nil, 0, nil) end
        local dir = hit.Position - pickerPos
        local quat = DirectionToQuat(dir, Ext.Math.QuatRotate(pickerRot, GLOBAL_COORDINATE.Y), axis)

        self._rotLastAngle = nil
        self._rotAccum = 0

        local rotateScale = GizmoVisualizer:UpdateScale(self.Guid)
        local scale = ToVec3((0.6 * rotateScale) / 0.8) -- rotate gizmo radius is 0.6, translate gizmo's axis's length is 0.8

        requests = 2

        Post(NetChannel.Visualize, { Type = "Point", Position =  pickerPos, Rotation = quat, Scale = scale,  Duration = -1, RequestId = requestId })
        Post(NetChannel.Visualize, { Type = "Point", Position = pickerPos, Rotation = quat, Scale = scale,  Duration = -1, RequestId = requestId })
    else
        receive:Unsubscribe()
    end

    self.DraggingTimer = Timer:EveryFrame(function (timerID)
        if not self.IsDragging or not self.Picker or not self.StartHit or not self.SelectedAxis then
            self:StopDragging()
            Debug("Gizmo: Stopped dragging due to invalid state")
            return UNSUBSCRIBE_SYMBOL
        end

        local mouseRay = ScreenToWorldRay()
        if not mouseRay then Warning("Gizmo:SetupDragging: Failed to get mouse ray") return end
    
        local delta = self:GetDelta(mouseRay)
        if not delta then return end

        if self.Mode == "Rotate" then
            delta = delta --[[@as { Angle:number, Axis:Vec3 }]]
            self:OnDragRotate(delta)
        elseif self.Mode == "Translate" then
            delta = delta --[[@as Vec3]]
            self:OnDragTranslate(delta)
        elseif self.Mode == "Scale" then
            delta = delta --[[@as Vec3]]
            self:OnDragScale(delta)
        end

        self:Visualize()
    end)
end

function Gizmo:StopDragging()
    self:StopWithoutCallbacks()
    self:OnDragEnd()
end

function Gizmo:StopWithoutCallbacks()
    self.SelectedAxis = nil
    self.IsDragging = false
    self.StartHit = nil
    self._rotLastAngle = nil
    self._rotAccum = nil
    Timer:Cancel(self.DraggingTimer)
    self.DraggingTimer = nil
    if self.Visualizations and #self.Visualizations > 0 then
        Post(NetChannel.Delete, { Guid = self.Visualizations })
        self.Visualizations = {}
    end
    GizmoVisualizer.ScaleMultiplier = {1.0, 1.0, 1.0}
end

function Gizmo:OnDragStart() end
function Gizmo:OnDragTranslate(delta) end
function Gizmo:OnDragRotate(delta) end
function Gizmo:OnDragScale(delta) end
function Gizmo:OnDragEnd() end
function Gizmo:DragVisualize() end

function Gizmo:StopListeners()
    for k,v in pairs(self.Subscription) do
        if v then
            v:Unsubscribe()
            self.Subscription[k] = nil
        end
    end
    for k,v in pairs(self.Timers) do
        if v then
            Timer:Cancel(v)
            self.Timers[k] = nil
        end
    end
end

function Gizmo:Visualize(guid)
    guid = guid or self.Guid
    if not EntityExists(guid) then return end
    GizmoVisualizer:UpdateScale(guid)
    if self.SelectedAxis then
        for axis,_ in pairs(self.SelectedAxis) do
            GizmoVisualizer.HighLightGizmoAxis(axis, guid)
        end
        for _,axis in pairs({"X","Y","Z"}) do
            if not self.SelectedAxis[axis] then
                if self.Mode == "Translate" then
                    GizmoVisualizer.ResetGizmoAxis(axis, guid)
                else
                    GizmoVisualizer.HideGizmoAxis(axis, guid)
                end
            end
        end
        return
    end

    for axis,_ in pairs(self.HoveredAxis or {}) do
        GizmoVisualizer.HoverGizmoAxis(axis, guid)
    end

    for _,axis in pairs({"X","Y","Z"}) do
        if not (self.HoveredAxis and self.HoveredAxis[axis]) then
            GizmoVisualizer.ResetGizmoAxis(axis, guid)
        end
    end
end

function Gizmo:Hide(guid)
    guid = guid or self.Guid
    for _,axis in pairs({"X","Y","Z"}) do
        GizmoVisualizer.HideGizmoAxis(axis, guid)
    end
end
