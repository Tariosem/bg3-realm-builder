MENU_WIDTH = 1000 * SCALE_FACTOR
MENU_HEIGHT = 1200 * SCALE_FACTOR

Menu = _Class("Menu")
--- @class RB_MainMenu
--- @field isValid boolean
--- @field effectsMenu EffectsMenu
--- @field entityMenu OutlinerMenu
--- @field sceneMenu SceneMenu
--- @field styleMenu StyleMenu
--- @field itemBrowser ItemBrowser
--- @field effectBrowser EffectBrowser
--- @field panel ExtuiWindowBase
--- @field tabBar ExtuiTabBar
--- @field FocusOnTab fun(self:RB_MainMenu, guid:string, doDetach:boolean|nil)
function Menu:__init()
    self.isValid = true
    self.panel = nil
    self.tabs = {}

    self:RegisterEvents()
end

function Menu:RegisterEvents()
    local meMod = KeybindManager:CreateModule("Generic")

    meMod:RegisterEvent("ToggleMenu", function(e)
        if e.Event ~= "KeyDown" then return end

        if self.panel then
            self.panel.Open = not self.panel.Open
        end
    end)

    meMod:RegisterEvent("OpenTransformToolbar", function(e)
        if e.Event ~= "KeyDown" then return end
        if self.editorMenu then
            self.editorMenu:Toggle()
        end
    end)
end

function Menu:Render()
    self.panel = RegisterWindow("Citadel", "Realm Builder", "MainMenu", self, nil, {MENU_WIDTH, MENU_HEIGHT})
    self.panel.Closeable = true

    self.tabBar = self.panel:AddTabBar("TabBar")
    self.tabBar.Reorderable = true
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
        self.editorMenu = TransformToolbar:Add(self.tabBar)
    end)

    Timer:Ticks(6, function()
        KeybindMenu:Render(self.tabBar)
    end)

    Timer:Ticks(7, function()
        self.itemBrowser = ItemBrowser.new(RB_ItemManager, "Item - Browser")
        self.itemBrowser:CreateCachedSort("DisplayName")
    end)

    Timer:Ticks(8, function()
        self.effectBrowser = EffectBrowser.new(RB_MultiEffectManager, "Effect - Browser")
        self.effectBrowser:CreateCachedSort("DisplayName")
    end)

    Timer:Ticks(9, function()
        self.characterBrowser = RootTemplateBrowser.new(RB_CharacterManager, "Character - Browser")
        self.characterBrowser:CreateCachedSort("DisplayName")
    end)

    Timer:Ticks(9, function()
        self.sceneryBrowser = RootTemplateBrowser.new(RB_SceneryManager, "Scenery - Browser")
        self.sceneryBrowser:CreateCachedSort("DisplayName")
    end)

    Timer:Ticks(9, function()
        self.prefabBrowser = RootTemplateBrowser.new(RB_PrefabManager, "Prefab - Browser")
        self.prefabBrowser:CreateCachedSort("TemplateName")
    end)

    Timer:Ticks(9, function()
        local tab = self.tabBar:AddTabItem("Materials")
        local childWin = tab:AddChildWindow("Material Presets Workshop")
        local window = RegisterWindow("generic", "Material Presets Workshop", "Material Presets Workshop", MaterialPresetsMenu)
        local render = MaterialPresetsMenu:RenderCustomMaterialPresets(childWin)
        local isWindow = false

        local tabDetachFunc
        window.Closeable = true
        window.Open = false
        window.OnClose = function ()
            if not isWindow then return end

            childWin.OnRightClick = tabDetachFunc
            isWindow = false

        
            DestroyAllChildren(childWin)
            DestroyAllChildren(window)
            render(childWin)
        end

        tabDetachFunc = function ()
            if isWindow then return end
            childWin.OnRightClick = tabDetachFunc
            window.Open = true
            isWindow = true

            DestroyAllChildren(childWin)
            DestroyAllChildren(window)
            MaterialPresetsMenu:RenderCCPresetsLib(childWin)
            render(window)
        end

        childWin.OnRightClick = tabDetachFunc
        
    end)
end

function Menu:NewEntityAdded(guid)
    if self.entityMenu then
        self.entityMenu:NewEntityAdded(guid)
    end
end

function Menu:EntityDeleted(guid)
    if self.entityMenu then
        self.entityMenu:EntityDeleted(guid)
    end
end

function Menu:Destroy()
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
function Menu:Add()
    local menu = Menu.new()
    menu:Render()
    return menu
end

--- @type RB_MainMenu
RBMenu = nil
RegisterOnSessionLoaded(function()
    if RBMenu == nil then
        RBMenu = Menu:Add()
        RBMenu.panel.Open = false
    end
end, 100)



