local lsattrNode = LSXHelpers.AttrNode
ResourceHelpers = {}

local function createParameterAttrNodes(paramObj, overrideValue, parameterName)
    local attrs = {}
    for k, v in pairs(paramObj) do
        local valueType = LSXHelpers.LSValueType(v)
        if not valueType then
            Warning("CustomMaterialProxy: Could not determine LSX value type for parameter '" ..
                tostring(paramObj.ParameterName) .. "'. Skipping.")
            return nil
        end
        if k:find("Index") then
            valueType = "int32"
        end

        local value = v
        if (k == "Value" or k == "ID") and overrideValue ~= nil then
            value = overrideValue
        end

        local attr = lsattrNode(k, valueType, value)

        table.insert(attrs, attr)
    end

    local otherAttrs = {
        lsattrNode("GroupName", "FixedString", ""),
        lsattrNode("ExportAsPreset", "bool", true),
    }

    MergeArrays(attrs, otherAttrs)

    return attrs
end

---@param matRes ResourceMaterialResource|ResourcePresetData
---@param parameters RB_ParameterSet
---@return XMLNode|nil
local function createParameterNodes(matRes, parameters)
    local paramNodes = {} --[[@as XMLNode[] ]]
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

    for i, params in pairs(paramList) do
        for _, param in pairs(params) do
            local node = XMLNode.new("node", { id = indexToNodeName[i] })
            local paramName = param.ParameterName
            local value = nil
            local valueField = i > 4 and "ID" or "Value"
            if parameters and parameters[i] then
                value = parameters[i][paramName] or param[valueField]
            end
            local attrs = createParameterAttrNodes(param, value, paramName)
            if not attrs then
                Warning("CustomMaterialProxy: Could not create LSX attribute nodes for parameter '" ..
                    tostring(paramName) .. "'. Skipping parameter.")
            else
                node:AppendChildren(attrs)
                table.insert(paramNodes, node)
            end
        end
    end

    return paramNodes
end


---@param params RB_ParameterSet
---@param srcMat GUIDSTRING
---@param uuid string
---@param customName string?
---@return XMLNode?
function ResourceHelpers.BuildMaterialResource(srcMat, uuid, params, customName)
    local matRes = Ext.Resource.Get(srcMat, "Material") --[[@as ResourceMaterialResource]]
    if not matRes then
        Error("CustomMaterialProxy: Could not find origin material resource for '" ..
            tostring(srcMat) .. "'.")
        return nil
    end

    local resNode = XMLNode.new("node", { id = "Resource" })

    local sourceFile = LSXHelpers.GetPathAfterData(matRes.SourceFile or "")
    local baseAttr = {
        lsattrNode("ID", "FixedString", uuid or srcMat),
        lsattrNode("Name", "LSString", customName or matRes.Name or "Material_" .. uuid),
        lsattrNode("SourceFile", "LSString", sourceFile),
        lsattrNode("MaterialType", "uint8", matRes.MaterialType.Value or 0),
        lsattrNode("DiffusionProfileUUID", "FixedString", matRes.DiffusionProfileUUID or ""),
    }
    resNode:AppendChildren(baseAttr)
    resNode:SortChildren(function(a, b) return a:GetAttribute("id") < b:GetAttribute("id") end)

    local secondChildrenWrapper = XMLNode.new("children")
    resNode:AppendChild(secondChildrenWrapper)
    local paramNodes = createParameterNodes(matRes, params)
    if paramNodes then
        secondChildrenWrapper:AppendChildren(paramNodes)
    end

    return resNode
end

local function createPresetParamAttrNodes(parameterName, value)
    local attrs = {}
    local valueType = LSXHelpers.LSValueType(value)
    if not valueType then
        Warning("CustomMaterialProxy: Could not determine LSX value type for preset parameter '" ..
            tostring(parameterName) .. "'. Skipping.")
        return nil
    end

    local valueField = "Value"

    attrs = {
        lsattrNode("Custom", LSValueType.bool, false),
        lsattrNode("Enabled", LSValueType.bool, true),
        lsattrNode(valueField, valueType, value),
        lsattrNode("Parameter", LSValueType.FixedString, parameterName),
    }

    return attrs
end

local function createPresetParameterNodes(matRes, parameters)
    local paramNodes = {} --[[@as XMLNode[] ]]
    for i, params in pairs(parameters) do
        if i == 5 then break end -- Texture2DParameters and VirtualTextureParameters are not supported in presets
        for paramName, value in pairs(params) do
            local node = XMLNode.new("node", { id = ParamTypeToField[i] })
            local attrs = createPresetParamAttrNodes(paramName, value)
            if not attrs then
                Warning("CustomMaterialProxy: Could not create LSX attribute nodes for parameter '" ..
                    tostring(paramName) .. "'. Skipping parameter.")
            else
                node:AppendChildren(attrs)
                node:SortChildren(function(a, b) return a:GetAttribute("id") < b:GetAttribute("id") end)
                table.insert(paramNodes, node)
            end
        end
    end

    return paramNodes
end

---@param parameters RB_ParameterSet
---@param uuid GUIDSTRING
---@param internalName string
---@return XMLNode
function ResourceHelpers.BuildMaterialPresetResourceNode(parameters, uuid, internalName)
    local root = XMLNode.new("node", { id = "Resource" })

    --- material preset doesn't support texture parameters

    local baseAttr = {
        lsattrNode("ID", LSValueType.FixedString, uuid),
        lsattrNode("Name", LSValueType.LSString, internalName),
        lsattrNode("Localized", LSValueType.bool, false),
        lsattrNode("_OriginalFileVersion_", LSValueType.int64, "144115198813274414"),
    }
    root:AppendChildren(baseAttr)

    root:SortChildren(function(a, b) return a:GetAttribute("id") < b:GetAttribute("id") end)

    local childrenNode = root:AppendChild(LSXHelpers.ChildrenNode())

    local presetsNode = childrenNode:AppendChild(XMLNode.new("node", { id = "Presets" }, {
        lsattrNode("MaterialResource", LSValueType.FixedString, ""),
    }))

    local thirdChildrenWrapper = presetsNode:AppendChild(LSXHelpers.ChildrenNode())

    local colorPresetNode = thirdChildrenWrapper:AppendChild(XMLNode.new("node", { id = "ColorPreset" }))

    local colorPresetAttrNodes = {
        lsattrNode("ForcePresetValues", LSValueType.bool, false),
        lsattrNode("GroupName", LSValueType.FixedString, ""),
        lsattrNode("MaterialPresetResource", LSValueType.FixedString, ""),
    }
    colorPresetNode:AppendChildren(colorPresetAttrNodes)

    local matePresetNode = XMLNode.new("node", { id = "MaterialPresets" })
    thirdChildrenWrapper:AppendChild(matePresetNode)

    local paramNodes = createPresetParameterNodes(nil, parameters)

    if paramNodes then
        thirdChildrenWrapper:AppendChildren(paramNodes)
    end

    return root
end

---@param force any
---@param groupName any
---@param mapKey any
---@param materialPresetResource any
---@return XMLNode
local function buildMPNode(force, groupName, mapKey, materialPresetResource)
    local presetNode = XMLNode.new("node", { id = "Object", key = "MapKey" })
    presetNode:AppendChild(LSXHelpers.AttrNode("ForcePresetValues", "bool", force))
    presetNode:AppendChild(LSXHelpers.AttrNode("GroupName", "FixedString", groupName))
    presetNode:AppendChild(LSXHelpers.AttrNode("MapKey", "FixedString", mapKey))
    presetNode:AppendChild(LSXHelpers.AttrNode("MaterialPresetResource", "FixedString", materialPresetResource))
    return presetNode
end

--- @param matOv ResourcePresetData
--- @param overrideMaterialPresets table<string, string> groupname -> materialpreset uuid
--- @param modfiedParams RB_ParameterSet
--- @return XMLNode
local function buildMaterialOverrideNodes(matOv, overrideMaterialPresets, modfiedParams)
    local materialOverridesNode = XMLNode.new("node", { id = "MaterialOverrides", })
    materialOverridesNode:AppendChild(LSXHelpers.AttrNode("MaterialResource", "FixedString", matOv.MaterialResource))
    
    local matOverridesChildren = materialOverridesNode:AppendChild(LSXHelpers.ChildrenNode())

    local matPresetsNode = matOverridesChildren:AppendChild(XMLNode.new("node", { id = "MaterialPresets", }))
    for _, preset in pairs(matOv.MaterialPresets) do
        local overrideUuid = overrideMaterialPresets[preset.GroupName]
        overrideMaterialPresets[preset.GroupName] = nil
        local presetNode = buildMPNode(
            false,
            preset.GroupName,
            preset.GroupName,
            overrideUuid or preset.MaterialPresetResource
        )
        matPresetsNode:AppendChild(presetNode)
    end
    for groupName, overrideUuid in pairs(overrideMaterialPresets) do
        local presetNode = buildMPNode(
            true,
            groupName,
            groupName,
            overrideUuid
        )
        matPresetsNode:AppendChild(presetNode)
    end

    local paramSetProxy = ParametersSetProxy.BuildFromResourcePresetData(matOv)
    if not paramSetProxy then
        Warning("Failed to create ParametersSetProxy for CharacterVisual MaterialOverrides")
        paramSetProxy = { Parameters = modfiedParams or {} }
    else
        paramSetProxy:Merge(modfiedParams or {})
    end

    local paramsNode = createPresetParameterNodes(nil, paramSetProxy.Parameters)

    if paramsNode then
        matOverridesChildren:AppendChildren(paramsNode)
    end

    return materialOverridesNode
end

--- @param mat ResourcePresetData
local function buildMaterialNode(mat, mapKey)
    local node = XMLNode.new("node", { id = "Materials", key = "MapKey" })
    node:AppendChild(LSXHelpers.AttrNode("MapKey", "FixedString", mapKey))
    local children = node:AppendChild(LSXHelpers.ChildrenNode())
    local matOverrideNode = buildMaterialOverrideNodes(mat, {}, {})
    children:AppendChild(matOverrideNode)
    return node
end

--- copy a CharacterVisual resource and modify it
--- @param srcUuid string Source CharacterVisual resource UUID
--- @param uuid string
--- @param internalName string
--- @param overrideMaterialPresets table<string, string>? Material preset overrides, map of GroupName to MaterialPresetResource UUID
--- @param modfiedParams RB_ParameterSet? Additional modified parameters to set on the resource
--- @param overrideVisuals table<string, string>? Map of Slot to VisualResource UUID overrides
--- @return XMLNode?
function ResourceHelpers.BuildCharacterVisualResource(srcUuid, uuid, internalName, overrideMaterialPresets, modfiedParams, overrideVisuals)
    local src = Ext.Resource.Get(srcUuid, "CharacterVisual") --[[@as ResourceCharacterVisualResource]]
    if not src then
        Error("Could not find source CharacterVisual resource with UUID '" .. tostring(srcUuid) .. "'.")
        return nil
    end

    local srcSet = src.VisualSet

    overrideMaterialPresets = overrideMaterialPresets or {}
    local resourceNode = XMLNode.new("node", { id = "Resource", })

    local attributes = {
        LSXHelpers.AttrNode("BaseVisual", "FixedString", src.BaseVisual),
        LSXHelpers.AttrNode("BodySetVisual", "FixedString", srcSet.BodySetVisual),
        LSXHelpers.AttrNode("ID", "FixedString", uuid),
        LSXHelpers.AttrNode("Name", "LSString", internalName),
        LSXHelpers.AttrNode("ShowEquipmentVisuals", "bool", srcSet.ShowEquipmentVisuals),
    }

    resourceNode:AppendChildren(attributes)
    local childrenNode = resourceNode:AppendChild(LSXHelpers.ChildrenNode())

    -- MaterialOverrides
    local matOvNode = buildMaterialOverrideNodes(
        srcSet.MaterialOverrides,
        overrideMaterialPresets,
        modfiedParams or {}
    )
    childrenNode:AppendChild(matOvNode)

    -- Materials    
    for mapKey, mat in pairs(srcSet.Materials) do
        local matNode = buildMaterialNode(mat, mapKey)
        childrenNode:AppendChild(matNode)
    end

    -- RealMaterialOverrides
    local realMatOverridesNode = childrenNode:AppendChild(XMLNode.new("node", { id = "RealMaterialOverrides", }))
    local realMatOverridesChildren = nil
    for mapKey, mapValue in pairs(srcSet.RealMaterialOverrides) do
        realMatOverridesChildren = realMatOverridesChildren or realMatOverridesNode:AppendChild(LSXHelpers.ChildrenNode())
        local overrideNode = XMLNode.new("node", { id = "Object", key = "MapKey", })
        overrideNode:AppendChild(LSXHelpers.AttrNode("MapKey", "FixedString", mapKey))
        overrideNode:AppendChild(LSXHelpers.AttrNode("MapValue", "FixedString", mapValue))
        realMatOverridesChildren:AppendChild(overrideNode)
    end

    -- Slots
    for _, slot in pairs(srcSet.Slots) do
        local slotNode = childrenNode:AppendChild(XMLNode.new("node", { id = "Slots", }))
        local visualId = overrideVisuals and overrideVisuals[slot.Slot] or slot.VisualResource
        slotNode:AppendChild(lsattrNode("Bone", "FixedString", slot.Bone))
        slotNode:AppendChild(lsattrNode("Slot", "FixedString", slot.Slot))
        slotNode:AppendChild(lsattrNode("VisualResource", "FixedString", visualId))
    end

    return resourceNode
end

--- copy a Visual resource and modify it
---@param srcUuid string
---@param uuid string
---@param internalName string
---@param overrideObjectMat table<string, string> materialID -> overrideMaterialID
---@return XMLNode
function ResourceHelpers.BuildVisualResource(srcUuid, uuid, internalName, overrideObjectMat)
    local src = Ext.Resource.Get(srcUuid, "Visual") --[[@as ResourceVisualResource]]

    local resourceNode = XMLNode.new("node", { id = "Resource", })

    local attributes = {
        lsattrNode("ID", "FixedString", uuid),
        lsattrNode("Name", "LSString", internalName .. "_" .. uuid),
        lsattrNode("SourceFile", "LSString", LSXHelpers.GetPathAfterData(src.SourceFile or "")),
        lsattrNode("AttachBone", "FixedString", src.AttachBone),
        lsattrNode("BlueprintInstanceResourceID", "FixedString", src.BlueprintInstanceResourceID),
        lsattrNode("BoundsMax", "fvec3", src.BoundsMax),
        lsattrNode("BoundsMin", "fvec3", src.BoundsMin),
        lsattrNode("HairPresetResourceId", "FixedString", src.HairPresetResourceId),
        lsattrNode("HairType", "uint8", src.HairType),
        lsattrNode("MaterialType", "uint8", Ext.Types.GetTypeInfo("MaterialType").EnumValues[src.MaterialType] or 0),
        lsattrNode("NeedsSkeletonRemap", "bool", src.NeedsSkeletonRemap),
        lsattrNode("RemapperSlotId", "FixedString", src.RemapperSlotId),
        lsattrNode("ScalpMaterialId", "FixedString", src.ScalpMaterialId),
        lsattrNode("SkeletonResource", "FixedString", src.SkeletonResource),
        lsattrNode("SkeletonSlot", "FixedString", src.SkeletonSlot),
        lsattrNode("Slot", "FixedString", src.Slot),
        lsattrNode("SoftbodyResourceID", "FixedString", src.SoftbodyResourceID),
        lsattrNode("SupportsVertexColorMask", "bool", src.SupportsVertexColorMask),
        lsattrNode("Template", "FixedString", src.Template),
    }

    if src.Cloth then
        local clothAttrs = {
            lsattrNode("ClothColliderResourceID", "FixedString", src.Cloth.ClothColliderResourceID),
        }
        MergeArrays(attributes, clothAttrs)
    end


    resourceNode:AppendChildren(attributes)
    local childrenNode = resourceNode:AppendChild(LSXHelpers.ChildrenNode())

    -- AnimationWaterfall
    for _, aw in pairs(src.AnimationWaterfall) do
        local awNode = childrenNode:AppendChild(XMLNode.new("node", { id = "AnimationWaterfall", }))
        awNode:AppendChild(lsattrNode("Object", "FixedString", aw))
    end

    -- Objects
    for _, obj in pairs(src.Objects) do
        local objNode = childrenNode:AppendChild(XMLNode.new("node", { id = "Objects", }))
        objNode:AppendChild(lsattrNode("ObjectID", "FixedString", obj.ObjectID))
        objNode:AppendChild(lsattrNode("LOD", "uint8", obj.LOD))
        local matId = overrideObjectMat[obj.MaterialID] or obj.MaterialID
        objNode:AppendChild(lsattrNode("MaterialID", "FixedString", matId))
    end

    return resourceNode
end