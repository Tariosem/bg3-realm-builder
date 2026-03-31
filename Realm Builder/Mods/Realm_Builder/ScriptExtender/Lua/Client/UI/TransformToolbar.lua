--- @class TransformToolbar
--- @field parent ExtuiTabBar
--- @field EventsToKeybinds table<string, SDLScanCode|string>
--- @field new fun(): TransformToolbar
TransformToolbar = _Class("TransformToolbar")

local INIT_WINDOW_POS = 0.1
local cursorMaxDistance = 100

--- @param entity EntityHandle
local function registerScenery(entity)
    if not entity or not entity.Scenery then
        return
    end

    local guid = entity.Scenery.Uuid
    
    if NearbyMap.GetRegisteredScenery(guid) then return end
    NearbyMap.RegisterScenery(entity)
end

function TransformToolbar:__init()
    self.Subscriptions = {}
    self.Selecting = {}
    self.Ignore = {
        Character = false,
        Scenery = false,
    }

    local inputStateLookup = {
        MultiSelecting = "Ctrl",
    }
    local ref = InputEvents.GetGlobalInputStatesRef()
    self.InputStates = setmetatable({}, {
        __index = function(t, k)
            local stateKey = inputStateLookup[k]
            if stateKey and ref[stateKey] ~= nil then
                return ref[stateKey]
            end
            return nil
        end
    })

    self:RegisterKeyInputEvents()

end

function TransformToolbar:RegisterKeyInputEvents()
    if self.Registered then return end
    self.Registered = true

    local function singleSelect()
        local guid = nil
        local entity = PickingUtils.GetPickingEntity()

        if entity and entity.Scenery and not self.Ignore["Scenery"] then
            registerScenery(entity)
        end

        if not guid then 
            guid = PickingUtils.GetPickingGuid()
        end

        if not guid then
            return
        end

        if EntityHelpers.IsCharacter(guid) and self.Ignore["Character"] then
            return
        end

        if guid and guid ~= "" then
            if self.InputStates.MultiSelecting then
                self.Selecting[guid] = {}

                local proxies = {}
                for selGuid, _ in pairs(self.Selecting) do
                    table.insert(proxies, MovableProxy.CreateByGuid(selGuid))
                end

                RB_GLOBALS.TransformEditor:Select(proxies)
            else
                self.Selecting = {}
                RB_GLOBALS.TransformEditor:Select({ MovableProxy.CreateByGuid(guid) })
            end
        else
        end
    end

    local restrainOpening = function(e)
        return self.TopToolBar and self.TopToolBar.Open
    end
    local restrainInCharacterCreation = function(e)
        return not IsInCharacterCreationMirror()
    end

    local restrains = {
        restrainOpening,
        restrainInCharacterCreation,
    }

    local ttMod = KeybindManager:CreateModule("TransformToolbar")
    local buMod = KeybindManager:CreateModule("BindUtility")

    self.KeybindModule = ttMod
    self.BindUtilityModule = buMod
    self:RegisterTransformEditorEvents()

    for _, restrain in ipairs(restrains) do
        ttMod:AddModuleCondition(restrain)
        buMod:AddModuleCondition(restrain)
    end

    local realSelectSub = InputEvents.SubscribeKeyAndMouse(function (e)
        if e.Event ~= "KeyDown" or e.Repeat then return end
        for _, restrain in ipairs(restrains) do
            if not restrain(e) then
                return
            end
        end
        local modEvent = ttMod:GetKeyByEvent("Select")

        if not modEvent then
            return
        end
        if e.Key ~= modEvent.Key then return end

        singleSelect()
    end)

    ttMod:RegisterEvent("Select", function(e)
        --if e.Event ~= "KeyDown" or e.Repeat then return end
        --singleSelect()
    end, "Ignore Modifiers")


    ttMod:RegisterEvent("ClearSelection", function(e)
        if e.Event ~= "KeyDown" then return end
        RB_GLOBALS.TransformEditor:Clear()
        self.Selecting = {}
    end)

    ttMod:RegisterEvent("Duplicate", function(e)
        if e.Event ~= "KeyDown" then return end
        if not RB_GLOBALS.TransformEditor.Target or #RB_GLOBALS.TransformEditor.Target == 0 then return end

        local targets = {}
        for _, proxy in pairs(RB_GLOBALS.TransformEditor.Target) do
            if proxy.Guid then
                table.insert(targets, proxy.Guid)
            end
        end

        Commands.DuplicateCommand(targets)
    end)

    ttMod:RegisterEvent("DeleteSelection", function(e)
        if e.Event ~= "KeyDown" then return end
        if not RB_GLOBALS.TransformEditor.Target or #RB_GLOBALS.TransformEditor.Target == 0 then return end
        local targets = {}
        for _, proxy in pairs(RB_GLOBALS.TransformEditor.Target) do
            if proxy.Guid then
                table.insert(targets, proxy.Guid)
            end
        end
        if #targets == 0 then return end

        Commands.DeleteCommand(targets)
    end)


    ttMod:RegisterEvent("OpenNearbyPopup", function(e)
        if e.Event ~= "KeyDown" then return end
        self:CreateNearbyPopup()
    end, GetLoca("Select entities that are behind others."))

    ttMod:RegisterEvent("Move3DCursor", function(e)
        if e.Event ~= "KeyDown" then return end
        if not self.Cursor then
            self:CreateCursor()
            return
        end
        self:MoveCursor()
    end, GetLoca("Move the 3D cursor to the picking position."))

    ttMod:RegisterEvent("Snap3DCursor", function(e)
        if e.Event ~= "KeyDown" then return end

        local function getCenterOfTargets()
            if not RB_GLOBALS.TransformEditor.Target or #RB_GLOBALS.TransformEditor.Target == 0 then
                return nil
            end

            local center = Vec3.new(0, 0, 0)
            for _, proxy in pairs(RB_GLOBALS.TransformEditor.Target) do
                center = center + proxy:GetWorldTranslate()
            end
            center = center / #RB_GLOBALS.TransformEditor.Target
            return center
        end

        local function setCursorPosition(pos)
            local movable = MovableProxy.CreateByGuid(self.Cursor)
            if not movable then
                Warning("3D Cursor movable not found")
                return
            end
            movable:SetWorldTranslate(pos)
        end

        if not self.Cursor then
            self:CreateCursor(getCenterOfTargets())
            return
        end
        local center = getCenterOfTargets()
        if center then
            setCursorPosition(center)
        end
    end, GetLoca("Snap the 3D cursor to the center of selected objects."))

    ttMod:RegisterEvent("SnapToHover", function(e)
        if e.Event ~= "KeyDown" then return end
        if not RB_GLOBALS.TransformEditor.Target or #RB_GLOBALS.TransformEditor.Target == 0 then return end

        local hovered = PickingUtils.GetPickingGuid()
        if not hovered or hovered == "" then
            Debug("No valid target to snap to")
            return
        end
        local hoveredProxy = MovableProxy.CreateByGuid(hovered)
        if not hoveredProxy then
            Debug("No valid target to snap to")
            return
        end

        local targetTransform = hoveredProxy:GetTransform()

        local targets = {}

        for _, proxy in pairs(RB_GLOBALS.TransformEditor.Target or {}) do
            table.insert(targets, proxy)
        end

        Commands.SnapToTarget(targets, targetTransform)
    end, GetLoca("Snap selected entities to hovered entity"))

    ttMod:RegisterEvent("LookAtCursor", function(e)
        if e.Event ~= "KeyDown" then return end
        if not RB_GLOBALS.TransformEditor.Target or #RB_GLOBALS.TransformEditor.Target == 0 then return end

        local focusPoint = nil

        local getPointFromRay = function()
            local mouseRay = ScreenToWorldRay()
            if not mouseRay then return nil end

            local hit = mouseRay:IntersectCloseat(cursorMaxDistance)
            if not hit then
                return nil
            end
            return hit.Position
        end

        if not self.Cursor then
            focusPoint = getPointFromRay()
        else
            local cursorProxy = MovableProxy.CreateByGuid(self.Cursor)
            if not cursorProxy then
                focusPoint = getPointFromRay()
            else
                focusPoint = cursorProxy:GetWorldTranslate()
            end
        end
        
        if not focusPoint then
            Debug("No valid target to look at")
            return
        end
        local targets = {} --[[@type RB_MovableProxy[] ]]

        for _, proxy in pairs(RB_GLOBALS.TransformEditor.Target or {}) do
            table.insert(targets, proxy)
        end

        local transforms = {}
        for _, proxy in pairs(targets) do
            local startPos = proxy:GetWorldTranslate()
            local dir = (focusPoint - startPos):Normalize()
            local rot = MathUtils.DirectionToQuat(dir, nil, "Z")

            transforms[proxy] = {
                RotationQuat = rot,
            }
        end

        Commands.SetTransformSeparate(targets, transforms)
    end, GetLoca("Rotate selected entities to look at the cursor."))

    ttMod:RegisterEvent("MoveToCursor", function(e)
        if e.Event ~= "KeyDown" then return end

        local targets = RB_GLOBALS.TransformEditor.Target or {}
        if #targets == 0 then return end

        local pos, rot = nil, nil

        if not self.Cursor or not EntityHelpers.EntityExists(self.Cursor) then
            local ray = ScreenToWorldRay()
            if not ray then
                Debug("Can't get picking ray")
                return
            end
            local hit = ray:IntersectCloseat()
            if not hit then
                Debug("No valid position to move to")
                return
            end
            pos = hit.Position
            local normal = hit.Normal
            if not pos or not normal then
                Debug("No valid position to move to")
                return
            end
            rot = MathUtils.DirectionToQuat(normal, nil, "Y")
        else
            local cursorProxy = MovableProxy.CreateByGuid(self.Cursor)
            if not cursorProxy then
                Debug("3D Cursor movable not found")
                return
            end
            pos = cursorProxy:GetWorldTranslate()
            rot = cursorProxy:GetWorldRotationQuat()
        end
        local minY = math.huge
        local centerXZ = Vec3.new(0, 0, 0)

        for _, proxy in ipairs(targets) do
            local p = proxy:GetWorldTranslate()
            centerXZ[1] = centerXZ[1] + p[1]
            centerXZ[3] = centerXZ[3] + p[3]
            if p[2] < minY then minY = p[2] end
        end

        centerXZ[1] = centerXZ[1] / #targets
        centerXZ[3] = centerXZ[3] / #targets

        local center = Vec3.new(centerXZ[1], minY, centerXZ[3])
        local locals = {}

        for _, proxy in ipairs(targets) do
            local p = proxy:GetWorldTranslate()
            locals[proxy] = {
                localPos = p - center,
            }
        end

        --- @type table<RB_MovableProxy, Transform>
        local transforms = {}

        for proxy, data in pairs(locals) do
            local newPos = pos + data.localPos

            transforms[proxy] = {
                Translate = newPos,
            }
        end

        -- if only one target, also apply rotation
        if #targets == 1 then
            transforms[targets[1]].RotationQuat = rot
        end

        Commands.SetTransformSeparate(targets, transforms)
    end, GetLoca("Move selected objects to the cursor position."))

    ttMod:RegisterEvent("SnapToGround", function (e)
        if e.Event ~= "KeyDown" then return end
        if not RB_GLOBALS.TransformEditor.Target or #RB_GLOBALS.TransformEditor.Target == 0 then return end

        local targets = {}

        for _, proxy in pairs(RB_GLOBALS.TransformEditor.Target or {}) do
            if proxy.Guid then
                table.insert(targets, proxy)
            end
        end

        Commands.SnapToGround(targets)
    end)

    buMod:RegisterEvent("BindTo", function(e)
        if e.Event ~= "KeyDown" then return end
        if not RB_GLOBALS.TransformEditor.Target or #RB_GLOBALS.TransformEditor.Target == 0 then return end
        local parent = PickingUtils.GetPickingGuid()
        if not parent or parent == "" then
            Debug("No valid target to bind to")
            return
        end
        local targets = {}

        for _, proxy in pairs(RB_GLOBALS.TransformEditor.Target) do
            if proxy.Guid then
                table.insert(targets, proxy.Guid)
            end
        end

        Commands.Bind(targets, parent)
    end)

    buMod:RegisterEvent("Unbind", function(e)
        if e.Event ~= "KeyDown" then return end
        if not RB_GLOBALS.TransformEditor.Target or #RB_GLOBALS.TransformEditor.Target == 0 then return end

        local targets = {}
        for _, proxy in pairs(RB_GLOBALS.TransformEditor.Target) do
            if proxy.Guid then
                table.insert(targets, proxy.Guid)
            end
        end

        Commands.Unbind(targets)
    end)

    buMod:RegisterEvent("BindPopup", function(e)
        if e.Event ~= "KeyDown" then return end
        local targets = {}


        for _, proxy in pairs(RB_GLOBALS.TransformEditor.Target or {}) do
            if proxy.Guid then
                table.insert(targets, proxy.Guid)
            end
        end

        if #targets == 0 then
            targets = { PickingUtils.GetPickingGuid() }
        end

        for guid, popup in pairs(self.BindPopupCache or {}) do
            popup:Dismiss()
        end

        for _, guid in ipairs(targets) do
            self:CreateBindPopup(guid)
        end
    end)

    local function registerToggleEvent(eventName, netType, field, valueOn, valueOff, mod)
        local channel = netType == "SetAttributes" and NetChannel.SetAttributes or NetChannel.Bind

        mod:RegisterEvent(eventName, function(e)
            if e.Event ~= "KeyDown" then return end
            if not RB_GLOBALS.TransformEditor.Target or #RB_GLOBALS.TransformEditor.Target == 0 then return end
            local targets = {}
            for _, proxy in pairs(RB_GLOBALS.TransformEditor.Target) do
                if proxy.Guid then
                    table.insert(targets, proxy.Guid)
                end
            end
            local paramsOn = { Guid = targets, Attributes = {}, Type = "SetAttributes" }
            local paramsOff = { Guid = targets, Attributes = {}, Type = "SetAttributes" }
            paramsOn.Attributes[field] = valueOn
            paramsOff.Attributes[field] = valueOff
            channel:SendToServer(paramsOn)

            HistoryManager:PushCommand({
                Undo = function() channel:SendToServer(paramsOff) end,
                Redo = function() channel:SendToServer(paramsOn) end,
                Description = "Toggle " .. field,
            })
        end)
    end

    --registerToggleEvent("LookAt", "SetType", "KeepLookingAt", true, false, buMod)
    --registerToggleEvent("StopLookAt", "SetType", "KeepLookingAt", false, true, buMod)
    --registerToggleEvent("Follow", "SetType", "FollowParent", true, false, buMod)
    --registerToggleEvent("StopFollow", "SetType", "FollowParent", false, true, buMod)
    registerToggleEvent("HideSelection", "SetAttributes", "Visible", false, true, ttMod)
    registerToggleEvent("ShowSelection", "SetAttributes", "Visible", true, false, ttMod)
    registerToggleEvent("ApplyGravity", "SetAttributes", "Gravity", true, false, ttMod)
    registerToggleEvent("FreezeGravity", "SetAttributes", "Gravity", false, true, ttMod)

    ttMod:RegisterEvent("Undo", function(e)
        if e.Event ~= "KeyDown" then return end
        HistoryManager:Undo()
    end)

    ttMod:RegisterEvent("Redo", function(e)
        if e.Event ~= "KeyDown" then return end
        HistoryManager:Redo()
    end)

    self:SetupBoxSelect()
end

function TransformToolbar:RegisterTransformEditorEvents()
    local globalEditor = RB_GLOBALS.TransformEditor
    local teMod = KeybindManager:CreateModule("TransformEditor")

    globalEditor.OnAction = function(sel, action)
        if not self.OperatorInput then return end
        self.OperatorInput.Text = action or ""
    end

    teMod:AddModuleCondition(function(e)
        return globalEditor.Disabled ~= true
    end)
    teMod:AddModuleCondition(function(e)
        return globalEditor.Target and #globalEditor.Target > 0 or false
    end)

    teMod:RegisterEvent("Rotate", function(e)
        if e.Event == "KeyDown" then
            globalEditor:SetMode("Rotate")
        end
    end)

    teMod:RegisterEvent("Grab", function(e)
        if e.Event == "KeyDown" then
            globalEditor:SetMode("Translate")
        end
    end)

    teMod:RegisterEvent("Scale", function(e)
        if e.Event == "KeyDown" then
            globalEditor:SetMode("Scale")
        end
    end)

    teMod:RegisterEvent("CycleMode", function(e)
        if e.Event == "KeyDown" then
            globalEditor:CycleMode()
        end
    end)

    teMod:RegisterEvent("FollowTarget", function(e)
        if globalEditor.IsDragging then return end

        local avgPos = Vec3.new(0, 0, 0)
        local targets = globalEditor.Target or {}
        for _, proxy in pairs(globalEditor.Target or {}) do
            avgPos = avgPos + proxy:GetWorldTranslate()
        end
        avgPos = avgPos / #globalEditor.Target

        local oba = self.OrbitalCameraUI
        if not oba then return end
        if not oba:IsRunning() then
            oba:Run()

            if oba.ToggleConfigWindow then
                oba.ToggleConfigWindow()
            end
        end

        self.OrbitalCameraUI:SetTarget(avgPos)

        if #targets == 1 and targets[1].Guid then
            self.OrbitalCameraUI.IgnoreEntity = targets[1].Guid
        else
            self.OrbitalCameraUI.IgnoreEntity = nil
        end
    end)

    self.Subscriptions["ResetTransform"] = InputEvents.SubscribeKeyInput({}, function(e)
        if not globalEditor.Target or #globalEditor.Target == 0 then return end
        if globalEditor.IsDragging then return end
        if e.Event ~= "KeyDown" then return end

        if not (e.Modifiers and e.Modifiers == "LAlt") then return end

        local resetTransform = {}
        if e.Key == teMod:GetKeyByEvent("Rotate").Key then resetTransform.RotationQuat = { 0, 0, 0, 1 } end
        if e.Key == teMod:GetKeyByEvent("Grab").Key then
            resetTransform.Translate = { RBGetPosition(
                RBGetHostCharacter()) }
        end
        if e.Key == teMod:GetKeyByEvent("Scale").Key then resetTransform.Scale = { 1, 1, 1 } end

        Commands.SetTransform(globalEditor.Target or {}, resetTransform)
    end)
end

local boxSelector = Ext.Require("Client/Editor/BoxSelector.lua") --[[@as BoxSelector]]
function TransformToolbar:SetupBoxSelect()
    boxSelector:Init({})
    local function onSelectEnd()
        if not boxSelector then return end
        local returnEntities = boxSelector:End() or {}
        local proxies = {}

        local guids = {}
        
        for _, entity in pairs(returnEntities) do
            local guid = entity.Uuid and entity.Uuid.EntityUuid
            if guid then
                table.insert(guids, guid)
            elseif entity.Scenery then
                local sceneryGuid = entity.Scenery.Uuid
                if sceneryGuid then
                    registerScenery(entity)
                    table.insert(guids, sceneryGuid)
                end
            end
        end

        if not self.InputStates.MultiSelecting then self.Selecting = {} end
        for _, guid in pairs(guids) do
            self.Selecting[guid] = {}
        end

        for selGuid, _ in pairs(self.Selecting) do
            if self.Ignore["Character"] and EntityHelpers.IsCharacter(selGuid) then
                goto continue
            end
            if self.Ignore["Scenery"] and NearbyMap.GetRegisteredScenery(selGuid)  then
                goto continue
            end
            if self.Ignore["NonSpawned"] and not EntityStore.IsSpawned(selGuid) then
                goto continue
            end

            local proxy = MovableProxy.CreateByGuid(selGuid)
            if proxy then
                table.insert(proxies, proxy)
            end
            ::continue::
        end

        RB_GLOBALS.TransformEditor:Select(proxies)
    end

    self.KeybindModule:RegisterEvent("BoxSelect", function(e)
        if e.Repeat then return end

        if e.Event == "KeyDown" then
            boxSelector:Start()
        else
            onSelectEnd()
        end
    end)

    local antiModifier = InputEvents.SubscribeKeyAndMouse(function(e)
        local boxSelectKeybinding = self.KeybindModule:GetKeyByEvent("BoxSelect")
        if not boxSelectKeybinding then return end
        if not boxSelector:IsSelecting() then return end
        if e.Key == boxSelectKeybinding.Key and e.Event == "KeyUp" then
            onSelectEnd()
        end
    end)
end

function TransformToolbar:Render()
    self:RenderTopBar()
    self:RenderConfigMenu()
end

function TransformToolbar:RenderTopBar()
    local screenWidth, screenHeight = UIHelpers.GetScreenSize()
    local windowSize = { screenWidth * 0.6, 80 * SCALE_FACTOR }
    local windowPos = { screenWidth * INIT_WINDOW_POS, 0 }
    local panel = WindowManager.RegisterWindow("generic", "Transform ToolBar", windowPos, windowSize)
    self.TopToolBar = panel

    panel.OnClose = function()
        RB_GLOBALS.TransformEditor:Clear()
        self.Selecting = {}
        self.KeybindConfigWindow.Open = false
        self.BindManagerWindow.Open = false
        self:ClearSubscriptions()
    end

    panel.NoResize = true
    panel.NoMove = true
    panel.NoTitleBar = true

    local topAlignedTable = ImguiElements.AddCenterAlignTable(panel, "TopBar")
    topAlignedTable.ColumnDefs[3] = { WidthFixed = true }

    local row = topAlignedTable:AddRow()
    local leftCell = row:AddCell()
    local centerCell = row:AddCell()
    local rightCell = row:AddCell()

    local closeButton = rightCell:AddImageButton("CloseTransformToolbar", RB_ICONS.X_Square, IMAGESIZE.ROW)
    closeButton.OnClick = function()
        self:Toggle()
    end
    closeButton.Tint = { 1, 1, 1, 0.8 }
    closeButton:SetColor("Button", ColorUtils.HexToRGBA("C24B0000"))
    closeButton:SetColor("ButtonHovered", ColorUtils.HexToRGBA("96920000"))
    closeButton:SetColor("ButtonActive", ColorUtils.HexToRGBA("C24B0000"))

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
    local hintText = GetLoca("Input any number key when dragging gizmo to start")
    operatorInput.Hint = hintText
    local inputTooltip = operatorInput:Tooltip()
    inputTooltip:AddSeparatorText("Numeric Input"):SetStyle("SeparatorTextAlign", 0.5, 0)
    inputTooltip:AddBulletText("G/R/L: ")
    inputTooltip:AddText("Switch to Move/Rotate/Scale mode")
    inputTooltip:AddBulletText("X/Y/Z: ")
    inputTooltip:AddText("Constrain to X/Y/Z axis")
    inputTooltip:AddBulletText("Shift + '-' :")
    inputTooltip:AddText("Toggle negative number input")
    inputTooltip:AddBulletText("Enter | LMB :")
    inputTooltip:AddText("Confirm the operation")
    inputTooltip:AddBulletText("Esc | RMB :")
    inputTooltip:AddText("Cancel the operation")

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
    pivotCombo.OnChange = function(e)
        local mode = indexToPivot[e.SelectedIndex + 1]
        RB_GLOBALS.TransformEditor:SetPivotMode(mode)
    end
    self.pivotCombo = pivotCombo

    spaceCombo.Options = localizedMode
    spaceCombo.SelectedIndex = table.find(indexToMode, RB_GLOBALS.TransformEditor.Space) - 1
    spaceCombo.OnChange = function(e)
        local mode = indexToMode[e.SelectedIndex + 1]
        RB_GLOBALS.TransformEditor:SetSpace(mode)
    end
    self.spaceCombo = spaceCombo
    self.GetCurrentSpace = function()
        return indexToMode[spaceCombo.SelectedIndex + 1]
    end


end

--- @param parent ExtuiTreeParent
function TransformToolbar:RenderOrbitalCamera(parent)

    local oba = OrbitalCameraUI.new()
    self.OrbitalCameraUI = oba
    local configWin = nil

    local runningLabel = "Orbital Camera is Running"
    local stoppedLabel = "Start Orbital Camera"

    local runningBtn = parent:AddButton(stoppedLabel)
    runningBtn.OnClick = function()
        local isRunning = oba:IsRunning()
        if isRunning then
            oba:Stop()
        else
            oba:Run()
        end
        isRunning = oba:IsRunning()
        runningBtn.Label = isRunning and runningLabel or stoppedLabel
    end

    configWin = parent
    configWin:AddSeparatorText("Orbital Camera Configurations")

    oba:RenderConfigTable(configWin)

    oba.ToggleConfigWindow = function()
        runningBtn.Label = runningLabel
    end
end

function TransformToolbar:RenderConfigMenu()
    local panel = WindowManager.RegisterWindow("generic", "Key Bind", { 0, 0 }, { 0, 0 })
    self.KeybindConfigWindow = panel

    panel.Open = false

    panel.AlwaysAutoResize = true
    panel.Closeable = true
    panel.NoTitleBar = true

    local closeSel = panel:AddSelectable("Transform Tool Configs")
    closeSel.Selected = true
    closeSel:SetColor("HeaderHovered", ColorUtils.HexToRGBA("96920000"))
    closeSel:SetColor("Header", ColorUtils.HexToRGBA("C24B0000"))
    closeSel.OnClick = function()
        panel.Open = false
        closeSel.Selected = true
    end

    local aligned = ImguiElements.AddAlignedTable(panel)

    local barPos = aligned:AddSliderWithStep("Toolbar Position", 0.5, 0, 1, 0.01, false)
    barPos.OnChange = function(e)
        local toolbarBar = self.TopToolBar
        local screenWidth, screenHeight = UIHelpers.GetScreenSize()
        local windowSize = toolbarBar.LastSize[1]
        local freeSpace = screenWidth - windowSize
        local u = e.Value[1]
        local pos = MathUtils.Clamp(u, 0, 1)
        local actuallPos = freeSpace * pos
        local windowPos = { actuallPos, 0 }
        if self.TopToolBar then
            self.TopToolBar:SetPos(windowPos)
        end
    end

    local onlySpawnedCheck = panel:AddCheckbox("Only Select Spawned When Box Selecting")
    onlySpawnedCheck.Checked = self.OnlySelectSpawned or false
    onlySpawnedCheck.OnChange = function(e)
        self.Ignore["NonSpawned"] = e.Checked
    end

    local ignoreScenerySel = panel:AddCheckbox("Ignore Scenery When Selecting")
    ignoreScenerySel.Checked = self.Ignore["Scenery"] or false
    ignoreScenerySel.OnChange = function(e)
        self.Ignore["Scenery"] = e.Checked
    end

    local ignoreCharacterSel = panel:AddCheckbox("Ignore Characters When Selecting")
    ignoreCharacterSel.Checked = self.Ignore["Character"] or false
    ignoreCharacterSel.OnChange = function(e)
        self.Ignore["Character"] = e.Checked
    end

    self:RenderOtherConfigOptions(panel)

    self:RenderOrbitalCamera(panel)
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
    local stepSlider = ImguiElements.AddSliderWithStep(row1:AddCell(), "Step", 1, 0.1, 3, 0.05)
    stepSlider.OnChange = function(e)
        if not RB_GLOBALS.TransformEditor.Gizmo then return end
        RB_GLOBALS.TransformEditor.Gizmo.Step = e.Value[1]
    end

    row2:AddCell():AddText("Gizmo Size")
    local gizmoSizeSlider = ImguiElements.AddSliderWithStep(row2:AddCell(), "Gizmo Size", 0.1, 0.01, 2, 0.01)
    gizmoSizeSlider.OnChange = function(e)
        local editor = RB_GLOBALS.TransformEditor
        if editor.Gizmo then
            editor.Gizmo:SetScale(e.Value[1])
            editor.Gizmo:Visualize()
        end
    end
end

function TransformToolbar:CreateBindPopup(guid)
    self.BindPopupCache = self.BindPopupCache or {}
    local notif = self.BindPopupCache[guid] or Notification.new(RBGetName(guid))
    if not self.BindPopupCache[guid] then
        self.BindPopupCache[guid] = notif
    end
    local screenWidth, screenHeight = UIHelpers.GetScreenSize()
    local camera = RBGetCamera()
    local pivot = WorldToScreenPoint({ RBGetPosition(guid) }, camera, screenWidth, screenHeight)
    if not pivot then pivot = { screenWidth / 2, screenHeight / 2 } end
    pivot = { pivot[1] / screenWidth, pivot[2] / screenHeight }
    notif.NoAnimation = true
    notif.AutoFadeOut = false
    notif.Pivot = pivot
    notif.Moveable = true

    ---@param panel ExtuiWindow
    local function render(panel)
        local tab = panel:AddTable("BindPopup", 2)
        tab.ColumnDefs[1] = { WidthFixed = true }
        tab.ColumnDefs[2] = { WidthStretch = true }
        local row1 = tab:AddRow()
        local left = row1:AddCell()

        left:AddText("Bind To:")

        local info = EntityStore:GetBindInfo(guid)
        local curParent = info and info.BindParent or nil
        local image = left:AddImage(RBGetIcon(curParent), IMAGESIZE.SMALL)
        image.SameLine = true

        local right = row1:AddCell()
        local nearByCombo = NearbyCombo.new(right)
        nearByCombo.HideImage = true
        local excludeEntites = {
            [guid] = true,
        }
        nearByCombo.ExcludeEntries = excludeEntites
        nearByCombo:SetSelected(curParent)
        nearByCombo.OnChange = function(sel, selectedGuid, displayName)
            if not selectedGuid or selectedGuid == "" then return end
            if selectedGuid == curParent then return end
            Commands.Bind({ guid }, selectedGuid)
            image:Destroy()
            image = left:AddImage(RBGetIcon(selectedGuid), IMAGESIZE.SMALL)
            image.SameLine = true
        end

        local snapButton = right:AddButton("Snap To Parent")
        snapButton.SameLine = true
        snapButton.OnClick = function()
            local proxy = MovableProxy.CreateByGuid(guid)
            if not proxy then return end
            Commands.SnapToParent({ proxy }, false, true)
        end
        snapButton.OnRightClick = function()
            local proxy = MovableProxy.CreateByGuid(guid)
            if not proxy then return end
            Commands.SnapToParent({ proxy }, true, false)
        end
        snapButton:Tooltip():AddText("Left Click: Snap Position\nRight Click: Snap Rotation")


        local unbindButton = panel:AddButton("Unbind")
        unbindButton.OnClick = function()
            Commands.Unbind({ guid })
            nearByCombo.SelectedIndex = -1
            image:Destroy()
            image = left:AddImage(RBGetIcon(), IMAGESIZE.SMALL)
            image.SameLine = true
        end

        local function addBindCheckbox(panel, label, info, field, valueToChecked, checkedToValue)
            local checked = valueToChecked(info[field])
            local checkbox = panel:AddCheckbox(label, checked)
            checkbox.OnChange = function(e)
                local newValue = checkedToValue(e.Checked)
                local attr = { [field] = newValue }
                NetChannel.Bind:SendToServer({ Type = "SetAttributes", Guid = { guid }, Attributes = attr })
                info[field] = newValue
                HistoryManager:PushCommand({
                    Undo = function()
                        local undoValue = checkedToValue(not e.Checked)
                        NetChannel.Bind:SendToServer({ Type = "SetAttributes", Guid = { guid }, Attributes = { [field] = undoValue } })
                        info[field] = undoValue
                    end,
                    Redo = function()
                        NetChannel.Bind:SendToServer({ Type = "SetAttributes", Guid = { guid }, Attributes = attr })
                        info[field] = newValue
                    end,
                    Description = "Set Bind " .. field,
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

        for _, mType in ipairs(allType) do
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
        listener = EntityStore:SubscribeToBindChanges(guid, function(data)
            local ok, err = pcall(function() return lookAtCheck.Checked, followCheck.Checked end)
            if not ok then
                if listener then
                    listener:Unsubscribe()
                    listener = nil
                end
                return
            end
            local d = data
            info = d
            lookAtCheck.Checked = d.KeepLookingAt == true or false
            followCheck.Checked = d.FollowParent == true or false
            nearByCombo:SetSelected(d.BindParent)
            if d.BindParent then
                image:Destroy()
                image = left:AddImage(RBGetIcon(d.BindParent), IMAGESIZE.SMALL)
                image.SameLine = true
            else
                image:Destroy()
                image = left:AddImage(RBGetIcon(), IMAGESIZE.SMALL)
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

local function safeGetSceneryName(entity)
    local vres = entity.Visual and entity.Visual.Visual and entity.Visual.Visual.VisualResource
    local displayName = vres and RBStringUtils.GetLastPath(vres.SourceFile) or "Unknown_Scenery"
    return displayName
end

function TransformToolbar:CreateNearbyPopup()
    local nearbyNotif = self.NearbyNotif or Notification.new("Depth Selection")
    self.NearbyNotif = nearbyNotif

    nearbyNotif.InstantDismiss = true
    nearbyNotif.NoAnimation = true
    nearbyNotif.AutoFadeOut = false
    nearbyNotif.Pivot = Vec2.new(PickingUtils.GetCursorPos()) / Vec2.new(UIHelpers.GetScreenSize())
    nearbyNotif.Moveable = true

    NearbyMap.UpdateNearbyMap()

    local hits = ScreenToWorldRay():IntersectAll(cursorMaxDistance) or {}
    local selected = nil
    local simpleUnique = {}

    local tempSubs = {}
    ---@param panel ExtuiWindow
    local function render(panel)
        local contextPopup = panel:AddPopup("NearbyEntitiesContextMenu")
        local contextMenu = ImguiElements.AddContextMenu(contextPopup)
        
        --- @param parent ExtuiTreeParent
        --- @param hit Hit
        local function renderHit(parent, hit)
            local ent = hit.Target
            if not ent then return end

            local guid = ent.Uuid and ent.Uuid.EntityUuid or nil
            local sceneryComp = ent.Scenery

            if not guid then
                if not sceneryComp then return end

                NearbyMap.RegisterScenery(ent)

                guid = sceneryComp.Uuid
            end

            if simpleUnique[guid] then return end
            simpleUnique[guid] = true

            local icon = RBGetIcon(guid)
            local name = "Unknown"
            if sceneryComp then
                name = safeGetSceneryName(ent)
            else
                name = RBGetName(guid)
            end


            local group = parent:AddGroup(name .. "##" .. guid)
            local iconBtn = group:AddImageButton("Icon##" .. guid, icon, IMAGESIZE.SMALL)
            local nameBtn = group:AddSelectable(name .. "##" .. guid)

            nameBtn.SpanAllColumns = false

            local distanceText = GetLoca("Distance") .. ": %.2f"
            local distanceLabel = group:AddText(distanceText:format(hit.Distance))
            distanceLabel:SetColor("Text", ColorUtils.HexToRGBA("C4B5B5B5"))
            distanceLabel.Font = "Tiny"

            iconBtn.OnClick = function()
                local proxy = MovableProxy.CreateByGuid(guid)
                if not proxy then return end
                RB_GLOBALS.TransformEditor:Select({ proxy })
            end

            nameBtn.OnClick = function ()
                selected = guid
                nameBtn.Selected = false
                contextPopup:Open()
                selected = guid
            end

            local onHoverEnter = function ()
                selected = guid
            end

            iconBtn.OnHoverEnter = onHoverEnter
            nameBtn.OnHoverEnter = onHoverEnter

            nameBtn.SameLine = true
            distanceLabel.SameLine = true
        end

        --- @type RB_ContextItem[]
        local contextItems = {
            {
                Label = "Open Entity Tab",
                OnClick = function(selectable)
                    if not selected or selected == "" then return end
                    if not EntityHelpers.EntityExists(selected) then return end
                    local entityTab = EntityTab.new(selected, nil, nil, nil)
                    entityTab:Render()
                end
            },
            {
                Label = "Open Visual Tab",
                OnClick = function(selectable)
                    if not selected or selected == "" then return end
                    local sceneryEnt = NearbyMap.GetRegisteredScenery(selected)
                    if sceneryEnt then
                        local entity = sceneryEnt
                        local visualTab = VisualTab.CreateByEntity(entity)
                        visualTab:Refresh()
                        return
                    end
                    local visualTab = VisualTab.new(selected, RBGetName(selected), nil, nil)
                    visualTab.isAttach = false
                    visualTab:Refresh()
                end
            },
            {
                Label = "Set Target",
                OnClick = function(selectable)
                    _P("Selected:", selected)
                    if not selected or selected == "" then return end
                    local proxy = nil
                    proxy = MovableProxy.CreateByGuid(selected)
                    if not proxy then return end
                    RB_GLOBALS.TransformEditor:Select({ proxy })
                end,
                Hint = "S",
                HotKey = {
                    Key = "S"
                }
            },
            {
                Label = "Add to Target",
                OnClick = function(selectable)
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

        for _, item in ipairs(contextItems) do
            local sle = contextMenu:AddItemPacked(item)

            if item.HotKey then
                tempSubs[item.Label] = InputEvents.SubscribeKeyAndMouse(function(e)
                    if e.Event ~= "KeyDown" then return end
                    if not selected or selected == "" then return end

                    item.OnClick(sle)
                end, item.HotKey)
            end
        end

        for _, hit in pairs(hits) do
            renderHit(panel, hit)
        end
    end

    nearbyNotif:Show(nearbyNotif.name, render)
    nearbyNotif.OnDismiss = function()
        for _, sub in pairs(tempSubs) do
            sub:Unsubscribe()
        end
        tempSubs = {}
    end
end

local function getCursorTransform(cursorUUID)
    local mouseRay = ScreenToWorldRay()
    if not mouseRay then return end

    local dis = cursorMaxDistance
    local hits = mouseRay:IntersectAll(dis)
    local hit = nil

    for _, h in pairs(hits or {}) do
        local targetUuid = h.Target and h.Target.Uuid and h.Target.Uuid.EntityUuid or nil
        if (not cursorUUID) or (not targetUuid) or (targetUuid ~= cursorUUID) then
            hit = h
            break
        end
    end
    if not hit then return end

    local pos, rot = nil, nil
    if hit then
        pos = hit.Position
        rot = MathUtils.DirectionToQuat(hit.Normal)
    else
        pos = mouseRay:At(dis)
        rot = Quat.new(CameraHelpers.GetCameraRotation())
    end
    return pos, rot
end

function TransformToolbar:CreateCursor(pos, onCreated)
    if self.Cursor and EntityHelpers.EntityExists(self.Cursor) or (self.creatingCursor) then
        return
    end

    if self.Cursor then
        NetChannel.Delete:SendToServer({ Guid = self.Cursor })
    end

    self.creatingCursor = true

    local rot = nil
    if not pos or not rot then
        pos, rot = getCursorTransform()
    end
    rot = rot or Quat.Identity()

    if not pos or not rot then
        self.creatingCursor = false
        return
    end

    NetChannel.Visualize:RequestToServer({
        Type = "Cursor",
        Position = pos,
        Rotation = rot,
        Duration = -1,
    }, function(response)
        for _, viz in pairs(response or {}) do
            self.Cursor = viz
            RB_GLOBALS.TransformEditor.Cursor = self.Cursor
        end
        self.creatingCursor = false
        onCreated = onCreated or function() end
        onCreated()
    end)

    self.CursorTimer = Timer:EveryFrame(function(timerID)
        RB_GLOBALS.TransformEditor.Gizmo.Visualizer:Visualize3DCursor(self.Cursor)
    end)
end

function TransformToolbar:MoveCursor()
    if not self.Cursor or not EntityHelpers.EntityExists(self.Cursor) then
        self:CreateCursor()
        return
    end

    local pos, rot = getCursorTransform(self.Cursor) 
    if not pos or not rot then return end

    NetChannel.SetTransform:RequestToServer({
        Guid = self.Cursor,
        Transforms = {
            [self.Cursor] = {
                Translate = pos,
                RotationQuat = rot,
            }
        }
    }, function()
    end)

    NetChannel.SetAttributes:SendToServer({
        Guid = self.Cursor,
        Attributes = {
            Visible = true,
        }
    })
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
