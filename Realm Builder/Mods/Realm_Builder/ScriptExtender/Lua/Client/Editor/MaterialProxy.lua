local materialProxies = {}

--- @class MaterialProxy
--- @field Material GUIDSTRING
--- @field TypeRefs table<string, 1|2|3|4> Mapping of property name to type (1=Scalar, 2=Vector2, 3=Vector3, 4=Vector4)
--- @field IndexRefs table<1|2|3|4, table<string, number>> Mapping of type to property name to index in resource
--- @field BaseValues table<number, table<string, number[]>> Mapping of type to property name to base value
--- @field Parameters table<number, table<string, number[]>> Mapping of type to property name to current value
--- @field new fun(materialName: GUIDSTRING): MaterialProxy|nil
--- @field GetResource fun(self): ResourceMaterialResource
--- @field GetParameter fun(self, paramName: string): number[]|?
--- @field SetProperty fun(self, paramName: string, value: number[]): boolean
--- @field GetValue fun(self, paramName: string): number[]|nil
--- @field GetBaseValue fun(self, paramName: string): number[]|nil
--- @field ResetProperty fun(self, paramName: string): boolean
--- @field ResetAll fun(self)
--- @field ResetToBaseValues fun(self)
MaterialProxy = {}
MaterialProxy.__index = MaterialProxy

--- @class MaterialPresetProxy : MaterialProxy
--- @field new fun(materialPresetName: GUIDSTRING?): MaterialPresetProxy|nil
--- @field GetResource fun(self): ResourceMaterialPresetResource
MaterialPresetProxy = {}
MaterialPresetProxy.__index = MaterialPresetProxy
setmetatable(MaterialPresetProxy, {__index = MaterialProxy})

--- @class ParametersSetProxy : MaterialProxy
--- @field new fun(paramSetName: MaterialParametersSet?): ParametersSetProxy|nil
ParametersSetProxy = {}
ParametersSetProxy.__index = ParametersSetProxy
setmetatable(ParametersSetProxy, {__index = MaterialProxy})


PropTypeToFunc = {
    [1] = "SetScalar",
    [2] = "SetVector2",
    [3] = "SetVector3",
    [4] = "SetVector4"
}

PropTypeToField = {
    [1] = "ScalarParameters",
    [2] = "Vector2Parameters",
    [3] = "Vector3Parameters",
    [4] = "VectorParameters"
}

PropTypeToLSXValueType = {
    [1] = "float",
    [2] = "fvec2",
    [3] = "fvec3",
    [4] = "fvec4"
}

---@param materialName string
---@return MaterialProxy? mp
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

function MaterialProxy:__init(materialName)
    local res = Ext.Resource.Get(materialName, "Material") --[[@as ResourceMaterialResource]]
    if not res then
        Error("MaterialProxy: Could not find material: " .. tostring(materialName))
        return
    end

    self.Material = materialName
    self.MaterialType = res.MaterialType
    self.SourceFile = res.SourceFile
    self.TypeRefs = {}
    self.IndexRefs = {}
    self.BaseValues = {}
    self.Parameters = {
        [1] = {}, -- ScalarParameters
        [2] = {}, -- Vector2Parameters
        [3] = {}, -- Vector3Parameters
        [4] = {}, -- VectorParameters
    }
    local params = {
        res.ScalarParameters,
        res.Vector2Parameters,
        res.Vector3Parameters,
        res.VectorParameters
    }

    for i=1,4 do
        self.BaseValues[i] = {}
    end

    for num, paramList in pairs(params) do
        self.IndexRefs[num] = {}
        for i, param in pairs(paramList) do
            local value = type(param.Value) == "number" and {param.Value} or param.Value --[[@as number[] ]]
            if self.Parameters[num][param.ParameterName] then
                Warning("MaterialProxy: Duplicate material parameter name '" .. param.ParameterName .. "' in material '" .. materialName .. "'. Overwriting previous value.")
            end
            self.TypeRefs[param.ParameterName] = num -- so I just assume that parameter names are unique
            self.IndexRefs[num][param.ParameterName] = i
            self.Parameters[num][param.ParameterName] = value
            self.BaseValues[num][param.ParameterName] = value
        end
    end

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

    local mP = setmetatable({}, MaterialPresetProxy) --[[@as MaterialPresetProxy]]
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

    self.Material = res.Presets.MaterialResource
    self.Preset = materialPresetName
    self.SorceFile = res.SourceFile
    self.TypeRefs = {}
    self.IndexRefs = {}
    self.BaseValues = {}
    self.Parameters = {
        [1] = {}, -- ScalarParameters
        [2] = {}, -- Vector2Parameters
        [3] = {}, -- Vector3Parameters
        [4] = {}, -- VectorParameters
    }

    local params = {
        res.Presets.ScalarParameters,
        res.Presets.Vector2Parameters,
        res.Presets.Vector3Parameters,
        res.Presets.VectorParameters
    }

    for i=1,4 do
        self.Parameters[i] = {}
        self.BaseValues[i] = {}
        self.IndexRefs[i] = {}
    end

    for num, paramList in pairs(params) do
        for i, param in pairs(paramList) do

            local parameterName = param.Parameter
            local value = type(param.Value) == "number" and {param.Value} or param.Value --[[@as number[] ]]
            if self.Parameters[num][parameterName] then
                _D(params)
                Warning("MaterialPresetProxy: Duplicate material parameter name '" .. parameterName .. "' in material preset '" .. materialPresetName .. "'. Overwriting previous value.")
            end

            self.TypeRefs[parameterName] = num
            self.IndexRefs[num][parameterName] = i
            self.Parameters[num][parameterName] = value
            self.BaseValues[num][parameterName] = value
            ::continue::
        end
    end
end

function ParametersSetProxy.new(paramSet)
    if not paramSet then return nil end

    if materialProxies[paramSet] then
        return materialProxies[paramSet]
    end

    local mP = setmetatable({}, ParametersSetProxy) --[[@as ParametersSetProxy]]
    mP:__init(paramSet)

    return mP
end

---@param paramSet MaterialParametersSet
function ParametersSetProxy:__init(paramSet)
    if not paramSet then
        Error("ParameterSetProxy: Could not find parameter set: " .. tostring(paramSet))
        return
    end

    self.TypeRefs = {}
    self.IndexRefs = {}
    self.BaseValues = {}
    self.Parameters = {
        [1] = {}, -- ScalarParameters
        [2] = {}, -- Vector2Parameters
        [3] = {}, -- Vector3Parameters
        [4] = {}, -- VectorParameters
    }

    for i=1,4 do
        self.Parameters[i] = {}
        self.BaseValues[i] = {}
        self.IndexRefs[i] = {}
    end

    local params = {
        paramSet.ScalarParameters,
        paramSet.Vector2Parameters,
        paramSet.Vector3Parameters,
        paramSet.VectorParameters
    }

    for num, paramList in pairs(params) do
        for i, param in pairs(paramList) do
            local parameterName = param.ParameterName
            local value = type(param.Value) == "number" and {param.Value} or param.Value --[[@as number[] ]]
            if self.Parameters[num][parameterName] then
                Warning("ParameterSetProxy: Duplicate material parameter name '" .. parameterName .. "' in parameter set. Overwriting previous value.")
            end

            self.TypeRefs[parameterName] = num
            self.IndexRefs[num][parameterName] = i
            self.Parameters[num][parameterName] = value
            self.BaseValues[num][parameterName] = value
            ::continue::
        end
    end
end

function ParametersSetProxy:GetParameter(paramName)
    local typeRef = self.TypeRefs[paramName]
    if not typeRef then
        return nil
    end

    local indexRef = self.IndexRefs[typeRef][paramName]
    if not indexRef then
        return nil
    end

    local param = nil
    param = self.Parameters[typeRef][paramName]
    if not param then
        return nil
    end

    return param
end

---@return ResourceMaterialResource
function MaterialProxy:GetResource()
    local res = Ext.Resource.Get(self.Material, "Material") --[[@as ResourceMaterialResource]]
    return res
end

--- @param paramName string
--- @return ResourceMaterialResourceScalarParameter|ResourceMaterialResourceVector2Parameter|ResourceMaterialResourceVector3Parameter|ResourceMaterialResourceVector4Parameter|nil
function MaterialProxy:GetParamObject(paramName)
    local typeRef = self.TypeRefs[paramName]
    if not typeRef then
        return nil
    end

    local indexRef = self.IndexRefs[typeRef][paramName]
    if not indexRef then
        return nil
    end

    local res = Ext.Resource.Get(self.Material, "Material") --[[@as ResourceMaterialResource]]
    if not res then
        Error("MaterialProxy: Could not find material: " .. tostring(self.Material))
        return nil
    end

    local param = nil
    param = res[PropTypeToField[typeRef]][indexRef]

    if param.ParameterName ~= paramName then
        -- fallback (search by name)
        for i, p in pairs(res[PropTypeToField[typeRef]]) do
            if p.ParameterName == paramName then
                param = p
                break
            end
        end
    end

    if param.ParameterName ~= paramName then
        Error("MaterialProxy: Could not find parameter object for '" .. tostring(paramName) .. "' in material: " .. tostring(self.Material))
        return nil
    end

    return param
end

--- @param paramName string
--- @return number[]|nil
function MaterialProxy:GetParameter(paramName)
    local typeRef = self.TypeRefs[paramName]
    if not typeRef then
        return nil
    end

    local indexRef = self.IndexRefs[typeRef][paramName]
    if not indexRef then
        return nil
    end

    local res = Ext.Resource.Get(self.Material, "Material") --[[@as ResourceMaterialResource]]
    if not res then
        Error("MaterialProxy: Could not find material: " .. tostring(self.Material))
        return nil
    end

    local param = nil
    param = res[PropTypeToField[typeRef]][indexRef]
    if not param then
        return nil
    end

    local value = param.Value
    if type(value) == "number" then
        value = {value}
    end

    return value
end

function MaterialProxy:GetParameterType(paramName)
    return self.TypeRefs[paramName]
end

---@return ResourceMaterialPresetResource
function MaterialPresetProxy:GetResource()
    local res = Ext.Resource.Get(self.Preset, "MaterialPreset") --[[@as ResourceMaterialPresetResource]]
    return res
end

---@param paramName string
---@return ResourcePresetDataScalarParameter|ResourcePresetDataVector2Parameter|ResourcePresetDataVector3Parameter|ResourcePresetDataVectorParameter|nil
function MaterialPresetProxy:GetParamObject(paramName)
    local typeRef = self.TypeRefs[paramName]
    if not typeRef then
        return nil
    end

    local indexRef = self.IndexRefs[typeRef][paramName]
    if not indexRef then
        return nil
    end

    local res = Ext.Resource.Get(self.Preset, "MaterialPreset") --[[@as ResourceMaterialPresetResource]]
    if not res then
        Error("MaterialPresetProxy: Could not find material preset: " .. tostring(self.Material))
        return nil
    end

    local param = nil
    param = res.Presets[PropTypeToField[typeRef]][indexRef]

    if param.Parameter ~= paramName then
        -- fallback (search by name)
        for i, p in pairs(res.Presets[PropTypeToField[typeRef]]) do
            if p.Parameter == paramName then
                param = p
                break
            end
        end
    end

    if param.Parameter ~= paramName then
        Error("MaterialPresetProxy: Could not find parameter object for '" .. tostring(paramName) .. "' in material preset: " .. tostring(self.Material))
        return nil
    end

    return param
end

---@param paramName string
---@return number[]|nil
function MaterialPresetProxy:GetParameter(paramName)
    local typeRef = self.TypeRefs[paramName]
    if not typeRef then
        return nil
    end

    local indexRef = self.IndexRefs[typeRef][paramName]
    if not indexRef then
        return nil
    end

    local res = Ext.Resource.Get(self.Preset, "MaterialPreset") --[[@as ResourceMaterialPresetResource]]
    if not res then
        Error("MaterialPresetProxy: Could not find material preset: " .. tostring(self.Material))
        return nil
    end

    local param = nil
    param = res.Presets[PropTypeToField[typeRef]][indexRef]
    if not param then
        return nil
    end

    local value = param.Value
    if type(value) == "number" then
        value = {value}
    end

    return value
end

function MaterialProxy:HasParameter(paramName)
    return self.TypeRefs[paramName] ~= nil
end

function MaterialProxy:GetValue(paramName)
    local typeRef = self.TypeRefs[paramName]
    if not typeRef then
        return nil
    end

    return self.Parameters[typeRef][paramName]
end


function MaterialProxy:GetBaseValue(paramName)
    local typeRef = self.TypeRefs[paramName]
    if not typeRef then
        return nil
    end

    return self.BaseValues[typeRef][paramName]
end

function MaterialPresetProxy:GetBaseValue()
    Error("MaterialPresetProxy: Cannot get base value on material preset.")
    return nil
end

function MaterialProxy:GetAllProperties()
    return self.Parameters
end

function MaterialProxy:GetAllScalarParameterNames()
    local scalars = {}
    for propertyName,_ in pairs(self.IndexRefs[1]) do
        table.insert(scalars, propertyName)
    end
    table.sort(scalars)
    return scalars
end

function MaterialProxy:GetAllVector2ParameterNames()
    local vec2s = {}
    for propertyName,_ in pairs(self.IndexRefs[2]) do
        table.insert(vec2s, propertyName)
    end
    table.sort(vec2s)
    return vec2s
end

function MaterialProxy:GetAllVector3ParameterNames()
    local vec3s = {}
    for propertyName,_ in pairs(self.IndexRefs[3]) do
        table.insert(vec3s, propertyName)
    end
    table.sort(vec3s)
    return vec3s
end

function MaterialProxy:GetAllVector4ParameterNames()
    local vec4s = {}
    for propertyName,_ in pairs(self.IndexRefs[4]) do
        table.insert(vec4s, propertyName)
    end
    table.sort(vec4s)
    return vec4s
end

--- @param mat Material
function MaterialProxy:ApplyToMaterial(mat)
    for typeRef,props in pairs(self.Parameters) do
        for propertyName,value in pairs(props) do
            if mat[PropTypeToFunc[typeRef]] then
                local val = #value == 1 and value[1] or value
                mat[PropTypeToFunc[typeRef]](mat, propertyName, val)
            end
        end
    end
end
