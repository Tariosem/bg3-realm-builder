--- @class MaterialTab
--- @field Parent ExtuiTreeParent
--- @field Editor MaterialEditor
--- @field Panel ExtuiTreeParent
--- @field ResetFuncs table<string, fun()>
--- @field UpdateFuncs table<string, fun(newValue: number[]?)>
--- @field ParamNodeRefs table<string, ExtuiSelectable>
--- @field MaterialName string
--- @field new fun(parent: ExtuiTreeParent, materialName: string, materialFunc:fun():Material , paramsSrc: fun():MaterialParametersSet):MaterialTab
MaterialTab = _Class("MaterialEditor")


--- @class MaterialDropData
--- @field MaterialProxy MaterialProxy|MaterialEditor|MaterialPresetProxy
--- @field PresetProxy MaterialPresetProxy
--- @field SuccessApply boolean

---@param parent ExtuiTreeParent
---@param materialName string
---@param materialFunc fun():Material
---@param paramsSrc fun():MaterialParametersSet
function MaterialTab:__init(parent, materialName, materialFunc, paramsSrc)
    self.Parent = parent
    self.Editor = MaterialEditor.new(materialName, materialFunc, paramsSrc)
    self.MaterialName = materialName
    self.SourceFile = self.Editor.SourceFile
    self.ParentNodeName = GetLastPath(self.SourceFile) or "N/A"

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
    local parentNode = StyleHelpers.AddTree(self.Parent, sourceFileName, false)
    parentNode:AddTreeIcon(RB_ICONS.Mask, IMAGESIZE.ROW).Tint = HexToRGBA("FFAC3232")
    parentNode.AllowItemOverlap = true
    self.ParentNode = parentNode
    self.Panel = parentNode.Panel

    parentNode.CanDrag = true
    parentNode.DragDropType = MATERIALPRESET_DRAGDROP_TYPE

    parentNode.UserData = {
        MaterialProxy = self.Editor,
        Parameters = self.Editor and self.Editor.Parameters or nil
    }

    parentNode.OnDragStart = function (sel)
        sel.DragPreview:AddImage(RB_ICONS.Mask, IMAGESIZE.ROW).Tint = HexToRGBA("FFAC3232")
        sel.DragPreview:AddText(sourceFileName).SameLine = true
    end

    parentNode.OnDragDrop = function (sel, drop)
        sel.UserData.PresetProxy = self.Editor.PresetProxy --[[@as MaterialPresetProxy ]]
        if drop.UserData and drop.UserData.Parameters then
            local params = drop.UserData.Parameters

            self:ApplyParameters(params)
            drop.UserData.SuccessApply = true
            self:UpdateUIState()
            if drop.UserData.PresetProxy then
                self:SetPreset(drop.UserData.PresetProxy)
            end
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
        [4] = "Vector4 Parameters"
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
    searchBar.OnChange = Debounce(50 ,function(sel)
        if sel.Text == "" then
            for _, node in pairs(self.ParamTableRefs) do
                node.Visible = true
            end
            return
        end

        local searchTerm = sel.Text:lower()
        for paramName,cell in pairs(self.ParamTableRefs) do
            if paramName:lower():find(searchTerm) then
                cell.Visible = true
            else
                cell.Visible = false
            end
        end
    end)
    for paramType,propNames in ipairs(params) do
        local propType = indexToDisplay[paramType]
        if #propNames < 1 then goto continue end
        local typeNode = parentNode:AddTree(propType .. "##" .. self.MaterialName, self.cachedExpandedState[paramType] == true) --[[@as ExtuiSelectable ]]
        local paramsGroup = typeNode:AddGroup("AllPropertiesGroup##" .. self.MaterialName .. tostring(math.random()))

        self.ParamTypeNodeRefs[paramType] = typeNode
        local allParamNode = {}
        local paramTable = paramsGroup:AddTable("ParameterTable##" .. self.MaterialName .. propType, 1)
        local paramRow = paramTable:AddRow()
        paramTable.BordersOuter = true
        paramTable.RowBg = true

        typeNode.OnExpand = function (isOpen)
            for _,node in pairs(allParamNode) do
                node:OnHoverEnter()
            end
            self.cachedExpandedState[paramType] = true
        end
        typeNode.OnCollapse = function ()
            self.cachedExpandedState[paramType] = false
        end

        for _,propertyName in ipairs(propNames) do
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
            local paramgroup = row:AddCell():AddGroup("PropertyGroup##" .. self.MaterialName .. propertyName .. tostring(math.random()))
            paramgroup.SameLine = true
            local sliders, colorPicker

            propNode.OnHoverEnter = function ()
                local paramValue = self:GetParameter(propertyName)
                sliders, colorPicker = self:RenderProperty(paramgroup, propertyName, paramValue, rowCell)
                propNode.OnHoverEnter = function()
                    propNode.Highlight = self:HasChanged(propertyName) and true or false
                    typeNode.Highlight = self:HasChangeInType(paramType)
                end
            end

            propNode.OnClick = function(sel)
                sel.Selected = false
                if colorPicker and sliders then
                    for _, slider in pairs(sliders) do
                        slider.Visible = not slider.Visible
                    end
                end
            end

            propNode.OnRightClick = function(sel)
                sel.Selected = false
                sel.Highlight = false
                self.Editor:ResetParameter(propertyName)
                self.UpdateFuncs[propertyName]()
            end

            if paramgroup.Visible then
                propNode.OnHoverEnter()
            end

            propNode.UserData = {
                MaterialProxy = self.Editor,
                ParameterName = propertyName
            }

            propNode.CanDrag = true
            propNode.DragDropType = MATERIALPRESET_DRAGDROP_TYPE

            propNode.OnDragStart = function (sel)
                propNode.DragPreview:AddText(propertyName)

                local value = self:GetParameter(propertyName) --[[@as number[] ]]
                if not value then return end
                propNode.UserData.ParameterValue = value
                if #value >= 3 then
                    local colorRect = propNode.DragPreview:AddColorEdit("##" .. self.MaterialName .. propertyName)
                    colorRect.Color = {value[1], value[2], value[3], value[4] or 1}
                else
                    for i=1, #value do
                        value[i] = FormatDecimal(value[i], 2)
                    end
                    propNode.DragPreview:AddText("Value: " .. table.concat(value, ", "))
                end
            end

            propNode.OnDragDrop = function (sel, drop)
                if drop.UserData and drop.UserData.ParameterValue then
                    local newValue = drop.UserData.ParameterValue --[[@as number[] ]]
                    local currentValue = self:GetParameter(propertyName)
                    if newValue and currentValue then
                        if not #newValue == #currentValue then
                            return
                        end
                    else
                        return -- Invalid parameters
                    end

                    self:SetParameter(propertyName, newValue)

                    local updateFunc = self.UpdateFuncs[propertyName]
                    if updateFunc then
                        updateFunc(newValue)
                    end
                end
            end

            allParamNode[propertyName] = propNode
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
--- @param propertyValue number[]
function MaterialTab:RenderProperty(node, propertyName, propertyValue)
    local sliders = {} --[[@type ExtuiSliderScalar[] ]]
    local colorPicker = nil
    if type(propertyValue) == "number" then
        propertyValue = { propertyValue }
    end

    if #propertyValue >= 3 then
        colorPicker = node:AddColorEdit("##" .. self.MaterialName .. propertyName)
        local resetButton = node:AddImageButton("Reset##" .. self.MaterialName .. propertyName, RB_ICONS.Arrow_CounterClockwise, IMAGESIZE.ROW)
        resetButton.SameLine = true
        resetButton.OnClick = function (sel)
            self:ResetValue(propertyName)

            local newValue = self:GetParameter(propertyName)
            if newValue then
                colorPicker.Color = ToVec4(newValue)
                for i=1, #newValue do
                    if sliders[i] then
                        sliders[i].Value = {newValue[i], 0, 0, 0}
                    end
                end
            end

            self.ParamNodeRefs[propertyName].Highlight = self:HasChanged(propertyName) and true or false
        end
        colorPicker.Color = ToVec4(propertyValue)
        colorPicker.AlphaBar = (#propertyValue == 4)
        colorPicker.NoAlpha = (#propertyValue == 3)
        colorPicker.NoInputs = true
        colorPicker.ItemWidth = 400 * SCALE_FACTOR
        colorPicker.OnChange = function (sel)
            local newValue = { sel.Color[1], sel.Color[2], sel.Color[3], sel.Color[4] } --[[@as number[] ]]

            for j=#propertyValue+1, 4 do
                newValue[j] = nil
            end

            for i=1, #sliders do
                sliders[i].Value = {newValue[i], 0, 0, 0}
            end

            self:SetParameter(propertyName, newValue)

            self.ParamNodeRefs[propertyName].Highlight = self:HasChanged(propertyName) and true or false
        end
    end

    local range = { min = -100, max = 100, step = 0.1 }
    for i=1, #propertyValue do
        local isIndex = propertyName:find("Index") ~= nil
        if isIndex then
            range.min = 0
            range.step = 1
        else
            range.min = -100
            range.max = 100
            range.step = 0.1
        end
        if propertyValue[i] > range.max then
            range.max = propertyValue[i] * 2
        end
        if propertyValue[i] < range.min then
            range.min = propertyValue[i] / 2
        end
        local slider = StyleHelpers.AddSliderWithStep(node, propertyName .. "##" .. self.MaterialName .. i, propertyValue[i], range.min, range.max, range.step, propertyName:find("Index") ~= nil)

        if colorPicker then
            slider.Visible = false
            slider.HideResetButton = true
        end
        slider.OnChange = function (sel)
            local newValue = { sliders[1].Value[1], sliders[2] and sliders[2].Value[1] or 0, sliders[3] and sliders[3].Value[1] or 0, sliders[4] and sliders[4].Value[1] or 0 } --[[@as number[] ]]

            for j=#propertyValue+1, 4 do
                newValue[j] = nil
            end

            if colorPicker then
                colorPicker.Color = ToVec4(newValue)
            end

            self:SetParameter(propertyName, newValue)

            self.ParamNodeRefs[propertyName].Highlight = self:HasChanged(propertyName) and true or false
        end

        table.insert(sliders, slider)
    end

    local function reset()
        self:ResetValue(propertyName)

        local newValue = self:GetParameter(propertyName)
        if newValue then
            for i=1, #newValue do
                if sliders[i] then
                    sliders[i].Value = {newValue[i], 0, 0, 0}
                end
            end
            if colorPicker then
                colorPicker.Color = ToVec4(newValue)
            end
        end

        self.ParamNodeRefs[propertyName].Highlight = self:HasChanged(propertyName) and true or false
    end

    local function updateSliders(newValue)
        if newValue then
            for i=1, #newValue do
                if sliders[i] then
                    sliders[i].Value = {newValue[i], 0, 0, 0}
                end
            end
            if colorPicker then
                colorPicker.Color = ToVec4(newValue)
            end
        end

        self.ParamNodeRefs[propertyName].Highlight = self:HasChanged(propertyName) and true or false
    end

    self.ResetFuncs[propertyName] = reset
    self.UpdateFuncs[propertyName] = updateSliders

    return sliders, colorPicker
end

function MaterialTab:ResetAll()
    self.Editor.PresetProxy = nil
    self.Editor.Parameters = {
        [1] = {},
        [2] = {},
        [3] = {},
        [4] = {}
    }
    self.Editor:ResetAll()
    
    self:UpdateUIState()
end

function MaterialTab:ResetValue(name)
    self.Editor:ResetParameter(name)
end

function MaterialTab:UpdateUIState()
    for key, updateFunc in pairs(self.UpdateFuncs) do
        local newValue = self:GetParameter(key)
        updateFunc(newValue)
    end

    for key, propNode in pairs(self.ParamNodeRefs) do
        propNode.Highlight = self:HasChanged(key) and true or false
    end

    for paramType, typeNode in pairs(self.ParamTypeNodeRefs) do
        typeNode.Highlight = self:HasChangeInType(paramType)
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
    local materialNode = ResourceHelpers.BuildMaterialResourceNode(self.Editor.Parameters, self.Editor.Material, uuid, internalName)
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
    return self.Editor.Parameters
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

function MaterialTab:SetParameter(name, value)
    self.Editor:SetParameter(name, value)
    self:UpdateUIState()
end

function MaterialTab:ResetParameter(name)
    self.Editor:ResetParameter(name)
    self:UpdateUIState()
end

function MaterialTab:ApplyParameters(params)
    self.Editor:ApplyParameters(params)
    self:UpdateUIState()
end

function MaterialTab:GetAllParameterNames()
    return {
        [1] = self.Editor.ParamSetProxy:GetAllScalarParameterNames(),
        [2] = self.Editor.ParamSetProxy:GetAllVector2ParameterNames(),
        [3] = self.Editor.ParamSetProxy:GetAllVector3ParameterNames(),
        [4] = self.Editor.ParamSetProxy:GetAllVector4ParameterNames(),
    }
end

function MaterialTab:HasChanged(name)
    return self.Editor:HasChanged(name)
end

function MaterialTab:HasChangeInType(paramType)
    return self.Editor:HasChangeInType(paramType)
end

function MaterialTab:ExportMaterial(defaultPath)
    local finalPath = defaultPath or ("Realm_Builder/Materials/Defaults/" .. GetLastPath(self.Editor.SourceFile))
    self.Editor:BuildMaterialResource(finalPath)
end

function MaterialTab:ExportPreset(defaultPath)
    local finalPath = defaultPath or ("Realm_Builder/Materials/Defaults/" .. GetLastPath(self.Editor.SourceFile))
    self.Editor:BuildMaterialPresetResource(finalPath)
end

function MaterialTab:ApplyToOthers()
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
    self.Label = Uuid_v4()
    self.Parent = RegisterWindow(self.Label, "Material Mixer", "Material Mixer Tab", self)
    self.Parent.Closeable = true

    self.Parent.OnClose = function (win)
        DeleteWindow(self.Parent)
    end

    self.MaterialName = "MaterialMixerEditor"
    self.ParentNodeName = "Material Mixer"
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

    parentNode.OnRightClick = function (sel)
        managePopup:Open()
    end

    parentNode.OnDragDrop = function (sel, drop)
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

function MaterialMixerTab:RenderProperty(node, propertyName, propertyValue, propRow)
    local sliders, picker = MaterialTab.RenderProperty(self, node, propertyName, propertyValue, propRow)

    local removeBtn = node:AddImageButton("##" .. self.MaterialName .. propertyName, RB_ICONS.X_Square, IMAGESIZE.ROW)
    removeBtn.OnClick = function (sel)
        self.ParametersSetProxy:RemoveParameter(propertyName)
        propRow:Destroy()
        self.ParamNodeRefs[propertyName] = nil
        self.UpdateFuncs[propertyName] = nil
        self.ResetFuncs[propertyName] = nil
        self:UpdateUIState()
    end

    removeBtn.SameLine = true

    return sliders, picker
end

function MaterialMixerTab:GetAllParameterNames()
    return {
        [1] = self.ParametersSetProxy:GetAllScalarParameterNames(),
        [2] = self.ParametersSetProxy:GetAllVector2ParameterNames(),
        [3] = self.ParametersSetProxy:GetAllVector3ParameterNames(),
        [4] = self.ParametersSetProxy:GetAllVector4ParameterNames(),
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
    local contextMenu = StyleHelpers.AddContextMenu(popup)

    contextMenu:AddItem("Export As Preset##" .. self.MaterialName, function (sel)
        local save = LSXHelpers.BuildMaterialPresetBank()
        local uuid = Uuid_v4()
        local preset = ResourceHelpers.BuildMaterialPresetResourceNode(self.ParametersSetProxy.Parameters, uuid, "MaterialMixer_Preset")
        save:AppendChild(preset)
        local finalPath = "Realm_Builder/Materials/" .. uuid .. ".lsx"

        Ext.IO.SaveFile(finalPath, save:Stringify({ AutoFindRoot = true }))
    end)    
end

