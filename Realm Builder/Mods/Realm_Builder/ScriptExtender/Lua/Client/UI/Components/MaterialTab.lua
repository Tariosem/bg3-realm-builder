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

    self.ResetFuncs = {}
    self.UpdateFuncs = {}
end

function MaterialTab:Render()
    local sourceFileName = GetLastPath(self.Editor.SourceFile) or "N/A"
    local parent = self.Parent
    local parentNode = parent:AddSelectable("[-] " .. sourceFileName .. "##" .. self.MaterialName)
    local group = parent:AddGroup("MaterialEditorGroup##" .. self.MaterialName, parentNode) -- Tree has issues with drag-and-drop, so use a Selectable + Group to emulate tree behavior.
    group.Visible = true

    local managePopup = parent:AddPopup("Manage##" .. self.MaterialName)
    self:SetupManagePopup(managePopup)

    parentNode.CanDrag = true
    parentNode.DragDropType = MATERIALPRESET_DRAGDROP_TYPE

    parentNode.UserData = {
        MaterialProxy = self.Editor,
        Parameters = self.Editor.Parameters
    }

    parentNode.OnClick = function (sel)
        parentNode.Selected = false
        group.Visible = not group.Visible
        parentNode.Label = (group.Visible and "[-] " or "[+] ") .. sourceFileName .. "##" .. self.MaterialName
    end

    parentNode.OnRightClick = function (sel)
        managePopup:Open()
    end

    parentNode.OnDragStart = function (sel)
        parentNode.DragPreview:AddText(sourceFileName)
    end

    parentNode.OnDragDrop = function (sel, drop)
        sel.UserData.PresetProxy = self.Editor.PresetProxy --[[@as MaterialPresetProxy ]]
        if drop.UserData and drop.UserData.MaterialProxy then
            local params = drop.UserData.Parameters

            self.Editor:ApplyParameters(params)
            drop.UserData.SuccessApply = true
            self:UpdateUIState()
            self.Editor.PresetProxy = drop.UserData.PresetProxy --[[@as MaterialPresetProxy ]]
        end
    end

    local params = {
        [1] = self.Editor.ParamSetProxy:GetAllScalarParameterNames(),
        [2] = self.Editor.ParamSetProxy:GetAllVector2ParameterNames(),
        [3] = self.Editor.ParamSetProxy:GetAllVector3ParameterNames(),
        [4] = self.Editor.ParamSetProxy:GetAllVector4ParameterNames()
    }
    local indexToDisplay = {
        [1] = "Scalar Parameters",
        [2] = "Vector2 Parameters",
        [3] = "Vector3 Parameters",
        [4] = "Vector4 Parameters"
    }

    self.ParamTypeNodeRefs = {}
    self.ParamNodeRefs = {}
    for paramType,propNames in ipairs(params) do
        local propType = indexToDisplay[paramType]
        if #propNames < 1 then goto continue end

        local typeNode = group:AddTree(propType .. "##" .. self.MaterialName)
        self.ParamTypeNodeRefs[paramType] = typeNode
        for _,propertyName in ipairs(propNames) do
            local allGroup = typeNode:AddGroup("AllPropertiesGroup##" .. self.MaterialName .. propertyName .. tostring(math.random()))
            local propNode = allGroup:AddSelectable("[+] " .. propertyName .. "##" .. self.MaterialName) --[[@as ExtuiSelectable ]]
            self.ParamNodeRefs[propertyName] = propNode
            local paramgroup = allGroup:AddGroup("PropertyGroup##" .. self.MaterialName .. propertyName .. tostring(math.random()))
            paramgroup.Visible = false

            propNode.OnHoverEnter = function ()
                local paramValue = self.Editor:GetParameter(propertyName) --[[@as number[] ]]

                self:RenderProperty(paramgroup, propertyName, paramValue)
                propNode.OnHoverEnter = function ()
                    propNode.Highlight = self.Editor:HasChanged(propertyName) and true or false
                    typeNode.Framed = self.Editor:HasChangeInType(paramType)
                end
            end

            propNode.OnClick = function (sel)
                propNode.Selected = false
                paramgroup.Visible = not paramgroup.Visible
                propNode.Label = (paramgroup.Visible and "[-] " or "[+] ") .. propertyName .. "##" .. self.MaterialName
            end

            propNode.UserData = {
                MaterialProxy = self.Editor,
                ParameterName = propertyName
            }

            propNode.CanDrag = true
            propNode.DragDropType = "ParameterValue"

            propNode.OnDragStart = function (sel)
                propNode.DragPreview:AddText(propertyName)

                local value = self.Editor:GetParameter(propertyName)
                if not value then return end
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
                if drop.UserData and drop.UserData.ParameterName then
                    local paramName = drop.UserData.ParameterName --[[@as string ]]
                    local proxy = drop.UserData.MaterialProxy --[[@as MaterialEditor ]]
                    local newValue = proxy:GetParameter(paramName)
                    local currentValue = self.Editor:GetParameter(propertyName)
                    if newValue and currentValue then
                        if not #newValue == #currentValue then
                            Error("Cannot drop parameter '" .. paramName .. "' onto parameter '" .. propertyName .. "' due to mismatched sizes.")
                            return
                        end
                    else
                        return -- Invalid parameters
                    end

                    self.Editor:SetParameter(propertyName, newValue)

                    local updateFunc = self.UpdateFuncs[propertyName]
                    if updateFunc then
                        updateFunc(newValue)
                    end
                end
            end
        end

        ::continue::
    end
    
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

            self.Editor:SetParameter(propertyName, newValue)

            self.ParamNodeRefs[propertyName].Highlight = self.Editor:HasChanged(propertyName) and true or false
        end
    end

    for i=1, #propertyValue do
        local slider = AddSliderWithStep(node, propertyName .. "##" .. self.MaterialName .. i, propertyValue[i], -10, 100, 0.1, propertyName:find("Index") ~= nil)

        slider.OnChange = function (sel)
            local newValue = { sliders[1].Value[1], sliders[2] and sliders[2].Value[1] or 0, sliders[3] and sliders[3].Value[1] or 0, sliders[4] and sliders[4].Value[1] or 0 } --[[@as number[] ]]

            for j=#propertyValue+1, 4 do
                newValue[j] = nil
            end

            if colorPicker then
                colorPicker.Color = ToVec4(newValue)
            end

            self.Editor:SetParameter(propertyName, newValue)

            self.ParamNodeRefs[propertyName].Highlight = self.Editor:HasChanged(propertyName) and true or false
        end

        table.insert(sliders, slider)
    end

    local function reset()
        self.Editor:ResetParameter(propertyName)

        local newValue = self.Editor:GetParameter(propertyName)
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

        self.ParamNodeRefs[propertyName].Highlight = self.Editor:HasChanged(propertyName) and true or false
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

        self.ParamNodeRefs[propertyName].Highlight = self.Editor:HasChanged(propertyName) and true or false
    end

    self.ResetFuncs[propertyName] = reset
    self.UpdateFuncs[propertyName] = updateSliders
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

function MaterialTab:UpdateUIState()
    for key, updateFunc in pairs(self.UpdateFuncs) do
        local newValue = self.Editor:GetParameter(key)
        updateFunc(newValue)
    end

    for key, propNode in pairs(self.ParamNodeRefs) do
        propNode.Highlight = self.Editor:HasChanged(key) and true or false
    end

    for paramType, typeNode in pairs(self.ParamTypeNodeRefs) do
        typeNode.Framed = self.Editor:HasChangeInType(paramType)
    end
end


---@param popup ExtuiPopup
function MaterialTab:SetupManagePopup(popup)
    local tt = popup:AddTable("ManageTable##" .. self.MaterialName, 1)
    tt.BordersInnerH = true

    local row = tt:AddRow()

    local btnReset = AddSelectableButton(row:AddCell(), "Reset All##" .. self.MaterialName, function (sel)
        self:ResetAll()
    end)
    btnReset.DontClosePopups = true

    local defaultMatPath = "Realm_Builder/Materials/Defaults/"
    local finalPath = defaultMatPath .. GetLastPath(self.Editor.SourceFile)

    local btnExport = AddSelectableButton(row:AddCell(), "Export As Material##" .. self.MaterialName, function (sel)
        self.Editor:ExportToLSXAsMaterial(finalPath)
    end)

    local btnExportAsPreset = AddSelectableButton(row:AddCell(), "Export As Preset##" .. self.MaterialName, function (sel)
        self.Editor:ExportToLSXAsMaterialPreset(finalPath)
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