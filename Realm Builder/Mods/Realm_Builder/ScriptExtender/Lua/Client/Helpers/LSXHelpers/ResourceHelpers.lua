local lsattrNode = LSXHelpers.AttrNode
ResourceHelpers = {}

local function createParameterAttrNodes(paramObj, overrideValue)
    local attrs = {}
    for k, v in pairs(paramObj) do
        local valueType = LSXHelpers.LSValueType(v)
        if not valueType then
            Warning("CustomMaterialProxy: Could not determine LSX value type for parameter '" ..
                tostring(paramObj.ParameterName) .. "'. Skipping.")
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
        attr:SetAttrOrder({ "id", "type", "value" })

        table.insert(attrs, attr)
    end
    return attrs
end

---@param matRes ResourceMaterialResource|ResourcePresetData
---@param parameters table<number, table<string, number[]>>?
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

    for i, params in pairs(paramList) do
        for _, param in pairs(params) do
            local node = LSXNode.new("node", { id = indexToNodeName[i] })
            local paramName = param.ParameterName
            local value = nil
            if i < 5 and parameters and parameters[i] then
                value = parameters[i][paramName] or param.Value
                if type(value) == "number" then
                    value = { value }
                end
            end
            local attrs = createParameterAttrNodes(param, value)
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
---@param matName GUIDSTRING
---@param customName string
---@return LSXNode?
function ResourceHelpers.BuildMaterialResource(params, matName, customName)
    local root = LSXHelpers.new()
    if not root then
        Error("CustomMaterialProxy: Could not create LSXTableNode for export.")
        return nil
    end

    local matRes = Ext.Resource.Get(matName, "Material") --[[@as ResourceMaterialResource]]
    if not matRes then
        Error("CustomMaterialProxy: Could not find origin material resource for '" ..
            tostring(matName) .. "'. Cannot export to LSX.")
        return nil
    end

    local resNode = root:AppendChild(LSXNode.new("region", { id = "MaterialBank" }))
        :AppendChild(LSXNode.new("node", { id = "MaterialBank" }))
        :AppendChild(LSXNode.new("children"))
        :AppendChild(LSXNode.new("node", { id = "Resource" }))

    local sourceFile = LSXHelpers.GetPathAfterData(matRes.SourceFile or "")
    local baseAttr = {
        lsattrNode("ID", "guid", customName or matName),
        lsattrNode("Name", "LSString", "Custom Material"),
        lsattrNode("SourceFile", "LSString", sourceFile),
        lsattrNode("MaterialType", "uint8", matRes.MaterialType or 0),
        lsattrNode("DiffusionProfileUUID", "FixedString", matRes.bUseDiffusionProfile or ""),
    }
    resNode:AppendChildren(baseAttr)
    resNode:SortChildren(function(a, b) return a:GetAttribute("id") < b:GetAttribute("id") end)

    local secondChildrenWrapper = LSXNode.new("children")
    resNode:AppendChild(secondChildrenWrapper)
    local paramNodes = createParameterNodes(matRes, params)
    if paramNodes then
        secondChildrenWrapper:AppendChildren(paramNodes)
    end

    return root
end

local function createPresetParamAttrNodes(parameterName, value)
    local attrs = {}
    local valueType = LSXHelpers.LSValueType(value)
    local saveValue = #value == 1 and value[1] or value
    if not valueType then
        Warning("CustomMaterialProxy: Could not determine LSX value type for preset parameter '" ..
            tostring(parameterName) .. "'. Skipping.")
        return nil
    end

    attrs = {
        lsattrNode("Color", LSValueType.bool, false), -- I don't even know what this does
        lsattrNode("Custom", LSValueType.bool, false), -- same as above
        lsattrNode("Enabled", LSValueType.bool, true), -- same as above
        lsattrNode("Value", valueType, saveValue),
        lsattrNode("Parameter", LSValueType.FixedString, parameterName),
    }

    return attrs
end

local function createPresetParameterNodes(matRes, parameters)
    local paramNodes = {} --[[@as LSXNode[] ]]
    for i, params in pairs(parameters) do
        for paramName, value in pairs(params) do
            local node = LSXNode.new("node", { id = PropTypeToField[i] })
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

---@param parameters table<1|2|3|4, table<string, number[]>>
---@param uuid GUIDSTRING
---@param internalName string
---@return LSXNode
function ResourceHelpers.BuildMaterialPresetResourceNode(parameters, uuid, internalName)
    local root = LSXNode.new("node", { id = "Resource" })

    local baseAttr = {
        lsattrNode("ID", LSValueType.FixedString, uuid),
        lsattrNode("Name", LSValueType.LSString, internalName),
        lsattrNode("Localized", LSValueType.bool, false),
        lsattrNode("_OriginalFileVersion_", LSValueType.int64, "144115198813274414"),
    }
    root:AppendChildren(baseAttr)

    root:SortChildren(function(a, b) return a:GetAttribute("id") < b:GetAttribute("id") end)

    local childrenNode = root:AppendChild(LSXHelpers.ChildrenNode())

    local presetsNode = childrenNode:AppendChild(LSXNode.new("node", { id = "Presets" }, {
        lsattrNode("MaterialResource", LSValueType.FixedString, ""),
    }))

    local thirdChildrenWrapper = presetsNode:AppendChild(LSXHelpers.ChildrenNode())

    local colorPresetNode = thirdChildrenWrapper:AppendChild(LSXNode.new("node", { id = "ColorPreset" }))

    local colorPresetAttrNodes = {
        lsattrNode("ForcePresetValues", LSValueType.bool, false),
        lsattrNode("GroupName", LSValueType.FixedString, ""),
        lsattrNode("MaterialPresetResource", LSValueType.FixedString, ""),
    }
    colorPresetNode:AppendChildren(colorPresetAttrNodes)

    local matePresetNode = LSXNode.new("node", { id = "MaterialPresets" })
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
---@return LSXNode
local function buildMPNode(force, groupName, mapKey, materialPresetResource)
    local presetNode = LSXNode.new("node", { id = "Object", key = "MapKey" })
    presetNode:AppendChild(LSXHelpers.AttrNode("ForcePresetValues", "bool", force))
    presetNode:AppendChild(LSXHelpers.AttrNode("GroupName", "FixedString", groupName))
    presetNode:AppendChild(LSXHelpers.AttrNode("MapKey", "FixedString", mapKey))
    presetNode:AppendChild(LSXHelpers.AttrNode("MaterialPresetResource", "FixedString", materialPresetResource))
    return presetNode
end

--- @param matOv ResourcePresetData
--- @param overrideMaterialPresets table<string, string> groupname -> materialpreset uuid
--- @param modfiedParams RB_ParameterSet
--- @return LSXNode
local function buildMaterialOverrideNodes(matOv, overrideMaterialPresets, modfiedParams)
    local materialOverridesNode = LSXNode.new("node", { id = "MaterialOverrides", })
    materialOverridesNode:AppendChild(LSXHelpers.AttrNode("MaterialResource", "FixedString", matOv.MaterialResource))
    
    local matOverridesChildren = materialOverridesNode:AppendChild(LSXHelpers.ChildrenNode())

    local matPresetsNode = matOverridesChildren:AppendChild(LSXNode.new("node", { id = "MaterialPresets", }))
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

    local paramSetProxy = ParametersSetProxy.BuildFromMaterialPresetParamSet(matOv)
    if not paramSetProxy then
        error("Failed to create ParametersSetProxy for CharacterVisual MaterialOverrides")
    end
    paramSetProxy:Merge(modfiedParams or {})

    local paramsNode = createPresetParameterNodes(nil, paramSetProxy.Parameters)

    if paramsNode then
        matOverridesChildren:AppendChildren(paramsNode)
    end

    return materialOverridesNode
end

--- @param mat ResourcePresetData
local function buildMaterialNode(mat, mapKey)
    local node = LSXNode.new("node", { id = "Materials", key = "MapKey" })
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
function ResourceHelpers.BuildCharacterVisualResource(srcUuid, uuid, internalName, overrideMaterialPresets, modfiedParams)
    local src = Ext.Resource.Get(srcUuid, "CharacterVisual") --[[@as ResourceCharacterVisualResource]]
    local srcSet = src.VisualSet

    overrideMaterialPresets = overrideMaterialPresets or {}
    local resourceNode = LSXNode.new("node", { id = "Resource", })

    local attributes = {
        LSXHelpers.AttrNode("BaseVisual", "FixedString", src.BaseVisual),
        LSXHelpers.AttrNode("BodySetVisual", "FixedString", srcSet.BodySetVisual),
        LSXHelpers.AttrNode("ID", "FixedString", uuid),
        LSXHelpers.AttrNode("Name", "LSString", internalName .. "_" .. uuid),
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
    local realMatOverridesNode = childrenNode:AppendChild(LSXNode.new("node", { id = "RealMaterialOverrides", }))
    local realMatOverridesChildren = nil
    for mapKey, mapValue in pairs(srcSet.RealMaterialOverrides) do
        realMatOverridesChildren = realMatOverridesChildren or realMatOverridesNode:AppendChild(LSXHelpers.ChildrenNode())
        local overrideNode = LSXNode.new("node", { id = "Object", key = "MapKey", })
        overrideNode:AppendChild(LSXHelpers.AttrNode("MapKey", "FixedString", mapKey))
        overrideNode:AppendChild(LSXHelpers.AttrNode("MapValue", "FixedString", mapValue))
        realMatOverridesChildren:AppendChild(overrideNode)
    end

    -- Slots
    for _, slot in pairs(srcSet.Slots) do
        local slotNode = childrenNode:AppendChild(LSXNode.new("node", { id = "Slots", }))
        slotNode:AppendChild(lsattrNode("Bone", "FixedString", slot.Bone))
        slotNode:AppendChild(lsattrNode("Slot", "FixedString", slot.Slot))
        slotNode:AppendChild(lsattrNode("VisualResource", "FixedString", slot.VisualResource))
    end

    return resourceNode
end

--- copy a Visual resource and modify it
---@param srcUuid string
---@param uuid string
---@param internalName string
---@param overrideObjectMat table<string, string> objectId -> matId
function ResourceHelpers.BuildVisualResource(srcUuid, uuid, internalName, overrideObjectMat)
    local src = Ext.Resource.Get(srcUuid, "Visual") --[[@as ResourceVisualResource]]

    local resourceNode = LSXNode.new("node", { id = "Resource", })

    local attributes = {
        LSXHelpers.AttrNode("ID", "FixedString", uuid),
        LSXHelpers.AttrNode("Name", "LSString", internalName .. "_" .. uuid),
        LSXHelpers.AttrNode("SourceFile", "LSString", LSXHelpers.GetPathAfterData(src.SourceFile or "")),
    }

    resourceNode:AppendChildren(attributes)
    local childrenNode = resourceNode:AppendChild(LSXHelpers.ChildrenNode())

    -- Objects
    for _, obj in pairs(src.Objects) do
        local objNode = childrenNode:AppendChild(LSXNode.new("node", { id = "Objects", }))
        objNode:AppendChild(lsattrNode("ObjectID", "FixedString", obj.ObjectID))
        objNode:AppendChild(lsattrNode("LOD", "uint8", obj.LOD))
        local matId = overrideObjectMat[obj.ObjectID] or obj.MaterialID
        objNode:AppendChild(lsattrNode("MaterialID", "FixedString", matId))
    end

    return resourceNode
end


--[[
<node id="Resource">
	<attribute id="AttachBone" type="FixedString" value="" />
	<attribute id="AttachmentSkeletonResource" type="FixedString" value="" />
	<attribute id="BlueprintInstanceResourceID" type="FixedString" value="" />
	<attribute id="BoundsMax" type="fvec3" value="1.4225477 2.2880502 1.4143094" />
	<attribute id="BoundsMin" type="fvec3" value="-1.4225483 0.42886278 0.0118334945" />
	<attribute id="ClothColliderResourceID" type="FixedString" value="" />
	<attribute id="HairPresetResourceId" type="FixedString" value="" />
	<attribute id="HairType" type="uint8" value="0" />
	<attribute id="ID" type="FixedString" value="a3b75b3e-6ded-1034-2d5d-8f1be8720794" />
	<attribute id="MaterialType" type="uint8" value="0" />
	<attribute id="Name" type="LSString" value="CAMBION_F_NKD_Wing_A" />
	<attribute id="NeedsSkeletonRemap" type="bool" value="False" />
	<attribute id="RemapperSlotId" type="FixedString" value="" />
	<attribute id="ScalpMaterialId" type="FixedString" value="" />
	<attribute id="SkeletonResource" type="FixedString" value="" />
	<attribute id="SkeletonSlot" type="FixedString" value="" />
	<attribute id="Slot" type="FixedString" value="Unassigned" />
	<attribute id="SoftbodyResourceID" type="FixedString" value="" />
	<attribute id="SourceFile" type="LSString" value="Generated/Public/Shared/Assets/Characters/_Models/_Creatures/Cambion/_Female/Resources/CAMBION_F_NKD_Wing_A.GR2" />
	<attribute id="SupportsVertexColorMask" type="bool" value="False" />
	<attribute id="Template" type="FixedString" value="Generated/Public/Shared/Assets/Characters/_Models/_Creatures/Cambion/_Female/Resources/CAMBION_F_NKD_Wing_A.Dummy_Root.0" />
	<attribute id="_OriginalFileVersion_" type="int64" value="144115207403209024" />
	<children>
		<node id="AnimationWaterfall">
			<attribute id="Object" type="FixedString" value="" />
		</node>
		<node id="Base" />
		<node id="ClothProxyMapping" />
		<node id="Objects">
			<attribute id="LOD" type="uint8" value="0" />
			<attribute id="MaterialID" type="FixedString" value="9e2966c7-b61c-4bc1-bef1-a79cb5fde067" />
			<attribute id="ObjectID" type="FixedString" value="CAMBION_F_NKD_Wing_A.CAMBION_F_NKD_Wing_A_Mesh.0" />
		</node>
		<node id="Objects">
			<attribute id="LOD" type="uint8" value="1" />
			<attribute id="MaterialID" type="FixedString" value="9e2966c7-b61c-4bc1-bef1-a79cb5fde067" />
			<attribute id="ObjectID" type="FixedString" value="CAMBION_F_NKD_Wing_A.CAMBION_F_NKD_Wing_A_Mesh_LOD1.1" />
		</node>
		<node id="Objects">
			<attribute id="LOD" type="uint8" value="2" />
			<attribute id="MaterialID" type="FixedString" value="9e2966c7-b61c-4bc1-bef1-a79cb5fde067" />
			<attribute id="ObjectID" type="FixedString" value="CAMBION_F_NKD_Wing_A.CAMBION_F_NKD_Wing_A_Mesh_LOD2.2" />
		</node>
	</children>
</node>]]