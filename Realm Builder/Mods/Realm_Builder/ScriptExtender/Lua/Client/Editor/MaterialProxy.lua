local materialProxies = {}

--- @alias ParamterName string
--- @enum RB_MaterialParamType
RB_MaterialParamType = {
    Scalar = 1,
    Vector2 = 2,
    Vector3 = 3,
    Vector4 = 4,
    Texture2D = 5,
    VirtualTexture = 6,
    [1] = "Scalar",
    [2] = "Vector2",
    [3] = "Vector3",
    [4] = "Vector4",
    [5] = "Texture2D",
    [6] = "VirtualTexture",
}

--- @alias RB_ParameterSet table< RB_MaterialParamType, table<ParamterName, number|number[]|string> >

--- @class MaterialProxy
--- @field Material GUIDSTRING
--- @field TypeRefs table<string, RB_MaterialParamType> Mapping of property name to type
--- @field IndexRefs table<RB_MaterialParamType, table<ParamterName, number>> Mapping of type to property name to index in resource
--- @field BaseValues RB_ParameterSet Mapping of type to property name to base value
--- @field Parameters RB_ParameterSet
--- @field new fun(materialName: GUIDSTRING): MaterialProxy|nil
--- @field GetResource fun(self): ResourceMaterialResource
--- @field GetParameter fun(self, paramName: string): number|number[]|string|nil
--- @field SetParameter fun(self, paramName: string, value: number[]): boolean
--- @field GetValue fun(self, paramName: string): number|number[]|string|nil
--- @field GetBaseValue fun(self, paramName: string): number|number[]|string|nil
--- @field ResetParameter fun(self, paramName: string): boolean
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
--- @field RemoveParameter fun(self, paramName: string): boolean
--- @field Update fun(self)
--- @field new fun(paramSetName: MaterialParameters?): ParametersSetProxy|nil
ParametersSetProxy = {}
ParametersSetProxy.__index = ParametersSetProxy
setmetatable(ParametersSetProxy, {__index = MaterialProxy})


ParamTypeToFunc = {
    [1] = "SetScalar",
    [2] = "SetVector2",
    [3] = "SetVector3",
    [4] = "SetVector4",
    [5] = "SetTexture2D",
    [6] = "SetVirtualTexture",
}

ParamTypeToField = {
    [1] = "ScalarParameters",
    [2] = "Vector2Parameters",
    [3] = "Vector3Parameters",
    [4] = "VectorParameters",
    [5] = "Texture2DParameters",
    [6] = "VirtualTextureParameters",
}

ParamTypeToLSValueType = {
    [1] = "float",
    [2] = "fvec2",
    [3] = "fvec3",
    [4] = "fvec4",
    [5] = "FixedString",
    [6] = "FixedString",
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

function MaterialProxy.__buildParameterTables(self, paramsList, name, fieldName, valueField)
    self.TypeRefs = {}
    self.IndexRefs = {}
    self.BaseValues = {}
    self.Parameters = {}
    for i = 1, #paramsList do
        self.Parameters[i] = {}
        self.BaseValues[i] = {}
        self.IndexRefs[i] = {}
    end

    for typeRef, paramList in ipairs(paramsList) do
        if typeRef > 4 then valueField = "ID" end
        for i, param in pairs(paramList or {}) do
            local paramName = param[fieldName]
            if paramName == "" then
                --Warning(string.format("Invalid parameter name in '%s' at index %d. Skipping.", name, i))
                goto continue
            end
            local value = param[valueField]
            if self.Parameters[typeRef][paramName] then
                Warning(string.format("Duplicate parameter '%s' in '%s'. Overwriting.", paramName, name))
            end

            self.TypeRefs[paramName] = typeRef
            self.IndexRefs[typeRef][paramName] = i
            self.Parameters[typeRef][paramName] = value
            self.BaseValues[typeRef][paramName] = value
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
    self.MaterialType = res.MaterialType
    self.SourceFile = res.SourceFile
    
    MaterialProxy.__buildParameterTables(self, {
        res.ScalarParameters,
        res.Vector2Parameters,
        res.Vector3Parameters,
        res.VectorParameters,
        res.Texture2DParameters,
        res.VirtualTextureParameters,
    }, materialName, "ParameterName", "Value")
end

function MaterialProxy:GetResource()
    local typeName = self.Preset and "MaterialPreset" or "Material"
    local id = self.Preset or self.Material
    local res = Ext.Resource.Get(id, typeName) --[[@as ResourceMaterialResource]]
    return res
end

function MaterialProxy:GetParamObject(paramName)
    local typeRef = self.TypeRefs[paramName]
    if not typeRef then return nil end

    local res = self:GetResource()
    local container = self.Preset and res.Presets or res
    local list = container[ParamTypeToField[typeRef]]
    if not list then return nil end

    for _, param in pairs(list) do
        local pname = param.ParameterName or param.Parameter
        if pname == paramName then
            return param
        end
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

    local mP = setmetatable({}, MaterialPresetProxy) --[[@as MaterialPresetProxy]]
    mP:__init(materialPresetName, isMaterialPreset)
    if mP.Material then
        materialProxies[materialPresetName] = mP
        return mP
    end

    return nil
end

function MaterialPresetProxy:__init(materialPresetName, res)
    res = res or Ext.Resource.Get(materialPresetName, "MaterialPreset") --[[@as ResourceMaterialPresetResource]]
    if not res then
        Error("MaterialPresetProxy: Could not find material preset: " .. tostring(materialPresetName))
        return
    end

    self.Material = res.Presets.MaterialResource
    self.Preset = materialPresetName
    self.SorceFile = res.SourceFile
    
    MaterialProxy.__buildParameterTables(self, {
        res.Presets.ScalarParameters,
        res.Presets.Vector2Parameters,
        res.Presets.Vector3Parameters,
        res.Presets.VectorParameters,
        res.Presets.Texture2DParameters,
        res.Presets.VirtualTextureParameters,
    }, materialPresetName, "Parameter", "Value")
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

--- copy from format parameters
--- @param params RB_ParameterSet
function ParametersSetProxy.BuildFromFormatParameters(params)
    local paramSetProxy = setmetatable({}, ParametersSetProxy) --[[@as ParametersSetProxy]]
    paramSetProxy.TypeRefs = {}
    paramSetProxy.IndexRefs = {}
    paramSetProxy.Parameters = {
        [1] = {}, -- ScalarParameters
        [2] = {}, -- Vector2Parameters
        [3] = {}, -- Vector3Parameters
        [4] = {}, -- VectorParameters
        [5] = {}, -- Texture2DParameters
        [6] = {}, -- VirtualTextureParameters
    }

    for i=1, #paramSetProxy.Parameters do
        paramSetProxy.Parameters[i] = {}
        paramSetProxy.IndexRefs[i] = {}
    end

    for itype, paramList in pairs(params) do
        for parameterName, value in pairs(paramList) do
            paramSetProxy.TypeRefs[parameterName] = itype
            paramSetProxy.Parameters[itype][parameterName] = value
            ::continue::
        end
    end

    return paramSetProxy
end

function ParametersSetProxy.BuildFromResourcePresetData(paramSet)
    local paramSetProxy = setmetatable({}, ParametersSetProxy) --[[@as ParametersSetProxy]]
    
    MaterialProxy.__buildParameterTables(paramSetProxy, {
        paramSet.ScalarParameters,
        paramSet.Vector2Parameters,
        paramSet.Vector3Parameters,
        paramSet.VectorParameters,
        paramSet.Texture2DParameters,
        paramSet.VirtualTextureParameters,
    }, "ParameterSet", "Parameter", "Value")

    return paramSetProxy
end

---@param paramSet MaterialParameters
function ParametersSetProxy:__init(paramSet)
    MaterialProxy.__buildParameterTables(self, {
        paramSet.ScalarParameters,
        paramSet.Vector2Parameters,
        paramSet.Vector3Parameters,
        paramSet.VectorParameters,
        paramSet.Texture2DParameters,
        paramSet.VirtualTextureParameters,
    }, "ParameterSet", "ParameterName", "Value")

    return self
end

function ParametersSetProxy:GetParameter(paramName)
    local typeRef = self.TypeRefs[paramName]
    if not typeRef then
        return nil
    end

    local param = self.Parameters[typeRef][paramName]
    if not param then
        return nil
    end

    return param, typeRef
end

function ParametersSetProxy:SetParameter(paramName, value, typeRef)
    if type(value) == "string" and not typeRef then
        Warning("ParametersSetProxy: When setting string parameter '" .. tostring(paramName) .. "', typeRef must be provided.")
        return false
    elseif type(value) == "number" then
        typeRef = 1
    else
        typeRef = #value
    end

    if not typeRef or typeRef < 1 or typeRef > 6 then
        return false
    end

    local existingType = self.TypeRefs[paramName]

    -- New parameter
    if not existingType then
        self.TypeRefs[paramName] = typeRef
    end

    -- Type mismatch
    if existingType and existingType ~= typeRef then
        return false
    end

    -- Set value
    self.Parameters[typeRef][paramName] = value
    return true
end

--- @param paramSet MaterialParameters
function ParametersSetProxy:Update(paramSet)
    local valueField = "Value"
    for typeRef, paramList in pairs({
        paramSet.ScalarParameters,
        paramSet.Vector2Parameters,
        paramSet.Vector3Parameters,
        paramSet.VectorParameters,
        paramSet.Texture2DParameters,
        paramSet.VirtualTextureParameters,
    }) do
        if typeRef > 4 then valueField = "ID" end
        for _, param in FilteredPairs(paramList or {}, function(_, a)
            return not self.TypeRefs[a.ParameterName] -- only new parameters
        end) do
            local paramName = param.ParameterName
            local value = param[valueField]

            self.TypeRefs[paramName] = typeRef
            self.Parameters[typeRef][paramName] = value
        end
    end
end

function ParametersSetProxy:SetDefaultParameter(paramName, value, typeRef)
    if type(value) == "string" and not typeRef then
        Warning("ParametersSetProxy: When setting string parameter '" .. tostring(paramName) .. "', typeRef must be provided.")
        return false
    elseif type(value) == "number" then
        typeRef = 1
    else
        typeRef = #value
    end

    if not typeRef or typeRef < 1 or typeRef > 6 then
        return false
    end

    local existingType = self.TypeRefs[paramName]

    -- New parameter, skipping
    if not existingType then
        return false
    end

    -- Type mismatch
    if existingType and existingType ~= typeRef then
        return false
    end

    -- Set value
    self.Parameters[typeRef][paramName] = value
    return true
end

function ParametersSetProxy:RemoveParameter(paramName)
    local typeRef = self.TypeRefs[paramName]
    if not typeRef then
        return false
    end

    self.Parameters[typeRef][paramName] = nil
    self.TypeRefs[paramName] = nil
    return true
end


--- @param paramSet RB_ParameterSet
function ParametersSetProxy:Merge(paramSet)
    for paramType, params in pairs(paramSet) do
        for paramName, value in pairs(params) do
            self:SetParameter(paramName, value, paramType)
        end
    end
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
    param = res[ParamTypeToField[typeRef]][indexRef]
    if not param then
        return nil
    end

    local value = param.Value

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
    param = res.Presets[ParamTypeToField[typeRef]][indexRef]
    if not param then
        return nil
    end

    local value = param.Value

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
    for propertyName,_ in pairs(self.Parameters[1]) do
        table.insert(scalars, propertyName)
    end
    table.sort(scalars)
    return scalars
end

function MaterialProxy:GetAllVector2ParameterNames()
    local vec2s = {}
    for propertyName,_ in pairs(self.Parameters[2]) do
        table.insert(vec2s, propertyName)
    end
    table.sort(vec2s)
    return vec2s
end

function MaterialProxy:GetAllVector3ParameterNames()
    local vec3s = {}
    for propertyName,_ in pairs(self.Parameters[3]) do
        table.insert(vec3s, propertyName)
    end
    table.sort(vec3s)
    return vec3s
end

function MaterialProxy:GetAllVector4ParameterNames()
    local vec4s = {}
    for propertyName,_ in pairs(self.Parameters[4]) do
        table.insert(vec4s, propertyName)
    end
    table.sort(vec4s)
    return vec4s
end

function MaterialProxy:GetAllTexture2DParameterNames()
    local textures = {}
    for propertyName,_ in pairs(self.Parameters[5]) do
        table.insert(textures, propertyName)
    end
    table.sort(textures)
    return textures
end

function MaterialProxy:GetAllVirtualTextureParameterNames()
    local vtextures = {}
    for propertyName,_ in pairs(self.Parameters[6]) do
        table.insert(vtextures, propertyName)
    end
    table.sort(vtextures)
    return vtextures
end

--- @param mat Material
function MaterialProxy:ApplyToMaterial(mat)
    for typeRef,props in pairs(self.Parameters) do
        for propertyName,value in pairs(props) do
            if mat[ParamTypeToFunc[typeRef]] then
                mat[ParamTypeToFunc[typeRef]](mat, propertyName, value)
            end
        end
    end
end