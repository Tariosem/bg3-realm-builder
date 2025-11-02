StatsTab = _Class("StatsTab", CustomEffectTab)
SpellTab = _Class("SpellTab", StatsTab)
StatusTab = _Class("StatusTab", StatsTab)

--- @class StatsTab : CustomEffectTab
function StatsTab:__init(uuid, parent, displayName, searchData, statsType)
    CustomEffectTab.__init(self, uuid, parent, displayName, searchData)

    self.searchData.StatsType = statsType
    self.searchData.fxGroupType = self.searchData.fxGroupType or {}

    self.isStatus = statsType == "StatusData"
    self.isSpell = statsType == "SpellData"

    self.cachedOpenCPs = {}
    self.effectTypeCells = {}
    self.cachedCP = {}
    self.cachedTables = {}
    self.cachedCells = {}
end

--- @class SpellTab : StatsTab
function SpellTab:__init(uuid, parent, displayName, searchData)
    StatsTab.__init(self, uuid, parent, displayName, searchData, "SpellData")

    self.spellAtPos = false
    self.searchData.SpellAnimation = self.searchData.SpellAnimation or "Drop here"
    self.searchData.WeaponTypes = self.searchData.WeaponTypes or "Melee"
    self.searchData.Sheathing = self.searchData.Sheathing or "Melee"
    self.searchData.AreaRadius = self.searchData.AreaRadius or 9
    self.searchData.TargetRadius = self.searchData.TargetRadius or 18
    self.searchData.FXScale = self.searchData.FXScale or 1

end

--- @class StatusTab : StatsTab
function StatusTab:__init(uuid, parent, displayName, searchData)
    StatsTab.__init(self, uuid, parent, displayName, searchData, "StatusData")

    self.searchData.Duration = self.searchData.Duration or 10
end

function StatusTab:_subclassChange()
    self.displayNameButton.OnClick = function()
        local text = self.displayNameInput.Text
        if text and text ~= "" then
            self:_stopAllStatus()
            self.displayName = text
            self:OnChange()
            self:Refresh()
        else
            self.displayNameInput.Text = self.displayName
        end
    end
end

function StatsTab:_subclassChange()
end

function StatsTab:Add(uuid, parent, displayName, searchData, statsType)
    local exist, tab = CheckWindowExists(uuid, "Custom Effect Tab")
    if exist then
        return tab
    end
    if statsType == "SpellData" then
        tab = SpellTab.new(uuid, parent, displayName, searchData)
    elseif statsType == "StatusData" then
        tab = StatusTab.new(uuid, parent, displayName, searchData)
    else
        Warning("StatsTab:Add: Invalid statsType: " .. tostring(statsType))
        return nil
    end
    if not tab then
        Warning("StatsTab:Add: Failed to create tab for statsType: " .. tostring(statsType))
        return nil
    end
    tab:Render()
    tab:_subclassChange()
    tab.panel.Open = false
    return tab
end

function StatusTab:Add(uuid, parent, displayName, searchData)
    return StatsTab.Add(self, uuid, parent, displayName, searchData, "StatusData")
end

function SpellTab:Add(uuid, parent, displayName, searchData)
    return StatsTab.Add(self, uuid, parent, displayName, searchData, "SpellData")
end

function StatsTab:RenderEffects()
    local effectTypes = Enums[self.searchData.StatsType]
    if not effectTypes then
        return {}
    end

    local tempArray = {}
    for k,v in SortedPairs(effectTypes) do
        table.insert(tempArray, k)
    end

    self.effectTimelineWin = self.effectTimelineWin or self.effectsInfoTab:AddChildWindow("EffectsTimeline")

    local effectsTable = self.effectTimelineWin:AddTable("EffectTable", 1)

    self.effectRow = effectsTable:AddRow()

    local clickDestroy = function(t)
        t:Destroy()
    end

    local warningCell = self.effectRow:AddCell()
    warningCell = warningCell:AddImage(WARNING_ICON)
    warningCell.ImageData.Size = {32 * SCALE_FACTOR, 32 *SCALE_FACTOR}
    warningCell.OnClick = clickDestroy
    warningCell = warningCell:Tooltip()
    warningCell:AddText("For each effect type, you can select only one MultiEffect, ")
    warningCell:AddText("or multiple single effects.")
    warningCell:AddText("Drag and drop effects from the browser")
    warningCell:AddText("For bone input, right-click to find the best matching bone.")

    return tempArray
end

function SpellTab:RenderEffects()
    local effectTypeArray = StatsTab.RenderEffects(self)

    local spellEffectWhitelist = {
        BeamEffect = true,
        TargetEffect = true,
        CastEffect = true,
        HitEffect = true,
        PositionEffect = true,
        SpellEffect = true,
    }

    for _, effectType in ipairs(effectTypeArray) do
        if spellEffectWhitelist[effectType] then
            self:RenderEffectType(effectType)
        end
    end

end

function StatusTab:RenderEffects()
    local effectTypeArray = StatsTab.RenderEffects(self)

    local statusEffectWhitelist = {
        StatusEffect = true,
    }

    for _, effectType in ipairs(effectTypeArray) do
        if statusEffectWhitelist[effectType] then
            self:RenderEffectType(effectType)
        end
    end
end

function StatsTab:RenderEffectType(effectType)
    local cell = self.cachedCells[effectType] or self.effectRow:AddCell(effectType .. "Cell")
    self.cachedCells[effectType] = cell
    local collaspingHeader = self.cachedCP[effectType] or cell:AddCollapsingHeader(effectType .. "##" .. effectType)
    self.cachedCP[effectType] = collaspingHeader
    local childTable = self.cachedTables[effectType]
    if childTable then
        childTable:Destroy()
        self.cachedTables[effectType] = nil
    end
    childTable = collaspingHeader:AddTable(effectType .. "Table", 1)
    self.cachedTables[effectType] = childTable
    local effectRow = childTable:AddRow()
    local childCell = effectRow:AddCell(effectType .. "ChildCell")

    --local titleSeparator = cell:AddSeparatorText(effectType)
    if not self.cachedOpenCPs[effectType] then
        self.cachedOpenCPs[effectType] = {}
    end

    local effectTypeData = self.searchData.fxNames[effectType]
    local effectGroupType = self.searchData.fxGroupType[effectType]

    if effectGroupType == "MultiEffect" then
        self:RenderMultiEffectType(childCell, effectType, effectTypeData)
    else
        self:RenderSingleEffectType(childCell, effectType, effectTypeData)
    end

end

function StatsTab:RenderSingleEffectType(cell, effectType)
    local parent = cell
    local effectGroupTable = parent:AddTable(effectType .. "effectsGroup", 1)
    local effectGroupRow = effectGroupTable:AddRow()
    local effectTypeData = self.searchData.fxNames[effectType] or {}

    if next(effectTypeData) then
        local theFirstCell = effectGroupRow:AddCell()
        local clearAllButton = theFirstCell:AddButton(GetLoca("ClearAll"))

        ApplyDangerButtonStyle(clearAllButton)
        clearAllButton.OnClick = function()
            ConfirmPopup:DangerConfirm(
                GetLoca("Are you sure you want to clear all effects of this type?"), 
                function()
                    self.searchData.fxNames[effectType] = {}
                    self.searchData.fxGroupType[effectType] = nil
                    self:RenderEffectType(effectType)
                    self:OnChange()
                end
            )
        end

        theFirstCell:AddSeparator()
    end

    local sortedNames = {}
    for name,_ in pairs(effectTypeData) do
        table.insert(sortedNames, name)
    end
    table.sort(sortedNames, function (a, b)
        return a < b
    end)

    for _, name in ipairs(sortedNames) do
        local data = effectTypeData[name]
        local effectCell = effectGroupRow:AddCell()
        local effectButton = effectCell:AddImageButton(name, data.Icon)
        effectButton.DragDropType = "EffectInfo"
        effectButton.UserData = data
        effectButton.Image.Size = {64 * SCALE_FACTOR, 64 * SCALE_FACTOR}
        effectButton.CanDrag = true
        effectButton.OnDragDrop = function(button, drop)
            self:ProcessDropData(effectType, drop.UserData, data)
        end

        effectButton.OnDragStart = function(button)
            effectButton.DragPreview:AddImage(data.Icon)
        end

        local effectHeader = effectCell:AddTree(name)
        effectHeader.SpanTextWidth = true

        if self.cachedOpenCPs[effectType][name] then
            effectHeader:SetOpen(true)
        end

        effectHeader.OnExpand = function()
            self.cachedOpenCPs[effectType][name] = true
        end

        effectHeader.OnCollapse = function()
            self.cachedOpenCPs[effectType][name] = false
        end

        effectHeader.IDContext = "EffectHeader_" .. name
        effectHeader.SameLine = true

        local displayNameInputPrefix = effectHeader:AddButton(GetLoca("DisplayName") .. ":")
        local displayNameInput = effectHeader:AddInputText("", data.DisplayName or "")
        displayNameInput.SameLine = true
        displayNameInput.IDContext = "DisplayNameInput_" .. name

        displayNameInputPrefix.OnClick = function()
            local input = displayNameInput.Text
            if input == "" or input == effectHeader.Label then
                return
            end
            local savedData = effectTypeData[name]
            local newName = self:GetUniqueNameInType(input, effectType, name)
            savedData.DisplayName = newName
            effectTypeData[newName] = savedData
            effectHeader.Label = newName
            self.cachedOpenCPs[effectType][name] = nil
            self.cachedOpenCPs[effectType][newName] = true
            self:RenderEffectType(effectType)
            self:OnChange()
        end

        local boneInputPrefix = effectHeader:AddText("Bone:")
        local boneInput = effectHeader:AddInputText("", data.Bone or "")
        boneInput.SameLine = true
        boneInput.IDContext = "BoneInput_" .. name

        boneInput.OnChange = function(text)
            local input = text.Text
            if not input or input == "" then
                effectTypeData[name].Bone = nil
            else
                effectTypeData[name].Bone = input
            end
        end

        
        boneInput.OnRightClick = function()
            if boneInput.Text and boneInput.Text ~= "" then
                local bestMatch = ParseBoneList(boneInput.Text)
                boneInput.Text = bestMatch
                effectTypeData[name].Bone = bestMatch
            end
            self:OnChange()
        end

        local removeButton = effectCell:AddButton(GetLoca("Remove"))
        removeButton.SameLine = true

        ApplyDangerButtonStyle(removeButton)
        removeButton.OnClick = function()
            ConfirmPopup:DangerConfirm(
                GetLoca("Are you sure you want to remove this effect?"), 
                function()
                    effectTypeData[name] = nil
                    self:RenderEffectType(effectType)
                    self:OnChange()
                end
            )
        end
        effectCell:AddSeparator()
    end

    self:RenderEmptyIcon(effectGroupRow, effectType)
end

function StatsTab:RenderMultiEffectType(cell, effectType)
    local parent = cell
    local effectGroupTable = parent:AddTable(effectType .. "effectsGroup", 1)
    local effectGroupRow = effectGroupTable:AddRow()
    local effectTypeData = self.searchData.fxNames[effectType]

    for name, data in pairs(effectTypeData) do
        local effectCell = effectGroupRow:AddCell()
        local effectButton = effectCell:AddImageButton(name .. "EffectInfoIcon", data.Icon)
        effectButton.Image.Size = {64 * SCALE_FACTOR, 64 * SCALE_FACTOR}
        effectButton.DragDropType = "EffectInfo"
        effectButton.UserData = data
        effectButton.Image.Size = {64 * SCALE_FACTOR, 64 * SCALE_FACTOR}
        effectButton.CanDrag = true
        effectButton.OnDragDrop = function(button, drop)
            self:ProcessDropData(effectType, drop.UserData, data)
        end
        effectButton.OnDragStart = function(button)
            effectButton.DragPreview:AddImage(data.Icon)
        end

        local effectHeader = effectCell:AddTree(name)
        effectHeader.SpanTextWidth = true
        effectHeader.IDContext = "EffectHeader_" .. name
        effectHeader.SameLine = true

        if self.cachedOpenCPs[effectType][name] then
            effectHeader:SetOpen(true)
        end

        effectHeader.OnExpand = function()
            self.cachedOpenCPs[effectType][name] = true
        end

        effectHeader.OnCollapse = function()
            self.cachedOpenCPs[effectType][name] = false
        end

        local displayNameInputPrefix = effectHeader:AddButton(GetLoca("DisplayName") .. ":")
        local displayNameInput = effectHeader:AddInputText("", data.DisplayName or "")
        displayNameInput.SameLine = true
        displayNameInput.IDContext = "DisplayNameInput_" .. name

        displayNameInputPrefix.OnClick = function()
            local input = displayNameInput.Text
            if input == "" or input == effectHeader.Label then
                return
            end
            local savedData = effectTypeData[name]
            local newName = self:GetUniqueNameInType(input, effectType, name)
            savedData.DisplayName = newName
            effectTypeData[newName] = savedData
            effectCell:Destroy()
            self.cachedOpenCPs[effectType][name] = nil
            self.cachedOpenCPs[effectType][newName] = true
            self:RenderEffectType(effectType)
            self:OnChange()
        end

        local removeButton = effectCell:AddButton(GetLoca("Remove"))
        removeButton.SameLine = true

        ApplyDangerButtonStyle(removeButton)
        removeButton.OnClick = function()
            ConfirmPopup:DangerConfirm(
                GetLoca("Are you sure you want to remove this effect?"), 
                function()
                    effectTypeData[name] = nil
                    self:RenderEffectType(effectType)
                    self:OnChange()
                end
            )
        end
        --return
    end

    if not effectTypeData or next(effectTypeData) == nil then
        self:RenderEmptyIcon(effectGroupRow, effectType)
    end
end

function StatsTab:RenderControlPanel()
    self.playButton = self.effectsInfoTab:AddButton(GetLoca("Play"))

    self.playButton.OnClick = function()
        self:Play()
    end
end

function StatusTab:RenderControlPanel()
    StatsTab.RenderControlPanel(self)

    local durationSlider = self.effectsInfoTab:AddSlider(GetLoca("Duration"), self.searchData.Duration or 10, 10, 60000)
    durationSlider.SameLine = true
    durationSlider:Tooltip():AddText("Enter -1 for infinite duration.")
    local stopButton = self.effectsInfoTab:AddButton(GetLoca("Stop"))

    durationSlider.OnChange = function(slider)
        self.searchData.Duration = slider.Value[1]
    end

    stopButton.OnClick = function()
        self:_stopAllStatus()
    end

end

function SpellTab:RenderControlPanel()
    StatsTab.RenderControlPanel(self)

    local playAtPositionCheckbox = self.effectsInfoTab:AddCheckbox(GetLoca("Play at Position"), self.spellAtPos)
    playAtPositionCheckbox.SameLine = true
    playAtPositionCheckbox.OnChange = function(checkbox)
        self.spellAtPos = checkbox.Checked
    end

    local animationInput = self.effectsInfoTab:AddInputText(GetLoca("Animation"), self.searchData.SpellAnimation or GetLoca("Drop here"))
    local weaponTypeInput = self.effectsInfoTab:AddInputText(GetLoca("Weapon Type"), self.searchData.WeaponTypes or "")
    local sheathInput = self.effectsInfoTab:AddCombo(GetLoca("Sheath"))
    sheathInput.Options = {"Melee", "Ranged", "Instrument", "Sheathed", "WeaponSet", "Somatic", "DontChange"}
    animationInput.DragDropType = "EffectInfo"
    animationInput.OnDragDrop = function(input, drop)
        local data = drop.UserData
        if data and data.Uuid then
            local animSet = GetEffectAnimation(data.Uuid)
            self.searchData.SpellAnimation = animSet and animSet.SpellAnimation or nil
            self.searchData.WeaponTypes = animSet and animSet.WeaponAttack or nil
            self.searchData.Sheathing = animSet and animSet.Sheathing or nil
            animationInput.Text = animSet and animSet.SpellAnimation or ""
            SetCombo(sheathInput, animSet and animSet.Sheathing or "Melee", true)
            self:OnChange() 
        end
    end

    animationInput.OnChange = function(input)
        self.searchData.SpellAnimation = input.Text
    end
    weaponTypeInput.OnChange = function(input)
        self.searchData.WeaponTypes = input.Text
    end
    weaponTypeInput.Visible = false
    sheathInput.OnChange = function(input)
        self.searchData.Sheathing = GetCombo(input)
    end

    local areaRadiusSlider = AddSliderWithStep(self.effectsInfoTab, "AreaRadius", self.searchData.AreaRadius or 9, 1, 100, 1, true)
    areaRadiusSlider.OnChange = function(slider)
        self.searchData.AreaRadius = slider.Value[1]
    end
    self.effectsInfoTab:AddText(GetLoca("Hit Radius")).SameLine = true

    local targetRadiusSlider = AddSliderWithStep(self.effectsInfoTab, "TargetRadius", self.searchData.TargetRadius or 18, 1, 100, 1, true)
    targetRadiusSlider.OnChange = function(slider)
        self.searchData.TargetRadius = slider.Value[1]
    end
    self.effectsInfoTab:AddText(GetLoca("Target Radius")).SameLine = true

    --[[local fxScaleSlider = AddSliderWithStep(self.effectsInfoTab, "FXScale", self.searchData.FXScale or 1, 1, 10, 1, true)
    fxScaleSlider.OnChange = function(slider)
        self.searchData.FXScale = slider.Value[1]
    end
    self.effectsInfoTab:AddText(GetLoca("FX Scale")).SameLine = true]]
end

function StatusTab:_stopStatus()
    local postData = {
        Object = self:GetSelectedObjects(),
        DisplayName = self.displayName
    }
    NetChannel.StopStatus:SendToServer(postData)
end

function StatusTab:_stopAllStatus()
    NetChannel.StopStatus:SendToServer({ DisplayName = self.displayName })
end

function StatsTab:RenderEmptyIcon(row, effectType)
    local emptyCell = row:AddCell()

    local emptyIcon = emptyCell:AddImageButton("EmptyIcon", "Action_RegainHP")
    emptyIcon.Image.Size = {64 * SCALE_FACTOR, 64 * SCALE_FACTOR}

    emptyIcon.DragDropType = "EffectInfo"

    emptyIcon.OnDragDrop = function(empty, drop)
        -- Always add new data instead of replacing
        self:ProcessDropData(effectType, drop.UserData)
    end

    local emptyInput = emptyCell:AddInputText("")
    emptyInput.SameLine = true
    emptyInput.IDContext = "EmptyInput_" .. effectType

    emptyIcon.OnClick = function()
        local input = emptyInput.Text
        if input and input ~= "" then
            local data = GetDataFromUuid(input)
            if not data then
                data = GetDataFromName(input)
            end
            if not data then return end
            local dropdata = {
                Uuid = data.Uuid,
                TemplateName = data.TemplateName,
                DisplayName = data.DisplayName or input,
                Icon = data.Icon or "Item_Unknown",
                isMultiEffect = data.isMultiEffect or false
            }
            emptyInput.Text = ""
            self:ProcessDropData(effectType, dropdata)
        end
    end
end

function StatsTab:ProcessDropData(effectType, data)
    local searchData = self.searchData
    if searchData.fxNames[effectType] == nil then
        searchData.fxNames[effectType] = {}
    end
    local theName = data.isMultiEffect and data.DisplayName or data.TemplateName
    local newName = self:GetUniqueNameInType(theName, effectType)
    local newEntry = {
        DisplayName = newName,
        Uuid = data.Uuid,
        TemplateName = data.TemplateName or data.Uuid,
        Icon = data.Icon,
        isMultiEffect = data.isMultiEffect or false,
        Bone = data.Bone or data.SourceBone or data.TargetBone or nil,
        FxName = data.FxName or nil,
    }
    if data.isMultiEffect then
        searchData.fxNames[effectType] = {}

        searchData.fxNames[effectType][newEntry.DisplayName] = newEntry

        searchData.fxGroupType[effectType] = "MultiEffect"
    else
        if searchData.fxGroupType[effectType] == "MultiEffect" then
            searchData.fxNames[effectType] = {}
        end

        searchData.fxNames[effectType][newEntry.DisplayName] = newEntry

        searchData.fxGroupType[effectType] = "SingleEffect"
    end

    self:RenderEffectType(effectType)
    self:OnChange()
end

function StatsTab:GetUniqueNameInType(name, effectType, discard)
    local data = self.searchData.fxNames[effectType]
    if not data then
        return name
    end

    if discard then
        self.searchData.fxNames[effectType][discard] = nil
    end

    local count = 1
    local uniqueName = name
    while data[uniqueName] do
        uniqueName = name .. " (" .. count .. ")"
        count = count + 1
    end

    return uniqueName
end

function StatsTab:Play()
    local postData = {}
    local searchData = self.searchData
    postData.Type = searchData.StatsType
    for effectType, multiData in pairs(self.searchData.fxNames) do
        local effectTypeValue = ""
        if searchData.fxGroupType[effectType] == "MultiEffect" then
            for _,data in pairs(multiData) do
                effectTypeValue = data.Uuid 
            end
        else
            for _,data in pairs(multiData) do
                local bone = data.Bone
                local bones = ParseBoneList(bone, true)
                local newString = nil
                if bones then
                    newString = data.TemplateName .. ":" .. bones .. ";"
                else
                    newString = data.TemplateName ..  ";"
                end
                effectTypeValue = effectTypeValue and effectTypeValue .. newString or newString
            end
        end
        if effectTypeValue and effectTypeValue:sub(-1) == ";" then
            effectTypeValue = effectTypeValue:sub(1, -2)
        end
        postData[effectType] = effectTypeValue
    end
    postData.Object = self:GetSelectedObjects()
    postData.Target = self:GetSelectedTargets()
    postData.DisplayName = self.displayName

    return postData
end

function SpellTab:Play()
    local postData = StatsTab.Play(self)

    postData.SpellAnimation = self.searchData.SpellAnimation ~= GetLoca("Drop here") and self.searchData.SpellAnimation or nil
    postData.WeaponTypes = self.searchData.WeaponTypes
    postData.Sheathing = self.searchData.Sheathing
    postData.AreaRadius = self.searchData.AreaRadius or 9
    postData.TargetRadius = tostring(self.searchData.TargetRadius) or "18"
    postData.FXScale = self.searchData.FXScale or 1

    NetChannel.CreateStat:SendToServer(postData)
end

function StatusTab:Play()
    local postData = StatsTab.Play(self)

    postData.Duration = self.searchData.Duration or 10

    NetChannel.CreateStat:SendToServer(postData)
end