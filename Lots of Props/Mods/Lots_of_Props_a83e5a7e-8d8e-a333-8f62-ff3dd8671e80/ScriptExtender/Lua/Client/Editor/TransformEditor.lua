--- @class TransformEditor
--- @field Mode "Translate" | "Rotate" | "Scale"
--- @field Space "World" | "Local" | "Relative"
--- @field Gizmo Gizmo|nil
--- @field Target GUIDSTRING|GUIDSTRING[]|nil
--- @field History HistoryManager
--- @field Subscriptions table<string, LOPSubscription>
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
    Step = 1,
    Subscriptions = {},
}

local AVAILABLE_SPACES = {
    World = true,
    Local = true,
    View = true,
    Relative = true,
}

local AVAILABLE_MODES = {
    Translate = true,
    Rotate = true,
    Scale = true,
}

local function EqualTransforms(a, b)
    if not a or not b then return false end
    if not a.Translate or not b.Translate then return false end
    if not a.RotationQuat or not b.RotationQuat then return false end
    if not a.Scale or not b.Scale then return false end

    local EPS = 0.0001
    for i=1,3 do
        if math.abs(a.Translate[i] - b.Translate[i]) > EPS then
            return false
        end
    end

    for i=1,4 do
        if math.abs(a.RotationQuat[i] - b.RotationQuat[i]) > EPS then
            return false
        end
    end

    for i=1,3 do
        if math.abs(a.Scale[i] - b.Scale[i]) > EPS then
            return false
        end
    end

    return true
end

local function SaveTransform(guid)
    local toSave = {
        Translate = {CGetPosition(guid)},
        RotationQuat = {CGetRotation(guid)},
        Scale = Vec3.new(CGetScale(guid))
    }
    if not toSave.Translate or #toSave.Translate ~= 3 then
        toSave.Translate = {CGetPosition(CGetHostCharacter())}
    end
    if not toSave.RotationQuat or #toSave.RotationQuat ~= 4 then
        toSave.RotationQuat = {0,0,0,1}
    end
    return toSave
end

---@param guids GUIDSTRING[]
---@param transforms table<GUIDSTRING, {Translate: Vec3|nil, RotationQuat: Vec4|nil, Scale: Vec3|nil}>
local function SetVisualTransform(guids, transforms)
    local entities = {}

    for _,guid in pairs(guids) do
        if type(guid) ~= "string" or guid == "" then
            Warning("TransformEditor: Invalid GUID provided: ", guid)
            goto continue
        end
        local entity = Ext.Entity.Get(guid) --[[@as EntityHandle]]
        if entity.PartyMember then
            local dummy = GetDummyByUuid(guid)
            if dummy and #dummy:GetAllComponentNames() ~= 0 then
                entity = dummy
            end
        end

        if entity then
            entities[guid] = entity
        else
            Warning("TransformEditor: Entity not found: ", guid)
        end
        ::continue::
    end

    for guid,entity in pairs(entities) do
        if not entity or not entity.Visual or not entity.Visual.Visual then return end
        local transform = transforms[guid]
        if not transform then
            --Warning("TransformEditor: No transform provided for guid: "..tostring(guid))
            return
        end
        local visual = entity.Visual.Visual
        if transform.Translate then
            visual:SetWorldTranslate(transform.Translate)
        end
        if transform.RotationQuat then
            visual:SetWorldRotate(transform.RotationQuat)
        end
        if transform.Scale then
            visual:SetWorldScale(transform.Scale)
        end
    end
    Post(NetChannel.Bind, { Type = "UpdateOffset", Guid = guids })
end

--- @param guids GUIDSTRING[]
--- @param transforms table<GUIDSTRING, {Translate: Vec3|nil, RotationQuat: Vec4|nil, Scale: Vec3|nil}>
local function SetItemTransform(guids, transforms)
    SetVisualTransform(guids, transforms)
    Post(NetChannel.SetTransform, {Guid=guids, Transforms = transforms})
end

local templateTypeHandler = {
    Character = SetVisualTransform,
    Item = SetItemTransform,
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
    if checkIFSame(self.Target, selection) then
        Debug("TransformEditor: Selection unchanged, ignoring.")
        return
    end

    self.Target = {}
    for guid,_ in pairs(selection) do
        if not EntityExists(guid) then goto continue end
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
    self.Gizmo:CreateItem(self.Target)
end

function TransformEditor:SetSpace(space)
    if self.IsDragging then return end
    if AVAILABLE_SPACES[space] then
        if self.Gizmo then
            self.Gizmo.Space = space
            self.Gizmo:UpdateItem()
        end
    else
        Warning("TransformEditor:SetSpace: Invalid space '"..tostring(space).."'. Available spaces are: "..table.concat(AVAILABLE_SPACES, ", "))
    end
end

function TransformEditor:Clear()
    if self.IsDragging then return end
    self.Target = nil
    self.StartTransforms = {}
    Post(NetChannel.ManageGizmo, {Type="Clear"})
end

function TransformEditor:SetMode(mode)
    if self.IsDragging then return end
    if not AVAILABLE_MODES[mode] then return end
    if mode and mode ~= self.Gizmo.Mode then
        self.Gizmo.Mode = mode
        self.Gizmo:UpdateItem()
        --Debug("TransformEditor Mode: "..tostring(self.Gizmo.Mode))
    end
end

--- @param guids GUIDSTRING[]
--- @return table<"Character"|"Item", GUIDSTRING[]>
function TransformEditor:Filter(guids)
    local groups = { Character = {}, Item = {} }
    for _, guid in ipairs(guids) do
        local entity = UuidToHandle(guid)
        if entity and entity.IsCharacter then
            table.insert(groups.Character, guid)
        elseif entity and entity.IsItem then
            table.insert(groups.Item, guid)
        elseif TableContains(self.Target or {}, guid) then
            table.remove(self.Target, table.find(self.Target, guid))
            if self.Target and #self.Target == 0 then
                if self.IsDragging then
                    self.IsDragging = false
                end
                self:Clear()
            end
        end
    end
    return groups
end

--- @param guids GUIDSTRING|GUIDSTRING[]
--- @param transform {Translate: Vec3|nil, RotationQuat: Vec4|nil, Scale: Vec3|nil}|table<GUIDSTRING, {Translate: Vec3|nil, RotationQuat: Vec4|nil, Scale: Vec3|nil}>
--- @param notRecordHistory boolean|nil
function TransformEditor:SetTransform(guids, transform, notRecordHistory)
    guids = NormalizeGuidList(guids)
    local groups = self:Filter(guids)
    local originTransform = {}
    for _,guid in pairs(guids) do
        originTransform[guid] = SaveTransform(guid)
    end

    if transform.Translate or transform.RotationQuat or transform.Scale then
        local t = {}
        for _,guid in pairs(guids) do
            t[guid] = transform
        end
        transform = t
    end

    local function doTransform(isReset)
        for t, handler in pairs(templateTypeHandler) do
            handler(groups[t], isReset and originTransform or transform)
        end
    end
    doTransform()
    if not notRecordHistory then
        HistoryManager:PushCommand({
            Undo = function()
                doTransform(true)
            end,
            Redo = function()
                doTransform(false)
            end
        })
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
        return self.Target and #self.Target > 0 or false
    end)

    restrain(teMod:RegisterEvent("RotateMode", function (e)
        if e.Event == "KeyDown" then
            self:SetMode("Rotate")
        end
    end))

    restrain(teMod:RegisterEvent("TranslateMode", function (e)
        if e.Event == "KeyDown" then
            self:SetMode("Translate")
        end
    end))

    restrain(teMod:RegisterEvent("ScaleMode", function (e)
        if e.Event == "KeyDown" then
            self:SetMode("Scale")
        end
    end))

    teMod:RegisterEvent("FollowTarget", function (e)
        if e.Event ~= "KeyDown" or not e.Pressed then return end

        if self.Gizmo and self.Target then
            CameraFollow(self.Target)
        end
    end)

    restrain(teMod:RegisterEvent("DeleteSelection", function (e)
        if e.Event ~= "KeyDown" or not e.Pressed then return end

        local guids = NormalizeGuidList(self.Target)
        local props = {}
        for _,guid in pairs(guids) do
            if not PropStore:GetProp(guid) then
            else
                table.insert(props, guid)
            end
        end
        if #props == 0 then return end

        ConfirmPopup:DangerConfirm(
            string.format("Are you sure you want to delete the selected %d prop(s)?", #guids),
            function()
                self:Clear()
                Post("Delete", { Guid = props })
            end)
        end)
    )

    self.Subscriptions["ResetTransform"] = SubscribeKeyInput({}, function (e)
        if not self.Target or #self.Target == 0 then return end
        if self.IsDragging then return end
        if e.Event ~= "KeyDown" then return end

        if e.Modifiers and e.Modifiers == "LAlt" then
            local resetTransform = {}
            if e.Key == teMod:GetKeyByEvent("RotateMode").Key then resetTransform.RotationQuat = {0,0,0,1} end
            if e.Key == teMod:GetKeyByEvent("TranslateMode").Key then resetTransform.Translate = {CGetPosition(CGetHostCharacter())} end
            if e.Key == teMod:GetKeyByEvent("ScaleMode").Key then resetTransform.Scale = {1,1,1} end

            self:SetTransform(self.Target, resetTransform)
        end
    end)

    restrain(teMod:RegisterEvent("DeleteAllGizmos", function (e)
        if e.Event ~= "KeyDown" then return end
        Post(NetChannel.ManageGizmo, {Type="ClearAll"})
    end))

    local function GetRottt(space, guid)
        local rot = Quat.Identity
        if space == "Local" then
            rot = {CGetRotation(guid)}
        elseif space == "Relative" then
            local parent = PropStore:GetBindParent(guid)
            if parent and EntityExists(parent) then
                rot = {CGetRotation(parent)}
            else
                Debug("TransformEditor: Relative space but no valid parent found")
                rot = Quat.Identity
            end
        elseif space == "View" then
            rot = Quat.new(GetCameraRotation())
        end
        return Quat.new(rot)
    end

    if not self.Gizmo then
        self.Gizmo = Gizmo.new(self)
    end

    self.Gizmo.OnDragStart = function(gizmo)
        self.IsDragging = true
        for _,guid in pairs(NormalizeGuidList(self.Target) or {}) do
            self.StartTransforms[guid] = SaveTransform(guid)
        end
    end

    self.Gizmo.DragVisualize = function (gizmo)
        if gizmo.Mode == "Translate" then
            local requests = CountMap(self.StartTransforms)
            ClientSubscribe(NetMessage.Visualization, function (data)
                for _,guid in ipairs(data.Guid) do
                    Timer:Ticks(10, function (timerID)
                        gizmo:Visualize(guid)
                    end)
                end
                requests = requests - 1
                if requests <= 0 then
                    requests = 0
                    return UNSUBSCRIBE_SYMBOL
                end
            end)
            for guid, transform in pairs(self.StartTransforms) do
                local rot = GetRottt(gizmo.Space, guid)
                local visualType = "Point"
                Post(NetChannel.Visualize, { Type = visualType, Position = transform.Translate, Rotation = rot, Duration = -1})
            end
            if CountMap(gizmo.SelectedAxis) == 1  then
                local color = nil
                local selectedAxis = nil
                for axis,_ in pairs(gizmo.SelectedAxis) do
                    color = GizmoVisualizer.HoveredColor[axis] or {0.9, 0.9, 0.9, 0.8}
                    selectedAxis = axis
                end
                for _,guid in pairs(NormalizeGuidList(self.Target) or {}) do
                    local transform = self.StartTransforms[guid]
                    if transform and transform.Translate then
                        local rot = GetRottt(gizmo.Space, guid)
                        local vector = GLOBAL_COORDINATE[selectedAxis] or Vec3.New(1,0,0)
                        local ray = Ray.new(transform.Translate, rot:Rotate(vector))
                        Post(NetChannel.Visualize, { Type = "Line", Position = ray:At(-100), EndPosition = ray:At(100), Color = color, Duration = -1})
                    end
                end
            end
        end
    end

    self.Gizmo.OnDragTranslate = function(gizmo, delta)
        delta = Vec3.new(delta) * self.Step

        local transforms = {}
        for _, guid in pairs(NormalizeGuidList(self.Target) or {}) do
            local newTransform = {}
            local startTransform = self.StartTransforms[guid]
            local finalDelta = delta
            if gizmo.Space == "Local" then
                finalDelta = Quat.new(startTransform.RotationQuat):Rotate(delta)
            elseif gizmo.Space == "Relative" then
                local parent = PropStore:GetBindParent(guid)
                if parent and EntityExists(parent) then
                    local parentRot = Quat.new({CGetRotation(parent)}) or Quat.Identity
                    finalDelta = parentRot:Rotate(delta)
                else
                    Debug("TransformEditor: Relative space but no valid parent found")
                    finalDelta = {0,0,0}
                end
            end
            if finalDelta:Length() < 0.0001 then
                goto continue
            end
            local newPos = Vec3.new(startTransform.Translate) + finalDelta
            newTransform.Translate = newPos

            transforms[guid] = newTransform
            ::continue::
        end
        self:SetTransform(self.Target, transforms, true)
    end

    self.Gizmo.OnDragScale = function(gizmo, delta)
        if gizmo.Mode ~= "Scale" then
            Error("TransformEditor: Scale delta received but mode is not Scale.")
            return
        end

        delta = 1 + (delta - 1) * self.Step

        local transforms = {}
        local selectedAxes = gizmo.SelectedAxis or { X = true, Y = true, Z = true } -- default to uniform
        local cnt = CountMap(selectedAxes)
        for _, guid in pairs(NormalizeGuidList(self.Target) or {}) do
            local newTransform = {}
            local startTransform = self.StartTransforms[guid]
            local baseScale = startTransform.Scale or {1,1,1}
            local newScale = Vec3.new(baseScale)

            local factor = 1 + (delta - 1) * self.Step
            factor = math.max(0.01, factor)
            if cnt == 3 then
                newScale = Vec3.new{ baseScale[1] * factor, baseScale[2] * factor, baseScale[3] * factor }
            else
                newScale = Vec3.new{ baseScale[1], baseScale[2], baseScale[3] }
                if selectedAxes.X then newScale[1] = math.max(0.01, baseScale[1] * factor) end
                if selectedAxes.Y then newScale[2] = math.max(0.01, baseScale[2] * factor) end
                if selectedAxes.Z then newScale[3] = math.max(0.01, baseScale[3] * factor) end
            end

            newTransform.Scale = newScale
            transforms[guid] = newTransform
            ::continue::
        end
        self:SetTransform(self.Target, transforms, true)
    end

    self.Gizmo.OnDragRotate = function(gizmo, delta)
        if gizmo.Mode ~= "Rotate" then
            Error("TransformEditor: Quat delta received but mode is not Rotate.")
            return
        end


        delta.Angle = delta.Angle * self.Step

        local transforms = {}
        for _, guid in pairs(NormalizeGuidList(self.Target) or {}) do
            local newTransform = {}
            local startTransform = self.StartTransforms[guid]
            local curRot = Quat.new(startTransform.RotationQuat) or Quat.Identity
            local newRot = nil
            local axis = delta.Axis or Vec3.new{0,0,0}
            local angle = delta.Angle or 0
            if gizmo.Space == "Local" then
                axis = curRot:Rotate(axis)
            elseif gizmo.Space == "Relative" then
                local parent = PropStore:GetBindParent(guid)
                if parent and EntityExists(parent) then
                    local parentRot = Quat.new({CGetRotation(parent)}) or Quat.Identity
                    axis = parentRot:Rotate(axis)
                else
                    --Debug("TransformEditor: Relative space but no valid parent found")
                    axis = Vec3.new{0,0,0}
                end
            end
            
            local deltaQuat = Ext.Math.QuatRotateAxisAngle(Quat.Identity, axis, angle)
            newRot = Quat.new(Ext.Math.QuatMul(deltaQuat, curRot))
            newTransform.RotationQuat = newRot

            transforms[guid] = newTransform
        end
        self:SetTransform(self.Target, transforms, true)
    end
    
    self.Gizmo.OnDragCancel = function(gizmo)
        self:SetTransform(self.Target, self.StartTransforms, true)
        self.StartTransforms = {}
        self.IsDragging = false
    end

    self.Gizmo.OnDragEnd = function(gizmo)
        Post(NetChannel.Visualize, { Type = "Clear" })
        local redoTransforms = {}
        local undoTransforms = DeepCopy(self.StartTransforms)
        local changed = {}
        for _,guid in pairs(NormalizeGuidList(self.Target) or {}) do
            if not EntityExists(guid) then goto continue end
            local save = SaveTransform(guid)
            if EqualTransforms(save, self.StartTransforms[guid]) then
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
                    self:SetTransform(changed, undoTransforms, true)
                end,
                Redo = function()
                    self:SetTransform(changed, redoTransforms, true)
                end
            })
        end

        self.StartTransforms = {}
        self.IsDragging = false
    end
end