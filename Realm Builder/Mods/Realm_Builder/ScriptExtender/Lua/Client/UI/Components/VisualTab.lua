local EntityEffectTabClass = Ext.Require("Client/UI/Components/EntityEffectTab.lua") --[[@as RB_EntityEffectTab]]
local VISUALTAB_WIDTH = 800 * SCALE_FACTOR
local VISUALTAB_HEIGHT = 1000 * SCALE_FACTOR

local visualTabCache = {} --[[@as table<GUIDSTRING|EntityHandle, VisualTab> ]]

local ClientVisualPresetData = {}
local ClientOriginalVisualData = {}

local function LoadVisualPresetData()
    local refFile = FilePath.GetVisualReferencePath()
    local refData = Ext.Json.Parse(Ext.IO.LoadFile(refFile) or "{}")
    for templateName, data in pairs(refData) do
        local visualPresetFile = FilePath.GetVisualPresetsPath(templateName)
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

EventsSubscriber.RegisterOnSessionLoaded(function()
    --local now = Ext.Utils.MonotonicTime()
    LoadVisualPresetData()
    ClearOriginalVisualData()
    --Debug("Visual preset data loaded in " .. (Ext.Utils.MonotonicTime() - now) .. "ms")
end)

--- @alias RB_MaterialsTable table<string, MaterialTab> -- linkId|attachment's visual resource id :: attachIndex :: descIndex -> MaterialTab
--- @alias RB_EffectsTable table<string, table<string, any>> -- componentType::componentIndex -> { PropertyName = Value, ... }

--- @class VisualTab
--- @field Materials RB_MaterialsTable
--- @field EntityEffectTab RB_EntityEffectTab
--- @field guid GUIDSTRING
--- @field templateName string
--- @field new fun(guid: GUIDSTRING?, displayName: string?, parent: ExtuiTreeParent?, templateName: string?): VisualTab
--- @field FetchByGuid fun(guid: GUIDSTRING): VisualTab|nil
VisualTab = {}
VisualTab.__index = VisualTab

function VisualTab.FetchByGuid(guid)
    return visualTabCache[guid]
end

function VisualTab.new(guid, displayName, parent, templateName, entity)
    local obj = setmetatable({}, VisualTab)

    --- clear stale cache entries
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

--- @param entity EntityHandle
--- @param uuid GUIDSTRING?
--- @param displayName string?
function VisualTab.CreateByEntity(entity, uuid, displayName)
    if entity.Scenery then
        displayName = entity.Visual and entity.Visual.Visual and
            RBStringUtils.GetLastPath(entity.Visual.Visual.VisualResource.SourceFile) or "Unknown Scenery"
        uuid = entity.Scenery.Uuid
    end

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
    self.EntityEffectTab = EntityEffectTabClass.new(nil, self.GetEntity, self.guid)

    self.currentPreset = EntityStore[guid] and EntityStore[guid].VisualPreset or nil

    if not templateName and self.guid ~= "" and not EntityStore[self.guid] then
        NetChannel.GetTemplate:RequestToServer({ Guid = self.guid }, function(response)
            if response.GuidToTemplateId and response.GuidToTemplateId[self.guid] then
                self.templateId = response.GuidToTemplateId[self.guid]
                local getTemplateName = RBStringUtils.TrimTail(response.GuidToTemplateId[self.guid], 37)
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
    self.templateName = self.templateName or (stored and RBStringUtils.TrimTail(stored.TemplateId, 37)) or "Unknown"
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

    self.displayName = self.displayName or RBGetName(self.guid)

    if self.parent and self.isAttach then
        self:OnAttach()
        self.panel = self.parent:AddTabItem(GetLoca("Visual"))
        self.isWindow = false
    else
        self.panel = WindowManager.RegisterWindow(self.guid, self.displayName .. " - Visual Editor",
            self.lastPosition,
            self.lastSize or { VISUALTAB_WIDTH, VISUALTAB_HEIGHT })
        self.isWindow = true
        self:OnDetach()
    end

    self.isVisible = true

    local entity = self:GetEntity(self.guid) --[[@as EntityHandle]]

    local hasEffect = entity.Effect and true or false
    local hasVisual = entity.Visual and entity.Visual.Visual and true or false

    if not (hasVisual or hasEffect) then
        local rerenderButton = self.panel:AddButton(GetLoca("Try to reload Visual Tab"))
        local reasons = {
            "Too far from camera",
            "In inventory, or equipped",
            "Entity has no visual"
        }
        local tooltip = rerenderButton:Tooltip()
        tooltip:AddText(GetLoca("Visual Tab cannot load because the entity's visual data is unavailable. Possible reasons:")).TextWrapPos = 900 *
            SCALE_FACTOR
        for i, reason in ipairs(reasons) do
            tooltip:AddBulletText(i .. ". " .. reason)
        end
        rerenderButton.OnClick = function()
            self:Refresh()
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

    if entity.CharacterCreationAppearance then
        local cca = entity.CharacterCreationAppearance --[[@as CharacterCreationAppearance]]
        local fields = {
            EyeColor = "Right Eye Color",
            SecondEyeColor = "Left Eye Color",
            HairColor = "Hair Color",
            SkinColor = "Skin Color",
        }
        local fieldOrder = {
            "SkinColor",
            "HairColor",
            "EyeColor",
            "SecondEyeColor",
        }
        local fieldResTypes = {
            EyeColor = "CharacterCreationEyeColor",
            SecondEyeColor = "CharacterCreationEyeColor",
            HairColor = "CharacterCreationHairColor",
            SkinColor = "CharacterCreationSkinColor",
        }

        local appearanceHeader = self.editorWindow:AddCollapsingHeader(GetLoca("Character Creation Appearance"))
        local alignedTab = ImguiElements.AddAlignedTable(appearanceHeader)
        for _, fieldName in ipairs(fieldOrder) do
            local colorId = cca[fieldName]
            local colorRes = Ext.StaticData.Get(colorId, fieldResTypes[fieldName])

            MaterialPresetsMenu:RenderPresetColorBox(colorRes, alignedTab:AddNewLine(fields[fieldName]))
        end
    end

    self:RenderAttachmentSection()
    self:RenderObjectSection()
    self:RenderEffectSection()
end

function VisualTab:RenderEffectSection()
    self.EntityEffectTab:SetUIParent(self.editorWindow)
    self.EntityEffectTab:Render()
end

function VisualTab:RenderMaterialContextPopup()
    local popup = self.panel:AddPopup("MaterialContextMenu")
    self.materialContextPopup = popup
    self.SelectedMaterial = ""
    local contextMenu = ImguiElements.AddContextMenu(popup, "Material")
    local exportNotif = Notification.new(GetLoca("Material Exported"))
    exportNotif.Pivot = { 0, 0 }
    exportNotif.ClickToDismiss = true

    contextMenu:AddItem("Copy To Other Materials", function(sel)
        local keyName = self.SelectedMaterial
        local matTab = self.Materials[keyName]
        if not matTab or not matTab.Editor then return end
        -- only copy number/vector parameters
        local paramSet = {
            [1] = matTab.Editor.Parameters[1],
            [2] = matTab.Editor.Parameters[2],
            [3] = matTab.Editor.Parameters[3],
            [4] = matTab.Editor.Parameters[4],
        }
        for _, otherMatTab in pairs(self.Materials) do
            otherMatTab.Editor:ApplyParameters(paramSet)
            otherMatTab:UpdateUIState()
        end
    end)

    contextMenu:AddItem("Open Material Mixer", function(sel)
        local matTab = self.Materials[self.SelectedMaterial]
        if not matTab then return end
        local allParams = matTab.Editor.ParamSet.Parameters
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

    contextMenu:AddItem("Edit Transform", function(selectable)
        if not self:CheckVisual() then return end
        if IsInCharacterCreationMirror() then return end
        local keyName = self.SelectedMaterial
        local parsedKey = RBStringUtils.SplitByString(keyName, "::")
        local eleCnt = #parsedKey
        local descIndex = tonumber(parsedKey[eleCnt]) or nil
        local attachIndex = tonumber(parsedKey[eleCnt - 1]) or nil
        if not descIndex then return end
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
    end)

    contextMenu:AddItem("Reset All", function(sel)
        local matTab = self.Materials[self.SelectedMaterial]
        if not matTab then return end
        matTab:ResetAll()
    end).DontClosePopups = true

    contextMenu:AddItem("Save Current as Default", function(sel)
        local matTab = self.Materials[self.SelectedMaterial]
        if not matTab then return end
        matTab.Editor:SaveCurrentParameters()
    end).DontClosePopups = true

    contextMenu:AddItem("Export As Material", function(sel)
        local keyName = self.SelectedMaterial
        local matTab = self.Materials[keyName]
        if not matTab then return end
        local uuid = RBUtils.Uuid_v4()
        local finalPath = "Realm_Builder/Materials/" .. uuid .. ".lsx"
        local save = ResourceHelpers.BuildMaterialResource(matTab.Editor.Material, uuid, matTab.Editor.Parameters,
            matTab.ParentNodeName:gsub("%.[lL][sS][fF]$", ""))
        if save then
            local suc = Ext.IO.SaveFile(finalPath, save:Stringify())
            if not suc then
                Error("Failed to export material to " .. finalPath)
                exportNotif:Show(GetLoca("Failed to export material."), function(panel)
                    panel:AddText("Failed to export material to " .. finalPath)
                end)
            else
                Info("Exported material to " .. finalPath)
                exportNotif:Show(GetLoca("Material exported successfully."), function(panel)
                    panel:AddText("Exported material to " .. finalPath)
                end)
            end
        end
    end)

    contextMenu:AddItem("Export As Preset", function(sel)
        local matTab = self.Materials[self.SelectedMaterial]
        if not matTab then return end

        local save = LSXHelpers.BuildMaterialPresetBank()
        local uuid = RBUtils.Uuid_v4()
        local preset = ResourceHelpers.BuildMaterialPresetResourceNode(matTab.Editor.Parameters, uuid,
            matTab.ParentNodeName:gsub("%.[lL][sS][fF]$", "") .. "_Preset")
        save:AppendChild(preset)
        local finalPath = "Realm_Builder/Materials/" .. uuid .. ".lsx"

        local suc = Ext.IO.SaveFile(finalPath, save:Stringify({ AutoFindRoot = true }))
        if not suc then
            Error("Failed to export material preset to " .. finalPath)
            exportNotif:Show(GetLoca("Failed to export material preset."), function(panel)
                panel:AddText("Failed to export material preset to " .. finalPath)
            end)
        else
            Info("Exported material preset to " .. finalPath)
            exportNotif:Show(GetLoca("Material preset exported successfully."), function(panel)
                panel:AddText("Exported material preset to " .. finalPath)
            end)
        end
    end)
end

--- @param parent ExtuiTreeParent
function VisualTab:RenderPresetsCell(parent)
    if self:GetEntity(self.guid) and not self.isAttach then
        local icon = RBGetIcon(self.guid) or "Item_Unknown"
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

    self.saveInput.EnterReturnsTrue = true

    local function updatePresetOptions(keyword)
        local comboOpts = {}

        for _, name in ipairs(self:_getAllPresetNames()) do
            if keyword == "" or name:find(keyword, 1, true) then
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

    self.__updatePresetOptions = updatePresetOptions

    self.saveInput.OnChange = function (sel)
        local saveInputText = sel.Text
        if saveInputText ~= "" and sel.EnterReturnsTrue then
            self.saveButton:OnClick()
            return
        end

        if saveInputText == "" then
            self.saveButton.Disabled = true
        else
            self.saveButton.Disabled = false
        end

        updatePresetOptions(saveInputText)
    end

    self.__updatePresetOptions("")

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
                    self.__updatePresetOptions("")
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
    warningImage:Tooltip():AddText(GetLoca("If 'Reset All' doesn't work, reload a save."))

    resetAllButton.OnClick = function(_)
        local isChara = EntityHelpers.IsCharacter(self.guid)

        for key, matTab in pairs(self.Materials) do
            matTab.Editor:ClearParameters()
            matTab.Editor:ResetAll()
            matTab:UpdateUIState()
        end

        if isChara then
            NetChannel.Replicate:SendToServer({
                Guid = self.guid,
                Field = "GameObjectVisual",
            })
        end

        if not isChara then
            self.EntityEffectTab:ResetAllEffects()
        end
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

    self.attachmentsHeader.OnHoverEnter = function()
        self:RenderAttachmentEditors()
        self.attachmentsHeader.OnHoverEnter = nil
    end
end

function VisualTab:RenderAttachmentEditors()
    local visual = self:GetVisual(self.guid)

    if not visual then return end

    local attachments = visual.Attachments or {}

    for attIndex, attach in ipairs(attachments) do
        if #attach.Visual.ObjectDescs == 0 then goto continue end
        local vres = attach.Visual.VisualResource
        if not vres then goto continue end
        local initVresId = vres.Guid
        local source = vres and vres.SourceFile or "Unknown Model"
        local gr2FileName = RBStringUtils.GetLastPath(source)

        local displayName = vres.Slot

        if displayName == "" or displayName == "Unassigned" then
            displayName = gr2FileName
        end

        local attachNode = ImguiElements.AddTree(self.attachmentsHeader, displayName .. "##" .. tostring(attIndex), false)
        attachNode:AddTreeIcon(RB_ICONS.Box, IMAGESIZE.ROW).Tint = ColorUtils.HexToRGBA("FFB98634")

        attachNode.OnRightClick = function()
            if IsInCharacterCreationMirror() then return end
            local liveAttachment = VisualHelpers.GetAttachment(self.guid, attIndex)
            if not liveAttachment then return end
            local descCnt = #liveAttachment.Visual.ObjectDescs
            if descCnt == 0 then return end

            local initFuncs = {} --[[@as (fun():RenderableObject)[] ]]
            for descIndex = 1, descCnt do
                local renderableFunc = function()
                    local liveAttach = VisualHelpers.GetAttachment(self.guid, attIndex)
                    if not liveAttach then return nil end
                    local desc = liveAttach.Visual.ObjectDescs[descIndex]
                    if not desc or not desc.Renderable then return nil end
                    return desc.Renderable
                end
                initFuncs[descIndex] = renderableFunc
            end
            local proxies = {}
            for descIndex, func in pairs(initFuncs) do
                local proxy = RenderableMovableProxy.new(func)
                table.insert(proxies, proxy)
            end
            RB_GLOBALS.TransformEditor:Select(proxies)
        end

        local gr2Text = attachNode:AddHint("Model: " .. gr2FileName)
        gr2Text:SetColor("Text", ColorUtils.HexToRGBA("FF6D6D6D"))
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

            local objNode = parentNode:AddTree(modelName .. "##" .. tostring(attIndex) .. "::" .. tostring(descIndex),
                false)
            objNode:AddTreeIcon(RB_ICONS.Bounding_Box, IMAGESIZE.ROW).Tint = ColorUtils.HexToRGBA("FF27B040")

            local matName = obj.Renderable.ActiveMaterial.Material.Name
            local function getliveMat()
                local visual = self:GetVisual(self.guid)
                if not visual then return nil end

                local attach = visual.Attachments[attIndex]

                if not attach then return nil end

                local attachVisual = attach.Visual
                if not attachVisual then return nil end

                local vres = attachVisual.VisualResource
                if not vres then return nil end

                local vresId = vres.Guid

                if vresId ~= initVresId then
                    return nil
                end

                local desc = attachVisual.ObjectDescs[descIndex]
                if not desc or not desc.Renderable then return nil end

                return desc.Renderable.ActiveMaterial
            end

            --- @return MaterialParameters|nil
            local function getliveParams()
                local mat = getliveMat()
                if not mat then return nil end
                return mat.Material.Parameters
            end

            local keyName = initVresId .. "::" .. tostring(attIndex) .. "::" .. tostring(descIndex)

            local materialTab = self.Materials[keyName] or
                MaterialTab.new(objNode, matName, getliveMat, getliveParams) --[[@as MaterialTab]]
            materialTab.Parent = objNode
            materialTab.Editor.Instance = getliveMat
            materialTab.Editor.ParamsSrc = getliveParams
            materialTab.Editor.ParamSet:Update(getliveParams())

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
    if next(RBUtils.LightCToArray(self:GetEntity(self.guid).Visual.Visual.ObjectDescs)) == nil then
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

    self.materialHeader.OnHoverEnter = function()
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
        local linkId = renderable.Model and renderable.Model.LinkId or -1
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
        materialNode:AddTreeIcon(RB_ICONS.Bounding_Box, IMAGESIZE.ROW).Tint = ColorUtils.HexToRGBA("FF268B39")

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

        local keyName = linkId .. "::" .. tostring(descIndex)
        local materialEditor = self.Materials[keyName] or
            MaterialTab.new(materialNode, material.MaterialName, getliveMat, getliveParams) --[[@as MaterialTab]]
        materialEditor.LinkId = linkId
        materialEditor.Parent = materialNode
        materialEditor.Editor.Instance = getliveMat
        materialEditor.Editor.ParamsSrc = getliveParams
        materialEditor.Editor.ParamSet:Update(getliveParams())

        materialNode.OnRightClick = function()
            materialNode:OnExpand()
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

function VisualTab:Add(guid, displayName, parent, templateName)
    if not EntityHelpers.EntityExists(guid) then
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
--- @field Effects RB_EffectsTable
--- @field Materials table<string, RB_ParameterSet> -- key <name :: attachIndex(if any) :: descIndex> -> RB_ParameterSet
--- @field Transforms table<string, Transform> -- key <name :: attachIndex(if any) :: descIndex> -> Transform

--- @return RB_VisualPreset
function VisualTab:SaveCurrentState()
    local effects = self.EntityEffectTab.Effects
    local presetData = {
        Materials = {},
        Effects = RBUtils.DeepCopy(effects),
    }

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

        local currentScale = { VisualHelpers.GetRenderableScale(self.guid, objStart.DescIndex, objStart.AttachIndex) }
        if RBTableUtils.EqualArrays(currentScale, objStart.Scale) == false then
            localTransforms[key] = {
                Scale = currentScale
            }
        end

        ::continue::
    end

    presetData.Materials = Mats
    presetData.Transforms = localTransforms

    return presetData
end

function VisualTab:Save(name, overwrite)
    local templateName = self.templateName or RBGetTemplateNameForGuid(self.guid)

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

    local filePath = FilePath.GetVisualPresetsPath(templateName)
    local oriFile = Ext.Json.Parse(Ext.IO.LoadFile(filePath) or "{}")

    local currentPresetData = self:SaveCurrentState()

    oriFile[saveName] = {
        Name = saveName,
        TemplateName = templateName,
        Effects = currentPresetData.Effects,
        Materials = currentPresetData.Materials,
        Transforms = currentPresetData.Transforms,
    }

    local ok, err = Ext.IO.SaveFile(filePath, Ext.Json.Stringify(oriFile))
    if not ok then
        Error("Failed to save VisualTab data: " .. err)
        return false
    end

    local refFilePath = FilePath.GetVisualReferencePath()
    local refFile = Ext.Json.Parse(Ext.IO.LoadFile(refFilePath) or "{}")

    refFile[templateName] = refFile[templateName] or {}

    local refOk = Ext.IO.SaveFile(refFilePath, Ext.Json.Stringify(refFile))
    if not refOk then
        Error("Failed to save VisualTab reference data: " .. err)
    end

    --Info("Saved VisualTab preset as '" .. saveName .. "' for template: " .. templateId)
    self.currentPreset = saveName
    self.savedPresets[saveName] = RBUtils.DeepCopy(oriFile[saveName])
    if EntityHelpers.IsPartyMember(self.guid) then

    else
        EntityStore[self.guid].VisualPreset = saveName
    end
    self:Load()

    --Info("VisualTab:Save - Preset '" .. saveName .. "' saved successfully for template: " .. templateName)
    return true
end

function VisualTab:ExportPreset()
    local effects = self.EntityEffectTab.Effects
    local presetData = {
        Materials = {},
        Effects = RBUtils.DeepCopy(effects),
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
        local currentScale = { VisualHelpers.GetRenderableScale(self.guid, objStart.DescIndex, objStart.AttachIndex) }
        if RBTableUtils.EqualArrays(currentScale, objStart.Scale) == false then
            presetData.Transforms[key] = {
                Scale = currentScale
            }
        end
    end

    return presetData
end

function VisualTab:Load(notoverwrite)
    local templateName = self.templateName or RBGetTemplateNameForGuid(self.guid)

    if not templateName then
        Error("VisualTab:Load - No template name found for GUID: " .. self.guid)
        return false
    end

    local filePath = FilePath.GetVisualPresetsPath(templateName)
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

    if self.__updatePresetOptions then
        self.__updatePresetOptions("")
    end

    local refFilePath = FilePath.GetVisualReferencePath()
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
    local templateName = self.templateName or RBGetTemplateNameForGuid(self.guid)

    if not templateName then
        Error("VisualTab:Remove - No template name found for GUID: " .. self.guid)
        return false
    end

    local filePath = FilePath.GetVisualPresetsPath(templateName)

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
        local refFilePath = FilePath.GetVisualReferencePath()
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

    self.EntityEffectTab:ResetAllEffects()

    VisualHelpers.ApplyVisualParams(self.guid, preset)
    self.currentPreset = name
    self.Effects = RBUtils.DeepCopy(preset.Effects) or {}
    self.EntityEffectTab:UpdateEffectsTableReference(self.Effects)
    self.LocalTransforms = RBUtils.DeepCopy(preset.Transforms) or {}

    for key, matParams in pairs(preset.Materials or {}) do
        if self.Materials[key] then
            self.Materials[key].Editor:ApplyParameters(matParams)
            self.Materials[key]:UpdateUIState()
        end
    end

    if self.loadCombo then
        ImguiHelpers.SetCombo(self.loadCombo, name)
    end

    if EntityHelpers.IsPartyMember(self.guid) then

    else
        EntityStore[self.guid].VisualPreset = name
    end

    self.EntityEffectTab:UpdateAllEffects()
end

--- @return string[]
function VisualTab:_getAllPresetNames()
    if not self.savedPresets then
        return {}
    end

    local names = {}
    for name, entry in pairs(self.savedPresets) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function VisualTab:Collapsed()
    if not self.isValid or not self.isVisible then
        return
    end
    
    self.__updatePresetOptions = nil

    self.EntityEffectTab:Collapsed()

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
            WindowManager.DeleteWindow(self.panel)
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

--- @alias RB_ObjectEdit table<string, RB_ParameterSet> linkId -> parameter set

--- @return RB_ObjectEdit?
function VisualTab:ExportObjectEdit()
    local objEdit = {}

    for key, mat in RBUtils.FilteredPairs(self.Materials, function(k, v)
        return v.LinkId and v:HasChanges()
    end) do
        objEdit[mat.LinkId] = mat:ExportChanges()
    end

    if not next(objEdit) then
        return nil
    end

    return objEdit
end

function VisualTab:OnDetach() end

function VisualTab:OnAttach() end

function VisualTab:OnChange() end
