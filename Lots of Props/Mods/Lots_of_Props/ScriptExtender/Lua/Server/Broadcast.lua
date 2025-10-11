function PostTo(userID, channel, data)
    local payload = type(data) == "string" and data or Ext.Json.Stringify(data)
    if not payload then
        Error("Failed to serialize data for broadcast: " .. tostring(data))
        return
    end
    --Info("Posting to user " .. tostring(userID) .. " on channel " .. channel)
    Ext.ServerNet.PostMessageToUser(userID, channel .. ModuleUUID, payload)
end

function BroadcastToChannel(channel, data)
    local payload = type(data) == "string" and data or Ext.Json.Stringify(data)
    if not payload then
        Error("Failed to serialize data for broadcast: " .. tostring(data))
        return
    end
    Ext.ServerNet.BroadcastMessage(channel .. ModuleUUID, payload)
end

function BroadcastAllProps()
    local data = PM:GetAllPropsForClients()

    BroadcastToChannel(NetMessage.ServerProps, data)
end

function BroadcastProps(guids)
    if type(guids) ~= "table" then
        Error("BroadcastProps: guids must be a table")
        return
    end

    local data = PM:GetPropsForClients(guids)

    BroadcastToChannel(NetMessage.ServerProps, data)
end

function BroadcastProp(guid)
    local data = PM:GetPropForClients(guid)

    BroadcastToChannel(NetMessage.ServerProps, data)
end

function BroadcastDeletedProps(guids)
    local data = guids

    BroadcastToChannel(NetMessage.DeletedProps, data)
end

function BroadcastVisualPreset(guid, templateName, presetName, force)
    local data = {
        Guid = guid,
        TemplateName = templateName,
        VisualPreset = presetName
    }

    BroadcastToChannel(NetMessage.ApplyVisualPreset, data)
end