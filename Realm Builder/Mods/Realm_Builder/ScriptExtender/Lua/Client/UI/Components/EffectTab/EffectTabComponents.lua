--- @class RB_EffectTabComponents
local effectTabComponents = {}
local effectDragDropFlag = "RB_Effect_DragDrop_Flag"
EffectDragDropFlag = effectDragDropFlag

--- @class RB_EffectDragDropData
--- @field Icon string
--- @field Uuid GUIDSTRING
--- @field EffectName string
--- @field SourceBone string
--- @field TargetBone string
--- @field Bone string
--- @field isMultiEffect boolean
--- @field isLoop boolean
--- @field isBeam boolean
--- @field atPosition boolean
--- @field atObject boolean
--- @field Scale number
--- @field Duration number
--- @field TimeOffset number

RBEffectUtils = RBEffectUtils or {}

--- @param effectEntry RB_Effect
--- @return RB_EffectDragDropData
function RBEffectUtils.CreateEffectDragDropDataFromEffect(effectEntry)
    --- @type RB_EffectDragDropData
    local dragDropData = {
        Icon = effectEntry.Icon,
        Uuid = effectEntry.Uuid,
        EffectName = effectEntry.EffectName,
        isMultiEffect = effectEntry.isMultiEffect or false,
        isLoop = effectEntry.isLoop or false,
        isBeam = effectEntry.isBeam or false,
        SourceBone = effectEntry.SourceBone or "",
        TargetBone = effectEntry.TargetBone or "",
        Bone = effectEntry.SourceBone or effectEntry.TargetBone or "",
    }

    return dragDropData
end

--- @param effectEntry RB_EffectDragDropData
--- @return RB_EffectPlayData
function RBEffectUtils.PlayEffectDragDropData(effectEntry)
    --- @type RB_EffectPlayData
    local playData = {
        FxName = effectEntry.Uuid,
        SourceBone = effectEntry.SourceBone,
        TargetBone = effectEntry.TargetBone,
        Scale = effectEntry.Scale or 1.0,
        Duration = effectEntry.Duration,
        TimeOffset = effectEntry.TimeOffset,
        Flags = {
            PlayLoop = effectEntry.isLoop,
            PlayBeamEffect = effectEntry.isBeam,
            PlayAtPosition = effectEntry.atPosition,
            PlayAtPositionAndRotation = effectEntry.atObject
        }
    }

    return playData
end

local getName = RBGetName
local getIcon = RBGetIcon
local nameCache = {}
local iconCache = {}

local function makeCache(obj)
    for guid, guids in pairs(obj) do
        if not nameCache[guid] then
            nameCache[guid] = getName(guid)
        end
        if not iconCache[guid] then
            iconCache[guid] = getIcon(guid) or RB_ICONS.Box
        end
        for _, targetGuid in ipairs(guids) do
            if not nameCache[targetGuid] then
                nameCache[targetGuid] = getName(targetGuid)
            end
            if not iconCache[targetGuid] then
                iconCache[targetGuid] = getIcon(targetGuid) or RB_ICONS.Box
            end
        end
    end
end

--- @param parent RB_UI_Tree
--- @param obj table<GUIDSTRING, GUIDSTRING[]> -- [casterGUID] -> targetGUID[] (repeatable)
function effectTabComponents:AddCasterTargetSelector(parent, obj)
    local tab = parent:AddTable("##" .. parent.Label, 2)
    local row = tab:AddRow()
    local leftCell = row:AddCell()
    local leftAligned = ImguiElements.AddAlignedTable(leftCell)
    local rightCell = row:AddCell()
    tab.ColumnDefs[1] = { WidthStretch = true }
    tab.ColumnDefs[2] = { WidthStretch = true }
    tab.BordersInnerV = true

    local expanded = {}
    local function updatePresentation()
        ImguiHelpers.DestroyAllChildren(rightCell)

        makeCache(obj)

        for casterGuid, targetGuids in RBUtils.SortedPairs(obj, function (a, b)
            local nameA = nameCache[a] or a
            local nameB = nameCache[b] or b
            return nameA < nameB
        end) do
            local casterName = nameCache[casterGuid] or casterGuid
            local casterIcon = iconCache[casterGuid] or RB_ICONS.Box
            local casterTree = ImguiElements.AddTree(rightCell, casterName .. "##" .. casterGuid, expanded[casterGuid] ~= nil)
            casterTree:AddTreeIcon(casterIcon)

            casterTree.OnRightClick = function()
                obj[casterGuid] = nil
                casterTree:Destroy()
            end

            local function updateChildTree()
                casterTree:ClearContent()
                if #targetGuids == 0 then
                    expanded[casterGuid] = nil
                    casterTree:Destroy()
                    return
                end

                for i, targetGuid in ipairs(targetGuids) do
                    local targetName = nameCache[targetGuid] or targetGuid
                    local targetIcon = iconCache[targetGuid] or RB_ICONS.Box

                    local id = targetName .. "##" .. targetGuid .. "##" .. i
                    local targetGroup = casterTree:AddGroup(id)

                    local function remove()
                        if not targetGuids[i] then
                            return
                        end
                        table.remove(targetGuids, i)
                        updateChildTree()
                    end

                    local imgSel = ImguiElements.AddImageSelectable(targetGroup, id, targetIcon)
                    imgSel.OnRightClick = function()
                        remove()
                    end
                end
            end

            casterTree.OnExpand = function()
                updateChildTree()
                casterTree.OnExpand = function()
                    expanded[casterGuid] = true
                end
                expanded[casterGuid] = true
            end
            if expanded[casterGuid] then
                casterTree:OnExpand()
            end

            casterTree.OnCollapse = function()
                expanded[casterGuid] = nil
            end
        end

    end

    local selectedCasterGroup = leftAligned:AddGroup("Selected Caster")
    local selectedCaster = nil
    local function updateSelectedCaster(guid)
        selectedCaster = guid
        ImguiHelpers.DestroyAllChildren(selectedCasterGroup)
        if not selectedCaster or not RBUtils.IsUuidShape(guid) then
            local imgSel = ImguiElements.AddImageSelectable(selectedCasterGroup, "None Selected", RB_ICONS.Box)
            imgSel.Disabled = true
            return
        end

        local name = nameCache[guid] or getName(guid)
        local icon = iconCache[guid] or getIcon(guid) or RB_ICONS.Box
        local imgSel = ImguiElements.AddImageSelectable(selectedCasterGroup, name, icon)
        imgSel.Disabled = true
    end
    
    local casterPicker = NearbyCombo.new(leftAligned:AddNewLine("Pick Caster"))
    casterPicker.ExcludeCamera = true
    casterPicker.OnChange = function (sel, Guid, displayName)
        updateSelectedCaster(Guid)
    end
    updateSelectedCaster(nil)

    local targetPicker = NearbyCombo.new(leftAligned:AddNewLine("Pick Targets"))
    targetPicker.ExcludeCamera = true
    targetPicker.OnChange = function (sel, Guid, displayName)
        if selectedCaster then
            obj[selectedCaster] = obj[selectedCaster] or {}
            table.insert(obj[selectedCaster], Guid)
            updatePresentation()
        end
        targetPicker:SetSelected(nil)
    end

    return updatePresentation
end

--- @param parent RB_UI_Tree
--- @param effectEntry RB_EffectDragDropData
function effectTabComponents:AddEffectEntry(parent, effectEntry, expanded)
    local effectManager = RB_GLOBALS.MultiEffectManager
    local uid = RBUtils.Uuid_v4()
    local managerEntry = effectManager.Data[effectEntry.Uuid]
    if not managerEntry then
        Warning("[EffectTabComponents] Effect with UUID: " .. tostring(effectEntry.Uuid) .. " not found in MultiEffectManager!")
        local errorTree = parent:AddTree("Missing Effect " .. effectEntry.Uuid .. "## " .. uid)
        errorTree.Disabled = true
        return errorTree
    end
    local tree = parent:AddTree(managerEntry.EffectName .. "## " .. uid, expanded or false)
    tree:AddTreeIcon(managerEntry.Icon or RB_ICONS.Box)

    tree.UserData = {
        Effect = effectEntry,
    }

    return tree
end

--- @param parent ExtuiTreeParent
--- @param handleDrop fun(droppedData: RB_EffectDragDropData)
function effectTabComponents:AddEffectListPlusCircle(parent, handleDrop)
    local group = parent:AddGroup("Effect List Actions##" .. parent.Label)

    local addButton = group:AddImageButton("##" .. parent.Label, RB_ICONS.Plus_Circle_Fill, IMAGESIZE.FRAME)
    local uuidOrNameInput = group:AddInputText("##Effect_UuidOrName_Input_" .. parent.Label, "")
    uuidOrNameInput.Hint = "Enter Effect UUID or Name"
    uuidOrNameInput.SameLine = true

    StyleHelpers.ApplyBorderlessImageButtonStyle(addButton)

    addButton.OnClick = function ()
        local effectManager = RB_GLOBALS.MultiEffectManager
        local input = uuidOrNameInput.Text
        if input == "" then
            return
        end

        local effectEntry = effectManager.Data[input]
        if not effectEntry then
            local findName = effectManager.EffectNameToUuid[input]
            if findName then
                effectEntry = effectManager.Data[findName]
            end
        end
        if not effectEntry then
            return
        end

        handleDrop(RBEffectUtils.CreateEffectDragDropDataFromEffect(effectEntry or {}))

        uuidOrNameInput.Text = ""
    end

    local eles = { uuidOrNameInput, addButton }
    for _, ele in ipairs(eles) do
        ele.DragDropType = effectDragDropFlag
        ele.OnDragDrop = function (sel, drop)
            handleDrop(drop.UserData and drop.UserData.Effect or {})
        end
    end

    return group
end

--- @param parent ExtuiTreeParent
--- @param label string
--- @param effectList RB_EffectDragDropData[]
--- @param contextRenderFunc fun(tree: RB_UI_Tree, effectEntry: RB_EffectDragDropData, index: integer)
--- @param handleDrop fun(droppedData: RB_EffectDragDropData?, insertIndex: integer)
--- @return fun(), RB_UI_Tree
function effectTabComponents:AddEffectList(parent, label, effectList, contextRenderFunc, handleDrop)
    local rootTree = ImguiElements.AddTree(parent, label)
    
    local effectManager = RB_GLOBALS.MultiEffectManager

    local expanded = {}
    local function refreshList()
        rootTree:DestroyChildren()
        rootTree:ClearContent()

        for i, effectEntry in ipairs(effectList) do
            local wasExpanded = expanded[effectEntry] ~= nil
            local function updateUI(disabled) end
            local disabledBtn = ImguiElements.AddVisibleButton(rootTree, not effectEntry.Disabled, function(v)
                updateUI(not v)
            end, label .. "##DisabledToggle##" .. i)
            local childTree = self:AddEffectEntry(rootTree, effectEntry, wasExpanded)
            childTree.SameLine = true

            function updateUI(disabled)
                if disabled then
                    childTree:SetOpen(false)
                end
                childTree.Disabled = disabled
                effectEntry.Disabled = disabled
            end

            contextRenderFunc(childTree, effectEntry, i)
            local expandFn = childTree.OnExpand
            if wasExpanded then
                expandFn(childTree)
            end
            childTree.OnExpand = function()
                expanded[effectEntry] = true
                if expandFn then
                    expandFn(childTree)
                end
            end

            local collapseFn = childTree.OnCollapse
            childTree.OnCollapse = function()
                expanded[effectEntry] = nil
                if collapseFn then
                    collapseFn(childTree)
                end
            end

            childTree.CanDrag = true
            childTree.DragDropType = effectDragDropFlag
            childTree.OnDragDrop = function (sel, drop)
                handleDrop(drop.UserData and drop.UserData.Effect, i)
            end

            updateUI(effectEntry.Disabled and true or false)
        end

    end

    refreshList()

    return refreshList, rootTree
end

--- @param parent ExtuiTreeParent
--- @param label string
--- @param initValue string?
--- @return ExtuiInputText
function effectTabComponents:AddBoneInput(parent, label, initValue)
    local group = parent:AddGroup(label)
    local input = group:AddInputText("##" .. label .. "_BoneInput", initValue or "")
    input.Hint = "Enter Bone Name"

    local confirm = group:AddButton("<")
    confirm.OnClick = function ()
        input.Text = BoneHelpers.ParseBoneList(input.Text)
        input:OnChange()
    end
    confirm.OnHoverEnter = function ()
        confirm:Tooltip():AddText("Find best matching bone names for the given input.")
        confirm.OnHoverEnter = nil
    end

    local reset = ImguiElements.AddResetButton(group, true)
    reset.OnClick = function ()
        input.Text = initValue or ""
    end

    confirm.SameLine = true

    return input
end

EffectTabComponents = effectTabComponents