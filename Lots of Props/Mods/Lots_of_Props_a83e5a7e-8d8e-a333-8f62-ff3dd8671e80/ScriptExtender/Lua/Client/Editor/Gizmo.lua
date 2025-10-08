--- @class Gizmo
--- @field Editor TransformEditor
--- @field Mode "Translate" | "Rotate" | "Scale"
--- @field SelectedAxis table<'X' | 'Y' | 'Z', boolean> | nil
--- @field HoveredAxis table<'X' | 'Y' | 'Z', boolean> | nil
--- @field StartHit Hit | nil
--- @field IsDragging boolean
--- @field Guid Guid -- Gizmo entity guid
--- @field Picker GizmoPicker
--- @field Subscription table<string, LOPSubscription>
--- @field DetectTimer table<string, TimerID>
--- @field new fun(editor: TransformEditor): Gizmo
--- @field OnDragStart fun(self: Gizmo)
--- @field OnDragTranslate fun(self: Gizmo, delta: Vec3)
--- @field OnDragRotate fun(self: Gizmo, delta: { Angle:number, Axis:Vec3 })
--- @field OnDragScale fun(self: Gizmo, delta: number)
--- @field OnDragEnd fun(self: Gizmo)
--- @field OnDragCancel fun(self: Gizmo)
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
    self.Picker = GizmoPicker.new(self)
    self.Subscription = {}
    self.DetectTimer = {}
    self.GetSubscription = ClientSubscribe(NetMessage.ServerGizmo, function (data)
        --Info("Gizmo: Received Gizmo data update for GUID: ", data)
        self.Guid = data.Gizmo
        self.Mode = data.Mode or self.Mode or "Translate"
        self.Space = data.Space or self.Space or "World"
        if data.Type == "Delete" or data.Type == "ClearAll" then
            self:ItemDestroyed()
        elseif data.Type == "Update" then
            self:SetupLiseners()
            self:Visualize()
        end
    end)
end

function Gizmo:EmptyDrag()
    if self.Mode == "Rotate" then
        self:OnDragRotate({ Angle = 0, Axis = Vec3.new{0,0,0} })
    else
        self:OnDragTranslate(Vec3.new{0,0,0})
    end
end

function Gizmo:SetScale(scale)
    GizmoVisualizer.GizmoScale = scale
end

function Gizmo:UpdatePicker()
    local pos = Vec3.new(CGetPosition(self.Guid))
    self.Picker.Position = pos
    self.Picker.Rotation = Quat.new{CGetRotation(self.Guid)}
    local scale = GizmoVisualizer:UpdateScale(self.Guid)
    self.Picker.Scale = scale
    self.Picker.AABB = { Min = pos - {scale, scale, scale}, Max = pos + {scale, scale, scale} }
end

function Gizmo:SetupLiseners()
    self:StopListeners()

    self.Subscription["LockAxis"] = SubscribeKeyInput({}, function (e)
        if not self.IsDragging then return end
        if e.Event ~= "KeyDown" or not e.Pressed then return end

        local mouseRay = ScreenToWorldRay()
        if not mouseRay then Warning("Gizmo:LockAxis: Failed to get mouse ray") return end
    
        if not GLOBAL_COORDINATE[e.Key] then return end

        if self.SelectedAxis and self.SelectedAxis[e.Key] and CountMap(self.SelectedAxis) == 1 then
            -- same axis ignore
            return
        end
    
        self:EmptyDrag()
        self:StopWithoutCallbacks()
        self:Hide()
        local axis = e.Key

        self.SelectedAxis = { [axis] = true }
        self.HoveredAxis = nil
        self.IsDragging = true
        self:UpdatePicker()
        self.StartHit = self:GetHit(mouseRay)
        self:SetupDragging()
        self:Visualize()
        self:DragVisualize()
    end)

    self.Subscription["DragStart"] = SubscribeMouseInput({}, function (e)
        if e.Button == 1 and e.Pressed and self.Picker and not self.IsDragging then
            local mouseRay = ScreenToWorldRay()
            if not mouseRay then Warning("Gizmo:DragStart: Failed to get mouse ray") return end
            self:UpdatePicker()
            local hit = self.Picker:Hit(mouseRay)
            if hit and hit.Axis then
                self.IsDragging = true
                self.SelectedAxis = hit.Axis
                self.HoveredAxis = nil
                self.StartHit = self:GetHit(mouseRay)
                self:OnDragStart()
                self:SetupDragging()
                self:Visualize()
                self:DragVisualize()
            end
        end
    end)

    self.Subscription["DragCancel"] = SubscribeMouseInput({}, function (e)
        if not self.IsDragging then return end
        if e.Pressed and tonumber(e.Button) == 3 then
            if self.SelectedAxis then
                self:EmptyDrag()
                self:StopWithoutCallbacks()
                self:OnDragCancel()
                self:Visualize()
            end
        end
    end)

    self.Subscription["DragEnd"] = SubscribeMouseInput({}, function (e)
        if not self.IsDragging then return end
        if e.Button == 1 and not e.Pressed then
            self:StopDragging()
            self:Visualize()
        end
    end)

    self.DetectTimer["DetectHover"] = Timer:EveryFrame(function (timerID)
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
        
end

function Gizmo:CreateItem(Target)
    if self.Guid and EntityExists(self.Guid) then
        --Warning("Gizmo: Gizmo entity already exists: "..tostring(self.Guid)..", turn to Update instead")
        self:UpdateItem(Target)
        return
    end
    local data = {
        Type = "Create",
        Target = Target,
        GizmoType = self.Mode,
        GizmoSpace = self.Space,
    }
    Post(NetChannel.ManageGizmo, data)
end

function Gizmo:UpdateItem(Target)
    if not self.Guid or not EntityExists(self.Guid) then
        Warning("Gizmo: No gizmo entity exists")
        return
    end
    local data = {
        Type = "Update",
        Guid = self.Guid,
        Target = Target,
        GizmoType = self.Mode,
        GizmoSpace = self.Space,
    }
    --Debug("Gizmo: Updating gizmo ", self.Guid, " with targets: ", Ext.DumpExport(Target))
    Post(NetChannel.ManageGizmo, data)
end

function Gizmo:ItemDestroyed()
    if self.IsDragging then
        self:StopDragging()
    end
    self:StopListeners()
    self.Guid = nil
    self.SelectedAxis = nil
    self.HoveredAxis = nil
    self.IsDragging = false
    self.StartHit = nil
end

local lastDraw = 0

--- @param ray Ray
function Gizmo:GetHit(ray)
    local cnt = CountMap(self.SelectedAxis or {})
    if cnt == 0 then return nil end

    local hit = nil
    if self.Mode == "Rotate" then
        local axis = nil
        for a,_ in pairs(self.SelectedAxis) do axis = a end
        hit = self.Picker:HitPlanePerpToAxis(ray, axis)

        local origin = Vec3.new{CGetPosition(self.Guid)}

        if hit and hit.Position and self.Visualizations and #self.Visualizations > 0 then
            local dir = hit.Position - origin
            local quat = DirectionToQuat(dir, Ext.Math.QuatRotate({CGetRotation(self.Guid)}, GLOBAL_COORDINATE.Y), axis)
            local newest = self.Visualizations[#self.Visualizations]
            for _,guid in ipairs(self.Visualizations or {}) do
                GizmoVisualizer:VisualizeRotateSymbol(guid, axis)
            end
            Post(NetChannel.SetTransform, {
                Guid = newest,
                Transforms = {
                    [newest] = {
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

    if false and Ext.Timer.MonotonicTime() - lastDraw > 1000 and hit and hit.Position then
        lastDraw = Ext.Timer.MonotonicTime()
        hit.Normal = hit.Normal or GLOBAL_COORDINATE.Y
        Post("Visualize", { Type = "Point", Position = hit.Position, Rotation = DirectionToQuat(hit.Normal)})
    end
    if not hit or not hit.Position then
        --Warning("Gizmo: No hit detected, fallback to gizmo origin")
        return Hit.new(Vec3.new{CGetPosition(self.Guid)}, nil, 0, nil)
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
--- @param selectedAxes table<'X' | 'Y' | 'Z', boolean>
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
    local gizmoOrigin = Vec3.new(CGetPosition(self.Guid))
    local delta = nil
    if self.Mode == "Translate" then
        local worlddelta = hit.Position - startHit.Position
        delta = worlddelta
        if self.Space == "Local" or self.Space == "Relative" then
            -- reverse rotate delta by picker rotation
            -- let editor handle local translation
            local rot = Quat.new(self.Picker.Rotation)
            delta = rot:Inverse():Rotate(worlddelta)
        end
    elseif self.Mode == "Rotate" then
        local axis = nil
        for a,_ in pairs(self.SelectedAxis) do axis = a end
        if not axis then Warning("Gizmo:GetDelta: No axis selected for rotation") return nil end

        local startDir = (startHit.Position - gizmoOrigin):Normalize()
        local dir = (hit.Position - gizmoOrigin):Normalize()

        local angle = CalcRotationChange(startDir, dir, axes[axis], gizmoOrigin)

        local axisVec = axes[axis]
        if self.Space == "Local" or self.Space == "Relative" then
            -- same as above
            local rot = Quat.new(self.Picker.Rotation)
            axisVec = rot:Inverse():Rotate(axes[axis])
        end

        delta = { Angle = angle, Axis = axisVec }

    elseif self.Mode == "Scale" then
        delta = Vec3.new{1,1,1}
        local scale = CalcScaleChange(startHit, hit, self.SelectedAxis, axes, gizmoOrigin)
        delta = scale
        for a,_ in pairs(self.SelectedAxis) do
            local index = AxisIndexMap[a]
            GizmoVisualizer.ScaleMultiplier[index] = scale
        end
    end
        
    return delta
end

function Gizmo:SetupDragging()
    self.Visualizations = {}
    local requests = 0
    local pickerPos = Vec3.new(self.Picker.Position)
    local pickerRot = Quat.new(self.Picker.Rotation)
    local receive = ClientSubscribe("Visualization", function (data)
        for _,guid in pairs(data.Guid or {}) do
            if TableContains(self.Visualizations, guid) then goto continue end
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

        local rotateScale = GizmoVisualizer:UpdateScale(self.Guid)
        local scale = ToVec3((0.6 * rotateScale) / 0.8) -- rotate gizmo radius is 0.6, translate gizmo's axis's length is 0.8

        requests = 2

        Post("Visualize", { Type = "Point", Position =  pickerPos, Rotation = quat, Scale = scale,  Duration = -1 })
        Post("Visualize", { Type = "Point", Position = pickerPos, Rotation = quat, Scale = scale,  Duration = -1 })
    else
        receive:Unsubscribe()
    end

    self.DetectTimer["Dragging"] = Timer:EveryFrame(function (timerID)
        if not self.IsDragging or not self.StartHit or not self.Picker or not self.Guid or not EntityExists(self.Guid) then
            self:StopDragging()
            Debug("Gizmo: Stopped dragging due to invalid state")
            return UNSUBSCRIBE_SYMBOL
        end

        local mouseRay = ScreenToWorldRay()
        if not mouseRay then Warning("Gizmo:SetupDragging: Failed to get mouse ray") return end
    
        local delta = self:GetDelta(mouseRay)
        if not delta then return end

        --Debug("Gizmo: Dragging delta: ", returnDelta)
        if self.Mode == "Rotate" then
            delta = delta --[[@as { Angle:number, Axis:Vec3 }]]
            self:OnDragRotate(delta)
        elseif self.Mode == "Translate" then
            delta = delta --[[@as Vec3]]
            self:OnDragTranslate(delta)
        elseif self.Mode == "Scale" then
            delta = delta --[[@as number]]
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
    self.StartOffset = nil
    Timer:Cancel(self.DetectTimer["Dragging"])
    self.Visualizations = {}
    Post("SetVisualize", { Visible = false, Count = -1})
    Post(NetChannel.Visualize, { Type = "Clear" })
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
    for k,v in pairs(self.DetectTimer) do
        if v then
            Timer:Cancel(v)
            self.DetectTimer[k] = nil
        end
    end
end

function Gizmo:Visualize(guid)
    guid = guid or self.Guid
    GizmoVisualizer:UpdateScale(guid)
    if self.SelectedAxis then
        for axis,_ in pairs(self.SelectedAxis) do
            GizmoVisualizer.HighLightGizmoAxis(axis, guid)
        end
        for _,axis in pairs({"X","Y","Z"}) do
            if not self.SelectedAxis[axis] then
                GizmoVisualizer.HideGizmoAxis(axis, guid)
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