MENU_WIDTH = 1000 * SCALE_FACTOR
MENU_HEIGHT = 1200 * SCALE_FACTOR

Menu = _Class("Menu")
--- @class LOP_MainMenu
--- @field isValid boolean
--- @field effectsMenu EffectsMenu
--- @field propsMenu PropsMenu
--- @field presetMenu PresetMenu
--- @field styleMenu StyleMenu
--- @field panel ExtuiWindowBase
--- @field tabBar ExtuiTabBar
--- @field FocusOnPropTab fun(self:LOP_MainMenu, guid:string, doDetach:boolean|nil)
function Menu:__init()
    self.isValid = true
    self.panel = nil
    self.tabs = {}

    self:RegisterEvents()
end

function Menu:RegisterEvents()
    local meMod = KeybindManager:CreateModule("Generic")

    meMod:RegisterEvent("ToggleMenu", function()
        if self.panel then
            self.panel.Open = not self.panel.Open
        end
    end, "Toggles the Lots of Props menu")

    meMod:RegisterEvent("OpenTransformToolbar", function()
        if self.editorMenu then
            self.editorMenu:Open()
        end
    end, "Opens the Transform Toolbar")


end

function Menu:Render()
    self.panel = RegisterWindow("Citadel", "Lots of  Props", "MainMenu", self, nil, {MENU_WIDTH, MENU_HEIGHT})
    self.panel.Closeable = true

    self.tabBar = self.panel:AddTabBar("TabBar")
    local now = Ext.Timer.MonotonicTime()
    Timer:Ticks(1, function()
        self.styleMenu = StyleMenu:Add(self.tabBar)
    end)

    now = Ext.Timer.MonotonicTime()

    Timer:Ticks(2, function()
        self.presetMenu = PresetMenu:Add(self.tabBar)
        --Debug("Finished adding PresetMenu tab, it takes" .. Ext.Timer.MonotonicTime() - now .. "ms")
        --now = Ext.Timer.MonotonicTime()
    end)

    Timer:Ticks(3, function()
        self.propsMenu = PropsMenu:Add(self.tabBar)
        --Debug("Finished adding PropsMenu tab, it takes" .. Ext.Timer.MonotonicTime() - now .. "ms")
        --now = Ext.Timer.MonotonicTime()
    end)

    Timer:Ticks(4, function()
        self.effectsMenu = EffectsMenu:Add(self.tabBar)
        --Debug("Finished adding EffectsMenu tab, it takes" .. Ext.Timer.MonotonicTime() - now .. "ms")
        --now = Ext.Timer.MonotonicTime()
    end)

    self.GetBrowsers = function()
        return self.effectsMenu.iconBrowser, self.propsMenu.iconBrowser
    end

    Timer:Ticks(5, function()
        self.editorMenu = TransformToolbar:Add(self.tabBar)
        --Debug("Finished adding TransformToolbar tab, it takes" .. Ext.Timer.MonotonicTime() - now .. "ms")
        --now = Ext.Timer.MonotonicTime()
    end)

    Timer:Ticks(6, function()
        KeybindMenu:Render(self.tabBar)
        --Debug("Finished adding KeybindMenu tab, it takes" .. Ext.Timer.MonotonicTime() - now .. "ms")
        --now = Ext.Timer.MonotonicTime()
    end)

    --print(string.format("[Lots of Props] EffectsMenu initialized in %d ms", Ext.Timer.MonotonicTime() - now))
    now = Ext.Timer.MonotonicTime()
end

function Menu:NewPropAdded(guid)
    if self.propsMenu then
        self.propsMenu:NewPropAdded(guid)
    end
end

function Menu:PropDeleted(guid)
    if self.propsMenu then
        self.propsMenu:PropDeleted(guid)
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
    if self.propsMenu then
        self.propsMenu:Destroy()
        self.propsMenu = nil
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

--- @return LOP_MainMenu
function Menu:Add()
    local menu = Menu.new()
    menu:Render()
    return menu
end

---@param guid string
---@param doDetach? boolean
function Menu:FocusOnPropTab(guid, doDetach)
    local propTab = self.propsMenu.propTabs[guid]
    if propTab then
        propTab:Focus()
        if doDetach and not propTab.isWindow then
            propTab.detachButton:OnClick()
        end
    else
        Warning("No prop tab found for GUID: " .. tostring(guid))
    end
end

--- @type LOP_MainMenu
LOPMenu = nil
RegisterOnSessionLoaded(function()
    local now = Ext.Timer.MonotonicTime()
    if LOPMenu == nil then
        LOPMenu = Menu:Add()
        LOPMenu.panel.Open = false
    end
    --print(string.format("[Lots of Props] Menu initialized in %d ms", Ext.Timer.MonotonicTime() - now))
end, 100)



