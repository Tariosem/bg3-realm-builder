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
--- @field InitGizmo fun(self: TransformEditor)
--- @field UpdateGizmo fun(self: TransformEditor)
--- @field new fun(): TransformEditor
TransformEditor = _Class("TransformEditor")

function TransformEditor:__init()
    self.Target = nil
    self.Gizmo = TransformGizmo.new(self)
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
    for _,v in pairs(selectionA) do
        mapA[v] = true
    end

    for _,v in pairs(selectionB) do
        if not mapA[v] then
            return false
        end
    end

    return true
end

local function simpleUnique(t)
    local map = {}
    local result = {}
    for _,v in pairs(t) do
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

local maxSize = 100

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
            end
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

    if #tempTarget > maxSize then
        Warning("TransformEditor: Selection size exceeds maximum of "..tostring(maxSize)..". Truncating selection.")
        local newSelection = {}
        for i=1, maxSize do
            table.insert(newSelection, tempTarget[i])
        end
        tempTarget = newSelection
    end
    self.Target = tempTarget

    self:HandleGizmo()
    self:RegisterEvents()
    self:PopupNotify()

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
    for _,v in pairs(oriSelection or {}) do
        if v == proxy then
            return
        end
    end
    for _,v in pairs(oriSelection or {}) do
        table.insert(newSelection, v)
    end
    table.insert(newSelection, proxy)
    self:Select(newSelection)
end

function TransformEditor:PopupNotify()
    local notif = self.SelectionChangedNotif or Notification.new("Editor Selection Changed")
    self.SelectionChangedNotif = notif
    notif.Pivot = { 0.8, 0.1 }
    notif.ClickToDismiss = true
    notif.AnimDirection = "Horizontal"
    notif.ChangeDirectionWhenFadeOut = true
    notif:Show("Selection Changed", function (panel)
        for i, proxy in pairs(self.Target or {}) do
            proxy:Render(panel)
            if i > 5 then
                local moreLabel = panel:AddText("... and "..tostring(#self.Target - 5).." more")
                moreLabel:SetColor("Text", {1,1,1,0.8})
                break
            end
        end
    end)
end

function TransformEditor:HandleGizmo()
    if not self.Target or #self.Target == 0 then
        self:Clear()
        return
    end
    if not self.Gizmo then
        self.Gizmo = TransformGizmo.new(self)

    end

    self.Gizmo.GetPivot = function(gizmo)
        if not self.Target or #self.Target == 0 then
            return Vec3.new(0,0,0), Quat.Identity()
        end

        local sumPos = Vec3.new(0,0,0)
        local pivotPos = nil
        if self.PivotMode == "Cursor" then
            if self.Cursor and EntityExists(self.Cursor) then
                local pos = {CGetPosition(self.Cursor)}
                pivotPos = Vec3.new(pos)
            else
                pivotPos = Vec3.new(CGetPosition(CGetHostCharacter()))
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
            for _,proxy in pairs(self.Target or {}) do
                if proxy:IsValid() then
                    local pos = proxy:GetWorldTranslate() or Vec3.new(0,0,0)
                    sumPos = sumPos + pos
                    validCount = validCount + 1
                end
            end
        
            if validCount == 0 then
                Debug("TransformEditor: GetPivot no valid target selected")
                return Vec3.new(0,0,0), Quat.Identity()
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
        Warning("TransformEditor:SetSpace: Invalid space '"..tostring(space))
    end
end

function TransformEditor:SetPivotMode(mode)
    if self.IsDragging then return end
    if Enums.TransformEditorPivotMode[mode] then
        self.PivotMode = mode
    else
        Warning("TransformEditor:SetPivotMode: Invalid mode '"..tostring(mode))
    end
end

function TransformEditor:Clear()
    self.Target = nil
    self.Gizmo:Disable()
end


function TransformEditor:SetMode(mode)
    if not Enums.TransformEditorMode[mode] then return end
    if mode and mode ~= self.Gizmo.ActiveMode then
        self.Gizmo:SetMode(mode)
        --Debug("TransformEditor Mode: "..tostring(self.Gizmo.Mode))
    elseif mode and mode == self.Gizmo.ActiveMode and not self.IsDragging then
        self.Gizmo:StartDragging()
    end
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
        rot = {GetCameraRotation()}
    elseif space == "Cursor" then
        if self.Cursor and EntityExists(self.Cursor) then
            rot = {CGetRotation(self.Cursor)}
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
function TransformEditor:MakePointVisualization(gizmo, pointTransform, index)
    if self.PointVisualizations and self.PointVisualizations[index] then
        local pointGuid = self.PointVisualizations[index]

        NetChannel.SetTransform:RequestToServer({ Guid = pointGuid, Transforms = {[pointGuid] = pointTransform} }, function()
            for _,axis in pairs({"X","Y","Z"}) do
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
    }, function (response)
        local tryCnt = 0

        for _,viz in pairs(response or {}) do
            table.insert(self.PointVisualizations, viz)
        end

        WaitUntil(function ()
            local allReady = true
            for _,viz in ipairs(response or {}) do
                if not VisualHelpers.GetEntityVisual(viz) then
                    allReady = false
                    break
                end
            end
            return allReady
        end, function ()
            for _,viz in ipairs(response or {}) do
                for _,axis in pairs({"X","Y","Z"}) do
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
            RotationQuat = DirectionToQuat(beamDirection),
        }
        local newLine2Transform = {
            Translate = secondPoint,
            RotationQuat = DirectionToQuat(ray.Direction)
        }
        NetChannel.SetTransform:RequestToServer({ Guid = lineGuid, Transforms = {[lineGuid] = newLineTransform} }, function (response)
            -- prevent flickering
            Timer:Ticks(5, function (timerID)
                if not self.IsDragging then return end
                gizmo.Visualizer:SetLineLength(lineGuid, 200)
            end)
        end)
        NetChannel.SetTransform:RequestToServer({ Guid = line2Guid, Transforms = {[line2Guid] = newLine2Transform }}, function (response)
            Timer:Ticks(5, function (timerID)
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
    }, function (response)
        local viz = response[1]
        WaitUntil(function ()
            return VisualHelpers.GetEntityVisual(viz) ~= nil
        end, function ()
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
    }, function (response)
        local viz = response[1]
        WaitUntil(function ()
            return VisualHelpers.GetEntityVisual(viz) ~= nil
        end, function ()
            gizmo.Visualizer:SetLineFxColor(viz, color)
            gizmo.Visualizer:SetLineLength(viz, 200)
        end, 300)
        table.insert(self.LineVisualizations[index], viz)
    end)
end



function TransformEditor:SetupGizmo()
    if not self.Gizmo then
        self.Gizmo = TransformGizmo.new(self)
    end

    local GetRottt = function(gizmo)
        local _,rot = gizmo:GetPickerTransform()
        return rot
    end

    self.Gizmo.OnDragStart = function(gizmo)
        self.IsDragging = true
        for _,proxy in pairs(self.Target or {}) do
            local saved = proxy:SaveTransform()
        end
    end

    self.Gizmo.DragVisualize = function (gizmo)
        self.PointVisualizations = self.PointVisualizations or {}
        self.LineVisualizations = self.LineVisualizations or {}

        for i=#self.LineVisualizations, 1, -1 do
            local guids = self.LineVisualizations[i]
            if not EntityExists(guids[1]) or not EntityExists(guids[2]) then
                NetChannel.Delete:RequestToServer({ Guid = guids }, function (response)
                    -- make sure it's dead
                end)
                table.remove(self.LineVisualizations, i)
            end
        end

        for i=#self.PointVisualizations, 1, -1 do
            local guid = self.PointVisualizations[i]
            if not EntityExists(guid) then
                NetChannel.Delete:RequestToServer({ Guid = guid }, function (response)
                    -- make sure it's dead
                end)
                table.remove(self.PointVisualizations, i)
            end
        end

        for _,v in pairs(self.LineVisualizations or {}) do
            gizmo.Visualizer:SetLineLength(v[1], 0)
            gizmo.Visualizer:SetLineLength(v[2], 0)
        end
        for _,v in pairs(self.PointVisualizations or {}) do
            gizmo.Visualizer:HideGizmo(v)
        end

        local selectedCnt = CountMap(gizmo.SelectedAxis)
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
            for _, axis in pairs({"X", "Y", "Z"}) do
                if not gizmo.SelectedAxis[axis] then goto continue end
                color = gizmo.Visualizer.AxisLineColor[axis] or {0.9, 0.9, 0.9, 0.8}

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
        for _, axis in pairs({"X", "Y", "Z"}) do
            if cnt > 2 then break end
            if not gizmo.SelectedAxis[axis] then goto continue end
            local color = nil
            color = gizmo.Visualizer.AxisLineColor[axis] or {0.9, 0.9, 0.9, 0.8}

            for targetCnt,proxy in pairs(self.Target or {}) do
                local transform = proxy:GetSavedTransform()
                local rot = GetRottt(gizmo)
                if self.Space == "Local" then
                    rot = Quat.new(transform.RotationQuat)
                elseif self.Space == "Parent" then
                    local parent = proxy:GetParent()
                    if parent and EntityExists(parent) then
                        rot = Quat.new(parent:GetSavedTransform().RotationQuat)
                    else
                        rot = Quat.Identity()
                    end
                end
                if not rot then return end
                local vector = GLOBAL_COORDINATE[axis]
                local ray = Ray.new(transform.Translate, rot:Rotate(vector))
                self:MakeAxisLineVisualization(gizmo, ray, color, targetCnt + offset * (cnt -1))
            end
            cnt = cnt + 1
            ::continue::
        end
    end

    self.Gizmo.OnDragTranslate = function(gizmo, delta)
        if self.Space == "Local" or self.Space == "Parent" then
            -- Convert delta from world space to local space
            local rot = GetRottt(gizmo)
            delta = rot:Inverse():Rotate(delta)
        end
        
        for _,proxy in pairs(self.Target or {}) do
            local startTransform = proxy:GetSavedTransform()
            local finalDelta = Vec3.new(delta)
            if self.Space == "Local" then
                finalDelta = Quat.new(startTransform.RotationQuat):Rotate(delta)
            elseif self.Space == "Parent" then
                local parent = proxy:GetParent()
                if parent and EntityExists(parent) then
                    local parentRot = parent:GetSavedTransform().RotationQuat
                    finalDelta = parentRot:Rotate(delta)
                else
                    finalDelta = {0,0,0}
                end
            end
            local newPos = Vec3.new(startTransform.Translate) + finalDelta

            proxy:SetWorldTranslate(newPos)
        end
    end

    self.Gizmo.OnDragScale = function(gizmo, delta)
        local cameraMatrix = nil
        if self.Space == "View" then
            cameraMatrix = Matrix.new(Ext.Math.QuatToMat4({GetCameraRotation()}))
        end

        for _, proxy in pairs(self.Target or {}) do
            local startTransform = proxy:GetSavedTransform()
            local baseScale = startTransform.Scale or {1,1,1}

            local deltaWorld = Vec3.new(delta)

            local newScale = nil
            if self.Space == "World" or self.Space == "View" or self.Space == "Parent" then
                -- Convert world-space delta scaling into local-space scale factors
                local R = Matrix.new(Ext.Math.QuatToMat4(startTransform.RotationQuat))
                if self.Space == "View" then
                    R = cameraMatrix * R
                elseif self.Space == "Parent" then
                    local parent = proxy:GetParent()
                    if parent and EntityExists(parent) then
                        local parentRot = parent:GetSavedTransform().RotationQuat
                        local parentMat = Matrix.new(Ext.Math.QuatToMat4(parentRot))
                        
                        R = parentMat:Inverse() * R
                    else
                        R = Matrix.Identity(4)
                    end
                end
                local S_world = Ext.Math.BuildScale(deltaWorld)

                local S_local = R:Transpose() * S_world * R
                

                local sx = S_local[1]
                local sy = S_local[6]
                local sz = S_local[11]

                newScale = Vec3.new(
                    baseScale[1] * sx,
                    baseScale[2] * sy,
                    baseScale[3] * sz
                )
            else
                newScale = Vec3.new(baseScale) * deltaWorld
            end

            if individualPivotMode[self.PivotMode] or individualOriention[self.Space] then
                proxy:SetWorldScale(newScale)
            else
                local pivotPos, _ = gizmo:GetPickerTransform()
                local newTransform = ScaleAroundPivot(pivotPos, startTransform, newScale)
                proxy:SetTransform(newTransform)
            end
        end
    end

    self.Gizmo.OnDragRotate = function(gizmo, delta)
        local deltaAngle = delta.Angle or 0
        local deltaAxis = Vec3.new(delta.Axis or {0,0,0})

        if deltaAxis == Vec3.new(0,0,0) or deltaAngle == 0 then
            for _,proxy in pairs(self.Target or {}) do
                proxy:RestoreTransform()
            end
            return
        end

        if self.Space == "Local" or self.Space == "Parent" then
            -- Convert delta axis from world space to local space
            local rot = GetRottt(gizmo)
            deltaAxis = rot:Inverse():Rotate(deltaAxis)
        end

        if not (individualPivotMode[self.PivotMode] or individualOriention[self.Space]) then
            local pivotPos, _ = gizmo:GetPickerTransform()
            for _, proxy in pairs(self.Target or {}) do
                local startTransform = proxy:GetSavedTransform()
                local newTransform = RotateAroundPivot(pivotPos, startTransform, deltaAxis, deltaAngle)

                proxy:SetTransform(newTransform)
            end
            return
        end

        for _, proxy in pairs(self.Target or {}) do
            local startTransform = proxy:GetSavedTransform()
            local curRot = Quat.new(startTransform.RotationQuat) or Quat.Identity()
            local newRot = nil
            local axis = deltaAxis or Vec3.new{0,0,0}
            local angle = deltaAngle or 0
            if self.Space == "Local" then
                axis = curRot:Rotate(axis) --[[@as Vec3]]
            elseif self.Space == "Parent" then
                local parent = proxy:GetParent()
                if parent and EntityExists(parent) then
                    local parentRot = parent:GetSavedTransform().RotationQuat
                    axis = parentRot:Rotate(axis)
                else
                    axis = Vec3.new{0,0,0}
                end
            end

            local deltaQuat = Quat.Identity()
            if axis:Length() == 0 or angle == 0 then
                deltaQuat = Quat.Identity()
            else
                deltaQuat = Ext.Math.QuatRotateAxisAngle(Quat.Identity(), axis, angle)
            end
            
            newRot = Quat.new(Ext.Math.QuatMul(deltaQuat, curRot))

            proxy:SetWorldRotation(newRot)
        end
    end

    self.Gizmo.OnDragEnd = function(gizmo, isCancelled)
        for _,v in pairs(self.LineVisualizations or {}) do
            gizmo.Visualizer:SetLineLength(v[1], 0)
            gizmo.Visualizer:SetLineLength(v[2], 0)
        end
        for _,v in pairs(self.PointVisualizations or {}) do
            gizmo.Visualizer:HideGizmo(v)
        end
        if isCancelled then 
            for _,proxy in pairs(self.Target or {}) do
                proxy:RestoreTransform()
            end
            self.IsDragging = false
            return 
        end

        local redoTransforms = {}
        local undoTransforms = {}
        for _,proxy in pairs(self.Target or {}) do
            undoTransforms[proxy] = proxy:GetSavedTransform()
        end
        local changed = {}
        for _,proxy in pairs(self.Target or {}) do
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
                    for _,proxy in pairs(changed) do
                        local startTransform = undoTransforms[proxy]
                        proxy:SetTransform(startTransform)
                    end
                end,
                Redo = function()
                    for _,proxy in pairs(changed) do
                        local endTransform = redoTransforms[proxy]
                        proxy:SetTransform(endTransform)
                    end
                end
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