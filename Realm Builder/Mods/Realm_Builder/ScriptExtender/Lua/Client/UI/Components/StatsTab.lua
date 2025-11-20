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

    self.cachedExpandedTrees = {}
    self.effectTypeCells = {}
    self.cachedTrees = {}
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
    self.effectRoot = StyleHelpers.AddTree(self.effectTimelineWin, "Timeline", true)

    local warningCell = self.effectRoot:Tooltip()
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
    local effectTypeTree = self.cachedTrees[effectType] or self.effectRoot:AddTree(effectType .. "##" .. effectType)
    self.cachedTrees[effectType] = effectTypeTree
    effectTypeTree:DestroyChildren()

    effectTypeTree.OnRightClick = function ()
        self.selectedEffectData = nil
        self.selectedEffectType = effectType
        self:OpenEffectContextMenu()
    end
    effectTypeTree.OnHoverEnter = function ()
        self.isFocused = true
        self.selectedEffectData = nil
        self.selectedEffectType = effectType
    end
    effectTypeTree.OnHoverLeave = function ()
        self.isFocused = false
        self.selectedEffectData = nil
        self.selectedEffectType = nil
    end

    if not self.cachedExpandedTrees[effectType] then
        self.cachedExpandedTrees[effectType] = {}
    end

    local effectTypeData = self.searchData.FxNames[effectType]
    local effectGroupType = self.searchData.fxGroupType[effectType]

    if effectGroupType == "MultiEffect" then
        self:RenderMultiEffectType(effectTypeTree, effectType, effectTypeData)
    else
        self:RenderSingleEffectType(effectTypeTree, effectType, effectTypeData)
    end

end

function StatsTab:SetupEffectTreeBehaviors(effectTree, effectType, name)
    local data = effectTree.UserData

    effectTree.OnDragDrop = function(button, drop)
        self:ProcessDropData(effectType, drop.UserData, data)
    end

    effectTree.OnDragStart = function(sel)
        sel.DragPreview:AddImage(data.Icon)
    end

    effectTree.OnRightClick = function ()
        self.selectedEffectData = data
        self.selectedEffectType = effectType
        self:OpenEffectContextMenu()
    end

    effectTree.OnHoverEnter = function ()
        self.isFocused = true
    end
    effectTree.OnHoverLeave = function ()
        self.isFocused = false
    end

    effectTree.OnExpand = function()
        self.cachedExpandedTrees[effectType][name] = true
    end
    effectTree.OnCollapse = function()
        self.cachedExpandedTrees[effectType][name] = false
    end

    if self.cachedExpandedTrees[effectType][name] then
        effectTree:SetOpen(true)
    end
end

--- @param parent RB_UI_Tree
function StatsTab:RenderSingleEffectType(parent, effectType)
    local effectTypeData = self.searchData.FxNames[effectType] or {}

    local sortedNames = {}
    for name,_ in pairs(effectTypeData) do
        table.insert(sortedNames, name)
    end
    table.sort(sortedNames, function (a, b)
        return a < b
    end)

    for _, name in ipairs(sortedNames) do
        local data = effectTypeData[name]
        local effectTree = parent:AddTree(name)
        local effectIcon = effectTree:AddTreeIcon(data.Icon, IMAGESIZE.ROW)
        effectTree.DragDropType = "EffectInfo"
        effectTree.UserData = data
        effectTree.CanDrag = true

        self:SetupEffectTreeBehaviors(effectTree, effectType, name)

        local attrTable = StyleHelpers.AddAlignedTable(effectTree)
        local displayNameInput = attrTable:AddInputText(GetLoca("DisplayName"), data.DisplayName or "")
        displayNameInput.SameLine = true
        displayNameInput.IDContext = "DisplayNameInput_" .. name
        displayNameInput.OnClick = function()
            local input = displayNameInput.Text
            if input == "" or input == data.DisplayName then
                return
            end
            local savedData = effectTypeData[name]
            local newName = self:GetUniqueNameInType(input, effectType, name)
            savedData.DisplayName = newName
            effectTypeData[newName] = savedData
            self.cachedExpandedTrees[effectType][name] = nil
            self.cachedExpandedTrees[effectType][newName] = true
            self:RenderEffectType(effectType)
            self:OnChange()
        end

        local boneInput = attrTable:AddInputText(GetLoca("Bone"), data.Bone or "")
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
    end

    self:RenderEmptyIcon(parent, effectType)
end

--- @param parent RB_UI_Tree
function StatsTab:RenderMultiEffectType(parent, effectType)
    local effectTypeData = self.searchData.FxNames[effectType]

    for name, data in pairs(effectTypeData) do
        local effectTree = parent:AddTree(name .. "## " .. effectType .. name)
        local effectIcon = effectTree:AddTreeIcon(data.Icon, IMAGESIZE.ROW)
        effectTree.DragDropType = "EffectInfo"
        effectTree.UserData = data
        effectTree.CanDrag = true
        effectTree.IDContext = "EffectHeader_" .. name

        self:SetupEffectTreeBehaviors(effectTree, effectType, name)

        if self.cachedExpandedTrees[effectType][name] then
            effectTree:SetOpen(true)
        end

        local attrTable = StyleHelpers.AddAlignedTable(effectTree)

        local displayNameInput = attrTable:AddInputText(GetLoca("DisplayName"), data.DisplayName or "")
        displayNameInput.SameLine = true
        displayNameInput.IDContext = "DisplayNameInput_" .. name

        displayNameInput.OnClick = function()
            local input = displayNameInput.Text
            if input == "" or input == data.DisplayName then
                return
            end
            local savedData = effectTypeData[name]
            local newName = self:GetUniqueNameInType(input, effectType, name)
            savedData.DisplayName = newName
            effectTypeData[newName] = savedData
            self.cachedExpandedTrees[effectType][name] = nil
            self.cachedExpandedTrees[effectType][newName] = true
            self:RenderEffectType(effectType)
            self:OnChange()
        end
        --return
    end

    if not effectTypeData or next(effectTypeData) == nil then
        self:RenderEmptyIcon(parent, effectType)
    end
end

function StatsTab:RenderControlPanel(parent)
    self.playButton = parent:AddButton(GetLoca("Play"))

    self.playButton.OnClick = function()
        self:Play()
    end
end

function StatusTab:RenderControlPanel(parent)
    StatsTab.RenderControlPanel(self, parent)

    local durationSlider = parent:AddSlider(GetLoca("Duration"), self.searchData.Duration or 10, 10, 60000)
    durationSlider.SameLine = true
    durationSlider:Tooltip():AddText("Enter -1 for infinite duration.")
    local stopButton = parent:AddButton(GetLoca("Stop"))

    durationSlider.OnChange = function(slider)
        self.searchData.Duration = slider.Value[1]
    end

    stopButton.OnClick = function()
        self:_stopAllStatus()
    end

end

function SpellTab:RenderControlPanel(parent)
    StatsTab.RenderControlPanel(self, parent)

    local playAtPositionCheckbox = parent:AddCheckbox(GetLoca("Play at Position"), self.spellAtPos)
    playAtPositionCheckbox.SameLine = true
    playAtPositionCheckbox.OnChange = function(checkbox)
        self.spellAtPos = checkbox.Checked
    end

    local animationInput = parent:AddInputText(GetLoca("Animation"), self.searchData.SpellAnimation or GetLoca("Drop here"))
    local weaponTypeInput = parent:AddInputText(GetLoca("Weapon Type"), self.searchData.WeaponTypes or "")
    local sheathInput = parent:AddCombo(GetLoca("Sheath"))
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

    local areaRadiusSlider = StyleHelpers.AddSliderWithStep(parent, "AreaRadius", self.searchData.AreaRadius or 9, 1, 100, 1, true)
    areaRadiusSlider.OnChange = function(slider)
        self.searchData.AreaRadius = slider.Value[1]
    end
    parent:AddText(GetLoca("Hit Radius")).SameLine = true

    local targetRadiusSlider = StyleHelpers.AddSliderWithStep(parent, "TargetRadius", self.searchData.TargetRadius or 18, 1, 100, 1, true)
    targetRadiusSlider.OnChange = function(slider)
        self.searchData.TargetRadius = slider.Value[1]
    end
    parent:AddText(GetLoca("Target Radius")).SameLine = true
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

function StatsTab:SetupEffectContextMenu()
    local parent = self.effectTimelineWin:AddPopup("EffectContextMenu")
    self.contextMenu = parent
    local contextMenu = StyleHelpers.AddContextMenu(parent, "Effect")

    --- @type RB_ContextItem[]
    local contextItems = {
        {
            Label = GetLoca("Remove"),
            OnClick = function()
                local effectType = self.selectedEffectType

                if self.selectedEffectData then
                    ConfirmPopup:DangerConfirm(
                        GetLoca("Remove this effect?"), 
                        function()
                            self.searchData.FxNames[effectType][self.selectedEffectData.DisplayName] = nil
                            self:RenderEffectType(effectType)
                            self:OnChange()
                            self.selectedEffectData = nil
                        end
                    )
                else
                    ConfirmPopup:DangerConfirm(
                        GetLoca("Clear all?"),
                        function()
                            self.searchData.FxNames[effectType] = {}
                            self.searchData.fxGroupType[effectType] = nil
                            self:RenderEffectType(effectType)
                            self:OnChange()
                            self.selectedEffectData = nil
                        end
                    )
                end
            end,
            Danger = true,
            Hint = "Del",
            HotKey = {
                Key = "DEL"
            }
        }
    }

    contextMenu:AddContext(contextItems, function()
        return self.isFocused
    end)

    return contextMenu
end

function StatsTab:OpenEffectContextMenu()
    if not self.contextMenu then
        self:SetupEffectContextMenu()
    end
    if self.contextMenu then
        self.contextMenu:Open()
    end
end

function StatsTab:RenderEmptyIcon(parent, effectType)
    local emptyIcon = parent:AddImageButton("EmptyIcon", RB_ICONS.Plus_Circle_Fill, IMAGESIZE.ROW)
    StyleHelpers.SetupImageButton(emptyIcon)
    emptyIcon.IDContext = "EmptyIcon_" .. effectType

    emptyIcon.DragDropType = "EffectInfo"

    emptyIcon.OnDragDrop = function(empty, drop)
        -- Always add new data instead of replacing
        self:ProcessDropData(effectType, drop.UserData)
    end

    local emptyInput = parent:AddInputText("")
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
    if searchData.FxNames[effectType] == nil then
        searchData.FxNames[effectType] = {}
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
        searchData.FxNames[effectType] = {}

        searchData.FxNames[effectType][newEntry.DisplayName] = newEntry

        searchData.fxGroupType[effectType] = "MultiEffect"
    else
        if searchData.fxGroupType[effectType] == "MultiEffect" then
            searchData.FxNames[effectType] = {}
        end

        searchData.FxNames[effectType][newEntry.DisplayName] = newEntry

        searchData.fxGroupType[effectType] = "SingleEffect"
    end

    self:RenderEffectType(effectType)
    self:OnChange()
end

function StatsTab:GetUniqueNameInType(name, effectType, discard)
    local data = self.searchData.FxNames[effectType]
    if not data then
        return name
    end

    if discard then
        self.searchData.FxNames[effectType][discard] = nil
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
    for effectType, multiData in pairs(self.searchData.FxNames) do
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