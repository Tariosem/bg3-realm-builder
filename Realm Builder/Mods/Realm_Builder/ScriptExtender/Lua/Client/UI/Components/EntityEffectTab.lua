--- @class RB_EntityEffectTab
--- @field Effects RB_EffectsTable -- EffectType::index -> EffectProperty -> Value
--- @field resetFuncs table<string, table<string, fun()>> -- EffectType::index -> EffectProperty -> reset function
--- @field updateFuncs table<string, table<string, fun()>> -- EffectType::index -> EffectProperty -> update function
--- @field resetParams table<string, table<string, any>> -- EffectType::index -> EffectProperty -> reset value
--- @field parent ExtuiTreeParent
--- @field GetEntity fun():EntityHandle
--- @field guid GUIDSTRING
--- @field effectHeader ExtuiCollapsingHeader
--- @field effectContextPopup ExtuiPopup
--- @field SelectedEffectComponent string
--- @field new fun(parent?: ExtuiTreeParent, entityGetter: fun():EntityHandle, guid:GUIDSTRING):RB_EntityEffectTab
local EntityEffectTab = _Class("EntityEffectTab")

--#region effects

local currenSupportEffects = {
    ["Light"] = true,
    ["ParticleSystem"] = true,
}

local lightCompProperties = {
    "IntensityProperty",
    "RadiusProperty",
    "FlickerSpeedProperty",
    "FlickerAmountProperty",
    "ColorProperty",
}

local lightEntityProperties = {
    "LightChannelFlag",
    "Flags",
    "LightType",
    "SpotLightInnerAngle",
    "SpotLightOuterAngle",
    "Gain",
    "EdgeSharpening",
    "ScatteringIntensityScale",
    "IntensityOffset",
    --"Kelvin",
    "DirectionLightAttenuationFunction",
    "DirectionLightAttenuationEnd",
    "DirectionLightAttenuationSide",
    "DirectionLightAttenuationSide2",
    "DirectionLightDimensions",
    "Color",
}

local particleSystemCompProperties = {
    "Brightness_",
    "UniformScale",
    "Color"
}

local function copyLightComponentToTable(component, table)
    for _, propName in ipairs(lightCompProperties) do
        local value = VisualHelpers.GetEffectComponentValue(component, propName)
        table[propName] = value
    end
    local lightEntity = component.LightEntity
    if lightEntity and lightEntity.Light then
        local light = lightEntity.Light --[[@as LightComponent]]
        for _, propName in ipairs(lightEntityProperties) do
            local value = light[propName]
            table[propName] = value
        end
    end
end

local function copyParticleSystemComponentToTable(component, table)
    for _, propName in ipairs(particleSystemCompProperties) do
        local value = component[propName]
        table[propName] = value
    end
end

local effectComponentCopyHandlers = {
    Light = copyLightComponentToTable,
    ParticleSystem = copyParticleSystemComponentToTable,
}

function EntityEffectTab:__init(parent, entityGetter, guid)
    self.Effects = {}
    self.resetFuncs = {}
    self.updateFuncs = {}
    self.resetParams = {}
    self.parent = parent
    self.GetEntity = entityGetter
    self.guid = guid
    self:SaveCurrentState()
end

function EntityEffectTab:SaveCurrentState()
    local entity = self:GetEntity() --[[@as EntityHandle]]
    local effectComp = entity.Effect
    local timeline = effectComp and effectComp.Timeline
    local comps = timeline and timeline.Components

    if not comps then
        return
    end

    for compIndex, component in RBUtils.FilteredPairs(comps, function(idx, comp)
        return currenSupportEffects[comp.TypeName] == true
    end) do
        local compKey = component.TypeName .. "::" .. tostring(compIndex)
        local copyHandler = effectComponentCopyHandlers[component.TypeName]
        local resetTable = {}
        self.resetParams[compKey] = resetTable
        if copyHandler then
            copyHandler(component, resetTable)
        end
    end
end

function EntityEffectTab:UpdateEffectsTableReference(effectsTable)
    self.Effects = effectsTable
end

function EntityEffectTab:SetUIParent(parent)
    self.parent = parent
end

function EntityEffectTab:UpdateAllEffects()
    for compKey, paramFuncs in pairs(self.updateFuncs) do
        for paramName, updateFunc in pairs(paramFuncs) do
            updateFunc()
        end
    end
end

function EntityEffectTab:Collapsed()
    self.updateFuncs = {}
    self.resetFuncs = {}
    if self.effectHeader then
        self.effectHeader:Destroy()
        self.effectHeader = nil
    end
end

function EntityEffectTab:ResetAllEffects()
    for compKey, paramFuncs in pairs(self.resetFuncs) do
        for paramName, resetFunc in pairs(paramFuncs) do
            resetFunc()
        end
    end
end

function EntityEffectTab:Render()
    local renderParent = self.parent
    if not renderParent then
        return
    end

    local entity = self:GetEntity() --[[@as EntityHandle]]
    if not entity.Effect or not entity.Effect.Timeline or not entity.Effect.Timeline.Components then
        return
    end

    if self.effectHeader then
        self.effectHeader:Destroy()
        self.effectHeader = renderParent:AddCollapsingHeader(GetLoca("Effect Editor"))
    else
        self.effectHeader = renderParent:AddCollapsingHeader(GetLoca("Effect Editor"))
    end

    self.effectHeader.OnHoverEnter = function()
        self:RenderEffectEditor()
        self.effectHeader.OnHoverEnter = nil
    end
end

function EntityEffectTab:RenderEffectEditor()
    local entity = self:GetEntity() --[[@as EntityHandle]]
    --self.effectRoot = self.effectHeader:AddTree(GetLoca("Effects"))
    if not entity.Effect or not entity.Effect.Timeline or not entity.Effect.Timeline.Components then
        return
    end

    self:SetupEffectContextMenu()

    self:RenderEffectTimelineEditor()

    -- WHY is effect so disorderly
    for compIndex, component in ipairs(entity.Effect.Timeline.Components) do
        --_P(component.TypeName)
        local newTree = nil
        local indexSuffix = tostring(compIndex)
        if component.TypeName == "Light" then
            local nodeName = GetLoca("Light") .. " (" .. indexSuffix .. ")"
            newTree = ImguiElements.AddTree(self.effectHeader, nodeName, false)
            newTree.OnRightClick = function()
                self.SelectedEffectComponent = "Light::" .. tostring(compIndex)
                self.effectContextPopup:Open()
            end

            self:RenderLightComponent(newTree, component, compIndex)
            self:RenderLightEntity(newTree, component, compIndex)
        end

        if component.TypeName == "ParticleSystem" then
            local nodeName = GetLoca("Particle System") .. " (" .. indexSuffix .. ")"
            newTree = ImguiElements.AddTree(self.effectHeader, nodeName, false)
            newTree.OnRightClick = function()
                self.SelectedEffectComponent = "ParticleSystem::" .. tostring(compIndex)
                self.effectContextPopup:Open()
            end
            self:RenderParticleSystemComponent(newTree, component, compIndex)
        end
    end
end

function EntityEffectTab:RenderEffectTimelineEditor()
    local entity = self:GetEntity() --[[@as EntityHandle]]
    if not entity.Effect or not entity.Effect.Timeline then
        return
    end

    local effectObj = entity.Effect
    if not effectObj or not effectObj.Timeline then
        return
    end

    local timeline = effectObj.Timeline

    local timelineTree = ImguiElements.AddTree(self.effectHeader, GetLoca("Timeline"), false)

    local playPauseButton = timelineTree:AddButton(timeline.IsPaused and GetLoca("Paused") or GetLoca("Playing"))
    playPauseButton.OnClick = function()
        local entity = self:GetEntity(self.guid) --[[@as EntityHandle]]
        if not entity.Effect or not entity.Effect.Timeline then
            return
        end
        entity.Effect.Timeline.IsPaused = not entity.Effect.Timeline.IsPaused
        playPauseButton.Label = entity.Effect.Timeline.IsPaused and GetLoca("Paused") or GetLoca("Playing")
    end

    local tab = timelineTree:AddTable("TimelineInfoTable", 2)
    tab.ColumnDefs[1] = { WidthFixed = true }
    tab.ColumnDefs[2] = { WidthStretch = true }
    tab.BordersInnerV = true

    local row = tab:AddRow()

    row:AddCell():AddText(GetLoca("Playing Speed") .. ":")
    local playSpeedSlider = ImguiElements.AddSliderWithStep(row:AddCell(), GetLoca("Set Play Speed"),
        timeline.PlayingSpeed, 0.1, 5.0, 0.1, false)
    playSpeedSlider.OnChange = function()
        local entity = self:GetEntity(self.guid) --[[@as EntityHandle]]
        if not entity.Effect or not entity.Effect.Timeline then
            return
        end
        entity.Effect.Timeline.PlayingSpeed = playSpeedSlider.Value[1]
    end
end

--- @class EffectComponentRenderInfo
--- @field Group string
--- @field RenderOrder string[]
--- @field PropertyMap EffectPropertyMap

--- @class EffectComponentParameterInfo
--- @field DisplayName string
--- @field Hint string
--- @field IsInt boolean
--- @field Range { Min:number, Max:number, Step:number }
--- @field Options RadioButtonOption[]?
--- @field Setter fun(value:any)
--- @field Getter fun():any

--- @class EffectPropertyMap
--- @field Boolean table<string, EffectComponentParameterInfo>
--- @field BitMask table<string, EffectComponentParameterInfo>
--- @field Enum table<string, EffectComponentParameterInfo>
--- @field Scalar table<string, EffectComponentParameterInfo>
--- @field Vector2 table<string, EffectComponentParameterInfo>
--- @field Vector3 table<string, EffectComponentParameterInfo>
--- @field Vector4 table<string, EffectComponentParameterInfo>

function EntityEffectTab:RenderEffectComponentEditor(parent, key, getComp, renderInfo)
    local component = getComp()
    if not component then return end

    local propMap = renderInfo.PropertyMap
    local renderOrder = renderInfo.RenderOrder

    local function renderNumberSliders(tree, propName, propInfo)
        self:RenderEffectComponentSliders(tree, getComp, key, propName, propInfo)
    end

    local renderHandlers = {
        Scalar = renderNumberSliders,
        Vector2 = renderNumberSliders,
        Vector3 = renderNumberSliders,
        Vector4 = renderNumberSliders,
        Boolean = function(tree, propName, propInfo)
            self:RenderEffectComponentBooleanCheckbox(tree, getComp, key, propName, propInfo)
        end,
        BitMask = function(tree, propName, propInfo)
            if propInfo.EnumName then
                propInfo.Options = ImguiHelpers.CreateRadioButtonOptionFromBitmask(propInfo.EnumName)
            end
            self:RenderEffectComponentBitmaskRadioButtons(tree, getComp, key, propName, propInfo)
        end,
        Enum = function(tree, propName, propInfo)
            if propInfo.EnumName then
                propInfo.Options = ImguiHelpers.CreateRadioButtonOptionFromEnum(propInfo.EnumName)
            end
            self:RenderEffectComponentEnumRadioButtons(tree, getComp, key, propName, propInfo)
        end,
    }

    local groupTrees = {
        Default = parent,
    }
    self.resetFuncs[key] = self.resetFuncs[key] or {}
    self.updateFuncs[key] = self.updateFuncs[key] or {}
    self.resetParams[key] = self.resetParams[key] or {}
    local seen = {}
    for _, propName in ipairs(renderOrder) do
        local propType = nil
        seen[propName] = true
        for pType, propList in pairs(propMap) do
            if propList[propName] then
                propType = pType
                break
            end
        end
        if not propType then goto continue end

        local propInfo = propMap[propType][propName]
        local groupName = propInfo.Group or "Default"
        if not groupTrees[groupName] then
            groupTrees[groupName] = ImguiElements.AddTree(parent, groupName)
            parent:AddSeparator():SetStyle("ItemSpacing", 0, 10)
        end

        renderHandlers[propType](groupTrees[groupName], propName, propInfo)
        groupTrees[groupName]:AddSeparator()
        ::continue::
    end
    for propType, propList in pairs(propMap) do
        for propName, propInfo in pairs(propList) do
            if seen[propName] then goto continue end

            local groupName = propInfo.Group or "Default"
            if not groupTrees[groupName] then
                groupTrees[groupName] = ImguiElements.AddTree(parent, groupName)
                parent:AddSeparator():SetStyle("ItemSpacing", 0, 10)
            end

            renderHandlers[propType](groupTrees[groupName], propName, propInfo)
            groupTrees[groupName]:AddSeparator()
            ::continue::
        end
    end
end

--- @param panel ExtuiTreeParent
function EntityEffectTab:RenderEffectComponentSliders(panel, getComp, key, componentName, valueInfo)
    local setter = valueInfo.Setter or function(value)
        local comp = getComp()
        if not comp then return end

        comp[componentName] = value
    end
    local getter = valueInfo.Getter or function()
        local comp = getComp()
        if not comp then return nil end

        return comp[componentName]
    end

    local initValue = self.resetParams[key] and self.resetParams[key][componentName] or getter()
    self.resetParams[key] = self.resetParams[key] or {}
    self.resetParams[key][componentName] = initValue
    if type(initValue) == "number" then
        initValue = { initValue }
    end
    local isInt = valueInfo.IsInt or false
    local range = valueInfo.Range or { Min = -10, Max = 10, Step = 0.1 }
    local compDisplayName = valueInfo.DisplayName or componentName

    local function saveChanged(value)
        local comp = getComp()
        if not comp then return end

        if #value == 1 then
            value = value[1]
        end
        setter(value)
        self.Effects[key] = self.Effects[key] or {}
        self.Effects[key][componentName] = value
    end

    local onReset = function()
        self.Effects[key] = self.Effects[key] or {}
        self.Effects[key][componentName] = nil
        if not next(self.Effects[key]) then
            self.Effects[key] = nil
        end
    end

    local updateMethod = ImguiElements.AddNumberSliders(panel, compDisplayName, getter, saveChanged,
        { IsInt = isInt, Range = range, OnReset = onReset, ResetValue = initValue, IsColor = valueInfo.IsColor })

    self.resetFuncs[key][componentName] = function()
        setter(self.resetParams[key][componentName])
        updateMethod()
        onReset()
    end
    self.updateFuncs[key][componentName] = function()
        updateMethod()
    end
end

function EntityEffectTab:RenderEffectComponentBooleanCheckbox(panel, getComp, key, componentName, boolInfo)
    local comp = getComp()
    local initValue = self.resetParams[key] and self.resetParams[key][componentName] or comp[componentName]
    self.resetParams[key] = self.resetParams[key] or {}
    self.resetParams[key][componentName] = initValue
    local displayName = boolInfo.DisplayName or componentName
    local checkbox = panel:AddCheckbox("##EffectComponentCheckbox_" .. key, initValue)
    checkbox.Label = displayName or componentName

    checkbox.OnChange = function()
        local comp = getComp()
        if not comp then return end

        comp[componentName] = checkbox.Checked
        self.Effects[key] = self.Effects[key] or {}
        self.Effects[key][componentName] = checkbox.Checked
    end

    self.resetFuncs[key][componentName] = function()
        checkbox.Checked = initValue

        local comp = getComp()
        if not comp then return end
        comp[componentName] = initValue

        self.Effects[key] = self.Effects[key] or {}
        self.Effects[key][componentName] = nil
        if not next(self.Effects[key]) then
            self.Effects[key] = nil
        end
    end

    self.updateFuncs[key][componentName] = function()
        local comp = getComp()
        if not comp then return end
        checkbox.Checked = comp[componentName]
    end
end

function EntityEffectTab:RenderEffectComponentBitmaskRadioButtons(panel, getComp, key, componentName, bitMaskInfo)
    local comp = getComp()
    local initValue = self.resetParams[key] and self.resetParams[key][componentName] or comp[componentName]
    self.resetParams[key] = self.resetParams[key] or {}
    self.resetParams[key][componentName] = initValue
    local displayName = bitMaskInfo.DisplayName or componentName
    local options = bitMaskInfo.Options or {}

    local tab = panel:AddTable("SameTable" .. panel.Label, 2)
    tab.ColumnDefs[1] = { WidthFixed = true }
    tab.ColumnDefs[2] = { WidthStretch = true }
    local row = tab:AddRow()
    local titleCell = row:AddCell()
    local radioCell = row:AddCell()
    local title = titleCell:AddBulletText(displayName)
    local radioGroup = ImguiElements.AddBitmaskRadioButtons(radioCell, options, initValue)

    local saveChanged = function(value)
        local comp = getComp()
        if not comp then return end

        comp[componentName] = value
        self.Effects[key] = self.Effects[key] or {}
        self.Effects[key][componentName] = value
    end

    local resetChange = function()
        local comp = getComp()
        if not comp then return end

        comp[componentName] = initValue
        radioGroup.Value = initValue
        self.Effects[key] = self.Effects[key] or {}
        self.Effects[key][componentName] = nil
        if not next(self.Effects[key]) then
            self.Effects[key] = nil
        end
    end

    radioGroup.OnChange = function()
        local comp = getComp()
        if not comp then return end
        saveChanged(radioGroup.Value)
    end

    title.OnRightClick = function()
        resetChange()
    end

    self.resetFuncs[key][componentName] = resetChange
    self.updateFuncs[key][componentName] = function()
        local comp = getComp()
        if not comp then return end
        radioGroup.Value = comp[componentName]
    end
end

function EntityEffectTab:RenderEffectComponentEnumRadioButtons(panel, getComp, key, componentName, enumInfo)
    local comp = getComp()
    local initValue = self.resetParams[key] and self.resetParams[key][componentName] or comp[componentName]
    self.resetParams[key] = self.resetParams[key] or {}
    self.resetParams[key][componentName] = initValue
    local displayName = enumInfo.DisplayName or componentName
    local options = enumInfo.Options or {}

    local tab = panel:AddTable("SameTable" .. panel.Label, 2)
    tab.ColumnDefs[1] = { WidthFixed = true }
    tab.ColumnDefs[2] = { WidthStretch = true }
    local row = tab:AddRow()
    local titleCell = row:AddCell()
    local radioCell = row:AddCell()
    local title = titleCell:AddBulletText(displayName)
    local radioGroup = ImguiElements.AddEnumRadioButtons(radioCell, options, initValue)

    local saveChanged = function(value)
        local comp = getComp()
        if not comp then return end

        comp[componentName] = value
        self.Effects[key] = self.Effects[key] or {}
        self.Effects[key][componentName] = value
    end

    local resetChange = function()
        local comp = getComp()
        if not comp then return end

        comp[componentName] = initValue
        radioGroup.Value = initValue
        self.Effects[key] = self.Effects[key] or {}
        self.Effects[key][componentName] = nil
        if not next(self.Effects[key]) then
            self.Effects[key] = nil
        end
    end

    radioGroup.OnChange = function()
        local comp = getComp()
        if not comp then return end
        saveChanged(radioGroup.Value)
    end

    title.OnRightClick = function()
        resetChange()
    end

    self.resetFuncs[key][componentName] = resetChange
    self.updateFuncs[key][componentName] = function()
        local comp = getComp()
        if not comp then return end
        radioGroup.Value = comp[componentName]
    end
end

function EntityEffectTab:SetupEffectContextMenu()
    local effectContextPopup = self.parent:AddPopup("EffectContextMenu")
    self.effectContextPopup = effectContextPopup
    self.SelectedEffectComponent = nil
    local contextMenu = ImguiElements.AddContextMenu(effectContextPopup, "Effect Component")

    contextMenu:AddItem("Apply To Same Type", function(sel)
        local compKey = self.SelectedEffectComponent
        if not compKey then return end

        local modfiedParams = self.Effects[compKey]
        if not modfiedParams then return end

        local parsedKey = RBStringUtils.SplitByString(compKey, "::")
        local compIndex = tonumber(parsedKey[2])
        if not compIndex then return end
        local selectedComp = VisualHelpers.GetEffectComponent(self.guid, compIndex)
        if not selectedComp then return end
        local compType = selectedComp.TypeName

        local entity = self:GetEntity(self.guid) --[[@as EntityHandle]]
        if not entity.Effect or not entity.Effect.Timeline or not entity.Effect.Timeline.Components then
            return
        end

        for otIdx, comp in RBUtils.FilteredPairs(entity.Effect.Timeline.Components, function(idx, comp)
            return comp.TypeName == compType and (idx ~= compIndex)
        end) do
            local otherKey = compType .. "::" .. tostring(otIdx)
            for paramName, paramValue in pairs(modfiedParams) do
                if comp.TypeName == "Light" then
                    VisualHelpers.ApplyValueToLightComponent(self.guid, otIdx, paramValue, paramName)
                else
                    comp[paramName] = paramValue
                end
                if self.updateFuncs[otherKey] and self.updateFuncs[otherKey][paramName] then
                    self.updateFuncs[otherKey][paramName]()
                end
            end
        end
    end)
end

---@param node ExtuiTree
---@param component AspkComponent
---@param compIndex any
function EntityEffectTab:RenderLightEntity(node, component, compIndex)
    local entityNode = node

    local lightEntity = component.LightEntity --[[@as LightComponent]]
    if not lightEntity or not lightEntity.Light then
        return
    end

    --- @type table<string, EffectComponentParameterInfo>
    local bitMaskParamMap = {
        LightChannelFlag = {
            Options = {
                { Label = "Character", Value = 1 << 5 },
                { Label = "Scenery",   Value = 1 },
            },
            DisplayName = "Light Channel",
            Group = "Light Flags",
        },
        Flags = {
            EnumName = "LightFlags",
            Options = {
            },
            DisplayName = "Light Flags",
            Group = "Light Flags",
        },
    }


    local enumParamMap = {
        LightType = {
            EnumName = "LightType",
            Options = {
            },
            DisplayName = "Light Type",
            Group = "General Light Settings",
        },
        DirectionLightAttenuationFunction = {
            Options = {
                { Label = "Linear",         Value = 0 },
                { Label = "Inverse Square", Value = 1 },
                { Label = "Smooth Step",    Value = 2 },
                { Label = "Smoother Step",  Value = 3 },
            },
            DisplayName = "Attenuation Function",
            Group = "Directional Light Settings",
        },
    }


    local scalarParamMap = {
        SpotLightInnerAngle = {
            Range = { Min = 0, Max = 180, Step = 1 },
            DisplayName = "Inner Angle",
            Group = "Spot Light Settings",
        },
        SpotLightOuterAngle = {
            Range = { Min = 0, Max = 180, Step = 1 },
            DisplayName = "Outer Angle",
            Group = "Spot Light Settings",
        },
        Gain = {
            Range = { Min = 0, Max = 100, Step = 0.1 },
            DisplayName = "Gain",
            Group = "General Light Settings",
        },
        EdgeSharpening = {
            Range = { Min = 0, Max = 10, Step = 0.05 },
            DisplayName = "Edge Sharpness",
            Group = "General Light Settings",
        },
        ScatteringIntensityScale = {
            Range = { Min = 0, Max = 100, Step = 0.1 },
            DisplayName = "Scattering Intensity Scale",
            Group = "General Light Settings",
        },
        IntensityOffset = {
            Range = { Min = -100, Max = 100, Step = 0.1 },
            DisplayName = "Intensity Offset",
            Group = "General Light Settings",
        },
        --[[Kelvin = {
            Range = { Min = 1000, Max = 40000, Step = 100 },
            DisplayName = "Color Temperature (Kelvin)",
            Group = "General Light Settings",
        },]]
        DirectionLightAttenuationEnd = {
            Range = { Min = 0, Max = 2, Step = 0.05 },
            DisplayName = "Attenuation End",
            Group = "Directional Light Settings",
        },
        DirectionLightAttenuationSide = {
            Range = { Min = 0, Max = 2, Step = 0.05 },
            DisplayName = "Attenuation Back",
            Group = "Directional Light Settings",
        },
        DirectionLightAttenuationSide2 = {
            Range = { Min = 0, Max = 2, Step = 0.05 },
            DisplayName = "Attenuation Sides",
            Group = "Directional Light Settings",
        },
    }
    local vector3ParamMap = {
        DirectionLightDimensions = {
            Range = { Min = 0, Max = 100, Step = 1 },
            DisplayName = "Direction Light Dimensions",
            Group = "Directional Light Settings",
            IsColor = false,
        },
        Color = {
            Range = { Min = -1, Max = 1, Step = 0.01 },
            DisplayName = "Light Entity Color",
            Group = "General Light Settings",
            IsColor = true,
        },
    }

    local renderOrder = {
        "LightChannelFlag",
        "Flags",
        "LightType",
        "SpotLightInnerAngle",
        "SpotLightOuterAngle",
        "Gain",
        "EdgeSharpening",
        "ScatteringIntensityScale",
        "DirectionLightAttenuationFunction",
        "DirectionLightAttenuationEnd",
        "DirectionLightAttenuationSide",
        "DirectionLightAttenuationSide2",
        "DirectionLightDimensions",
        "Color",
    }

    local key = "Light::" .. compIndex
    local function GetLiveLightEntity()
        local entity = self:GetEntity(self.guid)
        if not entity or not entity.Effect or not entity.Effect.Timeline or not entity.Effect.Timeline.Components[compIndex] or not entity.Effect.Timeline.Components[compIndex].LightEntity then
            return nil
        end
        return entity.Effect.Timeline.Components[compIndex].LightEntity.Light
    end

    self:RenderEffectComponentEditor(entityNode, key, GetLiveLightEntity, {
        PropertyMap = {
            Scalar = scalarParamMap,
            BitMask = bitMaskParamMap,
            Enum = enumParamMap,
            Vector3 = vector3ParamMap,
        },
        RenderOrder = renderOrder,
    })
end

---@param node any
---@param component AspkComponent
---@param compIndex integer
function EntityEffectTab:RenderLightComponent(node, component, compIndex)
    local compNode = node

    local lcomp = component --[[@as AspkLightComponent]]

    local function applyToFrames(value, propName, frameField)
        local comp = VisualHelpers.GetEffectComponent(self.guid, compIndex) --[[@as AspkLightComponent]]
        if not comp then return end

        local property = comp[propName]
        if not property or not property[frameField] then return end

        if frameField == "KeyFrames" then
            VisualHelpers.ChangeKeyFrames(property.KeyFrames, value)
        else
            VisualHelpers.ChangeFrames(property.Frames, value, true)
        end
    end


    local scalarNameMap = {
        ["IntensityProperty"] = {
            Range = { Min = 0, Max = 100, Step = 0.1 },
            DisplayName = "Intensity",
            Group = "Appearance",
        },
        ["RadiusProperty"] = {
            Range = { Min = 0, Max = 100, Step = 0.1 },
            DisplayName = "Radius",
            Group = "Appearance",
        },
        ["FlickerSpeedProperty"] = {
            Range = { Min = 0, Max = 10, Step = 0.05 },
            DisplayName = "Flicker Speed",
            Group = "Behavior",
        },
        ["FlickerAmountProperty"] = {
            Range = { Min = 0, Max = 1, Step = 0.01 },
            DisplayName = "Flicker Amount",
            Group = "Behavior",
        },
    }

    for propName, prop in pairs(scalarNameMap) do
        if propName == "IntensityProperty" then
            local isCubic = false
            local frames = lcomp.IntensityProperty and lcomp.IntensityProperty.KeyFrames and lcomp.IntensityProperty.KeyFrames[1] and lcomp.IntensityProperty.KeyFrames[1].Frames
            if frames then
                isCubic = VisualHelpers.AreFloakKeyFramesCubic(frames)
            end
            if isCubic then
                prop.Setter = function(value)
                    lcomp = VisualHelpers.GetEffectComponent(self.guid, compIndex) --[[@as AspkLightComponent]]
                    if not lcomp then return end
                    for _, keyFrame in pairs(lcomp.IntensityProperty.KeyFrames or {}) do
                        for _, frame in pairs(keyFrame.Frames or {}) do
                            frame.D = value
                        end
                    end
                end
                prop.Getter = function()
                    local comp = VisualHelpers.GetEffectComponent(self.guid, compIndex) --[[@as AspkLightComponent]]
                    if not comp then return nil end

                    local property = comp.IntensityProperty
                    if not property or not property.KeyFrames then return nil end

                    local frame = property.KeyFrames[1] and property.KeyFrames[1].Frames[1]
                    if not frame then return nil end

                    return frame.D or nil
                end
                prop.PreferSliders = true
                goto continue
            end
        end

        prop.Setter = function(value)
            applyToFrames(value, propName, "KeyFrames")
        end
        prop.Getter = function()
            local comp = VisualHelpers.GetEffectComponent(self.guid, compIndex) --[[@as AspkLightComponent]]
            if not comp then return nil end

            local property = comp[propName]
            if not property or not property.KeyFrames then return nil end

            return property.KeyFrames[1] and property.KeyFrames[1].Frames[1].Value or nil
        end
        ::continue::
    end

    local vec4NameMap = {
        ["ColorProperty"] = {
            Range = { Min = -1, Max = 1, Step = 0.01 },
            DisplayName = "Color",
            Group = "Appearance",
            IsColor = true,
        },
    }

    for propName, prop in pairs(vec4NameMap) do
        prop.Setter = function(value)
            applyToFrames(value, propName, "Frames")
        end
        prop.Getter = function()
            local comp = VisualHelpers.GetEffectComponent(self.guid, compIndex) --[[@as AspkLightComponent]]
            if not comp then return nil end

            local property = comp[propName]
            if not property or not property.Frames then return nil end

            local lc = property.Frames[1] and property.Frames[1].Color or {}
            return RBUtils.LightCToArray(lc)
        end
    end

    local boolNameMap = {
        ["ModulateLightTemplateRadius"] = {
            DisplayName = "Modulate Light Template Radius",
            Group = "Override Flags",
        },
        ["OverrideLightTemplateFlickerSpeed"] = {
            DisplayName = "Override Light Template Flicker Speed",
            Group = "Override Flags",
        },
        ["OverrideLightTemplateColor"] = {
            DisplayName = "Override Light Template Color",
            Group = "Override Flags",
        },
    }


    local key = "Light::" .. compIndex
    self:RenderEffectComponentEditor(compNode, key, function()
        return VisualHelpers.GetEffectComponent(self.guid, compIndex) --[[@as AspkLightComponent]]
    end, {
        PropertyMap = {
            Scalar = scalarNameMap,
            Vector4 = vec4NameMap,
            Boolean = boolNameMap,
        },
        RenderOrder = {
            "IntensityProperty",
            "RadiusProperty",
            "ColorProperty",
            "FlickerSpeedProperty",
            "FlickerAmountProperty",
            "ModulateLightTemplateRadius",
            "OverrideLightTemplateFlickerSpeed",
            "OverrideLightTemplateColor",
        }
    })
end

---@param node any
---@param component AspkComponent
---@param compIndex integer
function EntityEffectTab:RenderParticleSystemComponent(node, component, compIndex)
    local compNode = node

    local psComp = component --[[@as AspkParticleSystemComponent]]
    local scalarParamMap = {
        Brightness_ = {
            Range = { Min = 0, Max = 10, Step = 0.1 },
            DisplayName = "Brightness",
        },
        UniformScale = {
            Range = { Min = 0, Max = 10, Step = 0.1 },
            DisplayName = "Uniform Scale",
        },
    }
    local vec4PropNameMap = {
        Color = {
            Range = { Min = -1, Max = 1, Step = 0.01 },
            DisplayName = "Color",
            IsColor = true,
        }
    }

    local key = "ParticleSystem::" .. compIndex

    local function GetLiveParticleSystem()
        local entity = self:GetEntity(self.guid)
        if not entity or not entity.Effect or not entity.Effect.Timeline or not entity.Effect.Timeline.Components[compIndex] then
            return nil
        end
        return entity.Effect.Timeline.Components[compIndex]
    end

    self:RenderEffectComponentEditor(compNode, key, GetLiveParticleSystem, {
        PropertyMap = {
            Scalar = scalarParamMap,
            Vector4 = vec4PropNameMap,
        },
        RenderOrder = {
            "Color",
            "Brightness_",
            "UniformScale",
        }
    })
end

--#endregion effects

return EntityEffectTab