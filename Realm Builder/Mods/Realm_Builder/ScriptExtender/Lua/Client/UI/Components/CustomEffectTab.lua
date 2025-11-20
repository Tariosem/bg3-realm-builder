local EFFECTTAB_WIDTH = 1000 * SCALE_FACTOR
local EFFECTTAB_HEIGHT = 1200 * SCALE_FACTOR

CustomEffectTab = _Class("CustomEffectTab", EffectTab)

--- @class CustomEffectTab : EffectTab
function CustomEffectTab:__init(uuid, parent, displayName, searchData)
    EffectTab.__init(self, uuid, parent, displayName)

    self.isCustom = true
    self.isExist = true
    self.windowType = "Custom Effect Tab"
    self.searchData = searchData[uuid] or {} 

    self.icon = searchData[uuid].Icon or "Item_Unknown"
    self.displayName = searchData[uuid].DisplayName or displayName or "Unknown"
    self.Note = searchData[uuid].Note or ""
    self.Group = searchData[uuid].Group or ""
    self.Tags = searchData[uuid].Tags or {}
    self.description = searchData[uuid].Description or ""
end

function CustomEffectTab:RenderProfile()

    local leftAlignTable = self.IdsContainer:AddTable("LeftAlignTable", 2) --[[@as ExtuiTable]]
    leftAlignTable.ColumnDefs[1] = { WidthFixed = true }
    leftAlignTable.ColumnDefs[2] = { WidthStretch = true }
    local row = leftAlignTable:AddRow()
    local l1, r1 = row:AddCell(), row:AddCell()
    local l2, r2 = row:AddCell(), row:AddCell()
    local l3, r3 = row:AddCell(), row:AddCell()

    self.displayNameButton = AddSelectableButton(l1, GetLoca("Display Name"), function()
        local text = self.displayNameInput.Text
        if text and text ~= "" then
            self.displayName = text
            self:OnChange()
            self:Refresh()
        else
            self.displayNameInput.Text = self.displayName
        end
    end)
    self.displayNameButton:Tooltip():AddText(GetLoca("Change how this effect's name is displayed in the UI"))

    self.displayNameInput = r1:AddInputText("", self.displayName)
    self.displayNameInput.SameLine = true

    self.displayNameInputKeySub = SubscribeKeyInput({ Key = "RETURN"}, function()
        local ok, focus = pcall(function() return IsFocused(self.displayNameInput) end)
        if not ok then return UNSUBSCRIBE_SYMBOL end
        if focus then
            self.displayNameButton:OnClick()
        end
    end)

    self.iconNameButton = AddSelectableButton(l2, GetLoca("Icon"), function()
        local icon = CheckIcon(self.iconNameInput.Text, self.icon)
        if icon and icon ~= "" then
            self.icon = icon
            self.iconImage:Destroy()
            self.iconImage = self.iconContainer:AddImage(self.icon)
            self.iconImage.ImageData.Size = {EFFECTTAB_WIDTH * 0.15, EFFECTTAB_WIDTH * 0.15}
            self.iconImage.DragDropType = "EffectInfo"
            self.iconNameInput.Text = self.icon
            self.iconImage.OnDragDrop = function(empty, drop)
                local newIcon = drop.UserData.Icon
                self.iconNameInput.Text = newIcon
                self.iconNameButton.OnClick()
            end
            self:OnChange()
        else
            self.iconNameInput.Text = self.Icon
        end
    end)

    self.iconNameButton:Tooltip():AddText(GetLoca("Change this effect's icon, you can choose icon from browsers"))
    self.iconNameInput = r2:AddInputText("", self.icon)
    self.iconNameInput.SameLine = true

    self.iconNameInputKeySub = SubscribeKeyInput({ Key = "RETURN"}, function()
        local ok, focus = pcall(function() return IsFocused(self.iconNameInput) end)
        if not ok then return UNSUBSCRIBE_SYMBOL end
        if focus then
            self.iconNameButton:OnClick()
        end
    end)


    self.descButton = AddSelectableButton(l3, GetLoca("Description"), function()
        local text = self.descInput.Text
        if text and text ~= "" then
            self.description = text
            self:OnChange()
        else
            self.descInput.Text = self.description or ""
        end
    end)
    self.descInput = r3:AddInputText("", self.description or "")
    self.descInput.SameLine = true

    self.descInputKeySub = SubscribeKeyInput({ Key = "RETURN"}, function()
        local ok, focus = pcall(function() return IsFocused(self.descInput) end)
        if not ok then return UNSUBSCRIBE_SYMBOL end
        if focus then
            self.descButton:OnClick()
        end
    end)

    self.iconImage.DragDropType = "EffectInfo"

    self.iconImage.OnDragDrop = function(empty, drop)
        local newIcon = drop.UserData.Icon
        self.iconNameInput.Text = newIcon
        self.iconNameButton.OnClick()
    end

    self.selfDestruction = self.profileTab:AddButton(GetLoca("Self Destruction"))
    ApplyDangerButtonStyle(self.selfDestruction)
    self.selfDestruction.OnClick = function()
        if self.isCustom then
            ConfirmPopup:DangerConfirm(
                GetLoca("Are you sure?"),
                function()
                    self:SelfDestruction()
                end
            )
        else
            Warning("[EffectTab] Cannot self-destruct a non-custom effect tab.")
        end
    end

    self:RenderFilter()
end

function CustomEffectTab:RenderFilter()
    self.filterTab = self.profileTab

    self.noteInput = self.filterTab:AddInputText(GetLoca("Note"))

    self.noteInput.Text = self.Note or ""

    self.noteInput.OnChange = function(text)
        self:SetNote(text.Text)
        self:OnChange()
    end

    self.groupInput = self.filterTab:AddInputText(GetLoca("Group"))

    self.groupInput.Text = self.Group or ""

    self.groupInput.OnChange = function(text)
        self:SetGroup(text.Text)
        self:Save()
        self:OnChange()
    end

    self.tagsInput = self.filterTab:AddInputText(GetLoca("Tags"))

    self.tagsAddButton = self.filterTab:AddButton("+")
    self.tagsRemoveButton = self.filterTab:AddButton(" - ")

    self.tagsAddTooltip = self.tagsAddButton:Tooltip()
    self.tagsAddTooltip:AddText(GetLoca("Add Tag"))
    self.tagsRemoveTooltip = self.tagsRemoveButton:Tooltip()
    self.tagsRemoveTooltip:AddText(GetLoca("Remove Tag"))


    self.tagsPrefix = self.filterTab:AddText(GetLoca("Tags") .. ":")
    self.allTags = self.filterTab:AddText(">")

    self.tagsPrefix.SameLine = true
    self.tagsRemoveButton.SameLine = true
    self.allTags.SameLine = true

    local function updateTags()
        local tags = self.Tags or {}
        local tagText = table.concat(tags, ", ")
        self.allTags.Text = tagText ~= "" and "Tags: " .. tagText or "Tags: None"
    end

    self.tagsInput.OnChange = function(text)
        if text.Text == "" then
            self.tagsAddButton.Disabled = true
            self.tagsRemoveButton.Disabled = true
        else
            self.tagsAddButton.Disabled = false
            self.tagsRemoveButton.Disabled = false
        end
    end

    self.tagsAddButton.OnClick = function()
        local tag = self.tagsInput.Text
        if tag and tag ~= "" then
            self:AddTagToData(tag)
            self.tagsInput.Text = ""
            updateTags()
            self:Save()
            self:OnChange()
        else
            Warning("[EntityTab] Cannot add empty tag for GUID: " .. self.guid)
        end
    end

    self.tagsRemoveButton.OnClick = function()
        local tag = self.tagsInput.Text
        if tag and tag ~= "" then
            self:RemoveTagFromData(tag)
            self.tagsInput.Text = ""
            self.tagsAddButton.Disabled = true
            self.tagsRemoveButton.Disabled = true
            updateTags()
            self:Save()
            self:OnChange()
        else
            Warning("[EntityTab] Cannot remove empty tag for GUID: " .. self.guid)
        end
    end

    self.tagsAddButton.Disabled = true
    self.tagsRemoveButton.Disabled = true

end

function CustomEffectTab:RenderEffects()
    local fxNames = self.searchData.fxNames or {}
    self.effectNameCnt = {}

    table.sort(fxNames, function(a, b)
       if a.TimeOffset and b.TimeOffset then
           if a.TimeOffset < b.TimeOffset then
               return true
           elseif a.TimeOffset > b.TimeOffset then
               return false
           end
       end
       return a.DisplayName < b.DisplayName
    end)

    if self.effectTimelineWin then
        self.effectTimelineWin:Destroy()
        self.effectTimelineWin = nil
    end

    self.effectTimelineWin = self.effectsInfoTab:AddChildWindow("EffectsTimeline")

    self.effectRoot = StyleHelpers.AddTree(self.effectTimelineWin, GetLoca("Effects List"))
    self.effectRoot:DestroyChildren()

    local root = self.effectRoot

    local clearAllButton = self.effectRoot:AddButton(GetLoca("Clear All Effects"))

    ApplyDangerButtonStyle(clearAllButton)
    clearAllButton.OnClick = function()
        ConfirmPopup:DangerConfirm(
            GetLoca("Are you sure you want to clear all effects?"),
            function()
                self.searchData.fxNames = {}
                self:OnChange()
                self:RenderEffects()
            end
        )
    end

    self.effectsInfos = {}

    local allPlayPosCheck = {}
    local allPlayPosRotCheck = {}

    local checkAllPlayAtPos = function(checked)
        for _, checkbox in ipairs(allPlayPosCheck) do
            checkbox.Checked = checked
        end
        for _, effectsInfo in ipairs(self.effectsInfos) do
            local userData = effectsInfo.UserData
            userData.PlayAtPosition = checked
        end
    end

    local checkAllPlayAtPosAndRot = function(checked)
        for _, checkbox in ipairs(allPlayPosRotCheck) do
            checkbox.Checked = checked
        end
        for _, effectsInfo in ipairs(self.effectsInfos) do
            local userData = effectsInfo.UserData
            userData.PlayAtPositionAndRotation = checked
        end
    end

    local checkAllPlayAtPosButton  = root:AddButton(GetLoca("Check All Play At Position"))
    checkAllPlayAtPosButton.OnClick = function()
        local allChecked = true
        for _, checkbox in ipairs(allPlayPosCheck) do
            if not checkbox.Checked then
                allChecked = false
                break
            end
        end
        checkAllPlayAtPos(not allChecked)
    end

    local checkAllPlayAtPosAndRotButton  = root:AddButton(GetLoca("Check All Play At Pos And Rot"))
    checkAllPlayAtPosAndRotButton.OnClick = function()
        local allChecked = true
        for _, checkbox in ipairs(allPlayPosRotCheck) do
            if not checkbox.Checked then
                allChecked = false
                break
            end
        end
        checkAllPlayAtPosAndRot(not allChecked)
    end

    checkAllPlayAtPosAndRotButton.SameLine = true
    checkAllPlayAtPosButton.SameLine = true

    for i, effectObj in ipairs(fxNames) do
        local effectTree = root:AddTree(effectObj.DisplayName)
        local effectIcon = effectTree:AddTreeIcon(effectObj.Icon, IMAGESIZE.ROW)
        effectTree.UserData = effectObj
        effectTree.UserData.isMultiEffect = false
        local userData = effectTree.UserData
        local oriData = GetDataFromUuid(effectObj.FxName) or {}
        table.insert(self.effectsInfos, effectTree)
        effectTree.CanDrag = true
        effectTree.DragDropType = "EffectInfo"

        effectTree.OnDragStart = function()
            effectTree.DragPreview:AddImage(userData.Icon)
        end

        effectTree.OnClick = function()
            self:PlayEffect(effectTree)
        end

        effectTree:Tooltip():AddText(GetLoca("Click to play effect, or drag to custom effect slot"))

        if self.cachedOpenTrees and self.cachedOpenTrees[effectObj.DisplayName] then
            effectTree:SetOpen(true)
        end

        effectTree.OnExpand = function()
            self.cachedOpenTrees[effectObj.DisplayName] = true
        end

        effectTree.OnCollapse = function()
            self.cachedOpenTrees[effectObj.DisplayName] = nil
        end

        local attrTable = StyleHelpers.AddAlignedTable(effectTree)

        local displayNameInput = attrTable:AddInputText(GetLoca("Display Name: "), effectObj.DisplayName)
        displayNameInput.OnClick = function()
            local text = displayNameInput.Text
            self.cachedOpenTrees[effectObj.DisplayName] = nil
            effectObj.DisplayName = text
            self.cachedOpenTrees[effectObj.DisplayName] = true
            self:OnChange()
            self:RenderEffects()
        end

        local fxNameInput = attrTable:AddInputText(GetLoca("FxName: "), effectObj.FxName)
        fxNameInput.ReadOnly = true

        local repeatSlider = attrTable:AddSliderInt(GetLoca("Repeat: "), math.floor(effectObj.Repeat) or 1, 1, 100)
        repeatSlider.OnChange = function(slider)
            effectObj.Repeat = slider.Value[1]
            self:OnChange()
        end

        local timeOffsetSlider = attrTable:AddSlider(GetLoca("Time Offset (s): "), (effectObj.TimeOffset or 0) / 1000, 0, 60, 0.1)
        timeOffsetSlider.OnChange = function(slider)
            effectObj.TimeOffset = slider.Value[1] * 1000
            self:OnChange()
        end
    

        local sourceBoneInput, sourceBoneCell = attrTable:AddInputText(GetLoca("Source Bone: "), tostring(effectObj.SourceBone))
        sourceBoneInput.OnChange = function(text)
            local input = text.Text
            if not input or input == "" then
                effectObj.SourceBone = nil
            else
                effectObj.SourceBone = input
            end
        end

        sourceBoneInput.OnRightClick = function(text)
            if text.Text and text.Text ~= "" then
                local bestMatch = FindBestMatchBone(text.Text)
                text.Text = bestMatch
                effectObj.SourceBone = bestMatch
                --userData.SourceBone = bestMatch
            end
        end

        local sourceBoneResetButton = sourceBoneCell:AddButton(GetLoca("Reset"))
        sourceBoneResetButton:Tooltip():AddText(GetLoca("Reset to default source bone"))
        sourceBoneResetButton.SameLine = true

        sourceBoneResetButton.OnClick = function()
            local data = GetDataFromUuid(effectObj.FxName)
            if data and data.SourceBone then
                effectObj.SourceBone = data.SourceBone
                --userData.SourceBone = data.SourceBone
                sourceBoneInput.Text = tostring(data.SourceBone)
            else
                effectObj.SourceBone = ""
                --userData.SourceBone = ""
                sourceBoneInput.Text = ""
            end
        end

        local targetBoneInput, targetBoneCell = attrTable:AddInputText(GetLoca("Target Bone: "), tostring(effectObj.TargetBone))

        targetBoneInput.IDContext = "EffectTargetBone"
        targetBoneInput.SameLine = true

        targetBoneInput.OnChange = function(text)
            local input = text.Text
            if not input or input == "" then
                effectObj.TargetBone = nil
                --userData.TargetBone = nil
            else
                effectObj.TargetBone = input
                --userData.TargetBone = input
            end
        end

        targetBoneInput.OnRightClick = function(text)
            if text.Text and text.Text ~= "" then
                local bestMatch = FindBestMatchBone(text.Text)
                text.Text = bestMatch
                effectObj.TargetBone = bestMatch
                --userData.TargetBone = bestMatch
            end
        end

        local targetBoneResetButton = targetBoneCell:AddButton(GetLoca("Reset"))

        targetBoneResetButton:Tooltip():AddText(GetLoca("Reset to default target bone"))
        targetBoneResetButton.SameLine = true

        targetBoneResetButton.OnClick = function()
            local data = GetDataFromUuid(effectObj.FxName)
            if data and data.TargetBone then
                effectObj.TargetBone = data.TargetBone
                --userData.TargetBone = data.TargetBone
                targetBoneInput.Text = data.TargetBone
            else
                effectObj.TargetBone = ""
                --userData.TargetBone = ""
                targetBoneInput.Text = ""
            end
        end

        local isLoop = userData.isLoop or false
        local isLoopCheckbox = effectTree:AddCheckbox(GetLoca("Loop"), isLoop)
        isLoopCheckbox:Tooltip():AddText(GetLoca("Status and prep effects usually need this checked to play."))
        isLoopCheckbox.OnChange = function(checkbox)
            isLoop = checkbox.Checked
            --userData.isLoop = isLoop
            effectObj.isLoop = isLoop
            self:OnChange()
        end

        local isBeam = userData.isBeam or oriData.isBeam or false
        local isBeamCheckbox = effectTree:AddCheckbox(GetLoca("Beam"), isBeam)
        isBeamCheckbox.SameLine = true
        isBeamCheckbox:Tooltip():AddText(GetLoca("Check if this effect is a beam effect."))
        isBeamCheckbox.OnChange = function(checkbox)
            isBeam = checkbox.Checked
            --userData.isBeam = isBeam
            effectObj.isBeam = isBeam
            self:OnChange()
        end

        local playAtPos = userData.PlayAtPosition or false
        local playAtPosCheckbox = effectTree:AddCheckbox(GetLoca("Play At Position"), playAtPos)
        playAtPosCheckbox.SameLine = true
        playAtPosCheckbox:Tooltip():AddText(GetLoca("Play at the caster's position instead of directly on them."))
        playAtPosCheckbox.OnChange = function(checkbox)
            playAtPos = checkbox.Checked
            --userData.PlayAtPosition = playAtPos
            effectObj.PlayAtPosition = playAtPos
            self:OnChange()
        end


        local PlayAtPositionAndRotation = userData.PlayAtPositionAndRotation or false
        local playAtPosAndRotCheckbox = effectTree:AddCheckbox(GetLoca("Play At Position and Rotation"), PlayAtPositionAndRotation)
        playAtPosAndRotCheckbox.SameLine = true
        playAtPosAndRotCheckbox:Tooltip():AddText(GetLoca("Play at the caster's position and rotation."))
        playAtPosAndRotCheckbox.OnChange = function(checkbox)
            PlayAtPositionAndRotation = checkbox.Checked
            --userData.PlayAtPositionAndRotation = PlayAtPositionAndRotation
            effectObj.PlayAtPositionAndRotation = PlayAtPositionAndRotation
            self:OnChange()
        end

        table.insert(allPlayPosCheck, playAtPosCheckbox)
        table.insert(allPlayPosRotCheck, playAtPosAndRotCheckbox)
        
        local scale = userData.Scale or 1.0
        local scaleInput = attrTable:AddSlider(GetLoca("Scale: "), scale, 0.1, 10.0, 0.1)
        scaleInput.IDContext = "EffectScale"
        scaleInput.SameLine = true

        scaleInput.OnChange = function(slider)
            scale = slider.Value[1]
            --userData.Scale = scale
            effectObj.Scale = scale
            self:OnChange()
        end

        local stopButton = effectTree:AddButton(GetLoca("Stop Same Effect"))
        stopButton:Tooltip():AddText(GetLoca("Stop all effects with the same FxName."))

        stopButton.OnClick = function()
            local postdata = {
                Type = "FxName",
                FxName = effectObj.FxName,
            }
            NetChannel.StopEffect(postdata)
        end

        local removeButton = effectTree:AddButton(GetLoca("Remove"))
        removeButton.SameLine = true

        
        ApplyDangerButtonStyle(removeButton)
        removeButton.SameLine = true
        removeButton:Tooltip():AddText(GetLoca("Remove this effect from the timeline"))
        removeButton.OnClick = function()
            ConfirmPopup:DangerConfirm(
                GetLoca("Are you sure you want to remove this effect?"),
                function()
                    table.remove(self.searchData.fxNames, i)
                    self:OnChange()
                    self:RenderEffects()
                end,
                nil)
        end

        effectTree:AddSeparator()
    end

    -- Add Effect Slot

    local emptyIcon = root:AddImageButton("EmptyEffect", RB_ICONS.Plus_Square, IMAGESIZE.ROW)
    emptyIcon:Tooltip():AddText(GetLoca("Drag an effect here, or paste an fx name into the box and click."))
    emptyIcon.DragDropType = "EffectInfo"
    emptyIcon.CanDrag = true

    emptyIcon.OnDragDrop = function(empty, drop)
        local data = drop.UserData
        local fxNames = data.FxName
        if not fxNames or fxNames == "" then
            local uuid = data.Uuid
            local libData = GetDataFromUuid(uuid)
            if not libData then
                Warning("[EffectTab] Cannot find effect data for UUID: " .. tostring(uuid))
                return
            end
            fxNames = libData and libData.fxNames or data.FxName
        end
        if type(fxNames) == "string" then
            fxNames = {fxNames}
        end
        for _, fxName in ipairs(fxNames) do
            local libData = GetDataFromUuid(fxName)
            local entry = {
                Uuid = fxName,
                FxName = fxName,
                TemplateName = (libData and libData.TemplateName) or data.TemplateName or fxName,
                DisplayName = (libData and libData.DisplayName) or data.DisplayName or fxName,
                Icon = (libData and libData.Icon) or data.Icon or "Item_Unknown",
                TargetBone = (libData and libData.TargetBone) or data.TargetBone or "",
                SourceBone = (libData and libData.SourceBone) or data.SourceBone or "",
                isBeam = data.isBeam or false,
                isLoop = data.isLoop or false,
                isMultiEffect = (libData and libData.isMultiEffect) or data.isMultiEffect or false,
            }
            if entry.Icon == "" or entry.Icon == "Item_Unknown" then
                entry.Icon = data.Icon or "Item_Unknown"
            end
            table.insert(self.searchData.fxNames, entry)
        end
        --_D(libData)
        self:RenderEffects()
        self:OnChange()
    end

    local emptyIconInput = root:AddInputText("", "")
    emptyIconInput.SameLine = true

    emptyIconInput.IDContext = "EmptyEffectInput"

    emptyIcon.OnClick = function()
        local fxName = emptyIconInput.Text
        if not fxName or fxName == "" then
            return
        end
        local data = GetDataFromUuid(fxName)
        data = data or {}
        local entry = {
            FxNames = fxName,
            DisplayName = data.DisplayName or fxName,
            Icon = data.Icon or "Item_Unknown",
            TargetBone = data.TargetBone or "",
            SourceBone = data.SourceBone or "",
            isBeam = data.isBeam or false,
            isLoop = data.isLoop or false,
        }
        table.insert(self.searchData.fxNames, entry)
        self:RenderEffects()
        self:OnChange()
    end
end

function CustomEffectTab:Add(uuid, parent, displayName, searchData, statsType)
    local exist, tab = CheckWindowExists(uuid, "Custom Effect Tab")
    if exist then
        return tab
    end
    if statsType then
        return StatsTab:Add(uuid, parent, displayName, searchData, statsType)
    end
    tab = CustomEffectTab.new(uuid, parent, displayName, searchData)
    tab:Render()
    tab.panel.Open = false
    return tab
end
