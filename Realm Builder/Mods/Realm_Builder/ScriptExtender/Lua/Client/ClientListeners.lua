NetChannel.SetVisualTransform:SetHandler(function (data)
    local toSet = RBUtils.NormalizeGuidList(data.Guid)
    if not data.Transforms or type(data.Transforms) ~= "table" then
        Warning("SetVisualTransform: No Transforms provided")
        return
    end

    for _, guid in pairs(toSet) do
        local transform = data.Transforms[guid]
        if not transform then 
            goto continue
        end

        local visual = VisualHelpers.GetEntityVisual(guid)
        if not visual then
            RBUtils.WaitUntil(function()
                return VisualHelpers.GetEntityVisual(guid) ~= nil
            end, function ()
                VisualHelpers.SetVisualTransform({guid}, {[guid] = transform})
            end, function ()
                Warning("SetVisualTransform: No visual found for guid: " .. guid .. " after waiting.")
            end)
            --Debug("SetVisualTransform: No visual found for guid: " .. guid .. ", retrying in 30 ticks.")
            goto continue
        end

        VisualHelpers.SetVisualTransform({guid}, {[guid] = transform})

        ::continue::
    end
end)

NetChannel.ApplyVisualPreset:SetHandler(function(data, userID)
    local guid = data.Guid
    local templateName = data.TemplateName
    local preset = data.VisualPreset
    if preset == "" or preset == nil then
        --Warning("ApplyVisualPreset: Preset name is empty or nil.")
        return
    end
    local presetData = {}

    if type(preset) == "string" then
        presetData = GetVisualPresetData(templateName, preset)
        if presetData == nil then
            Warning("ApplyVisualPreset: Preset not found for template " .. templateName .. " and preset name " .. preset)
            return
        end
    else
        presetData = preset
    end

    VisualTabHelpers.SetVisualEdit(guid, presetData)
end)

NetChannel.ClientTimer:SetHandler(function (data, userID)
    if not data.TimerID then
        Warning("ClientTimer: No TimerID provided")
        return
    end
    if data.Ticks then
        Timer:Ticks(data.Ticks, function(timerID)
            NetChannel.ClientTimer:SendToServer({TimerID = data.TimerID})
        end)
    elseif data.MS then
        Timer:After(data.MS, function(timerID)
            NetChannel.ClientTimer:SendToServer({TimerID = data.TimerID})
        end)
    else
        Ext.OnNextTick(function()
            NetChannel.ClientTimer:SendToServer({TimerID = data.TimerID})
        end)
    end
end)