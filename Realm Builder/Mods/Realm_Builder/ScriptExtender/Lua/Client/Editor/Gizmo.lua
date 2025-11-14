--- @class Gizmo
--- @field Editor TransformEditor
--- @field Mode TransformEditorMode
--- @field SelectedAxis table<TransformAxis, boolean> | nil
--- @field HoveredAxis table<TransformAxis, boolean> | nil
--- @field StartHit Hit | nil
--- @field DraggingTimer TimerID|nil -- emit drag events every frame while dragging
--- @field IsDragging boolean -- whether currently dragging
--- @field SlowDown boolean
--- @field Guid Guid -- Gizmo entity guid, this is only a visual representation, most pick and drag logic is handled in gizmo picker
--- @field PivotPosition Vec3 -- current pivot position
--- @field PivotRotation Quat -- current pivot rotation
--- @field Step number -- multiplier for delta steps
--- @field SavedGizmos table<TransformEditorMode, GUIDSTRING> -- guids of saved gizmos for each mode
--- @field RotatePointer GUIDSTRING[] -- guids of rotate pointer visualizations
--- @field Picker GizmoPicker
--- @field Visualizer GizmoVisualizer 
--- @field Subscriptions table<string, RBSubscription>
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
    self.SelectedAxis = nil
    self.HoveredAxis = nil
    self.DisableHover = false
    self.StartHit = nil
    self.Guid = nil
    self.SavedGizmos = {}
    self.Picker = GizmoPicker.new(self)
    self.Visualizer = GizmoVisualizer.new()
    self.Subscriptions = {}
    self.Timers = {}
    self.SlowDown = false

    self.Step = 1.0
end

--- emit a zero-delta drag event
function Gizmo:EmptyDrag()
    self._delta = nil
    self._accuDelta = nil
    if self.Mode == "Rotate" then
        self:OnDragRotate({ Angle = 0, Axis = Vec3.new { 0, 0, 0 } })
    elseif self.Mode == "Translate" then
        self:OnDragTranslate(Vec3.new { 0, 0, 0 })
    else
        self:OnDragScale(Vec3.new { 1, 1, 1 })
    end
end

function Gizmo:SetScale(scale)
    self.Visualizer.GizmoScale = scale
end

function Gizmo:UpdatePicker()
    if not self.PivotPosition or not self.PivotRotation then return end
    local scale = self.Visualizer:UpdateScale(self.PivotPosition)
    self.Picker:SetTransform(self.PivotPosition, self.PivotRotation, scale)
end

function Gizmo:GetPickerTransform()
    return self.Picker.Position, self.Picker.Rotation, self.Picker.Scale
end

function Gizmo:StartDragging(mouseRay, hit)
    mouseRay = mouseRay or ScreenToWorldRay()
    if not mouseRay then
        Warning("Gizmo:DragStart: Failed to get mouse ray")
        return
    end
    hit = hit or self.Picker:Hit(mouseRay)
    self.IsDragging = true
    if hit and hit.Axis then
        self.SelectedAxis = hit.Axis
    else
        self.SelectedAxis = { X = true, Y = true, Z = true }
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

    if self.Mode == Enums.TransformEditorMode.Rotate and CountMap(axes) == 2 then
        axes = { [next(axes)] = true }
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
    self.IsDragging = false
    self:OnDragEnd(true)
end

function Gizmo:SetupListeners()
    self:StopListeners()

    self.Subscriptions["LockAxis"] = SubscribeKeyInput({}, function(e)
        if not self.IsDragging then return end
        if e.Event ~= "KeyDown" or not e.Pressed or e.Repeat then return end

        local mouseRay = ScreenToWorldRay()
        if not mouseRay then
            Warning("Gizmo:LockAxis: Failed to get mouse ray")
            return
        end

        if not GLOBAL_COORDINATE[e.Key] then return end

        local axisToLock = tostring(e.Key):sub(1, 1):upper()

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


    self.Subscriptions["MMBLockAxis"] = SubscribeMouseInput({}, function(e)
        if not self.IsDragging then return end
        if not e.Pressed or tonumber(e.Button) ~= 2 then return end

        local mouseRay = ScreenToWorldRay()
        if not mouseRay then
            Warning("Gizmo:MMBLockAxis: Failed to get mouse ray")
            return
        end

        local axisToLock = self.Picker:ClosestPlane(mouseRay)

        if self.SelectedAxis and self.SelectedAxis[axisToLock] and CountMap(self.SelectedAxis) == 1 then return end

        local axes = { [axisToLock] = true }

        self:RestartDragging(mouseRay, axes)
    end)

    self.Subscriptions["SlowDown"] = SubscribeKeyInput({ Key = "LSHIFT" }, function(e)
        if e.Repeat then return end
        if not self.IsDragging then return end
        if e.Event == "KeyDown" then
            self.SlowDown = true
        else
            self.SlowDown = false
        end
    end)

    self.Subscriptions["DragStart"] = SubscribeMouseInput({}, function(e)
        if e.Button == 1 and e.Pressed and self.Picker and not self.IsDragging then
            local mouseRay = ScreenToWorldRay()
            if not mouseRay then
                Warning("Gizmo:DragStart: Failed to get mouse ray")
                return
            end
            local hit = self.Picker:Hit(mouseRay)
            if not hit or not hit.Axis then return end
            self:StartDragging(mouseRay, hit)
        end
    end)

    self.Subscriptions["DragCancel"] = SubscribeMouseInput({}, function(e)
        if not self.IsDragging then return end
        if e.Pressed and tonumber(e.Button) == 3 then
            self:CancelDragging()
        end
    end)

    self.Subscriptions["DragEnd"] = SubscribeMouseInput({}, function(e)
        if not self.IsDragging then return end
        if e.Button == 1 and not e.Pressed then
            self:StopDragging()
        end
    end)

    self.Timers["DetectHover"] = Timer:EveryFrame(function(timerID)
        if self.IsDragging or not self.Picker then return end
        local mouseRay = ScreenToWorldRay()
        if not mouseRay then
            Warning("Gizmo:DetectHover: Failed to get mouse ray")
            return
        end

        self:UpdatePicker()
        local hit = self.Picker:Hit(mouseRay)
        if hit and hit.Axis then
            self.HoveredAxis = hit.Axis
        else
            self.HoveredAxis = nil
        end
        self:Visualize()
    end)

    self.Timers["Stick"] = Timer:EveryFrame(function(timerID)
        if self.IsDragging then return end
        if not self.Guid then return end
        
        local pos, rot = self:GetPivot()
        local allGuids = { self.Guid }
        for _, guid in pairs(self.SavedGizmos) do
            table.insert(allGuids, guid)
        end

        self.PivotPosition = pos
        self.PivotRotation = rot

        local transforms = {}
        for _, guid in ipairs(allGuids) do
            transforms[guid] = {
                Translate = pos,
                RotationQuat = rot,
            }
        end
        NetChannel.SetTransform:SendToServer({
            Guid = allGuids,
            Transforms = transforms
        })
    end)
end

--- @return Vec3, Quat
function Gizmo:GetPivot()
    return {0,0,0}, {0,0,0,1}
end

function Gizmo:DeleteItem()
    local guid = self.Guid
    --Debug("Gizmo:DeleteItem", guid)
    self:StopListeners()
    NetChannel.Delete:SendToServer({ Guid = guid })
    self.Guid = nil
    self.SavedGizmos[self.Mode] = nil
end

function Gizmo:CreateItem()
    -- hide original gizmo if exists
    local pos = self.PivotPosition or {0,0,0}

    if self.SavedGizmos[self.Mode] and EntityExists(self.SavedGizmos[self.Mode]) then
        local originGuid = self.Guid
        self.Guid = self.SavedGizmos[self.Mode]
        self.Visualizer:HideGizmo(originGuid)

        NetChannel.SetAttributes:SendToServer({
            Guid = self.Guid,
            Attributes = {
                Visible = true,
            }
        })
        NetChannel.SetAttributes:SendToServer({
            Guid = originGuid,
            Attributes = {
                Visible = false,
            }
        })

        return
    elseif self.SavedGizmos[self.Mode] then
        -- make sure it's dead
        NetChannel.Delete:SendToServer({ Guid = self.SavedGizmos[self.Mode] })
        self.SavedGizmos[self.Mode] = nil
    end
     
    NetChannel.ManageGizmo:RequestToServer({
        GizmoType = self.Mode,
        Position = pos
    }, function(response)
        local orginGuid = self.Guid
        self.Guid = response.Guid
        self.Visualizer:HideGizmo(orginGuid)
        self.SavedGizmos[self.Mode] = response.Guid
        local tryCnt = 0
        
        Timer:EveryFrame(function(timerID)
            if tryCnt > 300 then return UNSUBSCRIBE_SYMBOL end
            if not VisualHelpers.GetEntityVisual(self.Guid) then tryCnt = tryCnt + 1 return end

            NetChannel.SetAttributes:SendToServer({
                Guid = self.Guid,
                Attributes = {
                    Visible = true,
                }
            })
            return UNSUBSCRIBE_SYMBOL
        end)

    end)
end

function Gizmo:SetMode(mode)
    if not Enums.TransformEditorMode[mode] then
        Warning("Gizmo:SetMode: Invalid mode '" .. tostring(mode) .. "'")
        return
    end
    if mode and mode ~= self.Mode then
        local ifRestart = self.IsDragging
        if self.IsDragging then
            self:EmptyDrag()
            --self:StopWithoutCallbacks()
        end

        self.Mode = mode
        self:CreateItem()
        if ifRestart then
            self:RestartDragging()
        end
    end
end

--#region math

local lastDraw = 0

--- @param ray Ray
function Gizmo:GetHit(ray)
    local cnt = CountMap(self.SelectedAxis or {})
    if cnt == 0 then
        Debug("Gizm:GetHit: No Axis ")
        return Hit.new(self.Picker.Position, nil, 0, nil)
    end

    local hit = nil
    local pickerAxes = self.Picker:GetAxes()
    local axis = nil
    if self.Mode == "Rotate" then
        if cnt == 1 or cnt == 2 then
            for a, _ in pairs(self.SelectedAxis) do axis = pickerAxes[a] break end
            if not axis then
                Warning("Gizmo:GetHit: Failed to get axis vector for rotation")
                return Hit.new(self.Picker.Position, nil, 0, nil)
            end
        elseif cnt == 3 then
            axis = GetCameraForward() 
            if not axis then
                Warning("Gizmo:GetHit: Failed to get camera forward for 3-axis rotation")
                return Hit.new(self.Picker.Position, nil, 0, nil)
            end
        else
            Warning("Gizmo:GetHit: Invalid axis count for rotation: " .. tostring(cnt))
            return Hit.new(self.Picker.Position, nil, 0, nil)
        end

        hit = self.Picker:HitPlaneByNormal(ray, axis)
        --- @diagnostic disable-next-line
        if not hit then hit = Hit.new(self.Picker:ProjectPointOnPlanePerpToAxis(ray.Origin, axis), nil, 0, nil) end
    else
        if cnt == 1 then
            local axisName = nil
            for a, _ in pairs(self.SelectedAxis) do axisName = a break end
            -- https://underdisc.net/blog/6_gizmos/index.html
            local p = self.Picker:ClosestPointOnAxis(ray, axisName)
            hit = Hit.new(p, nil, (p - ray.Origin):Length(), nil)
            axis = pickerAxes[axisName]
        elseif cnt == 2 then
            hit = self.Picker:HitPlaneByAxes(ray, self.SelectedAxis)
        elseif cnt == 3 then
            local normal = GetCameraForward()
            if self.StartHit then
                hit = ray:IntersectPlane(self.StartHit.Position, normal, true)
            else
                hit = self.Picker:HitPlaneByNormal(ray, normal)
            end
        else
            Warning("Gizmo:GetHit: Invalid axis count for translation/scale: " .. tostring(cnt))
            return Hit.new(self.Picker.Position, nil, 0, nil)
        end
    end

    if false and hit and Ext.Timer.MonotonicTime() - lastDraw > 1000 then
        NetChannel.Visualize:RequestToServer({
            Type = "Point",
            Position = hit.Position,
            Duration = 1000
        }, function(response)
        end)
        lastDraw = Ext.Timer.MonotonicTime()
        --Debug("Gizmo:GetHit: Hit at ", hit.Position and tostring(hit.Position) or "nil")
    end

    if not hit or not hit.Position then
        return Hit.new(self.Picker.Position, nil, 0, nil)
    end

    return hit, axis
end

--- Ext.Math.Angle doesn't seem to return signed angles
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
    local hit, axis = self:GetHit(ray)
    if not hit or not hit.Position then return nil end
    local startHit = self.StartHit
    if not startHit then
        Warning("Gizmo:GetDelta: No start hit recorded")
        return nil
    end

    local axes = self.Picker:GetAxes()
    local gizmoOrigin = Vec3.new(self.Picker.Position)
    local delta = nil
    if self.Mode == "Translate" then
        delta = hit.Position - startHit.Position
    elseif self.Mode == "Rotate" then
        local startDir = (startHit.Position - gizmoOrigin):Normalize()
        local dir = (hit.Position - gizmoOrigin):Normalize()

        local axisVec = axis

        -- current raw angle (radians) between startDir and dir around axisVec
        local curAngle = CalcRotationChange(startDir, dir, axisVec, gizmoOrigin)

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
        delta = Vec3.new { 1, 1, 1 }
        local scaleValue = CalcScaleChange(startHit, hit, self.SelectedAxis, axes, gizmoOrigin)

        local scaleVec = Vec3.new { 1, 1, 1 }
        for axisName, _ in pairs(self.SelectedAxis or {}) do
            if axisName == "X" then
                scaleVec[1] = scaleValue
            elseif axisName == "Y" then
                scaleVec[2] = scaleValue
            elseif axisName == "Z" then
                scaleVec[3] = scaleValue
            end
        end

        delta = scaleVec
    end

    return delta
end

--#endregion math

function Gizmo:SetupDragging()
    self._accuDelta = nil
    self.RotatePointer = self.RotatePointer or {}
    local pickerPos = Vec3.new(self.Picker.Position)
    local pickerRot = Quat.new(self.Picker.Rotation)
    if self.Mode == "Rotate" then
        local axis = nil
        for a, _ in pairs(self.SelectedAxis) do axis = a end
        local mouseRay = ScreenToWorldRay()
        if not mouseRay then
            Warning("Gizmo:SetupDragging: Failed to get mouse ray")
            return
        end
        local hit = self:GetHit(mouseRay)
        local dir = hit.Position - pickerPos
        local quat = DirectionToQuat(dir, Ext.Math.QuatRotate(pickerRot, GLOBAL_COORDINATE.Y), axis)

        self._pointerStartDir = quat
        self._rotLastAngle = nil
        self._rotAccum = 0

        for i = #self.RotatePointer, 1, -1 do
            local guid = self.RotatePointer[i]
            if not EntityExists(guid) then
                table.remove(self.RotatePointer, i)
            end
        end

        if #self.RotatePointer < 2 then
            for i = 1, 2 - #self.RotatePointer do
                NetChannel.Visualize:RequestToServer({
                    Type = "Point",
                    Position = pickerPos,
                    Scale = ((0.6 * self.Visualizer.Scale[1]) / 0.81),
                    Rotation = quat,
                    Duration = -1,
                }, function(response)
                    for _, guid in ipairs(response or {}) do
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
            for _, guid in ipairs(self.RotatePointer or {}) do
                self.Visualizer:HideGizmo(guid)
            end
        end
    end

    local movableGizmo = MovableProxy.CreateByGuid(self.Guid)

    self.DraggingTimer = Timer:EveryFrame(function(timerID)
        if not self.IsDragging or not self.Picker or not self.StartHit or not self.SelectedAxis then
            self:StopDragging()
            --Debug("Gizmo: Stopped dragging due to invalid state")
            return UNSUBSCRIBE_SYMBOL
        end

        local mouseRay = ScreenToWorldRay()
        if not mouseRay then
            Warning("Gizmo:SetupDragging: Failed to get mouse ray")
            return
        end

        local delta = self:GetDelta(mouseRay)
        if not delta then return end

        delta = self:StepDelta(delta)

        delta = self:LerpDelta(delta)
        if not delta then return end -- may return nil to skip this frame

        if self.Mode == "Rotate" then
            delta = delta --[[@as { Angle:number, Axis:Vec3 }]]
            self:VisualizeRotatePointer(delta.Angle, delta.Axis)
            self:OnDragRotate(delta)
        elseif self.Mode == "Translate" then
            delta = delta --[[@as Vec3]]
            self:OnDragTranslate(delta)
            movableGizmo:SetWorldTranslate(self.PivotPosition + delta)
        elseif self.Mode == "Scale" then
            delta = delta --[[@as Vec3]]
            self.Visualizer.ScaleMultiplier = delta
            self:OnDragScale(delta)
        end

        self:Visualize()
    end)
end

function Gizmo:StepDelta(delta)
    if self.Mode == "Translate" then
        delta = delta * self.Step
    elseif self.Mode == "Rotate" then
        delta = { Angle = delta.Angle * self.Step, Axis = delta.Axis }
    elseif self.Mode == "Scale" then
        local scaleVec = Vec3.new { 1, 1, 1 }
        delta = scaleVec + (delta - scaleVec) * self.Step
    end
    return delta
end

local lerpFactor = 0.1
local handlers = {
    Translate = function(o, delta)
        if o.SlowDown and not o._delta then
            o._delta = delta
        elseif o.SlowDown and o._delta then
            delta = (delta - o._delta) * lerpFactor + o._delta
        elseif o._delta and not o.SlowDown then
            o:RegetStartHit()
            delta = (delta - o._delta) * lerpFactor + o._delta
            o._accuDelta = (o._accuDelta or Vec3.new { 0, 0, 0 }) + delta
            o._delta = nil
            return
        end

        if o._accuDelta then
            delta = o._accuDelta + delta
        end
        return delta
    end,

    Rotate = function(o, delta)
        local deltaAngle = delta.Angle
        if o.SlowDown and not o._delta then
            o._delta = deltaAngle
        elseif o.SlowDown and o._delta then
            deltaAngle = (deltaAngle - o._delta) * lerpFactor + o._delta
        elseif o._delta and not o.SlowDown then
            o:RegetStartHit()
            deltaAngle = (deltaAngle - o._delta) * lerpFactor + o._delta
            o._accuDelta = (o._accuDelta or 0) + deltaAngle
            o._delta = nil
            return
        end

        delta.Angle = deltaAngle
        if o._accuDelta then
            return { Angle = o._accuDelta + deltaAngle, Axis = delta.Axis }
        end
        return delta
    end,

    Scale = function(o, delta)
        if o.SlowDown and not o._delta then
            o._delta = delta
        elseif o.SlowDown and o._delta then
            delta = (delta - o._delta) * lerpFactor + o._delta
        elseif o._delta and not o.SlowDown then
            o:RegetStartHit()
            delta = (delta - o._delta) * 0.1 + o._delta
            o._accuDelta = (o._accuDelta or Vec3.new { 1, 1, 1 }) * delta
            o._delta = nil
            return
        end

        if o._accuDelta then
            delta = o._accuDelta * delta
        end
        return delta
    end,
}

function Gizmo:LerpDelta(delta)
    local handler = handlers[self.Mode]
    if handler then
        return handler(self, delta)
    end
    return delta
end

function Gizmo:RegetStartHit()
    if not self.IsDragging then
        Warning("Gizmo:RegetStartHit: Not dragging")
        return
    end
    local mouseRay = ScreenToWorldRay()
    if not mouseRay then
        Warning("Gizmo:RegetStartHit: Failed to get mouse ray")
        return
    end
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
    self._accuDelta = nil
    self._delta = nil
    self.Visualizer.ScaleMultiplier = { 1.0, 1.0, 1.0 }
    for _, guid in ipairs(self.RotatePointer or {}) do
        self.Visualizer:HideGizmo(guid)
    end
end

function Gizmo:OnDragStart() end

function Gizmo:OnDragTranslate(delta) end

function Gizmo:OnDragRotate(delta) end

function Gizmo:OnDragScale(delta) end

function Gizmo:OnDragEnd(isCancelled) end

function Gizmo:DragVisualize() end

function Gizmo:StopListeners()
    for k, v in pairs(self.Subscriptions) do
        if v then
            v:Unsubscribe()
            self.Subscriptions[k] = nil
        end
    end
    for k, v in pairs(self.Timers) do
        if v then
            Timer:Cancel(v)
            self.Timers[k] = nil
        end
    end
end

function Gizmo:Visualize(guid)
    guid = guid or self.Guid
    if not EntityExists(guid) then return end
    local pos = self.PivotPosition
    self.Visualizer:UpdateScale(pos)

    local selectedAxis = DeepCopy(self.SelectedAxis)
    if CountMap(selectedAxis) > 2 and self.Mode == "Rotate" then
        --- treat as single-axis rotation on closest axis
        selectedAxis = {}
    end

    if self.SelectedAxis then
        for axis, _ in pairs(selectedAxis or {}) do
            self.Visualizer:HighLightGizmoAxis(axis, guid)
        end
        for _, axis in pairs({ "X", "Y", "Z" }) do
            if not (selectedAxis and selectedAxis[axis]) then
                if self.Mode == "Translate" then
                    self.Visualizer:ResetGizmoAxis(axis, guid)
                else
                    self.Visualizer:HideGizmoAxis(axis, guid)
                end
            end
        end

        return
    end

    for axis, _ in pairs(self.HoveredAxis or {}) do
        self.Visualizer:HoverGizmoAxis(axis, guid)
    end

    for _, axis in pairs({ "X", "Y", "Z" }) do
        if not (self.HoveredAxis and self.HoveredAxis[axis]) then
            self.Visualizer:ResetGizmoAxis(axis, guid)
        end
    end
end

function Gizmo:VisualizeRotatePointer(angle, axis)
    local pointer = self.RotatePointer and self.RotatePointer[#self.RotatePointer]
    if not pointer or not EntityExists(pointer) then return end
    local pickerPos = self.Picker.Position
    local startQuat = self._pointerStartDir

    local cnt = CountMap(self.SelectedAxis or {})
    if cnt > 2 then
        for _,viz in ipairs(self.RotatePointer or {}) do
            self.Visualizer:HideGizmo(viz)
        end
        return 
    end

    for _, guid in ipairs(self.RotatePointer or {}) do
        local axisName = next(self.SelectedAxis or {}) or "X"
        self.Visualizer:VisualizeRotatePointer(guid, axisName)
    end

    local curPointQuat = Ext.Math.QuatRotateAxisAngle(Quat.Identity(), axis, angle)
    curPointQuat = Ext.Math.QuatMul(curPointQuat, startQuat)

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

function Gizmo:Hide()
    if self.Guid and EntityExists(self.Guid) then
        self.Visualizer:HideGizmo(self.Guid)
    end
    self.Visualizer:HideGizmo(self.Rotate)
    self.Visualizer:HideGizmo(self.Scale)
    self.Visualizer:HideGizmo(self.Translate)
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
    if not self.Guid then
        self:CreateItem()
    end
    self:SetupListeners()
end
