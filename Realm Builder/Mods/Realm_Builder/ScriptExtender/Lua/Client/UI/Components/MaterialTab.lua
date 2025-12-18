--- @class MaterialTab
--- @field Parent ExtuiTreeParent
--- @field Editor MaterialEditor
--- @field Panel ExtuiTreeParent
--- @field ResetFuncs table<string, fun()>
--- @field UpdateFuncs table<string, fun(newValue: number|number[]|string?)>
--- @field ParamNodeRefs table<string, ExtuiSelectable>
--- @field MaterialName string
--- @field new fun(parent: ExtuiTreeParent, materialName: string, materialFunc:fun():Material , paramsSrc: fun():MaterialParameters):MaterialTab
MaterialTab = _Class("MaterialEditor")


--- @class MaterialDropData
--- @field MaterialProxy MaterialProxy|MaterialEditor|MaterialPresetProxy
--- @field PresetProxy MaterialPresetProxy
--- @field SuccessApply boolean

---@param parent ExtuiTreeParent
---@param materialName string
---@param materialFunc fun():Material
---@param paramsSrc fun():MaterialParameters
function MaterialTab:__init(parent, materialName, materialFunc, paramsSrc)
    self.Parent = parent
    self.Editor = MaterialEditor.new(materialName, materialFunc, paramsSrc)
    self.MaterialName = materialName
    self.SourceFile = self.Editor.SourceFile
    self.ParentNodeName = RBStringUtils.GetLastPath(self.SourceFile) or "N/A"

    self.ResetFuncs = {}
    self.UpdateFuncs = {}
    self.ParamNodeRefs = {}
    self.ParamTypeNodeRefs = {}
end

--- @param parent ExtuiTreeParent?
--- @return RB_UI_Tree
function MaterialTab:Render(parent)
    local sourceFileName = self.ParentNodeName
    parent = parent or self.Parent
    local parentNode = ImguiElements.AddTree(self.Parent, sourceFileName, false)
    parentNode:AddTreeIcon(RB_ICONS.Mask, IMAGESIZE.ROW).Tint = ColorUtils.HexToRGBA("FFAC3232")
    parentNode.AllowItemOverlap = true
    self.ParentNode = parentNode
    self.Panel = parentNode.Panel

    parentNode.CanDrag = true
    parentNode.DragDropType = MATERIALPRESET_DRAGDROP_TYPE

    parentNode.UserData = {
        MaterialProxy = self.Editor,
        Parameters = self.Editor and self.Editor.Parameters or nil
    }

    parentNode.OnDragStart = function(sel)
        sel.DragPreview:AddImage(RB_ICONS.Mask, IMAGESIZE.ROW).Tint = ColorUtils.HexToRGBA("FFAC3232")
        sel.DragPreview:AddText(sourceFileName).SameLine = true
    end

    parentNode.OnDragDrop = function(sel, drop)
        sel.UserData.PresetProxy = self.Editor.PresetProxy --[[@as MaterialPresetProxy ]]
        if drop.UserData and drop.UserData.Parameters then
            local params = drop.UserData.Parameters

            drop.UserData.SuccessApply = true
            self:ApplyParameters(params)
            self:UpdateUIState()
        end
        if drop.UserData and drop.UserData.ParameterName then
            local paramName = drop.UserData.ParameterName --[[@as string ]]
            local newValue = drop.UserData.ParameterValue --[[@as number[] ]]

            self:SetParameter(paramName, newValue)
        end
    end

    local params = self:GetAllParameterNames()

    local indexToDisplay = {
        [1] = "Scalar Parameters",
        [2] = "Vector2 Parameters",
        [3] = "Vector3 Parameters",
        [4] = "Vector4 Parameters",
        [5] = "Texture2D Parameters",
        [6] = "Virtual Texture Parameters",
    }

    self.cachedExpandedState = self.cachedExpandedState or {}
    self.ParamTypeNodeRefs = {}
    self.ParamNodeRefs = {}
    self.UpdateFuncs = {}
    self.ResetFuncs = {}
    self.ParamTableRefs = {}
    local searchBar = parentNode:AddInputText("####" .. self.MaterialName .. "Global")
    searchBar.IDContext = "MaterialParamSearchBox" .. self.MaterialName .. "Global" .. tostring(math.random())
    searchBar.Hint = "Search parameters..."
    searchBar.OnChange = function(sel)
        if sel.Text == "" then
            for _, node in pairs(self.ParamTableRefs) do
                node.Visible = true
            end
            return
        end

        local searchTerm = sel.Text:lower()
        for paramName, cell in pairs(self.ParamTableRefs) do
            if paramName:lower():find(searchTerm) then
                cell.Visible = true
            else
                cell.Visible = false
            end
        end
    end

    for paramType, propNames in ipairs(params) do
        local propType = indexToDisplay[paramType]
        if #propNames < 1 then goto continue end
        local typeNode = parentNode:AddTree(propType .. "##" .. self.MaterialName,
            self.cachedExpandedState[paramType] == true) --[[@as ExtuiSelectable ]]
        local paramsGroup = typeNode:AddGroup("AllPropertiesGroup##" .. self.MaterialName .. tostring(math.random()))

        self.ParamTypeNodeRefs[paramType] = typeNode
        local allParamNode = {}
        local paramTable = paramsGroup:AddTable("ParameterTable##" .. self.MaterialName .. propType, 1)
        local paramRow = paramTable:AddRow()
        paramTable.BordersOuter = true
        paramTable.RowBg = true

        typeNode.OnCollapse = function()
            self.cachedExpandedState[paramType] = false
        end

        typeNode.DragDropType = MATERIALPRESET_DRAGDROP_TYPE
        typeNode.CanDrag = true
        typeNode.OnDragStart = function(sel)
            sel.DragPreview:AddText(propType)
            local allParamNames = self:GetAllParameterNames()[paramType]
            local udParams = {}
            for i = 1, paramType do
                udParams[i] = {}
            end
            for _, paramName in pairs(allParamNames) do
                local value = self:GetParameter(paramName) --[[@as number[] ]]
                if value then
                    udParams[paramType][paramName] = value
                end
            end
            sel.UserData.ParameterName = nil
            sel.UserData.ParameterValue = nil
            sel.UserData.Parameters = udParams
        end

        typeNode.OnDragDrop = function(sel, drop)
            if drop.UserData and drop.UserData.Parameters then
                local udParams = RBUtils.DeepCopy(drop.UserData.Parameters)

                for i = 1, 6 do
                    if i ~= paramType then
                        udParams[i] = {}
                    end
                end

                drop.UserData.SuccessApply = true
                self:ApplyParameters(udParams)
            end
            if drop.UserData and drop.UserData.ParameterName then
                local paramName = drop.UserData.ParameterName --[[@as string ]]
                local newValue = drop.UserData.ParameterValue --[[@as number[] ]]

                self:SetParameter(paramName, newValue)
            end
        end

        local function renderParamTable()
            for _, propertyName in ipairs(propNames) do
                local rowCell = paramRow:AddCell()
                local tab = rowCell:AddTable("PropertyTable##" .. self.MaterialName .. propertyName, 3)
                tab.ColumnDefs[1] = { WidthFixed = true }
                tab.ColumnDefs[2] = { WidthStretch = true }
                tab.ColumnDefs[3] = { WidthFixed = true }
                local row = tab:AddRow()
                local propCell = row:AddCell()
                local propNode = propCell:AddSelectable(propertyName .. "##" .. self.MaterialName) --[[@as ExtuiSelectable ]]
                self.ParamNodeRefs[propertyName] = propNode
                self.ParamTableRefs[propertyName] = rowCell
                row:AddCell() -- Spacer
                local paramgroup = row:AddCell()
                paramgroup.SameLine = true

                propNode.OnClick = function(sel)
                    sel.Highlight = false
                    sel.Selected = false
                    self.ResetFuncs[propertyName]()
                    typeNode.Framed = self:HasChangeInType(paramType)
                end
                propNode.OnRightClick = propNode.OnClick

                propNode.OnHoverEnter = function()
                    local paramValue, ptype = self:GetParameter(propertyName)
                    if type(paramValue) == "string" then
                        self:RenderTextProperty(paramgroup, propertyName, paramValue, ptype, rowCell)
                    else
                        self:RenderNumberProperty(paramgroup, propertyName, paramValue, rowCell)
                    end
                    propNode.OnHoverEnter = function()
                        propNode.Selected = self:HasChanged(propertyName) and true or false
                        typeNode.Framed = self:HasChangeInType(paramType)
                    end
                end

                if paramgroup.Visible then
                    propNode.OnHoverEnter()
                end

                propNode.CanDrag = true
                propNode.DragDropType = MATERIALPRESET_DRAGDROP_TYPE

                propNode.OnDragStart = function(sel)
                    propNode.DragPreview:AddText(propertyName)

                    local value, ptype = self:GetParameter(propertyName) --[[@as number[] ]]
                    if not value then return end
                    propNode.UserData.ParameterName = propertyName
                    propNode.UserData.ParameterValue = value
                    propNode.UserData.ParameterType = ptype
                    if type(value) == "string" then
                        local displayName = indexToDisplay[paramType] or "Unknown"
                        propNode.DragPreview:AddText(displayName .. " : " .. value)
                        return
                    elseif type(value) == "number" then
                        value = { value }
                    end

            
                    if #value >= 3 then
                        local colorRect = propNode.DragPreview:AddColorEdit("##" .. self.MaterialName .. propertyName)
                        colorRect.Color = { value[1], value[2], value[3], value[4] or 1 }
                    else
                        for i = 1, #value do
                            value[i] = RBStringUtils.FormatDecimal(value[i], 2)
                        end
                        propNode.DragPreview:AddText("Value: " .. table.concat(value, ", "))
                    end
                end

                propNode.OnDragDrop = function(sel, drop)
                    if drop.UserData and drop.UserData.ParameterValue then
                        local newValue = drop.UserData.ParameterValue --[[@as number[] ]]
                        local vType = drop.UserData.ParameterType --[[@as RB_MaterialParamType ]]
                        local currentValue, cType = self:GetParameter(propertyName)
                        if newValue and currentValue then
                            if not cType or vType ~= cType then
                                return
                            end
                        else
                            return -- Invalid parameters
                        end

                        self:SetParameter(propertyName, newValue, vType)

                        local updateFunc = self.UpdateFuncs[propertyName]
                        if updateFunc then
                            updateFunc(newValue)
                        end
                    end
                end

                allParamNode[propertyName] = propNode

                propNode.UserData = {
                    ParameterName = propertyName,
                    OnDestroy = function()
                        allParamNode[propertyName] = nil
                        self.ParamNodeRefs[propertyName] = nil
                        self.UpdateFuncs[propertyName] = nil
                        self.ResetFuncs[propertyName] = nil
                        self.ParamTableRefs[propertyName] = nil
                    end
                }
            end
        end

        typeNode.OnExpand = function()
            renderParamTable()
            renderParamTable = function() end
            for _, node in pairs(allParamNode) do
                node:OnHoverEnter()
            end
            self.cachedExpandedState[paramType] = true
        end

        if self.cachedExpandedState[paramType] == true then
            typeNode:OnExpand()
        end

        ::continue::
    end

    return parentNode
end

function MaterialTab:ClearRefs()
    self.ParamNodeRefs = {}
    self.ParamTypeNodeRefs = {}
    self.UpdateFuncs = {}
    self.ResetFuncs = {}
    self.ParamTableRefs = {}
end

--- @param node ExtuiTreeParent
--- @param propertyName string
--- @param vecValue number|number[]
function MaterialTab:RenderNumberProperty(node, propertyName, vecValue)
    local sliders = {} --[[@type ExtuiSliderScalar[] ]]
    local colorPicker = nil
    if type(vecValue) == "number" then
        vecValue = { vecValue }
    end

    local paramType = #vecValue
    if paramType >= 3 then
        colorPicker = node:AddColorEdit("##" .. self.MaterialName .. propertyName)
        local resetButton = ImguiElements.AddResetButton(node, true)
        resetButton.OnClick = function(sel)
            self:ResetValue(propertyName)

            local newValue = self:GetParameter(propertyName)
            if newValue then
                colorPicker.Color = RBUtils.ToVec4(newValue)
                for i = 1, #newValue do
                    if sliders[i] then
                        sliders[i].Value = { newValue[i], 0, 0, 0 }
                    end
                end
            end

            self:UpdateParamState(propertyName, paramType)
        end
        colorPicker.Color = RBUtils.ToVec4(vecValue)
        colorPicker.AlphaBar = (paramType == 4)
        colorPicker.NoAlpha = (paramType == 3)
        colorPicker.NoInputs = true
        colorPicker.ItemWidth = 400 * SCALE_FACTOR
        colorPicker.OnChange = function(sel)
            local newValue = { sel.Color[1], sel.Color[2], sel.Color[3], sel.Color[4] } --[[@as number[] ]]

            for j = paramType + 1, 4 do
                newValue[j] = nil
            end

            for i = 1, #sliders do
                sliders[i].Value = { newValue[i], 0, 0, 0 }
            end

            self:SetParameter(propertyName, newValue)

            self:UpdateParamState(propertyName, paramType)
        end
        colorPicker.OnRightClick = function(sel)
            for i = 1, paramType do
                if sliders[i] then
                    sliders[i].Visible = not sliders[i].Visible
                end
            end
        end
    end

    local range = { min = -100, max = 100, step = 0.1 }
    for i = 1, paramType do
        local isIndex = propertyName:find("Index") ~= nil
        if isIndex then
            range.min = 0
            range.step = 1
        else
            range.min = -100
            range.max = 100
            range.step = 0.1
        end
        local slider = ImguiElements.AddSliderWithStep(node, propertyName .. "##" .. self.MaterialName .. i,
            vecValue[i], range.min, range.max, range.step, isIndex)
        slider.ItemWidth = 400 * SCALE_FACTOR
        

        if colorPicker then
            slider.Visible = false
            slider.HideResetButton = true
        end
        slider.OnChange = function(sel)
            local newValue = { sliders[1].Value[1] }
            for j = 2, #vecValue do
                newValue[j] = sliders[j].Value[1]
            end
            for j = #vecValue + 1, 4 do
                newValue[j] = nil
            end

            if colorPicker then
                colorPicker.Color = RBUtils.ToVec4(newValue)
            end

            local applyValue = #vecValue == 1 and newValue[1] or newValue
            self:SetParameter(propertyName, applyValue, #vecValue, true)

            self:UpdateParamState(propertyName, paramType)
        end

        sliders[i] = slider
    end

    local function reset()
        self:ResetValue(propertyName)

        local newValue = self:GetParameter(propertyName)
        if newValue then
            if type(newValue) == "number" then
                newValue = { newValue }
            end
            for i = 1, #newValue do
                if sliders[i] then
                    sliders[i].Value = { newValue[i], newValue[i], newValue[i], newValue[i] }
                end
            end
            if colorPicker then
                colorPicker.Color = RBUtils.ToVec4(newValue)
            end
        end

        self:UpdateParamState(propertyName, paramType)
    end

    local function updateSliders(newValue)
        if newValue then
            if type(newValue) == "number" then
                newValue = { newValue }
            end
            for i = 1, #vecValue do
                if sliders[i] then
                    sliders[i].Value = { newValue[i], newValue[i], newValue[i], newValue[i] }
                end
            end
            if colorPicker then
                colorPicker.Color = RBUtils.ToVec4(newValue)
            end
        end

        self:UpdateParamState(propertyName, paramType)
    end

    self.ResetFuncs[propertyName] = reset
    self.UpdateFuncs[propertyName] = updateSliders

    return sliders, colorPicker
end

--- @param node ExtuiTreeParent
function MaterialTab:RenderTextProperty(node, propertyName, propertyValue, propertyType)
    if propertyType ~= RB_MaterialParamType.Texture2D and propertyType ~= RB_MaterialParamType.VirtualTexture then
        Warning("MaterialTab:RenderTextProperty called for unsupported property type '" ..
            tostring(propertyType) .. "' for property '" .. tostring(propertyName) .. "'.")
        return
    end
    local textBox = node:AddInputText("##" .. self.MaterialName .. propertyName)
    textBox.Text = propertyValue
    textBox.ItemWidth = 600 * SCALE_FACTOR
    textBox.AutoSelectAll = true

    textBox.OnRightClick = function()
        local res = Ext.Resource.Get(propertyValue, "Texture") --[[@as ResourceTextureResource]]
        if not res then
            textBox.OnRightClick = nil
            return
        end

        local editSourceFilePopup = ImguiElements.AddTexturePopup(node, function()
            return self:GetParameter(propertyName)
        end, function(newValue)
            self:SetParameter(propertyName, newValue, propertyType)
            textBox.Text = newValue
        end)
        editSourceFilePopup:Open()
        textBox.OnRightClick = function()
            editSourceFilePopup:Open()
        end
    end

    local resetButton = ImguiElements.AddResetButton(node, true)
    resetButton.OnClick = function(sel)
        self:ResetValue(propertyName)
        local newValue = self:GetParameter(propertyName)
        if newValue and type(newValue) == "string" then
            textBox.Text = newValue
        end

        self:UpdateParamState(propertyName, propertyType)
    end
    textBox.OnChange = function(sel)
        local newValue = sel.Text
        if not RBUtils.IsUuidIncludingNull(newValue) then return end
        local check = false
        local isVT = propertyType == RB_MaterialParamType.VirtualTexture
        if not isVT and propertyType == RB_MaterialParamType.Texture2D then
            check = TextureResourceManager:HasTextureResource(newValue)
        elseif isVT then
            check = TextureResourceManager:HasVirtualTextureResource(newValue)
        end
        if not check then
            if not isVT then
                Info("No Texture Resource found with UUID: " .. tostring(newValue))
            else
                Info("No Virtual Texture Resource found with UUID: " .. tostring(newValue))
            end
            return
        end

        self:SetParameter(propertyName, newValue, propertyType)

        self:UpdateParamState(propertyName, propertyType)
    end

    self.UpdateFuncs[propertyName] = function(newValue)
        if newValue and type(newValue) == "string" then
            textBox.Text = newValue
        end

        self:UpdateParamState(propertyName, propertyType)
    end
    self.ResetFuncs[propertyName] = function()
        self:ResetValue(propertyName)
        local newValue = self:GetParameter(propertyName)
        if newValue and type(newValue) == "string" then
            textBox.Text = newValue
        end

        self:UpdateParamState(propertyName, propertyType)
    end

    return textBox
end

function MaterialTab:ResetAll()
    self.Editor.PresetProxy = nil
    self.Editor.Parameters = {
        [1] = {},
        [2] = {},
        [3] = {},
        [4] = {},
        [5] = {},
        [6] = {},
    }
    self.Editor:ResetAll()

    self:UpdateUIState()
end

function MaterialTab:ResetValue(name)
    self.Editor:ResetParameter(name)
    if self.UpdateFuncs[name] then
        local newValue = self:GetParameter(name)
        self.UpdateFuncs[name](newValue)
    end
end

function MaterialTab:UpdateUIState()
    for key, updateFunc in pairs(self.UpdateFuncs) do
        local newValue = self:GetParameter(key)
        updateFunc(newValue)
    end

    for key, propNode in pairs(self.ParamNodeRefs) do
        propNode.Selected = self:HasChanged(key) and true or false
    end

    for paramType, typeNode in pairs(self.ParamTypeNodeRefs) do
        typeNode.Framed = self:HasChangeInType(paramType)
    end
end

function MaterialTab:UpdateParamState(name, paramType)
    if self.ParamNodeRefs[name] then
        self.ParamNodeRefs[name].Selected = self:HasChanged(name) and true or false
    end

    if self.ParamTypeNodeRefs[paramType] then
        self.ParamTypeNodeRefs[paramType].Framed = self:HasChangeInType(paramType)
    end

end

function MaterialTab:HasChanges()
    for key, _ in pairs(self.ParamNodeRefs) do
        if self:HasChanged(key) then
            return true
        end
    end

    return false
end

function MaterialTab:BuildMaterialResourceNode(uuid, internalName)
    local saveNode = LSXHelpers.BuildMaterialResource()
    local materialNode = ResourceHelpers.BuildMaterialResourceNode(self.Editor.Parameters, self.Editor.Material, uuid,
        internalName)
    saveNode:AppendChild(materialNode)

    return saveNode
end

function MaterialTab:BuildMaterialPresetResourceNode(uuid, internalName)
    local saveNode = LSXHelpers.BuildMaterialPresetBank()
    local presetNode = ResourceHelpers.BuildMaterialPresetResourceNode(self.Editor.Parameters, uuid, internalName)
    saveNode:AppendChild(presetNode)

    return saveNode
end

function MaterialTab:ExportChanges()
    return RBUtils.DeepCopy(self.Editor.Parameters)
end

function MaterialTab:ImportChanges(params)
    self.Editor:ApplyParameters(params)

    for key, func in pairs(self.UpdateFuncs) do
        local newValue = self.Editor:GetParameter(key)
        func(newValue)
    end
end

function MaterialTab:GetParameter(name)
    return self.Editor:GetParameter(name)
end

function MaterialTab:SetParameter(name, value, ptype, dontUpdate)
    self.Editor:SetParameter(name, value, ptype)
    if dontUpdate or not self.UpdateFuncs[name] then return end
    self.UpdateFuncs[name](value)
end

function MaterialTab:ResetParameter(name)
    self.Editor:ResetParameter(name)
    if self.UpdateFuncs[name] then
        local newValue = self:GetParameter(name)
        self.UpdateFuncs[name](newValue)
    end
end

function MaterialTab:ApplyParameters(params)
    self.Editor:ApplyParameters(params)
    self:UpdateUIState()
end

function MaterialTab:GetAllParameterNames()
    return {
        [1] = self.Editor.ParamSet:GetAllScalarParameterNames(),
        [2] = self.Editor.ParamSet:GetAllVector2ParameterNames(),
        [3] = self.Editor.ParamSet:GetAllVector3ParameterNames(),
        [4] = self.Editor.ParamSet:GetAllVector4ParameterNames(),
        [5] = self.Editor.ParamSet:GetAllTexture2DParameterNames(),
        [6] = self.Editor.ParamSet:GetAllVirtualTextureParameterNames(),
    }
end

function MaterialTab:HasChanged(name)
    return self.Editor:HasChanged(name)
end

function MaterialTab:HasChangeInType(paramType)
    return self.Editor:HasChangeInType(paramType)
end

function MaterialTab:SavePreset()
    MaterialPresetsMenu:SaveMaterialPreset(self.Editor)
end

function MaterialTab:SetPreset(presetProxy)
    self.Editor.PresetProxy = presetProxy
    self:UpdateUIState()
end

--- @class MaterialMixerTab : MaterialTab
--- @field ParametersSetProxy ParametersSetProxy
--- @field new fun(parameters: RB_ParameterSet):MaterialMixerTab
MaterialMixerTab = _Class("MaterialMixerTab", MaterialTab)

function MaterialMixerTab:__init(parameters)
    self.Label = RBUtils.Uuid_v4()
    self.Parent = WindowManager.RegisterWindow(self.Label, "Material Mixer", "Material Mixer Tab", self)
    self.Parent.Closeable = true

    self.Parent.OnClose = function(win)
        WindowManager.DeleteWindow(self.Parent)
    end

    self.MaterialName = "MaterialMixerEditor"
    self.ParentNodeName = "Material Mixer"


    RainbowDumpTable(parameters)

    self.ParametersSetProxy = ParametersSetProxy.BuildFromFormatParameters(parameters)

    self.ResetFuncs = {}
    self.UpdateFuncs = {}
end

function MaterialMixerTab:Render(parent)
    parent = parent or self.Parent
    if self.ParentNode then
        self.ParentNode:Destroy()
    end

    local parentNode = MaterialTab.Render(self, parent)

    parentNode.UserData = {
        MaterialProxy = self.ParametersSetProxy,
        Parameters = self.ParametersSetProxy.Parameters
    }
    parentNode.Label = "Material Mixer##" .. self.MaterialName

    parentNode:SetOpen(true)

    local managePopup = parent:AddPopup("Manage##" .. self.MaterialName)
    self.ContextMenu = managePopup
    self:SetupManagePopup(managePopup)

    parentNode.OnRightClick = function(sel)
        managePopup:Open()
    end

    parentNode.OnDragDrop = function(sel, drop)
        if drop.UserData and drop.UserData.Parameters then
            local params = drop.UserData.Parameters

            self:ApplyParameters(params)
            drop.UserData.SuccessApply = true
        end
        if drop.UserData and drop.UserData.ParameterName then
            local paramName = drop.UserData.ParameterName --[[@as string ]]
            local newValue = drop.UserData.ParameterValue --[[@as number[] ]]

            self:SetParameter(paramName, newValue)
        end
    end
end

function MaterialMixerTab:RenderNumberProperty(node, propertyName, propertyValue, propRow)
    MaterialTab.RenderNumberProperty(self, node, propertyName, propertyValue, propRow)

    local removeBtn = ImguiElements.AddMiddleAlignedImageButton(node, RB_ICONS.X_Square, true) --[[@as ExtuiImageButton ]]
    removeBtn.OnClick = function(sel)
        self.ParamNodeRefs[propertyName].UserData.OnDestroy()
        self.ParametersSetProxy:RemoveParameter(propertyName)
        propRow:Destroy()
        self:UpdateUIState()
    end
end

function MaterialMixerTab:RenderTextProperty(node, propertyName, propertyValue, propertyType, propRow)
    MaterialTab.RenderTextProperty(self, node, propertyName, propertyValue, propertyType)

    local removeBtn = ImguiElements.AddMiddleAlignedImageButton(node, RB_ICONS.X_Square, true) --[[@as ExtuiImageButton ]]
    removeBtn.OnClick = function(sel)
        self.ParamNodeRefs[propertyName].UserData.OnDestroy()
        self.ParametersSetProxy:RemoveParameter(propertyName)
        propRow:Destroy()
        self:UpdateUIState()
    end
end

function MaterialMixerTab:GetAllParameterNames()
    return {
        [1] = self.ParametersSetProxy:GetAllScalarParameterNames(),
        [2] = self.ParametersSetProxy:GetAllVector2ParameterNames(),
        [3] = self.ParametersSetProxy:GetAllVector3ParameterNames(),
        [4] = self.ParametersSetProxy:GetAllVector4ParameterNames(),
        [5] = self.ParametersSetProxy:GetAllTexture2DParameterNames(),
        [6] = self.ParametersSetProxy:GetAllVirtualTextureParameterNames(),
    }
end

function MaterialMixerTab:SetParameter(name, value)
    local ifRefresh = self.ParametersSetProxy:GetParameter(name) == nil

    self.ParametersSetProxy:SetParameter(name, value)

    if ifRefresh then
        self:Render()
    else
        self:UpdateUIState()
    end
end

function MaterialMixerTab:ResetValue(name)
    -- do nothing
end

function MaterialMixerTab:GetParameter(name)
    return self.ParametersSetProxy:GetParameter(name)
end

function MaterialMixerTab:HasChanged(name)
    --- material mixer will always return false since it is not based on a source material
    return false
end

function MaterialMixerTab:HasChangeInType(paramType)
    ---
    return false
end

function MaterialMixerTab:ResetParameter(name)
    self.ParametersSetProxy:ResetParameter(name)
    self:UpdateUIState()
end

function MaterialMixerTab:ResetAll()
    self.ParametersSetProxy:ResetAll()
    self:Render()
end

function MaterialMixerTab:ApplyParameters(params)
    for itype, typeParams in pairs(params) do
        for paramName, paramValue in pairs(typeParams) do
            self.ParametersSetProxy:SetParameter(paramName, paramValue)
        end
    end

    self:Render()
end

function MaterialMixerTab:SetPreset(presetProxy)
    self:UpdateUIState()
end

function MaterialMixerTab:SetupManagePopup(popup)
    local contextMenu = ImguiElements.AddContextMenu(popup)

    contextMenu:AddItem("Export As Preset##" .. self.MaterialName, function(sel)
        local save = LSXHelpers.BuildMaterialPresetBank()
        local uuid = RBUtils.Uuid_v4()
        local preset = ResourceHelpers.BuildMaterialPresetResourceNode(self.ParametersSetProxy.Parameters, uuid,
            "MaterialMixer_Preset")
        save:AppendChild(preset)
        local finalPath = "Realm_Builder/Materials/" .. uuid .. ".lsx"

        Ext.IO.SaveFile(finalPath, save:Stringify({ AutoFindRoot = true }))
    end)
end
