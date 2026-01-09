--- @class StatsTab : CustomEffectTab
--- @field entry RB_CustomStatsData
--- @field new fun(entry: RB_CustomStatsData): StatsTab
--- @field Add fun(entry: RB_CustomStatsData): StatsTab
local StatsTab = _Class("StatsTab", CustomEffectTab)

--- @class SpellTab : StatsTab
--- @field entry RB_CustomSpellData
--- @field new fun(entry: RB_CustomSpellData): SpellTab
--- @field Add fun(entry: RB_CustomSpellData): SpellTab
SpellTab = _Class("SpellTab", StatsTab)

--- @class StatusTab : StatsTab
--- @field entry RB_CustomStatusData
--- @field new fun(entry: RB_CustomStatusData): StatusTab
--- @field Add fun(entry: RB_CustomStatusData): StatusTab
StatusTab = _Class("StatusTab", StatsTab)

--- @class RB_CustomStatsData : RB_CustomEffectData
--- @field Effects table<string, RB_EffectDragDropData[]>
--- @field StatsType "SpellData"|"StatusData"

--- @class RB_CustomSpellData : RB_CustomStatsData
--- @field SpellAnimation string
--- @field WeaponTypes string
--- @field Sheathing SpellSheathing
--- @field AreaRadius number
--- @field TargetRadius number
--- @field FXScale number

--- @class RB_CustomStatusData : RB_CustomStatsData
--- @field Duration number

--- @type table<SpellEffectType, boolean>
local spellActiveEffectTypes = {
    BeamEffect = true,
    TargetEffect = true,
    CastEffect = true,
    HitEffect = true,
    PositionEffect = true,
    SpellEffect = true,
    PrepareEffect = true,
}

--- @type table<StatusEffectType, boolean>
local statusActiveEffectTypes = {
    StatusEffect = true,
}

--- @type table<"SpellData"|"StatusData", table<string, boolean>>
local activeEffectTypes = {
    SpellData = spellActiveEffectTypes,
    StatusData = statusActiveEffectTypes,
}

function StatsTab:RenderEffectList(parent)
    local entry = self.entry
    local childWindow = parent:AddChildWindow("EffectListWindow")
    local effectList = ImguiElements.AddTree(childWindow, "Effects")

    local activeList = activeEffectTypes[entry.StatsType] or {}

    local allEffectTypes = {}
    for effectType, _ in pairs(entry.Effects) do
        table.insert(allEffectTypes, effectType)
    end
    table.sort(allEffectTypes)


    for _, effectType in ipairs(allEffectTypes) do
        if activeList[effectType] then
            self:RenderEffectTypeList(effectList, effectType)
        end
    end

    local hiddenEffectList = ImguiElements.AddTree(childWindow, "Other Effects")
    hiddenEffectList.OnExpand = function ()
        for _, effectType in ipairs(allEffectTypes) do
            if not activeList[effectType] then
                self:RenderEffectTypeList(hiddenEffectList, effectType)
            end
        end
    end
end

local function renderStatsEffectEditor(parent, effectEntry)
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

    if effectEntry.isMultiEffect then
        return
    else
        local aligned = ImguiElements.AddAlignedTable(parent)

        local boneInput = EffectTabComponents:AddBoneInput(aligned, "Bone", effectEntry.Bone)
        boneInput.OnChange = function ()
            effectEntry.Bone = boneInput.Text
        end
    end
end

function StatsTab:RenderEffectTypeList(parent, effectType)
    local entry = self.entry
    entry.Effects[effectType] = entry.Effects[effectType] or {}
    local effectListTable = entry.Effects[effectType]

    local function clearTable()
        for k,v in pairs(effectListTable) do
            effectListTable[k] = nil
        end
    end

    --- @param dropped RB_EffectDragDropData
    local function handleDragDrop(dropped)
        if not dropped or not next(dropped) then
            return
        end
        dropped = RBUtils.DeepCopy(dropped)
        if dropped.isMultiEffect then
            clearTable()
            table.insert(effectListTable, dropped)
        else
            if effectListTable[1] and effectListTable[1].isMultiEffect then
                clearTable()
            end
            table.insert(effectListTable, dropped)
        end
    end

    local managePopup = nil
    local selectedEntry = nil
    --- @type fun()
    local refreshListFn

    local function openManagePopup()
        if managePopup == nil then
            managePopup = parent:AddPopup("ManageEffectsPopup")
            local ctxMenu = ImguiElements.AddContextMenu(managePopup, effectType)

            ctxMenu:AddItem(GetLoca("Clear All"), function (selectable)
                for k,v in pairs(effectListTable) do
                    effectListTable[k] = nil
                end
                refreshListFn()
            end)

            ctxMenu:AddItem(GetLoca("Remove Selected"), function (selectable)
                if selectedEntry ~= nil then
                    table.remove(effectListTable, selectedEntry)
                    selectedEntry = nil
                end
                refreshListFn()
            end)
        end

        managePopup:Open()
    end

    local subTree
    refreshListFn, subTree = EffectTabComponents:AddEffectList(parent, effectType, effectListTable, 
        function (tree, effectEntry, idx)
            tree.OnRightClick = function ()
                selectedEntry = idx
                openManagePopup()
            end
            renderStatsEffectEditor(tree, effectEntry)
        end,
        function (dropped)
            handleDragDrop(dropped)
            refreshListFn()
        end
    )

    subTree.DragDropType = EffectDragDropFlag
    --- @param dropped ExtuiStyledRenderable`
    subTree.OnDragDrop = function (sel, dropped)
        handleDragDrop(dropped.UserData.Effect)
        refreshListFn()
    end
end

--- @param obj RB_CustomStatsData
local function parseCustomStatsData(obj)
    local postData = {}
    postData.Type = obj.StatsType
    for effectType, multiData in pairs(obj.Effects) do
        local effectTypeValue = ""
        local isMultiEffect = false
        for _,data in pairs(multiData) do
            if data.isMultiEffect then
                isMultiEffect = true
                break
            end
        end
        if isMultiEffect then
            for _,data in pairs(multiData) do
                effectTypeValue = data.Uuid 
            end
        else
            for _,data in pairs(multiData) do
                local bone = data.Bone
                local bones = BoneHelpers.ParseBoneList(bone, true)
                local newString = nil
                if bones then
                    newString = data.EffectName .. ":" .. bones .. ";"
                else
                    newString = data.EffectName ..  ";"
                end
                effectTypeValue = effectTypeValue and effectTypeValue .. newString or newString
            end
        end
        if effectTypeValue and effectTypeValue:sub(-1) == ";" then
            effectTypeValue = effectTypeValue:sub(1, -2)
        end
        postData[effectType] = effectTypeValue
    end
    postData.Uuid = obj.Uuid

    return postData
end

--- @param obj RB_CustomSpellData
--- @return RB_CustomSpellData
local function parseSpellStatsData(obj)
    local data = parseCustomStatsData(obj)

    data.SpellAnimation = obj.SpellAnimation or nil
    data.WeaponTypes = obj.WeaponTypes
    data.Sheathing = obj.Sheathing
    data.AreaRadius = obj.AreaRadius or 9
    data.TargetRadius = tostring(obj.TargetRadius) or "18"
    data.FXScale = obj.FXScale or 1
    data.Icon = obj.Icon or "Skill_Wizard_LearnSpell"
    data.DisplayName = obj.DisplayName or ("RB_Spell_" .. obj.Uuid .. "_Name")
    data.PrepareEffectBone = obj.PrepareEffectBone or nil

    return data
end

--- @param parent ExtuiTreeParent
--- @param spellData RB_CustomSpellData
local function renderSpellEditor(parent, spellData)
    local alignedTable = ImguiElements.AddAlignedTable(parent)

    local animationInput = alignedTable:AddInputText(GetLoca("Animation"), spellData.SpellAnimation)
    local sheathingCombo = alignedTable:AddCombo(GetLoca("Sheath"))
    sheathingCombo.Options = {"Melee", "Ranged", "Instrument", "Sheathed", "WeaponSet", "Somatic", "DontChange"}
    sheathingCombo.OnChange = function(input)
        spellData.Sheathing = ImguiHelpers.GetCombo(input)
    end
    animationInput.Hint = "Drag an effect here to auto-fill"
    animationInput.DragDropType = EffectDragDropFlag
    animationInput.OnDragDrop = function(input, drop)
        local data = drop.UserData and drop.UserData.Effect or nil
        if data and data.Uuid then
            local animSet = StatsHelpers.GetEffectAnimation(data.Uuid)
            if not animSet then
                return
            end
            spellData.SpellAnimation = animSet and animSet.SpellAnimation
            --spellData.WeaponTypes = animSet and animSet.WeaponAttack
            spellData.Sheathing = animSet and animSet.Sheathing
            animationInput.Text = animSet and animSet.SpellAnimation or ""
            local idx = table.find(sheathingCombo.Options, animSet.Sheathing) or 1
            sheathingCombo.SelectedIndex = idx - 1
        end
    end

    local prepareBoneInputCell = alignedTable:AddNewLine("Prepare Effect Bone")
    EffectTabComponents:AddBoneInput(prepareBoneInputCell, "Prepare Effect Bone", spellData.PrepareEffectBone or "").OnChange = function (input)
        spellData.PrepareEffectBone = input.Text
    end

    local scalarParams = {
        {Label="Area Radius", Field="AreaRadius", Min=1, Max=100, Step=1, Default = 9},
        {Label="Target Radius", Field="TargetRadius", Min=1, Max=100, Step=1, Default = 18},
    }

    for _, param in ipairs(scalarParams) do
        local slider = alignedTable:AddSliderWithStep(param.Label, spellData[param.Field] or param.Default, param.Min, param.Max, param.Step, true)
        slider.OnChange = function(slider)
            spellData[param.Field] = slider.Value[1]
        end
    end
end

local SPELL_PREFIX = "VFX_RB_SPELL_"

local function makeSpellName(data)
    return SPELL_PREFIX .. data.Uuid
end

--- @param parent ExtuiTreeParent
function SpellTab:RenderControlPanel(parent)
    local playBtn = parent:AddButton("Cast Spell")
    playBtn.OnClick = function()
        self:PlayEffect()
    end

    local updateBtn = parent:AddButton("Update Spell")
    updateBtn.SameLine = true
    updateBtn.OnClick = function()
        local data = parseSpellStatsData(self.entry)
        data.Action = "Update"
        NetChannel.CreateStat:SendToServer(data)
    end

    local learnSpellBtn = parent:AddButton("Learn Spell")
    learnSpellBtn.OnClick = function()
        NetChannel.CallOsiris:SendToServer({
            Function = "AddSpell",
            Args = {
                RBGetHostCharacter(),
                makeSpellName(self.entry),
            },
        })
    end
    learnSpellBtn.SameLine = true

    local unlearnSpellBtn = parent:AddButton("Unlearn Spell")
    unlearnSpellBtn.OnClick = function()
        NetChannel.CallOsiris:SendToServer({
            Function = "RemoveSpell",
            Args = {
                RBGetHostCharacter(),
                makeSpellName(self.entry),
            },
        })
    end
    unlearnSpellBtn.SameLine = true

    renderSpellEditor(parent, self.entry)
end

function SpellTab:PlayEffect()
    local entry = self.entry
    local data = parseSpellStatsData(entry) 

    for caster, targets in pairs(self.Casters) do
        data.Object = caster
        data.Targets = targets
        NetChannel.CreateStat:SendToServer(data)
    end
end

--- @param parent ExtuiTreeParent
function StatusTab:RenderSelector(parent)
    local leftGroup = parent:AddGroup("LeftGroup")

    parent:AddSeparatorText("Apply To:")

    local rightGroup = parent:AddGroup("RightGroup")

    local function refreshPresention() end

    local picker = NearbyCombo.new(leftGroup)
    picker.ExcludeCamera = true
    picker.OnChange = function (sel, Guid, displayName)
        self.Casters[Guid] = {}
        refreshPresention()
    end

    local function renderEntityEntry(guid)
        local name = RBGetName(guid)
        local icon = RBGetIcon(guid)
        local imgSel = ImguiElements.AddImageSelectable(rightGroup, name, icon)
        imgSel.OnClick = function ()
            self.Casters[guid] = nil
            refreshPresention()
        end
    end

    function refreshPresention()
        ImguiHelpers.DestroyAllChildren(rightGroup)
        for guid, _ in pairs(self.Casters) do
            renderEntityEntry(guid)
        end
    end
end

--- @param parent ExtuiTreeParent
function StatusTab:RenderControlPanel(parent)
    local playBtn = parent:AddButton("Apply Status")
    playBtn.OnClick = function()
        self:PlayEffect()
    end

    local stopBtn = parent:AddButton("Stop Status")
    stopBtn.SameLine = true
    stopBtn.OnClick = function()
        local entry = self.entry
        for caster, _ in pairs(self.Casters) do
            NetChannel.StopStatus:SendToServer({
                Type = "Status",
                DisplayName = entry.DisplayName,
                Uuid = entry.Uuid,
                Object = caster,
            })
        end
    end

    local alignedTable = ImguiElements.AddAlignedTable(parent)
    local durationInput = alignedTable:AddInputInt("Duration (turn)", self.entry.Duration or 10)
    durationInput:Tooltip():AddText("Enter -1 for infinite duration.")
    durationInput.OnChange = function (sel, value)
        self.entry.Duration = value[1]
    end
end

function StatusTab:PlayEffect()
    local entry = self.entry
    local data = parseCustomStatsData(entry)

    data.Duration = entry.Duration or 10
    for caster, _ in pairs(self.Casters) do
        data.Object = caster
        NetChannel.CreateStat:SendToServer(data)
    end
end