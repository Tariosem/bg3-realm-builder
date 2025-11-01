MENU_WIDTH = 1000 * SCALE_FACTOR
MENU_HEIGHT = 1200 * SCALE_FACTOR

Menu = _Class("Menu")
--- @class RB_MainMenu
--- @field isValid boolean
--- @field effectsMenu EffectsMenu
--- @field entityMenu SceneMenu
--- @field presetMenu PresetMenu
--- @field styleMenu StyleMenu
--- @field itemBrowser ItemIconBrowser
--- @field effectBrowser EffectIconBrowser
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
    local now = Ext.Timer.MonotonicTime()
    Timer:Ticks(1, function()
        self.styleMenu = StyleMenu:Add(self.tabBar)
    end)

    now = Ext.Timer.MonotonicTime()

    Timer:Ticks(2, function()
        self.presetMenu = PresetMenu:Add(self.tabBar)
    end)

    Timer:Ticks(3, function()
        self.entityMenu = SceneMenu:Add(self.tabBar)
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
        self.itemBrowser = ItemIconBrowser.new(RB_ItemManager, "Item - Browser")
        self.itemBrowser:CreateCachedSort("DisplayName")
    end)

    Timer:Ticks(8, function()
        self.effectBrowser = EffectIconBrowser.new(RB_MultiEffectManager, "Effect - Browser")
        self.effectBrowser:CreateCachedSort("DisplayName")
    end)

    Timer:Ticks(9, function()
        self.characterBrowser = CharacterBrowser.new(RB_CharacterManager, "Character - Browser")
        self.characterBrowser:CreateCachedSort("DisplayName")
        self.characterBrowser:Render()
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

        
            DestroyAllChilds(childWin)
            DestroyAllChilds(window)
            render(childWin)
        end

        tabDetachFunc = function ()
            if isWindow then return end
            childWin.OnRightClick = tabDetachFunc
            window.Open = true
            isWindow = true

            DestroyAllChilds(childWin)
            DestroyAllChilds(window)
            MaterialPresetsMenu:RenderCCPresetsLib(childWin)
            render(window)
        end

        childWin.OnRightClick = tabDetachFunc
        
    end)

    --print(string.format("[Realm Builder] EffectsMenu initialized in %d ms", Ext.Timer.MonotonicTime() - now))
    now = Ext.Timer.MonotonicTime()
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
    if self.presetMenu then
        self.presetMenu:Destroy()
        self.presetMenu = nil
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

---@param guid string
---@param doDetach? boolean
function Menu:FocusOnTab(guid, doDetach)
    local entityTab = self.entityMenu.entityTabs[guid]
    if entityTab then
        entityTab:Focus()
        if doDetach and not entityTab.isWindow then
            entityTab.detachButton:OnClick()
        end
    else
        Warning("No prop tab found for GUID: " .. tostring(guid))
    end
end

--- @type RB_MainMenu
RBMenu = nil
RegisterOnSessionLoaded(function()
    local now = Ext.Timer.MonotonicTime()
    if RBMenu == nil then
        RBMenu = Menu:Add()
        RBMenu.panel.Open = false
    end
    print(string.format("[Realm Builder] Menu initialized in %d ms", Ext.Timer.MonotonicTime() - now))
end, 100)



