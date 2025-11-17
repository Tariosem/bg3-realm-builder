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
        ErrorNotify("Debug", "Memory Usage: " .. tostring(Ext.Utils.GetMemoryUsage()/1024/1024) .. " MB")
        ErrorNotify("Error", "This is a test error notification.")
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
RB_SceneryManager = SceneryManager.new()
RB_PrefabManager = PrefabManager.new()

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

local function PopulateAllTemplates()
    if RB_ItemManager.populated then return -1 end
    local itemCnt = 0
    local characterCnt = 0
    local sceneryCnt = 0
    local constructionsCnt = 0
    local prefabCnt = 0

    local allWeaponStats = Ext.Stats.GetStats("Weapon")
    for _, statsId in pairs(allWeaponStats) do
        local statsObj = Ext.Stats.Get(statsId)
        if statsObj.RootTemplate == "" or RB_ItemManager.Data[statsObj.RootTemplate] then goto continue end

        if statsObj and statsObj.RootTemplate and not RB_ItemManager.Data[statsObj.RootTemplate] then
            RB_ItemManager.Data[statsObj.RootTemplate] = RB_ItemManager:PopulateWeapon(statsObj, statsId)
            itemCnt = itemCnt + 1
        end

        ::continue::
    end

    local allArmorStats = Ext.Stats.GetStats("Armor")
    for _, statsId in pairs(allArmorStats) do
        local statsObj = Ext.Stats.Get(statsId)
        if statsObj.RootTemplate == "" or RB_ItemManager.Data[statsObj.RootTemplate] then goto continue end

        if statsObj and statsObj.RootTemplate and not RB_ItemManager.Data[statsObj.RootTemplate] then
            RB_ItemManager.Data[statsObj.RootTemplate] = RB_ItemManager:PopulateArmor(statsObj, statsId)
            itemCnt = itemCnt + 1
        end
        ::continue::
    end

    local debug = false
    local raw = Ext.ClientTemplate.GetAllRootTemplates()
    for uuid, object in pairs(raw) do
        if object.TemplateType == "item" and not RB_ItemManager.Data[uuid] then
            object = object --[[@as ItemTemplate]]
            RB_ItemManager.Data[object.Id] = RB_ItemManager:PopulateItem(object)
            RB_ItemManager.UuidToTemplateName[object.Id] = object.Name
            RB_ItemManager.TemplateNameToUuid[object.Name] = object.Id
            itemCnt = itemCnt + 1
        elseif object.TemplateType == "character" then
            --- @diagnostic disable-next-line
            RB_CharacterManager:PopulateCharacter(object)
            characterCnt = characterCnt + 1
        elseif object.TemplateType == "scenery" then
            object = object --[[@as SceneryTemplate]]
            RB_SceneryManager:PopulateScenery(object)
            sceneryCnt = sceneryCnt + 1
        elseif object.TemplateType == "TileConstruction" then
            object = object --[[@as ConstructionTemplate]]
            RB_SceneryManager:PopulateConstruction(object)
            constructionsCnt = constructionsCnt + 1
        elseif object.TemplateType == "prefab" then
            RB_PrefabManager:PopulatePrefab(object)
            prefabCnt = prefabCnt + 1
        end
        ::continue::
    end

    RB_CharacterManager.populated = true
    RB_ItemManager.populated = true
    RB_SceneryManager.populated = true
    RB_PrefabManager.populated = true
    RB_ItemManager.modCache = {}
    return {
        Items = itemCnt,
        Characters = characterCnt,
        Scenery = sceneryCnt,
        TileConstructions = constructionsCnt,
        Prefabs = prefabCnt,
    }, itemCnt + characterCnt + sceneryCnt + constructionsCnt + prefabCnt
end


local function Realm_Builder_Population()
    local now = Ext.Timer:MonotonicTime()
    local cnts, sumCnt = PopulateAllTemplates()
    local itemsFinished = Ext.Timer:MonotonicTime()
    local effectCnt = RB_MultiEffectManager:PopulateAllEffects()
    local effectsFinished = Ext.Timer:MonotonicTime()
    if sumCnt >= 0 then
        RPrintPurple("[Realm Builder] Populating " .. sumCnt .. " root templates took " .. (itemsFinished - now) .. " ms:")
        for k,v in SortedPairs(cnts) do
            RPrintPurple("    " .. tostring(k) .. ": " .. tostring(v))
        end
        RPrintPurple("[Realm Builder] Populating Effects took " .. (effectsFinished - itemsFinished) .. " ms for " .. effectCnt .. " effects")
    end
end

RegisterOnSessionLoaded(Realm_Builder_Population, 0)


Ext.RegisterConsoleCommand("rb_open_the_bloody_gates", function()
    if GLOBAL_DEBUG_WINDOW then
        GLOBAL_DEBUG_WINDOW.Open = true
    end
end, "Opens the Realm Builder debug window.")

