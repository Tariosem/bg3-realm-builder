local NetListener = {}

---@param channelName any
---@param func fun(channel:string, data:any, userID:string)
function RegisterNetListener(channelName, func)
    NetListener[channelName .. ModuleUUID] = func

    Ext.RegisterNetListener(channelName .. ModuleUUID, function(channel, payload, userID)
        local data = Ext.Json.Parse(payload)
        if not data then
            Error("Invalid payload for channel: " .. channel .. " - " .. tostring(payload))
            return
        end

        NetListener[channel](channel, data, userID)
    end)
end

RegisterNetListener("DeletePropsByTemplateId", function(channel, data, userID)
    local templateId = data.TemplateId
    local guids = EntityManager:DeleteEntityByTemplateId(templateId)

    NetChannel.Entities.Deleted:Broadcast(guids)
end)

RegisterNetListener("DeleteAllProps", function (channel, data, userID)
    local guids = EntityManager:DeleteAll()

    NetChannel.Entities.Deleted:Broadcast(guids)
end)

Ext.ModEvents.BG3MCM["MCM_Setting_Saved"]:Subscribe(function(payload)
end)