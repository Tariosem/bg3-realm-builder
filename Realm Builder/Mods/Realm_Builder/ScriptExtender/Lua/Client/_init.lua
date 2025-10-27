function Post(channel, payload)
    payload = payload or {}
    if type(payload) ~= "string" then
        payload = Ext.Json.Stringify(payload)
    end
    Ext.ClientNet.PostMessageToServer(channel .. ModuleUUID, payload)
end

---@param channel any
---@param callback fun(data:table):any
---@return RBSubscription
function ClientSubscribe(channel, callback)
    --Debug("Subscribe to channel: " .. channel)
    local unsubscribed = false
    local sub

    local unsub = function()
        if sub ~= -1 then
            unsubscribed = true
            Ext.Events.NetMessage:Unsubscribe(sub)
            sub = -1
        end
    end

    sub = Ext.Events.NetMessage:Subscribe(function (e)
        if unsubscribed then return end
        if e.Channel == channel .. ModuleUUID then
            local data = Ext.Json.Parse(e.Payload)
            if not data then
                Error("Invalid payload for channel: " .. channel .. " - " .. tostring(e.Payload))
                return
            end
            local callbakcReturn = callback(data)
            if callbakcReturn == UNSUBSCRIBE_SYMBOL then
                unsub()
            end
        end
    end)

    return { Unsubscribe = unsub, ID = sub } 
end

GLOBAL_DEBUG_WINDOW = Ext.IMGUI.NewWindow("Realm_Builder_DebugWindow")
GLOBAL_DEBUG_WINDOW.Closeable = true
GLOBAL_DEBUG_WINDOW.Open = false

RequireFiles("Client/", {
    "ClientListeners",
    "Localization",
    "Blacklist",
    "Helpers/__init",
    "KeybindManager",
    "UI/_init",
    "Editor/__init",
    "MCM",
    "CameraUpdater",
})

if GLOBAL_DEBUG_WINDOW then
    local debugButton = GLOBAL_DEBUG_WINDOW:AddButton("Debug Info")
    local surprise = Notification.new("Debug Info")
    surprise.Pivot = {0.5, 0.5}
    surprise.FlickToDismiss = true
    surprise.Duration = 5000

    debugButton.OnClick = function()
        surprise:Show("Debug Info", function (panel)
            local memoryUsage = Ext.Utils.GetMemoryUsage()
            local memStr = string.format("Memory Usage: %.2f MB", memoryUsage / 1024 / 1024)
            panel:AddText(memStr)
        end)
    end

    local visualizeMouseRay = GLOBAL_DEBUG_WINDOW:AddButton("Visualize Mouse Ray")
    local rayVTimer = nil

    visualizeMouseRay.OnClick = function()
        if rayVTimer then
            Timer:Cancel(rayVTimer)
            rayVTimer = nil
            visualizeMouseRay.Label = "Visualize Mouse Ray"
            return
        end

        visualizeMouseRay.Label = "Stop Visualizing Mouse Ray"
        rayVTimer = Timer:Every(1000, function()
            ScreenToWorldRay():Debug()
        end)
    end

end

RB_CharacterManager = CharacterManager.new()
RB_ItemManager = ItemManager.new()
RB_MultiEffectManager = MultiEffectManager.new()

--- @param uuid GUIDSTRING
--- @return GameObjectTemplate|ResourceMultiEffectInfo|ResourceEffectInfo|nil
function GetDataFromUuid(uuid)
    if not uuid or uuid == "" then
        return nil
    end
    TakeTailTemplate(uuid)
    return RB_ItemManager.Data[uuid] or RB_MultiEffectManager.Data[uuid] or {}
end

function GetDataFromName(name)
    if not name or name == "" then
        return nil
    end
    local uuid = RB_ItemManager.TemplateNameToUuid[name] or RB_MultiEffectManager.EffectNameToUuid[name] or nil
    if not uuid then
        return nil
    end
    return GetDataFromUuid(uuid)
end


local function Realm_Builder_Population()
    local now = Ext.Timer:MonotonicTime()
    local itemsCnt = RB_ItemManager:PopulateAllTemplates()
    local itemsFinished = Ext.Timer:MonotonicTime()
    local effectsCnt = RB_MultiEffectManager:PopulateAllEffects()
    local effectsFinished = Ext.Timer:MonotonicTime()
    if itemsCnt ~= -1 and effectsCnt ~= -1 then
        RPrintPurple("[Realm Builder] Populating Items took " .. (itemsFinished - now) .. " ms for " .. itemsCnt .. " items")
        RPrintPurple("[Realm Builder] Populating Effects took " .. (effectsFinished - itemsFinished) .. " ms for " .. effectsCnt .. " effects")
    end
end

RegisterOnSessionLoaded(Realm_Builder_Population, 0)


Ext.RegisterConsoleCommand("rb_open_the_bloody_gates", function()
    if GLOBAL_DEBUG_WINDOW then
        GLOBAL_DEBUG_WINDOW.Open = true
    end
end)

