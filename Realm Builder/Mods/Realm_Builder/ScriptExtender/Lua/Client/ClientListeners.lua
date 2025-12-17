NetChannel.SetVisualTransform:SetHandler(function (data)
    local toSet = RBUtils.NormalizeGuidList(data.Guid)
    if not data.Transforms or type(data.Transforms) ~= "table" then
        Warning("SetVisualTransform: No Transforms provided")
        return
    end

    for _, guid in pairs(toSet) do
        local transform = data.Transforms[guid]
        if not transform then 
            Warning("SetVisualTransform: No transform data for guid: " .. guid)
            goto continue
        end

        local visual = VisualHelpers.GetEntityVisual(guid)
        if not visual then
            Timer:Ticks(30, function()
                local delayedVisual = VisualHelpers.GetEntityVisual(guid)
                if delayedVisual then
                    VisualHelpers.SetVisualTransform({guid}, {[guid] = transform})
                else
                    Warning("SetVisualTransform (delayed): No visual found for guid: " .. guid)
                end
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
    VisualHelpers.ApplyVisualParams(guid, preset)
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