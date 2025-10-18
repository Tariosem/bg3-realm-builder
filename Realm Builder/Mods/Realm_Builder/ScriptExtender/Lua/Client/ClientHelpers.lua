function MakePropLSX(guid, modName)
    local curLevel = _C().Level.LevelName
    local propData = EntityStore:GetEntity(guid)
    local entity = Ext.Entity.Get(guid)
    if not propData then
        Error("MakePropLSX: No prop data found for GUID " .. tostring(guid))
        return nil
    end

    local root = LSXUtils.new()
    if not root then
        Error("MakePropLSX: Failed to create LSX root node.")
        return nil
    end

    local regionWrapper = LSXUtils.RegionNodeWrapper("Templates", root)

    local firstChildren = LSXNode.new("Children")
    regionWrapper:AppendChild(firstChildren)

    local gameObjectNode = LSXNode.new("node", { id = "GameObjects" })
    firstChildren:AppendChild(gameObjectNode)

    local basicAttrs = {
        LSXUtils.AttrNode("MapKey", "FixedString", guid),
        LSXUtils.AttrNode("Name", "LSString", propData.DisplayName or TrimTail(propData.TemplateId, 37)),
        LSXUtils.AttrNode("LevelName", "FixedString", curLevel),
        LSXUtils.AttrNode("Type", "FixedString", "item"),
        LSXUtils.AttrNode("TemplateName", "FixedString", TakeTailTemplate(propData.TemplateId)),
        LSXUtils.AttrNode("GravityType", "uint8", propData.Gravity and 0 or 1),
    }

    gameObjectNode:AppendChildren(basicAttrs)

    local secondChidren = LSXNode.new("Children")
    gameObjectNode:AppendChild(secondChidren)

    local transformNode = LSXNode.new("node", { id = "Transform" })
    secondChidren:AppendChild(transformNode)

    local pos = {CGetPosition(guid)}
    local rot = {CGetRotation(guid)}
    local scale = {CGetScale(guid)}
    local smallestScale = math.min(scale[1], scale[2], scale[3])

    local transformAttrs = {
        LSXUtils.AttrNode("Position", "fvec3", pos),
        LSXUtils.AttrNode("RotationQuat", "fvec4", rot),
        LSXUtils.AttrNode("Scale", "float", smallestScale),
    }

    transformNode:AppendChildren(transformAttrs)


    local layerListNode = LSXNode.new("node", { id = "LayerList" })
    secondChidren:AppendChild(layerListNode)

    local layerFirstChildren = LSXNode.new("Children")
    layerListNode:AppendChild(layerFirstChildren)

    local layerNode = LSXNode.new("node", { id = "Layer" })
    layerFirstChildren:AppendChild(layerNode)

    local layerSecondChildren = LSXNode.new("Children")
    layerNode:AppendChild(layerSecondChildren)

    local objectNode = LSXNode.new("node", { id = "Object", key = "MapKey" })
    layerSecondChildren:AppendChild(objectNode)

    local layerAttr = {
        LSXUtils.AttrNode("MapKey", "FixedString", curLevel),
    }

    objectNode:AppendChildren(layerAttr)

    if not modName then
        modName = "Mods"
    end

    local path = string.format("Realm_Builder/LSX/%s/Mods/%s/Levels/%s/items/%s", modName, modName, curLevel, propData.DisplayName)

    --- Sanitize path
    path:gsub("[<>:\"/\\|%?%*]", "_")

    local suc = Ext.IO.SaveFile(path, root:Stringify())

    if not suc then
        Error("MakePropLSX: Failed to save LSX file at " .. path)
        return nil
    end

    return suc
end