GLOBAL_DEBUG_WINDOW = Ext.IMGUI.NewWindow("Realm_Builder_DebugWindow")
GLOBAL_DEBUG_WINDOW.Closeable = true
GLOBAL_DEBUG_WINDOW.Open = false

local debugWindowRegistery = {}

EventsSubscriber.RegisterOnSessionLoaded(function()
    if Ext.Utils.GetGameState() ~= "Running" then return end
    for title, renderFunc in RBUtils.SortedPairs(debugWindowRegistery) do
        renderFunc(ImguiElements.AddTree(GLOBAL_DEBUG_WINDOW, title))
    end
end)

---@param title string
---@param renderFunc fun(panel: ExtuiTreeParent)
function RegisterDebugWindow(title, renderFunc)
    debugWindowRegistery[title] = renderFunc
end

RBUtils.RequireFiles("Client/", {
    "ClientListeners",
    "Localization",
    "Blacklist",
    "Helpers/__init",
    "Keybind/__init",
    "Editor/__init",
    "UI/_init",
    "MCM",
    "CameraUpdater",
})

RegisterDebugWindow("Realm Builder Debug", function(panel)
    local debugButton = panel:AddButton("Debug Info")

    debugButton.OnClick = function()
        ErrorNotify("Debug", "Memory Usage: " .. tostring(Ext.Utils.GetMemoryUsage() / 1024 / 1024) .. " MB")
    end

    local visualizeMouseRay = panel:AddButton("Visualize Mouse Ray")
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
end)

RB_GLOBALS.CharacterManager = CharacterManager.new()
RB_GLOBALS.ItemManager = ItemManager.new()
RB_GLOBALS.MultiEffectManager = MultiEffectManager.new()
RB_GLOBALS.VisualManager = VisualResourceManager.new()
RB_GLOBALS.CCAVManager = CCAVManager.new()
RB_GLOBALS.SceneryManager = SceneryManager.new()
RB_GLOBALS.TileConstructionManager = TileConstructionManager.new()
RB_GLOBALS.PrefabManager = PrefabManager.new()
RB_GLOBALS.CCAVManager = CCAVManager.new()
RB_GLOBALS.VisualManager = VisualResourceManager.new()
RB_GLOBALS.TextureManager = TextureResourceManager

--- @return table<string, integer>, integer
local function PopulateAllTemplates()
    local itemCnt = 0
    local characterCnt = 0
    local sceneryCnt = 0
    local constructionsCnt = 0
    local prefabCnt = 0
    local uuid_blacklist = RESOUCE_UUID_BLACKLIST or {}

    local allWeaponStats = Ext.Stats.GetStats("Weapon")
    for _, statsId in pairs(allWeaponStats) do
        local statsObj = Ext.Stats.Get(statsId)
        if statsObj.RootTemplate == "" or RB_GLOBALS.ItemManager.Data[statsObj.RootTemplate] then goto continue end

        if statsObj and statsObj.RootTemplate and not RB_GLOBALS.ItemManager.Data[statsObj.RootTemplate] then
            RB_GLOBALS.ItemManager.Data[statsObj.RootTemplate] = RB_GLOBALS.ItemManager:PopulateWeapon(statsObj, statsId)
            itemCnt = itemCnt + 1
        end

        ::continue::
    end

    local itemManager = RB_GLOBALS.ItemManager
    local characterManager = RB_GLOBALS.CharacterManager
    local sceneryManager = RB_GLOBALS.SceneryManager
    local prefabManager = RB_GLOBALS.PrefabManager
    local tileConstructionManager = RB_GLOBALS.TileConstructionManager

    local allArmorStats = Ext.Stats.GetStats("Armor")
    for _, statsId in pairs(allArmorStats) do
        local statsObj = Ext.Stats.Get(statsId)
        if statsObj.RootTemplate == "" or itemManager.Data[statsObj.RootTemplate] then goto continue end

        if statsObj and statsObj.RootTemplate and not itemManager.Data[statsObj.RootTemplate] then
            itemManager.Data[statsObj.RootTemplate] = itemManager:PopulateArmor(statsObj, statsId)
            itemCnt = itemCnt + 1
        end
        ::continue::
    end

    local raw = Ext.ClientTemplate.GetAllRootTemplates()
    for uuid, object in pairs(raw) do
        if uuid_blacklist[uuid] then goto continue end

        local ok, err = xpcall(function (...)
            if object.TemplateType == "item" and not itemManager.Data[uuid] then
                object = object --[[@as ItemTemplate]]
                itemManager.Data[object.Id] = itemManager:PopulateItem(object)
                itemManager.UuidToTemplateName[object.Id] = object.Name
                itemManager.TemplateNameToUuid[object.Name] = object.Id
                itemCnt = itemCnt + 1
            elseif object.TemplateType == "character" then
                --- @diagnostic disable-next-line
                characterManager:PopulateCharacter(object)
                characterCnt = characterCnt + 1
            elseif object.TemplateType == "scenery" then
                object = object --[[@as SceneryTemplate]]
                sceneryManager:PopulateScenery(object)
                sceneryCnt = sceneryCnt + 1
            elseif object.TemplateType == "TileConstruction" then
                object = object --[[@as ConstructionTemplate]]
                tileConstructionManager:PopulateConstruction(object)
                constructionsCnt = constructionsCnt + 1
            elseif object.TemplateType == "prefab" then
                prefabManager:PopulatePrefab(object)
                prefabCnt = prefabCnt + 1
            end
        end, debug.traceback)
        if not ok then
            _P("Error populating template with UUID " .. uuid .. ": " .. err)
        end

        ::continue::
    end

    characterManager.populated = true
    itemManager.populated = true
    sceneryManager.populated = true
    prefabManager.populated = true
    tileConstructionManager.populated = true
    itemManager.modCache = {}
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
    local begin = now
    RBPrintPurple("[REALM BUILDER]: Populating templates and resources...")
    local printError = Error

    local cnts, sumCnt = {}, -1
    local ok, err = xpcall(function ()
        cnts, sumCnt = PopulateAllTemplates()
    end, debug.traceback)
    if not ok then
        printError("[Realm Builder] Error populating templates: " .. err)  
    end
    
    local itemsElapsed = Ext.Timer:MonotonicTime() - now
    now = Ext.Timer:MonotonicTime()
    
    local effectCnt = nil
    ok, err = xpcall(function ()
        effectCnt = RB_GLOBALS.MultiEffectManager:PopulateAllEffects()
    end, debug.traceback)
    if not ok then
        printError("[Realm Builder] Error populating effects: " .. err)  
    end
    local effectsElapsed = Ext.Timer:MonotonicTime() - now
    now = Ext.Timer:MonotonicTime()
    
    local visualCnt, visualElapsed = nil, nil
    ok, err = xpcall(function ()
        visualCnt, visualElapsed = RB_GLOBALS.VisualManager:PopulateAllVisualResources()
    end, debug.traceback)
    if not ok then
        printError("[Realm Builder] Error populating visual resources: " .. err)  
    end

    local ccavCnt, ccavElapsed = nil, nil
    ok, err = xpcall(function ()
        ccavCnt, ccavElapsed = RB_GLOBALS.CCAVManager:PopulateAll()
    end, debug.traceback)
    if not ok then
        printError("[Realm Builder] Error populating CCAVs: " .. err)  
    end
    
    local textureCnt, textureElapsed = nil, nil
    ok, err = xpcall(function ()
        textureCnt, textureElapsed = RB_GLOBALS.TextureManager:PopulateAllTextureResources()
    end, debug.traceback)
    if not ok then
        printError("[Realm Builder] Error populating textures: " .. err)  
    end

    local populateInfoTable = {
        Visuals = { Count = visualCnt, Time = visualElapsed },
        CCAVs = { Count = ccavCnt, Time = ccavElapsed },
        Textures = { Count = textureCnt, Time = textureElapsed },
        Effects = { Count = effectCnt, Time = effectsElapsed },
    }

    local longest = -1
    RBPrintPurple("[REALM BUILDER]: Population complete")
    _P("")
    if sumCnt >= 0 then
        local toPrint = {}
        for k, v in RBUtils.SortedPairs(cnts) do
            longest = math.max(longest, #k)
            table.insert(toPrint, { k, v })
        end
        for k, v in RBUtils.SortedPairs(populateInfoTable) do
            longest = math.max(longest, #k)
            table.insert(toPrint, { k, v.Count, v.Time })
        end

        RBPrintPurple(RBStringUtils.PadSuffix("RootTemplate:", longest + 2 + 4) .. " " .. sumCnt .. " time: " .. itemsElapsed .. " ms")
        local other = false
        for _, info in pairs(toPrint) do
            if not other and info[3] then
                RBPrintPurple("\nOther Resources:")
                other = true
            end
            RBPrintPurple("    " .. RBStringUtils.PadSuffix(info[1] .. ":", longest + 2) .. " " .. info[2] .. (info[3] and (" time: " .. info[3] .. " ms") or ""))
        end
    end

    _P("")
    RBPrintPurple(RBStringUtils.PadSuffix("Total population time:", longest + 2 + 4) .. " " .. (Ext.Timer:MonotonicTime() - begin) .. " ms")
end

EventsSubscriber.RegisterOnSessionLoaded(Realm_Builder_Population, 0)

RegisterConsoleCommand("rb_open", function()
    if GLOBAL_DEBUG_WINDOW then
        GLOBAL_DEBUG_WINDOW.Open = true
    end
end, "Opens the Realm Builder debug window.")


Ext.Require("Client/Misc.lua")