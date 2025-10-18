--- @class TransformToolbar
--- @field parent ExtuiTabBar
--- @field EventsToKeybinds table<string, SDLScanCode|string>
--- @field new fun(): TransformToolbar
TransformToolbar = _Class("TransformToolbar")

function TransformToolbar:__init()
    self.Subscriptions = {}
    self.Selecting = {}
    self.isInputing = false
    self:RegisterKeyInputEvents()
end

function TransformToolbar:RegisterKeyInputEvents()
    if self.Registered then return end
    self.Registered = true

    local function singleSelect()
        local guid = GetPickingGuid()
        if guid and guid ~= "" then
            if self.MultiSelecting then
                self.Selecting[guid] = {}
                TransformEditor:Select(self.Selecting)
            else
                TransformEditor:Select(guid)
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

    buMod:AddModuleCondition(restrainOpening)
    ttMod:AddModuleCondition(restrainOpening)

    ttMod:AddModuleCondition(restrainInputing)
    buMod:AddModuleCondition(restrainInputing)

    self.Subscriptions["NumericInput"] = SubscribeKeyInput({}, function (e)
        if not restrainInputing(e) then return end
        if not restrainOpening(e) then return end
        if e.Repeat then return end
        if e.Event ~= "KeyDown" then return end
        if not TransformEditor.Gizmo then return end
        if not TransformEditor.Gizmo.IsDragging then return end
        if not TransformEditor.Target or #TransformEditor.Target == 0 then return end

        if tonumber(KeybindHelpers.ParseInputToCharInput(e)) then
            local selectedAxis = TransformEditor.Gizmo and TransformEditor.Gizmo.SelectedAxis
            TransformEditor.Gizmo:CancelDragging()

            self:SetupOperator(TransformEditor.Gizmo.Mode, self:GetCurrentSpace(), selectedAxis)
        end
    end)

    ttMod:RegisterEvent("MultiSelect", function (e)
        if e.Event == "KeyDown" then
            self.MultiSelecting = true
        elseif e.Event == "KeyUp" then
            TransformEditor:Select(self.Selecting)
            self.MultiSelecting = false
            self.Selecting = {}
        end
    end)

    ttMod:RegisterEvent("Select", function (e)
        if e.Event ~= "KeyDown" or e.Repeat then return end
        singleSelect()
    end)


    ttMod:RegisterEvent("ClearSelection", function (e)
        if e.Event ~= "KeyDown" then return end
        TransformEditor:Clear()
        self.Selecting = {}
    end)

    ttMod:RegisterEvent("MoveToCursor", function (e)
        if e.Event ~= "KeyDown" then return end

        local targets = NormalizeGuidList(TransformEditor.Target)
        local pos, rot = GetPickingHitPosAndRot()

        Commands.SetTransformCommand(targets, {Translate = pos, RotationQuat = rot})
    end)

    ttMod:RegisterEvent("Duplicate", function (e)
        if e.Event ~= "KeyDown" then return end

        self:DuplicateSelection()
    end)

    ttMod:RegisterEvent("OpenVisualTab", function (e)
        if e.Event ~= "KeyDown" then return end
        local pick = GetPickingGuid()
        if not pick or pick == "" then return end
        if CIsCharacter(pick) then
            local visualTab = VisualTab.new(pick, GetName(pick), nil, nil)
            visualTab:Render()
            return
        end

        local success = RBMenu.entityMenu:FocusEntityVisualTab(pick)
    end)

    buMod:RegisterEvent("BindTo", function (e)
        if e.Event ~= "KeyDown" then return end
        if not TransformEditor.Target or #TransformEditor.Target == 0 then return end
        local parent = GetPickingGuid()
        if not parent or parent == "" then
            Debug("No valid target to bind to")
            return
        end
        local targets = NormalizeGuidList(TransformEditor.Target)
        Commands.BindCommand(targets, parent)
    end)

    buMod:RegisterEvent("Unbind", function (e)
        if e.Event ~= "KeyDown" then return end
        if not TransformEditor.Target or #TransformEditor.Target == 0 then return end

        local targets = NormalizeGuidList(TransformEditor.Target)

        Commands.UnbindCommand(targets)
    end)

    buMod:RegisterEvent("Snap", function (e)
        if e.Event ~= "KeyDown" then return end
        if not TransformEditor.Target or #TransformEditor.Target == 0 then return end

        local targets = NormalizeGuidList(TransformEditor.Target)
        Commands.SnapCommand(targets)
    end)

    buMod:RegisterEvent("BindPopup", function (e)
        if e.Event ~= "KeyDown" then return end
        local targets = NormalizeGuidList(TransformEditor.Target)
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
            if not TransformEditor.Target or #TransformEditor.Target == 0 then return end
            local targets = NormalizeGuidList(TransformEditor.Target)
            local paramsOn = { Guid = targets , Attributes = {} }
            local paramsOff = { Guid = targets , Attributes = {} }
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
        for guid,_ in pairs(EntityStore:GetAll()) do
            table.insert(toCheck, guid)
        end

        local camera = GetCamera()
        if not camera then Warning("No camera found for box select") return end
        local screenWidth, screenHeight = GetScreenSize()
        if not screenWidth or not screenHeight then Warning("No screen size found for box select") return end

        local selected = {}
        for _,guid in ipairs(toCheck) do
            local entity = UuidToHandle(guid)
            if not entity then goto continue end

            if entity.PartyMember then
                local dummy = GetDummyByUuid(guid)
                if dummy then
                    entity = dummy
                end
            end

            local visual = VisualHelpers.GetEntityVisual(entity)
            if not visual then goto continue end

            local aabb = visual.WorldBound
            if not aabb then goto continue end

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
            boxSelectTimer = Timer:Every(10, function()
                boxSelectEnd = Vec2.new(GetCursorPos())
                if not boxSelectStart or not boxSelectEnd then return end
                local left = math.min(boxSelectStart[1], boxSelectEnd[1])
                local top = math.min(boxSelectStart[2], boxSelectEnd[2])
                local width = math.abs(boxSelectEnd[1] - boxSelectStart[1])
                local height = math.abs(boxSelectEnd[2] - boxSelectStart[2])
                boxSelectWindow:SetPos({left, top})
                -- imgui window will block mouse input so we need to shrink it a bit
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

            TransformEditor:Select(self.Selecting)

            --for guid,_ in pairs(self.Selecting) do
            --    VisualHelpers.VisualizeAABB(UuidToHandle(guid))
            --end
        end
    end)
end

function TransformToolbar:DuplicateSelection()
    local toPost = {
        Guid = {},
    }
    local targets = NormalizeGuidList(TransformEditor.Target)
    Commands.DuplicateCommand(targets)
end

function TransformToolbar:Render()

    self:RenderTopBar()
    self:RenderConfigMenu()
end

function TransformToolbar:RenderTopBar()
    local panel = RegisterWindow("generic", "Transform ToolBar", "ToolBar", self)
    self.TopToolBar = panel

    panel.OnClose = function()
        TransformEditor:Clear()
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

    local table = AddMiddleAlignTable(panel, "TopBar")
    table.ColumnDefs[3] = { WidthFixed = true }

    local row = table:AddRow()
    local leftCell = row:AddCell()
    local centerCell = row:AddCell()
    local rightCell = row:AddCell()

    local closeButton = rightCell:AddButton("X")
    closeButton.OnClick = function()
       panel.Open = false
    end

    local openKeybindConfig = leftCell:AddButton("Configs")
    openKeybindConfig.OnClick = function()
        if self.KeybindConfigWindow then
            self.KeybindConfigWindow.Open = true
        end
    end

    local operatorInput = leftCell:AddInputText("Operator Input")
    operatorInput.ReadOnly = true
    operatorInput.Disabled = true
    operatorInput.SameLine = true
    operatorInput.IDContext = "TransformOperatorInput"
    operatorInput.Hint = GetLoca("Input any number key when dragging gizmo to start transform operator")
    local inputTooltip = operatorInput:Tooltip()
    inputTooltip:AddSeparatorText("Transform Operator Input"):SetStyle("SeparatorTextAlign", 0.5, 0)
    inputTooltip:AddText("You can input commands like 'GX1', just like in blender.")
    inputTooltip:AddBulletText("G/R/S: ") inputTooltip:AddText("Switch to Move/Rotate/Scale mode")
    inputTooltip:AddBulletText("X/Y/Z: ") inputTooltip:AddText("Constrain to X/Y/Z axis")
    inputTooltip:AddBulletText("Shift + '-' :") inputTooltip:AddText("Toggle negative number input")
    inputTooltip:AddBulletText("F1/F2/F3/F4 :") inputTooltip:AddText("Switch to Global/Local/View/Parent space")
    inputTooltip:AddBulletText("Supported Operators:") inputTooltip:AddText(" + - * / % ^ ( )")
    inputTooltip:AddBulletText("Enter | LMB :") inputTooltip:AddText("Confirm the operation")
    inputTooltip:AddBulletText("Esc | RMB :") inputTooltip:AddText("Cancel the operation")

    local notice = inputTooltip:AddText("Note: Scale only supports Local space.")
    notice.Font = "Tiny"
    notice:SetColor("Text", HexToRGBA("C4B5B5B5"))


    operatorInput.OnChange = function (input)
        self:SetupOperator()
        local newText = input.Text
        if tonumber(newText) then
            newText = "NUM_" .. newText
        end
        self.Operator:ParseInput({ Key = newText:upper() })
        input.Text = ""
        if self.Operator then
            input.Hint = tostring(self.Operator)
        end
    end
    self.OperatorInput = operatorInput

    local spaceCombo = centerCell:AddCombo("Space")
    spaceCombo.ItemWidth = 300 * SCALE_FACTOR
    local indexToMode = {
        "World",
        "Local",
        "View",
        "Parent",
    }
    local localizedMode = {
        GetLoca("Global"),
        GetLoca("Local"),
        GetLoca("View"),
        GetLoca("Parent"),
    }

    spaceCombo.Options = localizedMode
    spaceCombo.SelectedIndex = 0
    spaceCombo.OnChange = function (e)
        local mode = indexToMode[e.SelectedIndex + 1]
        TransformEditor:SetSpace(mode)
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
    local stepSlider = AddSliderWithStep(row1:AddCell(), "Step", 1, 0.1, 3, 0.05)
    stepSlider.UserData.StepInput.Visible = false
    stepSlider.OnChange = function (e)
        TransformEditor.Step = e.Value[1]
    end

    row2:AddCell():AddText("Gizmo Size")
    local gizmoSizeSlider = AddSliderWithStep(row2:AddCell(), "Gizmo Size", 0.1, 0.01, 2, 0.01)
    gizmoSizeSlider.UserData.StepInput.Visible = false
    gizmoSizeSlider.OnChange = function (e)
        local editor = TransformEditor
        if editor.Gizmo then
            editor.Gizmo:SetScale(e.Value[1])
        end
    end

    local tips = panel:AddText("Tips: Use Alt + Mode Key to reset the transform.")
    tips:SetColor("Text", HexToRGBA("FFFFAA00"))
end

function TransformToolbar:SetupOperator(mode, space, axis)
    if not TransformEditor.Target or #TransformEditor.Target == 0 or self.isInputing then return end
    TransformEditor.Disabled = true
    TransformEditor:HideAndDisableGizmo()
    local targets = NormalizeGuidList(TransformEditor.Target)
    self.isInputing = true
    if not self.Operator then
        if mode == "Scale" then axis = {X = true, Y = true, Z = true} end
        self.Operator = TransformOperator.new(targets, space, mode, axis)
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
            self.OperatorInput.Hint = GetLoca("Input any number key when dragging gizmo to start transform operator")
            TransformEditor:ShowAndEnableGizmo()
            TransformEditor.Disabled = false
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

        local table = panel:AddTable("BindPopup", 2)
        table.ColumnDefs[1] = { WidthFixed = true }
        table.ColumnDefs[2] = { WidthStretch = true }
        local row1 = table:AddRow()
        local left = row1:AddCell()

        left:AddText("Bind To:")

        local info = EntityStore:GetBindInfo(guid)
        local curParent = info and info.BindParent or nil
        local image = left:AddImage(GetIcon(curParent), IMAGESIZE.SMALL )
        image.SameLine = true

        local right = row1:AddCell()
        local nearByCombo = NearbyCombo.new(right)
        nearByCombo.ExcludeEntries = {guid}

        nearByCombo:SetSelected(curParent)
        nearByCombo.OnChange = function (sel, selectedGuid, displayName)
            if not selectedGuid or selectedGuid == "" then return end
            if selectedGuid == curParent then return end
            Commands.BindCommand({guid}, selectedGuid)
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
            Commands.UnbindCommand({guid})
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
                NetChannel.Bind:SendToServer({ Guid = {guid}, Attributes = attr })
                info[field] = newValue
                HistoryManager:PushCommand({
                    Undo = function()
                        local undoValue = checkedToValue(not e.Checked)
                        NetChannel.Bind:SendToServer({ Guid = {guid}, Attributes = { [field] = undoValue } })
                        info[field] = undoValue
                    end,
                    Redo = function()
                        NetChannel.Bind:SendToServer({ Guid = {guid}, Attributes = attr })
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

        local listener = ClientSubscribe(NetChannel.BindProps, function (data)
            local ok, err = pcall(function() return lookAtCheck.Checked, followCheck.Checked end)
            if not ok then return UNSUBSCRIBE_SYMBOL end
            for _,d in ipairs(data.BindInfos) do
                if d.Guid == guid then
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
                    break
                end
            end
        end)

        notif.OnDismiss = function()
            listener:Unsubscribe()
        end
    end

    notif:Show(notif.name, render)


end

function TransformToolbar:Add()
    local menu = TransformToolbar.new()
    menu:Render()
    return menu
end

function TransformToolbar:Toggle()
    if not self.TopToolBar then return end

    self.TopToolBar.Open = not self.TopToolBar.Open
end