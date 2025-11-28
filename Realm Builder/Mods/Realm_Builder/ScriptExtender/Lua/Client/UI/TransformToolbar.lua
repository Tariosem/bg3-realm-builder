--- @class TransformToolbar
--- @field parent ExtuiTabBar
--- @field EventsToKeybinds table<string, SDLScanCode|string>
--- @field new fun(): TransformToolbar
TransformToolbar = _Class("TransformToolbar")

function TransformToolbar:__init()
    self.Subscriptions = {}
    self.Selecting = {}
    self.Ignore = {
        Character = false,
        Scenery = false,
    }
    self.isInputing = false
    self:RegisterKeyInputEvents()
end

function TransformToolbar:RegisterKeyInputEvents()
    if self.Registered then return end
    self.Registered = true

    local function singleSelect()
        local guid = GetPickingGuid()
        local entity = GetPickingEntity()

        if entity and entity.Scenery and not self.Ignore["Scenery"] then

            RB_GLOBALS.TransformEditor:Select({SceneryMovableProxy.new(entity.Scenery)})
            return
        end

        if CIsCharacter(guid) and self.Ignore["Character"] then
            return
        end

        if guid and guid ~= "" then
            if self.MultiSelecting then
                self.Selecting[guid] = {}

                local proxies = {}
                for selGuid,_ in pairs(self.Selecting) do
                    table.insert(proxies, MovableProxy.CreateByGuid(selGuid))
                end

                RB_GLOBALS.TransformEditor:Select(proxies)
            else

                RB_GLOBALS.TransformEditor:Select({MovableProxy.CreateByGuid(guid)})
            end
        else
        end
    end

    local restrainInputing = function(e)
        return not self.Operator and not self.isInputing
    end
    local restrainOpening = function(e)
        return self.TopToolBar and self.TopToolBar.Open
    end

    local ttMod = KeybindManager:CreateModule("TransformToolbar")
    local buMod = KeybindManager:CreateModule("BindUtility")
    
    self.KeybindModule = ttMod
    self.BindUtilityModule = buMod
    self:RegisterTransformEditorEvents()
    
    buMod:AddModuleCondition(restrainOpening)
    ttMod:AddModuleCondition(restrainOpening)

    ttMod:AddModuleCondition(restrainInputing)
    buMod:AddModuleCondition(restrainInputing)

    self.Subscriptions["NumericInput"] = SubscribeKeyInput({}, function (e)
        if not restrainInputing(e) then return end
        if not restrainOpening(e) then return end
        if e.Repeat then return end
        if e.Event ~= "KeyDown" then return end
        if not RB_GLOBALS.TransformEditor.Gizmo then return end
        if not RB_GLOBALS.TransformEditor.Gizmo.IsDragging then return end
        if not RB_GLOBALS.TransformEditor.Target or #RB_GLOBALS.TransformEditor.Target == 0 then return end

        if tonumber(KeybindHelpers.ParseInputToCharInput(e)) then
            local selectedAxis = RB_GLOBALS.TransformEditor.Gizmo and RB_GLOBALS.TransformEditor.Gizmo.SelectedAxis
            RB_GLOBALS.TransformEditor.Gizmo:CancelDragging()

            self:SetupOperator(RB_GLOBALS.TransformEditor.Gizmo.Mode, self:GetCurrentSpace(), selectedAxis)
        end
    end)

    ttMod:RegisterEvent("MultiSelect", function (e)
        if not e.Pressed then return end
        
        if not self.MultiSelecting then
            self.MultiSelecting = true
            Debug("Multi-Selecting Enabled")
        else
            self.MultiSelecting = false
            Debug("Multi-Selecting Disabled")
            self.Selecting = {}
        end
    end)

    ttMod:RegisterEvent("Select", function (e)
        if e.Event ~= "KeyDown" or e.Repeat then return end
        singleSelect()
    end)


    ttMod:RegisterEvent("ClearSelection", function (e)
        if e.Event ~= "KeyDown" then return end
        RB_GLOBALS.TransformEditor:Clear()
        self.Selecting = {}
    end)

    ttMod:RegisterEvent("MoveToCursor", function (e)
        if e.Event ~= "KeyDown" then return end

        local targets = RB_GLOBALS.TransformEditor.Target or {}
        local pos, rot = GetPickingHitPosAndRot()
        if not pos then return end

        Commands.SetTransform(targets, {Translate = pos, RotationQuat = rot})
    end)

    ttMod:RegisterEvent("Duplicate", function (e)
        if e.Event ~= "KeyDown" then return end

        local targets = {}
        for _,proxy in pairs(RB_GLOBALS.TransformEditor.Target) do
            if proxy.Guid then
                table.insert(targets, proxy.Guid)
            end
        end

        Commands.DuplicateCommand(targets)
    end)

    ttMod:RegisterEvent("OpenVisualTab", function (e)
        if e.Event ~= "KeyDown" then return end
        local host = CGetHostCharacter()

        if IsInCharacterCreationMirror() then
            VisualTab.new(host, GetName(host), nil, nil):Render()
            return
        end

        local pick = GetPickingEntity()
        local pickId = HandleToUuid(pick)

        if not pick then
            pickId = host
        end

        if pickId then
            VisualTab.new(pickId, GetName(pickId), nil, nil):Render()
        elseif pick.Visual then
            VisualHelpers.RegisterVisual(pick)
            if pick.Scenery then
                VisualTab.CreateByEntity(pick, pick.Scenery.Uuid, "Scenery"):Render()
            else
                _D(pick:GetAllComponents())
            end
        end
    end)

    ttMod:RegisterEvent("OpenNearbyPopup", function (e)
        if e.Event ~= "KeyDown" then return end
        self:CreateNearbyPopup()
    end)

    ttMod:RegisterEvent("Move3DCursor", function (e)
        if e.Event ~= "KeyDown" then return end
        if not self.Cursor then
            self:CreateCursor()
            return
        end
        self:MoveCursor()
    end)

    buMod:RegisterEvent("BindTo", function (e)
        if e.Event ~= "KeyDown" then return end
        if not RB_GLOBALS.TransformEditor.Target or #RB_GLOBALS.TransformEditor.Target == 0 then return end
        local parent = GetPickingGuid()
        if not parent or parent == "" then
            Debug("No valid target to bind to")
            return
        end
        local targets = {}

        for _,proxy in pairs(RB_GLOBALS.TransformEditor.Target) do
            if proxy.Guid then
                table.insert(targets, proxy.Guid)
            end
        end

        Commands.Bind(targets, parent)
    end)

    buMod:RegisterEvent("Unbind", function (e)
        if e.Event ~= "KeyDown" then return end
        if not RB_GLOBALS.TransformEditor.Target or #RB_GLOBALS.TransformEditor.Target == 0 then return end

        local targets = {}
        for _,proxy in pairs(RB_GLOBALS.TransformEditor.Target) do
            if proxy.Guid then
                table.insert(targets, proxy.Guid)
            end
        end

        Commands.Unbind(targets)
    end)

    buMod:RegisterEvent("Snap", function (e)
        if e.Event ~= "KeyDown" then return end
        if not RB_GLOBALS.TransformEditor.Target or #RB_GLOBALS.TransformEditor.Target == 0 then return end

        local targets = {}

        for _,proxy in pairs(RB_GLOBALS.TransformEditor.Target) do
            if proxy.Guid then
                table.insert(targets, proxy.Guid)
            end
        end

        Commands.SnapCommand(targets)
    end)

    buMod:RegisterEvent("BindPopup", function (e)
        if e.Event ~= "KeyDown" then return end
        local targets = {}

        for _,proxy in pairs(RB_GLOBALS.TransformEditor.Target) do
            if proxy.Guid then
                table.insert(targets, proxy.Guid)
            end
        end

        if #targets == 0 then 
            targets = {GetPickingGuid()}
        end

        for guid,popup in pairs(self.BindPopupCache or {}) do
            popup:Dismiss()
        end

        for _,guid in ipairs(targets) do
            self:CreateBindPopup(guid)
        end
    end)


    local function registerToggleEvent(eventName, netType, field, valueOn, valueOff, mod)
        local channel = netType == "SetAttributes" and NetChannel.SetAttributes or NetChannel.Bind

        mod:RegisterEvent(eventName, function (e)
            if e.Event ~= "KeyDown" then return end
            if not RB_GLOBALS.TransformEditor.Target or #RB_GLOBALS.TransformEditor.Target == 0 then return end
            local targets = {}
            for _,proxy in pairs(RB_GLOBALS.TransformEditor.Target) do
                if proxy.Guid then
                    table.insert(targets, proxy.Guid)
                end
            end
            local paramsOn = { Guid = targets , Attributes = {} , Type = "SetAttributes"}
            local paramsOff = { Guid = targets , Attributes = {} , Type = "SetAttributes"}
            paramsOn.Attributes[field] = valueOn
            paramsOff.Attributes[field] = valueOff
            channel:SendToServer(paramsOn)

            HistoryManager:PushCommand({
                Undo = function() channel:SendToServer(paramsOff) end,
                Redo = function() channel:SendToServer(paramsOn) end
            })
        end)
    end
    registerToggleEvent("LookAt", "SetType", "KeepLookingAt", true, false, buMod)
    registerToggleEvent("StopLookAt", "SetType", "KeepLookingAt", false, true, buMod)
    registerToggleEvent("Follow", "SetType", "FollowParent", true, false, buMod)
    registerToggleEvent("StopFollow", "SetType", "FollowParent", false, true, buMod)
    registerToggleEvent("HideSelection", "SetAttributes", "Visible", false, true, ttMod)
    registerToggleEvent("ShowSelection", "SetAttributes", "Visible", true, false, ttMod)
    registerToggleEvent("ApplyGravity", "SetAttributes", "Gravity", true, false, ttMod)
    registerToggleEvent("FreezeGravity", "SetAttributes", "Gravity", false, true, ttMod)

    ttMod:RegisterEvent("Undo", function (e)
        if e.Event ~= "KeyDown" then return end
        HistoryManager:Undo()
    end)

    ttMod:RegisterEvent("Redo", function (e)
        if e.Event ~= "KeyDown" then return end
        HistoryManager:Redo()
    end)

    self:SetupBoxSelect()
end

function TransformToolbar:RegisterTransformEditorEvents()
    local globalEditor = RB_GLOBALS.TransformEditor
    local teMod = KeybindManager:CreateModule("TransformEditor")
    teMod:AddModuleCondition(function(e)
        return globalEditor.Disabled ~= true
    end)
    teMod:AddModuleCondition(function(e)
        return globalEditor.Target and #globalEditor.Target > 0 or false
    end)
    
    teMod:RegisterEvent("RotateMode", function (e)
        if e.Event == "KeyDown" then
            globalEditor:SetMode("Rotate")
        end
    end)

    teMod:RegisterEvent("TranslateMode", function (e)
        if e.Event == "KeyDown" then
            globalEditor:SetMode("Translate")
        end
    end)

    teMod:RegisterEvent("ScaleMode", function (e)
        if e.Event == "KeyDown" then
            globalEditor:SetMode("Scale")
        end
    end)

    teMod:RegisterEvent("FollowTarget", function (e)
        if globalEditor.IsDragging then return end

        local avgPos = Vec3.new(0,0,0)
        for _,proxy in pairs(globalEditor.Target or {}) do
            avgPos = avgPos + proxy:GetWorldTranslate()
        end
        avgPos = avgPos / #globalEditor.Target
        CameraMoveToPosition({avgPos.X, avgPos.Y, avgPos.Z})
    end)

    self.Subscriptions["ResetTransform"] = SubscribeKeyInput({}, function (e)
        if not globalEditor.Target or #globalEditor.Target == 0 then return end
        if globalEditor.IsDragging then return end
        if e.Event ~= "KeyDown" then return end

        if not(e.Modifiers and e.Modifiers == "LAlt") then return end

        local resetTransform = {}
        if e.Key == teMod:GetKeyByEvent("RotateMode").Key then resetTransform.RotationQuat = {0,0,0,1} end
        if e.Key == teMod:GetKeyByEvent("TranslateMode").Key then resetTransform.Translate = {CGetPosition(CGetHostCharacter())} end
        if e.Key == teMod:GetKeyByEvent("ScaleMode").Key then resetTransform.Scale = {1,1,1} end

        Commands.SetTransform(globalEditor.Target or {}, resetTransform)
    end)

    self.KeybindModule:RegisterEvent("DeleteAllGizmos", function (e)
        if e.Event ~= "KeyDown" then return end
        if globalEditor.IsDragging then return end
        if not globalEditor.Gizmo.Guid then
            NetChannel.ManageGizmo:RequestToServer({ Clear = true }, function (response)
                globalEditor.Gizmo.Guid = nil
                globalEditor.Gizmo.Translate = nil
                globalEditor.Gizmo.Rotate = nil
                globalEditor.Gizmo.Scale = nil
            end)
        end
        globalEditor.Gizmo:DeleteItem()
        globalEditor.Target = nil
    end)
end

function TransformToolbar:SetupBoxSelect()
    local boxSelectStart = nil
    local boxSelectEnd = nil
    local boxSelectTimer = nil
    local boxSelectWindow = Ext.IMGUI.NewWindow("BoxSelect##" .. tostring(self))
    boxSelectWindow.Visible = false

    local function collectAABBCorners(aabb)
        local min = aabb.Min
        local max = aabb.Max
        return {
            Vec3.new(min[1], min[2], min[3]),
            Vec3.new(max[1], min[2], min[3]),
            Vec3.new(min[1], max[2], min[3]),
            Vec3.new(max[1], max[2], min[3]),
            Vec3.new(min[1], min[2], max[3]),
            Vec3.new(max[1], min[2], max[3]),
            Vec3.new(min[1], max[2], max[3]),
            Vec3.new(max[1], max[2], max[3]),
        }
    end

    local function boxSelect()
        if not boxSelectStart or not boxSelectEnd then return end
        local toCheck = {}

        for _,guid in pairs(GetAllPartyMembers()) do
            table.insert(toCheck, guid)
        end
        for guid,_ in pairs(EntityStore:GetAllStored()) do
            table.insert(toCheck, guid)
        end

        local camera = GetCamera()
        if not camera then Warning("No camera found for box select") return end
        local screenWidth, screenHeight = GetScreenSize()
        if not screenWidth or not screenHeight then Warning("No screen size found for box select") return end

        local selected = {}
        for _,guid in ipairs(toCheck) do
            local visual = VisualHelpers.GetEntityVisual(guid)
            local aabb = nil
            local function makeAabb(pos)
                local min = pos - Vec3.new(0.5, 0.5, 0.5)
                local max = pos + Vec3.new(0.5, 0.5, 0.5)
                return { Min = min, Max = max }
            end
            if not visual then
                local pos = Vec3.new{CGetPosition(guid)}
                aabb = makeAabb(pos)
            else
                aabb = visual.WorldBound
            end
            
            if not aabb then
                local pos = Vec3.new{CGetPosition(guid)}
                aabb = makeAabb(pos)
            end


            local vertices = collectAABBCorners(aabb)
            local inside = false
            for _,v in ipairs(vertices) do
                local screenPos = WorldToScreenPoint(v, camera, screenWidth, screenHeight)
                if screenPos and IsInRect(screenPos, boxSelectStart, boxSelectEnd) then
                    inside = true
                    break
                end
            end

            if inside then
                selected[guid] = {}
            end
            ::continue::
        end

        if next(selected) then
            if self.MultiSelecting then
                for guid,_ in pairs(selected) do
                    self.Selecting[guid] = {}
                end
            else
                self.Selecting = selected
            end
        else
        end
    end

    local function initBoxSelectWindow()
        boxSelectWindow.Visible = true
        boxSelectWindow:SetSize({0,0})
        boxSelectWindow:SetPos({0,0})
        boxSelectWindow.NoTitleBar = true
        boxSelectWindow.NoResize = true
        boxSelectWindow.NoMove = true
        boxSelectWindow:SetStyle("WindowBorderSize", 3 * SCALE_FACTOR)
        boxSelectWindow:SetStyle("WindowRounding", 0)
        boxSelectWindow:SetColor("Border", HexToRGBA("FF007712"))
        boxSelectWindow:SetColor("WindowBg", HexToRGBA("12121212"))
    end

    self.KeybindModule:RegisterEvent("BoxSelect", function (e)
        if e.Repeat then return end

        if e.Event == "KeyDown" then
            if boxSelectTimer then return end
            boxSelectStart = Vec2.new(GetCursorPos())
            boxSelectEnd = nil
            initBoxSelectWindow()
            boxSelectTimer = Timer:EveryFrame(function()
                boxSelectEnd = Vec2.new(GetCursorPos())
                if not boxSelectStart or not boxSelectEnd then return end
                local left = math.min(boxSelectStart[1], boxSelectEnd[1])
                local top = math.min(boxSelectStart[2], boxSelectEnd[2])
                local width = math.abs(boxSelectEnd[1] - boxSelectStart[1])
                local height = math.abs(boxSelectEnd[2] - boxSelectStart[2])
                boxSelectWindow:SetPos({left, top})
                -- imgui window will block mouse so we need to shrink it a bit
                boxSelectWindow:SetSize({width - 10 , height - 10})
                --boxSelect()
            end)
        else
            boxSelect()
            if boxSelectTimer then
                Timer:Cancel(boxSelectTimer)
                boxSelectTimer = nil
            end
            if boxSelectWindow then
                boxSelectWindow.Visible = false
                boxSelectWindow:SetSize({0,0})
                boxSelectWindow:SetPos({-1,-1})
            end
            boxSelectStart = nil
            boxSelectEnd = nil

            local proxies = {}
            for selGuid,_ in pairs(self.Selecting) do
                if CIsCharacter(selGuid) and self.Ignore["Character"] then
                    goto continue
                end

                table.insert(proxies, MovableProxy.CreateByGuid(selGuid))
                ::continue::
            end

            RB_GLOBALS.TransformEditor:Select(proxies)

        end
    end)
end

function TransformToolbar:Render()

    self:RenderTopBar()
    self:RenderConfigMenu()
end

function TransformToolbar:RenderTopBar()
    local panel = RegisterWindow("generic", "Transform ToolBar", "ToolBar", self)
    self.TopToolBar = panel

    panel.OnClose = function()
        RB_GLOBALS.TransformEditor:Clear()
        self.Selecting = {}
        self.KeybindConfigWindow.Open = false
        self.BindManagerWindow.Open = false
        self:ClearSubscriptions()
    end

    local screenWidth, screenHeight = GetScreenSize()
    panel:SetSize({screenWidth * 0.6, 80 * SCALE_FACTOR})
    panel:SetPos({screenWidth * 0.2, 0})

    panel.NoResize = true
    panel.NoMove = true
    panel.NoTitleBar = true

    local topAlignedTable = StyleHelpers.AddCenterAlignTable(panel, "TopBar")
    topAlignedTable.ColumnDefs[3] = { WidthFixed = true }

    local row = topAlignedTable:AddRow()
    local leftCell = row:AddCell()
    local centerCell = row:AddCell()
    local rightCell = row:AddCell()

    local closeButton = rightCell:AddImageButton("CloseTransformToolbar", RB_ICONS.X_Square, IMAGESIZE.ROW)
    closeButton.OnClick = function()
        self:Toggle()
    end
    closeButton.Tint = {1, 1, 1, 0.8}
    closeButton:SetColor("Button", HexToRGBA("C24B0000"))
    closeButton:SetColor("ButtonHovered", HexToRGBA("96920000"))
    closeButton:SetColor("ButtonActive", HexToRGBA("C24B0000"))

    local openKeybindConfig = leftCell:AddButton("Configs")
    openKeybindConfig.OnClick = function()
        if self.KeybindConfigWindow then
            self.KeybindConfigWindow.Open = true
        end
    end

    local operatorInput = leftCell:AddInputText("Numeric Input")
    operatorInput.ReadOnly = true
    operatorInput.Disabled = true
    operatorInput.SameLine = true
    operatorInput.IDContext = "TransformOperatorInput"
    operatorInput.Hint = GetLoca("Input any number key when dragging gizmo to start")
    local inputTooltip = operatorInput:Tooltip()
    inputTooltip:AddSeparatorText("Numeric Input"):SetStyle("SeparatorTextAlign", 0.5, 0)
    inputTooltip:AddBulletText("G/R/S: ") inputTooltip:AddText("Switch to Move/Rotate/Scale mode")
    inputTooltip:AddBulletText("X/Y/Z: ") inputTooltip:AddText("Constrain to X/Y/Z axis")
    inputTooltip:AddBulletText("Shift + '-' :") inputTooltip:AddText("Toggle negative number input")
    inputTooltip:AddBulletText("F1/F2/F3/F4 :") inputTooltip:AddText("Switch to Global/Local/View/Parent space")
    inputTooltip:AddBulletText("Enter | LMB :") inputTooltip:AddText("Confirm the operation")
    inputTooltip:AddBulletText("Esc | RMB :") inputTooltip:AddText("Cancel the operation")

    local notice = inputTooltip:AddText("Note: Scale only supports Local space.")
    notice.Font = "Tiny"
    notice:SetColor("Text", HexToRGBA("C4B5B5B5"))

    self.OperatorInput = operatorInput

    local spaceCombo = centerCell:AddCombo("Orientation")
    spaceCombo.ItemWidth = 300 * SCALE_FACTOR
    local indexToMode = {
        "World",
        "Local",
        "View",
        "Parent",
        "Cursor",
    }
    local localizedMode = {
        GetLoca("Global"),
        GetLoca("Local"),
        GetLoca("View"),
        GetLoca("Parent"),
        GetLoca("3D Cursor"),
    }
    centerCell:AddDummy(30 * SCALE_FACTOR, 1).SameLine = true
    local pivotCombo = centerCell:AddCombo("Pivot")
    pivotCombo.ItemWidth = 300 * SCALE_FACTOR
    local indexToPivot = {
        "Individual",
        "Median",
        "Cursor",
        --"Active",
    }
    local localizedPivot = {
        GetLoca("Individual Origins"),
        GetLoca("Median Point"),
        GetLoca("3D Cursor"),
        --GetLoca("Active Element"),
    }
    pivotCombo.Options = localizedPivot
    pivotCombo.SelectedIndex = table.find(indexToPivot, RB_GLOBALS.TransformEditor.PivotMode) - 1
    pivotCombo.SameLine = true
    pivotCombo.OnChange = function (e)
        local mode = indexToPivot[e.SelectedIndex + 1]
        RB_GLOBALS.TransformEditor:SetPivotMode(mode)
    end
    self.pivotCombo = pivotCombo

    spaceCombo.Options = localizedMode
    spaceCombo.SelectedIndex = table.find(indexToMode, RB_GLOBALS.TransformEditor.Space) - 1
    spaceCombo.OnChange = function (e)
        local mode = indexToMode[e.SelectedIndex + 1]
        RB_GLOBALS.TransformEditor:SetSpace(mode)
    end
    self.spaceCombo = spaceCombo
    self.GetCurrentSpace = function()
        return indexToMode[spaceCombo.SelectedIndex + 1]
    end
end

function TransformToolbar:RenderConfigMenu()
    local panel = RegisterWindow("generic", "Key Bind", "Menu", self, {0, 0}, {0, 0})
    self.KeybindConfigWindow = panel

    panel.Open = false

    panel.AlwaysAutoResize = true
    panel.Closeable = true
    panel.NoTitleBar = true

    local closeSel = panel:AddSelectable("Transform Tool Configs")
    closeSel.Selected = true
    closeSel:SetColor("HeaderHovered", HexToRGBA("96920000"))
    closeSel:SetColor("Header", HexToRGBA("C24B0000"))
    closeSel.OnClick = function()
        panel.Open = false
        closeSel.Selected = true
    end

    local ignoreScenerySel = panel:AddCheckbox("Ignore Scenery When Selecting")
    ignoreScenerySel.Checked = self.Ignore["Scenery"] or false
    ignoreScenerySel.OnChange = function (e)
        self.Ignore["Scenery"] = e.Checked
    end

    local ignoreCharacterSel = panel:AddCheckbox("Ignore Characters When Selecting")
    ignoreCharacterSel.Checked = self.Ignore["Character"] or false
    ignoreCharacterSel.OnChange = function (e)
        self.Ignore["Character"] = e.Checked
    end

    self:RenderOtherConfigOptions(panel)
end

--- @param panel ExtuiWindow
function TransformToolbar:RenderOtherConfigOptions(panel)
    local sep = panel:AddSeparatorText("Other Options")

    local leftA = panel:AddTable("LeftAlign", 2)
    leftA.ColumnDefs[1] = { WidthFixed = true }
    leftA.ColumnDefs[2] = { WidthStretch = true }

    local row1 = leftA:AddRow()
    local row2 = leftA:AddRow()

    row1:AddCell():AddText("Move Step")
    local stepSlider = StyleHelpers.AddSliderWithStep(row1:AddCell(), "Step", 1, 0.1, 3, 0.05)
    stepSlider.OnChange = function (e)
        if not RB_GLOBALS.TransformEditor.Gizmo then return end
        RB_GLOBALS.TransformEditor.Gizmo.Step = e.Value[1]
    end

    row2:AddCell():AddText("Gizmo Size")
    local gizmoSizeSlider = StyleHelpers.AddSliderWithStep(row2:AddCell(), "Gizmo Size", 0.1, 0.01, 2, 0.01)
    gizmoSizeSlider.OnChange = function (e)
        local editor = RB_GLOBALS.TransformEditor
        if editor.Gizmo then
            editor.Gizmo:SetScale(e.Value[1])
        end
    end
end

function TransformToolbar:SetupOperator(mode, space, axis)
    if not RB_GLOBALS.TransformEditor.Target or #RB_GLOBALS.TransformEditor.Target == 0 or self.isInputing then return end
    RB_GLOBALS.TransformEditor.Disabled = true
    RB_GLOBALS.TransformEditor:HideAndDisableGizmo()
    local targets = RB_GLOBALS.TransformEditor.Target --[[@as RB_MovableProxy[] ]]
    self.isInputing = true
    if not self.Operator then
        if mode == "Scale" then axis = {X = true, Y = true, Z = true} end
        self.Operator = TransformOperator.new(targets, space, mode, axis)
        self.Operator.Cursor = self.Cursor
    end
    
    local inputSub = SubscribeKeyAndMouse(function (e)
        local isDone = false
        if e.Key == "ESCAPE" or e.Key == "RMB" then
            self.Operator:Cancel()
            isDone = true
        elseif e.Key == "RETURN" or e.Key == "LMB" or e.Key == "KP_ENTER" then
            self.Operator:Confirm()
            isDone = true
        else
            self.Operator:ParseInput(e)
        end

        if isDone then
            self.isInputing = false
            self.Operator = nil
            self.OperatorInput.Text = ""
            self.OperatorInput.Hint = GetLoca("Input any number key when dragging gizmo to start")
            RB_GLOBALS.TransformEditor:ShowAndEnableGizmo()
            RB_GLOBALS.TransformEditor.Disabled = false
            return UNSUBSCRIBE_SYMBOL
        end

        if self.OperatorInput then
            self.OperatorInput.Text = tostring(self.Operator)
        end
    end)
end

function TransformToolbar:CreateBindPopup(guid)
    self.BindPopupCache = self.BindPopupCache or {}
    local notif = self.BindPopupCache[guid] or Notification.new(GetName(guid))
    if not self.BindPopupCache[guid] then
        self.BindPopupCache[guid] = notif
    end
    local screenWidth, screenHeight = GetScreenSize()
    local camera = GetCamera()
    local pivot = WorldToScreenPoint({CGetPosition(guid)}, camera, screenWidth, screenHeight)
    if not pivot then pivot = {screenWidth / 2, screenHeight / 2} end
    pivot = { pivot[1] / screenWidth, pivot[2] / screenHeight }
    notif.NoAnimation = true
    notif.AutoFadeOut = false
    notif.Pivot = pivot
    notif.Moveable = true

    ---@param panel ExtuiWindow
    local function render(panel)
        local dismissBtn = panel:AddButton("X")
        dismissBtn.OnClick = function()
            notif:Dismiss()
        end
        dismissBtn.SameLine = true

        local tab = panel:AddTable("BindPopup", 2)
        tab.ColumnDefs[1] = { WidthFixed = true }
        tab.ColumnDefs[2] = { WidthStretch = true }
        local row1 = tab:AddRow()
        local left = row1:AddCell()

        left:AddText("Bind To:")

        local info = EntityStore:GetBindInfo(guid)
        local curParent = info and info.BindParent or nil
        local image = left:AddImage(GetIcon(curParent), IMAGESIZE.SMALL )
        image.SameLine = true

        local right = row1:AddCell()
        local nearByCombo = NearbyCombo.new(right)
        local excludeEntites = {
            [guid] = true,
        }
        nearByCombo.ExcludeEntries = excludeEntites
        nearByCombo:SetSelected(curParent)
        nearByCombo.OnChange = function (sel, selectedGuid, displayName)
            if not selectedGuid or selectedGuid == "" then return end
            if selectedGuid == curParent then return end
            Commands.Bind({guid}, selectedGuid)
            image:Destroy()
            image = left:AddImage(GetIcon(selectedGuid), IMAGESIZE.SMALL )
            image.SameLine = true
        end

        local snapButton = right:AddButton("Snap")
        snapButton.SameLine = true
        snapButton.OnClick = function()
            Commands.SnapCommand({guid}, false, true)
        end
        snapButton.OnRightClick = function()
            Commands.SnapCommand({guid}, true, false)
        end
        snapButton:Tooltip():AddText("Left Click: Snap Position\nRight Click: Snap Rotation")


        local unbindButton = panel:AddButton("Unbind")
        unbindButton.OnClick = function()
            Commands.Unbind({guid})
            nearByCombo.SelectedIndex = -1
            image:Destroy()
            image = left:AddImage(GetIcon(), IMAGESIZE.SMALL)
            image.SameLine = true
        end

        local function addBindCheckbox(panel, label, info, field, valueToChecked, checkedToValue)
            local checked = valueToChecked(info[field])
            local checkbox = panel:AddCheckbox(label, checked)
            checkbox.OnChange = function(e)
                local newValue = checkedToValue(e.Checked)
                local attr = { [field] = newValue }
                NetChannel.Bind:SendToServer({ Type = "SetAttributes", Guid = {guid}, Attributes = attr })
                info[field] = newValue
                HistoryManager:PushCommand({
                    Undo = function()
                        local undoValue = checkedToValue(not e.Checked)
                        NetChannel.Bind:SendToServer({ Type = "SetAttributes", Guid = {guid}, Attributes = { [field] = undoValue } })
                        info[field] = undoValue
                    end,
                    Redo = function()
                        NetChannel.Bind:SendToServer({ Type = "SetAttributes", Guid = {guid}, Attributes = attr })
                        info[field] = newValue
                    end
                })
            end
            checkbox.SameLine = true
            return checkbox
        end

        local checkCheck = function(v) return v end

        local lookAtCheck = addBindCheckbox(panel, "Keep Looking At", info, "KeepLookingAt", checkCheck, checkCheck)
        local followCheck = addBindCheckbox(panel, "Follow Parent", info, "FollowParent", checkCheck, checkCheck)

        local markerSelector = panel:AddPopup("Select Marker")

        local selectMarkerTable = markerSelector:AddTable("MarkerSelect", 1)
        selectMarkerTable.BordersInnerH = true
        local markerRow = selectMarkerTable:AddRow()

        local makerMarker = function(mType)
            Commands.AddMarker(guid, mType)
        end
        local allType = {
            "SpotLight",
            "PointLight",
        }

        for _,mType in ipairs(allType) do
            local markerBtn = markerRow:AddCell():AddButton(mType)
            markerBtn.OnClick = function()
                makerMarker(mType)
            end
            markerBtn.SameLine = true
        end
        
        local addMarkerBtn = panel:AddButton("Add Marker")
        addMarkerBtn.OnClick = function()
            markerSelector:Open()
        end

        local listener
        listener = EntityStore:SubscribeToBindChanges(guid, function (data)
            local ok, err = pcall(function() return lookAtCheck.Checked, followCheck.Checked end)
            if not ok then if listener then listener:Unsubscribe() listener = nil end return end
            local d = data
            info = d
            lookAtCheck.Checked = d.KeepLookingAt == true or false
            followCheck.Checked = d.FollowParent == true or false
            nearByCombo:SetSelected(d.BindParent)
            if d.BindParent then
                image:Destroy()
                image = left:AddImage(GetIcon(d.BindParent), IMAGESIZE.SMALL )
                image.SameLine = true
            else
                image:Destroy()
                image = left:AddImage(GetIcon(), IMAGESIZE.SMALL )
                image.SameLine = true
            end
        end)

        notif.OnDismiss = function()
            if listener then
                listener:Unsubscribe()
                listener = nil
            end
        end
    end

    notif:Show(notif.name, render)


end

function TransformToolbar:CreateNearbyPopup()
    local nearbyNotif = self.NearbyNotif or Notification.new("Nearby Entities")
    self.NearbyNotif = nearbyNotif

    nearbyNotif.InstantDismiss = true
    nearbyNotif.NoAnimation = true
    nearbyNotif.AutoFadeOut = false
    nearbyNotif.Pivot = Vec2.new(GetCursorPos()) / Vec2.new(GetScreenSize())
    nearbyNotif.Moveable = true

    UpdateNearbyMap()

    local tempSubs = {}
    ---@param panel ExtuiWindow
    local function render(panel)
        local contextPopup = panel:AddPopup("NearbyEntitiesContextMenu")
        local contextMenu = StyleHelpers.AddContextMenu(contextPopup)
        local localNearbyCombo = NearbyCombo.new(panel, true)
        localNearbyCombo:RenderSelectionTable(panel)
        local selected = nil
        localNearbyCombo.ExcludeCamera = true

        --- @type RB_ContextItem[]
        local contextItems = {
            {
                Label = "Open Entity Tab",
                OnClick = function (selectable)
                    if not selected or selected == "" then return end
                    local entityTab = EntityTab.new(selected, nil, nil, nil)
                    entityTab:Render()
                end
            },
            {
                Label = "Open Visual Tab",
                OnClick = function (selectable)
                    if not selected or selected == "" then return end
                    local visualTab = VisualTab.new(selected, GetName(selected), nil, nil)
                    visualTab.isAttach = false
                    visualTab:Refresh()
                end
            },
            {
                Label = "Set Target",
                OnClick = function (selectable)
                    if not selected or selected == "" then return end
                    local proxy = MovableProxy.CreateByGuid(selected)
                    RB_GLOBALS.TransformEditor:Select({proxy})
                end,
                Hint = "S",
                HotKey = {
                    Key = "S"
                }
            },
            {
                Label = "Add to Target",
                OnClick = function (selectable)
                    if not selected or selected == "" then return end
                    local proxy = MovableProxy.CreateByGuid(selected)
                    if not proxy then return end
                    RB_GLOBALS.TransformEditor:AddTarget(proxy)
                end,
                Hint = "A",
                HotKey = {
                    Key = "A"
                }
            }
        }

        for _,item in ipairs(contextItems) do
            local sle = contextMenu:AddItemPacked(item)

            if item.HotKey then
                tempSubs[item.Label] = SubscribeKeyAndMouse(function (e)
                    if e.Event ~= "KeyDown" then return end
                    if not selected or selected == "" then return end
                    if localNearbyCombo.HoveringKey then
                        selected = localNearbyCombo.HoveringKey
                    end
                    item.OnClick(sle)
                end, item.HotKey)
            end

        end

        localNearbyCombo.OnChange = function (sel, selectedGuid, displayName)
            selected = selectedGuid
            contextPopup:Open()
        end

        local titleText = nearbyNotif.titleText
        nearbyNotif.titleText.OnHoverEnter = function()
            titleText:SetColor("Text", HexToRGBA("FF515151"))
        end
        nearbyNotif.titleText.OnHoverLeave = function()
            titleText:SetColor("Text", HexToRGBA("FFFFFFFF"))
        end
        nearbyNotif.titleText.OnClick = function()
            nearbyNotif:Dismiss()
        end
        nearbyNotif.titleText:SetColor("Text", HexToRGBA("FFFFFFFF"))
    end

    nearbyNotif:Show(nearbyNotif.name, render)
    nearbyNotif.OnDismiss = function()
        for _,sub in pairs(tempSubs) do
            sub:Unsubscribe()
        end
        tempSubs = {}
    end
end

function TransformToolbar:CreateCursor(pos)
    if self.Cursor and EntityExists(self.Cursor) or (self.creatingCursor) then
        return
    end

    self.creatingCursor = true
        
    pos = ScreenToWorldRay():At(10)
    local hostPosition = Vec3.new(pos)
    local hostRotation = Quat.new(GetCameraRotation())

    NetChannel.Visualize:RequestToServer({
        Type = "Cursor",
        Position = hostPosition,
        Rotation = hostRotation,
        Duration = -1,
    }, function (response)
        for _,viz in pairs(response or {}) do
            self.Cursor = viz
            RB_GLOBALS.TransformEditor.Cursor = self.Cursor
        end
        self.creatingCursor = false
    end)

    self.CursorTimer = Timer:EveryFrame(function (timerID)
        RB_GLOBALS.TransformEditor.Gizmo.Visualizer:Visualize3DCursor(self.Cursor)
    end)
end

function TransformToolbar:MoveCursor()
    if not self.Cursor or not EntityExists(self.Cursor) then
        self:CreateCursor()
        return
    end

    local pos = ScreenToWorldRay():At(10)
    local rot = Quat.new(GetCameraRotation())

    NetChannel.SetTransform:RequestToServer({ Guid = self.Cursor, Transforms = {
        [self.Cursor] = {
            Translate = pos,
            RotationQuat = rot,
        }
    } }, function()
    end)

    NetChannel.SetAttributes:SendToServer({ Guid = self.Cursor, Attributes = {
        Visible = true,
    } })
end

function TransformToolbar:Add()
    local menu = TransformToolbar.new()
    menu:Render()
    return menu
end

function TransformToolbar:Toggle()
    if not self.TopToolBar then return end

    self.TopToolBar.Open = not self.TopToolBar.Open
    local open = self.TopToolBar.Open
    if not open then
        RB_GLOBALS.TransformEditor:HideAndDisableGizmo()
    else
        RB_GLOBALS.TransformEditor:ShowAndEnableGizmo()
    end
end