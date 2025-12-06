local VISUALTAB_WIDTH = 800 * SCALE_FACTOR
local VISUALTAB_HEIGHT = 1000 * SCALE_FACTOR

local visualTabCache = {}

local ClientVisualPresetData = {}
local ClientOriginalVisualData = {}

local function LoadVisualPresetData()
    local refFile = GetVisualReferencePath()
    local refData = Ext.Json.Parse(Ext.IO.LoadFile(refFile) or "{}")
    for templateName, data in pairs(refData) do
        local visualPresetFile = GetVisualPresetsPath(templateName)
        local visualPresetData = Ext.Json.Parse(Ext.IO.LoadFile(visualPresetFile) or "{}")
        if visualPresetData then
            ClientVisualPresetData[templateName] = visualPresetData
        else
            Warning("VisualPresetDataLoadFromFile: Failed to load preset data for template: " .. templateName)
        end
    end
end

local function UpdateVisualPresetDataFromServer(data)
    for templateName, presets in pairs(data) do
        if not ClientVisualPresetData[templateName] then
            ClientVisualPresetData[templateName] = {}
        end
        for presetName, presetData in pairs(presets) do
            if not ClientVisualPresetData[templateName][presetName] then
                ClientVisualPresetData[templateName][presetName] = presetData
            end
        end
    end
end

local function ClearOriginalVisualData(templateName)
    if templateName then
        ClientOriginalVisualData[templateName] = nil
    else
        ClientOriginalVisualData = {}
    end
    --Info("Cleared original visual data for template: " .. tostring(templateName or "all"))
end

function GetVisualPresetData(templateName, presetName)
    if not templateName or not presetName then
        Warning("GetVisualPresetData: Invalid templateName or presetName")
        return nil
    end

    local templateData = ClientVisualPresetData[templateName]
    if not templateData then
        Warning("GetVisualPresetData: No data found for template: " .. templateName)
        return nil
    end

    return templateData[presetName]
end

RegisterOnSessionLoaded(function()
    --local now = Ext.Utils.MonotonicTime()
    LoadVisualPresetData()
    ClearOriginalVisualData()
    --Debug("Visual preset data loaded in " .. (Ext.Utils.MonotonicTime() - now) .. "ms")
end)


--- @class VisualTab
--- @field Materials table<string, MaterialTab>
--- @field Effects table<string, table<string, any>> -- EffectType::index -> EffectProperty -> value
--- @field guid GUIDSTRING
--- @field templateName string
--- @field updateFuncs table<string, table<string, fun()>> -- EffectType::index -> EffectProperty -> update function
--- @field resetFuncs table<string, table<string, fun()>> -- EffectType::index -> EffectProperty -> reset function
--- @field resetParams table<string, table<string, any>> -- EffectType::index -> EffectProperty -> reset value
--- @field new fun(guid: GUIDSTRING?, displayName: string?, parent: ExtuiTreeParent?, templateName: string?): VisualTab
--- @field FetchByGuid fun(guid: GUIDSTRING): VisualTab|nil
VisualTab = {}
VisualTab.__index = VisualTab

function VisualTab.FetchByGuid(guid)
    return visualTabCache[guid]
end

function VisualTab.new(guid, displayName, parent, templateName, entity)
    local obj = setmetatable({}, VisualTab)

    for key, value in pairs(visualTabCache) do
        if type(key) == "userdata" and #key:GetAllComponentNames() == 0 then
            visualTabCache[key] = nil
        end
        if type(key) == "string" and not VisualHelpers.GetEntityVisual(key) then
            visualTabCache[key] = nil
        end
    end

    if guid and visualTabCache[guid] then
        visualTabCache[guid]:Refresh()
        return visualTabCache[guid]
    end

    obj:__init(guid, displayName, parent, templateName)

    if guid then
        visualTabCache[guid] = obj
    elseif entity then
        visualTabCache[entity] = obj
    end

    return obj
end

function VisualTab:GetEntity()
    return Ext.Entity.Get(self.guid)
end

function VisualTab:GetVisual()
    return VisualHelpers.GetEntityVisual(self.guid)
end

function VisualTab.CreateByEntity(entity, uuid, displayName)

    --- @diagnostic disable-next-line
    local obj = VisualTab.new(uuid, displayName, nil, nil, entity)

    function obj:GetEntity()
        return entity
    end
    function obj:GetVisual()
        return entity.Visual.Visual
    end

    return obj
end

function VisualTab:__init(guid, displayName, parent, templateName)
    self.guid = guid or ""
    self.templateName = templateName or "Unknown"

    self.parent = parent or nil
    self.isAttach = true
    self.panel = nil
    self.isWindow = false
    self.isValid = true
    self.isVisible = false
    self.displayName = displayName or "Unknown"

    self.Materials = {}
    self.Effects = {}

    self.resetParams = {}

    self.currentPreset = EntityStore[guid] and EntityStore[guid].VisualPreset or nil

    self.updateFuncs = {}
    self.resetFuncs = {}

    if not templateName and self.guid ~= "" and not EntityStore[self.guid] then
        NetChannel.GetTemplate:RequestToServer({ Guid = self.guid }, function(response)
            if response.GuidToTemplateId and response.GuidToTemplateId[self.guid] then
                self.templateId = response.GuidToTemplateId[self.guid]
                local getTemplateName = TrimTail(response.GuidToTemplateId[self.guid], 37)
                self.templateName = getTemplateName
                self:SetupTemplate()
                self:Refresh()
                Debug("VisualTab: Received template name from server: " .. self.templateName)
            else
                --Error("VisualTab: Could not get template name from server for entity " .. self.guid)
            end
        end)
    elseif templateName or (self.guid ~= "" and EntityStore[self.guid]) then
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
    if self.isVisible then
        return
    end

    self.displayName = self.displayName or GetDisplayNameFromGuid(self.guid)

    if self.parent and self.isAttach then
        self:OnAttach()
        self.panel = self.parent:AddTabItem(GetLoca("Visual"))
        self.isWindow = false
    else
        self.panel = RegisterWindow(self.guid, self.displayName .. " - Visual Editor", "VisualTab", self, self.lastPosition,
            self.lastSize or { VISUALTAB_WIDTH, VISUALTAB_HEIGHT })
        self.isWindow = true
        self:OnDetach()
    end

    self.isVisible = true

    local entity = self:GetEntity(self.guid)

    if entity == nil or not entity.Visual or not entity.Visual.Visual or (not entity.Visual.Visual.ObjectDescs and not entity.Effect) then
        local tryToRerender = function()
            self:Refresh()
        end
        if not retryCnt or retryCnt < 1 then
            Timer:Ticks(30, function()
                self:Refresh((retryCnt or 0) + 1)
            end)
        else
            local rerenderButton = self.panel:AddButton(GetLoca("Try to reload Visual Tab"))
            rerenderButton:Tooltip():AddText(GetLoca("Entity is too far away, in inventory, or has no visual."))
            rerenderButton.OnClick = tryToRerender
        end
        return
    end

    local topTable = self.panel:AddTable("VisualTop", 2)

    topTable.ColumnDefs[1] = { WidthStretch = true }
    topTable.ColumnDefs[2] = { WidthStretch = false, WidthFixed = true }

    local topRow = topTable:AddRow("VisualTopRow")

    local leftCell = topRow:AddCell()
    local rightCell = topRow:AddCell()

    self:RenderPresetsCell(leftCell)

    self:RenderUtilsCell(rightCell)

    self:RenderMaterialContextPopup()

    self.editorWindow = self.panel:AddChildWindow("EditorWindow")

    self:RenderAttachmentSection()
    self:RenderObjectSection()
    self:RenderEffectSection()
end

function VisualTab:RenderMaterialContextPopup()
    local popup = self.panel:AddPopup("MaterialContextMenu")
    self.materialContextPopup = popup
    self.SelectedMaterial = ""
    local contextMenu = StyleHelpers.AddContextMenu(popup, "Material")
    local exportNotif = Notification.new(GetLoca("Material Exported"))
    exportNotif.Pivot = {0,0}
    exportNotif.ClickToDismiss = true

    contextMenu:AddItem("Copy To Other Materials", function (sel)
        local keyName = self.SelectedMaterial
        local matTab = self.Materials[keyName]
        if not matTab then return end
        -- only copy number/vector parameters
        local param1234 = {
            [1] = matTab.Editor.Parameters[1],
            [2] = matTab.Editor.Parameters[2],
            [3] = matTab.Editor.Parameters[3],
            [4] = matTab.Editor.Parameters[4],
        }
        for _, otherMatTab in pairs(self.Materials) do
            otherMatTab.Editor:ApplyParameters(param1234)
            otherMatTab:UpdateUIState()
        end
    end)

    contextMenu:AddItem("Open Material Mixer", function (sel)
        local matTab = self.Materials[self.SelectedMaterial]
        if not matTab then return end
        local allParams = matTab.Editor.ParamSetProxy.Parameters
        local mixerParams = {}
        for paramType, typeParams in pairs(allParams) do
            mixerParams[paramType] = {}
            for paramName, paramValue in pairs(typeParams) do
                mixerParams[paramType][paramName] = matTab.Editor:GetParameter(paramName)
            end
        end

        local mixerTab = MaterialMixerTab.new(mixerParams)
        mixerTab:Render()
    end)

    contextMenu:AddItem("Reset All", function (sel)
        local matTab = self.Materials[self.SelectedMaterial]
        if not matTab then return end
        matTab:ResetAll()
    end).DontClosePopups = true

    contextMenu:AddItem("Export As Material", function (sel)
        local keyName = self.SelectedMaterial
        local matTab = self.Materials[keyName]
        if not matTab then return end
        local uuid = Uuid_v4()
        local finalPath = "Realm_Builder/Materials/" .. uuid .. ".lsx"
        local save = ResourceHelpers.BuildMaterialResource(matTab.Editor.Material, uuid, matTab.Editor.Parameters, matTab.ParentNodeName:gsub("%.[lL][sS][fF]$", ""))
        if save then
            local suc = Ext.IO.SaveFile(finalPath, save:Stringify())
            if not suc then
                Error("Failed to export material to " .. finalPath)
                exportNotif:Show(GetLoca("Failed to export material."), function (panel)
                    panel:AddText("Failed to export material to " .. finalPath)
                end)
            else
                Info("Exported material to " .. finalPath)
                exportNotif:Show(GetLoca("Material exported successfully."), function (panel)
                    panel:AddText("Exported material to " .. finalPath)
                end)
            end
        end
    end)

    contextMenu:AddItem("Export As Preset", function (sel)
        local matTab = self.Materials[self.SelectedMaterial]
        if not matTab then return end

        local save = LSXHelpers.BuildMaterialPresetBank()
        local uuid = Uuid_v4()
        local preset = ResourceHelpers.BuildMaterialPresetResourceNode(matTab.Editor.Parameters, uuid, matTab.ParentNodeName:gsub("%.[lL][sS][fF]$", "") .. "_Preset")
        save:AppendChild(preset)
        local finalPath = "Realm_Builder/Materials/" .. uuid .. ".lsx"

        local suc = Ext.IO.SaveFile(finalPath, save:Stringify({ AutoFindRoot = true }))
        if not suc then
            Error("Failed to export material preset to " .. finalPath)
            exportNotif:Show(GetLoca("Failed to export material preset."), function (panel)
                panel:AddText("Failed to export material preset to " .. finalPath)
            end)
        else
            Info("Exported material preset to " .. finalPath)
            exportNotif:Show(GetLoca("Material preset exported successfully."), function (panel)
                panel:AddText("Exported material preset to " .. finalPath)
            end)
        end
    end)
end

function VisualTab:RenderPresetsCell(parent)
    if self:GetEntity(self.guid) and not self.isAttach then
        local icon = GetIcon(self.guid) or "Item_Unknown"
        self.symbol = parent:AddImage(icon)
        self.symbol.ImageData.Size = { 64 * SCALE_FACTOR, 64 * SCALE_FACTOR }
        if EntityStore[self.guid] and EntityStore[self.guid].IconTintColor then
            self.symbol.Tint = EntityStore[self.guid].IconTintColor
        end
        self.displayNameText = parent:AddText(self.displayName)
        self.displayNameText.SameLine = true
    end

    self.saveInput = parent:AddInputText("")
    self.saveButton = parent:AddButton(GetLoca("Save"))

    self.saveButton.SameLine = true

    self.saveInput.IDContext = "PresetSave"

    self.loadCombo = parent:AddCombo("")
    self.loadButton = parent:AddButton(GetLoca("Load"))
    local removeButton = parent:AddButton(GetLoca("Remove"))

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
            if name:find(text) then
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
        if ImguiHelpers.IsFocused(self.saveInput) and not self.saveButton.Disabled then
            self.saveButton:OnClick()
        end
    end)

    self.loadButton.OnClick = function()
        local selectedName = ImguiHelpers.GetCombo(self.loadCombo)
        if selectedName and selectedName ~= "" then
            self:LoadPreset(selectedName)
            --Info("Loaded VisualTab preset: " .. selectedName)
        end
    end

    self.loadCombo.OnHoverEnter = function()
        --self.saveInput:OnChange()
    end
    self.saveInput:OnChange()

    StyleHelpers.ApplyDangerButtonStyle(removeButton)
    removeButton.OnClick = function()
        if not ImguiHelpers.GetCombo(self.loadCombo) or ImguiHelpers.GetCombo(self.loadCombo) == "" then
            return
        end
        ConfirmPopup:DangerConfirm(
            GetLoca("Are you sure you want to remove") .. " '" .. ImguiHelpers.GetCombo(self.loadCombo) .. "'?",
            function()
                local selectedName = ImguiHelpers.GetCombo(self.loadCombo)
                if selectedName and selectedName ~= "" then
                    self:Remove(selectedName)
                    self.saveInput:OnChange()
                    --Info("Removed VisualTab preset: " .. selectedName)
                end
            end)
    end

    local resetAllButton = parent:AddButton(GetLoca("Reset All"))

    local reapplyBtn = parent:AddButton(GetLoca("Reapply Changes"))

    reapplyBtn.SameLine = true
    reapplyBtn.OnClick = function()
        self:ReapplyCurrentChanges()
    end

    local warningImage = parent:AddImage(RB_ICONS.Warning) --[[@as ExtuiImageButton]]
    warningImage.Tint = { 1, 0.5, 0.5, 1 }
    warningImage.ImageData.Size = { 32 * SCALE_FACTOR, 32 * SCALE_FACTOR }
    warningImage.SameLine = true
    if self.templateName then
        self.tooltipTemplate = warningImage:Tooltip():AddText(GetLoca("Template: ") .. self.templateName)
    end
    warningImage:Tooltip():AddText(GetLoca("Some changes will affect all instances of the same template."))
    warningImage:Tooltip():AddText(GetLoca("If 'Reset All' doesn't work, reload a save."))

    resetAllButton.OnClick = function(_)
        Timer:Ticks(10, function()
            local isChara = CIsCharacter(self.guid)

            for key, matTab in pairs(self.Materials) do
                matTab.Editor:ClearParameters()

                if not isChara then
                    matTab.Editor:ResetAll()
                end

                matTab:UpdateUIState()
            end

            if isChara  then
                NetChannel.Replicate:SendToServer({
                    Guid = self.guid,
                    Field = "GameObjectVisual",
                })
            end

            if not isChara then
                for key, func in pairs(self.resetFuncs) do
                    for propName, resetFunc in pairs(func) do
                        resetFunc()
                    end
                end
            end
        end)
    end

    --#endregion Left Cell Content
end

function VisualTab:RenderUtilsCell(parent)
    local detachCell = ImguiElements.AddRightAlignCell(parent)
    local loadCell = parent

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
        StyleHelpers.ApplyInfoButtonStyle(detachButton)
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
    local entity = self:GetEntity(self.guid) --[[@as EntityHandle]]

    local visual = self:GetVisual(self.guid)

    if not visual then return end

    if not visual.Attachments or #visual.Attachments == 0 then return end

    local renderParent = self.editorWindow

    if self.attachmentsHeader then
        self.attachmentsHeader:Destroy()
        self.attachmentsHeader = renderParent:AddCollapsingHeader(GetLoca("Attachments"))
    else
        self.attachmentsHeader = renderParent:AddCollapsingHeader(GetLoca("Attachments"))
    end

    self.attachmentsHeader.OnHoverEnter = function ()
        self:RenderAttachmentEditors()
        self.attachmentsHeader.OnHoverEnter = nil
    end
end

--- @type table<string, fun(element: CharacterCreationAppearanceMaterialSetting):RB_ParameterSet>
local colorDefinitionMap = {
    Tattoo = function(element)
        local params = {}
        local colorDef = Ext.StaticData.Get(element.Color, "ColorDefinition") --[[@as ResourceColor]]

        return params
    end,
    HairHighlight = function (element)
        local params = {}
        local colorDef = Ext.StaticData.Get(element.Color, "ColorDefinition") --[[@as ResourceColor]]
        local vec3Color = {colorDef.Color[1], colorDef.Color[2], colorDef.Color[3]}

        params = {
            [1] = {
                ["Highlight_Intensity"] = {
                    element.ColorIntensity or 0.0
                },
            },
            [2] = {},
            [3] = {
                ["Highlight_Color"] = vec3Color or {1.0, 1.0, 1.0},
                ["Beard_Highlight_Color"] = vec3Color or {1.0, 1.0, 1.0}
            }
        }
        return params
    end,
    HairGraying = function (element)
        local params = {}
        local colorDef = Ext.StaticData.Get(element.Color, "ColorDefinition") --[[@as ResourceColor]]
        local vec3Color = {colorDef.Color[1], colorDef.Color[2], colorDef.Color[3]}
        params = {
            [1] = {
                ["Graying_Intensity"] = {
                    element.ColorIntensity or 0.0
                },
                ["Beard_Graying_Intensity"] = {
                    element.ColorIntensity or 0.0
                }
            },
            [2] = {},
            [3] = {
                ["Hair_Graying_Color"] = vec3Color or {1.0, 1.0, 1.0},
                ["Beard_Graying_Color"] = vec3Color or {1.0, 1.0, 1.0}
            }
        }

        return params
    end,
    HornColor = function (element)
        local params = {}
        local colorDef = Ext.StaticData.Get(element.Color, "ColorDefinition") --[[@as ResourceColor]]
        local vec3Color = {colorDef.Color[1], colorDef.Color[2], colorDef.Color[3]}

        params = {
            [1] = {},
            [2] = {},
            [3] = {
                ["NonSkinColor"] = vec3Color or {1.0, 1.0, 1.0}
            }
        }

        return params
    end,
    HornTipColor = function (element)
        local params = {}
        local colorDef = Ext.StaticData.Get(element.Color, "ColorDefinition") --[[@as ResourceColor]]
        local vec3Color = {colorDef.Color[1], colorDef.Color[2], colorDef.Color[3]}
        params = {
            [1] = {},
            [2] = {},
            [3] = {
                ["NonSkinTipColor"] = vec3Color or {1.0, 1.0, 1.0}
            }
        }

        return params
    end,
    LipsMakeup = function (element)
        local params = {}
        local colorDef = Ext.StaticData.Get(element.Color, "ColorDefinition") --[[@as ResourceColor]]
        local vec3Color = {colorDef.Color[1], colorDef.Color[2], colorDef.Color[3]}

        params = {
            [1] = {
                ["LipsMakeupIntensity"] = {
                    element.ColorIntensity or 0.0
                },
                ["LipsMakeupMetalness"] = {
                    element.MetallicTint or 0.0
                },
                ["LipsMakeupRoughness"] = {
                    1 - (element.GlossyTint or 0.0)
                }
            },
            [2] = {},
            [3] = {
                ["Lips_Makeup_Color"] = vec3Color or {1.0, 1.0, 1.0},
            }
        }

        return params
    end,
}
local additionalChoicesHandle = {
    [1] = "Vitiligo",
    [2] = "Freckle",
    [3] = "Age_Weight",
    [4] = "Freckle_Intensity",
}

local function mergeParameterSets(base, override)
    for ptype, typeParams in pairs(override) do
        base[ptype] = base[ptype] or {}
        for paramName, value in pairs(typeParams) do
            base[ptype][paramName] = value
        end
    end
end

function VisualTab:DetermineOverrideCharacterParameters()
    local overrideCharacterParams = {
        {}, -- ScalarParameters
        {}, -- Vector2Parameters
        {}, -- Vector3Parameters
        {}, -- VectorParameters
    }
    local entity = self:GetEntity(self.guid) --[[@as EntityHandle]]
    local ccDummy = GetMirrotDummyEntity()
    --- @type CharacterCreationAppearance|CharacterCreationAppearanceComponent
    local cca = entity.CharacterCreationAppearance
    if ccDummy and ccDummy.ClientCCChangeAppearanceDefinition then
        cca = ccDummy.ClientCCChangeAppearanceDefinition.Definition.Visual
    end
    if not cca then
        cca = entity.AppearanceOverride and entity.AppearanceOverride.Visual --[[@as CharacterCreationAppearanceComponent]]
    end
    if cca then
        
        local ccaPresetgroup = ImguiElements.AddTree(self.attachmentsHeader, "Character Creation Material Presets")

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

        ---[[ 1 = Vitiligo, 2 = Freckle Quantity, 3 = Maturity, 4 = Freckle Intensity]]
        for i, num in pairs(cca.AdditionalChoices) do
            local params = {}
            local paramName = additionalChoicesHandle[i]
            params[1] = {}
            if i == 3 then
                num = num * 0.4
            end
            params[1][paramName] = num
            mergeParameterSets(overrideCharacterParams, params)
        end
        
        for i, colorChoice in pairs(cca.Elements) do
            local mat = Ext.StaticData.Get(colorChoice.Material, "CharacterCreationAppearanceMaterial") --[[@as ResourceCharacterCreationAppearanceMaterial]]
            local mp = MaterialProxy.new(mat.MaterialPresetUUID)
            if mp and next(mp.Parameters) and next(mp.Parameters[1]) then
                mergeParameterSets(overrideCharacterParams, mp.Parameters)
                goto continue
            end
            if not mat or not colorDefinitionMap[mat.MaterialType2] then
                goto continue
            end
            local params = colorDefinitionMap[mat.MaterialType2](colorChoice)
            mergeParameterSets(overrideCharacterParams, params)
            ::continue::
        end

        local hasCCA = false
        for _, colorIndex in ipairs(colorOrder) do
            local colorType = colorIndex
            local resUuid = allColors[colorType]
            if not IsUuid(resUuid) then goto continue end
            local res = Ext.StaticData.Get(resUuid, colorTypes[colorType]) --[[@as ResourceCharacterCreationColor]]
            if not res then goto continue end
            local matPresetRes = MaterialPresetProxy.new(res.MaterialPresetUUID)
            if not matPresetRes then goto continue end
            hasCCA = true
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
        if not hasCCA then
            ccaPresetgroup.Visible = false
        end

        ccaPresetgroup.OnExpand = function()
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
            ccaPresetgroup.OnExpand = nil
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
                    overrideCharacterParams[ptype][param.Parameter] = param.Value
                end
            end
        end
    end

    return overrideCharacterParams
end

function VisualTab:RenderAttachmentEditors()
    local entity = self:GetEntity(self.guid) --[[@as EntityHandle]]
    local visual = self:GetVisual(self.guid)

    if not visual then return end

    local overrideCharacterParams = {}
    if CIsCharacter(self.guid) then
        overrideCharacterParams = self:DetermineOverrideCharacterParameters()
    end

    local attachments = visual.Attachments or {}

    for attIndex, attach in ipairs(attachments) do
        if #attach.Visual.ObjectDescs == 0 then goto continue end
        local vres = attach.Visual.VisualResource
        if not vres then goto continue end
        local source = vres and vres.SourceFile or "Unknown Model"
        local gr2FileName = GetLastPath(source)

        local displayName = vres.Slot

        if displayName == "" or displayName == "Unassigned" then 
            displayName = gr2FileName
        end

        local attachNode = ImguiElements.AddTree(self.attachmentsHeader, displayName .. "##" .. tostring(attIndex), false)
        attachNode:AddTreeIcon(RB_ICONS.Box, IMAGESIZE.ROW).Tint = HexToRGBA("FFB98634")
        
        local gr2Text = attachNode:AddHint("Model: " .. gr2FileName)
        gr2Text:SetColor("Text", HexToRGBA("FF6D6D6D"))
        gr2Text.SameLine = true
        gr2Text.Font = "Tiny"
        local lodNode = nil

        for descIndex, obj in ipairs(attach.Visual.ObjectDescs) do
            local modelName = obj.Renderable and obj.Renderable.Model and obj.Renderable.Model.Name or "Unknown Model"
            local parentNode = attachNode
            if modelName:find("LOD") then
                lodNode = lodNode or attachNode:AddTree("LODs", false)
                parentNode = lodNode
            end

            local objNode = parentNode:AddTree(modelName .. "##" .. tostring(attIndex) .. "::" .. tostring(descIndex), false)
            objNode:AddTreeIcon(RB_ICONS.Bounding_Box, IMAGESIZE.ROW).Tint = HexToRGBA("FF27B040")


            local matName = obj.Renderable.ActiveMaterial.Material.Name
            local function getliveMat()
                local visual = self:GetVisual(self.guid)
                if not visual then return nil end

                 local attach = visual.Attachments[attIndex]
                if not attach then return nil end

                local desc = attach.Visual.ObjectDescs[descIndex]
                if not desc or not desc.Renderable then return nil end

                return desc.Renderable.ActiveMaterial
            end

            --- @return MaterialParameters|nil
            local function getliveParams()
                local mat = getliveMat()
                if not mat then return nil end
                return mat.Material.Parameters
            end

            local keyName = gr2FileName .. "::" .. modelName .. "::" .. tostring(attIndex) .. "::" .. tostring(descIndex)
            self:RenderTransformSliders(objNode, descIndex, attIndex, keyName)

            local materialTab = self.Materials[keyName] or MaterialTab.new(objNode, matName, getliveMat, getliveParams) --[[@as MaterialTab]]
            materialTab.Parent = objNode
            materialTab.Editor.Instance = getliveMat
            materialTab.Editor.ParamsSrc = getliveParams
            materialTab.Editor.ParamSetProxy:Update(getliveParams())
            materialTab.Editor:SetDefaultParameters(overrideCharacterParams)

            objNode.OnRightClick = function()
                --local renable = VisualHelpers.GetRenderable(self.guid, descIndex, attIndex)
                objNode:OnExpand()
                self.SelectedMaterial = keyName
                self.materialContextPopup:Open()
            end

            objNode.OnExpand = function()
                materialTab:Render()
                materialTab:UpdateUIState()
                materialTab.Panel.Visible = false
                materialTab.ParentNode.OnRightClick = function()
                    self.SelectedMaterial = keyName
                    self.materialContextPopup:Open()
                end
                
                objNode.OnExpand = function()
                end
            end

            self.Materials[keyName] = materialTab
        end

        ::continue::
    end
end

function VisualTab:RenderObjectSection()
    if next(LightCToArray(self:GetEntity(self.guid).Visual.Visual.ObjectDescs)) == nil then
        return
    end

    local visual = self:GetVisual(self.guid)
    if not visual then return end

    local renderParent = self.editorWindow

    if self.materialHeader then
        self.materialHeader:Destroy()
        self.materialHeader = renderParent:AddCollapsingHeader(GetLoca("Material Editor"))
    else
        self.materialHeader = renderParent:AddCollapsingHeader(GetLoca("Material Editor"))
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
    local visual = self:GetVisual(self.guid)
    if not visual then return end

    local lodTree = nil
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

        --- @type ExtuiTreeParent
        local parentTree = self.materialHeader
        if meshName:find("LOD") then
            lodTree = lodTree or ImguiElements.AddTree(self.materialHeader, "LODs", false)
            parentTree = lodTree
        end

        local materialNode = ImguiElements.AddTree(parentTree, meshName .. "##" .. tostring(descIndex), false)
        materialNode:AddTreeIcon(RB_ICONS.Bounding_Box, IMAGESIZE.ROW).Tint = HexToRGBA("FF268B39")

        local function getliveMat()
            local visual = self:GetVisual(self.guid)
            if not visual then return nil end

            local rend = visual.ObjectDescs[descIndex] and visual.ObjectDescs[descIndex].Renderable
            if not rend then return nil end

            return rend.ActiveMaterial
        end

        local function getliveParams()
            local mat = getliveMat()
            if not mat then return nil end
            return mat.Material.Parameters
        end

        --- @return MaterialParameters|nil

        local keyName = meshName .. "::" .. tostring(descIndex)
        self:RenderTransformSliders(materialNode, descIndex, nil, keyName)
        local materialEditor = self.Materials[keyName] or
            MaterialTab.new(materialNode, material.MaterialName, getliveMat, getliveParams) --[[@as MaterialTab]]
        materialEditor.IsObject = true
        materialEditor.Parent = materialNode
        materialEditor.Editor.Instance = getliveMat
        materialEditor.Editor.ParamsSrc = getliveParams
        materialEditor.Editor.ParamSetProxy:Update(getliveParams())

        materialNode.OnRightClick = function()
            materialNode.OnExpand()
            self.SelectedMaterial = keyName
            self.materialContextPopup:Open()
        end

        materialNode.OnExpand = function()
            materialEditor:Render()
            materialEditor:UpdateUIState()
            materialEditor.ParentNode.OnRightClick = function()
                self.SelectedMaterial = keyName
                self.materialContextPopup:Open()
            end

            
            materialNode.OnExpand = function() end
        end

        self.Materials[keyName] = materialEditor

        ::continue::
    end
end

function VisualTab:RenderEffectSection()
    local entity = self:GetEntity(self.guid) --[[@as EntityHandle]]
    if entity.Effect == nil then
        return
    end

    self.hasEffect = true

    local renderParent = self.editorWindow

    if self.effectHeader then
        self.effectHeader:Destroy()
        self.effectHeader = renderParent:AddCollapsingHeader(GetLoca("Effect Editor"))
    else
        self.effectHeader = renderParent:AddCollapsingHeader(GetLoca("Effect Editor"))
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
    local entity = self:GetEntity(self.guid) --[[@as EntityHandle]]
    --self.effectRoot = self.effectHeader:AddTree(GetLoca("Effects"))
    if not entity.Effect or not entity.Effect.Timeline or not entity.Effect.Timeline.Components then
        return
    end

    self:SetupEffectContextMenu()
    local effectNameCnt = {}

    self:RenderEffectTimelineEditor()

    -- WHY is effect so disorderly
    for compIndex, component in ipairs(entity.Effect.Timeline.Components) do
        --_P(component.TypeName)
        local newTree = nil
        if component.TypeName == "Light" then
            effectNameCnt[component.TypeName] = (effectNameCnt[component.TypeName] or 0) + 1
            local cnt = effectNameCnt[component.TypeName]
            local nodeName = GetLoca("Light") .. (cnt ~= 1 and " (" .. cnt .. ")" or "")
            newTree = ImguiElements.AddTree(self.effectHeader, nodeName, false)
            newTree.OnRightClick = function()
                self.SelectedEffectComponent = "Light::" .. tostring(compIndex)
                self.effectContextPopup:Open()
            end

            self:RenderLightComponent(newTree, component, compIndex, cnt)
            self:RenderLightEntity(newTree, component, compIndex, cnt)
        end

        if component.TypeName == "ParticleSystem" then
            effectNameCnt[component.TypeName] = (effectNameCnt[component.TypeName] or 0) + 1
            local cnt = effectNameCnt[component.TypeName]
            local nodeName = GetLoca("Particle System") .. (cnt ~= 1 and " (" .. cnt .. ")" or "")
            newTree = ImguiElements.AddTree(self.effectHeader, nodeName, false)
            newTree.OnRightClick = function()
                self.SelectedEffectComponent = "ParticleSystem::" .. tostring(compIndex)
                self.effectContextPopup:Open()
            end
            self:RenderParticleSystemComponent(newTree, component, compIndex, cnt)
        end
    end
end

function VisualTab:RenderEffectTimelineEditor()
    local entity = self:GetEntity(self.guid) --[[@as EntityHandle]]
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


    --local phaseCnt = #entity.Effect.Timeline.Header.Phases or 0
    --[[local phaseSlider = ImguiElementsAddSliderWithStep(timelineTree, GetLoca("Set Phases"), timeline.PhaseIndex, 1, math.max(1, phaseCnt), 1, true)
    phaseSlider.UserData.DisableRightClickSet = true
    phaseSlider.OnChange = function()
        local entity = self:GetEntity(self.guid)
        if not entity.Effect or not entity.Effect.Timeline then
            return
        end
        --entity.Effect.Timeline.PhaseIndex = phaseSlider.Value[1]
        --entity.Effect.Timeline.JumpToPhase = phaseSlider.Value[1]
    end

    local timeSlider = ImguiElementsAddSliderWithStep(timelineTree, GetLoca("Set Time"), timeline.TimePlayed, 0, timeline.Duration, 0.1, false)

    timeSlider.UserData.DisableRightClickSet = true
    timeSlider.OnChange = function()
        local entity = self:GetEntity(self.guid)
        if not entity.Effect or not entity.Effect.Timeline then
            return
        end
        entity.Effect.Timeline.JumpToTime = timeSlider.Value[1]
    end]]

    row:AddCell():AddText(GetLoca("Playing Speed") .. ":")
    local playSpeedSlider = ImguiElements.AddSliderWithStep(row:AddCell(), GetLoca("Set Play Speed"), timeline.PlayingSpeed, 0.1, 5.0, 0.1, false)
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

function VisualTab:RenderEffectComponentEditor(parent, key, getComp, renderInfo)
    local component = getComp()
    if not component then return end

    local propMap = renderInfo.PropertyMap
    local renderOrder = renderInfo.RenderOrder

    local renderHandlers = {
        Scalar = function(tree, propName, propInfo)
            self:RenderEffectComponentSliders(tree, getComp, key, propName, propInfo)
        end,
        Vector2 = function(tree, propName, propInfo)
            self:RenderEffectComponentSliders(tree, getComp, key, propName, propInfo)
        end,
        Vector3 = function(tree, propName, propInfo)
            self:RenderEffectComponentSliders(tree, getComp, key, propName, propInfo)
        end,
        Vector4 = function(tree, propName, propInfo)
            self:RenderEffectComponentSliders(tree, getComp, key, propName, propInfo)
        end,
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
function VisualTab:RenderEffectComponentSliders(panel, getComp, key, componentName, valueInfo)
    local applyMethod = valueInfo.Setter or function (value)
        local comp = getComp()
        if not comp then return end

        comp[componentName] = value
    end
    local getMethod = valueInfo.Getter or function ()
        local comp = getComp()
        if not comp then return nil end

        return comp[componentName]
    end

    local initValue = self.resetParams[key] and self.resetParams[key][componentName] or getMethod()
    self.resetParams[key] = self.resetParams[key] or {}
    self.resetParams[key][componentName] = initValue
    if type(initValue) == "number" then
        initValue = { initValue }
    end
    local isInt = valueInfo.IsInt or false
    local range = valueInfo.Range or { Min = -10, Max = 10 , Step = 0.1 }
    local compDisplayName = valueInfo.DisplayName or componentName

    local function saveChanged(value)
        local comp = getComp()
        if not comp then return end

        if #value == 1 then
            value = value[1]
        end
        applyMethod(value)
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

    local updateMethod = ImguiElements.AddNumberSliders(panel, compDisplayName, getMethod, saveChanged, { IsInt = isInt, Range = range, OnReset = onReset, ResetValue = initValue, IsColor = valueInfo.IsColor })

    self.resetFuncs[key][componentName] = function()
        applyMethod(self.resetParams[key][componentName])
        updateMethod()
        onReset()
    end
    self.updateFuncs[key][componentName] = function()
        updateMethod()
    end
end

function VisualTab:RenderEffectComponentBooleanCheckbox(panel, getComp, key, componentName, boolInfo)
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

function VisualTab:RenderEffectComponentBitmaskRadioButtons(panel, getComp, key, componentName, bitMaskInfo)
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

function VisualTab:RenderEffectComponentEnumRadioButtons(panel, getComp, key, componentName, enumInfo)
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

function VisualTab:SetupEffectContextMenu()
    local effectContextPopup = self.panel:AddPopup("EffectContextMenu")
    self.effectContextPopup = effectContextPopup
    self.SelectedEffectComponent = nil
    local contextMenu = StyleHelpers.AddContextMenu(effectContextPopup, "Effect Component")

    contextMenu:AddItem("Apply To Same Type", function (sel)
        local compKey = self.SelectedEffectComponent
        if not compKey then return end
        
        local modfiedParams = self.Effects[compKey]
        if not modfiedParams then return end

        local parsedKey = SplitByString(compKey, "::")
        local compIndex = tonumber(parsedKey[2])
        if not compIndex then return end
        local selectedComp = VisualHelpers.GetEffectComponent(self.guid, compIndex)
        if not selectedComp then return end
        local compType = selectedComp.TypeName

        local entity = self:GetEntity(self.guid) --[[@as EntityHandle]]
        if not entity.Effect or not entity.Effect.Timeline or not entity.Effect.Timeline.Components then
            return
        end

        for otIdx, comp in FilteredPairs(entity.Effect.Timeline.Components, function(idx, comp)
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
function VisualTab:RenderLightEntity(node, component, compIndex)
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
                { Label = "Scenery", Value = 1 },
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
                { Label = "Linear", Value = 0 },
                { Label = "Inverse Square", Value = 1 },
                { Label = "Smooth Step", Value = 2 },
                { Label = "Smoother Step", Value = 3 },
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
function VisualTab:RenderLightComponent(node, component, compIndex)
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
            local hasABCDField = false
            local checkMap = { A = true, B = true, C = true, D = true }
            for _, frame in pairs(lcomp.IntensityProperty.KeyFrames or {}) do
                for _, f in pairs(frame.Frames or {}) do
                    for pName, value in pairs(f) do
                        if checkMap[pName] then
                            hasABCDField = true
                            break
                        end
                    end
                end
                if hasABCDField then break end
            end
            if hasABCDField then
                prop.Setter = function(value)
                    lcomp = VisualHelpers.GetEffectComponent(self.guid, compIndex) --[[@as AspkLightComponent]]
                    if not lcomp then return end
                    for _, keyFrame in pairs(lcomp.IntensityProperty.KeyFrames or {}) do
                        for _, frame in pairs(keyFrame.Frames or {}) do
                            frame.A = value[1]
                            frame.B = value[2]
                            frame.C = value[3]
                            frame.D = value[4]
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

                    return { frame.A, frame.B, frame.C, frame.D }
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
            return LightCToArray(lc)
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
function VisualTab:RenderParticleSystemComponent(node, component, compIndex)
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

function VisualTab:RenderTransformSliders(parent, descIndex, attachIndex, keyName)
    local selectInTransformEditor = parent:AddButton(GetLoca("Select in Transform Editor"))
    selectInTransformEditor.IDContext = "VisualTab_TransformEditorSelectButton_" .. descIndex .. "_" .. (attachIndex or "")

    selectInTransformEditor.OnClick = function()
        if not self:CheckVisual() then return end
        local renderableFunc = function()
            return VisualHelpers.GetRenderable(self.guid, descIndex, attachIndex)
        end
        local startScale = VisualHelpers.GetRenderableScale(self.guid, descIndex, attachIndex)
        local proxy = RenderableMovableProxy.new(renderableFunc)
        RB_GLOBALS.TransformEditor:Select({ proxy })
        self.resetParams[keyName] = self.resetParams[keyName] or {}
        self.resetParams[keyName].Scale = startScale
        self.resetParams[keyName].DescIndex = descIndex
        self.resetParams[keyName].AttachIndex = attachIndex
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

--- @class RB_VisualPreset
--- @field Name string
--- @field TemplateName string
--- @field Effects table<string, table<string, any>> -- key <componentType :: componentIndex> -> propertyName -> value
--- @field Materials table<string, RB_ParameterSet> -- key <name :: attachIndex(if any) :: descIndex> -> RB_ParameterSet
--- @field Transforms table<string, Transform> -- key <name :: attachIndex(if any) :: descIndex> -> Transform

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

    local localTransforms = {}
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

    
        local objStart = self.resetParams[key]

        if objStart == nil then
            goto continue
        end

        local currentScale = VisualHelpers.GetRenderableScale(self.guid, objStart.DescIndex, objStart.AttachIndex)
        if EqualArrays(currentScale, objStart.Scale) == false then
            localTransforms[key] = {
                Scale = currentScale
            }
        end

        ::continue::
    end

    oriFile[saveName] = {
        Name = saveName,
        TemplateName = templateName,
        Effects = DeepCopy(self.Effects),
        Materials = Mats,
        Transforms = localTransforms,
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

function VisualTab:ExportPreset()
    local presetData = {
        Materials = {},
        Effects = DeepCopy(self.Effects),
        Transforms = {},
    }

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
            presetData.Materials[key] = params
        end
        local objStart = self.resetParams[key]
        local currentScale = VisualHelpers.GetRenderableScale(self.guid, objStart.DescIndex, objStart.AttachIndex)
        if EqualArrays(currentScale, objStart.Scale) == false then
            presetData.Transforms[key] = {
                Scale = currentScale
            }
        end
    end

    return presetData
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

    if not preset then
        Error("No saved preset found with name: " .. name)
        return false
    end

    for _, resetFunc in pairs(self.resetFuncs) do
        for _, func in pairs(resetFunc) do
            if func then
                func()
            end
        end
    end

    VisualHelpers.ApplyVisualParams(self.guid, preset)
    self.currentPreset = name
    self.Effects = DeepCopy(preset.Effects) or {}
    self.LocalTransforms = DeepCopy(preset.Transforms) or {}

    for key, matParams in pairs(preset.Materials or {}) do
        if self.Materials[key] then
            self.Materials[key].Editor:ApplyParameters(matParams)
            self.Materials[key]:UpdateUIState()
        end
    end

    if self.loadCombo then
        ImguiHelpers.SetCombo(self.loadCombo, name)
    end

    if IsPartyMember(self.guid) then

    else
        EntityStore[self.guid].VisualPreset = name
    end

    self:UpdateAll()
end

function VisualTab:UpdateAll()
    for _, compType in pairs(self.updateFuncs) do
        for _, updateFunc in pairs(compType) do
            if updateFunc then
                updateFunc()
            end
        end
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
    --Debug("VisualTab:_getAllPresetNames - Found presets: " .. table.concat(names, ", "))
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
    local entity = self:GetEntity(self.guid)
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

--- merge modified material params from materials into one set
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
