--- @class MaterialEditor
--- @field Material string -- origin Material UUID
--- @field SourceFile string
--- @field MaterialType number
--- @field DiffusionProfileUUID string
--- @field ParamSetProxy ParametersSetProxy -- ParameterSetProxy instance for easier parameter access
--- @field Instance fun():Material
--- @field ParamsSrc fun():MaterialParametersSet
--- @field new fun(originMaterial: GUIDSTRING, matSrc:fun():Material , paramsSrc:fun():MaterialParametersSet):MaterialEditor
MaterialEditor = _Class("MaterialEditor")

---@param originMaterial string
---@param matSrc fun():Material
---@param paramsSrc fun():MaterialParametersSet
function MaterialEditor:__init(originMaterial, matSrc, paramsSrc)
    local matRes = Ext.Resource.Get(originMaterial, "Material") --[[@as ResourceMaterialResource]]
    if not matRes then
        Error("MaterialEditor: Could not find origin material resource for '" .. tostring(originMaterial) .. "'.")
        return
    end

    self.Material = originMaterial or ""
    self.SourceFile = LSXHelpers.GetPathAfterData(matRes.SourceFile or "")
    self.MaterialType = matRes.MaterialType or 0
    self.DiffusionProfileUUID = matRes.DiffusionProfileUUID or ""

    self.ParamSetProxy = ParametersSetProxy.new(paramsSrc()) --[[@as ParametersSetProxy]]

    self.ParamsSrc = paramsSrc
    self.Instance = matSrc

    self.Parameters = {
        [1] = {}, -- ScalarParameters
        [2] = {}, -- Vector2Parameters
        [3] = {}, -- Vector3Parameters
        [4] = {}, -- VectorParameters
        [5] = {}, -- Texture2DParameters
        [6] = {}, -- VirtualTextureParameters
    }
end

--- @param params RB_ParameterSet
function MaterialEditor:SetDefaultParameters(params)
    for ptype,paramsTable in pairs(params) do
        for paramName,value in pairs(paramsTable) do
            self.ParamSetProxy:SetDefaultParameter(paramName, value, ptype)     
        end
    end

    return true
end

---@param paramName string
---@return number[]?, RB_ParamType?
function MaterialEditor:GetParameter(paramName)
    local ptype = self.ParamSetProxy:GetParameterType(paramName)
    if not ptype then
        Warning("MaterialEditor: Could not determine parameter type for '" .. tostring(paramName) .. "'.")
        return nil
    end

    local value = self.Parameters[ptype][paramName]

    if not value then
        local proxyParam = self.ParamSetProxy:GetParameter(paramName)

        if not proxyParam then
            Warning("MaterialEditor: Could not find parameter '" .. tostring(paramName) .. "' in material proxy for material '" .. tostring(self.Material) .. "'.")
            return nil
        end
        value = proxyParam
    end

    return value, ptype
end

function MaterialEditor:HasChanged(paramName)
    local ptype = self.ParamSetProxy:GetParameterType(paramName)
    if not ptype then
        Warning("MaterialEditor: Could not determine parameter type for '" .. tostring(paramName) .. "'.")
        return false
    end

    local currentValue = self.Parameters[ptype][paramName]

    return currentValue ~= nil
end

function MaterialEditor:HasChangeInType(paramType)
    if not self.Parameters[paramType] then
        Warning("MaterialEditor: Invalid parameter type '" .. tostring(paramType) .. "'.")
        return false
    end

    for _,_ in pairs(self.Parameters[paramType]) do
        return true
    end

    return false
end

function MaterialEditor:SetParameter(paramName, value, ptype)
    local mat = self.Instance()
    if not mat then return false end

    if type(value) == "string" and not ptype then
        Warning("MaterialEditor: When setting string parameter '" .. tostring(paramName) .. "', ptype must be provided.")
        return false
    else
        ptype = #value
    end

    local funcName = ParamTypeToFunc[ptype]
    local applyValue = #value == 1 and value[1] or value

    mat[funcName](mat, paramName, applyValue)

    self.Parameters[ptype][paramName] = value

    return true
end

function MaterialEditor:ResetParameter(paramName)
    local mat = self.Instance()
    if not mat then return false end

    local value, ptype = self.ParamSetProxy:GetParameter(paramName)

    if not value then
        Warning("MaterialEditor: Could not find parameter '" .. tostring(paramName) .. "' in material proxy for material '" .. tostring(self.Material) .. "'. Cannot reset.")
        return false
    end

    local funcName = ParamTypeToFunc[ptype]
    local applyValue = #value == 1 and value[1] or value

    mat[funcName](mat, paramName, applyValue)

    self.Parameters[ptype][paramName] = nil

    return true
end

---@param parameters RB_ParameterSet
---@return boolean
function MaterialEditor:ApplyParameters(parameters)
    local mat = self.Instance()
    if not mat then return false end

    for i,params in pairs(parameters) do
        i = tonumber(i) --[[@as number]]
        for paramName, value in pairs(params) do
            if not self.ParamSetProxy:GetParameterType(paramName) then goto continue end
            local applyValue = #value == 1 and value[1] or value

            if type(applyValue) == "string" then
                
            elseif #value ~= i then
                Warning("MaterialEditor: Parameter '" .. tostring(paramName) .. "' value length does not match parameter type. Skipping.")
                goto continue
            end

            mat[ParamTypeToFunc[i]](mat, paramName, applyValue)
            self.Parameters[i][paramName] = value
            ::continue::
        end
    end

    return true
end

---@return Vec4
function MaterialEditor:GetPreviewColor()
    --- traverse vec3 and vec4 parameters contains "Color" in their name and compute an color for preview
    
    return MaterialProxy.GetPreviewColor(self)
end

function MaterialEditor:ClearParameters()
    self.Parameters = {
        [1] = {}, -- ScalarParameters
        [2] = {}, -- Vector2Parameters
        [3] = {}, -- Vector3Parameters
        [4] = {}, -- VectorParameters
        [5] = {}, -- Texture2DParameters
        [6] = {}, -- VirtualTextureParameters
    }
end

function MaterialEditor:ResetAll()
    local mat = self.Instance()
    if not mat then
        --Error("MaterialEditor: Could not find material instance for material '" .. tostring(self.Material) .. "'.")
        return false
    end

    for ptype,params in pairs(self.ParamSetProxy.Parameters) do
        for paramName,value in pairs(params) do
            local funcName = ParamTypeToFunc[ptype]
            local applyValue = #value == 1 and value[1] or value

            mat[funcName](mat, paramName, applyValue)

            self.Parameters[ptype][paramName] = nil
        end
    end
end

function MaterialEditor:Reapply()
    self:ApplyParameters(self.Parameters)
end

function MaterialEditor:BuildMaterialPresetResource(path)
    local bank = LSXHelpers.BuildMaterialPresetBank()

    local uuid = Uuid_v4()
    local resource = ResourceHelpers.BuildMaterialPresetResourceNode(self.Parameters, uuid, "Custom_Material_Preset")

    bank:AppendChild(resource)

    return bank, uuid
end

