--- @class MaterialEditor
--- @field Material string -- origin Material UUID
--- @field SourceFile string
--- @field MaterialType number
--- @field DiffusionProfileUUID string
--- @field Proxy MaterialProxy -- MaterialProxy instance for easier parameter access
--- @field PresetProxy MaterialPresetProxy? -- MaterialPresetProxy instance if a preset is applied
--- @field ParamSetProxy ParametersSetProxy -- ParameterSetProxy instance for easier parameter access
--- @field Instance fun():Material
--- @field ParamsSrc fun():MaterialParametersSet
--- @field new fun(originMaterial: GUIDSTRING, matSrc:fun():Material , paramsSrc:fun():MaterialParametersSet, materialPreset: GUIDSTRING?):MaterialEditor
MaterialEditor = _Class("MaterialEditor")

local function GetPathAfterData(path)
    return path:match("Data[\\/](.*)") or path
end


---@param originMaterial string
---@param matSrc fun():Material
---@param paramsSrc fun():MaterialParametersSet
---@param materialPreset string?
function MaterialEditor:__init(originMaterial, matSrc, paramsSrc, materialPreset)
    local matRes = Ext.Resource.Get(originMaterial, "Material") --[[@as ResourceMaterialResource]]
    if not matRes then
        Error("MaterialEditor: Could not find origin material resource for '" .. tostring(originMaterial) .. "'. Cannot create MaterialEditor.")
        return
    end

    self.Material = originMaterial or ""
    self.SourceFile = GetPathAfterData(matRes.SourceFile or "")
    self.MaterialType = matRes.MaterialType or 0
    self.DiffusionProfileUUID = matRes.DiffusionProfileUUID or ""

    self.Proxy = MaterialProxy.new(originMaterial) --[[@as MaterialProxy]]
    self.PresetProxy = MaterialPresetProxy.new(materialPreset) --[[@as MaterialPresetProxy?]]
    self.ParamSetProxy = ParametersSetProxy.new(paramsSrc()) --[[@as ParametersSetProxy]]

    self.ParamsSrc = paramsSrc
    self.Instance = matSrc

    self.Parameters = {
        [1] = {}, -- ScalarParameters
        [2] = {}, -- Vector2Parameters
        [3] = {}, -- Vector3Parameters
        [4] = {}, -- VectorParameters
    }

    if self.PresetProxy then
        for ptype,params in pairs(self.PresetProxy.Parameters) do
            for paramName,value in pairs(params) do
                self.Parameters[ptype][paramName] = value
            end
        end
    end

end

--- this function return a value for a given parameter name
--- it first checks the local changes, then preset, then original material proxy
---@param paramName string
---@return number[]?
function MaterialEditor:GetParameter(paramName)
    local ptype = self.ParamSetProxy:GetParameterType(paramName)
    if not ptype then
        Warning("MaterialEditor: Could not determine parameter type for '" .. tostring(paramName) .. "'.")
        return nil
    end

    local value = self.Parameters[ptype][paramName]

    if not value then
        local proxyParam = self.ParamSetProxy:GetParameter(paramName)
        if self.PresetProxy then
            local presetParam = self.PresetProxy:GetParameter(paramName)
            if presetParam then
                proxyParam = presetParam
            end
        end

        if not proxyParam then
            Warning("MaterialEditor: Could not find parameter '" .. tostring(paramName) .. "' in material proxy for material '" .. tostring(self.Material) .. "'.")
            return nil
        end
        value = proxyParam
        if type(value) ~= "table" then
            value = { value }
        end
    end

    return value
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

function MaterialEditor:SetParameter(paramName, value)
    local mat = self.Instance()
    if not mat then return false end

    local funcName = PropTypeToFunc[#value]
    local applyValue = #value == 1 and value[1] or value

    mat[funcName](mat, paramName, applyValue)

    self.Parameters[#value][paramName] = value

    return true
end

function MaterialEditor:ResetParameter(paramName)
    local mat = self.Instance()
    if not mat then return false end

    local value = self.ParamSetProxy:GetParameter(paramName)
    local presetValue = nil

    if self.PresetProxy then
        presetValue = self.PresetProxy:GetParameter(paramName)
        if presetValue then
            value = presetValue
        end
    end

    if not value then
        Warning("MaterialEditor: Could not find parameter '" .. tostring(paramName) .. "' in material proxy for material '" .. tostring(self.Material) .. "'. Cannot reset.")
        return false
    end

    local funcName = PropTypeToFunc[#value]
    local applyValue = #value == 1 and value[1] or value

    mat[funcName](mat, paramName, applyValue)

    self.Parameters[#value][paramName] = presetValue and presetValue or nil

    return true
end

---@param parameters table<number, table<string, number[]>>
---@return boolean
function MaterialEditor:ApplyParameters(parameters)
    local mat = self.Instance()
    if not mat then return false end

    for i,params in pairs(parameters) do
        i = tonumber(i) --[[@as number]]
        for paramName, value in pairs(params) do
            if not self.ParamSetProxy:GetParameterType(paramName) then goto continue end
            local applyValue = #value == 1 and value[1] or value
            mat[PropTypeToFunc[#value]](mat, paramName, applyValue)
            self.Parameters[i][paramName] = value
            ::continue::
        end
    end

    return true
end

---@return Vec4
function MaterialEditor:GetPreviewColor()
    --- traverse vec3 and vec4 parameters contains "Color" in their name and compute an color for preview
    
    local color = Vec4.new(0.5, 0.5, 0.5, 1)

    local cnt = 0
    for ptype, params in pairs(self.Parameters) do
        if ptype == 3 or ptype == 4 then
            for paramName, value in pairs(params) do
                if paramName:lower():find("color") then
                    local newVec4 = Vec4.new(value)

                    color = color + newVec4
                    cnt = cnt + 1
                end
            end
        end
    end

    color = color / math.max(cnt, 1)

    AdjustColor(color, 0.8, 1.2)

    color[4] = 1.0

    return color
end

function MaterialEditor:ClearParameters()
    self.PresetProxy = nil
    self.Parameters = {
        [1] = {}, -- ScalarParameters
        [2] = {}, -- Vector2Parameters
        [3] = {}, -- Vector3Parameters
        [4] = {}, -- VectorParameters
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
            local funcName = PropTypeToFunc[#value]
            local applyValue = #value == 1 and value[1] or value

            mat[funcName](mat, paramName, applyValue)

            self.Parameters[ptype][paramName] = nil
        end
    end
end

function MaterialEditor:Reapply()
    self:ApplyParameters(self.Parameters)
end

function DetermineLSXValueType(value)
    if type(value) == "boolean" then
        return LSXValueType.bool
    elseif type(value) == "number" then
        return LSXValueType.float
    elseif type(value) == "string" then
        return LSXValueType.FixedString
    elseif type(value) == "table" then
        if #value == 1 then
            return LSXValueType.float
        elseif #value == 2 then
            return LSXValueType.fvec2
        elseif #value == 3 then
            return LSXValueType.fvec3
        elseif #value == 4 then
            return LSXValueType.fvec4
        end
    end
    
    return LSXValueType.LSString
end

local function createParameterAttrNodes(paramObj, overrideValue)
    local attrs = {}
    for k, v in pairs(paramObj) do
        local valueType = DetermineLSXValueType(v)
        if not valueType then
            Warning("CustomMaterialProxy: Could not determine LSX value type for parameter '" .. tostring(paramObj.ParameterName) .. "'. Skipping.")
            return nil
        end

        local value = v
        if k == "Value" and overrideValue then
            value = #overrideValue == 1 and overrideValue[1] or overrideValue
        end

        local attr = LSXNode.new("attribute", {
            id = k,
            type = valueType,
            value = value
        })

        table.insert(attrs, attr)
    end
    return attrs
end

---@param matRes ResourceMaterialResource
---@param parameters table<number, table<string, number[]>>
---@return LSXNode|nil
local function createParameterNodes(matRes, parameters)
    local paramNodes = {} --[[@as LSXNode[] ]]
    local paramList = {
        matRes.ScalarParameters,
        matRes.Vector2Parameters,
        matRes.Vector3Parameters,
        matRes.VectorParameters,
        matRes.Texture2DParameters,
        matRes.VirtualTextureParameters
    }
    local indexToNodeName = {
        [1] = "ScalarParameters",
        [2] = "Vector2Parameters",
        [3] = "Vector3Parameters",
        [4] = "VectorParameters",
        [5] = "Texture2DParameters",
        [6] = "VirtualTextureParameters"
    }

    for i,params in pairs(paramList) do
        for _,param in pairs(params) do
            local node = LSXNode.new("node", { id=indexToNodeName[i] })
            local paramName = param.ParameterName
            local value = nil
            if i < 5 then
                value = parameters[i][paramName] or param.Value
                if type(value) == "number" then
                    value = { value }
                end
            end
            local attrs = createParameterAttrNodes(param, value)
            if not attrs then
                Warning("CustomMaterialProxy: Could not create LSX attribute nodes for parameter '" .. tostring(paramName) .. "'. Skipping parameter.")
            else
                node:AppendChildren(attrs)
                node:SortChildren(function (a,b) return a:GetAttribute("id") < b:GetAttribute("id") end)
                table.insert(paramNodes, node)
            end
        end
    end

    return paramNodes
end

function MaterialEditor:ExportToLSXAsMaterial(path)
    local root = LSXHelpers.new()
    if not root then
        Error("CustomMaterialProxy: Could not create LSXTableNode for export.")
        return nil
    end

    local matRes = Ext.Resource.Get(self.Material, "Material") --[[@as ResourceMaterialResource]]
    if not matRes then
        Error("CustomMaterialProxy: Could not find origin material resource for '" .. tostring(self.Material) .. "'. Cannot export to LSX.")
        return nil
    end

    local matRegion = root:AppendChild(LSXNode.new("region", {id="MaterialBank"}))
    local matNode = matRegion:AppendChild(LSXNode.new("node", {id="MaterialBank"}))
    local childrenWrapper = matNode:AppendChild(LSXNode.new("children"))
    local resNode = childrenWrapper:AppendChild(LSXNode.new("node", {id="Resource"}))

    local baseAttr = {
        LSXNode.new("attribute", {
            id = "ID",
            type = LSXValueType.guid,
            value = self.Material
        }),
        LSXNode.new("attribute", {
            id = "Name",
            type = LSXValueType.LSString,
            value = "Custom Material"
        }),
        LSXNode.new("attribute", {
            id = "SourceFile",
            type = LSXValueType.LSString,
            value = self.SourceFile or ""
        }),
        LSXNode.new("attribute", {
            id = "MaterialType",
            type = LSXValueType.uint8,
            value = self.MaterialType or 0
        }),
        LSXNode.new("attribute", {
            id = "DiffusionProfileUUID",
            type = LSXValueType.FixedString,
            value = matRes.DiffusionProfileUUID or ""
        }),
    }
    resNode:AppendChildren(baseAttr)

    resNode:SortChildren(function(a,b) return a:GetAttribute("id") < b:GetAttribute("id") end)

    local secondChildrenWrapper = LSXNode.new("children")
    resNode:AppendChild(secondChildrenWrapper)
    local paramNodes = createParameterNodes(matRes, self.Parameters)
    if paramNodes then
        secondChildrenWrapper:AppendChildren(paramNodes)
    end

    local xmlString = root:Stringify()

    local success = Ext.IO.SaveFile(path .. ".lsx", xmlString)

    if not success then
        Warning("CustomMaterialProxy: Could not save LSX file to path: " .. tostring(path))
        return nil
    end

    return success
end

function MaterialEditor:ExportToLSXAsMaterialPreset(path)

    
    local presetParams = self.PresetProxy and self.PresetProxy.Parameters or {}

    for typeIndex, paramTable in pairs(presetParams) do
        for paramName,value in pairs(paramTable) do
            if not self.Parameters[typeIndex][paramName] then
                self.Parameters[typeIndex][paramName] = value
            end
        end
    end

end

