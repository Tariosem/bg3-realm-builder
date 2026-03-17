--- @class RB_MainMenu
--- @field isValid boolean
--- @field effectsMenu EffectsMenu
--- @field entityMenu OutlinerMenu
--- @field sceneMenu SceneMenu
--- @field styleMenu StyleMenu
--- @field browsers table<string, IconBrowser>
--- @field panel ExtuiWindowBase
--- @field tabBar ExtuiTabBar
--- @field FocusOnTab fun(self:RB_MainMenu, guid:string, doDetach:boolean|nil)
RealmBuilderMainMenu = _Class("Menu")

function RealmBuilderMainMenu:__init()
    self.isValid = true
    self.panel = nil
    self.tabs = {}

    self:RegisterEvents()
end

function RealmBuilderMainMenu:RegisterEvents()
    local meMod = KeybindManager:CreateModule("GeneralShortcuts")

    meMod:RegisterEvent("OpenMainMenu", function(e)
        if e.Event ~= "KeyDown" then return end

        if self.panel then
            self.panel.Open = not self.panel.Open
        end
        NetChannel.ManageEntity:SendToServer({ Action = "Scan" })
    end)

    meMod:RegisterEvent("OpenTransformToolbar", function(e)
        if e.Event ~= "KeyDown" then return end
        if self.transformBar then
            self.transformBar:Toggle()
        end
    end)

    meMod:RegisterEvent("OpenBrowserMenu", function(e)
        if e.Event ~= "KeyDown" then return end
        if self.browserMenu then
            self.browserMenu.Open = not self.browserMenu.Open
        end
    end)
    
    meMod:RegisterEvent("DeleteAllGizmos", function (e)
        local globalEditor = RB_GLOBALS.TransformEditor
        if e.Event ~= "KeyDown" then return end
        if globalEditor.IsDragging then return end
        if not globalEditor.Gizmo.Guid then
            NetChannel.ManageGizmo:RequestToServer({ Clear = true }, function (response)
                globalEditor.Gizmo.Guid = nil
                globalEditor.Gizmo.SavedGizmos = {}
            end)
        end
        globalEditor.Gizmo:DeleteItem()
        globalEditor.Target = nil
    end)

    meMod:RegisterEvent("OpenVisualTab", function (e)
        if e.Event ~= "KeyDown" then return end
        local host = RBGetHostCharacter()

        if IsInCharacterCreationMirror() then
            VisualTab.new(host, RBGetName(host), nil, nil):Render()
            return
        end

        local pick = PickingUtils.GetPickingEntity()
        local pickId = HandleToUuid(pick)

        if not pick then
            pickId = host
        end

        if pickId then
            VisualTab.new(pickId, RBGetName(pickId), nil, nil):Render()
        elseif pick.Visual then
            VisualHelpers.RegisterVisual(pick)
            if pick.Scenery then
                VisualTab.CreateByEntity(pick, pick.Scenery.Uuid, "Scenery"):Render()
            else
                --_D(pick:GetAllComponents())
            end
        end
    end)
end

function RealmBuilderMainMenu:RenderBrowserMenu()
    local function ToggleBrowser(targetKey)
        local targetBrowser = self.browsers[targetKey]

        for key, browser in pairs(self.browsers) do
            if key ~= targetKey and browser and browser.panel and browser.panel.Open then
                browser:Close()
            end
        end
        targetBrowser:Toggle()
        
    end

    local browserMenu = WindowManager.RegisterWindow("generic", "Browser Menu")
    browserMenu.Closeable = true
    browserMenu:SetSize({ 300 * SCALE_FACTOR, 600 * SCALE_FACTOR })

    local allAvailableBrowsers = {
        {Key = "item", Label = "Item"},
        {Key = "effect", Label = "Effect"},
        {Key = "visual", Label = "Visual"},
        {Key = "character", Label = "Character"},
        {Key = "scenery", Label = "Scenery"},
        {Key = "prefab", Label = "Prefab"},
        --{Key = "construction", Label = "Tile Construction"},
        {Key = "CCAV", Label = "Character Creation Appearance Visuals"},
    }
    
    table.sort(allAvailableBrowsers, function(a,b) return a.Label < b.Label end)

    self.browserBtns = {}
    for _, browser in pairs(allAvailableBrowsers) do
        local btn = browserMenu:AddButton(GetLoca(browser.Label))
        btn.OnClick = function()
            ToggleBrowser(browser.Key)
        end
        if not self.browsers[browser.Key] then
            btn.Visible = false
        end
        self.browserBtns[browser.Key] = btn
    end
    allAvailableBrowsers = nil

    self.browserMenu = browserMenu
    browserMenu.Open = false
end

function RealmBuilderMainMenu:Render()
    local screenWidth, screenHeight = UIHelpers.GetScreenSize()
    local MENU_WIDTH = screenWidth * 0.25
    local MENU_HEIGHT = screenHeight
    local MENU_X = screenWidth - MENU_WIDTH
    local MENU_Y = 0

    local panel = WindowManager.RegisterWindow("Citadel", "Realm Builder", {MENU_X, MENU_Y}, {MENU_WIDTH, MENU_HEIGHT})
    self.panel = panel
    panel.Closeable = true
    WindowManager.SetMainWindowHandle(panel)

    self.tabBar = self.panel:AddTabBar("TabBar")
    self.tabBar.Reorderable = true

    self.browsers = {}

    local now = Ext.Timer.MonotonicTime()
    Timer:Ticks(1, function()
        self.styleMenu = StyleMenu:Add(self.tabBar)
    end)

    Timer:Ticks(2, function()
        self.sceneMenu = SceneMenu:Add(self.tabBar)
        RB_GLOBALS.SceneMenu = self.sceneMenu
    end)

    Timer:Ticks(3, function()
        self.entityMenu = OutlinerMenu:Add(self.tabBar)
    end)

    Timer:Ticks(4, function()
        self.effectsMenu = EffectsMenu:Add(self.tabBar)
    end)


    Timer:Ticks(5, function()
        self.transformBar = TransformToolbar:Add(self.tabBar)
        self.transformBar:Toggle()
    end)

    Timer:Ticks(6, function()
        KeybindMenu:Render(self.tabBar)
    end)

    Timer:Ticks(7, function()
        Debug("Initializing Browsers...")
        self.browsers.item = ItemBrowser.new(RB_GLOBALS.ItemManager, "Item - Browser")
        self.browsers.item:CreateCachedSort("DisplayName")
        Debug("Item Browser initialized.")
    end)

    Timer:Ticks(8, function()
        self.browsers.effect = EffectBrowser.new(RB_GLOBALS.MultiEffectManager, "Effect - Browser")
        self.browsers.effect:CreateCachedSort("DisplayName")
        Debug("Effect Browser initialized.")
    end)

    Timer:Ticks(9, function()
        self.browsers.character = RootTemplateBrowser.new(RB_GLOBALS.CharacterManager, "Character - Browser")
        self.browsers.character.templateType = "character"
        self.browsers.character:CreateCachedSort("TemplateName")
        Debug("Character Browser initialized.")
    end)

    Timer:Ticks(9, function()
        self.browsers.scenery = RootTemplateBrowser.new(RB_GLOBALS.SceneryManager, "Scenery - Browser")
        self.browsers.scenery:CreateCachedSort("TemplateName")
        Debug("Scenery Browser initialized.")
    end)

    Timer:Ticks(9, function()
        self.browsers.prefab = RootTemplateBrowser.new(RB_GLOBALS.PrefabManager, "Prefab - Browser")
        self.browsers.prefab.templateType = "prefab"
        self.browsers.prefab:CreateCachedSort("TemplateName")
        Debug("Prefab Browser initialized.")
    end)

    Timer:Ticks(9, function()
        self.browsers.construction = RootTemplateBrowser.new(RB_GLOBALS.TileConstructionManager, "Tile Construction - Browser")
        self.browsers.construction:CreateCachedSort("TemplateName")
        Debug("Tile Construction Browser initialized.")
    end)

    Timer:Ticks(10, function()
        if not RB_GLOBALS.VisualManager or not RB_GLOBALS.VisualManager.populated then
            return
        end
        local visualBrowser = RB_GLOBALS.VisualManager:SetupVisualBrowser()
        self.browsers.visual = visualBrowser
        self.browsers.visual:CreateCachedSort("SourceFile")
        Debug("Visual Browser initialized.")        
    end)

    Timer:Ticks(9, function (timerID)
        if not RB_GLOBALS.CCAVManager or not RB_GLOBALS.CCAVManager.populated then
            return
        end
        self.browsers.CCAV = RB_GLOBALS.CCAVManager:SetupCCAVBrowser()
        self.browsers.CCAV:CreateCachedSort("DisplayName")
        Debug("CCAV Browser initialized.")
    end)

    Timer:Ticks(10, function()
        self:RenderBrowserMenu()
    end)

    Timer:Ticks(10, function()
        local tab = self.tabBar:AddTabItem("Materials")
        local childWin = tab:AddChildWindow("Material Presets Workshop")
        local window = WindowManager.RegisterWindow("generic", "Material Presets Workshop")
        local render = MaterialPresetsMenu:RenderCCModExportMenu(childWin)
        local isWindow = false

        local tabDetachFunc
        window.Closeable = true
        window.Open = false
        window.OnClose = function ()
            if not isWindow then return end

            childWin.OnRightClick = tabDetachFunc
            isWindow = false
        
            ImguiHelpers.DestroyAllChildren(childWin)
            ImguiHelpers.DestroyAllChildren(window)
            render(childWin)
        end

        tabDetachFunc = function ()
            if isWindow then return end
            childWin.OnRightClick = tabDetachFunc
            window.Open = true
            isWindow = true

            ImguiHelpers.DestroyAllChildren(childWin)
            ImguiHelpers.DestroyAllChildren(window)
            MaterialPresetsMenu:RenderCCPresetsLib(childWin)
            render(window)
        end

        childWin.OnRightClick = tabDetachFunc
        
    end)
end

function RealmBuilderMainMenu:NewEntityAdded(guid)
    if self.entityMenu then
        self.entityMenu:NewEntityAdded(guid)
    end
end

function RealmBuilderMainMenu:EntityDeleted(guid)
    if self.entityMenu then
        self.entityMenu:EntityDeleted(guid)
    end
end

function RealmBuilderMainMenu:Destroy()
    if not self.isValid then
        return
    end
    if self.styleMenu then
        self.styleMenu:Destroy()
        self.styleMenu = nil
    end
    if self.sceneMenu then
        self.sceneMenu:Destroy()
        self.sceneMenu = nil
    end
    if self.entityMenu then
        self.entityMenu:Destroy()
        self.entityMenu = nil
    end
    if self.effectsMenu then
        self.effectsMenu:Destroy()
        self.effectsMenu = nil
    end
    if self.panel then
        --- @diagnostic disable-next-line
        WindowManager.DeleteWindow(self.panel)
        self.panel = nil
    end
    self.isValid = false
end

--- @return RB_MainMenu
function RealmBuilderMainMenu:Add()
    local menu = RealmBuilderMainMenu.new()
    menu:Render()
    return menu
end

--- @type RB_MainMenu
EventsSubscriber.RegisterOnSessionLoaded(function()
    if RB_GLOBALS.MainMenu == nil then
        RB_GLOBALS.MainMenu = RealmBuilderMainMenu:Add()
        RB_GLOBALS.MainMenu.panel.Open = false
    end
end, 100)



