local materialProxies = {}

--- @class MaterialProxy
--- @field Material GUIDSTRING
--- @field TypeRefs table<string, 1|2|3|4> Mapping of property name to type (1=Scalar, 2=Vector2, 3=Vector3, 4=Vector4)
--- @field IndexRefs table<1|2|3|4, table<string, number>> Mapping of type to property name to index in resource
--- @field BaseValues table<number, table<string, number[]>> Mapping of type to property name to base value
--- @field Parameters table<number, table<string, number[]>> Mapping of type to property name to current value
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
--- @field new fun(materialPresetName: GUIDSTRING): MaterialPresetProxy|nil
MaterialPresetProxy = {}
MaterialPresetProxy.__index = MaterialPresetProxy
setmetatable(MaterialPresetProxy, {__index = MaterialProxy})

--- @class CustomMaterialProxy : MaterialProxy
--- @field new fun(parameters: table<string, number[]>, originMaterial: GUIDSTRING): CustomMaterialProxy|nil
--- @field SetValue fun(self, propertyName: string, value: number[]): boolean
--- @field ResetValue fun(self, propertyName: string): boolean
--- @field ResetAll fun(self): boolean
CustomMaterialProxy = {}
CustomMaterialProxy.__index = CustomMaterialProxy
setmetatable(CustomMaterialProxy, {__index = MaterialProxy})

PropTypeToFunc = {
    [1] = "SetScalar",
    [2] = "SetVector2",
    [3] = "SetVector3",
    [4] = "SetVector4"
}

PropTypeToFiled = {
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

function CustomMaterialProxy.new(parameters, originMaterial)
    if not originMaterial then
        Error("CustomMaterialProxy: originMaterial is required.")
        return nil
    end

    local originProxy = MaterialProxy.new(originMaterial)
    if not originProxy then
        Error("CustomMaterialProxy: Could not create origin material proxy for '" .. tostring(originMaterial) .. "'.")
        return nil
    end

    local copy = DeepCopy(originProxy)

    local mP = setmetatable(copy, CustomMaterialProxy) --[[@as CustomMaterialProxy]]
    mP.Material = Uuid_v4()

    for propertyName,value in pairs(parameters) do
        local typeRef = originProxy.TypeRefs[propertyName]
        if not typeRef then
            Warning("CustomMaterialProxy: Property '" .. tostring(propertyName) .. "' does not exist on origin material '" .. tostring(originMaterial) .. "'. Skipping.")
        else
            if #value ~= typeRef then
                Warning("CustomMaterialProxy: Invalid value for property '" .. tostring(propertyName) .. "' in custom material. Expected " .. tostring(typeRef) .. " values, got " .. tostring(#value) .. ". Skipping.")
            else
                mP.Parameters[typeRef][propertyName] = value
            end
        end
    end

    return mP
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
    end

    for num, paramList in pairs(params) do
        for i, param in pairs(paramList) do

            local parameterName = param.Parameter
            local value = type(param.Value) == "number" and {param.Value} or param.Value --[[@as number[] ]]
            if self.Parameters[num][parameterName] then
                Warning("MaterialPresetProxy: Duplicate material parameter name '" .. parameterName .. "' in material preset '" .. materialPresetName .. "'. Overwriting previous value.")
            end

            self.TypeRefs[parameterName] = num
            self.IndexRefs[parameterName] = i
            self.Parameters[num][parameterName] = value
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

--- @param propertyName string
--- @return ResourceMaterialResourceParameter
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
    param = res[PropTypeToFiled[typeRef]][indexRef]
    if not param then
        return nil
    end

    return param
end

---@param propertyName string
---@return ResourcePresetDataScalarParameter|ResourcePresetDataVector2Parameter|ResourcePresetDataVector3Parameter|ResourcePresetDataVectorParameter|nil
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
    param = res.Presets[PropTypeToFiled[typeRef]][indexRef]
    if not param then
        return nil
    end

    return param
end

function CustomMaterialProxy:GetProperty(propertyName)
    Error("CustomMaterialProxy: Cannot get property on custom material.")
    return nil
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

function CustomMaterialProxy:SetProperty(propertyName, value)
    Error("CustomMaterialProxy: Cannot set property on custom material.")
    return false
end

function MaterialProxy:HasProperty(propertyName)
    return self.TypeRefs[propertyName] ~= nil
end

function MaterialProxy:GetValue(propertyName)
    local typeRef = self.TypeRefs[propertyName]
    if not typeRef then
        return nil
    end

    return self.Parameters[typeRef][propertyName]
end

function CustomMaterialProxy:SetValue(propertyName, value)
    local typeRef = self.TypeRefs[propertyName]
    if not typeRef then
        Error("CustomMaterialProxy: Could not find property '" .. tostring(propertyName) .. "' in material '" .. tostring(self.Material) .. "'")
        return false
    end

    if #value ~= typeRef then
        Error("CustomMaterialProxy: Invalid value for property '" .. tostring(propertyName) .. "' in material '" .. tostring(self.Material) .. "'. Expected " .. tostring(typeRef) .. " values, got " .. tostring(#value))
        return false
    end

    self.Parameters[typeRef][propertyName] = value
    return true
end

function CustomMaterialProxy:ResetValue(propertyName)
    local typeRef = self.TypeRefs[propertyName]
    if not typeRef then
        Error("CustomMaterialProxy: Could not find property '" .. tostring(propertyName) .. "' in material '" .. tostring(self.Material) .. "'")
        return false
    end
    local originProxy = MaterialProxy.new(self.Material)
    if not originProxy then
        Error("CustomMaterialProxy: Could not find origin material proxy for '" .. tostring(self.Material) .. "'.")
        return false
    end

    self.Parameters[typeRef][propertyName] = originProxy.Parameters[typeRef][propertyName]
    return true
end

function CustomMaterialProxy:ResetAll()
    local originProxy = MaterialProxy.new(self.Material)
    if not originProxy then
        Error("CustomMaterialProxy: Could not find origin material proxy for '" .. tostring(self.Material) .. "'.")
        return false
    end

    for typeRef,props in pairs(originProxy.Parameters) do
        for propertyName,value in pairs(props) do
            self.Parameters[typeRef][propertyName] = value
        end
    end

    return true
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
    return self.Parameters
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
    for typeRef,props in pairs(self.Parameters) do
        for propertyName,value in pairs(props) do
            if mat[PropTypeToFunc[typeRef]] then
                local val = #value == 1 and value[1] or value
                mat[PropTypeToFunc[typeRef]](mat, propertyName, val)
            end
        end
    end
end

local function whatLSXType(value)
    if type(value) == "boolean" then
        return "bool"
    elseif type(value) == "number" then
        return "float"
    elseif type(value) == "string" then
        return 
    elseif type(value) == "table" then
        if #value == 2 then
            return "fvec2"
        elseif #value == 3 then
            return "fvec3"
        elseif #value == 4 then
            return "fvec4"
        end
    end
end

---@param materialProxy MaterialProxy
---@param propertyName string
---@param customParam number[]
---@return LSXTableNode|nil
local function createParameterNode(materialProxy, propertyName, customParam)

    local originProperty = materialProxy:GetProperty(propertyName)
    if not originProperty then
        Error("createParameterNode: Could not find property '" .. tostring(propertyName) .. "' in material '" .. tostring(materialProxy.Material) .. "'.")
        return nil
    end

    local saveParam = #customParam == 1 and customParam[1] or customParam
    local valueType = PropTypeToLSXValueType[#customParam]
    local node = {
        id = PropTypeToFiled[#customParam],
    }

    local lsxNode = LSXTableNode.new("node")

    for k,v in pairs(originProperty) do
        local attr = nil
        if k ~= "Value" then
            attr = {
                id = k,
                type = whatLSXType(v),
                value = v
            }
        else
            attr = {
                id = "Value",
                type = valueType,
                value = saveParam
            }
        end
        local attrNode = LSXTableNode.new("attribute", attr)
        lsxNode:AppendChild(attrNode)
    end

    return lsxNode
end

function CustomMaterialProxy:ExportToLSX()
    local originProxy = MaterialProxy.new(self.Material)
    if not originProxy then
        Error("CustomMaterialProxy: Could not find origin material proxy for '" .. tostring(self.Material) .. "'. Cannot export to LSX.")
        return nil
    end

    local root = LSXTable.new()
    if not root then
        Error("CustomMaterialProxy: Could not create LSXTableNode for export.")
        return nil
    end

    local matRegion = LSXTableNode.new("region", {id="MaterialBank"})
    root:AppendChild(matRegion)
    local matNode = LSXTableNode.new("node", {id="MaterialBank"})
    matRegion:AppendChild(matNode)
    local childrenWrapper = LSXTable.ChildrenWrapper(matNode)
    local resNode = LSXTableNode.new("node", {id="Resource"})
    childrenWrapper:AppendChild(resNode)

    local baseAttr = {
        LSXTableNode.new("attribute", {
            id = "Id",
            type = LSXTableValueType.guid,
            value = self.Material
        }),
        LSXTableNode.new("attribute", {
            id = "Name",
            type = LSXTableValueType.LSString,
            value = "Custom Material"
        }),
        LSXTableNode.new("attribute", {
            id = "SourceFile",
            type = LSXTableValueType.LSString,
            value = self.SourceFile or ""
        }),
        LSXTableNode.new("attribute", {
            id = "MaterialType",
            type = LSXTableValueType.uint8,
            value = self.MaterialType or 0
        })
    }
    for _,attr in pairs(baseAttr) do
        resNode:AppendChild(attr)
    end

    
    local secondChildrenWrapper = LSXTable.ChildrenWrapper(resNode)
    for typeRef,props in pairs(self.Parameters) do
        for propertyName,value in pairs(props) do
            local paramNode = createParameterNode(originProxy, propertyName, value)
            if paramNode then
                secondChildrenWrapper:AppendChild(paramNode)
            end
        end
    end

    return root:Stringify()
end