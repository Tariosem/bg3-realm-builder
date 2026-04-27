--- @class CameraTool
--- @field CameraProxy CameraProxy
--- @field Init fun(self:CameraTool)
CameraTool = {}

local deepCopy = RBUtils.DeepCopy

local function moveTo(t, from, to)
    local removed = table.remove(t, from)
    table.insert(t, to, removed)
end

local function makeTranslationStr(translation)
    translation = translation or {}
    return string.format(" (X: %.2f Y: %.2f Z: %.2f)", translation[1], translation[2], translation[3])
end

--- @return Transform?
local function getCameraTransform()
    local cam = RBGetCamera()
    if not cam or not cam.PhotoModeCameraSavedTransform then return end
    local camTransform = cam.Transform.Transform

    return {
        Translate = Vec3.new(camTransform.Translate),
        RotationQuat = Quat.new(camTransform.RotationQuat),
        Scale = Vec3.new(1, 1, 1)
    }
end

--- @param e ExtuiStyledRenderable
local function setUpTransformDragDrop(e)
    e.CanDrag = true
    e.DragDropType = "CameraTool.Transform"
end

function CameraTool:Init()
    local window = WindowManager.RegisterWindow("CameraTool", "Camera Tool")
    window.Open = false
    window.Closeable = true
    self.WindowOnClose = {}
    window.OnClose = function()
        for _, v in pairs(self.WindowOnClose) do
            pcall(v)
        end
    end

    self.CameraProxy = CameraProxy.new()
    self.CameraToolKeybind = KeybindManager:CreateModule("CameraTool")
    self.CameraToolKeybind:AddModuleCondition(function (e)
        return IsInPhotoMode()
    end)
    self.CameraToolKeybind:RegisterEvent("ToggleCameraToolWindow", function (e)
        if e.Event ~= "KeyDown" then return end
        window.Open = not window.Open
    end)
    self:RenderPanel(window)
end

--- @param parent ExtuiTreeParent
local function renderPositionSaver(parent)
    parent = parent:AddGroup("PositionSaver")
    --- @class PositionEntry
    --- @field Name string
    --- @field Transform Transform

    local saveLabelPattern = "[%s]"
    local function generateLabel()
        return string.format(saveLabelPattern, RBUtils.GetFormatHMS())
    end

    local entries = {}

    local function refreshGroups() end
    --- @param entry PositionEntry
    --- @param idx integer
    local function renderSingleEntry(entry, idx)
        local id = entry.Name .. idx
        local entryTransform = entry.Transform
        local translation = entryTransform.Translate
        
        local function suffix(str)
            return str .. "##" .. id
        end

        local group = parent:AddGroup(id)

        local xBtn = group:AddButton(suffix("[X]"))
        StyleHelpers.ApplyDangerButtonStyle(xBtn)

        local translateStr = makeTranslationStr(translation)
        local nameBtn = CameraTool:RenderCameraTransformButton(group, entry.Name, entryTransform)
        nameBtn.SameLine = true
        nameBtn.OnDragDrop = function() end -- 

        xBtn.OnClick = function()
            table.remove(entries, idx)
            refreshGroups()
        end

    end

    local function renderPlusEntry()
        local group = parent:AddGroup("PlusEntry")
        local plusBtn = parent:AddButton("[+] Add Current Camera Position")
        plusBtn.OnClick = function()
            local cam = RBGetCamera()
            if not cam or not cam.PhotoModeCameraSavedTransform then return end
            local camTransform = getCameraTransform()

            local name = generateLabel()

            table.insert(entries, {
                Name = name,
                Transform = camTransform
            })
            refreshGroups()
        end
    end

    function refreshGroups()
        ImguiHelpers.DestroyAllChildren(parent)
        for i,v in pairs(entries) do
            renderSingleEntry(v, i)
        end
        renderPlusEntry()
    end

    refreshGroups()

    return parent
end 

--- @param parent ExtuiTreeParent
function CameraTool:RenderPanel(parent)

    local cT = ImguiElements.AddCollapsingTable(parent, "Camera Animator", "Position Saver",
        {
            CollapseDirection = "Right"
        })

    local mainArea = cT.MainArea
    local sideBar = cT.SideBar

    self:RenderPositionSaver(sideBar)

    self:RenderMainArea(mainArea)

end

--- @param parent ExtuiTreeParent
function CameraTool:RenderPositionSaver(parent)
    return renderPositionSaver(parent)
end

--- @param parent ExtuiTreeParent
--- @param name string
--- @param transform Transform
--- @return ExtuiButton
function CameraTool:RenderCameraTransformButton(parent, name, transform)
    name = name or "Unnamed Transform"
    local translation = transform and transform.Translate or nil
    local translateStr = transform and makeTranslationStr(translation) or " (Drag or Drop Here)"
    local btn = parent:AddButton(name .. translateStr)
    if transform then
        btn.UserData = transform
    end
    
    setUpTransformDragDrop(btn)

    btn.OnClick = function ()
        local camProxy = CameraTool.CameraProxy
        if not camProxy then return end
        transform = btn.UserData
        if not transform then return end
        camProxy:SetTransform(transform)
    end

    --- @param e ExtuiStyledRenderable
    btn.OnDragStart = function (e)
        e.UserData = deepCopy(e.UserData or transform)
        e.DragPreview:AddText(name .. translateStr)
    end

    btn.OnDragDrop = function (e, drop)
        if drop and drop.UserData then
            transform = drop.UserData
            btn.UserData = transform
            btn.Label = name .. makeTranslationStr(transform.Translate)
        end
    end

    return btn
end

--- @param parent ExtuiTreeParent
function CameraTool:RenderMainArea(parent)

    local upperWindow = parent

    self:RenderOrbitalCameraControls(upperWindow)

    local sep = parent:AddSeparator()

    local lowerWindow = parent

    self:RenderCameraAnimator(lowerWindow)
end

local OrbitalCameraUI = Ext.Require("Client/Editor/OrbitalCamera.lua") --[[@as OrbitalCameraUI]]
--- @param parent ExtuiTreeParent
function CameraTool:RenderOrbitalCameraControls(parent)
    local camProxy = self.CameraProxy
    if not camProxy then return end

    local orbCamUI = OrbitalCameraUI.new(camProxy)

    local title = parent:AddSelectable("Orbital Camera Controls")
    local runningText = GetLoca("Orbital Camera Running")
    local notRunningText = GetLoca("Orbital Camera Not Running")

    local cH = ImguiElements.AddTree(parent, "Config")
    cH:SetOpen(false)
    local configTable = orbCamUI:RenderConfigTable(cH)
    
    title.OnClick = function()
        local editor = RB_GLOBALS.TransformEditor
        if editor and editor.Target and #editor.Target > 0 then
            local add = Ext.Math.Add
            local div = Ext.Math.Div
            local avgPos = {0,0,0}
            local targets = editor.Target or {}
            local targetCnt = #targets
            for i, v in pairs(targets) do
                local pos = v:GetWorldTranslate()
                avgPos = add(avgPos, pos)
            end
            avgPos = div(avgPos, targetCnt)
            orbCamUI:SetTarget(avgPos)

            if targetCnt == 1 and targets[1].Guid then
                orbCamUI.controller.IgnoreEntity = targets[1].Guid
            else
                orbCamUI.controller.IgnoreEntity = nil
            end
        else
            local host = _C()
            local uuid = host.Uuid.EntityUuid
            local pos = {RBGetPosition(uuid)}
            pos[2] = pos[2] + 1.5
            orbCamUI:SetTarget(pos)
            orbCamUI.controller.IgnoreEntity = uuid
        end

        if orbCamUI:IsRunning() then
            orbCamUI:Stop()
        else
            orbCamUI:Run()
        end
        local IsRunning = orbCamUI:IsRunning()
        cH.Visible = IsRunning
        title.Label = IsRunning and runningText or notRunningText
        title.Highlight = IsRunning
    end
    cH.Visible = false

    self.WindowOnClose["StopOrbitalCamera"] = function()
        if orbCamUI:IsRunning() and not IsInPhotoMode() then
            orbCamUI:Stop()
        end
    end

    self.CameraToolKeybind:RegisterEvent("ToggleOrbitalCamera", function (e)
        if e.Event ~= "KeyDown" then return end
    
        title:OnClick()
    end, "Toggle Orbital Camera, auto center on selected object")
end

--- @class CameraAnimationEntry
--- @field Name string
--- @field From Transform
--- @field To Transform
--- @field Duration number
--- @field Easing AnimationEasing

---@param entries CameraAnimationEntry[]
---@param onSetTransform fun(transform:Transform)
---@param onComplete fun()
---@return RunningAnimation
local function animateTransforms(entries, onSetTransform, onComplete)
    local idx = 0

    local function lerpTransform(from, to, t)
        return {
            Translate = Vector.Lerp(from.Translate, to.Translate, t),
            RotationQuat = Quat.Slerp(from.RotationQuat, to.RotationQuat, t),
            Scale = Vector.Lerp(from.Scale, to.Scale, t)
        }
    end

    local running = nil
    local function onAnimationComplete()
        idx = idx + 1
        if entries[idx] then
            running = AnimateValue(120, 0, 1, entries[idx].Duration, entries[idx].Easing, onAnimationComplete,
            function (value, eased)
                local from = entries[idx].From
                local to = entries[idx].To
                local interpTransform = lerpTransform(from, to, value)
                onSetTransform(interpTransform)
            end)
        else
            onComplete()
            running = nil
        end
    end
    onAnimationComplete() -- start the first animation

    return {
        Stop = function()
            if running then
                running:Stop()
            end
        end
    }
end

--- @param parent ExtuiTreeParent
function CameraTool:RenderCameraAnimator(parent)
    local function refreshEntries() end
    local function renderEntry() end
    local function playAnimation() end
    local controlPanel = parent:AddGroup("ControlPanel")

    local playingLoca = GetLoca("Stop Animation")
    local notPlayingLoca = GetLoca("Play Animation")
    local playBtn = controlPanel:AddButton(notPlayingLoca)
    local loopPlayCheckbox = controlPanel:AddCheckbox("Loop Animation")
    local previewBtn = controlPanel:AddButton("Preview Animation")

    loopPlayCheckbox.SameLine = true
    previewBtn.SameLine = true

    local simpleMode = true
    local simpleModeBtn = controlPanel:AddButton("Simple Mode: " .. (simpleMode and "ON" or "OFF"))

    simpleModeBtn.OnClick = function()
        simpleMode = not simpleMode
        simpleModeBtn.Label = "Simple Mode: " .. (simpleMode and "ON" or "OFF")
        refreshEntries()
    end

    parent = parent:AddChildWindow("EntriesPanel")

    local allEasings = GetAllEasings()
    --- @type CameraAnimationEntry[]
    local entries = {} 
    local parentTable = parent:AddTable("EntriesTable", 1)
    parentTable.BordersInnerH = true
    parentTable.RowBg = true
    
    --- @param toPlay CameraAnimationEntry[]?
    --- @return CameraAnimationEntry[]
    local function returnValidEntries(toPlay)
        toPlay = toPlay or entries
        local indexTable = {}
        local copied = deepCopy(toPlay)
        for i, e in pairs(copied) do
            if e.From and e.To and e.Duration and e.Easing then
                if simpleMode then
                    e.Easing = entries[1].Easing or "Linear"
                    e.Duration = entries[1].Duration or 2000
                end
                if e.Swap then
                    local temp = e.From
                    e.From = e.To
                    e.To = temp
                end
                
                table.insert(indexTable, e)
            end
        end
        return indexTable
    end

    local function setupEntryDragDrop(ele, idx)
        ele.CanDrag = true
        ele.DragDropType = "CameraTool.Entry"
        ele.OnDragStart = function (e)
            e.UserData = idx
            renderEntry(e.DragPreview, entries[idx], idx)
        end
        ele.OnDragDrop = function (e, drop)
            if drop and drop.UserData then
                local fromIdx = drop.UserData
                local toIdx = idx

                if fromIdx and toIdx then
                    moveTo(entries, fromIdx, toIdx)
                    refreshEntries()
                end
            end
        end
    end

    --- @param parent ExtuiTreeParent
    --- @param entry CameraAnimationEntry
    local function renderEntriConfig(parent, entry)
        local aT = ImguiElements.AddAlignedTable(parent)
        local durationSlider = aT:AddSliderWithStep("Duration", entry.Duration, 100, 10000, 500, true)

        local easingCombo = aT:AddCombo("Easing")
        easingCombo.Options = allEasings
        ImguiHelpers.SetCombo(easingCombo, entry.Easing)
        
        durationSlider.OnChange = function (e)
            entry.Duration = e.Value[1]
        end

        easingCombo.OnChange = function (e)
            entry.Easing = ImguiHelpers.GetCombo(e)
        end
        return aT
    end

    function renderEntry(parent, entry, idx)
        local id = "Entry" .. idx
        local chilWin = parent --[[@as ExtuiTreeParent]]
        local tab = parent:AddTable("SeparatorTable##" .. idx, 4)
        tab.ColumnDefs[1] = {WidthFixed = true}
        tab.ColumnDefs[2] = {WidthFixed = true}
        tab.ColumnDefs[3] = {WidthStretch = true}
        tab.ColumnDefs[4] = {WidthFixed = true}
        local row = tab:AddRow()
        --- @type ExtuiTableCell[]
        local topRow = {row:AddCell(), row:AddCell(), row:AddCell(), row:AddCell()}
        local xBtn = topRow[1]:AddButton("[X]")
        local sep = topRow[2]:AddSelectable("Sequence " .. idx)
        local nameInput = topRow[3]:AddInputText("##name" .. idx)
        local duplicateBtn = topRow[4]:AddButton("Duplicate")
        nameInput.Text = entries[idx].Name or ""
        nameInput.OnChange = function (e)
            entries[idx].Name = e.Text
        end
        setupEntryDragDrop(sep, idx)
        sep.OnClick = function()
            sep.Selected = false
            playAnimation({entry})
        end

        StyleHelpers.ApplyDangerButtonStyle(xBtn)
        
        duplicateBtn.SameLine = true

        local midTable = chilWin:AddTable("MidTable##" .. id, 3)
        midTable.ColumnDefs[1] = {WidthStretch = true}
        midTable.ColumnDefs[2] = {WidthFixed = true}
        midTable.ColumnDefs[3] = {WidthFixed = true}
        local midRow = midTable:AddRow()
        local fromCell = midRow:AddCell()
        local arrowCell = midRow:AddCell()
        local toCell = midRow:AddCell()
        local fromBtn = self:RenderCameraTransformButton(fromCell, "From", entry.From)
        fromBtn.OnDragDrop = function (e, drop)
            if drop and drop.UserData then
                local droppedTransform = drop.UserData
                entry.From = droppedTransform
                fromBtn.UserData = droppedTransform
                fromBtn.Label = "From" .. makeTranslationStr(droppedTransform.Translate)
            end
        end
        local swapBtn = arrowCell:AddSelectable(entry.Swap and "<-" or "->")
        local toBtn = self:RenderCameraTransformButton(toCell, "To", entry.To)
        swapBtn.SameLine = true
        toBtn.SameLine = true
        toBtn.OnDragDrop = function (e, drop)
            if drop and drop.UserData then
                local droppedTransform = drop.UserData
                entry.To = droppedTransform
                toBtn.UserData = droppedTransform
                toBtn.Label = "To" .. makeTranslationStr(droppedTransform.Translate)
            end
        end

        swapBtn.OnClick = function()
            entry.Swap = not entry.Swap
            swapBtn.Label = entry.Swap and "<-" or "->"
            swapBtn.Selected = false
        end
        swapBtn:Tooltip():AddText("Swap From and To Transforms")

        local configTable = renderEntriConfig(chilWin, entry)
        configTable.Visible = (not simpleMode) or (idx == 1)

        xBtn.OnClick = function()
            table.remove(entries, idx)
            refreshEntries()
        end

        duplicateBtn.OnClick = function()
            local copy = deepCopy(entry)
            table.insert(entries, idx + 1, copy)
            refreshEntries()
        end
    end

    local function addNewEntry()
        --- @type CameraAnimationEntry
        local newEntry = {
            Name = RBUtils.GetFormatHMS(),
            Duration =  2000,
            Easing = "Linear"
        }
        table.insert(entries, newEntry)
        refreshEntries()
    end

    local function renderAddButton()
        local cell = parentTable:AddRow():AddCell()
        local addBtn = cell:AddButton("[+] Add Animation Entry")
        addBtn.OnClick = function()
            addNewEntry()
        end
    end

    function refreshEntries()
        ImguiHelpers.DestroyAllChildren(parentTable)
        for i, v in pairs(entries) do
            local newCell = parentTable:AddRow():AddCell()
            renderEntry(newCell, v, i)
        end
        renderAddButton()
    end

    local loop = false
    local currentAnim = nil

    function playAnimation(toPlay)
        if #entries == 0 then return end
        local camProxy = self.CameraProxy
        if not camProxy then return end

        if currentAnim then
            currentAnim:Stop()
            currentAnim = nil
        else
            toPlay = toPlay or entries
            local animatedEntries = returnValidEntries(toPlay)
            if #animatedEntries == 0 then return end
            currentAnim = animateTransforms(animatedEntries, function (transform)
                camProxy:SetTransform(transform)
            end, function ()
                currentAnim = nil
                if loop then
                    playBtn.OnClick()
                else
                    playBtn.Label = notPlayingLoca
                end
            end)
        end
        
        playBtn.Label = currentAnim and playingLoca or notPlayingLoca
    end

    playBtn.OnClick = function()
        playAnimation()
    end

    loopPlayCheckbox.OnChange = function (e)
        loop = e.Checked
    end

    previewBtn.OnClick = function()
        local animatedEntries = returnValidEntries()
        local allDurations = 0
        for i, v in pairs(animatedEntries) do
            allDurations = allDurations + v.Duration
        end
        NetChannel.CallOsiris:RequestToServer({
            Function = "CreateAt",
            Args = {
                MARKER_ITEM.SpotLight,
                0, 0, 0,
                0, 0, ""
            }
        }, function (response)
            local item = response[1]
            local itemProxy = nil
            if not item then return end

            local function deleteItem()
                NetChannel.Delete:SendToServer({ Guid = item })
                deleteItem = function() end
            end

            animateTransforms(animatedEntries, function (transform)
                NetChannel.SetTransform:SendToServer({
                    Guid = item,
                    Transforms = {
                        [item] = transform
                    }
                })
            end, function ()
                deleteItem()
            end)
            Timer:After(allDurations, function ()
                deleteItem()
            end)
        end)
    end

    self.WindowOnClose["StopCameraAnimation"] = function()
        if currentAnim then
            currentAnim:Stop()
            currentAnim = nil
            playBtn.Label = notPlayingLoca
        end
    end

    refreshEntries()

    return refreshEntries
end

EventsSubscriber.RegisterOnSessionLoaded(function()
    CameraTool:Init()
end)