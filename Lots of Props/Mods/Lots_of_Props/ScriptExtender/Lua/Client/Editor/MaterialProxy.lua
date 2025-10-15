local materialProxies = {}

--- @class MaterialProxy
--- @field Material GUIDSTRING
--- @field TypeRefs table<string, 1|2|3|4> Mapping of property name to type (1=Scalar, 2=Vector2, 3=Vector3, 4=Vector4)
--- @field IndexRefs table<1|2|3|4, table<string, number>> Mapping of type to property name to index in resource
--- @field BaseValues table<string, number[]>
--- @field Values table<string, number[]>
--- @field new fun(materialName: GUIDSTRING): MaterialProxy|nil
--- @field GetProperty fun(self, propertyName: string): ResourceMaterialResourceScalarParameter|ResourceMaterialResourceVector2Parameter|ResourceMaterialResourceVector3Parameter|ResourceMaterialResourceVector4Parameter|nil
--- @field SetProperty fun(self, propertyName: string, value: number[]): boolean
--- @field GetValue fun(self, propertyName: string): number[]|nil
--- @field GetBaseValue fun(self, propertyName: string): number[]|nil
--- @field ResetProperty fun(self, propertyName: string): boolean
--- @field ResetAll fun(self)
--- @field ResetToBaseValues fun(self)
MaterialProxy = {}
MaterialProxy.__index = MaterialProxy

--- @class MaterialPresetProxy : MaterialProxy
MaterialPresetProxy = {}
MaterialPresetProxy.__index = MaterialPresetProxy
setmetatable(MaterialPresetProxy, {__index = MaterialProxy})

PropTypeToFunc = {
    [1] = "SetScalar",
    [2] = "SetVector2",
    [3] = "SetVector3",
    [4] = "SetVector4"
}

function MaterialProxy.new(materialName)
    if not materialName then
        return nil
    end

    if materialProxies[materialName] then
        return materialProxies[materialName]
    end

    local isMaterial = Ext.Resource.Get(materialName, "Material") --[[@as ResourceMaterialResource]]
    if not isMaterial then
        return MaterialPresetProxy.new(materialName)
    end

    local mP = setmetatable({}, MaterialProxy)
    mP:__init(materialName)
    if mP.Material then
        materialProxies[materialName] = mP
        return mP
    end

    return nil
end

function MaterialPresetProxy.new(materialPresetName)
    if not materialPresetName then
        return nil
    end

    if materialProxies[materialPresetName] then
        return materialProxies[materialPresetName]
    end

    local isMaterialPreset = Ext.Resource.Get(materialPresetName, "MaterialPreset") --[[@as ResourceMaterialPresetResource]]
    if not isMaterialPreset then
        return nil
    end

    local mP = setmetatable({}, MaterialPresetProxy)
    mP:__init(materialPresetName)
    if mP.Material then
        materialProxies[materialPresetName] = mP
        return mP
    end

    return nil
end

function MaterialPresetProxy:__init(materialPresetName)
    local res = Ext.Resource.Get(materialPresetName, "MaterialPreset") --[[@as ResourceMaterialPresetResource]]
    if not res then
        Error("MaterialPresetProxy: Could not find material preset: " .. tostring(materialPresetName))
        return
    end

    _D(res)
    self.Material = res.Presets.MaterialResource
    self.Preset = materialPresetName
    self.SorceFile = res.SourceFile
    self.TypeRefs = {}
    self.IndexRefs = {}
    self.BaseValues = {}
    self.Values = {}

    local params = {
        res.Presets.ScalarParameters,
        res.Presets.Vector2Parameters,
        res.Presets.Vector3Parameters,
        res.Presets.VectorParameters
    }

    for i=1,4 do
        self.Values[i] = {}
        self.BaseValues[i] = {}
    end

    for num, paramList in pairs(params) do
        for i, param in pairs(paramList) do

            local parameterName = param.Parameter
            local value = type(param.Value) == "number" and {param.Value} or param.Value --[[@as number[] ]]
            if self.Values[num][parameterName] then
                Warning("MaterialPresetProxy: Duplicate material parameter name '" .. parameterName .. "' in material preset '" .. materialPresetName .. "'. Overwriting previous value.")
            end

            self.TypeRefs[parameterName] = num
            self.IndexRefs[parameterName] = i
            self.Values[num][parameterName] = value
            self.BaseValues[num][parameterName] = value
            ::continue::
        end
    end
end

function MaterialProxy:__init(materialName)
    local res = Ext.Resource.Get(materialName, "Material") --[[@as ResourceMaterialResource]]
    if not res then
        Error("MaterialProxy: Could not find material: " .. tostring(materialName))
        return
    end

    self.Material = materialName
    self.SourceFile = res.SourceFile
    self.TypeRefs = {}
    self.IndexRefs = {}
    self.BaseValues = {}
    self.Values = {}

    local params = {
        res.ScalarParameters,
        res.Vector2Parameters,
        res.Vector3Parameters,
        res.VectorParameters
    }

    for i=1,4 do
        self.Values[i] = {}
        self.BaseValues[i] = {}
    end

    for num, paramList in pairs(params) do
        self.IndexRefs[num] = {}
        for i, param in pairs(paramList) do
            local value = type(param.Value) == "number" and {param.Value} or param.Value --[[@as number[] ]]
            if self.Values[num][param.ParameterName] then
                Warning("MaterialProxy: Duplicate material parameter name '" .. param.ParameterName .. "' in material '" .. materialName .. "'. Overwriting previous value.")
            end
            self.TypeRefs[param.ParameterName] = num
            self.IndexRefs[num][param.ParameterName] = i
            self.Values[num][param.ParameterName] = value
            self.BaseValues[num][param.ParameterName] = value
        end
    end

end

function MaterialProxy:GetProperty(propertyName)
    local typeRef = self.TypeRefs[propertyName]
    if not typeRef then
        return nil
    end

    local indexRef = self.IndexRefs[typeRef][propertyName]
    if not indexRef then
        return nil
    end

    local res = Ext.Resource.Get(self.Material, "Material") --[[@as ResourceMaterialResource]]
    if not res then
        Error("MaterialProxy: Could not find material: " .. tostring(self.Material))
        return nil
    end

    local param = nil
    if typeRef == 1 then
        param = res.ScalarParameters[indexRef]
    elseif typeRef == 2 then
        param = res.Vector2Parameters[indexRef]
    elseif typeRef == 3 then
        param = res.Vector3Parameters[indexRef]
    elseif typeRef == 4 then
        param = res.VectorParameters[indexRef]
    end

    if not param then
        return nil
    end

    return param
end

function MaterialPresetProxy:GetProperty(propertyName)
    local typeRef = self.TypeRefs[propertyName]
    if not typeRef then
        return nil
    end

    local indexRef = self.IndexRefs[propertyName]
    if not indexRef then
        return nil
    end

    local res = Ext.Resource.Get(self.Preset, "MaterialPreset") --[[@as ResourceMaterialPresetResource]]
    if not res then
        Error("MaterialPresetProxy: Could not find material preset: " .. tostring(self.Material))
        return nil
    end

    local param = nil
    if typeRef == 1 then
        param = res.Presets.ScalarParameters[indexRef]
    elseif typeRef == 2 then
        param = res.Presets.Vector2Parameters[indexRef]
    elseif typeRef == 3 then
        param = res.Presets.Vector3Parameters[indexRef]
    elseif typeRef == 4 then
        param = res.Presets.VectorParameters[indexRef]
    end

    if not param then
        return nil
    end

    return param
end

function MaterialProxy:SetProperty(propertyName, value)
    value = type(value) == "number" and {value} or value

    local typeRef = self.TypeRefs[propertyName]
    if not typeRef then
        Error("MaterialProxy: Could not find property '" .. tostring(propertyName) .. "' in material '" .. tostring(self.Material) .. "'")
        return false
    end

    if #value ~= typeRef then
        Error("MaterialProxy: Invalid value for property '" .. tostring(propertyName) .. "' in material '" .. tostring(self.Material) .. "'. Expected " .. tostring(typeRef) .. " values, got " .. tostring(#value))
        return false
    end

    local indexRef = self.IndexRefs[typeRef][propertyName]
    if not indexRef then
        Error("MaterialProxy: Could not find property '" .. tostring(propertyName) .. "' in material '" .. tostring(self.Material) .. "'")
        return false
    end

    local res = Ext.Resource.Get(self.Material, "Material") --[[@as ResourceMaterialResource]]
    if not res then
        Error("MaterialProxy: Could not find material: " .. tostring(self.Material))
        return false
    end

    local instance = res.Instance

    if not instance then
        Error("MaterialProxy: Instance not found for material: " .. tostring(self.Material))
        return false
    end

    if #value == 1 then
        value = value[1]
    end

    instance[PropTypeToFunc[typeRef]](instance, propertyName, value)

    return true
end

function MaterialPresetProxy:SetProperty()
    Error("MaterialPresetProxy: Cannot set property on material preset.")
    return false
end

function MaterialProxy:GetValue(propertyName)
    local typeRef = self.TypeRefs[propertyName]
    if not typeRef then
        return nil
    end

    return self.Values[typeRef][propertyName]
end

function MaterialProxy:GetBaseValue(propertyName)
    local typeRef = self.TypeRefs[propertyName]
    if not typeRef then
        return nil
    end

    return self.BaseValues[typeRef][propertyName]
end

function MaterialPresetProxy:GetBaseValue()
    Error("MaterialPresetProxy: Cannot get base value on material preset.")
    return nil
end

function MaterialProxy:GetAllProperties()
    return self.Values
end

function MaterialProxy:GetAllScalarPropertyNames()
    local scalars = {}
    for propertyName,_ in pairs(self.IndexRefs[1]) do
        table.insert(scalars, propertyName)
    end
    table.sort(scalars)
    return scalars
end

function MaterialProxy:GetAllVector2PropertyNames()
    local vec2s = {}
    for propertyName,_ in pairs(self.IndexRefs[2]) do
        table.insert(vec2s, propertyName)
    end
    table.sort(vec2s)
    return vec2s
end

function MaterialProxy:GetAllVector3PropertyNames()
    local vec3s = {}
    for propertyName,_ in pairs(self.IndexRefs[3]) do
        table.insert(vec3s, propertyName)
    end
    table.sort(vec3s)
    return vec3s
end

function MaterialProxy:GetAllVector4PropertyNames()
    local vec4s = {}
    for propertyName,_ in pairs(self.IndexRefs[4]) do
        table.insert(vec4s, propertyName)
    end
    table.sort(vec4s)
    return vec4s
end

--- @param mat Material
function MaterialProxy:ApplyToMaterial(mat)
    for typeRef,props in pairs(self.Values) do
        for propertyName,value in pairs(props) do
            if mat[PropTypeToFunc[typeRef]] then
                local val = #value == 1 and value[1] or value
                mat[PropTypeToFunc[typeRef]](mat, propertyName, val)
            end
        end
    end
end

function MaterialProxy:ExportToTable()

end