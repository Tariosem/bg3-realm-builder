--- @class RB_EntityEffectTab
--- @field Effects RB_EffectsTable -- EffectType::index -> EffectProperty -> Value
--- @field resetFuncs table<string, table<string, fun()>> -- EffectType::index -> EffectProperty -> reset function
--- @field reapplyFuncs table<string, table<string, fun()>> -- EffectType::index -> EffectProperty -> reapply function
--- @field updateFuncs table<string, table<string, fun()>> -- EffectType::index -> EffectProperty -> update function
--- @field resetParams table<string, table<string, any>> -- EffectType::index -> EffectProperty -> reset value
--- @field parent ExtuiTreeParent
--- @field GetEntity fun():EntityHandle
--- @field guid GUIDSTRING
--- @field effectHeader ExtuiCollapsingHeader
--- @field effectContextPopup ExtuiPopup
--- @field SelectedEffectComponent string
--- @field Editor EntityEffectEditor
--- @field new fun(parent?: ExtuiTreeParent, editor:EntityEffectEditor  ):RB_EntityEffectTab
local EntityEffectTab = _Class("EntityEffectTab")

--#region effects

function EntityEffectTab:__init(parent, editor)
    self.updateFuncs = {}
    self.parent = parent
    self.Editor = editor
end

local function isEntityHasEffect(entity)
    return entity and entity.Effect and entity.Effect.Timeline and entity.Effect.Timeline.Components and #entity.Effect.Timeline.Components > 0
end

function EntityEffectTab:SetUIParent(parent)
    self.parent = parent
end

function EntityEffectTab:UpdateUIState()
    for compKey, paramFuncs in pairs(self.updateFuncs) do
        for paramName, updateFunc in pairs(paramFuncs) do
            updateFunc()
        end
    end
end

function EntityEffectTab:Collapsed()
    self.updateFuncs = {}
    if self.effectHeader then
        self.effectHeader:Destroy()
        self.effectHeader = nil
    end
end

function EntityEffectTab:Render()
    local renderParent = self.parent
    if not renderParent then
        return
    end

    local effect = self.Editor:GetEntityEffect()
    if not effect then return end

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
    self:SetupEffectContextMenu()

    self:RenderEffectTimelineEditor()

    -- WHY is effect so disorderly
    for compIndex, component in ipairs(self.Editor:GetAllComponents()) do
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
    local effectObj = self.Editor:GetEntityEffect()
    if not effectObj or not effectObj.Timeline then
        return
    end

    local timeline = effectObj.Timeline

    local timelineTree = ImguiElements.AddTree(self.effectHeader, GetLoca("Timeline"), false)

    local playPauseButton = timelineTree:AddButton(timeline.IsPaused and GetLoca("Paused") or GetLoca("Playing"))
    playPauseButton.OnClick = function()
        local effect = self.Editor:GetEntityEffect()
        if not effect or not effect.Timeline then
            return
        end
        effect.Timeline.IsPaused = not effect.Timeline.IsPaused
        playPauseButton.Label = effect.Timeline.IsPaused and GetLoca("Paused") or GetLoca("Playing")
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
        local effect = self.Editor:GetEntityEffect()
        if not effect or not effect.Timeline then
            return
        end
        effect.Timeline.PlayingSpeed = playSpeedSlider.Value[1]
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

function EntityEffectTab:RenderEffectComponentEditor(parent, key, renderInfo)
    local propMap = renderInfo.PropertyMap
    local renderOrder = renderInfo.RenderOrder

    local function renderNumberSliders(tree, propName, propInfo)
        self:RenderEffectComponentSliders(tree, key, propName, propInfo)
    end

    local renderHandlers = {
        Scalar = renderNumberSliders,
        Vector2 = renderNumberSliders,
        Vector3 = renderNumberSliders,
        Vector4 = renderNumberSliders,
        Boolean = function(tree, propName, propInfo)
            self:RenderEffectComponentBooleanCheckbox(tree, key, propName, propInfo)
        end,
        BitMask = function(tree, propName, propInfo)
            if propInfo.EnumName then
                propInfo.Options = ImguiHelpers.CreateRadioButtonOptionFromBitmask(propInfo.EnumName)
            end
            self:RenderEffectComponentBitmaskRadioButtons(tree, key, propName, propInfo)
        end,
        Enum = function(tree, propName, propInfo)
            if propInfo.EnumName then
                propInfo.Options = ImguiHelpers.CreateRadioButtonOptionFromEnum(propInfo.EnumName)
            end
            self:RenderEffectComponentEnumRadioButtons(tree, key, propName, propInfo)
        end,
    }

    local groupTrees = {
        Default = parent,
    }
    self.updateFuncs[key] = self.updateFuncs[key] or {}
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
function EntityEffectTab:RenderEffectComponentSliders(panel, key, propName, valueInfo)
    local _, compIndex = self.Editor:ParseKey(key)
    if not compIndex then return end
    local setter = function(value)
        value = #value == 1 and value[1] or value
        self.Editor:SetProperty(compIndex, propName, value)
    end
    local getter = function()
        return self.Editor:GetProperty(compIndex, propName)
    end

    local onReset = function()
        self.Editor:ResetProperty(compIndex, propName)
    end

    local initValue = getter() --[[@as number[] ]]
    if type(initValue) == "number" then
        initValue = { initValue }
    end
    local isInt = valueInfo.IsInt or false
    local range = valueInfo.Range or { Min = -10, Max = 10, Step = 0.1 }
    local compDisplayName = valueInfo.DisplayName or propName

    local updateMethod = ImguiElements.AddNumberSliders(panel, compDisplayName, getter, setter,
        { IsInt = isInt, Range = range, OnReset = onReset, ResetValue = initValue, IsColor = valueInfo.IsColor })

    self.updateFuncs[key][propName] = updateMethod
end

function EntityEffectTab:RenderEffectComponentBooleanCheckbox(panel, key, propName, boolInfo)
    local _, compIndex = self.Editor:ParseKey(key)
    if not compIndex then return end

    local setter = function(value)
        self.Editor:SetProperty(compIndex, propName, value)
    end

    local getter = function()
        return self.Editor:GetProperty(compIndex, propName)
    end

    local initValue = getter() --[[@as boolean ]]
    local displayName = boolInfo.DisplayName or propName
    local checkbox = panel:AddCheckbox("##EffectComponentCheckbox_" .. key, initValue)
    checkbox.Label = displayName or propName

    checkbox.OnChange = function()
        setter(checkbox.Checked)
    end

    self.updateFuncs[key][propName] = function()
        checkbox.Checked = getter()
    end

    checkbox.OnRightClick = function()
        self.Editor:ResetProperty(compIndex, propName)
        checkbox.Checked = getter()
    end
end

function EntityEffectTab:_renderRadioButtons(panel, key, componentName, info, fn)
    local _, compIndex = self.Editor:ParseKey(key)
    if not compIndex then return end

    local setter = function(value)
        self.Editor:SetProperty(compIndex, componentName, value)
    end

    local getter = function()
        return self.Editor:GetProperty(compIndex, componentName)
    end

    local initValue = getter() --[[@as number ]]
    local displayName = info.DisplayName or componentName
    local options = info.Options or {}
    local tab = panel:AddTable("SameTable" .. panel.Label, 2)
    tab.ColumnDefs[1] = { WidthFixed = true }
    tab.ColumnDefs[2] = { WidthStretch = true }
    local row = tab:AddRow()
    local titleCell = row:AddCell()
    local radioCell = row:AddCell()
    local title = titleCell:AddBulletText(displayName)
    local radioGroup = ImguiElements[fn](radioCell, options, initValue)


    radioGroup.OnChange = function()
        setter(radioGroup.Value)
    end

    title.OnRightClick = function()
        self.Editor:ResetProperty(compIndex, componentName)
        radioGroup.Value = getter()
    end

    self.updateFuncs[key][componentName] = function()
        radioGroup.Value = getter()
    end
end

function EntityEffectTab:RenderEffectComponentBitmaskRadioButtons(panel, key, componentName, bitMaskInfo)
    return self:_renderRadioButtons(panel, key, componentName, bitMaskInfo, "AddBitmaskRadioButtons")
end

function EntityEffectTab:RenderEffectComponentEnumRadioButtons(panel, key, componentName, enumInfo)
    return self:_renderRadioButtons(panel, key, componentName, enumInfo, "AddEnumRadioButtons")
end

function EntityEffectTab:SetupEffectContextMenu()
    local effectContextPopup = self.parent:AddPopup("EffectContextMenu")
    self.effectContextPopup = effectContextPopup
    self.SelectedEffectComponent = nil
    local contextMenu = ImguiElements.AddContextMenu(effectContextPopup, "Effect Component")

    contextMenu:AddItem("Apply To Same Type", function(sel)
        local entity = self.Editor:GetEntity()
        if not entity then return end
        local compKey = self.SelectedEffectComponent
        if not compKey then return end

        local parsedKey = RBStringUtils.SplitByString(compKey, "::")
        local compIndex = tonumber(parsedKey[2])
        if not compIndex then return end
        local selectedComp = VisualHelpers.GetEffectComponent(entity, compIndex)
        if not selectedComp then return end
        local compType = selectedComp.TypeName

        self.Editor:ApplyToAllSameType(compType, compIndex)
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

    self:RenderEffectComponentEditor(entityNode, key, {
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

    local vec4NameMap = {
        ["ColorProperty"] = {
            Range = { Min = -1, Max = 1, Step = 0.01 },
            DisplayName = "Color",
            Group = "Appearance",
            IsColor = true,
        },
    }

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
    self:RenderEffectComponentEditor(compNode, key, {
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

    self:RenderEffectComponentEditor(compNode, key, {
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