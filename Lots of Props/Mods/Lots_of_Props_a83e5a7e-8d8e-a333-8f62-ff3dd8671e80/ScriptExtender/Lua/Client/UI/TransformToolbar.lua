--- @class TransformToolbar
--- @field parent ExtuiTabBar
--- @field TransformEditor TransformEditor
--- @field EventsToKeybinds table<string, SDLScanCode|string>
--- @field new fun(): TransformToolbar
TransformToolbar = _Class("TransformToolbar")

function TransformToolbar:__init()
    self.TransformEditor = TransformEditor
    self.Subscriptions = {}
    self.Selecting = {}
    self:RegisterKeyInputEvents()
end

local function bindCommand(targets, parent)
    Post(NetChannel.Bind, { Type = "Bind", Parent = parent, Guid = targets })

    HistoryManager:PushCommand({
        Undo = function()
            Post(NetChannel.Bind, { Type = "Unbind", Guid = targets, Parent = nil })
        end,
        Redo = function()
            Post(NetChannel.Bind, { Type = "Bind", Parent = parent, Guid = targets })
        end
    })

end

local function unbindCommand(targets)
    local oriParents = {}
    for _,guid in ipairs(targets) do
        local parent = PropStore:GetBindParent(guid)
        if parent then
            oriParents[guid] = parent
        end
    end

    Post(NetChannel.Bind, { Type = "Unbind", Guid = targets, Parent = nil })
    HistoryManager:PushCommand({
        Undo = function()
            for guid,parent in pairs(oriParents) do
                Post(NetChannel.Bind, { Type = "Bind", Guid = {guid}, Parent = parent })
            end
        end,
        Redo = function()
            Post(NetChannel.Bind, { Type = "Unbind", Guid = targets, Parent = nil })
        end
    })
end

local function snapCommand(targets, onlyRotation, onlyPosition)
    local parents = {}
    for _,guid in ipairs(targets) do
        local parent = PropStore:GetBindParent(guid)
        if parent then
            parents[guid] = parent
        end
    end
    local targetPos = {}
    for guid,parent in pairs(parents) do
        targetPos[guid] = {Translate = {CGetPosition(parent)}, RotationQuat = {CGetRotation(parent)}}
    end
    if onlyRotation then
        for guid,pos in pairs(targetPos) do
            pos.Translate = nil
        end
    elseif onlyPosition then
        for guid,pos in pairs(targetPos) do
            pos.RotationQuat = nil
        end
    end

    TransformEditor:SetTransform(targets, targetPos)
end

function TransformToolbar:RegisterKeyInputEvents()
    if self.Registered then return end
    self.Registered = true

    local function singleSelect()
        local guid = GetPickingGuid()
        if guid and guid ~= "" then
            if self.MultiSelecting then
                self.Selecting[guid] = {}
                self.TransformEditor:Select(self.Selecting)
            else
                self.TransformEditor:Select(guid)
            end
        else
        end
    end

    local ttMod = KeybindManager:CreateModule("TransformToolbar")
    local buMod = KeybindManager:CreateModule("BindUtility")
    buMod:AddModuleCondition(function (e)
        return self.TopToolBar and self.TopToolBar.Open
    end)
    ttMod:AddModuleCondition(function (e)
        return self.TopToolBar and self.TopToolBar.Open
    end)
    self.KeybindModule = ttMod
    self.BindUtilityModule = buMod

    ttMod:RegisterEvent("MultiSelect", function (e)
        if e.Event == "KeyDown" then
            self.MultiSelecting = true
            Debug("MultiSelecting enabled")
        elseif e.Event == "KeyUp" then
            self.TransformEditor:Select(self.Selecting)
            self.MultiSelecting = false
            self.Selecting = {}
            Debug("MultiSelecting disabled")
        end
    end)

    ttMod:RegisterEvent("Select", function (e)
        if e.Event ~= "KeyDown" or e.Repeat then return end
        singleSelect()
    end)


    ttMod:RegisterEvent("ClearSelection", function (e)
        if e.Event ~= "KeyDown" then return end
        self.TransformEditor:Clear()
        self.Selecting = {}
    end)

    ttMod:RegisterEvent("MoveToCursor", function (e)
        if e.Event ~= "KeyDown" then return end

        local targets = NormalizeGuidList(self.TransformEditor.Target)
        local pos, rot = GetCursorPosAndRot()

        TransformEditor:SetTransform(targets, {Translate = pos, RotationQuat = rot})
    end)

    ttMod:RegisterEvent("Duplicate", function (e)
        if e.Event ~= "KeyDown" then return end

        self:DuplicateSelection()
    end)

    ttMod:RegisterEvent("OpenVisualTab", function (e)
        if e.Event ~= "KeyDown" then return end
        local pick = GetPickingGuid()
        if not pick or pick == "" then return end
        if CIsCharacter(pick) then return end

        local success = LOPMenu.propsMenu:FocusPropVisualTab(pick)
    end)

    buMod:RegisterEvent("BindTo", function (e)
        if e.Event ~= "KeyDown" then return end
        if not self.TransformEditor.Target or #self.TransformEditor.Target == 0 then return end
        local parent = GetPickingGuid()
        if not parent or parent == "" then
            Debug("No valid target to bind to")
            return
        end
        local targets = NormalizeGuidList(self.TransformEditor.Target)
        bindCommand(targets, parent)
    end)

    buMod:RegisterEvent("Unbind", function (e)
        if e.Event ~= "KeyDown" then return end
        if not self.TransformEditor.Target or #self.TransformEditor.Target == 0 then return end

        local targets = NormalizeGuidList(self.TransformEditor.Target)

        unbindCommand(targets)
    end)

    buMod:RegisterEvent("Snap", function (e)
        if e.Event ~= "KeyDown" then return end
        if not self.TransformEditor.Target or #self.TransformEditor.Target == 0 then return end

        local targets = NormalizeGuidList(self.TransformEditor.Target)
        snapCommand(targets)
    end)

    buMod:RegisterEvent("BindPopup", function (e)
        if e.Event ~= "KeyDown" then return end
        local targets = NormalizeGuidList(self.TransformEditor.Target)
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
            if not self.TransformEditor.Target or #self.TransformEditor.Target == 0 then return end
            local targets = NormalizeGuidList(self.TransformEditor.Target)
            local paramsOn = { Type = netType, Guid = targets }
            local paramsOff = { Type = netType, Guid = targets }
            paramsOn[field] = valueOn
            paramsOff[field] = valueOff
            Post(channel, paramsOn)
            HistoryManager:PushCommand({
                Undo = function() Post(channel, paramsOff) end,
                Redo = function() Post(channel, paramsOn) end
            })
        end)
    end
    registerToggleEvent("LookAt", "SetType", "KeepLookingAt", true, false, buMod)
    registerToggleEvent("StopLookAt", "SetType", "KeepLookingAt", false, true, buMod)
    registerToggleEvent("Follow", "SetType", "NotFollowParent", false, true, buMod)
    registerToggleEvent("StopFollow", "SetType", "NotFollowParent", true, false, buMod)
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
        for guid,_ in pairs(PropStore:GetAll()) do
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

            self.TransformEditor:Select(self.Selecting)

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
    local targets = NormalizeGuidList(self.TransformEditor.Target)
    local selectionSet = {}
    for _,guid in ipairs(targets) do
        selectionSet[guid] = true
    end
    for _,guid in ipairs(targets) do
        local entity = UuidToHandle(guid)
        if entity and entity.IsItem then
            table.insert(toPost.Guid, guid)
        end
    end
    if #toPost.Guid == 0 then Debug("No valid entity to duplicate") return end

    local duplications = {}
    local cnt = #toPost.Guid

    Post(NetChannel.Duplicate, toPost)

    ClientSubscribe("ServerProps", function(data)
        for _, prop in ipairs(data) do
            table.insert(duplications, prop.Guid)
            cnt = cnt - 1
        end
        if cnt <= 0 then
            self.TransformEditor:Select(selectionSet)
            HistoryManager:PushCommand({
                Undo = function()
                    Post("Delete", {Guid = duplications})
                end,
                Redo = function()
                    Post("Duplicate", toPost)
                end
            })
            return UNSUBSCRIBE_SYMBOL
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
        self.TransformEditor:Clear()
        self.Selecting = {}
        self.KeybindConfigWindow.Open = false
        self.BindManagerWindow.Open = false
        self:ClearSubscriptions()
    end

    local screenWidth, screenHeight = GetScreenSize()
    panel:SetSize({screenWidth * 0.6, 100})
    panel:SetPos({screenWidth * 0.2, 0})

    panel.NoResize = true
    panel.NoMove = true
    panel.NoTitleBar = true

    local table = panel:AddTable("TopBar", 3)
    table.ColumnDefs[1] = { WidthFixed = true }
    table.ColumnDefs[2] = { WidthStretch = true }
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

    local spaceCombo = centerCell:AddCombo("Space")
    spaceCombo.ItemWidth = 300 * SCALE_FACTOR
    local indexToMode = {
        "World",
        "Local",
        "View",
        "Relative",
    }
    local localizedMode = {
        GetLoca("Global"),
        GetLoca("Local"),
        GetLoca("View"),
        GetLoca("Relative"),
    }

    ClientSubscribe(NetMessage.ServerGizmo, function (data)
        local space = data.Space
        for i,mode in ipairs(indexToMode) do
            if mode == space then
                spaceCombo.SelectedIndex = i - 1
                break
            end
        end
    end)

    spaceCombo.Options = localizedMode
    spaceCombo.SelectedIndex = 0
    spaceCombo.OnChange = function (e)
        local mode = indexToMode[e.SelectedIndex + 1]
        if mode == "View" then
            StartUpdateingCamera()
        end
        self.TransformEditor:SetSpace(mode)
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
        self.TransformEditor.Step = e.Value[1]
    end

    row2:AddCell():AddText("Gizmo Size")
    local gizmoSizeSlider = AddSliderWithStep(row2:AddCell(), "Gizmo Size", 0.1, 0.01, 2, 0.01)
    gizmoSizeSlider.UserData.StepInput.Visible = false
    gizmoSizeSlider.OnChange = function (e)
        local editor = self.TransformEditor
        if editor.Gizmo then
            editor.Gizmo:SetScale(e.Value[1])
        end
    end

    local tips = panel:AddText("Tips: Use Alt + Mode Key to reset the transform.")
    tips:SetColor("Text", HexToRGBA("FFFFAA00"))
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

        local info = PropStore:GetBindInfo(guid)
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
            bindCommand({guid}, selectedGuid)
            image:Destroy()
            image = left:AddImage(GetIcon(selectedGuid), IMAGESIZE.SMALL )
            image.SameLine = true
        end

        local snapButton = right:AddButton("Snap")
        snapButton.SameLine = true
        snapButton.OnClick = function()
            snapCommand({guid}, false, true)
        end
        snapButton.OnRightClick = function()
            snapCommand({guid}, true, false)
        end
        snapButton:Tooltip():AddText("Left Click: Snap Position\nRight Click: Snap Rotation")


        local unbindButton = panel:AddButton("Unbind")
        unbindButton.OnClick = function()
            unbindCommand({guid})
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
                Post(NetChannel.Bind, { Type = "SetType", Guid = {guid}, [field] = newValue })
                info[field] = newValue
                HistoryManager:PushCommand({
                    Undo = function()
                        local undoValue = checkedToValue(not e.Checked)
                        Post(NetChannel.Bind, { Type = "SetType", Guid = {guid}, [field] = undoValue })
                        info[field] = undoValue
                    end,
                    Redo = function()
                        Post(NetChannel.Bind, { Type = "SetType", Guid = {guid}, [field] = newValue })
                        info[field] = newValue
                    end
                })
            end
            checkbox.SameLine = true
            return checkbox
        end

        local notCheck = function(checked) return not checked end
        local checkCheck = function(v) return v end

        local lookAtCheck = addBindCheckbox(panel, "Keep Looking At", info, "KeepLookingAt", checkCheck, checkCheck)
        local notFollowCheck = addBindCheckbox(panel, "Follow Parent", info, "NotFollowParent", notCheck, notCheck)

        local listener = ClientSubscribe(NetMessage.BindProps, function (data)
            local ok, err = pcall(function() return lookAtCheck.Checked, notFollowCheck.Checked end)
            if not ok then return UNSUBSCRIBE_SYMBOL end
            for _,d in ipairs(data.BindInfos) do
                if d.Guid == guid then
                    info = d
                    lookAtCheck.Checked = d.KeepLookingAt == true or false
                    notFollowCheck.Checked = (not d.NotFollowParent) == true or false
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

function TransformToolbar:Open()
    if self.TopToolBar then
        self.TopToolBar.Open = true
    end
    self:RegisterKeyInputEvents()
end