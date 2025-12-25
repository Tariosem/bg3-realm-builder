--- @class MaterialEditor
--- @field Material FixedString -- uuid of the material
--- @field SourceFile string
--- @field MaterialType MaterialType
--- @field DiffusionProfileUUID string
--- @field ParamSet ParametersSetProxy -- ParameterSetProxy instance for easier parameter access
--- @field Parameters RB_ParameterSet -- Table of changed parameters
--- @field Instance fun():AppliedMaterial?
--- @field ParamsSrc fun():MaterialParameters
--- @field new fun(originMaterial: GUIDSTRING, matSrc:fun():Material , paramsSrc:fun():MaterialParameters):MaterialEditor
MaterialEditor = _Class("MaterialEditor")

---@param originMaterial string
---@param matSrc fun():Material
---@param paramsSrc fun():MaterialParameters
function MaterialEditor:__init(originMaterial, matSrc, paramsSrc)
    local matRes = Ext.Resource.Get(originMaterial, "Material") --[[@as ResourceMaterialResource]]
    if not matRes then
        Error("MaterialEditor: Could not find origin material resource for '" .. tostring(originMaterial) .. "'.")
        return
    end

    self.Material = originMaterial or ""
    self.SourceFile = RBStringUtils.GetPathAfterData(matRes.SourceFile or "")

    --- populate all parameter names
    self.ParamSet = ParametersSetProxy.new(paramsSrc()) --[[@as ParametersSetProxy]]

    self.ParamsSrc = paramsSrc
    self.Instance = matSrc

    self:SaveCurrentParameters()

    self.Parameters = {
        [1] = {}, -- ScalarParameters
        [2] = {}, -- Vector2Parameters
        [3] = {}, -- Vector3Parameters
        [4] = {}, -- VectorParameters
        [5] = {}, -- Texture2DParameters
        [6] = {}, -- VirtualTextureParameters
    }
end

--- @param params RB_ParameterSet?
function MaterialEditor:SaveCurrentParameters(params)
    local params = params or self.ParamSet.Parameters
    local appliedMat = self.Instance()

    if not appliedMat then
        Warning("MaterialEditor: Could not find material instance for material '" .. tostring(self.Material) .. "'.")
        return false
    end

    for ptype,paramsTable in pairs(params) do
        for paramName,value in pairs(paramsTable) do
            local getFunc = MaterialEnums.ParamTypeToGetFunc[ptype]

            if not getFunc then
                if self.Parameters and self.Parameters[ptype] and self.Parameters[ptype][paramName] then
                    self.ParamSet:SetDefaultParameter(paramName, self.Parameters[ptype][paramName], ptype)
                end
                goto continue
            end

            local currentValue = appliedMat[getFunc](appliedMat, paramName)

            self.ParamSet:SetDefaultParameter(paramName, currentValue, ptype)
            ::continue::
        end
    end

    return true
end

---@param paramName string
---@return number|number[]|string?, RB_MaterialParamType?
function MaterialEditor:GetParameter(paramName)
    local ptype = self.ParamSet:GetParameterType(paramName)
    if not ptype then
        --Warning("MaterialEditor: Could not determine parameter type for '" .. tostring(paramName) .. "'.")
        return nil
    end

    local value = self.Parameters[ptype][paramName]

    if not value then
        local getFunc = MaterialEnums.ParamTypeToGetFunc[ptype]
        if not getFunc then
            value = self.ParamSet:GetParameter(paramName) --[[@as number|number[]|string]]
            return value, ptype
        end
        local appliedMat = self.Instance()
        if not appliedMat then
            Warning("MaterialEditor: Could not find material instance for material '" .. tostring(self.Material) .. "'.")
            return nil
        end
        value = appliedMat[getFunc](appliedMat, paramName)

        if not value then
            Warning("MaterialEditor: Could not find parameter '" .. tostring(paramName) .. "' in material proxy for material '" .. tostring(self.Material) .. "'.")
            return nil
        end
    end

    return value, ptype
end

function MaterialEditor:HasChanged(paramName)
    local ptype = self.ParamSet:GetParameterType(paramName)
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

    ptype = ptype or self.ParamSet:GetParameterType(paramName)
    if not ptype then
        --Warning("MaterialEditor: Could not find parameter '" .. tostring(paramName) .. "' in material proxy for material '" .. tostring(self.Material) .. "'. Cannot set.")
        return false
    end
    local funcName = MaterialEnums.ParamTypeToSetFunc[ptype]
    if not funcName then
        Warning("MaterialEditor: Invalid parameter type '" .. tostring(ptype) .. "' for parameter '" .. tostring(paramName) .. "'.")
        return false
    end

    mat[funcName](mat, paramName, value)

    self.Parameters[ptype][paramName] = value

    return true
end

function MaterialEditor:ResetParameter(paramName)
    local mat = self.Instance()
    if not mat then return false end

    local value, ptype = self.ParamSet:GetParameter(paramName)

    if not value then
        Warning("MaterialEditor: Could not find parameter '" .. tostring(paramName) .. "' in material proxy for material '" .. tostring(self.Material) .. "'. Cannot reset.")
        return false
    end

    local funcName = MaterialEnums.ParamTypeToSetFunc[ptype]

    mat[funcName](mat, paramName, value)

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
            local existParam, paramType = self:GetParameter(paramName)
            if not existParam or paramType ~= i then
                goto continue
            end

            mat[MaterialEnums.ParamTypeToSetFunc[i]](mat, paramName, value)
            self.Parameters[i][paramName] = value
            ::continue::
        end
    end

    return true
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

    local ok, err = pcall(function()
        for ptype,params in pairs(self.ParamSet.Parameters) do
            for paramName,value in pairs(params) do
                local funcName = MaterialEnums.ParamTypeToSetFunc[ptype]

                mat[funcName](mat, paramName, value)

                self.Parameters[ptype][paramName] = nil
            end
        end
    end)
    if not ok then
        RainbowDumpTable(self.ParamSet.Parameters)
    end
end

function MaterialEditor:Reapply()
    self:ApplyParameters(self.Parameters)
end