GLOBAL_DEBUG_WINDOW = Ext.IMGUI.NewWindow("Realm_Builder_DebugWindow")
GLOBAL_DEBUG_WINDOW.Closeable = true
GLOBAL_DEBUG_WINDOW.Open = false

local debugWindowRegistery = {}

RegisterOnSessionLoaded(function ()
    for title,renderFunc in SortedPairs(debugWindowRegistery) do
        renderFunc(ImguiElements.AddTree(GLOBAL_DEBUG_WINDOW, title))
    end
    GLOBAL_DEBUG_WINDOW.Open = Ext.Debug.IsDeveloperMode()
end)

---@param title string
---@param renderFunc fun(panel: ExtuiTreeParent)
function RegisterDebugWindow(title, renderFunc)
    debugWindowRegistery[title] = renderFunc
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

RegisterDebugWindow("Realm Builder Debug", function(panel)
    local debugButton = panel:AddButton("Debug Info")

    debugButton.OnClick = function()
        ErrorNotify("Debug", "Memory Usage: " .. tostring(Ext.Utils.GetMemoryUsage()/1024/1024) .. " MB")
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
        configurableIntersect.Function = ImguiHelpers.GetCombo(ev)
    end

    --- @type RadioButtonOption[]
    local options = ImguiHelpers.CreateRadioButtonOptionFromEnum("PhysicsGroupFlags")

    local separator = header:AddSeparatorText("Include Groups")
    local includeGroup = ImguiElements.AddBitmaskRadioButtons(header, options, configurableIntersect.PhysicsGroupFlags)

    includeGroup.OnChange = function (radioBtn, value)
        configurableIntersect.PhysicsGroupFlags = value
    end

    local excludeSeparator = header:AddSeparatorText("Exclude Groups")
    local excludeGroup = ImguiElements.AddBitmaskRadioButtons(header, options, configurableIntersect.PhysicsGroupFlagsExclude)

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


RegisterConsoleCommand("rb_open", function()
    if GLOBAL_DEBUG_WINDOW then
        GLOBAL_DEBUG_WINDOW.Open = true
    end
end, "Opens the Realm Builder debug window.")

--- some random stuff Other mods already did
--- just putting it here for my own convenience
if Ext.Debug.IsDeveloperMode() then
    RegisterDebugWindow("Random", function (panel)
        
        --- PM Extra Data Editor
        local pmTree = ImguiElements.AddTree(panel, "PhotoMode ExtraData")
        local pmEDField = {
            "PhotoModeCameraMovementSpeed",
            "PhotoModeCameraRotationSpeed"
        }
        for i, string in pairs(pmEDField) do
            if string:find("PhotoMode") then
                local getter = function ()
                    return Ext.Stats.GetStatsManager().ExtraData[string]
                end
                local setter = function (val)
                    Ext.Stats.GetStatsManager().ExtraData[string] = val
                end
                ImguiElements.AddEditorByGetter(pmTree, string, getter, setter)
            end
        end

        --#region Photo Mode Camera Proxy
        --- @class PhotoModeCameraProxy : RB_MovableProxy
        --- @field Entity EntityHandle
        local PhotoModeCameraProxy = _Class("PhotoModeCameraProxy", MovableProxy)

        function PhotoModeCameraProxy:__init()
            local entity = Ext.Entity.GetAllEntitiesWithComponent("PhotoModeCameraTransform")[1]
            if not entity then
                self.IsValid = function() return false end
                return
            end
            self.Entity = entity
            self.StickTransform = self:GetTransform()
            local id
            local marker = nil
            NetChannel.CallOsiris:RequestToServer({
                Function = "CreateAt",
                Args = {
                    MARKER_ITEM.SpotLight,
                    self.StickTransform.Translate[1],
                    self.StickTransform.Translate[2],
                    self.StickTransform.Translate[3],
                    0,
                    0,
                    ""
                }
            }, function (response)
                marker = response[1]
            end)
            id = Ext.Events.Tick:Subscribe(function (e)
                if not self:IsValid() then
                    --- @diagnostic disable-next-line
                    NetChannel.Delete:SendToServer({Guid = marker})
                    Ext.Events.Tick:Unsubscribe(id)
                    return
                end
                self.Entity.PhotoModeCameraTransform.Transform = self.StickTransform
                if marker then
                    NetChannel.SetTransform:SendToServer({
                        Guid = marker,
                        Transforms = {
                            [marker] = self.StickTransform
                        }
                    })
                    return
                end
            end)
        end

        function PhotoModeCameraProxy:GetTransform()
            local comp = self.Entity.PhotoModeCameraTransform
            if not comp then
                return nil
            end
            return {
                Translate = Vec3.new(comp.Transform.Translate),
                RotationQuat = Quat.new(comp.Transform.RotationQuat),
                Scale = Vec3.new(1,1,1)
            }
        end

        function PhotoModeCameraProxy:SetTransform(transform)
            local comp = self.Entity.PhotoModeCameraTransform
            if not comp then
                return
            end
            if transform.Translate then
                comp.Transform.Translate = transform.Translate
            end
            if transform.RotationQuat then
                comp.Transform.RotationQuat = transform.RotationQuat
            end
            transform.Scale = {1,1,1}
            self.StickTransform = transform
        end

        function PhotoModeCameraProxy:IsValid()
            return self.Entity and self.Entity.PhotoModeCameraTransform ~= nil
        end

    
        local controlPMBtn = panel:AddButton("Control Photo Mode Camera")
        controlPMBtn.OnClick = function ()
            local proxy = PhotoModeCameraProxy.new()
            RB_GLOBALS.TransformEditor:Select({proxy})
        end

        --#endregion
    end)

end