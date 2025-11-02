--- @class TransformEditor
--- @field Gizmo Gizmo|nil
--- @field Target GUIDSTRING|GUIDSTRING[]|nil
--- @field History HistoryManager
--- @field Subscriptions table<string, RBSubscription>
--- @field Debug boolean
--- @field Select fun(self: TransformEditor, guid: GUIDSTRING|table<GUIDSTRING, any>)
--- @field InitGizmo fun(self: TransformEditor)
--- @field UpdateGizmo fun(self: TransformEditor)
TransformEditor = {}

TransformEditor = {
    Gizmo = nil,
    Target = nil,
    Debug = false,
    StartTransforms = {},
    Subscriptions = {},
    Blacklist = {},
    Disabled = false,
}

local function checkIFSame(array, map)
    if not map or not array then return false end
    if #array ~= table.count(map) then return false end
    for _,v in pairs(array) do
        if not map[v] then return false end
    end
    return true
end

--- @param selection table<GUIDSTRING, any>|GUIDSTRING|nil
function TransformEditor:Select(selection, notRecordHistory)
    local oriSelection = self.Target
    local oriSelectionMap = {}
    for _,v in pairs(oriSelection or {}) do
        oriSelectionMap[v] = true
    end

    if self.IsDragging then return end
    if not selection or selection == "" then
        self.Target = nil
        self:Clear()
        Debug("TransformEditor: Clear selection. No guid provided.")
        return
    end
    if type(selection) == "string" then
        selection = { [selection] = {} }
    end
    if not self.Gizmo or not self.Gizmo.Guid then self.Target = nil end
    if checkIFSame(self.Target, selection) then return end

    self.Target = {}
    for guid,_ in pairs(selection) do
        if self.Blacklist[guid] then goto continue end
        table.insert(self.Target, guid)
        ::continue::
    end

    self:HandleGizmo()
    self:RegisterEvents()
    self:PopupNotify()

    if not notRecordHistory then
        HistoryManager:PushCommand({
            Undo = function()
                self:Select(oriSelectionMap or {}, true)
            end,
            Redo = function()
                self:Select(selection or {}, true)
            end
        })
    end
end

function TransformEditor:AddToBlacklist(guid)
    if not guid then return end
    if not self.Blacklist then
        self.Blacklist = {}
    end
    self.Blacklist[guid] = true
end

function TransformEditor:RemoveFromBlacklist(guid)
    if not guid then return end
    if not self.Blacklist then return end
    self.Blacklist[guid] = nil
end

function TransformEditor:PopupNotify()
    if not self.Target or #NormalizeGuidList(self.Target) == 0 then return end
    local renderList = {}
    for _,guid in pairs(NormalizeGuidList(self.Target) or {}) do
        local icon = GetIcon(guid)
        local name = GetDisplayNameFromGuid(guid)
        if not name then name = GetDisplayNameForEntity(guid) or "Unknown" end
        table.insert(renderList, {Icon=icon, Name=name})
    end

    local notif = self.SelectionChangedNotif or Notification.new("Editor Selection Changed")
    self.SelectionChangedNotif = notif
    notif.Pivot = { 0.1 , 0.8 }
    notif.FlickToDismiss = true
    notif.AnimDirection = "Vertical"
    notif.ChangeDirectionWhenFadeOut = true
    notif:Show("Selection Changed", function (panel)
        for _,entry in pairs(renderList) do
            panel:AddImage(entry.Icon, {32, 32})
            local nameText = panel:AddText(entry.Name)
            nameText.TextWrapPos = 900
            nameText.SameLine = true
        end
    end)
end

function TransformEditor:HandleGizmo()
    if not self.Target or #NormalizeGuidList(self.Target) == 0 then
        self:Clear()
        return
    end
    if not self.Gizmo then
        self.Gizmo = Gizmo.new(self)
    end
    self.Gizmo:SetTarget(self.Target)
end

function TransformEditor:SetSpace(space)
    if Enums.TransformEditorSpace[space] then
        if self.Gizmo then
            self.Gizmo:SetSpace(space)
        end
    else
        Warning("TransformEditor:SetSpace: Invalid space '"..tostring(space))
    end
end

function TransformEditor:Clear()
    self.Target = nil
    self.StartTransforms = {}
    if self.Gizmo then
        self.Gizmo:SetTarget(self.Target)
    end
end

function TransformEditor:SetMode(mode)
    if not Enums.TransformEditorMode[mode] then return end
    if mode and mode ~= self.Gizmo.Mode then
        self.Gizmo:SetMode(mode)
        --Debug("TransformEditor Mode: "..tostring(self.Gizmo.Mode))
    elseif mode and mode == self.Gizmo.Mode and not self.IsDragging then
        self.Gizmo:StartDragging()
    end
end

function TransformEditor:RegisterEvents()
    if self.Registered then return end
    self.Registered = true

    local function restrain(t)
        t:AddCondition(function(e)
            return not self.IsDragging
        end)
    end

    local teMod = KeybindManager:CreateModule("TransformEditor")
    teMod:AddModuleCondition(function(e)
        return self.Disabled ~= true
    end)
    self.TransformEditorMod = teMod


    teMod:RegisterEvent("RotateMode", function (e)
        if not self.Target or #self.Target == 0 then return end
        if e.Event == "KeyDown" then
            self:SetMode("Rotate")
        end
    end)

    teMod:RegisterEvent("TranslateMode", function (e)
        if not self.Target or #self.Target == 0 then return end
        if e.Event == "KeyDown" then
            self:SetMode("Translate")
        end
    end)

    teMod:RegisterEvent("ScaleMode", function (e)
        if not self.Target or #self.Target == 0 then return end
        if e.Event == "KeyDown" then
            self:SetMode("Scale")
        end
    end)

    teMod:RegisterEvent("FollowTarget", function (e)
        if not self.Target or #self.Target == 0 then return end
        if e.Event ~= "KeyDown" or not e.Pressed then return end

        if self.Gizmo and self.Target then
            CameraFollow(self.Target)
        end
    end)

    restrain(teMod:RegisterEvent("DeleteSelection", function (e)
        if not self.Target or #self.Target == 0 then return end
        if e.Event ~= "KeyDown" or not e.Pressed then return end

        local guids = NormalizeGuidList(self.Target)
        local props = {}
        for _,guid in pairs(guids) do
            if not EntityStore:GetStoredData(guid) then
            else
                table.insert(props, guid)
            end
        end
        if #props == 0 then return end

        ConfirmPopup:DangerConfirm(
            string.format("Are you sure you want to delete the selected %d prop(s)?", #props),
            function()
                self:Clear()
                NetChannel.Delete:SendToServer({ Guid = props })
            end)
        end)
    )

    self.Subscriptions["ResetTransform"] = SubscribeKeyInput({}, function (e)
        if not self.Target or #self.Target == 0 then return end
        if self.IsDragging then return end
        if e.Event ~= "KeyDown" then return end

        if not(e.Modifiers and e.Modifiers == "LAlt") then return end

        local resetTransform = {}
        if e.Key == teMod:GetKeyByEvent("RotateMode").Key then resetTransform.RotationQuat = {0,0,0,1} end
        if e.Key == teMod:GetKeyByEvent("TranslateMode").Key then resetTransform.Translate = {CGetPosition(CGetHostCharacter())} end
        if e.Key == teMod:GetKeyByEvent("ScaleMode").Key then resetTransform.Scale = {1,1,1} end

        Commands.SetTransform(self.Target, resetTransform)
    end)

    restrain(teMod:RegisterEvent("DeleteAllGizmos", function (e)
        if e.Event ~= "KeyDown" then return end
        NetChannel.ManageGizmo:RequestToServer({ Clear = true }, function (response)
            self.Gizmo.Guid = nil
        end)
        self.Gizmo:DeleteItem()
    end))

    local function GetRottt(space, guid)
        local rot = Quat.Identity()
        if space == "Local" then
            rot = self.StartTransforms[guid].RotationQuat
        elseif space == "Parent" then
            local parent = EntityStore:GetBindParent(guid)
            if parent and EntityExists(parent) then
                rot = self.StartTransforms[parent] and self.StartTransforms[parent].RotationQuat or {CGetRotation(parent)}
            else
                Debug("TransformEditor: Parent space but no valid parent found")
                rot = Quat.Identity()
            end
        elseif space == "View" then
            rot = self.Gizmo.Picker.Rotation
        end
        return Quat.new(rot)
    end

    if not self.Gizmo then
        self.Gizmo = Gizmo.new(self)
    end

    self.Gizmo.OnDragStart = function(gizmo)
        self.IsDragging = true
        for _,guid in pairs(NormalizeGuidList(self.Target) or {}) do
            self.StartTransforms[guid] = EntityHelpers.SaveTransform(guid)
        end
    end

    self.Gizmo.DragVisualize = function (gizmo)
        self.PointVisualizations = self.PointVisualizations or {}
        self.LineVisualizations = self.LineVisualizations or {}

        for i=#self.LineVisualizations, 1, -1 do
            local guid = self.LineVisualizations[i]
            if not EntityExists(guid) then
                NetChannel.Delete:RequestToServer({ Guid = guid }, function (response)
                    
                end)
                table.remove(self.LineVisualizations, i)
            end
        end

        --[[for i=#self.PointVisualizations, 1, -1 do
            local guid = self.PointVisualizations[i]
            if not EntityExists(guid) then
                NetChannel.Delete:RequestToServer({ Guid = guid }, function (response)
                    -- make sure it's dead
                end)
                table.remove(self.PointVisualizations, i)
            end
        end



        for cnt,guid in pairs(NormalizeGuidList(self.Target) or {}) do
            local transform = self.StartTransforms[guid]
            local newPointTransform = {
                Translate = transform.Translate,
                RotationQuat = GetRottt(gizmo.Space, guid)
            }

            if transform and transform.Translate then
                if self.PointVisualizations and self.PointVisualizations[cnt] then
                    local pointGuid = self.PointVisualizations[cnt]

                    NetChannel.SetTransform:RequestToServer({ Guid = pointGuid, Transforms = {[pointGuid] = newPointTransform} }, function()
                        for _,axis in pairs({"X","Y","Z"}) do
                            if gizmo.SelectedAxis and gizmo.SelectedAxis[axis] then
                                gizmo.Visualizer:HighLightGizmoAxis(axis, pointGuid)
                            else
                                gizmo.Visualizer:HideGizmoAxis(axis, pointGuid)
                            end
                        end
                    end)
                else
                    NetChannel.Visualize:RequestToServer({
                        Type = "Point",
                        Position = transform.Translate,
                        Rotation = newPointTransform.RotationQuat,
                        Duration = -1,
                    }, function (response)
                        local tryCnt = 0

                        for _,viz in ipairs(response or {}) do
                            table.insert(self.PointVisualizations, viz)
                        end
                        Timer:EveryFrame(function (timerID)
                            if tryCnt > 300 or not self.IsDragging then
                                for _,viz in pairs(response or {}) do
                                    gizmo.Visualizer:HideGizmo(viz)
                                end
                                return UNSUBSCRIBE_SYMBOL
                            end
                            local allReady = true
                            for _,viz in ipairs(response or {}) do
                                if not VisualHelpers.GetEntityVisual(viz) then
                                    allReady = false
                                    break
                                end
                            end
                            if not allReady then tryCnt = tryCnt + 1 return end

                            for _,viz in ipairs(response or {}) do
                                for _,axis in pairs({"X","Y","Z"}) do
                                    if gizmo.SelectedAxis and gizmo.SelectedAxis[axis] then
                                        gizmo.Visualizer:HighLightGizmoAxis(axis, viz)
                                    else
                                        gizmo.Visualizer:HideGizmoAxis(axis, viz)
                                    end
                                end
                            end

                            return UNSUBSCRIBE_SYMBOL
                        end)
                    end)
                end
            end
        end]]

        if CountMap(gizmo.SelectedAxis) ~= 1 then 
            for _,v in pairs(self.LineVisualizations or {}) do
                gizmo.Visualizer:SetLineLength(v, 0)
            end
            return
        end

        local color = nil
        local selectedAxis = nil
        for axis,_ in pairs(gizmo.SelectedAxis) do
            color = gizmo.Visualizer.AxisLineColor[axis] or {0.9, 0.9, 0.9, 0.8}
            selectedAxis = axis
            if self.LineVisualizations and #self.LineVisualizations > 0 then
                gizmo.Visualizer:SetLineFxColor(self.LineVisualizations[1], color)
            end
        end
        for cnt,guid in pairs(NormalizeGuidList(self.Target) or {}) do
            local transform = self.StartTransforms[guid]
            local rot = GetRottt(gizmo.Space, guid)
            local vector = GLOBAL_COORDINATE[selectedAxis]
            local ray = Ray.new(transform.Translate, rot:Rotate(vector))
            if self.LineVisualizations[cnt] then
                local lineGuid = self.LineVisualizations[cnt]
                gizmo.Visualizer:SetLineFxColor(lineGuid, color)
                local newLineTransform = {
                    Translate = ray:At(-100),
                    RotationQuat = DirectionToQuat(ray.Direction * -1),
                }
                NetChannel.SetTransform:RequestToServer({ Guid = lineGuid, Transforms = {[lineGuid] = newLineTransform} }, function (response)
                    -- prevent flickering
                    Timer:Ticks(5, function (timerID)
                        if not self.IsDragging then return end
                        gizmo.Visualizer:SetLineLength(lineGuid, 20)
                    end)
                end)
            else
                NetChannel.Visualize:RequestToServer({
                    Type = "Line",
                    Position = ray:At(-100),
                    EndPosition = ray:At(100),
                    Width = gizmo.Visualizer.Scale[1] * 0.3,
                    Duration = -1,
                }, function (response)
                    for _,viz in ipairs(response or {}) do
                        local tryCnt = 0
                        Timer:EveryFrame(function (timerID)
                            if tryCnt > 300 or not self.IsDragging then return UNSUBSCRIBE_SYMBOL end
                            if not VisualHelpers.GetEntityVisual(viz) then tryCnt = tryCnt + 1 return end
                            gizmo.Visualizer:SetLineFxColor(viz, color)
                            return UNSUBSCRIBE_SYMBOL
                        end)
                        table.insert(self.LineVisualizations, viz)
                    end
                end)
            end
        end
    end

    self.Gizmo.OnDragTranslate = function(gizmo, delta)
        local transforms = {}
        for _, guid in pairs(NormalizeGuidList(self.Target) or {}) do
            local newTransform = {}
            local startTransform = self.StartTransforms[guid]
            local finalDelta = delta
            if gizmo.Space == "Local" then
                finalDelta = Quat.new(startTransform.RotationQuat):Rotate(delta)
            elseif gizmo.Space == "Parent" then
                local parent = EntityStore:GetBindParent(guid)
                if parent and EntityExists(parent) then
                    local parentRot = Quat.new({CGetRotation(parent)}) or Quat.Identity()
                    finalDelta = parentRot:Rotate(delta)
                else
                    Debug("TransformEditor: Parent space but no valid parent found")
                    finalDelta = {0,0,0}
                end
            end
            local newPos = Vec3.new(startTransform.Translate) + finalDelta
            newTransform.Translate = newPos

            transforms[guid] = newTransform
        end
        Commands.SetTransform(self.Target, transforms, true)
    end

    self.Gizmo.OnDragScale = function(gizmo, delta)
        local transforms = {}

        local cameraMatrix = nil
        if gizmo.Space == "View" then
            cameraMatrix = Matrix.new(Ext.Math.QuatToMat4({GetCameraRotation()}))
        end

        for _, guid in pairs(NormalizeGuidList(self.Target) or {}) do
            local newTransform = {}
            local startTransform = self.StartTransforms[guid]
            local baseScale = startTransform.Scale or {1,1,1}

            local deltaWorld = Vec3.new(delta)

            local newScale = nil
            if gizmo.Space == "World" or gizmo.Space == "View" or gizmo.Space == "Parent" then
                -- Convert world-space delta scaling into local-space scale factors
                local R = Matrix.new(Ext.Math.QuatToMat4(startTransform.RotationQuat))
                if gizmo.Space == "View" then
                    R = cameraMatrix * R
                elseif gizmo.Space == "Parent" then
                    local parent = EntityStore:GetBindParent(guid)
                    if parent and EntityExists(parent) then
                        local parentRot = Quat.new{CGetRotation(parent)} or Quat.Identity()
                        local parentMat = Matrix.new(Ext.Math.QuatToMat4(parentRot))
                        
                        R = parentMat:Inverse() * R
                    else
                        R = Matrix.Identity(4)
                    end
                end
                local S_world = Ext.Math.BuildScale(deltaWorld)

                local S_local = R:Transpose() * S_world * R
                

                local sx = S_local[1 + (1 - 1) * 4]
                local sy = S_local[2 + (2 - 1) * 4]
                local sz = S_local[3 + (3 - 1) * 4]

                newScale = Vec3.new(
                    baseScale.X * sx,
                    baseScale.Y * sy,
                    baseScale.Z * sz
                )
            else
                newScale = Vec3.new(baseScale) * deltaWorld
            end

            newTransform.Scale = newScale
            transforms[guid] = newTransform
        end
        Commands.SetTransform(self.Target, transforms, true)
    end

    self.Gizmo.OnDragRotate = function(gizmo, delta)
        local deltaAngle = delta.Angle or 0
        local transforms = {}
        for _, guid in pairs(NormalizeGuidList(self.Target) or {}) do
            local newTransform = {}
            local startTransform = self.StartTransforms[guid]
            local curRot = Quat.new(startTransform.RotationQuat) or Quat.Identity()
            local newRot = nil
            local axis = delta.Axis or Vec3.new{0,0,0}
            local angle = deltaAngle or 0
            if gizmo.Space == "Local" then
                axis = curRot:Rotate(axis)
            elseif gizmo.Space == "Parent" then
                local parent = EntityStore:GetBindParent(guid)
                if parent and EntityExists(parent) then
                    local parentRot = Quat.new({CGetRotation(parent)}) or Quat.Identity()
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
            newTransform.RotationQuat = newRot

            transforms[guid] = newTransform
            ::continue::
        end
        Commands.SetTransform(self.Target, transforms, true)
    end
    

    self.Gizmo.OnDragEnd = function(gizmo)
        for _,v in pairs(self.LineVisualizations or {}) do
            gizmo.Visualizer:SetLineLength(v, 0)
        end
        for _,v in pairs(self.PointVisualizations or {}) do
            gizmo.Visualizer:HideGizmo(v)
        end
        local redoTransforms = {}
        local undoTransforms = DeepCopy(self.StartTransforms)
        local changed = {}
        for _,guid in pairs(NormalizeGuidList(self.Target) or {}) do
            if not EntityExists(guid) then goto continue end
            local save = EntityHelpers.SaveTransform(guid)
            if EntityHelpers.EqualTransforms(save, self.StartTransforms[guid]) then
                undoTransforms[guid] = nil
            else
                redoTransforms[guid] = save
                table.insert(changed, guid)
            end
            ::continue::
        end

        if next(redoTransforms) then
            HistoryManager:PushCommand({
                Undo = function()
                    Commands.SetTransform(changed, undoTransforms, true)
                end,
                Redo = function()
                    Commands.SetTransform(changed, redoTransforms, true)
                end
            })
        end

        self._accuDelta = nil
        self._delta = nil
        self.StartTransforms = {}
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

