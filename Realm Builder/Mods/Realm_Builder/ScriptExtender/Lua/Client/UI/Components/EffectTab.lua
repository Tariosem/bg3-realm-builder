local EFFECTTAB_WIDTH = 1000 * SCALE_FACTOR
local EFFECTTAB_HEIGHT = 1200 * SCALE_FACTOR

EffectTab = _Class("EffectTab")

--- @class EffectTab
function EffectTab:__init(uuid, parent, displayName)
    self.guid = uuid or ""
    local templateData = GetDataFromUuid(self.guid) or {}
    self.displayName = displayName or templateData.DisplayName or "Unknown"

    self.panel = nil
    self.windowType = "Effect Tab"
    self.isValid = true
    self.isWindow = false
    self.isAttach = false
    self.parent = parent or nil
    self.icon = templateData and templateData.Icon or "Item_Unknown"
    self.templateName = templateData and templateData.TemplateName or "Unknown"

    self.scanPropOnly = true
    self.defaultObject = {}
    self.defaultTarget = {}
    self.effects = {}
    self.repeatDelay = 1000
    self.repeatTimer = nil

    self.Note = templateData and templateData.Note or ""
    self.Group = templateData and templateData.Group or ""
    self.Tags = templateData and templateData.Tags or {}

    self.cachedOpenCPs = {}

    if templateData then
        self.isCustom = false
    else
        self.isCustom = true
    end
end

function EffectTab:Render()
    self.isVisible = true

    if self.parent and self.isAttach then
        self.panel = self.parent:AddTabItem(self.displayName)
        self.isWindow = false
    else
        if self.isCustom then
            self.panel = RegisterWindow(self.guid, self.displayName, self.windowType, self, self.lastPosition, self.lastSize)
        else 
            self.panel = RegisterWindow(self.guid, self.displayName, self.windowType, self, self.lastPosition, self.lastSize)

            self.panel.OnClose = function()
                self:Destroy()
            end
        end
        self.panel.Closeable = true
        self.panel:SetSize({EFFECTTAB_WIDTH, EFFECTTAB_HEIGHT})

        self.isWindow = true
    end

    self.uniTabBar = self.panel:AddTabBar("EffectTabBar")


    self.profileTab = self.uniTabBar:AddTabItem(GetLoca("Profile"))

    self.profile = self.profileTab:AddTable("EffectTabProfile", 2)

    self.profile.ColumnDefs[1] = { WidthStretch = false, WidthFixed = true }
    self.profile.ColumnDefs[2] = { WidthStretch = true }

    self.profileRow = self.profile:AddRow()
    self.iconContainer = self.profileRow:AddCell()
    self.iconImage = self.iconContainer:AddImage(self.icon)
    self.iconImage.ImageData.Size = {EFFECTTAB_WIDTH * 0.15, EFFECTTAB_WIDTH * 0.15}

    self.IdsContainer = self.profileRow:AddCell()

    self:RenderProfile()
    self:RenderEffectsTab()
end

function EffectTab:RenderProfile()
    local leftAlighTable = self.IdsContainer:AddTable("", 2)
    leftAlighTable.ColumnDefs[1] = { WidthStretch = false, WidthFixed = true }
    leftAlighTable.ColumnDefs[2] = { WidthStretch = true }
    
    -- Display Name
    local row1 = leftAlighTable:AddRow()
    row1:AddCell():AddText(GetLoca("Display Name: "))
    self.displayNameInput = AddPrefixInput(row1:AddCell(), nil, self.displayName, true)

    -- Icon
    local row2 = leftAlighTable:AddRow()
    row2:AddCell():AddText(GetLoca("Icon: "))
    self.iconNameInput = AddPrefixInput(row2:AddCell(), nil, self.icon, true)

    -- Template Name
    local templateName = RB_MultiEffectManager.Data[self.guid] and RB_MultiEffectManager.Data[self.guid].TemplateName or "Unknown"
    local row3 = leftAlighTable:AddRow()
    row3:AddCell():AddText(GetLoca("Effect Name: "))
    self.templateNameText = AddPrefixInput(row3:AddCell(), nil, templateName, true)

    -- Uuid
    local row4 = leftAlighTable:AddRow()
    row4:AddCell():AddText(GetLoca("Uuid: "))
    self.uuidText = AddPrefixInput(row4:AddCell(), nil, self.guid, true)
end

function EffectTab:RenderEffectsTab()
    self.effectsInfoTab = self.uniTabBar:AddTabItem(GetLoca("Effects"))

    local topTree = StyleHelpers.AddTree(self.effectsInfoTab, GetLoca("General"))

    self.selectionHeader = topTree:AddTree(GetLoca("Caster and Target"))

    self:CreatePicker("defaultObject", GetLoca("Caster"), self.selectionHeader)

    if not self.isStatus then
        self:CreatePicker("defaultTarget", GetLoca("Target"), self.selectionHeader)
    end

    self:RenderControlPanel(topTree:AddTree(GetLoca("Control Panel")))

    self.effectsInfoTab:AddSeparatorText(GetLoca("Effects Timeline"))

    self:RenderEffects()
end

function EffectTab:RenderEffects()
    local FxNames = GetDataFromUuid(self.guid).FxNames or {}

    self.effectsTimelineWin = self.effectsInfoTab:AddChildWindow("EffectsTimeline")

    self.effectsRoot = StyleHelpers.AddTree(self.effectsTimelineWin, GetLoca("Effects List"))
    self.effectsRoot:DestroyChildren()

    self.effectsInfos = {}

    for _, fxName in ipairs(FxNames) do
        local data = RB_MultiEffectManager.Data[fxName]
        local effectTree = self.effectsRoot:AddTree(data.DisplayName or fxName)
        local effectIcon = effectTree:AddTreeIcon(self.icon, IMAGESIZE.ROW)
        effectTree.UserData = { 
            Icon = self.icon,
            Uuid = self.guid,
            TemplateName = data.TemplateName,
            FxName = fxName, 
            DisplayName = data.DisplayName or fxName, 
            Repeat = data.Repeat or 1, 
            SourceBone = data.SourceBone or "", 
            TargetBone = data.TargetBone or "",
            Bone = data.TargetBone,
            isMultiEffect = data.isMultiEffect,
            isLoop = data.isLoop,
            isBeam = data.isBeam
        }
        table.insert(self.effectsInfos, effectTree)
        effectTree.CanDrag = true
        effectTree.DragDropType = "EffectInfo"

        effectTree.OnDragStart = function(sel)
            sel.DragPreview:AddImage(effectTree.UserData.Icon)
        end

        effectTree.OnClick = function()
            effectTree.Selected = false
            self:PlayEffect(effectTree)
        end

        StyleHelpers.AddReadOnlyAttrTable(effectTree, {
            [GetLoca("Fx Name")] = effectTree.UserData.FxName,
            [GetLoca("Name")] = effectTree.UserData.TemplateName,
            [GetLoca("Source Bone")] = effectTree.UserData.SourceBone,
            [GetLoca("Target Bone")] = effectTree.UserData.TargetBone,
            [GetLoca("Repeat Count")] = effectTree.UserData.Repeat,
        })

        effectTree:AddSeparator()
    end
end

function EffectTab:RenderControlPanel(parent)
    self.playButton = parent:AddButton(GetLoca("Play"))

    self.playButton.OnClick = function()
        self:Play()
    end

    self.repeatDelay = self.repeatDelay or 1000
    local repeatPlayButton = parent:AddButton(GetLoca("Timed Repeat"))
    parent:AddText("Repeat Interval (s)")
    local repeatDelaySlider = StyleHelpers.AddSliderWithStep(parent, nil, self.repeatDelay / 1000, 0.1, 60, 0.1)
    

    local stopAllButton = parent:AddButton(GetLoca("Stop All"))
    
    repeatPlayButton.OnClick = function()
        if self.repeatTimer then
            Timer:Cancel(self.repeatTimer)
            self.repeatTimer = nil

            repeatPlayButton.Label = GetLoca("Timed Repeat")
            return 
        end

        if self.repeatDelay > 100 then
            self.repeatTimer = Timer:Every(self.repeatDelay, function ()
                if not self:Play() then
                    Timer:Cancel(self.repeatTimer)
                    self.repeatTimer = nil
                else
                end
            end)
            repeatPlayButton.Label = GetLoca("Stop Repeating")
        else
        
        end
    end

    repeatDelaySlider.OnChange = function ()
        self.repeatDelay = repeatDelaySlider.Value[1] * 1000
    end

    stopAllButton.OnClick = function ()
        local toStop = {}
        for _, info in ipairs(self.effectsInfos) do
            local userData = info.UserData
            if userData and userData.FxName then
                table.insert(toStop, userData.FxName)
            end
        end
        local postdata = {
            Type = "FxName",
            FxName = toStop,
        }
        NetChannel.StopEffect:SendToServer(postdata)
    end

end

function EffectTab:RegisterEffectName(fxName, displayName, discardName)

    if not displayName then
        displayName = fxName
    end
    if self.effectNameCnt == nil then
        self.effectNameCnt = {}
    end

    if discardName then
        self:RemoveEffectName(fxName, displayName)
    end

    if not self.effectNameCnt[displayName] then
        self.effectNameCnt[displayName] = 0
    end

    self.effectNameCnt[displayName] = self.effectNameCnt[displayName] + 1

    if self.effectNameCnt[displayName] > 1 then
        return displayName .. " (" .. self.effectNameCnt[displayName] .. ")"
    else
        return displayName
    end
end

function EffectTab:RemoveEffectName(fxName, displayName)
    if not self.effectNameCnt or not self.effectNameCnt[fxName] then
        return
    end

    self.effectNameCnt[displayName] = self.effectNameCnt[displayName] - 1
    if self.effectNameCnt[displayName] <= 0 then
        self.effectNameCnt[displayName] = nil
    end
end

function EffectTab:CreatePicker(fieldName, labelText, parent)
    local uiTable = nil

    if parent then
        parent:AddText(labelText)
        uiTable = parent:AddTable(fieldName .. "Table", 1)
    else 
        self.effectsInfoTab:AddText(labelText)
        uiTable = self.effectsInfoTab:AddTable(fieldName .. "Table", 1)
    end

    uiTable.SameLine = true

    self[fieldName] = self[fieldName] or {}

    local row = uiTable:AddRow()

    local selectedCell = row:AddCell()

    local defaultNames = selectedCell:AddText("> None")

    local selectedTable = selectedCell:AddTable(fieldName .. "SelectedTable", 1)
    selectedTable.SameLine = true
    local selectedRow = selectedTable:AddRow()

    local comboCell = row:AddCell()

    local combo = NearbyCombo.new(comboCell)
    combo.ExcludeCamera = true

    defaultNames.Label = "> " .. table.concat(self[fieldName] or {}, ", ")

    local function updateTextContent()
        if selectedRow then
            selectedRow:Destroy()
        end
        selectedRow = selectedTable:AddRow()
        local cell = selectedRow:AddCell()
        if self[fieldName] and #self[fieldName] > 0 then
            defaultNames.Label = "> "
            for i, name in ipairs(self[fieldName]) do
                if i > 1 then
                    cell:AddText(", ").SameLine = true
                end
                local guid = GetGuidFromDisplayName(name)
                local tempImage = cell:AddImage(GetIcon(guid), IMAGESIZE.ROW)
                local tempText = cell:AddText(name)
                if i > 1  and i % 4 ~= 0 then
                    tempImage.SameLine = true
                end
                tempText.SameLine = true
            end
        else
            defaultNames.Label = "> None"
        end
    end

    combo.OnChange = function(text, guid, displayName)
        if not guid or guid == "" then
            return
        end
        if not displayName or displayName == "" then
            return
        end
        if not self[fieldName] then
            self[fieldName] = {}
        end
        ToggleEntry(self[fieldName], displayName)

        updateTextContent()
        self:OnChange()
    end

    if not self.updatePickerTextFns then
        self.updatePickerTextFns = {}
    end

    table.insert(self.updatePickerTextFns, function()
        updateTextContent()
    end)

    updateTextContent()
end

function EffectTab:GetSelectedGuids(field)
    local guids = {}
    for _, name in ipairs(self[field] or {}) do
        local guid = GetGuidFromDisplayName(name)
        if guid then
            table.insert(guids, guid)
        end
    end
    return guids
end

function EffectTab:GetSelectedObjects()
    local guids = {}
    for _,name in ipairs(self.defaultObject) do
        local guid = GetGuidFromDisplayName(name)
        if guid then
            table.insert(guids, guid)
        end
    end
    if guids == nil or #guids == 0 then
        guids = {CGetHostCharacter()}
    end
    return guids
end

function EffectTab:GetSelectedTargets()
    local guids = {}
    for _,name in ipairs(self.defaultTarget) do
        local guid = GetGuidFromDisplayName(name)
        if guid then
            table.insert(guids, guid)
        end
    end
    if guids == nil or #guids == 0 then
        guids = {CGetHostCharacter()}
    end
    return guids
end

function EffectTab:Add(uuid, parent, displayName)
    local exist, existTab = CheckWindowExists(uuid, "Effect Tab")
    if exist then
        if existTab then
            existTab:Focus()
        end
        return nil
    end
    local tab = EffectTab.new(uuid, parent, displayName)
    tab:Render()
    return tab
end

function EffectTab:SelfDestruction()
    if self.isExist then
        self:Collapsed()
        self.isExist = false
        self:OnChange()
        if self.repeatTimer then
            Timer:Cancel(self.repeatTimer)
            self.repeatTimer = nil
        end
    end
end

function EffectTab:Destroy()
    if self.isValid then
        self:Collapsed()
        self.isValid = false
        if self.repeatTimer then
            Timer:Cancel(self.repeatTimer)
            self.repeatTimer = nil
        end
    end
end

function EffectTab:Focus()
    if self.isWindow then
        FocusWindow(self.panel)
    else
        self.panel.SetSelected = true
        Timer:After(100, function()
            if self.panel and self.panel.SetSelected then
                self.panel.SetSelected = false
            end
        end)
    end
end

function EffectTab:Close()
    if self.parent and not self.isAttach and self.isWindow then
        self.panel.Open = false
    end
end

function EffectTab:Collapsed()
    if not self.isValid then
        return
    end

    if self.effectTimelineWin then
        self.effectTimelineWin:Destroy()
        self.effectTimelineWin = nil
    end

    if self.displayNameInputKeySub then
        self.displayNameInputKeySub:Unsubscribe()
        self.displayNameInputKeySub = nil
    end

    if self.iconNameInputKeySub then
        self.iconNameInputKeySub:Unsubscribe()
        self.iconNameInputKeySub = nil
    end

    if self.descInputKeySub then
        self.descInputKeySub:Unsubscribe()
        self.descInputKeySub = nil
    end

    self.updatePickerTextFns = {}
    self.cachedCP = {}
    self.cachedCells = {}
    self.cachedTables = {}
    
    if self.isWindow then
        DeleteWindow(self.panel)
        self.panel = nil
    else
        self.panel:Destroy()
        self.panel = nil
    end

    self.isVisible = false
end

function EffectTab:Refresh()
    self.lastPosition = self.panel.LastPosition
    self.lastSize = self.panel.LastSize
    self:Collapsed()
    self:Render()
end

function EffectTab:SetGroup(group)
    if self.isCustom then
        self.Group = group or ""
        if self.groupInput then
            self.groupInput.Text = self.Group
        end
    else
    end
end

function EffectTab:SetNote(note)
    if self.isCustom then
        self.Note = note or ""
        if self.noteInput then
            self.noteInput.Text = self.Note
        end
    else
    end
end

function EffectTab:AddTagToData(tag)
    if self.isCustom then
        if not self.Tags then
            self.Tags = {}
        end
        if not Contains(self.Tags, tag) then
            table.insert(self.Tags, tag)
            if self.tagsInput then
                self.tagsInput.Text = ""
            end
        end
    else
    end
end

function EffectTab:RemoveTagFromData(tag)
    if self.isCustom then
        if self.Tags and TableContains(self.Tags, tag) then
            ToggleEntry(self.Tags, tag)
            if self.tagsInput then
                self.tagsInput.Text = ""
            end
        end
    else
    end
end

function EffectTab:PlayEffect(userdata)
    local objs = self:GetSelectedGuids("defaultObject")
    local targets = self:GetSelectedGuids("defaultTarget")

    if #objs == 0 then
        objs = {CGetHostCharacter()}
    end

    if #targets == 0 then
        targets = {CGetHostCharacter()}
    end

    local info = userdata.UserData
    local tags = {}
    local fxNameData = RB_MultiEffectManager.Data[info.FxName] or {}
    local data = {
        Object = objs,
        Target = targets,
        FxName = info.FxName,
        Scale = info.Scale or 1.0,
        SourceBone = info.SourceBone or fxNameData.SourceBone,
        TargetBone = info.TargetBone or fxNameData.TargetBone,
    }
    if info.isLoop then
        tags.PlayLoop = info.isLoop
    end
    if info.PlayAtPosition then
        tags.PlayAtPosition = info.PlayAtPosition
    end
    if info.PlayAtPositionAndRotation then
        tags.PlayAtPositionAndRotation = info.PlayAtPositionAndRotation
    end
    if fxNameData.isBeam then
        tags.PlayBeamEffect = true
    end
    data.Tags = tags

    local timeOffset = info.TimeOffset or 0
    if timeOffset == 0 then
        NetChannel.PlayEffect:SendToServer({data})
    else
        Timer:After(timeOffset, function()
            NetChannel.PlayEffect:SendToServer({data})
        end)
    end

    return true
end

function EffectTab:Play()
    local objs = self:GetSelectedGuids("defaultObject")
    local targets = self:GetSelectedGuids("defaultTarget")

    if #objs == 0 then
        objs = {CGetHostCharacter()}
    end

    if #targets == 0 then
        targets = {CGetHostCharacter()}
    end

    local immediateEffects = {}
    local delayedEffects = {}

    for _, userdata in ipairs(self.effectsInfos) do
        local info = userdata.UserData
        local tags = {}
        local libData = RB_MultiEffectManager.Data[info.FxName] or {}

        local data = {
            Object = objs,
            Target = targets,
            FxName = info.FxName,
            Scale = info.Scale or 1.0,
            SourceBone = info.SourceBone or (libData and libData.SourceBone) or "",
            TargetBone = info.TargetBone or (libData and libData.TargetBone) or "",
        }
        
        if info.isLoop then
            tags.PlayLoop = info.isLoop
        end
        if info.PlayAtPosition then
            tags.PlayAtPosition = info.PlayAtPosition
        end
        if info.PlayAtPositionAndRotation then
            tags.PlayAtPositionAndRotation = info.PlayAtPositionAndRotation
        end
        if libData and libData.isBeam then
            tags.PlayBeamEffect = true
        end
        data.Tags = tags

        local timeOffset = info.TimeOffset or 0
        local repeatCount = info.Repeat or 1

        if timeOffset == 0 then
            for i = 1, repeatCount do
                table.insert(immediateEffects, data)
            end
        else
            table.insert(delayedEffects, {
                data = data,
                offset = timeOffset,
                repeatCnt = repeatCount
            })
        end
    end

    if #immediateEffects > 0 then
        NetChannel.PlayEffect:SendToServer(immediateEffects)
    end

    for _, delayedEffect in ipairs(delayedEffects) do
        Timer:After(delayedEffect.offset, function()
            local effects = {}
            for i = 1, delayedEffect.repeatCnt do
                table.insert(effects, delayedEffect.data)
            end
            NetChannel.PlayEffect:SendToServer(effects)
        end)
    end

    return true
end

function EffectTab:OnChange() end