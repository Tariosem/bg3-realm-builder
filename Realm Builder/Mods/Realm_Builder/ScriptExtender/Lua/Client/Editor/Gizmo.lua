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
--- @field Subscription table<string, RBSubscription>
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
end

function Gizmo:EmptyDrag()
    self.Editor._accuDelta = nil
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
    self:UpdatePicker()
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
    local rx, ry, rz, rw = table.unpack(Quat.Identity())

    if self.Space == "View" then
        rx, ry, rz, rw = GetCameraRotation()
    elseif self.Space == "Parent" then
        local parent = EntityStore:GetBindParent(target)
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
    local scale = GizmoVisualizer.UpdateScale(self.Guid)
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

function Gizmo:CancelDragging()
    self:StopWithoutCallbacks()
    self:EmptyDrag()
    self:StopDragging()
end

function Gizmo:SetupListeners()
    self:StopListeners()

    self.Subscription["LockAxis"] = SubscribeKeyInput({}, function (e)
        if not self.IsDragging then return end
        if e.Event ~= "KeyDown" or not e.Pressed or e.Repeat then return end

        local mouseRay = ScreenToWorldRay()
        if not mouseRay then Warning("Gizmo:LockAxis: Failed to get mouse ray") return end
    
        if not GLOBAL_COORDINATE[e.Key] then return end

        local axisToLock = tostring(e.Key):sub(1,1):upper()

        if self.Mode == "Rotate" then
            if self.SelectedAxis and self.SelectedAxis[axisToLock] and CountMap(self.SelectedAxis) == 1 then return end
            self:RestartDragging(mouseRay, { [axisToLock] = true })
            return
        end

        local axes = { X = true, Y = true, Z = true }
        if self.SelectedAxis and self.SelectedAxis[axisToLock] and CountMap(self.SelectedAxis) == 1 then
            -- do nothing
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
            self:CancelDragging()
            --self:EmptyDrag()
            --self:StopDragging()
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
        end
        self:Visualize()
    end)

    
    self.Timers["Stick"] = Timer:EveryFrame(function (timerID)
        if not self.Guid then return end
        local target = self.Targets and self.Targets[1]
        if not target or not EntityExists(target) then self:Hide() return end
        local pos = {CGetPosition(target)}
        local rot = Quat.Identity()
        if self.Space == "Local" then
            rot = {CGetRotation(target)}
        elseif self.Space == "Parent" then
            local parent = EntityStore:GetBindParent(target)
            if parent then
                rot = {CGetRotation(parent)}
            end
        elseif self.Space == "View" then
            rot = {GetCameraRotation()}
        end
        if not rot or #rot ~= 4 then
            rot = Quat.Identity()
        end
        NetChannel.SetTransform:SendToServer({
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
    --Debug("Gizmo:DeleteItem", guid)
    self:StopListeners()
    NetChannel.Delete:SendToServer({ Guid = guid })
    self.Guid = nil
end

function Gizmo:CreateItem()
    if self.Guid then
        self:DeleteItem()
    end

    if self.Targets and #self.Targets == 0 then
        return
    end

    local pos = {CGetPosition(self.Targets and self.Targets[1])}

    NetChannel.ManageGizmo:RequestToServer({
        GizmoType = self.Mode,
        Position = pos
    }, function (response)
        self.Guid = response.Guid
        if not next(self.Timers) then
            self:SetupListeners()
        end
    end)
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
        --Debug("Gizmo:SetMode: Changed mode to", mode)
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

--#region math

local lastDraw = 0

--- @param ray Ray
function Gizmo:GetHit(ray)
    local cnt = CountMap(self.SelectedAxis or {})
    if cnt == 0 then Debug("Gizm:GetHit: No Axis ") return Hit.new(self.Picker.Position, nil, 0, nil) end

    local hit = nil
    if self.Mode == "Rotate" then
        local axis = nil
        for a,_ in pairs(self.SelectedAxis) do axis = a end
        hit = self.Picker:HitPlanePerpToAxis(ray, axis)

        local origin = self.Picker.Position

        if not hit then hit = Hit.new(self.Picker:ProjectPointOnPlanePerpToAxis(ray.Origin, axis), nil, 0, nil) end
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
                hit = ray:IntersectPlane(self.StartHit.Position, normal, true)
            else
                hit = self.Picker:HitPlaneByNormal(ray, normal)
            end
        end
    end

    if false and hit and Ext.Timer.MonotonicTime() - lastDraw > 1000 then
        NetChannel.Visualize:RequestToServer({
            Type = "Point",
            Position = hit.Position,
            Duration = 1000
        }, function (response)
        end)
        lastDraw = Ext.Timer.MonotonicTime()
        --Debug("Gizmo:GetHit: Hit at ", hit.Position and tostring(hit.Position) or "nil")
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
    
    return angle --WrapQuat(Ext.Math.QuatRotateAxisAngle(Quat.Identity(), axis, angle))
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
    local eps = EPSILON
    if cnt == 0 then return 1.0 end

    return (eV:Length() + eps) / (sV:Length() + eps)
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

--#endregion math

function Gizmo:SetupDragging()
    self.Editor._accuDelta = nil
    self.RotatePointer = self.RotatePointer or {}
    local pickerPos = Vec3.new(self.Picker.Position)
    local pickerRot = Quat.new(self.Picker.Rotation)
    if self.Mode == "Rotate" then
        local axis = nil
        for a,_ in pairs(self.SelectedAxis) do axis = a end
        local mouseRay = ScreenToWorldRay()
        if not mouseRay then Warning("Gizmo:SetupDragging: Failed to get mouse ray") return end
        local hit = self:GetHit(mouseRay)
        local dir = hit.Position - pickerPos
        local quat = DirectionToQuat(dir, Ext.Math.QuatRotate(pickerRot, GLOBAL_COORDINATE.Y), axis)

        self._rotLastAngle = nil
        self._rotAccum = 0

        for i = #self.RotatePointer, 1, -1 do
            local guid = self.RotatePointer[i]
            if not EntityExists(guid) then
                table.remove(self.RotatePointer, i)
            end
        end

        if #self.RotatePointer == 0 then
            for i=1, 2 do
                NetChannel.Visualize:RequestToServer({
                    Type = "Point",
                    Position = pickerPos,
                    Rotation = quat,
                    Duration = -1,
                }, function (response)
                    for _,guid in ipairs(response or {}) do
                        local cnt = 0
                        Timer:EveryFrame(function (timerID)
                            if cnt > 300 then
                                Warning("Gizmo:SetupDragging: Failed to visualize rotate pointer")
                                return UNSUBSCRIBE_SYMBOL
                            end
                            if not VisualHelpers.GetEntityVisual(guid) then cnt = cnt + 1 end
                            GizmoVisualizer.VisualizeRotateSymbol(guid, axis)
                            return UNSUBSCRIBE_SYMBOL
                        end)
                        table.insert(self.RotatePointer, guid)
                    end
                end)
            end
        else
            NetChannel.SetTransform:SendToServer({
                Guid = self.RotatePointer[1],
                Transforms = {
                    [self.RotatePointer[1]] = {
                        Translate = pickerPos,
                        RotationQuat = quat,
                    }
                }
            })
        end
    else
        if self.RotatePointer and #self.RotatePointer > 0 then
            for _,guid in ipairs(self.RotatePointer or {}) do
                GizmoVisualizer.HideGizmo(guid)
            end
        end
    end

    self.DraggingTimer = Timer:EveryFrame(function (timerID)
        if not self.IsDragging or not self.Picker or not self.StartHit or not self.SelectedAxis then
            self:StopDragging()
            --Debug("Gizmo: Stopped dragging due to invalid state")
            return UNSUBSCRIBE_SYMBOL
        end

        local mouseRay = ScreenToWorldRay()
        if not mouseRay then Warning("Gizmo:SetupDragging: Failed to get mouse ray") return end
    
        local delta = self:GetDelta(mouseRay)
        if not delta then return end

        if self.Mode == "Rotate" then
            delta = delta --[[@as { Angle:number, Axis:Vec3 }]]
            self:OnDragRotate(delta)
            self:VisualizeRotatePointer()
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

function Gizmo:RegetStartHit()
    if not self.IsDragging then Warning("Gizmo:RegetStartHit: Not dragging") return end
    local mouseRay = ScreenToWorldRay()
    if not mouseRay then Warning("Gizmo:RegetStartHit: Failed to get mouse ray") return end
    self.StartHit = self:GetHit(mouseRay)
    self._rotLastAngle = nil
    self._rotAccum = 0
end

function Gizmo:StopDragging()
    self:StopWithoutCallbacks()
    self:OnDragEnd()
    self.IsDragging = false
end

function Gizmo:StopWithoutCallbacks()
    Timer:Cancel(self.DraggingTimer)
    self.DraggingTimer = nil
    self.SelectedAxis = nil
    self.StartHit = nil
    self._rotLastAngle = nil
    self._rotAccum = nil
    self.Editor._accuDelta = nil
    GizmoVisualizer.ScaleMultiplier = {1.0, 1.0, 1.0}
    for _,guid in ipairs(self.RotatePointer or {}) do
        GizmoVisualizer.HideGizmo(guid)
    end
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
    GizmoVisualizer.UpdateScale(guid)
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

function Gizmo:VisualizeRotatePointer()
    local firstPointer = self.RotatePointer and self.RotatePointer[1]
    local pointer = self.RotatePointer and self.RotatePointer[#self.RotatePointer]
    if not pointer or not EntityExists(pointer) then return end
    local target = self.Targets and self.Targets[1]
    if not target or not EntityExists(target) then return end
    local pickerPos = Vec3.new(self.Picker.Position)

    local startDir = Quat.new(CGetRotation(firstPointer))

    local axis = nil
    for a,_ in pairs(self.SelectedAxis) do axis = a end

    for _,guid in ipairs(self.RotatePointer or {}) do
        GizmoVisualizer.VisualizeRotateSymbol(guid, axis)
    end

    local startQuat = self.Editor.StartTransforms[target].RotationQuat
    local curQuat = Quat.new(CGetRotation(target))

    local deltaQuat = curQuat * startQuat:Inverse()

    local curPointQuat = deltaQuat * startDir

    NetChannel.SetTransform:SendToServer({
        Guid = pointer,
        Transforms = {
            [pointer] = {
                Translate = pickerPos,
                RotationQuat = curPointQuat,
            }
        }
    })
end

function Gizmo:Hide(guid)
    guid = guid or self.Guid
    if not EntityExists(guid) then return end
    GizmoVisualizer.HideGizmo(guid)
end

function Gizmo:Disable()
    if self.IsDragging then
        self:EmptyDrag()
        self:StopDragging()
    end

    self:StopListeners()
    self:Hide()
end

function Gizmo:Enable()
    if not self.Guid and self.Targets and #self.Targets > 0 then
        self:CreateItem()
    end
    self:SetupListeners()
end 