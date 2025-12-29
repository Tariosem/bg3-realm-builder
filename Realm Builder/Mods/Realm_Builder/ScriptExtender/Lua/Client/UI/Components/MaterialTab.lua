--- @class MaterialTab
--- @field Parent ExtuiTreeParent
--- @field Editor MaterialEditor
--- @field Panel ExtuiTreeParent
--- @field ResetFuncs table<string, fun()>
--- @field UpdateFuncs table<string, fun(newValue: number|number[]|string?)>
--- @field ParamTypeRoots table<RB_MaterialParamType, RB_UI_Tree>
--- @field ParamSelectables table<string, ExtuiSelectable>
--- @field ParamTables table<string, ExtuiTable>
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

    self.ParamSelectables = {}
    self.ParamTypeRoots = {}
end

local indexToDisplay = {
    [1] = "Scalar Parameters",
    [2] = "Vector2 Parameters",
    [3] = "Vector3 Parameters",
    [4] = "Vector4 Parameters",
    [5] = "Texture2D Parameters",
    [6] = "Virtual Texture Parameters",
}

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

    self.ExpandedState = self.ExpandedState or {}
    self.ParamTypeRoots = {}
    self.ParamSelectables = {}
    self.UpdateFuncs = {}
    self.ResetFuncs = {}
    self.ParamTables = {}
    local searchBar = parentNode:AddInputText("####" .. self.MaterialName .. "Global")
    searchBar.IDContext = "MaterialParamSearchBox" .. self.MaterialName .. "Global" .. tostring(math.random())
    searchBar.Hint = "Search parameters..."
    searchBar.OnChange = function(sel)
        if sel.Text == "" then
            for _, node in pairs(self.ParamTables) do
                node.Visible = true
            end
            for i, paramNode in pairs(self.ParamTypeRoots) do
                paramNode:SetOpen(self.ExpandedState[i] == true)
            end
            return
        end

        local searchTerm = sel.Text:lower()
        for ptype, propNames in pairs(params) do
            for _, propName in pairs(propNames) do
                local paramNode = self.ParamTypeRoots[ptype]
                local paramTable = self.ParamTables[propName]
                if propName:lower():find(searchTerm) then
                    local realState = self.ExpandedState[ptype] == true
                    paramNode:SetOpen(true)
                    self.ExpandedState[ptype] = realState

                    if not paramTable then
                        paramTable = self.ParamTables[propName] or {}
                    end

                    paramTable.Visible = true
                elseif paramTable then
                    paramTable.Visible = false
                end
            end
        end
    end

    for paramType, propNames in ipairs(params) do
        local propType = indexToDisplay[paramType]
        if #propNames < 1 then goto continue end
        local typeNode = parentNode:AddTree(propType .. "##" .. self.MaterialName,
            self.ExpandedState[paramType] == true)
        local paramsGroup = typeNode:AddGroup("AllPropertiesGroup##" .. self.MaterialName .. tostring(math.random()))

        self.ParamTypeRoots[paramType] = typeNode
        local allParamNode = {}
        local paramTable = paramsGroup:AddTable("ParameterTable##" .. self.MaterialName .. propType, 1)
        local paramRow = paramTable:AddRow()
        paramTable.BordersOuter = true
        paramTable.RowBg = true

        typeNode.OnCollapse = function()
            self.ExpandedState[paramType] = false
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

        local rendered = false
        typeNode.OnExpand = function()
            if not rendered then
                allParamNode = self:RenderParameterContent(propNames, paramType, paramRow)
                rendered = true
            end

            for _, node in pairs(allParamNode) do
                node:OnHoverEnter()
            end
            self.ExpandedState[paramType] = true
        end

        if self.ExpandedState[paramType] == true then
            typeNode:OnExpand()
        end

        ::continue::
    end

    return parentNode
end

function MaterialTab:RenderParameterContent(paramNames, paramType, paramRow)
    local allParamNode = {}
    local typeNode = self.ParamTypeRoots[paramType]
    for _, paramName in ipairs(paramNames) do
        local rowCell = paramRow:AddCell()
        local tab = rowCell:AddTable("PropertyTable##" .. self.MaterialName .. paramName, 3)
        tab.ColumnDefs[1] = { WidthFixed = true }
        tab.ColumnDefs[2] = { WidthStretch = true }
        tab.ColumnDefs[3] = { WidthFixed = true }
        local row = tab:AddRow()
        local propCell = row:AddCell()
        local propNode = propCell:AddSelectable(paramName .. "##" .. self.MaterialName) --[[@as ExtuiSelectable ]]
        self.ParamSelectables[paramName] = propNode
        self.ParamTables[paramName] = rowCell
        row:AddCell() -- Spacer
        local paramgroup = row:AddCell()
        paramgroup.SameLine = true

        propNode.OnClick = function(sel)
            sel.Highlight = false
            sel.Selected = false
            self.ResetFuncs[paramName]()
            typeNode.Framed = self:HasChangeInType(paramType)
        end
        propNode.OnRightClick = propNode.OnClick

        propNode.OnHoverEnter = function()
            local paramValue, ptype = self:GetParameter(paramName)
            if type(paramValue) == "string" then
                self:RenderTextProperty(paramgroup, paramName, paramValue, ptype, rowCell)
            else
                self:RenderNumberProperty(paramgroup, paramName, paramValue, rowCell)
            end
            propNode.OnHoverEnter = function()
                propNode.Selected = self:HasChanged(paramName) and true or false
                typeNode.Framed = self:HasChangeInType(paramType)
            end
        end

        if paramgroup.Visible then
            propNode.OnHoverEnter()
        end

        propNode.CanDrag = true
        propNode.DragDropType = MATERIALPRESET_DRAGDROP_TYPE

        propNode.OnDragStart = function(sel)
            propNode.DragPreview:AddText(paramName)

            local value, ptype = self:GetParameter(paramName) --[[@as number[] ]]
            if not value then return end
            propNode.UserData.ParameterName = paramName
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
                local colorRect = propNode.DragPreview:AddColorEdit("##" .. self.MaterialName .. paramName)
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
                local currentValue, cType = self:GetParameter(paramName)
                if newValue and currentValue then
                    if not cType or vType ~= cType then
                        return
                    end
                else
                    return -- Invalid parameters
                end

                self:SetParameter(paramName, newValue, vType)

                local updateFunc = self.UpdateFuncs[paramName]
                if updateFunc then
                    updateFunc(newValue)
                end
            end
        end

        allParamNode[paramName] = propNode

        propNode.UserData = {
            ParameterName = paramName,
            OnDestroy = function()
                allParamNode[paramName] = nil
                self.ParamSelectables[paramName] = nil
                self.UpdateFuncs[paramName] = nil
                self.ResetFuncs[paramName] = nil
                self.ParamTables[paramName] = nil
            end
        }
    end

    return allParamNode
end

function MaterialTab:ClearRefs()
    self.ParamSelectables = {}
    self.ParamTypeRoots = {}
    self.UpdateFuncs = {}
    self.ResetFuncs = {}
    self.ParamTables = {}
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
    if propertyType ~= MaterialEnums.MaterialParamType.Texture2D and propertyType ~= MaterialEnums.MaterialParamType.VirtualTexture then
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
        local isVT = propertyType == MaterialEnums.MaterialParamType.VirtualTexture
        if not isVT and propertyType == MaterialEnums.MaterialParamType.Texture2D then
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

    for key, propNode in pairs(self.ParamSelectables) do
        propNode.Selected = self:HasChanged(key) and true or false
    end

    for paramType, typeNode in pairs(self.ParamTypeRoots) do
        typeNode.Framed = self:HasChangeInType(paramType)
    end
end

function MaterialTab:UpdateParamState(name, paramType)
    if self.ParamSelectables[name] then
        self.ParamSelectables[name].Selected = self:HasChanged(name) and true or false
    end

    if self.ParamTypeRoots[paramType] then
        self.ParamTypeRoots[paramType].Framed = self:HasChangeInType(paramType)
    end
end

function MaterialTab:HasChanges()
    for key, _ in pairs(self.ParamSelectables) do
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

--- return a copy of current parameters
--- @return RB_ParameterSet
function MaterialTab:ExportChanges()
    return RBUtils.DeepCopy(self.Editor.Parameters)
end

--- @param params RB_ParameterSet
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

--- @param name string
--- @param value number|number[]|string?
--- @param ptype RB_MaterialParamType?
--- @param dontUpdate boolean?
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

--- @return table<RB_MaterialParamType, string[]>
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
--- @field InitState RB_ParameterSet
--- @field ContextMenu ExtuiPopup
--- @field UpdateFuncs table<string, fun(newValue: number|number[]|string?)>
--- @field ResetFuncs table<string, fun()>
--- @field new fun(parameters: RB_ParameterSet):MaterialMixerTab
MaterialMixerTab = _Class("MaterialMixerTab", MaterialTab)

--- @param parameters RB_ParameterSet
function MaterialMixerTab:__init(parameters)
    self.Label = RBUtils.Uuid_v4()
    self.Parent = WindowManager.RegisterWindow(self.Label, "Material Mixer", "Material Mixer Tab", self)
    self.Parent.Closeable = true

    self.Parent.OnClose = function(win)
        WindowManager.DeleteWindow(self.Parent)
    end

    self.MaterialName = "MaterialMixerEditor"
    self.ParentNodeName = "Material Mixer"

    --RainbowDumpTable(parameters)

    self.InitState = RBUtils.DeepCopy(parameters)
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

    local removeBtn = ImguiElements.AddImageButton(node, RB_ICONS.X_Square, true) --[[@as ExtuiImageButton ]]
    removeBtn.OnClick = function(sel)
        self.ParamSelectables[propertyName].UserData.OnDestroy()
        self.ParametersSetProxy:RemoveParameter(propertyName)
        propRow:Destroy()
        self:UpdateUIState()
    end
end

function MaterialMixerTab:RenderTextProperty(node, propertyName, propertyValue, propertyType, propRow)
    MaterialTab.RenderTextProperty(self, node, propertyName, propertyValue, propertyType)

    local removeBtn = ImguiElements.AddImageButton(node, RB_ICONS.X_Square, true) --[[@as ExtuiImageButton ]]
    removeBtn.OnClick = function(sel)
        self.ParamSelectables[propertyName].UserData.OnDestroy()
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
    local ptype = self.ParametersSetProxy:GetParameterType(name)
    local initValue = self.InitState[ptype][name]
    self.ParametersSetProxy:SetParameter(name, initValue)
    if self.UpdateFuncs[name] then
        local newValue = self:GetParameter(name)
        self.UpdateFuncs[name](newValue)
    end
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
    self.ParametersSetProxy = ParametersSetProxy.BuildFromFormatParameters(self.InitState)
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

    contextMenu:AddItem("Reset All##" .. self.MaterialName, function(sel)
        self:ResetAll()
    end)

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
