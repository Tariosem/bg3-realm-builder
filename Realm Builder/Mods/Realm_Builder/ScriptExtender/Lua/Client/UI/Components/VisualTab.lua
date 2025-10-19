local VISUALTAB_WIDTH = 800 * SCALE_FACTOR
local VISUALTAB_HEIGHT = 1000 * SCALE_FACTOR

--- @class VisualTab
--- @field Materials MaterialTab[]
--- @field new fun(guid: GUIDSTRING, displayName: string|nil, parent: ExtuiTreeParent|nil, templateName: string|nil): VisualTab
VisualTab = _Class("VisualTab")

function VisualTab:__init(guid, displayName, parent, templateName)
    self.guid = guid or ""
    self.templateName = templateName or "Unknown"
    self.param = {}
    self.keys = {}

    self.parent = parent or nil
    self.isAttach = true
    self.panel = nil
    self.isWindow = false
    self.isValid = true
    self.isVisible = false
    self.displayName = displayName or "Unknown"

    self.autoReload = true
    self.allowRepeat = false

    self.modifiedParams = {}

    self.currentPreset = EntityStore[guid] and EntityStore[guid].VisualPreset or nil

    self.updateFuncs = {}
    self.resetFuncs = {}
    self.Materials = {}

    self:Load()

    if self.currentPreset then
        self:LoadPreset(self.currentPreset)
    end

    NetChannel.GetTemplate:RequestToServer({Guid = self.guid}, function (response)
        if response.Success and response.Template then
            self.templateName = response.Template
            self:SetupTemplate()
            Debug("VisualTab: Received template name from server: " .. self.templateName)
        else
            Error("VisualTab: Could not get template name from server for entity " .. self.guid)
        end
    end)
end

function VisualTab:SetupTemplate()
    local templateName = self.templateName or "Unknown"

    if not ClientVisualPresetData[templateName] then
        ClientVisualPresetData[templateName] = {}
    end
    self.savedModifiedParams = ClientVisualPresetData[templateName]
end

function VisualTab:GetCurrentPreset()
    return self.currentPreset
end

function VisualTab:Render(retryCnt)

    self.displayName = self.displayName or GetDisplayNameFromGuid(self.guid)

    if self.parent and self.isAttach then
        self:OnAttach()
        self.panel = self.parent:AddTabItem(GetLoca("Visual"))
        self.isWindow = false
    else
        self.panel = RegisterWindow(self.guid, self.displayName, "VisualTab", self, self.lastPosition, self.lastSize or {VISUALTAB_WIDTH, VISUALTAB_HEIGHT})
        self.isWindow = true
        self:OnDetach()
    end

    self.isVisible = true

    local entity = Ext.Entity.Get(self.guid)

    if entity == nil or not entity.Visual or not entity.Visual.Visual or (not entity.Visual.Visual.ObjectDescs and not entity.Effect) then
        --Error("VisualTab: Entity is invalid or does not have visual data.")
        local tryToRerender = function()
            self:Refresh()
        end
        if not retryCnt or retryCnt < 1 then
            Timer:After(500, function()
                self:Refresh((retryCnt or 0) + 1)
            end)
        else
            local rerenderButton = self.panel:AddButton(GetLoca("Try to reload Visual Tab"))
            rerenderButton:Tooltip():AddText(GetLoca("Prop is too far away, in inventory, or has no visual."))
            rerenderButton.OnClick = tryToRerender
        end
        return
    end

    self.keys = {}

    self.topTable = self.panel:AddTable("VisualTop", 2)

    self.topTable.ColumnDefs[1] = { WidthStretch = true }
    self.topTable.ColumnDefs[2] = { WidthStretch = false, WidthFixed = true }

    self.topRow = self.topTable:AddRow("VisualTopRow")

    self.topLeftCell = self.topRow:AddCell()
    self.topRightCell = self.topRow:AddCell()

    self:RenderPresetsCell()
    self:RenderUtilsCell()

    -- Right cell content

    self:RenderAttachmentsSection()

    --#region Material Editor

    self:RenderMaterialEditor()

    --#endregion Material Editor

    self:RenderEffectEditor()

    self:Load()
end

function VisualTab:RenderPresetsCell()
    if Ext.Entity.Get(self.guid) and not self.isAttach then
        local icon = GetIcon(self.guid)
        if icon == "Item_Unknown" and self.templateName then
            icon = GetIconForTemplateName(self.templateName)
        end
        self.symbol = self.topLeftCell:AddImage(icon)
        self.symbol.ImageData.Size = {64 * SCALE_FACTOR, 64 * SCALE_FACTOR}
        if EntityStore[self.guid] and EntityStore[self.guid].IconTintColor then
            self.symbol.Tint = EntityStore[self.guid].IconTintColor
        end
        self.displayNameText = self.topLeftCell:AddText(self.displayName)
        self.displayNameText.SameLine = true
    end

    self.saveInput = self.topLeftCell:AddInputText("")
    self.saveButton = self.topLeftCell:AddButton(GetLoca("Save"))
    
    self.saveButton.SameLine = true
    
    self.saveInput.IDContext = "PresetSave"

    self.loadCombo = self.topLeftCell:AddCombo("")
    self.loadButton = self.topLeftCell:AddButton(GetLoca("Load"))
    local removeButton = self.topLeftCell:AddButton(GetLoca("Remove"))

    self.loadButton.SameLine = true
    removeButton.SameLine = true

    self.loadCombo.IDContext = "SelectPreset"

    self.saveInput.OnChange = function()
        --Info("VisualTab:SaveInput - Preset name changed to: " .. self.saveInput.Text)
        local text = self.saveInput.Text

        if text == "" then
            self.loadCombo.Options = self:_getAllPresetNames()
            self.saveButton.Disabled = true
        else
            self.saveButton.Disabled = false
        end

        local comboOpts = {}

        for _, name in ipairs(self:_getAllPresetNames()) do
            if Contains(name, text) then
                table.insert(comboOpts, name)
            end
        end

        self.loadCombo.Options = comboOpts
        for index, presetName in ipairs(self.loadCombo.Options) do
            if presetName == self.currentPreset then
                self.loadCombo.SelectedIndex = index - 1
            end
        end
    end

    self.saveButton.OnClick = function()
        local name = self.saveInput.Text
        if name == "" then
            --Warning("Preset name cannot be empty!")
            return
        end

        if not self:Save(name) then
            Error("Failed to save VisualTab preset.")
        end
        self.saveInput.Text = ""
        self.saveInput:OnChange()
    end

    self.saveInputKeySub = SubscribeKeyInput({ Key= "RETURN" }, function()
        if IsFocused(self.saveInput) and not self.saveButton.Disabled then
            self.saveButton:OnClick()
        end
    end)

    self.loadButton.OnClick = function()
        local selectedName = GetCombo(self.loadCombo)
        if selectedName and selectedName ~= "" then
            self:LoadPreset(selectedName)
            --Info("Loaded VisualTab preset: " .. selectedName)
        end
    end

    ApplyDangerButtonStyle(removeButton)
    removeButton.OnClick = function()
        if not GetCombo(self.loadCombo) or GetCombo(self.loadCombo) == "" then
            return
        end
        ConfirmPopup:DangerConfirm(
            GetLoca("Are you sure you want to remove") .. " '" .. GetCombo(self.loadCombo) .. "'?", 
            function()
                local selectedName = GetCombo(self.loadCombo)
                if selectedName and selectedName ~= "" then
                    self:Remove(selectedName)
                    self.saveInput:OnChange()
                    --Info("Removed VisualTab preset: " .. selectedName)
                end
            end)
    end

    local resetAllButton = self.topLeftCell:AddButton(GetLoca("Reset All"))

    local warningImage = self.topLeftCell:AddImage(WARNING_ICON)
    warningImage.ImageData.Size = {32 * SCALE_FACTOR, 32 *SCALE_FACTOR}
    warningImage.SameLine = true
    warningImage:Tooltip():AddText(GetLoca("Some changes will affect all instances of the same template."))
    warningImage:Tooltip():AddText(GetLoca("If 'Reset All' doesn't work, reload a save."))
    warningImage:Tooltip():AddBulletText("Template: " .. self.templateName)


    resetAllButton.OnClick = function ()

        NetChannel.Replicate:SendToServer({
            Guid = self.guid,
            Field = "GameObjectVisual",
        })

        Timer:Ticks(10, function ()
            for key, func in pairs(self.resetFuncs) do
                func({}, true)
            end

            
            for key, matTab in pairs(self.Materials) do
                Debug("Resetting material: " .. key)
                matTab:ResetAll()
            end
        end)
    end

    --#endregion Left Cell Content
end

function VisualTab:RenderUtilsCell()
    local detachCell = AddRightAlignCell(self.topRightCell)
    local loadCell = self.topRightCell

    local detachButton = detachCell:AddButton(GetLoca("Detach"))

    if not self.isAttach then
        detachButton.Label = GetLoca("Attach")
    end

    detachButton.OnClick = function ()
        if not self.parent then return end
        self.isAttach = not self.isAttach
        self:Refresh()
    end

    local tryLoadButton = loadCell:AddButton(GetLoca("Load File"))
    local tryLoadTooltipText = tryLoadButton:Tooltip():AddText("Try to load preset from file. Right click to overwrite existing preset.")
    local tryLoadTimer = nil

    local function tryLoad(overwrite)
        if tryLoadTimer then Timer:Cancel(tryLoadTimer) end
        local suc = self:Load(overwrite)
        if not suc then
            tryLoadTooltipText.Label = GetLoca("File not found or empty")
            tryLoadTimer = Timer:After(3000, function ()
                tryLoadTooltipText.Label = "Try to load preset from file."
            end)
        else
            tryLoadTooltipText.Label = GetLoca("Loaded presets from file")
            tryLoadTimer = Timer:After(3000, function ()
                tryLoadTooltipText.Label = "Try to load preset from file."
            end)
        end
    end

    tryLoadButton.OnClick = function()
        tryLoad(false)
    end

    tryLoadButton.OnRightClick = function()
        tryLoad(true)
    end

    if self.isWindow then
        self.panel.Closeable = true
        self.panel.OnClose = detachButton.OnClick
    end
end

function VisualTab:RenderAttachmentsSection()
    local entity = Ext.Entity.Get(self.guid) --[[@as EntityHandle]]
    
    local visual = VisualHelpers.GetEntityVisual(self.guid)

    if not entity then
        Debug("VisualTab:RenderAttachmentsSection - Entity not found for GUID " .. tostring(self.guid))
        return
    end

    if not visual then
        Debug("VisualTab:RenderAttachmentsSection - Visual not found for GUID " .. tostring(self.guid))
        return
    end

    if not visual.Attachments or #visual.Attachments == 0 then
        Debug("VisualTab:RenderAttachmentsSection - No attachments found for GUID " .. tostring(self.guid))
        return
    end

    if self.attachmentsHeader then
        self.attachmentsHeader:Destroy()
        self.attachmentsHeader = self.panel:AddCollapsingHeader(GetLoca("Attachments"))
    else
        self.attachmentsHeader = self.panel:AddCollapsingHeader(GetLoca("Attachments"))
    end


    local attachments = visual.Attachments or {}

    for attIndex,attach in ipairs(attachments) do

        local source = attach.Visual.VisualResource and attach.Visual.VisualResource.SourceFile or "Unknown Model"
        local attachNode = self.attachmentsHeader:AddTree(GetLastPath(source) .. "##" .. tostring(attIndex))

        for descIndex, obj in ipairs(attach.Visual.ObjectDescs) do
            local objFlags = LightCToArray(obj.Flags)

            local modelName = obj.Renderable and obj.Renderable.Model and obj.Renderable.Model.Name or "Unknown Model"
            local objNode = attachNode:AddTree(modelName .. "##" .. tostring(attIndex) .. "_" .. tostring(descIndex))
            --[[objNode.OnHoverEnter = function ()


                local visual = VisualHelpers.GetEntityVisual(self.guid)
                if not visual then
                    return
                end
                local attachments = visual.Attachments or {}
                local attach = attachments[attIndex]
                if not attach then
                    return
                end

                local desc = attach.Visual.ObjectDescs[descIndex]
                if not desc then
                    return
                end

                local renderable = desc.Renderable
                if not renderable then
                    return
                end


                NetChannel.Visualize:RequestToServer({
                    Type = "Box",
                    Min = renderable.WorldBound.Min,
                    Max = renderable.WorldBound.Max,
                    LineThickness = 0.1,
                    Duration = 2000
                }, function (response)
    
                end)
            end]]

            local function getliveMat()
                local visual = VisualHelpers.GetEntityVisual(self.guid)
                if not visual then
                    return nil
                end
                local attachments = visual.Attachments or {}
                local attach = attachments[attIndex]
                if not attach then
                    return nil
                end

                local desc = attach.Visual.ObjectDescs[descIndex]
                if not desc then
                    return nil
                end

                local renderable = desc.Renderable --[[@as RenderableObject]]
                if not renderable then
                    return nil
                end

                local material = renderable.ActiveMaterial
                if not material then
                    return nil
                end

                return material
            end

            local materialEditor = MaterialTab.new(objNode, obj.Renderable.ActiveMaterial.Material.Name, getliveMat)
            materialEditor:Render()

            self.Materials[modelName] = materialEditor
        end
        ::continue::
    end

end

function VisualTab:RenderMaterialEditor()
    if next(LightCToArray(Ext.Entity.Get(self.guid).Visual.Visual.ObjectDescs)) == nil then
        return
    end

    if self.materialHeader then
        self.materialHeader:Destroy()
        self.materialHeader = self.panel:AddCollapsingHeader(GetLoca("Material Editor"))
    else
        self.materialHeader = self.panel:AddCollapsingHeader(GetLoca("Material Editor"))
    end

    if self.isWindow then
        self.materialHeader.DefaultOpen = true
    end

    --self.materialRoot = self.materialHeader:AddTree(GetLoca("Materials"))

    local materialNameCnt = {}

    for descIndex, desc in ipairs(Ext.Entity.Get(self.guid).Visual.Visual.ObjectDescs) do
        if not desc.Renderable or not desc.Renderable.ActiveMaterial then
            goto continue
        end

        local renderable = desc.Renderable --[[@as RenderableObject]]

        local material = renderable.ActiveMaterial --[[@as AppliedMaterial]]

        local meshName = renderable.Model and renderable.Model.Name or "Unknown Mesh"

        local materialNode = self.materialHeader:AddTree(meshName .. "##" .. tostring(descIndex))

        local function getliveMat()
            return VisualHelpers.GetMaterial(self.guid, descIndex)
        end
    
        local materialEditor = MaterialTab.new(materialNode, material.MaterialName, getliveMat) --[[@as MaterialTab]]
        materialEditor:Render()

        self:RenderScaleSliders(materialNode, descIndex, meshName)

        while self.Materials[meshName] do
            materialNameCnt[meshName] = (materialNameCnt[meshName] or 1) + 1
            meshName = meshName .. " (" .. tostring(materialNameCnt[meshName]) .. ")"
        end

        self.Materials[meshName] = materialEditor

        ::continue::
    end
end

function VisualTab:RenderEffectEditor()
    local entity = Ext.Entity.Get(self.guid) --[[@as EntityHandle]]
    if entity.Effect == nil then
        return
    end

    self.hasEffect = true

    if self.effectHeader then
        self.effectHeader:Destroy()
        self.effectHeader = self.panel:AddCollapsingHeader(GetLoca("Effect Editor"))
    else
        self.effectHeader = self.panel:AddCollapsingHeader(GetLoca("Effect Editor"))
    end

    if self.isWindow then
        self.effectHeader.DefaultOpen = true
    end

    --self.effectRoot = self.effectHeader:AddTree(GetLoca("Effects"))

    local effectNameCnt = {}

    -- WHY is effect so disorderly
    for compIndex, component in ipairs(entity.Effect.Timeline.Components) do

        --_P(component.TypeName)

        if component.TypeName == "Light" then
            effectNameCnt[component.TypeName] = (effectNameCnt[component.TypeName] or 0) + 1
            local cnt = effectNameCnt[component.TypeName]
            local nodeName = GetLoca("Light") .. (cnt ~= 1 and " (" .. cnt .. ")" or "")
            local newNode = self.effectHeader:AddTree(nodeName)

            self:RenderLightComponent(newNode, component, compIndex, cnt)
            
            newNode:AddSeparator()

            self:RenderLightEntity(newNode, component, compIndex, cnt)
        end

        if component.TypeName == "ParticleSystem" then
            effectNameCnt[component.TypeName] = (effectNameCnt[component.TypeName] or 0) + 1
            local cnt = effectNameCnt[component.TypeName]
            local nodeName = GetLoca("Particle System") .. (cnt ~= 1 and " (" .. cnt .. ")" or "")
            local newNode = self.effectHeader:AddTree(nodeName)
            self:RenderParticleSystemComponent(newNode, component, compIndex, cnt)
        end

    end
end

---@param node any
---@param component AspkComponent
---@param compIndex any
function VisualTab:RenderLightEntity(node, component, compIndex)
    local entityNode = node

    local lightEntity = component.LightEntity --[[@as LightComponent]]
    if not lightEntity or not lightEntity.Light then
        return
    end

    local light = lightEntity.Light --[[@as LightComponent]]
    local lightTemplate = light.Template

    local entityColorNode = entityNode:AddTree(GetLoca("Light Entity Color"))
    local angleNode = entityNode:AddTree(GetLoca("Light Angles"))
    local gainNode = entityNode:AddTree(GetLoca("Gain"))
    local scatteringNode = entityNode:AddTree(GetLoca("Scattering"))
    --local attenuationNode = entityNode:AddTree(GetLoca("Attenuation"))
    --local templateNode = entityNode:AddTree(GetLoca("Template Settings"))
    local otherNode = entityNode:AddTree(GetLoca("Other Settings"))
    
    local scalarPropNameMap = {
        --Kelvin = {min=1000, max=40000, step=100, displayName = "Template_Kelvin" , isTemplate = true},
        SpotLightInnerAngle = {min=0, max=180, step=1, displayName = "Inner Angle", preassign = angleNode},
        SpotLightOuterAngle = {min=0, max=180, step=1, displayName = "Outer Angle", preassign = angleNode},
        Gain = {min=0, max=100, step=0.1, displayName = "Gain", preassign = gainNode},
        EdgeSharpening = {min=0, max=10, step=0.05, displayName = "Edge Sharpness", preassign = otherNode},
        --Intensity = {min=-1000, max=1000, step=10, displayName = "Template Intensity", isTemplate = true, preassign = templateNode},
        --Radius = {min=0, max=100, step=1, displayName = "Template Radius", --[[isTemplate = true,]] preassign = templateNode},
        ScatteringIntensityScale = {min=0, max=100, step=0.1, displayName = "Scattering Intensity Scale", preassign = scatteringNode},
    }

    local vec3PropNameMap = {
        Blackbody = { displayName = "Blackbody", preassign = otherNode },
        DirectionLightDimensions = { displayName = "Direction Light Dimensions", preassign = otherNode },
        Color = { displayName = "Light Entity Color", preassign = entityColorNode },
    }

    local function saveLightEntityProperty(key, propName, value)
        self.modifiedParams[key] = {
            Type = "LightEntity",
            CompIndex = compIndex,
            PropertyName = propName,
            Value = value,
            IsTemplate = scalarPropNameMap[propName] and scalarPropNameMap[propName].isTemplate or false,
        }
    end

    local function GetLiveLightEntity()
        local entity = Ext.Entity.Get(self.guid)
        if not entity.Effect then return nil end
        return entity.Effect.Timeline.Components[compIndex].LightEntity.Light
    end

    for propName, property in pairs(light) do
        if scalarPropNameMap[propName] and type(property) == "number" then
            local key = "LightEntity::" .. compIndex .. "::" .. propName
            self:CheckKey(key)
            local valueNode = scalarPropNameMap[propName].preassign or entityNode:AddTree(scalarPropNameMap[propName] or propName)
            if scalarPropNameMap[propName].isTemplate or valueNode == angleNode then
                valueNode:AddBulletText(scalarPropNameMap[propName].displayName or propName)
            elseif valueNode == otherNode then
                valueNode = valueNode:AddTree(scalarPropNameMap[propName].displayName or propName)
            end
            local initValue = property
            local currentValue = property
            local slider = AddSliderWithStep(valueNode, nil, currentValue, scalarPropNameMap[propName].min, scalarPropNameMap[propName].max, scalarPropNameMap[propName].step)
            slider.UserData.ResetButton.Visible = false
            slider.OnChange = function()
                local liveLight = GetLiveLightEntity()
                if not liveLight then return end
                liveLight[propName] = slider.Value[1]
                if scalarPropNameMap[propName].isTemplate then
                    liveLight.Template[propName] = slider.Value[1]
                end
                saveLightEntityProperty(key, propName, slider.Value[1])
            end
            local valueResetButton = valueNode:AddButton(GetLoca("Reset"))
            valueResetButton.IDContext = key .. "Reset"

            slider.OnRightClick = function()
                local liveLight = GetLiveLightEntity()
                if not liveLight then return end
                _P(liveLight[propName], slider.Value[1], "TemplateValue", liveLight.Template and liveLight.Template[propName] or "N/A")
            end

            valueResetButton.OnClick = function(sel, updateInit)
                local liveLight = GetLiveLightEntity()
                if not liveLight then return end

                if updateInit then
                    initValue = liveLight[propName]
                    return
                end

                liveLight[propName] = initValue
                if scalarPropNameMap[propName].isTemplate then
                    liveLight.Template[propName] = initValue
                end
                slider.Value = {initValue, initValue, initValue, initValue}
                self.modifiedParams[key] = nil
            end

            self.resetFuncs[key] = valueResetButton.OnClick

            self.updateFuncs[key] = function()
                local liveLight = GetLiveLightEntity()
                if not liveLight then return end
                if slider then
                    slider.Value = ToVec4(liveLight[propName])
                end
            end
        end

        if vec3PropNameMap[propName] and type(property) == "table" and #property == 3 then
            local key = "LightEntity::" .. compIndex .. "::" .. propName
            self:CheckKey(key)
            local valueNode = vec3PropNameMap[propName].preassign or entityNode:AddTree(vec3PropNameMap[propName].displayName or propName)
            if valueNode == otherNode then
                valueNode = valueNode:AddTree(vec3PropNameMap[propName].displayName or propName)
            end 
            local initValue = {property[1], property[2], property[3]}
            local currentValue = property

            local sliderX = AddSliderWithStep(valueNode, "X", currentValue[1], -100, 100, 0.1)
            valueNode:AddText("X").SameLine = true
            local sliderY = AddSliderWithStep(valueNode, "Y", currentValue[2], -100, 100, 0.1)
            valueNode:AddText("Y").SameLine = true
            local sliderZ = AddSliderWithStep(valueNode, "Z", currentValue[3], -100, 100, 0.1)
            valueNode:AddText("Z").SameLine = true
            local valueResetButton = valueNode:AddButton(GetLoca("Reset"))

            local colorEdit = valueNode:AddColorEdit("Color", {currentValue[1], currentValue[2], currentValue[3]})
            local function sliderOnChange()
                local liveLight = GetLiveLightEntity()
                if not liveLight then return end
                liveLight[propName] = {sliderX.Value[1], sliderY.Value[1], sliderZ.Value[1]}
                saveLightEntityProperty(key, propName, {sliderX.Value[1], sliderY.Value[1], sliderZ.Value[1]})
                if colorEdit then
                    colorEdit.Color = {sliderX.Value[1], sliderY.Value[1], sliderZ.Value[1], colorEdit.Color[4] or 1.0}
                end
            end

            local function colorEditOnChange()
                local liveLight = GetLiveLightEntity()
                if not liveLight then return end
                local col = colorEdit.Color
                liveLight[propName] = {col[1], col[2], col[3]}
                saveLightEntityProperty(key, propName, {col[1], col[2], col[3]})
                if sliderX and sliderY and sliderZ then
                    sliderX.Value = {col[1], col[1], col[1], col[1]}
                    sliderY.Value = {col[2], col[2], col[2], col[2]}
                    sliderZ.Value = {col[3], col[3], col[3], col[3]}
                end
            end

            sliderX.OnChange = sliderOnChange
            sliderY.OnChange = sliderOnChange
            sliderZ.OnChange = sliderOnChange

            colorEdit.OnChange = colorEditOnChange

            valueResetButton.OnClick = function(sel, updateInit)
                local liveLight = GetLiveLightEntity()
                if not liveLight then return end

                if updateInit then
                    initValue = {liveLight[propName][1], liveLight[propName][2], liveLight[propName][3]}
                    return
                end

                liveLight[propName] = {initValue[1], initValue[2], initValue[3]}
                sliderX.Value = ToVec4(initValue[1])
                sliderY.Value = ToVec4(initValue[2])
                sliderZ.Value = ToVec4(initValue[3])
                colorEdit.Color = {initValue[1], initValue[2], initValue[3], colorEdit.Color[4] or 1.0}
                self.modifiedParams[key] = nil
            end

            self.resetFuncs[key] = valueResetButton.OnClick
            self.updateFuncs[key] = function()
                local liveLight = GetLiveLightEntity()
                if not liveLight then return end
                if sliderX and sliderY and sliderZ then
                    sliderX.Value = ToVec4(liveLight[propName][1])
                    sliderY.Value = ToVec4(liveLight[propName][2])
                    sliderZ.Value = ToVec4(liveLight[propName][3])
                    colorEdit.Color = {liveLight[propName][1], liveLight[propName][2], liveLight[propName][3], colorEdit.Color[4] or 1.0}
                end
            end

        end
    end

end

---@param node any
---@param component AspkComponent
---@param compIndex integer
function VisualTab:RenderLightComponent(node, component, compIndex)
    local compNode = node

    local lComp = component --[[@as AspkLightComponent]]

    local properties = lComp.Properties

    local function saveLightProperty(key, propName, value)
        self.modifiedParams[key] = {
            Type = "Light",
            CompIndex = compIndex,
            PropertyName = propName,
            Value = value,
        }
    end

    local propNameMap = {
        --["Appearance.Flicker Amount"] = "Flicker Amount",
        ["Appearance.Intensity"] = "Intensity",
        ["Appearance.Radius"] = "Radius",
        ["Behavior.Flicker Speed"] = "Flicker Speed"
    }

    local overrideMap = {
        ["Appearance.Radius"] = "ModulateLightTemplateRadius",
        ["Behavior.Flicker Speed"] = "OverrideLightTemplateFlickerSpeed"
    }

    for propName, property in pairs(properties) do
        if propName == "Appearance.Color" then
            if not property.Frames[1].Color then
                goto continue
            end
            local key = "Light::" .. compIndex .. "::" .. propName
            self:CheckKey(key)
            local overrideKey = "Light::" .. compIndex .. "::OverrideLightTemplateColor"
            self:CheckKey(overrideKey)
            local colorNode = compNode:AddTree("Color")
            local initColor = property.Frames[1].Color
            local initBool = lComp.OverrideLightTemplateColor
            local currentColor = property.Frames[1].Color
            local colorResetButton = colorNode:AddButton(GetLoca("Reset"))
            local overrideEntityCheck = colorNode:AddCheckbox(GetLoca("Override Entity Color"), lComp.OverrideLightTemplateColor)
            overrideEntityCheck.OnChange = function(checkbox)
                local entity = Ext.Entity.Get(self.guid)
                if not entity.Effect then return end
                entity.Effect.Timeline.Components[compIndex].OverrideLightTemplateColor = checkbox.Checked
                saveLightProperty(overrideKey, "OverrideLightTemplateColor", checkbox.Checked)
            end
            overrideEntityCheck.SameLine = true

            self.updateFuncs[overrideKey] = function()
                local entity = Ext.Entity.Get(self.guid)
                if not entity.Effect then return end
                if overrideEntityCheck then
                    overrideEntityCheck.Checked = entity.Effect.Timeline.Components[compIndex].OverrideLightTemplateColor
                end
            end

            local colorPicker = colorNode:AddColorEdit("")
            --colorPicker.SameLine = true
            colorPicker.Color = currentColor
            colorPicker.OnChange = function(picker)
                local entity = Ext.Entity.Get(self.guid)
                if not entity.Effect then return end
                local frames = entity.Effect.Timeline.Components[compIndex].Properties[propName].Frames
                local colorValue = {picker.Color[1], picker.Color[2], picker.Color[3], picker.Color[4]}
                VisualHelpers.ChangeFrames(frames, colorValue, true)
                saveLightProperty(key, propName, colorValue)
            end

            colorResetButton.OnClick = function(sel, updateInit)
                local entity = Ext.Entity.Get(self.guid)
                if not entity.Effect then return end
                local component = entity.Effect.Timeline.Components[compIndex]
                local frames = component.Properties[propName].Frames

                if updateInit then
                    initColor = {frames[1].Color[1], frames[1].Color[2], frames[1].Color[3], frames[1].Color[4]}
                    initBool = component.OverrideLightTemplateColor
                    return
                end

                component.OverrideLightTemplateColor = initBool
                VisualHelpers.ChangeFrames(frames, initColor, true)
                colorPicker.Color = {initColor[1], initColor[2], initColor[3], initColor[4]}
                overrideEntityCheck.Checked = initBool
                self.modifiedParams[key] = nil
                self.modifiedParams[overrideKey] = nil
            end

            self.resetFuncs[key] = colorResetButton.OnClick

            self.updateFuncs[key] = function()
                local entity = Ext.Entity.Get(self.guid)
                if not entity.Effect then return end
                local frames = entity.Effect.Timeline.Components[compIndex].Properties[propName].Frames
                if frames and frames[1] and frames[1].Color and colorPicker then
                    local colorValue = frames[1].Color
                    colorPicker.Color = {colorValue[1], colorValue[2], colorValue[3], colorValue[4]}
                end
            end
        end

        if propNameMap[propName] then
            local key = "Light::" .. compIndex .. "::" .. propName
            self:CheckKey(key)
            local hasValue = false
            for type, value in pairs(property.KeyFrames[1].Frames[1]) do
                if type == "Value" and value then
                    hasValue = true
                    break
                end
            end
            -- A B C D value variation
            if not hasValue then
                if not property.KeyFrames or not property.KeyFrames[1] or not property.KeyFrames[1].Frames or not property.KeyFrames[1].Frames[1] then
                    goto continue
                end

                local valueNode = compNode:AddTree(propNameMap[propName] or propName)
                local valueResetButton = valueNode:AddButton(GetLoca("Reset"))
                local setTo0Button = valueNode:AddButton(GetLoca("Set to 0"))
                setTo0Button.SameLine = true
                local initValue = {property.KeyFrames[1].Frames[1].A, property.KeyFrames[1].Frames[1].B, property.KeyFrames[1].Frames[1].C, property.KeyFrames[1].Frames[1].D}
                local currentValue = property.KeyFrames[1].Frames[1]

                local sliderA = AddSliderWithStep(valueNode ,"A", currentValue.A, -100, 100, 0.1)
                valueNode:AddText("?Amplitude").SameLine = true
                local sliderB = AddSliderWithStep(valueNode, "B", currentValue.B, -100, 100, 0.1)
                valueNode:AddText("?Frequency").SameLine = true
                local sliderC = AddSliderWithStep(valueNode, "C", currentValue.C, -100, 100, 0.1)
                valueNode:AddText("?Phase").SameLine = true
                local sliderD = AddSliderWithStep(valueNode, "D", currentValue.D, -100, 100, 0.1)
                valueNode:AddText("Base").SameLine = true

                sliderA.OnChange = function(slider)
                    local entity = Ext.Entity.Get(self.guid)
                    if not entity.Effect then return end
                    local keyFrames = entity.Effect.Timeline.Components[compIndex].Properties[propName].KeyFrames
                    for keyFrameIndex, keyFrame in ipairs(keyFrames) do
                        VisualHelpers.ChangeABCDFrames(keyFrame.Frames, sliderA.Value[1], sliderB.Value[1], sliderC.Value[1], sliderD.Value[1])
                    end
                    saveLightProperty(key, propName, {sliderA.Value[1], sliderB.Value[1], sliderC.Value[1], sliderD.Value[1]})
                end

                sliderB.OnChange = function(slider)
                    local entity = Ext.Entity.Get(self.guid)
                    if not entity.Effect then return end
                    local keyFrames = entity.Effect.Timeline.Components[compIndex].Properties[propName].KeyFrames
                    for keyFrameIndex, keyFrame in ipairs(keyFrames) do
                        VisualHelpers.ChangeABCDFrames(keyFrame.Frames, sliderA.Value[1], sliderB.Value[1], sliderC.Value[1], sliderD.Value[1])
                    end
                    saveLightProperty(key, propName, {sliderA.Value[1], sliderB.Value[1], sliderC.Value[1], sliderD.Value[1]})
                end

                sliderC.OnChange = function(slider)
                    local entity = Ext.Entity.Get(self.guid)
                    if not entity.Effect then return end
                    local keyFrames = entity.Effect.Timeline.Components[compIndex].Properties[propName].KeyFrames
                    for keyFrameIndex, keyFrame in ipairs(keyFrames) do
                        VisualHelpers.ChangeABCDFrames(keyFrame.Frames, sliderA.Value[1], sliderB.Value[1], sliderC.Value[1], sliderD.Value[1])
                    end
                    saveLightProperty(key, propName, {sliderA.Value[1], sliderB.Value[1], sliderC.Value[1], sliderD.Value[1]})
                end

                sliderD.OnChange = function(slider)
                    local entity = Ext.Entity.Get(self.guid)
                    if not entity.Effect then return end
                    local keyFrames = entity.Effect.Timeline.Components[compIndex].Properties[propName].KeyFrames
                    for keyFrameIndex, keyFrame in ipairs(keyFrames) do
                        VisualHelpers.ChangeABCDFrames(keyFrame.Frames, sliderA.Value[1], sliderB.Value[1], sliderC.Value[1], sliderD.Value[1])
                    end
                    saveLightProperty(key, propName, {sliderA.Value[1], sliderB.Value[1], sliderC.Value[1], sliderD.Value[1]})
                end

                valueResetButton.OnClick = function(sel, updateInit)
                    local entity = Ext.Entity.Get(self.guid)
                    if not entity.Effect then return end
                    local keyFrames = entity.Effect.Timeline.Components[compIndex].Properties[propName].KeyFrames
                    if updateInit then
                        initValue = {keyFrames[1].Frames[1].A, keyFrames[1].Frames[1].B, keyFrames[1].Frames[1].C, keyFrames[1].Frames[1].D}
                        return
                    end

                    for keyFrameIndex, keyFrame in ipairs(keyFrames) do
                        VisualHelpers.ChangeABCDFrames(keyFrame.Frames, initValue[1], initValue[2], initValue[3], initValue[4])
                    end
                    sliderA.Value = {initValue[1], initValue[1], initValue[1], initValue[1]}
                    sliderB.Value = {initValue[2], initValue[2], initValue[2], initValue[2]}
                    sliderC.Value = {initValue[3], initValue[3], initValue[3], initValue[3]}
                    sliderD.Value = {initValue[4], initValue[4], initValue[4], initValue[4]}
                    self.modifiedParams[key] = nil
                end

                setTo0Button.OnClick = function()
                    local entity = Ext.Entity.Get(self.guid)
                    if not entity.Effect then return end
                    local keyFrames = entity.Effect.Timeline.Components[compIndex].Properties[propName].KeyFrames
                    for keyFrameIndex, keyFrame in ipairs(keyFrames) do
                        VisualHelpers.ChangeABCDFrames(keyFrame.Frames, 0, 0, 0, 0)
                    end
                    sliderA.Value = {0, 0, 0, 0}
                    sliderB.Value = {0, 0, 0, 0}
                    sliderC.Value = {0, 0, 0, 0}
                    sliderD.Value = {0, 0, 0, 0}
                    self.modifiedParams[key] = {0, 0, 0, 0}
                end

                self.resetFuncs[key] = valueResetButton.OnClick

                self.updateFuncs[key] = function()
                    local entity = Ext.Entity.Get(self.guid)
                    if not entity.Effect then return end
                    local keyFrames = entity.Effect.Timeline.Components[compIndex].Properties[propName].KeyFrames
                    if keyFrames and keyFrames[1] and keyFrames[1].Frames and keyFrames[1].Frames[1] and sliderA then
                        local frame = keyFrames[1].Frames[1]
                        sliderA.Value = {frame.A, frame.A, frame.A, frame.A}
                        sliderB.Value = {frame.B, frame.B, frame.B, frame.B}
                        sliderC.Value = {frame.C, frame.C, frame.C, frame.C}
                        sliderD.Value = {frame.D, frame.D, frame.D, frame.D}
                    end
                end

                goto continue
            end

            local valueNode = compNode:AddTree(propNameMap[propName] or propName)
            local valueResetButton = valueNode:AddButton(GetLoca("Reset"))
            local resetBoolFunc = nil

            if overrideMap[propName] then
                local boolName = overrideMap[propName]
                local overrideKey = "Light::" .. compIndex .. "::" .. boolName
                self:CheckKey(overrideKey)
                local initBool = lComp[boolName]
                local overrideCheck = valueNode:AddCheckbox(GetLoca(boolName), lComp[boolName] or false)
                overrideCheck.OnChange = function(checkbox)
                    local entity = Ext.Entity.Get(self.guid)
                    if not entity.Effect then return end
                    entity.Effect.Timeline.Components[compIndex][boolName] = checkbox.Checked
                    saveLightProperty(overrideKey, boolName, checkbox.Checked)
                end

                self.updateFuncs[overrideKey] = function()
                    local entity = Ext.Entity.Get(self.guid)
                    if not entity.Effect then return end
                    if overrideCheck then
                        overrideCheck.Checked = entity.Effect.Timeline.Components[compIndex][boolName]
                    end
                end

                resetBoolFunc = function()
                    local entity = Ext.Entity.Get(self.guid)
                    if not entity.Effect then return end
                    local component = entity.Effect.Timeline.Components[compIndex]
                    component[boolName] = initBool
                    overrideCheck.Checked = initBool
                    self.modifiedParams[overrideKey] = nil 
                end    

                overrideCheck.SameLine = true
            end

            local initValue = property.KeyFrames[1].Frames[1].Value
            local currentValue = property.KeyFrames[1].Frames[1].Value
            local valueSlider = AddSliderWithStep(valueNode, key, currentValue, -100, 100, 0.1)
            valueSlider.UserData.ResetButton.Visible = false
            if not overrideMap[propName] then
                valueSlider.UserData.StepInput.SameLine = true
            end
            valueSlider.OnChange = function(slider)
                local entity = Ext.Entity.Get(self.guid)
                if not entity.Effect then return end
                local keyFrames = entity.Effect.Timeline.Components[compIndex].Properties[propName].KeyFrames
                for keyFrameIndex, keyFrame in ipairs(keyFrames) do
                    VisualHelpers.ChangeFrames(keyFrame.Frames, slider.Value[1])
                end
                saveLightProperty(key, propName, slider.Value[1])
            end

            valueResetButton.OnClick = function(sel, updateInit)
                local entity = Ext.Entity.Get(self.guid)
                if not entity.Effect then return end
                local keyFrames = entity.Effect.Timeline.Components[compIndex].Properties[propName].KeyFrames

                if updateInit then
                    initValue = keyFrames[1].Frames[1].Value
                    return
                end

                for keyFrameIndex, keyFrame in ipairs(keyFrames) do
                    VisualHelpers.ChangeFrames(keyFrame.Frames, initValue)
                end
                valueSlider.Value = {initValue, initValue, initValue, initValue}
                if resetBoolFunc then
                    resetBoolFunc()
                end
                self.modifiedParams[key] = nil
            end

            self.resetFuncs[key] = valueResetButton.OnClick

            self.updateFuncs[key] = function()
                local entity = Ext.Entity.Get(self.guid)
                if not entity.Effect then return end
                local keyFrames = entity.Effect.Timeline.Components[compIndex].Properties[propName].KeyFrames
                if keyFrames and keyFrames[1] and keyFrames[1].Frames and keyFrames[1].Frames[1] and valueSlider then
                    local frame = keyFrames[1].Frames[1]
                    valueSlider.Value = {frame.Value, frame.Value, frame.Value, frame.Value}
                end
            end
        end
        ::continue::
    end
end

---@param node any
---@param component AspkComponent
---@param compIndex integer
function VisualTab:RenderParticleSystemComponent(node, component, compIndex)
    local compNode = node

    local psComp = component --[[@as AspkParticleSystemComponent]]

    local function saveParticleProperty(key, propName, value)
        self.modifiedParams[key] = {
            Type = "ParticleSystem",
            CompIndex = compIndex,
            PropertyName = propName,
            Value = value
        }
    end

    local scalarPropNameMap = {
        Brightness_ = {min=0, max=10, step=0.1, displayName="Brightness"},
        UniformScale = {min=0, max=10, step=0.1, displayName="Uniform Scale"},
    }

    local vec4PropNameMap = {
        Color = "Color",
    }

    for propName, property in pairs(psComp) do 
        if scalarPropNameMap[propName] and type(property) == "number" then
            local key = "ParticleSystem::" .. compIndex .. "::" .. propName
            self:CheckKey(key)
            local valueNode = compNode:AddTree(scalarPropNameMap[propName].displayName or propName)
            local valueResetButton = valueNode:AddButton(GetLoca("Reset"))
            local initValue = property
            local currentValue = property
            local slider = AddSliderWithStep(valueNode, nil, currentValue, scalarPropNameMap[propName].min, scalarPropNameMap[propName].max, scalarPropNameMap[propName].step)
            slider.UserData.ResetButton.Visible = false
            slider.OnChange = function(slider)
                local entity = Ext.Entity.Get(self.guid)
                if not entity.Effect then return end
                local liveComponent = entity.Effect.Timeline.Components[compIndex]
                liveComponent[propName] = slider.Value[1]
                saveParticleProperty(key, propName, slider.Value[1])
            end

            valueResetButton.OnClick = function(sel, updateInit)
                local entity = Ext.Entity.Get(self.guid)
                if not entity.Effect then return end
                local liveComponent = entity.Effect.Timeline.Components[compIndex]

                if updateInit then
                    initValue = liveComponent[propName]
                    return
                end

                liveComponent[propName] = initValue
                slider.Value = {initValue, initValue, initValue, initValue}
                self.modifiedParams[key] = nil
            end

            self.resetFuncs[key] = valueResetButton.OnClick
            self.updateFuncs[key] = function()
                local entity = Ext.Entity.Get(self.guid)
                if not entity.Effect then return end
                local liveComponent = entity.Effect.Timeline.Components[compIndex]
                if liveComponent[propName] and slider then
                    slider.Value = {liveComponent[propName], liveComponent[propName], liveComponent[propName], liveComponent[propName]}
                end
            end

            goto continue
        end

        if vec4PropNameMap[propName] and type(property) == "table" and #property == 4 then
            local key = "ParticleSystem::" .. compIndex .. "::" .. propName
            self:CheckKey(key)
            local valueNode = compNode:AddTree(vec4PropNameMap[propName] or propName)
            local valueResetButton = valueNode:AddButton(GetLoca("Reset")) 
            local initValue = {property[1], property[2], property[3], property[4]}
            local currentValue = property
            local colorEdit = valueNode:AddColorEdit("")
            colorEdit.SameLine = true
            colorEdit.Color = currentValue
            colorEdit.OnChange = function(picker)
                local entity = Ext.Entity.Get(self.guid)
                if not entity.Effect then return end
                local liveComponent = entity.Effect.Timeline.Components[compIndex]
                local colorValue = {picker.Color[1], picker.Color[2], picker.Color[3], picker.Color[4]}
                liveComponent[propName] = colorValue
                saveParticleProperty(key, propName, colorValue)
            end

            valueResetButton.OnClick = function(sel, updateInit)
                local entity = Ext.Entity.Get(self.guid)
                if not entity.Effect then return end
                local liveComponent = entity.Effect.Timeline.Components[compIndex]

                if updateInit then
                    initValue = {liveComponent[propName][1], liveComponent[propName][2], liveComponent[propName][3], liveComponent[propName][4]}
                    return
                end

                liveComponent[propName] = {initValue[1], initValue[2], initValue[3], initValue[4]}
                colorEdit.Color = {initValue[1], initValue[2], initValue[3], initValue[4]}
                self.modifiedParams[key] = nil
            end

            self.resetFuncs[key] = valueResetButton.OnClick
            self.updateFuncs[key] = function()
                local entity = Ext.Entity.Get(self.guid)
                if not entity.Effect then return end
                local liveComponent = entity.Effect.Timeline.Components[compIndex]
                if liveComponent[propName] and colorEdit then
                    local col = liveComponent[propName]
                    colorEdit.Color = {col[1], col[2], col[3], col[4]}
                end
            end

            goto continue
        end

        ::continue::
    end
end

function VisualTab:RenderScaleSliders(parent, descIndex, materialName)
    local tempEntity = Ext.Entity.Get(self.guid)
    local tempRenderable = tempEntity.Visual.Visual.ObjectDescs[descIndex].Renderable
    if not tempRenderable then
        Error("VisualTab:RenderScaleSliders - No renderable found for descIndex: " .. descIndex)
        return
    end

    local scaleNode = parent:AddTree(GetLoca("Scale"))
    local key = materialName .. "::" .. descIndex .. "::Scale"
    local oriScale = tempRenderable.WorldTransform.Scale
    local currentScale = tempRenderable.WorldTransform.Scale

    scaleNode:AddText(GetLoca("Uniform Scale"))
    local uniformScaleSlider = AddSliderWithStep(scaleNode, materialName .. "UniformScale", currentScale[1], 0.1, 100, 0.1)
    scaleNode:AddText("X")
    local scaleXSlider = AddSliderWithStep(scaleNode, materialName .. "ScaleX", currentScale[1], 0.1, 100, 0.1)
    scaleXSlider.SameLine = true
    scaleNode:AddText("Y")
    local scaleYSlider = AddSliderWithStep(scaleNode, materialName .. "ScaleY", currentScale[2], 0.1, 100, 0.1)
    scaleYSlider.SameLine = true
    scaleNode:AddText("Z")
    local scaleZSlider = AddSliderWithStep(scaleNode, materialName .. "ScaleZ", currentScale[3], 0.1, 100, 0.1)
    scaleZSlider.SameLine = true

    local scaleResetButton = scaleNode:AddButton(GetLoca("Reset"))

    scaleResetButton.IDContext = materialName .. "ScaleResetButton"
    uniformScaleSlider.IDContext = materialName .. "UniformScaleSlider"
    scaleXSlider.IDContext = materialName .. "ScaleXSlider"
    scaleYSlider.IDContext = materialName .. "ScaleYSlider"
    scaleZSlider.IDContext = materialName .. "ScaleZSlider"

    local function saveScale()
        self.modifiedParams[key] = {
            Type = "Scale",
            DescIndex = descIndex,
            Value = {
                scaleXSlider.Value[1],
                scaleYSlider.Value[1],
                scaleZSlider.Value[1]
            }
        }
    end

    local function scaleSliderOnChange()
        local entity = Ext.Entity.Get(self.guid)
        if not self:CheckVisual() then return end
        local renderable = entity.Visual.Visual.ObjectDescs[descIndex].Renderable
        renderable.WorldTransform.Scale = {
            scaleXSlider.Value[1],
            scaleYSlider.Value[1],
            scaleZSlider.Value[1]
        }
        saveScale()
    end

    uniformScaleSlider.OnChange = function(slider)
        scaleXSlider.Value = ToVec4(slider.Value[1])
        scaleYSlider.Value = ToVec4(slider.Value[1])
        scaleZSlider.Value = ToVec4(slider.Value[1])
        scaleSliderOnChange()
        saveScale()
    end

    scaleXSlider.OnChange = scaleSliderOnChange
    scaleYSlider.OnChange = scaleSliderOnChange
    scaleZSlider.OnChange = scaleSliderOnChange

    scaleResetButton.OnClick = function(sel, updateInit)
        local entity = Ext.Entity.Get(self.guid)
        if not self:CheckVisual() then return end
        local renderable = entity.Visual.Visual.ObjectDescs[descIndex].Renderable

        if updateInit then
            oriScale = {
                renderable.WorldTransform.Scale[1],
                renderable.WorldTransform.Scale[2],
                renderable.WorldTransform.Scale[3]
            }
            return
        end

        renderable.WorldTransform.Scale = oriScale
        uniformScaleSlider.Value = {oriScale[1], oriScale[1], oriScale[1], oriScale[1]}
        scaleXSlider.Value = {oriScale[1], oriScale[1], oriScale[1], oriScale[1]}
        scaleYSlider.Value = {oriScale[2], oriScale[2], oriScale[2], oriScale[2]}
        scaleZSlider.Value = {oriScale[3], oriScale[3], oriScale[3], oriScale[3]}
        self.modifiedParams[key] = nil
    end

    self.resetFuncs[key] = scaleResetButton.OnClick

    self.updateFuncs[key] = function()
        local entity = Ext.Entity.Get(self.guid)
        if not self:CheckVisual() then return end
        local renderable = entity.Visual.Visual.ObjectDescs[descIndex].Renderable
        if renderable and renderable.WorldTransform then
            local scale = renderable.WorldTransform.Scale
            uniformScaleSlider.Value = {scale[1], scale[1], scale[1], scale[1]}
            scaleXSlider.Value = {scale[1], scale[1], scale[1], scale[1]}
            scaleYSlider.Value = {scale[2], scale[2], scale[2], scale[2]}
            scaleZSlider.Value = {scale[3], scale[3], scale[3], scale[3]}
        end
    end
end

function VisualTab:Add(guid, displayName, parent, templateName)
    if not EntityExists(guid) then
        Error("VisualTab:Add - Entity with GUID " .. guid .. " does not exist.")
        return nil
    end
    
    local visualTab = VisualTab.new(guid, displayName, parent, templateName)
    visualTab:Render()
    return visualTab
end

function VisualTab:Save(name, overwrite)
    local templateName = self.templateName or GetTemplateNameForGuid(self.guid)

    if not templateName then
        Error("VisualTab:Save - No template name found for GUID: " .. self.guid)
        return false
    end

    if self.savedModifiedParams and self.savedModifiedParams[name] and not overwrite then
        ConfirmPopup:QuickConfirm(
            string.format(GetLoca("A preset named '%s' already exists. Overwrite?"), name),
            function()
                self:Save(name, true)
            end,
            nil,
            10
        )
        return false
    end

    local saveName = name or self.displayName or "Unnamed"

    local filePath = GetVisualPresetsPath(templateName)
    local oriFile = Ext.Json.Parse(Ext.IO.LoadFile(filePath) or "{}")

    local Mats = {}
    for key, mat in pairs(self.Materials) do
        local params = mat:ExportChanges()
        Mats[key] = params
    end

    oriFile[saveName] = {
        Name = saveName,
        TemplateName = templateName,
        ModifiedParams = self.modifiedParams or {},
        Materials = Mats
    }

    local ok, err = Ext.IO.SaveFile(filePath, Ext.Json.Stringify(oriFile))
    if not ok then
        Error("Failed to save VisualTab data: " .. err)
        return false
    end

    local refFilePath = GetVisualReferencePath()
    local refFile = Ext.Json.Parse(Ext.IO.LoadFile(refFilePath) or "{}")

    refFile[templateName] = refFile[templateName] or {}

    local refOk = Ext.IO.SaveFile(refFilePath, Ext.Json.Stringify(refFile))
    if not refOk then
        Error("Failed to save VisualTab reference data: " .. err)
    end

    --Info("Saved VisualTab preset as '" .. saveName .. "' for template: " .. templateId)
    self.currentPreset = saveName
    EntityStore[self.guid].VisualPreset = saveName
    self:Load()

    --Info("VisualTab:Save - Preset '" .. saveName .. "' saved successfully for template: " .. templateName)
    return true
end

function VisualTab:Load(notoverwrite)
    local templateName = self.templateName or GetTemplateNameForGuid(self.guid)

    if not templateName then
        Error("VisualTab:Load - No template name found for GUID: " .. self.guid)
        return false
    end

    local filePath = GetVisualPresetsPath(templateName)
    local fileContent = Ext.IO.LoadFile(filePath)

    if not fileContent then
        --Error("VisualTab:Load - Failed to load file: " .. filePath)
        return false
    end

    local data = Ext.Json.Parse(fileContent)

    if not data or type(data) ~= "table" or not next(data) then
        --Error("Invalid VisualTab data format in: " .. filePath)
        return false
    end
    
    for name, presetData in pairs(data) do
        if self.savedModifiedParams and self.savedModifiedParams[name] and not notoverwrite then
            --Warning("Preset already loaded, skipping: " .. name)
        else
            self.savedModifiedParams[name] = presetData
        end
    end

    if self.saveInput and self.saveInput.OnChange then
        self.saveInput.OnChange()
    end

    local refFilePath = GetVisualReferencePath()
    local refFile = Ext.Json.Parse(Ext.IO.LoadFile(refFilePath) or "{}")
    if not refFile[templateName] then
        refFile[templateName] = {}
        local refOk, err = Ext.IO.SaveFile(refFilePath, Ext.Json.Stringify(refFile))
        if not refOk then
            Error("Failed to save VisualTab reference data: " .. err)
        end
    end

    return true
    --Info("VisualTab:Load - Loaded presets for template: " .. templateName)
end

function VisualTab:Remove(name)
    local templateName = self.templateName or GetTemplateNameForGuid(self.guid)

    if not templateName then
        Error("VisualTab:Remove - No template name found for GUID: " .. self.guid)
        return false
    end

    local filePath = GetVisualPresetsPath(templateName)

    local oriFile = Ext.Json.Parse(Ext.IO.LoadFile(filePath) or "{}")
    if not oriFile or type(oriFile) ~= "table" then
        Error("Failed to load or parse VisualTab data for removal.")
        return false
    end

    local removed = false
    if oriFile[name] then
        oriFile[name] = nil
        removed = true
    end

    if not removed then
        Warning("Preset not found for removal: " .. name)
        return false
    end

    local ok, err = Ext.IO.SaveFile(filePath, Ext.Json.Stringify(oriFile))
    if not ok then
        Error("Failed to save VisualTab data after removal: " .. err)
        return false
    end

    if self.savedModifiedParams then
        self.savedModifiedParams[name] = nil
    end

    if #self.savedModifiedParams == 0 then
        local refFilePath = GetVisualReferencePath()
        local refFile = Ext.Json.Parse(Ext.IO.LoadFile(refFilePath) or "{}")
        if refFile[templateName] then
            refFile[templateName] = nil
            Ext.IO.SaveFile(refFilePath, Ext.Json.Stringify(refFile))
        end
        ClientVisualPresetData[templateName] = nil
    end

    --Info("Removed VisualTab preset: " .. name .. " from template: " .. templateId)
    self:Load()
    return true
end

function VisualTab:LoadPreset(name)
    if not self.savedModifiedParams then
        Error("No saved preset found with name: " .. name)
        return false
    end

    local preset = self.savedModifiedParams[name]

    if not preset or not preset.ModifiedParams then
        Warning("Preset not found or invalid: " .. name .. ", object: " .. self.templateName)
        return false
    end

    local presetParams = DeepCopy(preset.ModifiedParams)

    for _, resetFunc in pairs(self.resetFuncs) do
        if resetFunc then
            resetFunc()
        end
    end

    VisualHelpers.ApplyVisualParams(self.guid, presetParams)

    self.currentPreset = name
    self.modifiedParams = DeepCopy(presetParams)

    for key, matParams in pairs(preset.Materials or {}) do
        if self.Materials[key] then
            self.Materials[key].Editor:ApplyParameters(matParams)
        end
    end

    if self.loadCombo then
        SetCombo(self.loadCombo, name)
    end

    EntityStore[self.guid].VisualPreset = name

    self:UpdateAll()
end

function VisualTab:UpdateAll()
    for _, func in pairs(self.updateFuncs) do
        func()
    end
end

function VisualTab:TryUpdate(key)
    if self.updateFuncs[key] then
        self.updateFuncs[key]()
    else
        --Warning("No update function found for key: " .. key)
    end
end

function VisualTab:_getAllPresetNames()
    if not self.savedModifiedParams then
        return {}
    end

    local names = {}
    local templateName = self.templateName or GetTemplateNameForGuid(self.guid)
    for name, entry in pairs(self.savedModifiedParams) do
        if entry.TemplateName == templateName then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

function VisualTab:Collapsed()
    if not self.isValid or not self.isVisible then
        return
    end

    self.resetFuncs = {}
    self.updateFuncs = {}

    if self.saveInputKeySub then
        self.saveInputKeySub:Unsubscribe()
        self.saveInputKeySub = nil
    end

    if self.materialHeader then
        self.materialHeader:Destroy()
        self.materialHeader = nil
    end

    if self.effectHeader then
        self.effectHeader:Destroy()
        self.effectHeader = nil
    end

    if self.panel then
        if self.isWindow then
            DeleteWindow(self.panel)
            self.panel = nil
        else
            self.panel:Destroy()
            self.panel = nil
        end
    end

    self.isVisible = false
end

function VisualTab:Refresh(retryCnt)
    if self.isWindow then
        self.lastPosition = self.panel.LastPosition
        self.lastSize = self.panel.LastSize
    end

    self:Collapsed()
    self:Render(retryCnt)
end

function VisualTab:CheckKey(key)
    if self.keys[key] then
        Warning("Duplicate key detected in VisualTab: " .. key)
    end
    self.keys[key] = true
end

function VisualTab:Destroy()
    if not self.isValid then
        return
    end

    if self.replaceSub then
        Ext.Events.NetMessage:Unsubscribe(self.replaceSub)
        self.replaceSub = nil
    end

    if self.panel then
        self:Collapsed()
    end

    self.isValid = false
end

function VisualTab:CheckVisual()
    local entity = Ext.Entity.Get(self.guid)
    if not entity then
        Error("VisualTab:CheckVisual - Entity not found for GUID: " .. self.guid)
        return false
    end

    if not entity.Visual or not entity.Visual.Visual then
        self:Refresh()
        return false
    end

    return true
end

function VisualTab:OnDetach() end

function VisualTab:OnAttach() end

function VisualTab:OnChange() end