if Ext.Debug.IsDeveloperMode() then
    GLOBAL_DEBUG_WINDOW = Ext.IMGUI.NewWindow("Realm_Builder_DebugWindow")
    GLOBAL_DEBUG_WINDOW.Closeable = true
    --GLOBAL_DEBUG_WINDOW.Open = Ext.Debug.IsDeveloperMode()
end

RequireFiles("Client/", {
    "ClientListeners",
    "Localization",
    "Blacklist",
    "Helpers/__init",
    "Keybind/__init",
    "UI/_init",
    "Editor/__init",
    "MCM",
    "CameraUpdater",
})

if GLOBAL_DEBUG_WINDOW then
    local debugButton = GLOBAL_DEBUG_WINDOW:AddButton("Debug Info")

    debugButton.OnClick = function()
        ErrorNotify("Debug", "Memory Usage: " .. tostring(Ext.Utils.GetMemoryUsage()/1024/1024) .. " MB")
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

local PhysicsGroupFlags = Ext.Enums.PhysicsGroupFlags
local PhysicsType = Ext.Enums.PhysicsType

local configurableIntersect = {
    PhysicsType = PhysicsType.Dynamic | PhysicsType.Static,
    PhysicsGroupFlags = PhysicsGroupFlags.Item 
        | PhysicsGroupFlags.Character
        | PhysicsGroupFlags.Scenery
        | PhysicsGroupFlags.VisibleItem,
    PhysicsGroupFlagsExclude = PhysicsGroupFlags.Terrain,
    Function = "RaycastClosest"
}

--- @return PhxPhysicsHit
function Ray:IntersectDebug()
    return Ext.Level[configurableIntersect.Function](self.Origin, self.Direction, configurableIntersect.PhysicsType, configurableIntersect.PhysicsGroupFlags, configurableIntersect.PhysicsGroupFlagsExclude, 1)
end

if false and GLOBAL_DEBUG_WINDOW then
    local header = GLOBAL_DEBUG_WINDOW:AddCollapsingHeader("Raycast Options")

    local funcCombo = header:AddCombo("Function")
    funcCombo.Options = {"RaycastClosest", "RaycastAll"}
    funcCombo.OnChange = function (ev)
        configurableIntersect.Function = GetCombo(ev)
    end

    --- @type RadioButtonOption[]
    local options = StyleHelpers.CreateRadioButtonOptionFromEnum("PhysicsGroupFlags")

    local separator = header:AddSeparatorText("Include Groups")
    local includeGroup = StyleHelpers.AddBitmaskRadioButtons(header, options, configurableIntersect.PhysicsGroupFlags)

    includeGroup.OnChange = function (radioBtn, value)
        configurableIntersect.PhysicsGroupFlags = value
    end

    local excludeSeparator = header:AddSeparatorText("Exclude Groups")
    local excludeGroup = StyleHelpers.AddBitmaskRadioButtons(header, options, configurableIntersect.PhysicsGroupFlagsExclude)

    excludeGroup.OnChange = function (radioBtn, value)
        configurableIntersect.PhysicsGroupFlagsExclude = value
    end

    local debugBtn = header:AddButton("Debug Raycast")
    debugBtn.OnClick = function ()
        local ray = ScreenToWorldRay()
        if not ray then
            return
        end
        local hit = ray:IntersectDebug()
        _D(hit)
    end
end

RB_CharacterManager = CharacterManager.new()
RB_ItemManager = ItemManager.new()
RB_MultiEffectManager = MultiEffectManager.new()
RB_VisualManager = VisualResourceManager.new()
RB_SceneryManager = SceneryManager.new()
RB_TileConstructionManager = TileConstructionManager.new()
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
--- @return table<string, integer>, integer
local function PopulateAllTemplates()
    if RB_ItemManager.populated then return {}, 0 end
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
            RB_TileConstructionManager:PopulateConstruction(object)
            constructionsCnt = constructionsCnt + 1
        elseif object.TemplateType == "prefab" then
            RB_PrefabManager:PopulatePrefab(object)
            prefabCnt = prefabCnt + 1
        end
    end

    RB_CharacterManager.populated = true
    RB_ItemManager.populated = true
    RB_SceneryManager.populated = true
    RB_PrefabManager.populated = true
    RB_TileConstructionManager.populated = true
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
        RBPrintPurple("[Realm Builder] Populating " .. sumCnt .. " root templates took " .. (itemsFinished - now) .. " ms:")
        local longest = -1
        local toPrint = {}
        for k,v in SortedPairs(cnts) do
            longest = math.max(longest, #k)
            table.insert(toPrint, {k, v})
        end
        for _,pair in pairs(toPrint) do
            RBPrintPurple("    " .. PadSuffix(pair[1] .. ":", longest + 2) .. " " .. pair[2])
        end
        RBPrintPurple("[Realm Builder] Populating Effects took " .. (effectsFinished - itemsFinished) .. " ms for " .. effectCnt .. " effects")
    end
end

RegisterOnSessionLoaded(Realm_Builder_Population, 0)


RegisterConsoleCommand("rb_open_the_bloody_gates", function()
    if GLOBAL_DEBUG_WINDOW then
        GLOBAL_DEBUG_WINDOW.Open = true
    end
end, "Opens the Realm Builder debug window.")
