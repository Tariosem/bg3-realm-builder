--- @class MaterialEditor
--- @field Material string -- origin Material UUID
--- @field SourceFile string
--- @field MaterialType number
--- @field DiffusionProfileUUID string
--- @field Proxy MaterialProxy -- MaterialProxy instance for easier parameter access
--- @field Instance fun():Material
--- @field new fun(matSrc: fun():Material, originMaterial: string): MaterialEditor
MaterialEditor = _Class("MaterialEditor")

---@param matSrc fun():Material
---@param originMaterial any
function MaterialEditor:__init(matSrc, originMaterial, materialPreset)
    local matRes = Ext.Resource.Get(originMaterial, "Material") --[[@as ResourceMaterialResource]]
    if not matRes then
        Error("MaterialEditor: Could not find origin material resource for '" .. tostring(originMaterial) .. "'. Cannot create MaterialEditor.")
        return
    end

    self.Material = originMaterial or ""
    self.SourceFile = matRes.SourceFile or ""
    self.MaterialType = matRes.MaterialType or 0
    self.DiffusionProfileUUID = matRes.DiffusionProfileUUID or ""

    self.Proxy = MaterialProxy.new(originMaterial) --[[@as MaterialProxy]]
    self.PresetProxy = MaterialPresetProxy.new(materialPreset) --[[@as MaterialPresetProxy?]]

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

---@param paramName string
---@return number[]?
function MaterialEditor:GetParameter(paramName)
    local ptype = self.Proxy:GetParameterType(paramName)
    if not ptype then return nil end

    local value = self.Parameters[ptype][paramName]

    if not value then
        local proxyParam = self.Proxy:GetParameter(paramName)
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

function MaterialEditor:SetParameter(paramName, value)
    local mat = self.Instance()
    if not mat then
        Error("MaterialEditor: Could not find material instance for material '" .. tostring(self.Material) .. "'.")
        return false
    end

    local funcName = PropTypeToFunc[#value]
    local applyValue = #value == 1 and value[1] or value

    mat[funcName](mat, paramName, applyValue)

    self.Parameters[#value][paramName] = value

    return true
end

function MaterialEditor:ResetParameter(paramName)
    local mat = self.Instance()
    if not mat then
        Error("MaterialEditor: Could not find material instance for material '" .. tostring(self.Material) .. "'.")
        return false
    end

    local value = self.Proxy:GetParameter(paramName)

    if self.PresetProxy then
        local presetValue = self.PresetProxy:GetParameter(paramName)
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

    self.Parameters[#value][paramName] = nil

    return true
end

---@param parameters table<number, table<string, number[]>>
---@return boolean
function MaterialEditor:ApplyParameters(parameters)
    local mat = self.Instance()
    if not mat then
        Error("MaterialEditor: Could not find material instance for material '" .. tostring(self.Material) .. "'.")
        return false
    end

    for i,params in pairs(parameters) do
        for paramName, value in pairs(params) do
            if not self.Proxy:HasParameter(paramName) then
                goto continue
            end
            local applyValue = #value == 1 and value[1] or value
            mat[PropTypeToFunc[#value]](mat, paramName, applyValue)
            self.Parameters[i][paramName] = value
            ::continue::
        end
    end

    return true
end

function MaterialEditor:ResetAll()
    local mat = self.Instance()
    if not mat then
        Error("MaterialEditor: Could not find material instance for material '" .. tostring(self.Material) .. "'.")
        return false
    end

    for ptype,params in pairs(self.Proxy.Parameters) do
        for paramName,_ in pairs(params) do
            local value = self.Proxy:GetParameter(paramName)
            if self.PresetProxy then
                local presetValue = self.PresetProxy:GetParameter(paramName)
                if presetValue then
                    value = presetValue
                end
            end
            if value then
                local funcName = PropTypeToFunc[#value]
                local applyValue = #value == 1 and value[1] or value
                mat[funcName](mat, paramName, applyValue)

            end
        end
        self.Parameters[ptype] = {}
    end
end

local function whatLSXType(value)
    if type(value) == "boolean" then
        return LSXValueType.bool
    elseif type(value) == "number" then
        return LSXValueType.float
    elseif type(value) == "string" then
        return LSXValueType.FixedString
    elseif type(value) == "table" then
        if #value == 2 then
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
        local valueType = whatLSXType(v)
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

local function createPresetParamAttrNodes(parameterName, value)
    local attrs = {}
    local valueType = whatLSXType(value)
    local saveValue = #value == 1 and value[1] or value
    if not valueType then
        Warning("CustomMaterialProxy: Could not determine LSX value type for preset parameter '" .. tostring(parameterName) .. "'. Skipping.")
        return nil
    end

    attrs = {
        LSXUtils.AttrNode("Color", LSXValueType.bool, parameterName:find("Color") ~= nil or parameterName:find("Colour") ~= nil),
        LSXUtils.AttrNode("Custom", LSXValueType.bool, false),
        LSXUtils.AttrNode("Enabled", LSXValueType.bool, true),
        LSXUtils.AttrNode("Value", valueType, saveValue),
        LSXUtils.AttrNode("Parameter", LSXValueType.FixedString, parameterName),
    }
    
    return attrs
end

local function createPresetParameterNodes(matRes, parameters)
    local paramNodes = {} --[[@as LSXNode[] ]]
    for i,params in pairs(parameters) do
        for paramName,value in pairs(params) do
            local node = LSXNode.new("node", { id= PropTypeToField[i] })
            local attrs = createPresetParamAttrNodes(paramName, value)
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
    local root = LSXUtils.new()
    if not root then
        Error("CustomMaterialProxy: Could not create LSXTableNode for export.")
        return nil
    end

    local matRes = Ext.Resource.Get(self.Material, "Material") --[[@as ResourceMaterialResource]]
    if not matRes then
        Error("CustomMaterialProxy: Could not find origin material resource for '" .. tostring(self.Material) .. "'. Cannot export to LSX.")
        return nil
    end

    local matRegion = LSXNode.new("region", {id="MaterialBank"})
    root:AppendChild(matRegion)
    local matNode = LSXNode.new("node", {id="MaterialBank"})
    matRegion:AppendChild(matNode)
    local childrenWrapper = LSXNode.new("children")
    matNode:AppendChild(childrenWrapper)
    local resNode = LSXNode.new("node", {id="Resource"})
    childrenWrapper:AppendChild(resNode)

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
        },
        nil,
        "Change me!"),
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
    local root = LSXUtils.new()
    if not root then
        Error("CustomMaterialProxy: Could not create LSXTableNode for export.")
        return nil
    end
    local presetRegion = LSXUtils.RegionNodeWrapper("MaterialPresetBank", root)
    local childrenWrapper = LSXNode.new("children")
    presetRegion:AppendChild(childrenWrapper)
    local resNode = LSXNode.new("node", {id="Resource"})
    childrenWrapper:AppendChild(resNode)

    local baseAttr = {
        LSXUtils.AttrNode("ID", LSXValueType.FixedString, Uuid_v4()),
        LSXUtils.AttrNode("Name", LSXValueType.LSString, "Custom Material Preset"):AddComment("Change me!"),
        LSXUtils.AttrNode("Localized", LSXValueType.bool, false),
        LSXUtils.AttrNode("_OriginalFileVersion_", LSXValueType.int64, "144115198813274414"),
    }
    resNode:AppendChildren(baseAttr)

    resNode:SortChildren(function(a,b) return a:GetAttribute("id") < b:GetAttribute("id") end)

    local secondChildrenWrapper = LSXNode.new("children")
    resNode:AppendChild(secondChildrenWrapper)

    local presetsNode = LSXNode.new("node", {id="Presets"}, {
        LSXUtils.AttrNode("MaterialPresetResource", LSXValueType.FixedString, ""),
    })
    secondChildrenWrapper:AppendChild(presetsNode)

    local thirdChildrenWrapper = LSXNode.new("children") 
    presetsNode:AppendChild(thirdChildrenWrapper)

    local colorPresetNode = LSXNode.new("node", {id="ColorPresets"})
    thirdChildrenWrapper:AppendChild(colorPresetNode)
    local colorPresetAttrNodes = {
        LSXNode.new("attribute", {
            id = "ForcePresetValues",
            type = LSXValueType.bool,
            value = false,
        }),
        LSXNode.new("attribute", {
            id = "GroupName",
            type = LSXValueType.FixedString,
            value = "",
        }),
        LSXNode.new("attribute", {
            id = "MaterialPresetResource",
            type = LSXValueType.FixedString,
            value = "",
        }),
    }
    colorPresetNode:AppendChildren(colorPresetAttrNodes)

    local matePresetNode = LSXNode.new("node", {id="MaterialPresets"})
    thirdChildrenWrapper:AppendChild(matePresetNode)

    local paramNodes = createPresetParameterNodes(nil, self.Parameters)

    if paramNodes then
        thirdChildrenWrapper:AppendChildren(paramNodes)
    end


    local xmlString = root:Stringify()

    local success = Ext.IO.SaveFile(path .. ".lsx", xmlString)
    if not success then
        Warning("CustomMaterialProxy: Could not save LSX file to path: " .. tostring(path))
        return nil
    end

    return success
end