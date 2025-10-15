NetChannel.SetVisualTransform:SetHandler(function (data)
    local toSet = NormalizeGuidList(data.Guid)
    if not data.Transforms or type(data.Transforms) ~= "table" then
        Warning("SetVisualTransform: No Transforms provided")
        return
    end

    for _, guid in pairs(toSet) do
        local transform = data.Transforms[guid]
        if not transform then goto continue end
        local entity = Ext.Entity.Get(guid)
        if not entity then goto continue end
        if entity.PartyMember then
            local dummy = GetDummyByUuid(guid)
            if dummy then
                entity = dummy
            end
        end

        local visual = VisualHelpers.GetEntityVisual(entity)
        if not visual then goto continue end

        if CIsCharacter(guid) then
            if transform.Translate then
                visual:SetWorldTranslate(transform.Translate)
            end
            if transform.RotationQuat then
                visual:SetWorldRotate(transform.RotationQuat)
            end
            if transform.Scale then
                visual:SetWorldScale(transform.Scale)
            end
            goto continue
        end

        for _,obj in pairs(visual.ObjectDescs) do
            local renderable = obj.Renderable
            if transform.Translate then
                renderable:SetWorldTranslate(transform.Translate)
            end
            if transform.RotationQuat then
                renderable:SetWorldRotate(transform.RotationQuat)
            end
            if transform.Scale then
                renderable:SetWorldScale(transform.Scale)
            end
        end
        ::continue::
    end
end)

NetChannel.ApplyVisualPreset:SetHandler(function(data, userID)
    local guid = data.Guid
    local templateName = data.TemplateName
    local presetName = data.VisualPreset
    if presetName == "" or presetName == nil then
        --Warning("ApplyVisualPreset: Preset name is empty or nil.")
        return
    end
    local preset = GetVisualPresetData(templateName, presetName)
    if preset == nil then
        Warning("ApplyVisualPreset: Preset not found for template " .. templateName .. " and preset name " .. presetName)
        return
    end
    local modifiedParams = preset.ModifiedParams
    VisualHelpers.ApplyVisualParams(guid, modifiedParams)
end)