--- @class RB_CustomEffectData
--- @field Uuid GUIDSTRING
--- @field DisplayName string
--- @field Icon string
--- @field Effects RB_EffectDragDropData[]

--- @class CustomEffectTab : RB_EffectTab
--- @field entry RB_CustomEffectData
--- @field panel ExtuiWindow
CustomEffectTab = _Class("CustomEffectTab", RBEffectTab)

function CustomEffectTab:__init(entry)
    self.uuid = entry.Uuid
    self.entry = entry
    self.Casters = {}

    self.loopHandles = {}

    local window = WindowManager.RegisterWindow(self.uuid, entry.DisplayName)

    self.panel = window
    window.Closeable = true
    window.Open = false
end

--- @param parent ExtuiTreeParent
--- @param effectEntry RB_EffectDragDropData
local function renderCustomEffectEditor(parent, effectEntry)
    local readOnlyAttrs = {
        "EffectName",
        "Icon",
        "Uuid",
    }
    local readOnlyContents = {}
    for _, attrName in ipairs(readOnlyAttrs) do
        readOnlyContents[attrName] = effectEntry[attrName]
    end
    ImguiElements.AddReadOnlyAttrTable(parent, readOnlyContents)

    local boneInputs = {
        "SourceBone",
        "TargetBone",
    }

    local aligned = ImguiElements.AddAlignedTable(parent)

    for _, name in ipairs(boneInputs) do
        local input = EffectTabComponents:AddBoneInput(aligned, name, effectEntry[name])
        input.OnChange = function ()
            effectEntry[name] = input.Text
        end
    end

    local scalarFields = {
        Scale = { min=0, max=10, step=0.1 },
        Duration = { min=0, max=60000, step=100 }
    }

    if not effectEntry.isLoop then
        scalarFields.Duration = nil
    end

    for fieldName, params in pairs(scalarFields) do
        aligned:AddSliderWithStep(fieldName, effectEntry[fieldName] or 0, params.min, params.max, params.step, false).OnChange = function (s)
            effectEntry[fieldName] = s.Value[1]
        end
    end

    local boolTable = ImguiElements.AddAlignedTable(parent)
    local boolFields = {
        [1] = "None",
        [2] = "atObject",
        [3] = "atPosition"
    }

    local boolNames = {
        [1] = GetLoca("At Object"),
        [2] = GetLoca("At Caster"),
        [3] = GetLoca("At Position"),
    }

    local boolHints = {
        [1] = GetLoca("Play On Caster"),
        [2] = GetLoca("Play At Caster's Position and Orientation"),
        [3] = GetLoca("Play At Caster's Position"),
    }

    local newLine = boolTable:AddNewLine("Play Flags")

    --- @type RadioButtonOption[]
    local options = {}
    local initValue = 1
    for idx, field in ipairs(boolFields) do
        --- @type RadioButtonOption
        local option = {
            Label = boolNames[idx],
            Value = idx,
            Tooltip = boolHints[idx],
        }
        table.insert(options, option)
        if effectEntry[field] then
            initValue = idx
        end
    end

    local radioGroup = ImguiElements.AddEnumRadioButtons(newLine, options, initValue)
    radioGroup.OnChange = function (radioBtn, value)
        for idx, field in ipairs(boolFields) do
            if field ~= "None" then
                effectEntry[field] = (value == idx)
            end
        end
    end

    if effectEntry.isBeam then
        boolTable.Visible = false
    end

    local debugTable = ImguiElements.AddTree(parent, "Debug")

    debugTable.OnHoverEnter = function()
        debugTable:Tooltip():AddText("Debug Options for Effect")
        debugTable.OnHoverEnter = function() end
    end

    debugTable.OnExpand = function()
        local alignedTab = ImguiElements.AddAlignedTable(debugTable)
        local attrFields = {
            isBeam = "Is Beam",
            isLoop = "Is Loop",
        }
        for attrName, displayName in pairs(attrFields) do
            local checkBox = alignedTab:AddCheckbox(displayName, effectEntry[attrName] or false)
            checkBox.OnChange = function ()
                effectEntry[attrName] = checkBox.Checked
            end
        end
        debugTable.OnExpand = function() end
    end
end

--- @param parent ExtuiTreeParent
function CustomEffectTab:RenderProfileTab(parent)
    local entry = self.entry
    local imageGroup = parent:AddGroup("Icon##" .. self.uuid)
    local imageHeader = imageGroup:AddImage(entry.Icon, IMAGESIZE.LARGE)
    
    local function renameIcon() end

    local function iconHeaderOnDragDrop(sel, dropped)
        if not dropped.UserData or not dropped.UserData.Effect then return end
        local dropEffect = dropped.UserData.Effect
        if not dropEffect or not dropEffect.Icon then return end
        renameIcon(dropEffect.Icon)
    end

    local function updateImage()
        imageHeader:Destroy()
        imageHeader = imageGroup:AddImage(entry.Icon, IMAGESIZE.LARGE)

        imageHeader.DragDropType = EffectDragDropFlag
        imageHeader.OnDragDrop = iconHeaderOnDragDrop
    end

    imageHeader.DragDropType = EffectDragDropFlag
    imageHeader.OnDragDrop = iconHeaderOnDragDrop


    local function updateDisplayName()
        local lastPos, lastSize = self.panel.LastPosition, self.panel.LastSize
        WindowManager.DeleteWindow(self.panel)
        self.panel = WindowManager.RegisterWindow(self.uuid, entry.DisplayName, lastPos, lastSize)
        self.panel.Closeable = true
        self:Render(self.panel)
        self.panel.Open = true
    end

    local alignedTable = ImguiElements.AddAlignedTable(parent)
    alignedTable.SameLine = true

    local displayNameInput, valueCell = alignedTable:AddInputText("DisplayName", entry.DisplayName or "")
    displayNameInput.EnterReturnsTrue = true

    local function renameDisplayName()
        entry.DisplayName = displayNameInput.Text
        updateDisplayName()
        if self.OnChange then
            self:OnChange()
        end
    end

    displayNameInput.OnChange = function ()
        if not displayNameInput.EnterReturnsTrue then return end
        renameDisplayName()
    end

    local iconInput = alignedTable:AddInputText("Icon", entry.Icon or "")
    iconInput.EnterReturnsTrue = true

    function renameIcon(newIcon)
        newIcon = newIcon or iconInput.Text
        local isIcon = RBCheckIcon(newIcon)
        if isIcon == RB_ICONS.Box then
            iconInput.Text = entry.Icon
            return
        end
        entry.Icon = newIcon
        iconInput.Text = newIcon
        updateImage()
        if self.OnChange then
            self:OnChange()
        end
    end

    iconInput.OnChange = function ()
        if not iconInput.EnterReturnsTrue then return end
        renameIcon()
    end

    local descriptionInput = alignedTable:AddInputText("Description", entry.Description or "")
    descriptionInput.OnChange = function ()
        entry.Description = descriptionInput.Text
        if self.OnChange then
            self:OnChange()
        end
    end
end

--- @param parent ExtuiTreeParent
function CustomEffectTab:RenderControlPanel(parent)
    local leftGroup = parent:AddGroup("Controls##" .. self.uuid)
    local rightGroup = parent:AddGroup("Loop Controls##" .. self.uuid)
    rightGroup.SameLine = true
    local playBtn = leftGroup:AddButton("Play Effect##" .. self.uuid)
    playBtn.OnClick = function()
        self:PlayEffect()
    end

    local function clearHandles()
        NetChannel.StopEffect:SendToServer({ Type = "Handles", Handles = self.loopHandles or {} })
        self.loopHandles = {}
    end

    local stopAllBtn = leftGroup:AddButton("Stop All Effects##" .. self.uuid)
    stopAllBtn.OnClick = function()
        clearHandles()
    end

    local loopIntervalInput = rightGroup:AddInputInt("Loop Interval (ms)", 6000)
    loopIntervalInput.ItemWidth = 300 * SCALE_FACTOR
    local loopTimer = nil

    local beginLabel = "Start Looping"
    local stopLabel = "Stop Looping"

    local loopPlayBtn = rightGroup:AddButton(beginLabel)

    local function stopLooping()
        Timer:Cancel(loopTimer)
        loopTimer = nil
        loopPlayBtn.Label = beginLabel
        clearHandles()
    end

    loopPlayBtn.OnClick = function()
        if loopTimer then
            stopLooping()
            return
        end

        loopTimer = Timer:Every(loopIntervalInput.Value[1], function ()
            clearHandles()

            if IsInCharacterCreationMirror() or IsIsPhotoMode() then
                return stopLooping()
            end

            self:PlayEffect()
        end)
        loopPlayBtn.Label = stopLabel
    end
end

--- @param parent ExtuiTreeParent
function CustomEffectTab:RenderEffectList(parent)
    local childWindow = parent:AddChildWindow("Effects##" .. self.uuid)

    local effectListTable = self.entry.Effects
    local managePopup = nil
    local selectedEntry = nil
    local effectManager = RB_GLOBALS.MultiEffectManager

    local refreshFn = function() end
    local function openManagePopup()
        if managePopup == nil then
            managePopup = childWindow:AddPopup("ManageEffectsPopup")
            local ctxMenu = ImguiElements.AddContextMenu(managePopup, "Effect")

            ctxMenu:AddItem(GetLoca("Clear All"), function (selectable)
                for k,v in pairs(effectListTable) do
                    effectListTable[k] = nil
                end
                refreshFn()
            end)

            ctxMenu:AddItem(GetLoca("Remove Selected"), function (selectable)
                if selectedEntry ~= nil then
                    table.remove(effectListTable, selectedEntry)
                    selectedEntry = nil
                    refreshFn()
                end
            end)
        end

        managePopup:Open()
    end

    local refreshListFn
    refreshListFn = EffectTabComponents:AddEffectList(childWindow:AddGroup("Effects"), "Effects", effectListTable,
    function(tree, effectEntry, idx)
        local renderEditorFunc = function ()
            renderCustomEffectEditor(tree, effectEntry)
        end
        tree.OnRightClick = function ()
            selectedEntry = idx
            openManagePopup()
        end
        tree.OnExpand = function ()
            renderEditorFunc()
            renderEditorFunc = function () end
        end
    end,
    function (dropped, i)
        table.insert(effectListTable, dropped)
        refreshFn()
    end)

    refreshFn = function ()
        table.sort(effectListTable, function (a, b)
            if a.TimeOffset ~= b.TimeOffset then
                return (a.TimeOffset or 0) < (b.TimeOffset or 0)
            end

            return (a.EffectName or "") < (b.EffectName or "")
        end)
        refreshListFn()
    end

    EffectTabComponents:AddEffectListPlusCircle(childWindow:AddGroup("NewEffects"), function (droppedData)
        droppedData = RBUtils.DeepCopy(droppedData)
        local managerEntry = effectManager.Data[droppedData.Uuid]
        if managerEntry.isMultiEffect then
            for _, fxName in ipairs(managerEntry.FxNames) do
                local singleEffectEntry = effectManager.Data[fxName]
                if singleEffectEntry == nil then
                    goto continue
                end
                local singleEffectData = RBEffectUtils.CreateEffectDragDropDataFromEffect(singleEffectEntry)
                table.insert(effectListTable, singleEffectData)
                ::continue::
            end
        else
            table.insert(effectListTable, droppedData)
        end
        refreshFn()
    end)
end

function CustomEffectTab:Add(entry)
    local instance = self.new(entry)
    local window = instance.panel
    instance:Render(window)
    window.Open = true
    return instance
end

function CustomEffectTab:Focus()
    ImguiHelpers.FocusWindow(self.panel)
end

function CustomEffectTab:PlayEffect()
    local entry = self.entry
    for _, effectEntry in ipairs(entry.Effects) do
        local playData = RBEffectUtils.PlayEffectDragDropData(effectEntry)

        local casters = self.Casters or {}
        for caster, targets in pairs(casters) do
            playData.Object = { caster }
            playData.Target = targets

            self.loopHandles = self.loopHandles or {}
            if effectEntry.TimeOffset == nil or effectEntry.TimeOffset <= 0 then
                NetChannel.PlayEffect:RequestToServer({ playData }, function(handles)
                    for _, handle in ipairs(handles) do
                        table.insert(self.loopHandles, handle)
                    end
                end)
            else
                Timer:After(effectEntry.TimeOffset, function ()
                    NetChannel.PlayEffect:RequestToServer({ playData }, function(handles)
                        for _, handle in ipairs(handles) do
                            table.insert(self.loopHandles, handle)
                        end
                    end)
                end)
            end

        end
    end
end
