--- @class MaterialEditor
--- @field Parent ExtuiTreeParent
--- @field MaterialName string
--- @field Proxy CustomMaterialProxy
--- @field GetMaterial fun():Material|nil   
--- @field Parameters table<number, table<string, number[]>>
--- @field ResetFuncs table<string, fun()>
--- @field UpdateFuncs table<string, fun(newValue:number[])>
--- @field new fun(parent: ExtuiTreeParent, materialName: string, materialFunc: fun():Material|nil): MaterialEditor
MaterialEditor = _Class("MaterialEditor")

function MaterialEditor:__init(parent, materialName, materialFunc)
    self.Parent = parent
    self.GetMaterial = materialFunc
    self.MaterialName = materialName
    self.Proxy = CustomMaterialProxy.new({}, materialName) --[[@as CustomMaterialProxy]]

    self.Parameters = {
        [1] = {}, -- ScalarParameters
        [2] = {}, -- Vector2Parameters
        [3] = {}, -- Vector3Parameters
        [4] = {}, -- VectorParameters
    }
    self.ResetFuncs = {}
    self.UpdateFuncs = {}
end

function MaterialEditor:Render()
    local sourceFileName = GetLastPath(self.Proxy.SourceFile) or "N/A"
    local parent = self.Parent
    local parentNode = parent:AddSelectable("[+]" .. sourceFileName .. "##" .. self.MaterialName)
    local group = parent:AddGroup("MaterialEditorGroup##" .. self.MaterialName, parentNode)
    group.Visible = false

    parentNode.CanDrag = true
    parentNode.DragDropType = "MaterialPreset"
    parentNode.UserData = {
        MaterialParameters = self.Parameters,
    }

    parentNode.OnClick = function (sel)
        parentNode.Selected = false
        group.Visible = not group.Visible
        parentNode.Label = (group.Visible and "[-]" or "[+]") .. sourceFileName .. "##" .. self.MaterialName
    end

    parentNode.OnDragStart = function (sel)
        parentNode.DragPreview:AddText(sourceFileName)
    end

    parentNode.OnDragDrop = function (sel, drop)
        Debug("MaterialEditor: OnDragDrop", drop, drop.UserData)
        if drop.UserData and drop.UserData.MaterialProxy then
            local proxy = drop.UserData.MaterialProxy --[[@as MaterialProxy]]
            
            self:ApplyMatParameters(proxy)
        end
    end

    local params = {
        [1] = self.Proxy:GetAllScalarPropertyNames(),
        [2] = self.Proxy:GetAllVector2PropertyNames(),
        [3] = self.Proxy:GetAllVector3PropertyNames(),
        [4] = self.Proxy:GetAllVector4PropertyNames()
    }
    local indexToDisplay = {
        [1] = "ScalarParameters",
        [2] = "Vector2Parameters",
        [3] = "Vector3Parameters",
        [4] = "VectorParameters"
    }

    for i,propNames in ipairs(params) do
        local propType = indexToDisplay[i]
        if #propNames > 0 then
            local typeNode = group:AddTree(propType .. " Properties##" .. self.MaterialName)
            for _,propertyName in ipairs(propNames) do
                local propertyValue = self.Proxy:GetValue(propertyName)
                if propertyValue then
                    local propNode = typeNode:AddTree(propertyName .. "##" .. self.MaterialName)
                    self:RenderProperty(propNode, propertyName, propertyValue)
                end
            end
        end
    end
    
end

--- @param node ExtuiTreeParent
--- @param propertyName string
--- @param propertyValue number|number[]
function MaterialEditor:RenderProperty(node, propertyName, propertyValue)
    local sliders = {} --[[@type ExtuiSliderScalar[] ]]
    local colorPicker = nil

    if #propertyValue >= 3 then
        colorPicker = node:AddColorEdit(propertyName .. " Color##" .. self.MaterialName)
        colorPicker.Color = ToVec4(propertyValue)
        colorPicker.AlphaBar = (#propertyValue == 4)
        colorPicker.NoAlpha = (#propertyValue == 3)
        colorPicker.OnChange = function (sel)
            local newValue = { sel.Color[1], sel.Color[2], sel.Color[3], sel.Color[4] } --[[@as number[] ]]

            for j=#propertyValue+1, 4 do
                newValue[j] = nil
            end

            self:ApplyChange(propertyName, newValue)
        end
    end

    for i=1, #propertyValue do
        local slider = AddSliderWithStep(node, propertyName .. "##" .. self.MaterialName .. i, propertyValue[i], 0, 100, 0.1, propertyName:find("Index") ~= nil)

        slider.OnChange = function (sel)
            local newValue = { sliders[1].Value[1], sliders[2] and sliders[2].Value[1] or 0, sliders[3] and sliders[3].Value[1] or 0, sliders[4] and sliders[4].Value[1] or 0 } --[[@as number[] ]]

            for j=#propertyValue+1, 4 do
                newValue[j] = nil
            end

            self:ApplyChange(propertyName, newValue)
        end

        table.insert(sliders, slider)
    end

    local function reset()
        local newValue = self.Proxy:GetValue(propertyName)
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

        self:ApplyChange(propertyName, newValue)
        self.Parameters[#newValue][propertyName] = nil
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

function MaterialEditor:ApplyChange(propertyName, newValue)
    local mat = self.GetMaterial()
    if not mat then
        Error("MaterialEditor: Could not find material for entity " .. tostring(self.Guid) .. " descIndex " .. tostring(self.DescIndex))
        return
    end

    local funcName = PropTypeToFunc[#newValue]
    local applyValue = #newValue == 1 and newValue[1] or newValue

    mat[funcName](mat, propertyName, applyValue)

    self.Parameters[#newValue][propertyName] = newValue

    local updateFunc = self.UpdateFuncs[propertyName]
    if updateFunc then
        updateFunc(newValue)
    end
end

function MaterialEditor:ResetAll()
    for _,resetFunc in pairs(self.ResetFuncs) do
        resetFunc()
    end
    self.Parameters = {}
    for i=1,4 do
        self.Parameters[i] = {}
    end
end

function MaterialEditor:ExportChanges()
    return self.Parameters
end

function MaterialEditor:ApplyChanges(changes)
    for propertyName, value in pairs(changes) do
        local mat = self.GetMaterial()
        if not mat then
            Error("MaterialEditor: Could not find material for entity " .. tostring(self.Guid) .. " descIndex " .. tostring(self.DescIndex))
            return
        end

        local funcName = PropTypeToFunc[#value]
        local applyValue = #value == 1 and value[1] or value
    
        mat[funcName](mat, propertyName, applyValue)

        local updateFunc = self.UpdateFuncs[propertyName]
        if updateFunc then
            updateFunc(value)
        end
    end
end

--- @param parameters table<number, table<string, number[]>>
function MaterialEditor:ApplyMatParameters(parameters)
    local mat = self.GetMaterial()
    if not mat then Warning("MaterialEditor: Could not find material") return end

    for propType, props in pairs(parameters) do
        for propName, value in pairs(props) do
            if not self.Proxy:HasProperty(propName) then
                Warning("MaterialEditor: Property " .. tostring(propName) .. " does not exist on material " .. tostring(self.MaterialName))
                return
            end
            local funcName = PropTypeToFunc[#value]
            local applyValue = #value == 1 and value[1] or value
        
            mat[funcName](mat, propName, applyValue)

            self.Parameters[#value][propName] = value
            local updateFunc = self.UpdateFuncs[propName]
            if updateFunc then
                updateFunc(value)
            end
        end
    end
end

function MaterialEditor:Reapply()
    for paramType, props in pairs(self.Parameters) do
        for propertyName, value in pairs(props) do
            local mat = self.GetMaterial()
            if not mat then
                Error("MaterialEditor: Could not find material for entity " .. tostring(self.Guid) .. " descIndex " .. tostring(self.DescIndex))
                return
            end

            local funcName = PropTypeToFunc[#value]
            local applyValue = #value == 1 and value[1] or value
        
            mat[funcName](mat, propertyName, applyValue)

            local updateFunc = self.UpdateFuncs[propertyName]
            if updateFunc then
                updateFunc(value)
            end
        end
    end
end