--- @class MaterialTab
--- @field Parent ExtuiTreeParent
--- @field Editor MaterialEditor
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
--- @return ExtuiSelectable, ExtuiGroup
function MaterialTab:Render(parent)
    local sourceFileName = self.ParentNodeName
    parent = parent or self.Parent
    local uuid = Uuid_v4()
    local parentNode = parent:AddSelectable("[-] " .. sourceFileName .. "##" .. self.MaterialName .. uuid) --[[@as ExtuiSelectable ]]
    local group = parent:AddGroup("MaterialEditorGroup##" .. self.MaterialName, parentNode) -- Tree is weird with drag-and-drop, so use a Selectable + Group to simulate a collapsible tree node
    group.Visible = true

    local managePopup = group:AddPopup("Manage##" .. self.MaterialName)
    self:SetupManagePopup(managePopup)

    parentNode.CanDrag = true
    parentNode.DragDropType = MATERIALPRESET_DRAGDROP_TYPE

    parentNode.UserData = {
        MaterialProxy = self.Editor,
        Parameters = self.Editor and self.Editor.Parameters or nil
    }

    parentNode.OnClick = function (sel)
        parentNode.Selected = false
        group.Visible = not group.Visible
        parentNode.Label = (group.Visible and "[-] " or "[+] ") .. sourceFileName .. "##" .. self.MaterialName .. uuid
    end

    parentNode.OnRightClick = function (sel)
        managePopup:Open()
    end

    parentNode.OnDragStart = function (sel)
        parentNode.DragPreview:AddText(sourceFileName)
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
    self.ParamGroupRefs = {}
    for paramType,propNames in ipairs(params) do
        local propType = indexToDisplay[paramType]
        if #propNames < 1 then goto continue end

        local typeNode = group:AddTree(propType .. "##" .. self.MaterialName)

        local searchBox = typeNode:AddInputText("##" .. self.MaterialName .. propType)
        searchBox.Hint = "Search " .. propType .. "..."
        searchBox.OnChange = Debounce(50 ,function (sel)
            if sel.Text == "" then
                for _, node in pairs(self.ParamGroupRefs) do
                    node.Visible = true
                end
                return
            end

            local searchTerm = sel.Text:lower()
            for _,propertyName in ipairs(propNames) do
                local propNode = self.ParamGroupRefs[propertyName]
                if propNode then
                    if searchTerm == "" or propertyName:lower():find(searchTerm) then
                        propNode.Visible = true
                    else
                        propNode.Visible = false
                    end
                end
            end
        end)

        typeNode:SetOpen(true)
        self.ParamTypeNodeRefs[paramType] = typeNode
        for _,propertyName in ipairs(propNames) do
            local allGroup = typeNode:AddGroup("AllPropertiesGroup##" .. self.MaterialName .. propertyName .. tostring(math.random()))
            local initLable = self.cachedExpandedState[propertyName] and "[-] " or "[+] "
            local propNode = allGroup:AddSelectable(initLable .. propertyName .. "##" .. self.MaterialName) --[[@as ExtuiSelectable ]]
            self.ParamNodeRefs[propertyName] = propNode
            self.ParamGroupRefs[propertyName] = allGroup
            local paramgroup = allGroup:AddGroup("PropertyGroup##" .. self.MaterialName .. propertyName .. tostring(math.random()))
            paramgroup.Visible = self.cachedExpandedState[propertyName] == true

            propNode.OnHoverEnter = function ()
                local paramValue = self:GetParameter(propertyName)

                self:RenderProperty(paramgroup, propertyName, paramValue)
                propNode.OnHoverEnter = function ()
                    propNode.Highlight = self:HasChanged(propertyName) and true or false
                    typeNode.Framed = self:HasChangeInType(paramType)
                end
            end

            if paramgroup.Visible then
                propNode.OnHoverEnter()
            end

            propNode.OnClick = function (sel)
                propNode.Selected = false
                paramgroup.Visible = not paramgroup.Visible
                propNode.Label = (paramgroup.Visible and "[-] " or "[+] ") .. propertyName .. "##" .. self.MaterialName
                self.cachedExpandedState[propertyName] = paramgroup.Visible
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
        end

        ::continue::
    end
    
    return parentNode, group
end

function MaterialTab:ClearRefs()
    self.ParamNodeRefs = {}
    self.ParamTypeNodeRefs = {}
    self.UpdateFuncs = {}
    self.ResetFuncs = {}
    self.ParamGroupRefs = {}
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
        colorPicker = node:AddColorEdit(propertyName .. "##" .. self.MaterialName)
        colorPicker.Color = ToVec4(propertyValue)
        colorPicker.AlphaBar = (#propertyValue == 4)
        colorPicker.NoAlpha = (#propertyValue == 3)
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
        local slider = AddSliderWithStep(node, propertyName .. "##" .. self.MaterialName .. i, propertyValue[i], range.min, range.max, range.step, propertyName:find("Index") ~= nil)

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
    local resetValue = self.Editor:ResetParameter(name)
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
        typeNode.Framed = self:HasChangeInType(paramType)
    end
end

---@param popup ExtuiPopup
function MaterialTab:SetupManagePopup(popup)
    local tt = popup:AddTable("ManageTable##" .. self.MaterialName, 1)
    tt.BordersInnerH = true

    local row = tt:AddRow()

    local matMixerBtn = AddSelectableButton(row:AddCell(), "Open Material Mixer##" .. self.MaterialName, function (sel)
        local allParams = self.Editor.ParamSetProxy.Parameters
        local mixerParams = {}
        for paramType, typeParams in pairs(allParams) do
            mixerParams[paramType] = {}
            for paramName, paramValue in pairs(typeParams) do
                mixerParams[paramType][paramName] = self.Editor:GetParameter(paramName)
            end
        end

        local mixerTab = MaterialMixerTab.new(mixerParams)
        mixerTab:Render()
    end)

    local btnReset = AddSelectableButton(row:AddCell(), "Reset All##" .. self.MaterialName, function (sel)
        self:ResetAll()
    end)
    btnReset.DontClosePopups = true

    local defaultMatPath = "Realm_Builder/Materials/"
    local finalPath = defaultMatPath .. self.ParentNodeName

    local btnExport = AddSelectableButton(row:AddCell(), "Export As Material##" .. self.MaterialName, function (sel)
        local save = LSXHelpers.BuildMaterialResource(self.Editor.Parameters, self.Editor.Material)
        if save then
            Ext.IO.SaveFile(finalPath, save:Stringify())
        end
    end)

    local btnExportAsPreset = AddSelectableButton(row:AddCell(), "Export As Preset##" .. self.MaterialName, function (sel)
        local save = LSXHelpers.BuildMaterialPresetBank()

        local preset = LSXHelpers.BuildMaterialPresetResourceNode(self.Editor.Parameters, Uuid_v4(), self.ParentNodeName:gsub("%.[lL][sS][fF]$", "") .. "_Preset")
        save:AppendChild(preset)

        Ext.IO.SaveFile(finalPath, save:Stringify({ AutoFindRoot = true }))
    end)

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
    if self.parentNode then
        self.parentNode:Destroy()
        self.group:Destroy()
    end

    local parentNode, group = MaterialTab.Render(self, parent)

    parentNode.UserData = {
        MaterialProxy = self.ParametersSetProxy,
        Parameters = self.ParametersSetProxy.Parameters
    }

    parentNode.Label = "[-] Material Mixer##" .. self.MaterialName
    group.Visible = true

    self.parentNode = parentNode
    self.group = group

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
    -- no-op
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

    local tt = popup:AddTable("ManageTable##" .. self.MaterialName, 1)
    tt.BordersInnerH = true

    local row = tt:AddRow()

    local btnReset = AddSelectableButton(row:AddCell(), "Clear All##" .. self.MaterialName, function (sel)
        self.ParametersSetProxy.Parameters = {
            [1] = {},
            [2] = {},
            [3] = {},
            [4] = {}
        }
        self:Render()
    end)

    local btnExport = AddSelectableButton(row:AddCell(), "Export As Material Preset##" .. self.MaterialName, function (sel)

    end)

    local destroybtn = AddSelectableButton(row:AddCell(), "Destroy Mixer##" .. self.MaterialName, function (sel)
        DeleteWindow(self.Parent)
    end)
    
end

