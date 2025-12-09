--- @class TransformEditor
--- @field Gizmo TransformGizmo|nil
--- @field Cursor GUIDSTRING|nil
--- @field Target RB_MovableProxy[]|nil
--- @field Subscriptions table<string, RBSubscription>
--- @field Debug boolean
--- @field Space TransformEditorSpace
--- @field PivotMode TransformEditorPivotMode
--- @field Disabled boolean
--- @field IsDragging boolean
--- @field SelectionChangedNotif Notification|nil
--- @field PointVisualizations string[]|nil
--- @field LineVisualizations (string[])[]|nil
--- @field registered boolean
--- @field SetupGizmo fun(self: TransformEditor)
--- @field RegisterEvents fun(self: TransformEditor)
--- @field GetPivotRotation fun(self: TransformEditor): Quat
--- @field HideAndDisableGizmo fun(self: TransformEditor)
--- @field ShowAndEnableGizmo fun(self: TransformEditor)
--- @field Select fun(self: TransformEditor, selection: RB_MovableProxy[], notRecordHistory:boolean|nil):boolean|nil -- returns true if selection changed
--- @field AddTarget fun(self: TransformEditor, proxy: RB_MovableProxy)
--- @field Clear fun(self: TransformEditor)
--- @field SetMode fun(self: TransformEditor, mode: TransformEditorMode)
--- @field SetActiveMode fun(self: TransformEditor, mode: TransformEditorMode)
--- @field InitGizmo fun(self: TransformEditor)
--- @field UpdateGizmo fun(self: TransformEditor)
--- @field new fun(): TransformEditor
TransformEditor = _Class("TransformEditor")

local TRANSFORMEDITOR_MAX_SELECTION_SIZE = 100

function TransformEditor:__init()
    self.Target = nil
    self.Gizmo = TransformGizmo.new()
    self.Cursor = nil
    self.Subscriptions = {}
    self.Space = "World"
    self.PivotMode = "Median"
    self.Disabled = false
end

local function chekcIfSameSelection(selectionA, selectionB)
    if not selectionA and not selectionB then return true end
    if (not selectionA and selectionB) or (selectionA and not selectionB) then return false end
    if #selectionA ~= #selectionB then return false end

    local mapA = {}
    for _, v in pairs(selectionA) do
        mapA[v] = true
    end

    for _, v in pairs(selectionB) do
        if not mapA[v] then
            return false
        end
    end

    return true
end

local function simpleUnique(t)
    local map = {}
    local result = {}
    for _, v in pairs(t) do
        if not map[v] then
            map[v] = true
            table.insert(result, v)
        end
    end
    return result
end

local commonOriention = {
    World = true,
    View = true,
    Cursor = true,
}

local individualOriention = {
    Local = true,
    Parent = true,
}

local individualPivotMode = {
    Individual = true,
}


--- @param selection RB_MovableProxy[]
function TransformEditor:Select(selection, notRecordHistory)
    local oriSelection = self.Target

    if not notRecordHistory then
        HistoryManager:PushCommand({
            Undo = function()
                self:Select(oriSelection or {}, true)
            end,
            Redo = function()
                self:Select(selection or {}, true)
            end,
            Description = "Select Entities"
        })
    end

    if self.IsDragging then return end
    if not selection or #selection == 0 then
        self.Target = nil
        self:Clear()
        return
    end

    if chekcIfSameSelection(selection, oriSelection) then return end
    local tempTarget = simpleUnique(selection)

    local maxSize = TRANSFORMEDITOR_MAX_SELECTION_SIZE
    local overflowFlag = false
    if #tempTarget > maxSize then
        overflowFlag = true
        Warning("TransformEditor: Selection size exceeds maximum of " ..
            tostring(maxSize) .. ". Truncating selection.")
        local newSelection = {}
        for i = 1, maxSize do
            table.insert(newSelection, tempTarget[i])
        end
        tempTarget = newSelection
    end
    self.Target = tempTarget

    self:HandleGizmo()
    self:RegisterEvents()
    self:PopupNotify(overflowFlag)

    return true
end

function TransformEditor:StartDragging()
    if self.Gizmo then
        self.Gizmo:StartDragging()
    end
end

function TransformEditor:AddTarget(proxy)
    if not proxy then return end
    local oriSelection = self.Target
    local newSelection = {}
    for _, v in pairs(oriSelection or {}) do
        if v == proxy then
            return
        end
    end
    for _, v in pairs(oriSelection or {}) do
        table.insert(newSelection, v)
    end
    table.insert(newSelection, proxy)
    simpleUnique(newSelection)
    self:Select(newSelection)
end

function TransformEditor:PopupNotify(exceed)
    local notif = self.SelectionChangedNotif or Notification.new("Editor Selection Changed")
    self.SelectionChangedNotif = notif
    notif.Pivot = { 0.8, 0.1 }
    notif.ClickToDismiss = true
    notif.AnimDirection = "Horizontal"
    notif.ChangeDirectionWhenFadeOut = true
    notif:Show("Selection Changed", function(panel)
        for i, proxy in pairs(self.Target or {}) do
            proxy:Render(panel)
            if i > 5 then
                local moreLabel = panel:AddText("... and " .. tostring(#self.Target - 5) .. " more")
                moreLabel:SetColor("Text", { 1, 1, 1, 0.8 })
                break
            end
        end
        if exceed then
            panel:AddText("Selection size exceeded maximum limit.\n Truncated to " ..
                tostring(TRANSFORMEDITOR_MAX_SELECTION_SIZE) .. " entities."):SetColor("Text", { 1, 0, 0, 1 })
        end
    end)
end

function TransformEditor:HandleGizmo()
    if not self.Target or #self.Target == 0 then
        self:Clear()
        return
    end
    if not self.Gizmo then
        self.Gizmo = TransformGizmo.new()
    end

    self.Gizmo.GetPivot = function(gizmo)
        if not self.Target or #self.Target == 0 then
            return Vec3.new(0, 0, 0), Quat.Identity()
        end

        local sumPos = Vec3.new(0, 0, 0)
        local pivotPos = nil
        if self.PivotMode == "Cursor" then
            if self.Cursor and EntityHelpers.EntityExists(self.Cursor) then
                local pos = { RBGetPosition(self.Cursor) }
                pivotPos = Vec3.new(pos)
            else
                pivotPos = Vec3.new(RBGetPosition(RBGetHostCharacter()))
            end
        elseif self.PivotMode == "Active" then
            local latestProxy = self.Target[#self.Target]
            while not latestProxy:IsValid() do
                table.remove(self.Target, #self.Target)
                if #self.Target == 0 then
                    Debug("TransformEditor: GetPivot no valid target selected")
                    return Vec3.new(GetHostPosition()), Quat.Identity()
                end
                latestProxy = self.Target[#self.Target]
            end
            pivotPos = latestProxy:GetWorldTranslate() or Vec3.new(GetHostPosition())
        else
            local validCount = 0
            for _, proxy in self:SafeTraverseTarget() do
                local pos = proxy:GetWorldTranslate() or Vec3.new(0, 0, 0)
                sumPos = sumPos + pos
                validCount = validCount + 1
            end

            if validCount == 0 then
                Debug("TransformEditor: GetPivot no valid target selected")
                return Vec3.new(0, 0, 0), Quat.Identity()
            end
            pivotPos = sumPos / validCount
        end
        local rot = self:GetPivotRotation() or Quat.Identity()

        return pivotPos, rot
    end

    self.Gizmo:Enable()
end

function TransformEditor:SetSpace(space)
    if self.IsDragging then return end
    if Enums.TransformEditorSpace[space] then
        self.Space = space
    else
        Warning("TransformEditor:SetSpace: Invalid space '" .. tostring(space))
    end
end

function TransformEditor:SetPivotMode(mode)
    if self.IsDragging then return end
    if Enums.TransformEditorPivotMode[mode] then
        self.PivotMode = mode
    else
        Warning("TransformEditor:SetPivotMode: Invalid mode '" .. tostring(mode))
    end
end

function TransformEditor:Clear()
    self.Target = nil
    self.Gizmo:Disable()
end

function TransformEditor:SetMode(mode)
    if not Enums.TransformEditorMode[mode] then return end
    if mode and mode ~= self.Gizmo.ActiveMode then
        self.Gizmo:SetActiveMode(mode)
        if not self.IsDragging then
            self.Gizmo:StartDragging()
        end
        --Debug("TransformEditor Mode: "..tostring(self.Gizmo.Mode))
    elseif mode and mode == self.Gizmo.ActiveMode and not self.IsDragging then
        self.Gizmo:StartDragging()
    end
end

function TransformEditor:CycleMode()
    self.Gizmo:CycleMode()
end

function TransformEditor:GetPivotRotation()
    local space = self.Space or "World"
    local latestProxy = self.Target[#self.Target]
    while not latestProxy:IsValid() do
        table.remove(self.Target, #self.Target)
        if #self.Target == 0 then
            return Quat.Identity()
        end
        latestProxy = self.Target[#self.Target]
    end
    local rot = Quat.Identity()
    if not latestProxy then
        return rot
    end
    if space == "Local" then
        rot = latestProxy:GetWorldRotation()
    elseif space == "Parent" then
        local parent = latestProxy:GetParent()
        if parent then
            rot = parent:GetWorldRotation()
        else
            rot = Quat.Identity()
        end
    elseif space == "View" then
        rot = { CameraHelpers.GetCameraRotation() }
    elseif space == "Cursor" then
        if self.Cursor and EntityHelpers.EntityExists(self.Cursor) then
            rot = { RBGetRotation(self.Cursor) }
        else
            rot = Quat.Identity()
        end
    else
        rot = Quat.Identity()
    end
    return Quat.new(rot)
end

function TransformEditor:RegisterEvents()
    if self.registered then return end
    self.registered = true

    self:SetupGizmo()
end

--- @param gizmo TransformGizmo
--- @param pointTransform Transform
--- @param index integer
--- @
function TransformEditor:MakePointVisualization(gizmo, pointTransform, index)
    if self.PointVisualizations and self.PointVisualizations[index] then
        local pointGuid = self.PointVisualizations[index]

        NetChannel.SetTransform:RequestToServer({ Guid = pointGuid, Transforms = { [pointGuid] = pointTransform } },
            function()
                for _, axis in pairs({ "X", "Y", "Z" }) do
                    if gizmo.SelectedAxis and gizmo.SelectedAxis[axis] then
                        gizmo.Visualizer:HighLightGizmoAxis(axis, pointGuid)
                    else
                        gizmo.Visualizer:HideGizmoAxis(axis, pointGuid)
                    end
                end
            end)
        return
    end

    NetChannel.Visualize:RequestToServer({
        Type = "Point",
        Position = pointTransform.Translate,
        Rotation = pointTransform.RotationQuat,
        Duration = -1,
    }, function(response)
        local tryCnt = 0

        for _, viz in pairs(response or {}) do
            table.insert(self.PointVisualizations, viz)
        end

        RBUtils.WaitUntil(function()
            local allReady = true
            for _, viz in ipairs(response or {}) do
                if not VisualHelpers.GetEntityVisual(viz) then
                    allReady = false
                    break
                end
            end
            return allReady
        end, function()
            for _, viz in ipairs(response or {}) do
                for _, axis in pairs({ "X", "Y", "Z" }) do
                    if gizmo.SelectedAxis and gizmo.SelectedAxis[axis] then
                        gizmo.Visualizer:HighLightGizmoAxis(axis, viz)
                    else
                        gizmo.Visualizer:HideGizmoAxis(axis, viz)
                    end
                end
            end
        end)
    end)
end

--- @param gizmo TransformGizmo
--- @param ray Ray
--- @param color vec3
--- @param index integer
function TransformEditor:MakeAxisLineVisualization(gizmo, ray, color, index)
    local beamDirection = ray.Direction * -1
    local startPoint = ray:At(-30)
    local secondPoint = ray:At(30)

    if self.LineVisualizations[index] then
        local lineGuid = self.LineVisualizations[index][1]
        local line2Guid = self.LineVisualizations[index][2]
        gizmo.Visualizer:SetLineFxColor(lineGuid, color)
        gizmo.Visualizer:SetLineFxColor(line2Guid, color)
        local newLineTransform = {
            Translate = startPoint,
            RotationQuat = MathUtils.DirectionToQuat(beamDirection),
        }
        local newLine2Transform = {
            Translate = secondPoint,
            RotationQuat = MathUtils.DirectionToQuat(ray.Direction)
        }
        NetChannel.SetTransform:RequestToServer({ Guid = lineGuid, Transforms = { [lineGuid] = newLineTransform } },
            function(response)
                -- prevent flickering
                Timer:Ticks(5, function(timerID)
                    if not self.IsDragging then return end
                    gizmo.Visualizer:SetLineLength(lineGuid, 200)
                end)
            end)
        NetChannel.SetTransform:RequestToServer({ Guid = line2Guid, Transforms = { [line2Guid] = newLine2Transform } },
            function(response)
                Timer:Ticks(5, function(timerID)
                    if not self.IsDragging then return end
                    gizmo.Visualizer:SetLineLength(line2Guid, 200)
                end)
            end)
        return
    end

    self.LineVisualizations[index] = {}
    NetChannel.Visualize:RequestToServer({
        Type = "Line",
        Position = startPoint,
        EndPosition = ray:At(100),
        Width = gizmo.Visualizer.Scale[1] * 0.3,
        Duration = -1,
    }, function(response)
        local viz = response[1]
        RBUtils.WaitUntil(function()
            return VisualHelpers.GetEntityVisual(viz) ~= nil
        end, function()
            gizmo.Visualizer:SetLineFxColor(viz, color)
            gizmo.Visualizer:SetLineLength(viz, 200)
        end, 300)
        table.insert(self.LineVisualizations[index], viz)
    end)
    NetChannel.Visualize:RequestToServer({
        Type = "Line",
        Position = secondPoint,
        EndPosition = ray:At(-100),
        Width = gizmo.Visualizer.Scale[1] * 0.3,
        Duration = -1,
    }, function(response)
        local viz = response[1]
        RBUtils.WaitUntil(function()
            return VisualHelpers.GetEntityVisual(viz) ~= nil
        end, function()
            gizmo.Visualizer:SetLineFxColor(viz, color)
            gizmo.Visualizer:SetLineLength(viz, 200)
        end, 300)
        table.insert(self.LineVisualizations[index], viz)
    end)
end

function TransformEditor:SafeTraverseTarget()
    --[[for i=#self.Target or {}, 1, -1 do
        local proxy = self.Target[i]
        if not proxy:IsValid() then
            table.remove(self.Target, i)
        end
    end]]
    return pairs(self.Target or {})
end

function TransformEditor:SetupGizmo()
    if not self.Gizmo then
        self.Gizmo = TransformGizmo.new()
    end

    local GetRottt = function(gizmo)
        local _, rot = gizmo:GetPickerTransform()
        return rot
    end

    local picPos --[[@as Vec3?]]
    local picRot --[[@as Quat?]]
    local picRotInv = nil --[[@as Quat?]]
    local cachedStartTransform = {} --[[@type table<RB_MovableProxy, Transform>]]
    local cachedScaleAxes = {} --[[@as table<RB_MovableProxy, Vec3[]>]]

    self.Gizmo.OnDragStart = function(gizmo)
        self.IsDragging = true
        cachedStartTransform = {}
        cachedScaleAxes = {}
        for _, proxy in pairs(self.Target or {}) do
            local saved = proxy:SaveTransform()
            cachedStartTransform[proxy] = saved
        end
        picPos, picRot = gizmo:GetPickerTransform()
        picRotInv = picRot:Inverse()
    end

    self.Gizmo.DragVisualize = function(gizmo)
        self.PointVisualizations = self.PointVisualizations or {}
        self.LineVisualizations = self.LineVisualizations or {}

        for i = #self.LineVisualizations, 1, -1 do
            local guids = self.LineVisualizations[i]
            if not EntityHelpers.EntityExists(guids[1]) or not EntityHelpers.EntityExists(guids[2]) then
                NetChannel.Delete:RequestToServer({ Guid = guids }, function(response)
                    -- make sure it's dead
                end)
                table.remove(self.LineVisualizations, i)
            end
        end

        for i = #self.PointVisualizations, 1, -1 do
            local guid = self.PointVisualizations[i]
            if not EntityHelpers.EntityExists(guid) then
                NetChannel.Delete:RequestToServer({ Guid = guid }, function(response)
                    -- make sure it's dead
                end)
                table.remove(self.PointVisualizations, i)
            end
        end

        for _, v in pairs(self.LineVisualizations or {}) do
            gizmo.Visualizer:SetLineLength(v[1], 0)
            gizmo.Visualizer:SetLineLength(v[2], 0)
        end
        for _, v in pairs(self.PointVisualizations or {}) do
            gizmo.Visualizer:HideGizmo(v)
        end

        local selectedCnt = RBTableUtils.CountMap(gizmo.SelectedAxis)
        if gizmo.ActiveMode == "Rotate" and gizmo.SelectedAxis and selectedCnt > 1 then
            return
        end

        local pivotPos, pivotRot = gizmo:GetPickerTransform()

        local newPointTransform = {
            Translate = pivotPos,
            RotationQuat = pivotRot,
        }
        self:MakePointVisualization(gizmo, newPointTransform, 1)

        if selectedCnt > 2 then return end -- skip axis visualizations

        -- make axis visualizations
        -- only calculate one visualization for space modes that use a common rotation
        if commonOriention[self.Space] then
            local color = nil
            local cnt = 1
            for _, axis in pairs({ "X", "Y", "Z" }) do
                if not gizmo.SelectedAxis[axis] then goto continue end
                color = gizmo.Visualizer.AxisLineColor[axis] or { 0.9, 0.9, 0.9, 0.8 }

                if not pivotRot then return end
                local vector = GLOBAL_COORDINATE[axis]
                local ray = Ray.new(pivotPos, pivotRot:Rotate(vector))
                self:MakeAxisLineVisualization(gizmo, ray, color, cnt)
                cnt = cnt + 1
                ::continue::
            end
            return
        end

        local cnt = 1
        local offset = #self.Target or 0
        for _, axis in pairs({ "X", "Y", "Z" }) do
            if cnt > 2 then break end
            if not gizmo.SelectedAxis[axis] then goto continue end
            local color = nil
            color = gizmo.Visualizer.AxisLineColor[axis] or { 0.9, 0.9, 0.9, 0.8 }

            for targetCnt, proxy in pairs(self.Target or {}) do
                local transform = proxy:GetSavedTransform()
                local rot = GetRottt(gizmo)
                if self.Space == "Local" then
                    rot = Quat.new(transform.RotationQuat)
                elseif self.Space == "Parent" then
                    local parent = proxy:GetParent()
                    if parent and parent:IsValid() then
                        rot = Quat.new(parent:GetSavedTransform().RotationQuat)
                    else
                        rot = Quat.Identity()
                    end
                end
                if not rot then return end
                local vector = GLOBAL_COORDINATE[axis]
                local ray = Ray.new(transform.Translate, rot:Rotate(vector))
                self:MakeAxisLineVisualization(gizmo, ray, color, targetCnt + offset * (cnt - 1))
            end
            cnt = cnt + 1
            ::continue::
        end
    end

    self.Gizmo.OnDragTranslate = function(gizmo, delta)
        if self.Space == "Local" or self.Space == "Parent" then
            -- Convert delta from world space to local space
            if not picRotInv then
                Debug("TransformEditor: OnDragTranslate picRotInv is nil")
                return
            end
            delta = picRotInv:Rotate(delta)
        end

        for _, proxy in self:SafeTraverseTarget() do
            local startTransform = cachedStartTransform[proxy]
            local finalDelta = Vec3.new(delta)
            if self.Space == "Local" then
                finalDelta = Ext.Math.QuatRotate(startTransform.RotationQuat, delta)
            elseif self.Space == "Parent" then
                local parent = proxy:GetParent()
                if parent and parent:IsValid() then
                    local parentRot = parent:GetSavedTransform().RotationQuat
                    finalDelta = Ext.Math.QuatRotate(parentRot, delta)
                else
                    finalDelta = { 0, 0, 0 }
                end
            end
            local newPos = Ext.Math.Add(startTransform.Translate, finalDelta)

            proxy:SetWorldTranslate(newPos)
        end
    end

    self.Gizmo.OnDragScale = function(gizmo, delta)
        local deltaWorld1 = { delta[1] - 1, delta[2] - 1, delta[3] - 1 }
        local function calculateScale(axes, baseScale)
            local dx = Ext.Math.Dot(axes.X, deltaWorld1)
            local dy = Ext.Math.Dot(axes.Y, deltaWorld1)
            local dz = Ext.Math.Dot(axes.Z, deltaWorld1)

            return Vec3.new(
                baseScale[1] * (1 + dx),
                baseScale[2] * (1 + dy),
                baseScale[3] * (1 + dz)
            )
        end

        for _, proxy in self:SafeTraverseTarget() do
            local startTransform = cachedStartTransform[proxy]
            local baseScale = startTransform.Scale or { 1, 1, 1 }
            local newScale

            --- common orientation space can use gizmo axes directly
            if self.Space == "World" or self.Space == "View" or self.Space == "Cursor" then
                local axes = gizmo.Picker:GetAxes()
                newScale = calculateScale(axes, baseScale)

                --- individual orientation spaces need to calculate axes per entity
            elseif self.Space == "Parent" then
                local parent = proxy:GetParent()
                if parent and parent:IsValid() then
                    if not cachedScaleAxes[parent] then
                        local parentRot = parent:GetSavedTransform().RotationQuat
                        cachedScaleAxes[parent] = {
                            X = Ext.Math.QuatRotate(parentRot, GLOBAL_COORDINATE.X),
                            Y = Ext.Math.QuatRotate(parentRot, GLOBAL_COORDINATE.Y),
                            Z = Ext.Math.QuatRotate(parentRot, GLOBAL_COORDINATE.Z),
                        }
                    end
                    newScale = calculateScale(cachedScaleAxes[parent], baseScale)
                else
                    newScale = Vec3.new(baseScale[1] * delta[1],
                        baseScale[2] * delta[2],
                        baseScale[3] * delta[3])
                end
            else
                newScale = Vec3.new(baseScale[1] * delta[1],
                    baseScale[2] * delta[2],
                    baseScale[3] * delta[3])
            end

            if individualPivotMode[self.PivotMode] or individualOriention[self.Space] then
                proxy:SetWorldScale(newScale)
            elseif picPos then
                local newTransform = MathUtils.ScaleAroundPivot(picPos, startTransform, newScale)
                proxy:SetTransform(newTransform)
            else
                Warning("TransformEditor: OnDragScale picPos is nil")
            end
            ::continue::
        end
    end

    self.Gizmo.OnDragRotate = function(gizmo, delta)
        local deltaAngle = delta[4]
        local deltaAxis = Vec3.new(delta[1], delta[2], delta[3])

        if deltaAxis == Vec3.new(0, 0, 0) or deltaAngle == 0 then
            for _, proxy in pairs(self.Target or {}) do
                proxy:RestoreTransform()
            end
            return
        end

        if self.Space == "Local" or self.Space == "Parent" then
            -- Convert delta axis from world space to local space
            if not picRotInv then
                Debug("TransformEditor: OnDragRotate picRotInv is nil")
                return
            end
            deltaAxis = picRotInv:Rotate(deltaAxis)
        end

        if not (individualPivotMode[self.PivotMode] or individualOriention[self.Space]) then
            for _, proxy in self:SafeTraverseTarget() do
                local startTransform = cachedStartTransform[proxy]
                if not picPos then
                    Debug("TransformEditor: OnDragRotate picPos is nil")
                    return
                end
                local newTransform = MathUtils.RotateAroundPivot(picPos, startTransform, deltaAxis, deltaAngle)

                proxy:SetTransform(newTransform)
                ::continue::
            end
            return
        end

        for _, proxy in self:SafeTraverseTarget() do
            local startTransform = cachedStartTransform[proxy]
            local curRot = startTransform.RotationQuat or Quat.Identity()
            local newRot = nil
            local axis = deltaAxis or Vec3.new { 0, 0, 0 }
            local angle = deltaAngle or 0
            if self.Space == "Local" then
                axis = Ext.Math.QuatRotate(curRot, axis)
            elseif self.Space == "Parent" then
                local parent = proxy:GetParent()
                if parent and parent:IsValid() then
                    local parentRot = parent:GetSavedTransform().RotationQuat
                    axis = Ext.Math.QuatRotate(parentRot, axis)
                else
                    axis = Vec3.new { 0, 0, 0 }
                end
            end

            local deltaQuat = Quat.Identity()
            if Ext.Math.Length(axis) == 0 or angle == 0 then
                deltaQuat = Quat.Identity()
            else
                deltaQuat = Ext.Math.QuatRotateAxisAngle(Quat.Identity(), axis, angle)
            end

            newRot = Ext.Math.QuatMul(deltaQuat, curRot)

            proxy:SetWorldRotation(newRot)
            ::continue::
        end
    end

    self.Gizmo.OnDragEnd = function(gizmo, isCancelled)
        for _, v in pairs(self.LineVisualizations or {}) do
            gizmo.Visualizer:SetLineLength(v[1], 0)
            gizmo.Visualizer:SetLineLength(v[2], 0)
        end
        for _, v in pairs(self.PointVisualizations or {}) do
            gizmo.Visualizer:HideGizmo(v)
        end
        if isCancelled then
            for _, proxy in self:SafeTraverseTarget() do
                proxy:RestoreTransform()
            end
            self.IsDragging = false
            return
        end

        local redoTransforms = {}
        local undoTransforms = {}
        for _, proxy in pairs(self.Target or {}) do
            undoTransforms[proxy] = proxy:GetSavedTransform()
        end
        local changed = {}
        for _, proxy in pairs(self.Target or {}) do
            local save = proxy:GetTransform()
            if EntityHelpers.EqualTransforms(save, undoTransforms[proxy]) then
                undoTransforms[proxy] = nil
            else
                redoTransforms[proxy] = save
                table.insert(changed, proxy)
            end
        end

        if next(redoTransforms) then
            HistoryManager:PushCommand({
                Undo = function()
                    for _, proxy in pairs(changed) do
                        if not proxy:IsValid() then
                            goto continue
                        end
                        local startTransform = undoTransforms[proxy]
                        proxy:SetTransform(startTransform)
                        ::continue::
                    end
                end,
                Redo = function()
                    for _, proxy in pairs(changed) do
                        if not proxy:IsValid() then
                            goto continue
                        end
                        local endTransform = redoTransforms[proxy]
                        proxy:SetTransform(endTransform)
                        ::continue::
                    end
                end,
                Description = "Set Transform"
            })
        end

        self.IsDragging = false
    end
end

function TransformEditor:HideAndDisableGizmo()
    if self.Gizmo then
        self.Gizmo:Disable()
    end
    self.Disabled = true
end

function TransformEditor:ShowAndEnableGizmo()
    if self.Gizmo then
        self.Gizmo:Enable()
    end
    self.Disabled = false
end

RB_GLOBALS.TransformEditor = TransformEditor.new()
