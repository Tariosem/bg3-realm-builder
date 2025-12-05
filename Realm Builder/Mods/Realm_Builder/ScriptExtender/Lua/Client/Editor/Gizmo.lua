--- @class TransformGizmo
--- @field Editor TransformEditor
--- @field Mode TransformEditorMode 
--- @field ActiveMode TransformEditorMode
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
--- @field new fun(editor: TransformEditor): TransformGizmo
--- @field OnDragStart fun(self: TransformGizmo)
--- @field OnDragTranslate fun(self: TransformGizmo, delta: Vec3)
--- @field OnDragRotate fun(self: TransformGizmo, delta: { Angle:number, Axis:Vec3 })
--- @field OnDragScale fun(self: TransformGizmo, delta: Vec3)
--- @field OnDragEnd fun(self: TransformGizmo)
TransformGizmo = _Class("Gizmo")

--- @class QuatInfo
--- @field Angle number
--- @field Axis Vec3

function TransformGizmo:__init(editor)
    self.Editor = editor
    self.Mode = "Translate"
    self.ActiveMode = "Translate"
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

    Ext.Events.Shutdown:Subscribe(function()
        self:Disable()
        self:DeleteItem()
        for _, guid in pairs(self.SavedGizmos) do
            NetChannel.Delete:SendToServer({ Guid = guid })
        end
    end)
end

--- emit a zero-delta drag event
function TransformGizmo:EmptyDrag()
    self._delta = nil
    self._accuDelta = nil
    if self.ActiveMode == "Rotate" then
        self:OnDragRotate({ Angle = 0, Axis = Vec3.new { 0, 0, 0 } })
    elseif self.ActiveMode == "Translate" then
        self:OnDragTranslate(Vec3.new { 0, 0, 0 })
    else
        self:OnDragScale(Vec3.new { 1, 1, 1 })
    end
end

function TransformGizmo:SetScale(scale)
    self.Visualizer.GizmoScale = scale
end

function TransformGizmo:UpdatePicker()
    if not self.PivotPosition or not self.PivotRotation then return end
    if not #self.PivotPosition == 3 then return end

    local scale = self.Visualizer:UpdateScale(self.PivotPosition)
    self.Picker:SetTransform(self.PivotPosition, self.PivotRotation, scale)
end

function TransformGizmo:GetPickerTransform()
    return self.Picker.Position, self.Picker.Rotation, self.Picker.Scale
end

function TransformGizmo:StartDragging(mouseRay, hit)
    mouseRay = mouseRay or ScreenToWorldRay()
    if not mouseRay then
        Warning("Gizmo:DragStart: Failed to get mouse ray")
        return
    end
    hit = hit or self.Picker:Hit(mouseRay)
    self.IsDragging = true
    if hit and hit.Axis then
        self.SelectedAxis = hit.Axis
        self.ActiveMode = hit.HitMode or self.ActiveMode
    else
        self.SelectedAxis = { X = true, Y = true, Z = true }
    end
    self.HoveredAxis = nil
    self.StartHit = self:GetHit(mouseRay)

    self:OnDragStart()
    self:SetupDragging()
    self:DragVisualize()
end

function TransformGizmo:RestartDragging(mouseRay, axes)
    mouseRay = mouseRay or ScreenToWorldRay()
    axes = axes or DeepCopy(self.SelectedAxis) or { X = true, Y = true, Z = true }

    if self.ActiveMode == Enums.TransformEditorMode.Rotate and CountMap(axes) == 2 then
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

function TransformGizmo:CancelDragging()
    self:StopWithoutCallbacks()
    self:EmptyDrag()
    self.IsDragging = false
    self:OnDragEnd(true)
end

function TransformGizmo:SetupListeners()
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
        self.SelectedAxis = self.SelectedAxis or {}

        local axisToLock = tostring(e.Key):sub(1, 1):upper()

        local curCnt = CountMap(self.SelectedAxis)
        if self.ActiveMode == "Rotate" then
            if self.SelectedAxis and self.SelectedAxis[axisToLock] and curCnt == 1 then return end
            self:RestartDragging(mouseRay, { [axisToLock] = true })
            return
        end

        local axes = { X = true, Y = true, Z = true }
        if self.SelectedAxis and self.SelectedAxis[axisToLock] and curCnt == 1 then
            -- do nothing
        elseif e.Modifiers == "LShift" or e.Modifiers == "RShift" then
            axes[axisToLock] = nil
        else
            axes = { [axisToLock] = true }
        end

        local newCnt = CountMap(axes)
        local changed = curCnt ~= newCnt
        for a, _ in pairs(axes) do
            if changed then break end
            if not self.SelectedAxis[a] then
                changed = true
            end
        end

        if not changed then return end
        self:RestartDragging(mouseRay, axes)
    end)

    --[[
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
    ]]

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
            self.ActiveMode = hit.HitMode or self.ActiveMode
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

    local lastRay = nil
    self.Timers["DetectHover"] = Timer:EveryFrame(function(timerID)
        if self.IsDragging or not self.Picker then return end
        local mouseRay = ScreenToWorldRay()
        if not mouseRay then return end
        if lastRay and mouseRay == lastRay then return end
        lastRay = mouseRay

        self:UpdatePicker()
        local hit = self.Picker:Hit(mouseRay)
        if hit and hit.Axis then
            self.HoveredAxis = hit.Axis
            self.ActiveMode = hit.HitMode or self.ActiveMode
        else
            self.HoveredAxis = nil
        end
        self:Visualize()
    end)

    self.Timers["Stick"] = Timer:EveryFrame(function(timerID)
        if self.IsDragging then return end
        
        local pos, rot = self:GetPivot()
        local allGuids = { }
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
function TransformGizmo:GetPivot()
    return Vec3.new({0,0,0}), Quat.new({0,0,0,1})
end

function TransformGizmo:DeleteItem()
    local guidlist = {}
    for _, guid in pairs(self.SavedGizmos) do
        table.insert(guidlist, guid)
    end
    self:StopListeners()
    NetChannel.Delete:SendToServer({ Guid = guidlist })
    self.SavedGizmos = {}
end

function TransformGizmo:CreateItem()
    -- hide original gizmo if exists
    local pos = self.PivotPosition or {0,0,0}
    if self.Mode == "Transform" then
        for _, mode in ipairs({ "Translate", "Rotate", "Scale" }) do
            self:CreateModeItem(mode)
        end
        return
    end

    if self.LastMode == "Transform" then
        for _, mode in ipairs({ "Translate", "Rotate", "Scale" }) do
            local originGuid = self.SavedGizmos[mode]
            self.Visualizer:HideGizmo(originGuid)
            NetChannel.SetAttributes:SendToServer({
                Guid = originGuid,
                Attributes = {
                    Visible = false,
                }
            })
        end
    end

    if self.SavedGizmos[self.Mode] and EntityExists(self.SavedGizmos[self.Mode]) then
        local originGuid = self.SavedGizmos[self.LastMode]
        local activeGuid = self.SavedGizmos[self.Mode]
        self.Visualizer:HideGizmo(originGuid)

        NetChannel.SetAttributes:SendToServer({
            Guid = activeGuid,
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
        local orginGuid = self.SavedGizmos[self.LastMode]
        local newGuid = response.Guid
        self.Visualizer:HideGizmo(orginGuid)
        self.SavedGizmos[self.Mode] = newGuid
        
        WaitUntil(function()
            return VisualHelpers.GetEntityVisual(newGuid) ~= nil
        end, function()
            NetChannel.SetAttributes:SendToServer({
                Guid = newGuid,
                Attributes = {
                    Visible = true,
                }
            })
            NetChannel.SetAttributes:SendToServer({
                Guid = orginGuid,
                Attributes = {
                    Visible = false,
                }
            })
        end)
    end)
end

function TransformGizmo:CreateModeItem(mode)
    if self.SavedGizmos[mode] and EntityExists(self.SavedGizmos[mode]) then
        NetChannel.SetAttributes:SendToServer({
            Guid = self.SavedGizmos[mode],
            Attributes = {
                Visible = true,
            }
        })
        return
    elseif self.SavedGizmos[mode] then
        -- make sure it's dead
        NetChannel.Delete:SendToServer({ Guid = self.SavedGizmos[mode] })
        self.SavedGizmos[mode] = nil
    end

    NetChannel.ManageGizmo:RequestToServer({
        GizmoType = mode,
        Position = self.PivotPosition or {0,0,0}
    }, function(response)
        self.SavedGizmos[mode] = response.Guid
        
        WaitUntil(function()
            return VisualHelpers.GetEntityVisual(self.SavedGizmos[mode]) ~= nil
        end, function()
            NetChannel.SetAttributes:SendToServer({
                Guid = self.SavedGizmos[mode],
                Attributes = {
                    Visible = true,
                }
            })
        end)
    end)
end

function TransformGizmo:StepMode()
    local modes = {"Translate", "Rotate", "Scale", "Transform"}
    local currentIndex = 1
    for i, mode in ipairs(modes) do
        if mode == self.Mode then
            currentIndex = i
            break
        end
    end
    local nextIndex = currentIndex % #modes + 1
    self:SetMode(modes[nextIndex])
end

function TransformGizmo:SetMode(mode)
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

        self.LastMode = self.Mode
        self.Mode = mode
        if mode ~= "Transform" then
            self.ActiveMode = mode
        end
        self:CreateItem()
        if ifRestart then
            self:RestartDragging()
        end
    end
end

--#region math

local lastDraw = 0

--- @param ray Ray
function TransformGizmo:GetHit(ray)
    local cnt = CountMap(self.SelectedAxis or {})
    if cnt == 0 then
        Debug("Gizm:GetHit: No Axis ")
        return Hit.new(self.Picker.Position, nil, 0, nil)
    end

    local hit = nil
    local pickerAxes = self.Picker:GetAxes()
    local axis = nil
    if self.ActiveMode == "Rotate" then
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

--- Ext.Math.Angle doesn't return signed angles
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
--- @return Vec3|number|QuatInfo|nil
function TransformGizmo:GetDelta(ray)
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
    if self.ActiveMode == "Translate" then
        delta = hit.Position - startHit.Position
    elseif self.ActiveMode == "Rotate" then
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
    elseif self.ActiveMode == "Scale" then
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

function TransformGizmo:SetupDragging()
    self._accuDelta = nil
    self.RotatePointer = self.RotatePointer or {}
    local pickerPos = Vec3.new(self.Picker.Position)
    local pickerRot = Quat.new(self.Picker.Rotation)
    if self.ActiveMode == "Rotate" then
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

        delta = self:LerpDelta(delta) --[[@as Vec3|number|QuatInfo ]]
        if not delta then return end -- may return nil to skip this frame

        if self.ActiveMode == "Rotate" then
            delta = delta --[[@as QuatInfo ]]
            self:VisualizeRotatePointer(delta.Angle, delta.Axis)
            self:OnDragRotate(delta)
        elseif self.ActiveMode == "Translate" then
            delta = delta --[[@as Vec3 ]]
            self:OnDragTranslate(delta)
            NetChannel.SetTransform:SendToServer({
                Guid = self.SavedGizmos.Translate,
                Transforms = {
                    [self.SavedGizmos.Translate] = {
                        Translate = pickerPos + delta,
                        RotationQuat = pickerRot,
                    }
                }
            })
        elseif self.ActiveMode == "Scale" then
            delta = delta --[[@as Vec3 ]]
            self.Visualizer.ScaleMultiplier = delta
            self:OnDragScale(delta)
        end

        self:Visualize()
    end)
end

--- @param delta Vec3|number|QuatInfo
--- @return Vec3|number|QuatInfo
function TransformGizmo:StepDelta(delta)
    if self.ActiveMode == "Translate" then
        delta = delta * self.Step
    elseif self.ActiveMode == "Rotate" then
        delta = { Angle = delta.Angle * self.Step, Axis = delta.Axis }
    elseif self.ActiveMode == "Scale" then
        local scaleVec = Vec3.new { 1, 1, 1 }
        delta = scaleVec + (delta - scaleVec) * self.Step
    end
    return delta
end

local lerpFactor = 0.1
local slowDownhandlers = {
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

--- @param delta Vec3|number|QuatInfo
--- @return Vec3|number|QuatInfo|nil
function TransformGizmo:LerpDelta(delta)
    local handler = slowDownhandlers[self.ActiveMode]
    if handler then
        return handler(self, delta)
    end
    return delta
end

function TransformGizmo:RegetStartHit()
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

function TransformGizmo:StopDragging()
    self:StopWithoutCallbacks()
    self:OnDragEnd()
    self.IsDragging = false
end

function TransformGizmo:StopWithoutCallbacks()
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

function TransformGizmo:OnDragStart() end

function TransformGizmo:OnDragTranslate(delta) end

function TransformGizmo:OnDragRotate(delta) end

function TransformGizmo:OnDragScale(delta) end

function TransformGizmo:OnDragEnd(isCancelled) end

function TransformGizmo:DragVisualize() end

function TransformGizmo:StopListeners()
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

function TransformGizmo:Visualize(guid)
    guid = guid or self.SavedGizmos[self.ActiveMode]
    if not EntityExists(guid) then return end
    local pos = {CGetPosition(guid)}
    if #pos == 3 then
        self.Visualizer:UpdateScale(pos)
    end
    
    local selectedAxis = DeepCopy(self.SelectedAxis)
    if CountMap(selectedAxis) > 2 and self.ActiveMode == "Rotate" then
        --- treat as single-axis rotation on closest axis
        selectedAxis = {}
    end

    if self.SelectedAxis then
        for axis, _ in pairs(selectedAxis or {}) do
            self.Visualizer:HighLightGizmoAxis(axis, guid)
        end
        for _, axis in pairs({ "X", "Y", "Z" }) do
            if not (selectedAxis and selectedAxis[axis]) then
                if self.ActiveMode == "Translate" then
                    self.Visualizer:ResetGizmoAxis(axis, guid)
                else
                    self.Visualizer:HideGizmoAxis(axis, guid)
                end
            end
        end

        for _, other in pairs(self.SavedGizmos) do
            if other ~= guid then
                self.Visualizer:HideGizmo(other)
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

    for mode, other in pairs(self.SavedGizmos) do
        if mode ~= self.ActiveMode then
            self.Visualizer:ResetGizmo(other)
        end
    end
end

function TransformGizmo:VisualizeRotatePointer(angle, axis)
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

function TransformGizmo:Hide()
    for _, guid in pairs(self.SavedGizmos) do
        NetChannel.SetAttributes:SendToServer({
            Guid = guid,
            Attributes = {
                Visible = false,
            }
        })
        self.Visualizer:HideGizmo(guid)
    end
end

function TransformGizmo:Disable()
    if self.IsDragging then
        self:EmptyDrag()
        self:StopDragging()
    end

    self:StopListeners()
    self:Hide()
end

function TransformGizmo:Enable()
    self:CreateItem()
    self:SetupListeners()
end
