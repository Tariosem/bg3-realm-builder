--- @class MaterialTab
--- @field Parent ExtuiTreeParent
--- @field Editor MaterialEditor
MaterialTab = _Class("MaterialEditor")

function MaterialTab:__init(parent, materialName, materialFunc)
    self.Parent = parent
    self.Editor = MaterialEditor.new(materialFunc, materialName)
    self.GetMaterial = materialFunc
    self.MaterialName = materialName

    self.ResetFuncs = {}
    self.UpdateFuncs = {}
end

function MaterialTab:Render()
    local sourceFileName = GetLastPath(self.Editor.SourceFile) or "N/A"
    local parent = self.Parent
    local parentNode = parent:AddSelectable("[+] " .. sourceFileName .. "##" .. self.MaterialName)
    local group = parent:AddGroup("MaterialEditorGroup##" .. self.MaterialName, parentNode) -- Tree has issues with drag-and-drop, so use a Selectable + Group to emulate tree behavior.
    group.Visible = false

    local managePopup = parent:AddPopup("Manage##" .. self.MaterialName)
    self:SetupManagePopup(managePopup)

    parentNode.CanDrag = true
    parentNode.DragDropType = "MaterialPreset"
    parentNode.UserData = {
        MaterialProxy = self.Editor
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
        if drop.UserData and drop.UserData.MaterialProxy then
            local proxy = drop.UserData.MaterialProxy --[[@as MaterialProxy]]

            Debug(proxy.Parameters)
            self.Editor:ApplyParameters(proxy.Parameters)
            for key, func in pairs(self.UpdateFuncs) do
                local newValue = self.Editor:GetParameter(key)
                func(newValue)
            end
        end
    end

    local params = {
        [1] = self.Editor.Proxy:GetAllScalarPropertyNames(),
        [2] = self.Editor.Proxy:GetAllVector2PropertyNames(),
        [3] = self.Editor.Proxy:GetAllVector3PropertyNames(),
        [4] = self.Editor.Proxy:GetAllVector4PropertyNames()
    }
    local indexToDisplay = {
        [1] = "Scalar Parameters",
        [2] = "Vector2 Parameters",
        [3] = "Vector3 Parameters",
        [4] = "Vector Parameters"
    }

    for i,propNames in ipairs(params) do
        local propType = indexToDisplay[i]
        if #propNames > 0 then
            local typeNode = group:AddTree(propType .. "##" .. self.MaterialName)
            for _,propertyName in ipairs(propNames) do
                local propertyValue = self.Editor:GetParameter(propertyName)
                if propertyValue then
                    local allGroup = typeNode:AddGroup("AllPropertiesGroup##" .. self.MaterialName .. propertyName .. tostring(math.random()))
                    local propNode = allGroup:AddSelectable("[+] " .. propertyName .. "##" .. self.MaterialName)
                    local paramgroup = allGroup:AddGroup("PropertyGroup##" .. self.MaterialName .. propertyName .. tostring(math.random()))
                    paramgroup.Visible = false
                    self:RenderProperty(paramgroup, propertyName, propertyValue)

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
            end
        end
    end
    
end

--- @param node ExtuiTreeParent
--- @param propertyName string
--- @param propertyValue number|number[]
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
    end

    self.ResetFuncs[propertyName] = reset
    self.UpdateFuncs[propertyName] = updateSliders
end

function MaterialTab:ResetAll()
    for key, func in pairs(self.ResetFuncs) do
        func()
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

    local btnExport = AddSelectableButton(row:AddCell(), "Export As Material##" .. self.MaterialName, function (sel)
        local res = self.Editor.Proxy:GetResource()

        self.Editor:ExportToLSXAsMaterial("SOMETHING")
    end)

    local btnExportAsPreset = AddSelectableButton(row:AddCell(), "Export As Preset##" .. self.MaterialName, function (sel)
        self.Editor:ExportToLSXAsMaterialPreset("SOMETHING")
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