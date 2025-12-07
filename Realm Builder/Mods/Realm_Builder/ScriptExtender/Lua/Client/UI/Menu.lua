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
        self.entityMenu:UpdateList()
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
        local host = CGetHostCharacter()

        if IsInCharacterCreationMirror() then
            VisualTab.new(host, GetName(host), nil, nil):Render()
            return
        end

        local pick = GetPickingEntity()
        local pickId = HandleToUuid(pick)

        if not pick then
            pickId = host
        end

        if pickId then
            VisualTab.new(pickId, GetName(pickId), nil, nil):Render()
        elseif pick.Visual then
            VisualHelpers.RegisterVisual(pick)
            if pick.Scenery then
                VisualTab.CreateByEntity(pick, pick.Scenery.Uuid, "Scenery"):Render()
            else
                _D(pick:GetAllComponents())
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

    local browserMenu = RegisterWindow("generic", "Browser Menu", "Browser Menu")
    browserMenu.Closeable = true
    browserMenu:SetSize({ 300 * SCALE_FACTOR, 600 * SCALE_FACTOR })

    local allAvailableBrowsers = {
        {Key = "item", Label = "Item"},
        {Key = "effect", Label = "Effect"},
        {Key = "visual", Label = "Visual"},
        {Key = "character", Label = "Character"},
        {Key = "scenery", Label = "Scenery"},
        {Key = "prefab", Label = "Prefab"},
        {Key = "construction", Label = "Tile Construction"},
    }
    table.sort(allAvailableBrowsers, function(a,b) return a.Label < b.Label end)

    self.browserBtns = {}
    for _, browser in pairs(allAvailableBrowsers) do
        local btn = browserMenu:AddButton(browser.Label)
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
    local screenWidth, screenHeight = GetScreenSize()
    local MENU_WIDTH = screenWidth * 0.25
    local MENU_HEIGHT = screenHeight
    local MENU_X = screenWidth - MENU_WIDTH
    local MENU_Y = 0

    self.panel = RegisterWindow("Citadel", "Realm Builder", "MainMenu", self, { MENU_X, MENU_Y}, {MENU_WIDTH, MENU_HEIGHT})
    self.panel.Closeable = true

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
        self.browsers.item = ItemBrowser.new(RB_ItemManager, "Item - Browser")
        self.browsers.item:CreateCachedSort("DisplayName")
        Debug("Item Browser initialized.")
    end)

    Timer:Ticks(8, function()
        self.browsers.effect = EffectBrowser.new(RB_MultiEffectManager, "Effect - Browser")
        self.browsers.effect:CreateCachedSort("DisplayName")
        Debug("Effect Browser initialized.")
    end)

    Timer:Ticks(9, function()
        self.browsers.character = RootTemplateBrowser.new(RB_CharacterManager, "Character - Browser")
        self.browsers.character:CreateCachedSort("TemplateName")
        Debug("Character Browser initialized.")
    end)

    Timer:Ticks(9, function()
        self.browsers.scenery = RootTemplateBrowser.new(RB_SceneryManager, "Scenery - Browser")
        self.browsers.scenery:CreateCachedSort("TemplateName")
        Debug("Scenery Browser initialized.")
    end)

    Timer:Ticks(9, function()
        self.browsers.prefab = RootTemplateBrowser.new(RB_PrefabManager, "Prefab - Browser")
        self.browsers.prefab:CreateCachedSort("TemplateName")
        Debug("Prefab Browser initialized.")
    end)

    Timer:Ticks(9, function()
        self.browsers.construction = RootTemplateBrowser.new(RB_TileConstructionManager, "Tile Construction - Browser")
        self.browsers.construction:CreateCachedSort("TemplateName")
        Debug("Tile Construction Browser initialized.")
    end)

    Timer:Ticks(10, function()
        if not RB_VisualManager or not RB_VisualManager.populated then
            return
        end
        self.browsers.visual = RootTemplateBrowser.new(RB_VisualManager, "Visual - Browser")
        self.browsers.visual.iconTooltipName = "SourceFile"
        self.browsers.visual.TooltipChangeLogic = function()
        
        end
        self.browsers.visual:CreateCachedSort("SourceFile")
        Debug("Visual Browser initialized.")
    end)

    Timer:Ticks(10, function()
        self:RenderBrowserMenu()
    end)

    Timer:Ticks(10, function()
        local tab = self.tabBar:AddTabItem("Materials")
        local childWin = tab:AddChildWindow("Material Presets Workshop")
        local window = RegisterWindow("generic", "Material Presets Workshop", "Material Presets Workshop", MaterialPresetsMenu)
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
        DeleteWindow(self.panel)
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
RBMenu = nil
RegisterOnSessionLoaded(function()
    if RBMenu == nil then
        RBMenu = RealmBuilderMainMenu:Add()
        RBMenu.panel.Open = false
    end
end, 100)



