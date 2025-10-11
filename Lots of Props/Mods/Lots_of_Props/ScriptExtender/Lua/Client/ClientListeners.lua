ClientSubscribe(NetMessage.SetVisualTransform, function (data)
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

ClientSubscribe(NetMessage.SetLineColor, function (data)
    GizmoVisualizer.SetLineFxColor(data.Guid, data.Color)
end)