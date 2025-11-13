local VISUALTAB_WIDTH = 800 * SCALE_FACTOR
local VISUALTAB_HEIGHT = 1000 * SCALE_FACTOR

local visualTabCache = {}

--- @class VisualTab
--- @field Materials table<string, MaterialTab>
--- @field new fun(guid: GUIDSTRING, displayName: string|nil, parent: ExtuiTreeParent|nil, templateName: string|nil): VisualTab
--- @field FetchByGuid fun(guid: GUIDSTRING): VisualTab|nil
VisualTab = {}
VisualTab.__index = VisualTab

function VisualTab.FetchByGuid(guid)
    return visualTabCache[guid]
end

function VisualTab.new(guid, displayName, parent, templateName)
    local obj = setmetatable({}, VisualTab)

    for key, value in pairs(visualTabCache) do
        if not VisualHelpers.GetEntityVisual(key) then
            visualTabCache[key] = nil
        end
    end

    if visualTabCache[guid] then
        visualTabCache[guid]:Refresh()
        return visualTabCache[guid]
    end

    obj:__init(guid, displayName, parent, templateName)

    visualTabCache[guid] = obj

    return obj
end

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
    self.resetParams = {}

    self.currentPreset = EntityStore[guid] and EntityStore[guid].VisualPreset or nil

    self.updateFuncs = {}
    self.resetFuncs = {}
    self.Materials = {}


    if not templateName and not EntityStore[guid] then
        NetChannel.GetTemplate:RequestToServer({ Guid = self.guid }, function(response)
            if response.GuidToTemplateId and response.GuidToTemplateId[self.guid] then
                self.templateId = response.GuidToTemplateId[self.guid]
                local getTemplateName = TrimTail(response.GuidToTemplateId[self.guid], 37)
                self.templateName = getTemplateName
                self:SetupTemplate()
                self:Refresh()
                Debug("VisualTab: Received template name from server: " .. self.templateName)
            else
                Error("VisualTab: Could not get template name from server for entity " .. self.guid)
            end
        end)
    else
        self:SetupTemplate()
    end
end

function VisualTab:SetupTemplate()
    local stored = EntityStore:GetStoredData(self.guid)
    self.templateId = self.templateId or (stored and stored.TemplateId) or nil
    self.templateName = self.templateName or (stored and TrimTail(stored.TemplateId, 37)) or "Unknown"
    local templateName = self.templateName or "Unknown"

    if self.tooltipTemplate then
        self.tooltipTemplate.Label = GetLoca("Template: ") .. templateName
    end

    if not ClientVisualPresetData[templateName] then
        ClientVisualPresetData[templateName] = {}
    end

    self.savedPresets = ClientVisualPresetData[templateName]

    self:Load()

    if self.currentPreset then
        self:LoadPreset(self.currentPreset)
    end
end

function VisualTab:ReapplyCurrentChanges()
    for _, mat in pairs(self.Materials) do
        mat.Editor:Reapply()
    end
end

function VisualTab:GetCurrentPreset()
    return self.currentPreset
end

function VisualTab:Render(retryCnt)
    if self.isVisible or not self.templateId then
        return
    end

    self.displayName = self.displayName or GetDisplayNameFromGuid(self.guid)

    if self.parent and self.isAttach then
        self:OnAttach()
        self.panel = self.parent:AddTabItem(GetLoca("Visual"))
        self.isWindow = false
    else
        self.panel = RegisterWindow(self.guid, self.displayName, "VisualTab", self, self.lastPosition,
            self.lastSize or { VISUALTAB_WIDTH, VISUALTAB_HEIGHT })
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
            rerenderButton:Tooltip():AddText(GetLoca("Entity is too far away, in inventory, or has no visual."))
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

    self:RenderAttachmentSection()
    self:RenderObjectSection()
    self:RenderEffectSection()
end

function VisualTab:RenderPresetsCell()
    if Ext.Entity.Get(self.guid) and not self.isAttach then
        local icon = GetIcon(self.guid) or "Item_Unknown"
        self.symbol = self.topLeftCell:AddImage(icon)
        self.symbol.ImageData.Size = { 64 * SCALE_FACTOR, 64 * SCALE_FACTOR }
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

    self.saveInputKeySub = SubscribeKeyInput({ Key = "RETURN" }, function()
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

    local reapplyBtn = self.topLeftCell:AddButton(GetLoca("Reapply Changes"))

    reapplyBtn.SameLine = true
    reapplyBtn.OnClick = function()
        self:ReapplyCurrentChanges()
    end

    local warningImage = self.topLeftCell:AddImage(RB_ICONS.Warning) --[[@as ExtuiImageButton]]
    warningImage.Tint = { 1, 0.5, 0.5, 1 }
    warningImage.ImageData.Size = { 32 * SCALE_FACTOR, 32 * SCALE_FACTOR }
    warningImage.SameLine = true
    if self.templateName then
        self.tooltipTemplate = warningImage:Tooltip():AddText(GetLoca("Template: ") .. self.templateName)
    end
    warningImage:Tooltip():AddText(GetLoca("Some changes will affect all instances of the same template."))
    warningImage:Tooltip():AddText(GetLoca("If 'Reset All' doesn't work, reload a save."))

    resetAllButton.OnClick = function(_, notResetOnServer)
        Timer:Ticks(10, function()
            local entity = Ext.Entity.Get(self.guid) --[[@as EntityHandle]]
            local isChara = CIsCharacter(self.guid)

            for key, matTab in pairs(self.Materials) do
                matTab.Editor:ClearParameters()

                if not isChara or notResetOnServer then
                    matTab.Editor:ResetAll()
                end

                matTab:UpdateUIState()
            end

            if isChara and not notResetOnServer then
                NetChannel.Replicate:SendToServer({
                    Guid = self.guid,
                    Field = "GameObjectVisual",
                })
            end

            if not isChara then
                for key, func in pairs(self.resetFuncs) do
                    func()
                end
            end
        end)
    end

    resetAllButton.OnRightClick = function()
        resetAllButton:OnClick(true)
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

    detachButton.OnClick = function()
        if not self.parent then return end
        self.isAttach = not self.isAttach
        self:Refresh()
    end

    detachButton.OnRightClick = function()
        self:Refresh()
    end

    if not self.parent then
        ApplyInfoButtonStyle(detachButton)
        detachButton.Label = GetLoca("Refresh")
        detachButton.OnClick = detachButton.OnRightClick
    end

    local tryLoadButton = loadCell:AddButton(GetLoca("Load File"))
    local tryLoadTooltipText = tryLoadButton:Tooltip():AddText(
        "Try to load preset from file. Right click to overwrite existing preset.")
    local tryLoadTimer = nil

    local function tryLoad(overwrite)
        if tryLoadTimer then Timer:Cancel(tryLoadTimer) end
        local suc = self:Load(overwrite)
        if not suc then
            tryLoadTooltipText.Label = GetLoca("File not found or empty")
            tryLoadTimer = Timer:After(3000, function()
                tryLoadTooltipText.Label = "Try to load preset from file."
            end)
        else
            tryLoadTooltipText.Label = GetLoca("Loaded presets from file")
            tryLoadTimer = Timer:After(3000, function()
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
        self.panel.OnClose = function()
            if self.parent then
                detachButton.OnClick()
            else
                self:Collapsed()
            end
        end
    end
end

function VisualTab:RenderAttachmentSection()
    local entity = Ext.Entity.Get(self.guid) --[[@as EntityHandle]]

    local visual = VisualHelpers.GetEntityVisual(self.guid)

    if not visual then return end

    if not visual.Attachments or #visual.Attachments == 0 then return end

    if self.attachmentsHeader then
        self.attachmentsHeader:Destroy()
        self.attachmentsHeader = self.panel:AddCollapsingHeader(GetLoca("Attachments"))
    else
        self.attachmentsHeader = self.panel:AddCollapsingHeader(GetLoca("Attachments"))
    end

    self.attachmentsHeader.OnHoverEnter = function ()
        self:RenderAttachmentEditors()
        self.attachmentsHeader.OnHoverEnter = nil
    end
end

function VisualTab:DetermineOverrideCharacterParameters()
    local overrideCharacterParams = {
        {}, -- ScalarParameters
        {}, -- Vector2Parameters
        {}, -- Vector3Parameters
        {}, -- VectorParameters
    }
    local entity = Ext.Entity.Get(self.guid) --[[@as EntityHandle]]
    local cca = entity.CharacterCreationAppearance
    if not cca then
        --- @diagnostic disable-next-line
        cca = entity.AppearanceOverride and entity.AppearanceOverride.Visual
    end
    if cca then
        local ccaPresetgroup = self.attachmentsHeader:AddTree(GetLoca("Character Creation Material Presets"))

        local allColors = {
            SkinColor = cca.SkinColor,
            HairColor = cca.HairColor,
            EyeColor = cca.EyeColor,
            LeftEyeColor = cca.SecondEyeColor,
        }
        local colorTypes = {
            SkinColor = "CharacterCreationSkinColor",
            HairColor = "CharacterCreationHairColor",
            EyeColor = "CharacterCreationEyeColor",
            LeftEyeColor = "CharacterCreationEyeColor",
        }
        local colorOrder = {
            "EyeColor",
            "LeftEyeColor",
            "HairColor",
            "SkinColor",
        }

        for _, colorIndex in ipairs(colorOrder) do
            local colorType = colorIndex
            local resUuid = allColors[colorType]
            if not resUuid or resUuid == GUID_NULL then goto continue end
            local res = Ext.StaticData.Get(resUuid, colorTypes[colorType]) --[[@as ResourceCharacterCreationColor]]
            if not res then goto continue end
            local matPresetRes = MaterialPresetProxy.new(res.MaterialPresetUUID)
            if not matPresetRes then goto continue end
            for ptype, params in pairs(matPresetRes.Parameters) do
                for paramName, value in pairs(params) do
                    if colorIndex == "LeftEyeColor" then
                        paramName = paramName .. "_L"
                    end
                    overrideCharacterParams[ptype] = overrideCharacterParams[ptype] or {}
                    if not overrideCharacterParams[ptype][paramName] then
                        overrideCharacterParams[ptype][paramName] = value
                    end
                end
            end
            ::continue::
        end

        ccaPresetgroup.OnHoverEnter = function()
            local twoColTable = ccaPresetgroup:AddTable("CCAPresetsTable", 2)
            local row = twoColTable:AddRow()
            for _, ctype in ipairs(colorOrder) do
                local color = allColors[ctype]
                if not color or color == GUID_NULL then goto continue end
                local res = Ext.StaticData.Get(color, colorTypes[ctype]) --[[@as ResourceCharacterCreationColor]]
                if not res then goto continue end
                local cell = row:AddCell()
                local preset = MaterialPresetsMenu:RenderPresetColorBox(res, cell)
                local prefixText = cell:AddText(GetLoca(ctype))
                prefixText.SameLine = true

                ::continue::
            end


            ccaPresetgroup.OnHoverEnter = nil
        end
    end

    local characterTemplate = entity.ClientCharacter.Template
    local characterVisual = Ext.Resource.Get(characterTemplate.CharacterVisualResourceID, "CharacterVisual") --[[@as ResourceCharacterVisualResource]]
    if characterVisual and characterVisual.VisualSet then
        local visualSet = characterVisual.VisualSet
        for _, matPreset in pairs(visualSet.MaterialOverrides.MaterialPresets) do
            local matPresetRes = MaterialPresetProxy.new(matPreset.MaterialPresetResource)
            if not matPresetRes then goto continue end
            for ptype, params in pairs(matPresetRes.Parameters) do
                for paramName, value in pairs(params) do
                    if not overrideCharacterParams[ptype][paramName] then
                        overrideCharacterParams[ptype][paramName] = value
                    end
                end
            end
            ::continue::
        end

        for _, visualResource in pairs(visualSet.Slots) do
            local vres = Ext.Resource.Get(visualResource.VisualResource, "Visual") --[[@as ResourceVisualResource]]
            if vres.HairPresetResourceId and IsUuid(vres.HairPresetResourceId) then
                local matPresetRes = MaterialPresetProxy.new(vres.HairPresetResourceId)
                if matPresetRes then
                    for ptype, params in pairs(matPresetRes.Parameters) do
                        for paramName, value in pairs(params) do
                            if not overrideCharacterParams[ptype][paramName] then
                                overrideCharacterParams[ptype][paramName] = value
                            end
                        end
                    end
                end
            end
        end

        
        local paramLists = {
            visualSet.MaterialOverrides.ScalarParameters,
            visualSet.MaterialOverrides.Vector2Parameters,
            visualSet.MaterialOverrides.Vector3Parameters,
            visualSet.MaterialOverrides.VectorParameters,
        }
        for ptype, paramList in pairs(paramLists) do
            for _, param in pairs(paramList) do
                if not overrideCharacterParams[ptype][param.Parameter] and param.Enabled then
                    local fValue = type(param.Value) == "number" and { param.Value } or param.Value
                    overrideCharacterParams[ptype][param.Parameter] = fValue
                end
            end
        end
    end

    return overrideCharacterParams
end

function VisualTab:RenderAttachmentEditors()
    local entity = Ext.Entity.Get(self.guid) --[[@as EntityHandle]]
    local visual = VisualHelpers.GetEntityVisual(self.guid)

    if not visual then return end

    local overrideCharacterParams = {}
    if CIsCharacter(self.guid) then
        overrideCharacterParams = self:DetermineOverrideCharacterParameters()
    end

    local attachments = visual.Attachments or {}

    for attIndex, attach in ipairs(attachments) do
        if #attach.Visual.ObjectDescs == 0 then goto continue end
        local vres = attach.Visual.VisualResource
        local source = vres and vres.SourceFile or "Unknown Model"
        local gr2FileName = GetLastPath(source)

        local displayName = gr2FileName

        local attachNode = self.attachmentsHeader:AddTree(displayName .. "##" .. tostring(attIndex))
        local lodNode = nil

        for descIndex, obj in ipairs(attach.Visual.ObjectDescs) do
            local modelName = obj.Renderable and obj.Renderable.Model and obj.Renderable.Model.Name or "Unknown Model"
            local parentNode = attachNode
            if modelName:find("LOD") then
                lodNode = lodNode or attachNode:AddTree("LODs")
                parentNode = lodNode
            end

            local objToggle = parentNode:AddSelectable("[+] " ..
                modelName .. "##" .. tostring(attIndex) .. "_" .. tostring(descIndex))
            local objNode = AddIndent(parentNode):AddGroup("ObjectDescGroup##" ..
                tostring(attIndex) .. "_" .. tostring(descIndex))

            local matName = obj.Renderable.ActiveMaterial.Material.Name
            local function getliveMat()
                return VisualHelpers.GetActiveMaterial(self.guid, descIndex, attIndex)
            end

            --- @return MaterialParametersSet|nil
            local function getliveParams()
                local mat = getliveMat()
                if not mat then return nil end
                return mat.Material.Parameters
            end

            local keyName = gr2FileName .. "::" .. modelName .. "::" .. tostring(attIndex) .. "::" .. tostring(descIndex)

            local function appltToOthers()
                local matTab = self.Materials[keyName]
                for _, otherMatTab in pairs(self.Materials) do
                    otherMatTab.Editor:ApplyParameters(matTab.Editor.Parameters)
                    otherMatTab:UpdateUIState()
                end
            end

            local materialTab = self.Materials[keyName] or MaterialTab.new(objNode, matName, getliveMat, getliveParams) --[[@as MaterialTab]]
            materialTab.Parent = objNode
            materialTab.ApplyToOthers = appltToOthers
            materialTab.Editor.Instance = getliveMat
            materialTab.Editor.ParamsSrc = getliveParams
            materialTab.Editor.ParamSetProxy:Update(getliveParams())
            materialTab.Editor:SetDefaultParameters(overrideCharacterParams)

            objToggle.OnClick = function(sel)
                objToggle.Selected = false
                materialTab.panel.Visible = not materialTab.panel.Visible

                sel.Label = (materialTab.panel.Visible and "[-] " or "[+] ") ..
                    modelName .. "##" .. tostring(attIndex) .. "_" .. tostring(descIndex)
            end

            objToggle.OnRightClick = function()
                objToggle.OnHoverEnter()
                materialTab:ShowContextMenu()
            end

            objToggle.OnHoverEnter = function()
                materialTab:Render()
                materialTab:UpdateUIState()
                materialTab.panel.Visible = false
                self:RenderTransformSliders(materialTab.panel, descIndex, attIndex, modelName)
                objToggle.OnHoverEnter = function() end
            end

            self.Materials[keyName] = materialTab
        end

        ::continue::
    end
end

function VisualTab:RenderObjectSection()
    if next(LightCToArray(Ext.Entity.Get(self.guid).Visual.Visual.ObjectDescs)) == nil then
        return
    end

    local visual = VisualHelpers.GetEntityVisual(self.guid)
    if not visual then return end

    if self.materialHeader then
        self.materialHeader:Destroy()
        self.materialHeader = self.panel:AddCollapsingHeader(GetLoca("Material Editor"))
    else
        self.materialHeader = self.panel:AddCollapsingHeader(GetLoca("Material Editor"))
    end

    if self.isWindow then
        self.materialHeader.DefaultOpen = true
    end

    self.materialHeader.OnHoverEnter = function ()
        self:RenderObjectEditor()
        self.materialHeader.OnHoverEnter = nil
    end
end

function VisualTab:RenderObjectEditor()
    local visual = VisualHelpers.GetEntityVisual(self.guid)
    if not visual then return end


    --self.materialRoot = self.materialHeader:AddTree(GetLoca("Materials"))

    for descIndex, desc in ipairs(visual.ObjectDescs) do
        if not desc.Renderable or not desc.Renderable.ActiveMaterial then
            goto continue
        end

        local renderable = desc.Renderable --[[@as RenderableObject]]

        local material = renderable.ActiveMaterial --[[@as AppliedMaterial]]

        local meshName = renderable.Model and renderable.Model.Name or "Unknown Mesh"
        if meshName == "" then
            meshName = "Unknown Mesh"
        end

        local materialNode = self.materialHeader:AddTree(meshName .. "##" .. tostring(descIndex))

        local function getliveMat()
            return VisualHelpers.GetMaterial(self.guid, descIndex)
        end

        local function getliveParams()
            local mat = getliveMat()
            if not mat then return nil end
            return mat.Parameters
        end

        --- @return MaterialParametersSet|nil

        local keyName = meshName .. "::" .. tostring(descIndex)

        local function appltToOthers()
            local matTab = self.Materials[keyName]
            for _, otherMatTab in pairs(self.Materials) do
                otherMatTab.Editor:ApplyParameters(matTab.Editor.Parameters)
                otherMatTab:UpdateUIState()
            end
        end

        local materialEditor = self.Materials[keyName] or
            MaterialTab.new(materialNode, material.MaterialName, getliveMat, getliveParams) --[[@as MaterialTab]]
        materialEditor.IsObject = true
        materialEditor.Parent = materialNode
        materialEditor.ApplyToOthers = appltToOthers
        materialEditor.Editor.Instance = getliveMat
        materialEditor.Editor.ParamsSrc = getliveParams
        materialEditor.Editor.ParamSetProxy:Update(getliveParams())

        materialNode.OnHoverEnter = function()
            materialEditor:Render()
            materialEditor:UpdateUIState()
            self:RenderTransformSliders(materialNode, descIndex, nil, meshName)
            materialNode.OnHoverEnter = nil
        end

        self.Materials[keyName] = materialEditor

        ::continue::
    end
end

function VisualTab:RenderEffectSection()
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

    self.effectHeader.OnHoverEnter = function ()
        self:RenderEffectEditor()
        self.effectHeader.OnHoverEnter = nil
    end
end


function VisualTab:RenderEffectEditor()
    local entity = Ext.Entity.Get(self.guid) --[[@as EntityHandle]]
    --self.effectRoot = self.effectHeader:AddTree(GetLoca("Effects"))
    if not entity.Effect or not entity.Effect.Timeline or not entity.Effect.Timeline.Components then
        return
    end

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

---@param node ExtuiTree
---@param component AspkComponent
---@param compIndex any
function VisualTab:RenderLightEntity(node, component, compIndex)
    local entityNode = node

    local lightEntity = component.LightEntity
    if not lightEntity or not lightEntity.Light then
        return
    end

    local light = lightEntity.Light --[[@as LightComponent]]

    local entityColorNode = entityNode:AddTree(GetLoca("Light Entity Color"))
    local generalNode = entityNode:AddTree(GetLoca("General Light Settings"))
    local spotNode = entityNode:AddTree(GetLoca("Spot Light Settings"))
    local directionalNode = entityNode:AddTree(GetLoca("Directional Light Settings"))
    local otherNode = entityNode:AddTree(GetLoca("Other Settings"))

    local allNodes = {
        entityColorNode,
        directionalNode,
        directionalNode,
        otherNode,
    }

    node.OnRightClick = function()
        for _, n in ipairs(allNodes) do
            n:SetOpen(true)
        end
    end

    local bitMaskPropNameMap = {
        LightChannelFlag = { displayName = "Light Channel", bits = { ["Character"] = 1 << 5, ["Scenery"] = 1 }, preassign = generalNode },
        Flags = { displayName = "Light Flags", bits = { ["Cast Shadow"] = 1 << 3,  }, preassign = generalNode },
    }

    local scalarPropNameMap = {
        SpotLightInnerAngle = { min = 0, max = 180, step = 1, displayName = "Inner Angle", preassign = spotNode },
        SpotLightOuterAngle = { min = 0, max = 180, step = 1, displayName = "Outer Angle", preassign = spotNode },
        Gain = { min = 0, max = 100, step = 0.1, displayName = "Gain", preassign = generalNode },
        EdgeSharpening = { min = 0, max = 10, step = 0.05, displayName = "Edge Sharpness", preassign = generalNode },
        LightType = { min = 0, max = 2, step = 1, displayName = "Light Type", preassign = entityNode, IsInteger = true, Tooltip = "0=Point,1=Spot,2=Directional" },
        ScatteringIntensityScale = { min = 0, max = 100, step = 0.1, displayName = "Scattering Intensity Scale", preassign = generalNode },
        DirectionLightAttenuationFunction = { min = 0, max = 4, step = 1, displayName = "Attenuation Function", preassign = directionalNode, IsInteger = true, Tooltip = "0=Liner,1=Inverse Square,2=Smooth Step,3=Smoother Step,4=None" },
        DirectionLightAttenuationEnd = { min = 0, max = 2, step = 0.05, displayName = "Attenuation End", preassign = directionalNode },
        DirectionLightAttenuationSide = { min = 0, max = 2, step = 0.05, displayName = "Attenuation Back", preassign = directionalNode },
        DirectionLightAttenuationSide2 = { min = 0, max = 2, step = 0.05, displayName = "Attenuation Sides", preassign = directionalNode },
        CullFlags = { min = 0, max = 1 << 24, step = 1, displayName = "Cull Flags", preassign = otherNode, IsInteger = true },
        Flags = { min = 0, max = 1 << 24, step = 1, displayName = "Light Flags", preassign = otherNode, IsInteger = true },
    }

    local vec3PropNameMap = {
        --Blackbody = { displayName = "Blackbody", preassign = otherNode },
        DirectionLightDimensions = { displayName = "Direction Light Dimensions", preassign = directionalNode, Range = {0,100} },
        Color = { displayName = "Light Entity Color", preassign = entityColorNode },
    }

    local renderOrder = {
        "LightType",
        "LightChannelFlag",
        "Flags",
        "SpotLightInnerAngle",
        "SpotLightOuterAngle",
        "Gain",
        "EdgeSharpening",
        "ScatteringIntensityScale",
        "DirectionLightAttenuationFunction",
        "DirectionLightAttenuationEnd",
        "DirectionLightAttenuationSide",
        "DirectionLightAttenuationSide2",
        "CullFlags",
        "DirectionLightDimensions",
        "Color",
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
        if not entity or not entity.Effect or not entity.Effect.Timeline or not entity.Effect.Timeline.Components[compIndex] or not entity.Effect.Timeline.Components[compIndex].LightEntity then
            return nil
        end
        return entity.Effect.Timeline.Components[compIndex].LightEntity.Light
    end

    for _, propName in ipairs(renderOrder) do
        local key = "LightEntity::" .. compIndex .. "::" .. propName
        local property = self.resetParams[key] or light[propName]
        self.resetParams[key] = property
        if bitMaskPropNameMap[propName] and type(property) == "number" then
            local valueNode = bitMaskPropNameMap[propName].preassign or entityNode:AddTree(bitMaskPropNameMap[propName].displayName or propName)
            --- @type RadioButtonOption[]
            local options = {}
            for name, bit in pairs(bitMaskPropNameMap[propName].bits) do
                table.insert(options, {
                    Hint = name,
                    Bit = bit,
                })
            end
            table.sort(options, function(a, b) return a.Bit < b.Bit end)
            local displayNameText = valueNode:AddText(bitMaskPropNameMap[propName].displayName or propName)
            if bitMaskPropNameMap[propName].Tooltip then
                displayNameText:Tooltip():AddText(bitMaskPropNameMap[propName].Tooltip)
            end
            local raidoGroup = StyleHelpers.AddBitmaskRadioButtons(valueNode, options, property or 0)
            raidoGroup.OnChange = function(sel, value)
                local liveLight = GetLiveLightEntity()
                if not liveLight then return end
                liveLight[propName] = value
                saveLightEntityProperty(key, propName, value)
            end
        end
        if scalarPropNameMap[propName] and type(property) == "number" then
            local valueNode = scalarPropNameMap[propName].preassign or entityNode:AddTree(scalarPropNameMap[propName].displayName or propName)
            local initValue = property
            local currentValue = property
            local slider = AddSliderWithStep(valueNode, nil, currentValue, scalarPropNameMap[propName].min,
                scalarPropNameMap[propName].max, scalarPropNameMap[propName].step, scalarPropNameMap[propName].IsInteger)
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
            valueResetButton.SameLine = true
            valueResetButton.IDContext = key .. "Reset"

            local displayNameText = valueNode:AddText(scalarPropNameMap[propName].displayName or propName)
            if scalarPropNameMap[propName].Tooltip then
                displayNameText:Tooltip():AddText(scalarPropNameMap[propName].Tooltip)
            end
            displayNameText.SameLine = true

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
                slider.Value = { initValue, initValue, initValue, initValue }
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
            local valueNode = vec3PropNameMap[propName].preassign or
                entityNode:AddTree(vec3PropNameMap[propName].displayName or propName)
            if valueNode == otherNode then
                valueNode = valueNode:AddTree(vec3PropNameMap[propName].displayName or propName)
            end
            local initValue = { property[1], property[2], property[3] }
            local currentValue = property
            local displayNameText = valueNode:AddText(vec3PropNameMap[propName].displayName or propName)
            if vec3PropNameMap[propName].Tooltip then
                displayNameText:Tooltip():AddText(vec3PropNameMap[propName].Tooltip)
            end
            local colorEdit = valueNode:AddColorEdit("Color", { currentValue[1], currentValue[2], currentValue[3] })
            colorEdit.NoAlpha = true
            local valueResetButton = valueNode:AddButton(GetLoca("Reset"))
            valueResetButton.SameLine = true
            local range = vec3PropNameMap[propName].Range or { -100, 100 }
            local sliderX = AddSliderWithStep(valueNode, "X", currentValue[1], range[1], range[2], 0.1)
            valueNode:AddText("X").SameLine = true
            local sliderY = AddSliderWithStep(valueNode, "Y", currentValue[2], range[1], range[2], 0.1)
            valueNode:AddText("Y").SameLine = true
            local sliderZ = AddSliderWithStep(valueNode, "Z", currentValue[3], range[1], range[2], 0.1)
            valueNode:AddText("Z").SameLine = true


            local function sliderOnChange()
                local liveLight = GetLiveLightEntity()
                if not liveLight then return end
                liveLight[propName] = { sliderX.Value[1], sliderY.Value[1], sliderZ.Value[1] }
                saveLightEntityProperty(key, propName, { sliderX.Value[1], sliderY.Value[1], sliderZ.Value[1] })
                if colorEdit then
                    colorEdit.Color = { sliderX.Value[1], sliderY.Value[1], sliderZ.Value[1], colorEdit.Color[4] or 1.0 }
                end
            end

            local function colorEditOnChange()
                local liveLight = GetLiveLightEntity()
                if not liveLight then return end
                local col = colorEdit.Color
                liveLight[propName] = { col[1], col[2], col[3] }
                saveLightEntityProperty(key, propName, { col[1], col[2], col[3] })
                if sliderX and sliderY and sliderZ then
                    sliderX.Value = { col[1], col[1], col[1], col[1] }
                    sliderY.Value = { col[2], col[2], col[2], col[2] }
                    sliderZ.Value = { col[3], col[3], col[3], col[3] }
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
                    initValue = { liveLight[propName][1], liveLight[propName][2], liveLight[propName][3] }
                    return
                end

                liveLight[propName] = { initValue[1], initValue[2], initValue[3] }
                sliderX.Value = ToVec4(initValue[1])
                sliderY.Value = ToVec4(initValue[2])
                sliderZ.Value = ToVec4(initValue[3])
                colorEdit.Color = { initValue[1], initValue[2], initValue[3], colorEdit.Color[4] or 1.0 }
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
                    colorEdit.Color = { liveLight[propName][1], liveLight[propName][2], liveLight[propName][3], colorEdit
                    .Color[4] or 1.0 }
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
        local key = "LightComponent::" .. compIndex .. "::" .. propName
        if propName == "Appearance.Color" then
            if not property.Frames[1].Color then
                goto continue
            end
            self:CheckKey(key)
            local overrideKey = "Light::" .. compIndex .. "::OverrideLightTemplateColor"
            self:CheckKey(overrideKey)
            local colorNode = compNode:AddTree("Color")
            local initColor = self.resetParams[key] or property.Frames[1].Color
            self.resetParams[key] = { initColor[1], initColor[2], initColor[3], initColor[4] }
            local initBool = self.resetParams[overrideKey] or lComp.OverrideLightTemplateColor
            self.resetParams[overrideKey] = initBool
            local currentColor = property.Frames[1].Color
            local colorResetButton = colorNode:AddButton(GetLoca("Reset"))
            local overrideEntityCheck = colorNode:AddCheckbox(GetLoca("Override Entity Color"),
                lComp.OverrideLightTemplateColor)
            overrideEntityCheck.OnChange = function(checkbox)
                local entity = Ext.Entity.Get(self.guid)
                if not entity or not entity.Effect then return end
                entity.Effect.Timeline.Components[compIndex].OverrideLightTemplateColor = checkbox.Checked
                saveLightProperty(overrideKey, "OverrideLightTemplateColor", checkbox.Checked)
            end
            overrideEntityCheck.SameLine = true

            self.updateFuncs[overrideKey] = function()
                local entity = Ext.Entity.Get(self.guid)
                if not entity or not entity.Effect then return end
                if overrideEntityCheck then
                    overrideEntityCheck.Checked = entity.Effect.Timeline.Components[compIndex]
                        .OverrideLightTemplateColor
                end
            end

            local colorPicker = colorNode:AddColorEdit("")
            --colorPicker.SameLine = true
            colorPicker.Color = currentColor
            colorPicker.OnChange = function(picker)
                local entity = Ext.Entity.Get(self.guid)
                if not entity or not entity.Effect then return end
                local frames = entity.Effect.Timeline.Components[compIndex].Properties[propName].Frames
                local colorValue = { picker.Color[1], picker.Color[2], picker.Color[3], picker.Color[4] }
                VisualHelpers.ChangeFrames(frames, colorValue, true)
                saveLightProperty(key, propName, colorValue)
            end

            colorResetButton.OnClick = function(sel, updateInit)
                local entity = Ext.Entity.Get(self.guid)
                if not entity or not entity.Effect then return end
                local component = entity.Effect.Timeline.Components[compIndex]
                local frames = component.Properties[propName].Frames

                if updateInit then
                    initColor = { frames[1].Color[1], frames[1].Color[2], frames[1].Color[3], frames[1].Color[4] }
                    initBool = component.OverrideLightTemplateColor
                    return
                end

                component.OverrideLightTemplateColor = initBool
                VisualHelpers.ChangeFrames(frames, initColor, true)
                colorPicker.Color = { initColor[1], initColor[2], initColor[3], initColor[4] }
                overrideEntityCheck.Checked = initBool
                self.modifiedParams[key] = nil
                self.modifiedParams[overrideKey] = nil
            end

            self.resetFuncs[key] = colorResetButton.OnClick

            self.updateFuncs[key] = function()
                local entity = Ext.Entity.Get(self.guid)
                if not entity or not entity.Effect then return end
                local frames = entity.Effect.Timeline.Components[compIndex].Properties[propName].Frames
                if frames and frames[1] and frames[1].Color and colorPicker then
                    local colorValue = frames[1].Color
                    colorPicker.Color = { colorValue[1], colorValue[2], colorValue[3], colorValue[4] }
                end
            end
        end

        if propNameMap[propName] then
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
                local initValue = { property.KeyFrames[1].Frames[1].A, property.KeyFrames[1].Frames[1].B, property
                    .KeyFrames[1].Frames[1].C, property.KeyFrames[1].Frames[1].D }
                local currentValue = property.KeyFrames[1].Frames[1]

                local sliderA = AddSliderWithStep(valueNode, "A", currentValue.A, -100, 100, 0.1)
                valueNode:AddText("?Amplitude").SameLine = true
                local sliderB = AddSliderWithStep(valueNode, "B", currentValue.B, -100, 100, 0.1)
                valueNode:AddText("?Frequency").SameLine = true
                local sliderC = AddSliderWithStep(valueNode, "C", currentValue.C, -100, 100, 0.1)
                valueNode:AddText("?Phase").SameLine = true
                local sliderD = AddSliderWithStep(valueNode, "D", currentValue.D, -100, 100, 0.1)
                valueNode:AddText("Base").SameLine = true

                sliderA.OnChange = function(slider)
                    local entity = Ext.Entity.Get(self.guid)
                    if not entity or not entity.Effect then return end
                    local keyFrames = entity.Effect.Timeline.Components[compIndex].Properties[propName].KeyFrames
                    for keyFrameIndex, keyFrame in ipairs(keyFrames) do
                        VisualHelpers.ChangeABCDFrames(keyFrame.Frames, sliderA.Value[1], sliderB.Value[1],
                            sliderC.Value[1], sliderD.Value[1])
                    end
                    saveLightProperty(key, propName,
                        { sliderA.Value[1], sliderB.Value[1], sliderC.Value[1], sliderD.Value[1] })
                end
                sliderB.OnChange = sliderA.OnChange
                sliderC.OnChange = sliderA.OnChange
                sliderD.OnChange = sliderA.OnChange

                valueResetButton.OnClick = function(sel, updateInit)
                    local entity = Ext.Entity.Get(self.guid)
                    if not entity or not entity.Effect then return end
                    local keyFrames = entity.Effect.Timeline.Components[compIndex].Properties[propName].KeyFrames
                    if updateInit then
                        initValue = { keyFrames[1].Frames[1].A, keyFrames[1].Frames[1].B, keyFrames[1].Frames[1].C,
                            keyFrames[1].Frames[1].D }
                        return
                    end

                    for keyFrameIndex, keyFrame in ipairs(keyFrames) do
                        VisualHelpers.ChangeABCDFrames(keyFrame.Frames, initValue[1], initValue[2], initValue[3],
                            initValue[4])
                    end
                    sliderA.Value = { initValue[1], initValue[1], initValue[1], initValue[1] }
                    sliderB.Value = { initValue[2], initValue[2], initValue[2], initValue[2] }
                    sliderC.Value = { initValue[3], initValue[3], initValue[3], initValue[3] }
                    sliderD.Value = { initValue[4], initValue[4], initValue[4], initValue[4] }
                    self.modifiedParams[key] = nil
                end

                setTo0Button.OnClick = function()
                    local entity = Ext.Entity.Get(self.guid)
                    if not entity or not entity.Effect then return end
                    local keyFrames = entity.Effect.Timeline.Components[compIndex].Properties[propName].KeyFrames
                    for keyFrameIndex, keyFrame in ipairs(keyFrames) do
                        VisualHelpers.ChangeABCDFrames(keyFrame.Frames, 0, 0, 0, 0)
                    end
                    sliderA.Value = { 0, 0, 0, 0 }
                    sliderB.Value = { 0, 0, 0, 0 }
                    sliderC.Value = { 0, 0, 0, 0 }
                    sliderD.Value = { 0, 0, 0, 0 }
                    self.modifiedParams[key] = { 0, 0, 0, 0 }
                end

                self.resetFuncs[key] = valueResetButton.OnClick

                self.updateFuncs[key] = function()
                    local entity = Ext.Entity.Get(self.guid)
                    if not entity or not entity.Effect then return end
                    local keyFrames = entity.Effect.Timeline.Components[compIndex].Properties[propName].KeyFrames
                    if keyFrames and keyFrames[1] and keyFrames[1].Frames and keyFrames[1].Frames[1] and sliderA then
                        local frame = keyFrames[1].Frames[1]
                        sliderA.Value = { frame.A, frame.A, frame.A, frame.A }
                        sliderB.Value = { frame.B, frame.B, frame.B, frame.B }
                        sliderC.Value = { frame.C, frame.C, frame.C, frame.C }
                        sliderD.Value = { frame.D, frame.D, frame.D, frame.D }
                    end
                end

                goto continue
            end

            local valueNode = compNode:AddTree(propNameMap[propName] or propName)
            local valueResetButton = valueNode:AddButton(GetLoca("Reset"))
            local resetBoolFunc = nil

            if overrideMap[propName] then
                local overrideKey = "LightComponent::" .. compIndex .. "::" .. overrideMap[propName]
                local boolName = overrideMap[propName]
                self:CheckKey(overrideKey)
                local initBool = lComp[boolName]
                local overrideCheck = valueNode:AddCheckbox(GetLoca(boolName), lComp[boolName] or false)
                overrideCheck.OnChange = function(checkbox)
                    local entity = Ext.Entity.Get(self.guid)
                    if not entity or not entity.Effect then return end
                    entity.Effect.Timeline.Components[compIndex][boolName] = checkbox.Checked
                    saveLightProperty(overrideKey, boolName, checkbox.Checked)
                end

                self.updateFuncs[overrideKey] = function()
                    local entity = Ext.Entity.Get(self.guid)
                    if not entity or not entity.Effect then return end
                    if overrideCheck then
                        overrideCheck.Checked = entity.Effect.Timeline.Components[compIndex][boolName]
                    end
                end

                resetBoolFunc = function()
                    local entity = Ext.Entity.Get(self.guid)
                    if not entity or not entity.Effect then return end
                    local component = entity.Effect.Timeline.Components[compIndex]
                    component[boolName] = initBool
                    overrideCheck.Checked = initBool
                    self.modifiedParams[overrideKey] = nil
                end

                overrideCheck.SameLine = true
            end

            local initValue = self.resetParams[key] or property.KeyFrames[1].Frames[1].Value
            self.resetParams[key] = initValue
            local currentValue = property.KeyFrames[1].Frames[1].Value
            local valueSlider = AddSliderWithStep(valueNode, key, currentValue, -100, 100, 0.1)
            valueSlider.UserData.ResetButton.Visible = false
            if not overrideMap[propName] then
                valueSlider.UserData.StepInput.SameLine = true
            end
            valueSlider.OnChange = function(slider)
                local entity = Ext.Entity.Get(self.guid)
                if not entity or not entity.Effect then return end
                local keyFrames = entity.Effect.Timeline.Components[compIndex].Properties[propName].KeyFrames
                for keyFrameIndex, keyFrame in ipairs(keyFrames) do
                    VisualHelpers.ChangeFrames(keyFrame.Frames, slider.Value[1])
                end
                saveLightProperty(key, propName, slider.Value[1])
            end

            valueResetButton.OnClick = function(sel, updateInit)
                local entity = Ext.Entity.Get(self.guid)
                if not entity or not entity.Effect then return end
                local keyFrames = entity.Effect.Timeline.Components[compIndex].Properties[propName].KeyFrames

                if updateInit then
                    initValue = keyFrames[1].Frames[1].Value
                    return
                end

                for keyFrameIndex, keyFrame in ipairs(keyFrames) do
                    VisualHelpers.ChangeFrames(keyFrame.Frames, initValue)
                end
                valueSlider.Value = { initValue, initValue, initValue, initValue }
                if resetBoolFunc then
                    resetBoolFunc()
                end
                self.modifiedParams[key] = nil
            end

            self.resetFuncs[key] = valueResetButton.OnClick

            self.updateFuncs[key] = function()
                local entity = Ext.Entity.Get(self.guid)
                if not entity or not entity.Effect then return end
                local keyFrames = entity.Effect.Timeline.Components[compIndex].Properties[propName].KeyFrames
                if keyFrames and keyFrames[1] and keyFrames[1].Frames and keyFrames[1].Frames[1] and valueSlider then
                    local frame = keyFrames[1].Frames[1]
                    valueSlider.Value = { frame.Value, frame.Value, frame.Value, frame.Value }
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
        Brightness_ = { min = 0, max = 10, step = 0.1, displayName = "Brightness" },
        UniformScale = { min = 0, max = 10, step = 0.1, displayName = "Uniform Scale" },
    }

    local vec4PropNameMap = {
        Color = "Color",
    }

    for propName, property in pairs(psComp) do
        local key = "ParticleSystem::" .. compIndex .. "::" .. propName
        if scalarPropNameMap[propName] and type(property) == "number" then
            local valueNode = compNode:AddTree(scalarPropNameMap[propName].displayName or propName)
            local valueResetButton = valueNode:AddButton(GetLoca("Reset"))
            local initValue = self.resetParams[key] or property
            self.resetParams[key] = initValue
            local currentValue = property
            local slider = AddSliderWithStep(valueNode, nil, currentValue, scalarPropNameMap[propName].min,
                scalarPropNameMap[propName].max, scalarPropNameMap[propName].step)
            slider.UserData.ResetButton.Visible = false
            slider.OnChange = function(slider)
                local entity = Ext.Entity.Get(self.guid)
                if not entity or not entity.Effect then return end
                local liveComponent = entity.Effect.Timeline.Components[compIndex]
                liveComponent[propName] = slider.Value[1]
                saveParticleProperty(key, propName, slider.Value[1])
            end

            valueResetButton.OnClick = function(sel, updateInit)
                local entity = Ext.Entity.Get(self.guid)
                if not entity or not entity.Effect then return end
                local liveComponent = entity.Effect.Timeline.Components[compIndex]

                if updateInit then
                    initValue = liveComponent[propName]
                    return
                end

                liveComponent[propName] = initValue
                slider.Value = { initValue, initValue, initValue, initValue }
                self.modifiedParams[key] = nil
            end

            self.resetFuncs[key] = valueResetButton.OnClick
            self.updateFuncs[key] = function()
                local entity = Ext.Entity.Get(self.guid)
                if not entity or not entity.Effect then return end
                local liveComponent = entity.Effect.Timeline.Components[compIndex]
                if liveComponent[propName] and slider then
                    slider.Value = { liveComponent[propName], liveComponent[propName], liveComponent[propName],
                        liveComponent[propName] }
                end
            end

            goto continue
        end

        if vec4PropNameMap[propName] and type(property) == "table" and #property == 4 then
            local valueNode = compNode:AddTree(vec4PropNameMap[propName] or propName)
            local valueResetButton = valueNode:AddButton(GetLoca("Reset"))
            local initValue = self.resetParams[key] or { property[1], property[2], property[3], property[4] }
            self.resetParams[key] = initValue
            local currentValue = property
            local colorEdit = valueNode:AddColorEdit("")
            colorEdit.SameLine = true
            colorEdit.Color = currentValue
            colorEdit.OnChange = function(picker)
                local entity = Ext.Entity.Get(self.guid)
                if not entity or not entity.Effect then return end
                local liveComponent = entity.Effect.Timeline.Components[compIndex]
                local colorValue = { picker.Color[1], picker.Color[2], picker.Color[3], picker.Color[4] }
                liveComponent[propName] = colorValue
                saveParticleProperty(key, propName, colorValue)
            end

            valueResetButton.OnClick = function(sel, updateInit)
                local entity = Ext.Entity.Get(self.guid)
                if not entity or not entity.Effect then return end
                local liveComponent = entity.Effect.Timeline.Components[compIndex]

                if updateInit then
                    initValue = { liveComponent[propName][1], liveComponent[propName][2], liveComponent[propName][3],
                        liveComponent[propName][4] }
                    return
                end

                liveComponent[propName] = { initValue[1], initValue[2], initValue[3], initValue[4] }
                colorEdit.Color = { initValue[1], initValue[2], initValue[3], initValue[4] }
                self.modifiedParams[key] = nil
            end

            self.resetFuncs[key] = valueResetButton.OnClick
            self.updateFuncs[key] = function()
                local entity = Ext.Entity.Get(self.guid)
                if not entity or not entity.Effect then return end
                local liveComponent = entity.Effect.Timeline.Components[compIndex]
                if liveComponent[propName] and colorEdit then
                    local col = liveComponent[propName]
                    colorEdit.Color = { col[1], col[2], col[3], col[4] }
                end
            end

            goto continue
        end

        ::continue::
    end
end

function VisualTab:RenderTransformSliders(parent, descIndex, attachIndex, modelName)
    local selectInTransformEditor = parent:AddButton(GetLoca("Select in Transform Editor"))
    selectInTransformEditor.IDContext = tostring(parent) ..
        "::" .. modelName .. "::" .. descIndex .. "::" .. (attachIndex or 0) .. "::SelectInTransformEditor"

    selectInTransformEditor.OnClick = function()
        if not self:CheckVisual() then return end
        local renderableFunc = function()
            return VisualHelpers.GetRenderable(self.guid, descIndex, attachIndex)
        end
        local startScale = VisualHelpers.GetRenderableScale(self.guid, descIndex, attachIndex)
        local proxy = RenderableMovableProxy.new(renderableFunc)
        RB_GLOBALS.TransformEditor:Select({ proxy })
        self.StartScale = self.StartScale or {}
        table.insert(self.StartScale, { AttachIndex = attachIndex, DescIndex = descIndex, Scale = startScale })
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

    if self.savedPresets and self.savedPresets[name] and not overwrite then
        ConfirmPopup:QuickConfirm(
            string.format(GetLoca("A preset named '%s' already exists. Overwrite?"), name),
            function()
                self:Save(name, true)
            end,
            nil,
            10
        )
        return true
    end

    local saveName = name or self.displayName or "Unnamed"

    local filePath = GetVisualPresetsPath(templateName)
    local oriFile = Ext.Json.Parse(Ext.IO.LoadFile(filePath) or "{}")

    local Mats = {}
    for key, mat in pairs(self.Materials) do
        local params = mat:ExportChanges()
        local hasChanges = false
        for typeRef, changed in pairs(params) do
            if next(changed) then
                hasChanges = true
                break
            end
        end

        if hasChanges then
            Mats[key] = params
        end
    end

    for _, startScaleData in ipairs(self.StartScale or {}) do
        local currentScale = VisualHelpers.GetAttachmentScale(self.guid, startScaleData.DescIndex,
            startScaleData.AttachIndex)
        if EqualArrays(currentScale, startScaleData.Scale) then
            goto continue
        end
        local attachKey = "Transform::" ..
            startScaleData.DescIndex .. "::" .. (startScaleData.AttachIndex or 0) .. "::Scale"
        self.modifiedParams[attachKey] = {
            Type = "Scale",
            DescIndex = startScaleData.DescIndex,
            AttachIndex = startScaleData.AttachIndex,
            Value = currentScale
        }
        ::continue::
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
    self.savedPresets[saveName] = DeepCopy(oriFile[saveName])
    if IsPartyMember(self.guid) then

    else
        EntityStore[self.guid].VisualPreset = saveName
    end
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
        --ErrorNotify("Error", "VisualTab:Load - Could not load preset file: " .. filePath)
        return false
    end

    local data = Ext.Json.Parse(fileContent)
    if not data or type(data) ~= "table" or not next(data) then
        ErrorNotify("Error", "VisualTab:Load - No valid preset data found in file: " .. filePath)
        return false
    end

    for name, presetData in pairs(data) do
        if self.savedPresets and self.savedPresets[name] and not notoverwrite then
            --Warning("Preset already loaded, skipping: " .. name)
        else
            self.savedPresets[name] = presetData
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

    if self.savedPresets then
        self.savedPresets[name] = nil
    end

    if #self.savedPresets == 0 then
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
    if not self.savedPresets then
        Error("No saved preset found with name: " .. name)
        return false
    end

    local preset = self.savedPresets[name]

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
    self.modifiedParams = presetParams or {}

    for key, matParams in pairs(preset.Materials or {}) do
        if self.Materials[key] then
            self.Materials[key].Editor:ApplyParameters(matParams)
            self.Materials[key]:UpdateUIState()
        end
    end

    if self.loadCombo then
        SetCombo(self.loadCombo, name)
    end

    if IsPartyMember(self.guid) then

    else
        EntityStore[self.guid].VisualPreset = name
    end

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
    if not self.savedPresets then
        return {}
    end

    local names = {}
    for name, entry in pairs(self.savedPresets) do
        table.insert(names, name)
    end
    table.sort(names)
    Debug("VisualTab:_getAllPresetNames - Found presets: " .. table.concat(names, ", "))
    return names
end

function VisualTab:Collapsed()
    if not self.isValid or not self.isVisible then
        return
    end

    self.resetFuncs = {}
    self.updateFuncs = {}

    for key, matTab in pairs(self.Materials) do
        matTab:ClearRefs()
    end

    if self.saveInputKeySub then
        self.saveInputKeySub:Unsubscribe()
        self.saveInputKeySub = nil
    end

    if self.materialHeader then
        self.materialHeader:Destroy()
        self.materialHeader = nil
    end

    if self.attachmentsHeader then
        self.attachmentsHeader:Destroy()
        self.attachmentsHeader = nil
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
    if self.isWindow and self.panel then
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

    if self.panel then
        self:Collapsed()
    end

    self.isValid = false

    if visualTabCache[self.guid] == self then
        visualTabCache[self.guid] = nil
    end
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

--- merge all modified material params from all materials in this tab
--- @return RB_ParameterSet?
function VisualTab:ExportModifiedMaterialParams()
    local exportedParams = {} --[[@as RB_ParameterSet ]]
    local hasChanges = false
    for key, mat in pairs(self.Materials) do
        local params = mat:ExportChanges()

        for typeRef, paramSet in pairs(params) do
            if not exportedParams[typeRef] then
                exportedParams[typeRef] = {}
            end
            for paramName, value in pairs(paramSet) do
                if not exportedParams[typeRef][paramName] then
                    exportedParams[typeRef][paramName] = value
                    hasChanges = true
                end
            end
        end
    end

    if not hasChanges then
        return nil
    end

    return exportedParams
end

--- @alias RB_ObjectEdit table<string, RB_ParameterSet> materialName -> parameter set

--- @return RB_ObjectEdit?
function VisualTab:ExportObjectEdit()
    local objEdit = {}

    for key, mat in FilteredPairs(self.Materials, function(k, v)
        return v.IsObject and v:HasChanges() and not objEdit[v.MaterialName]
    end) do
        objEdit[mat.MaterialName] = mat:ExportChanges()
    end

    if not next(objEdit) then
        return nil
    end

    return objEdit
end

function VisualTab:OnDetach() end

function VisualTab:OnAttach() end

function VisualTab:OnChange() end
