--- @type table
MCM = MCM or {}

local function toggleMainWindow()
    if RBMenu and RBMenu.panel then
        RBMenu.panel.Open = not RBMenu.panel.Open
    else
        RBMenu = Menu:Add()
    end
    NetChannel.ManageEntity:SendToServer({ Action = "Scan" })
end

local function ToggleBrowser(targetKey)
    if not RBMenu then
        return
    end

    local allBrowsers = {
        effect = RBMenu.effectBrowser,
        item = RBMenu.itemBrowser,
        character = RBMenu.characterBrowser,
        scenery = RBMenu.sceneryBrowser,
        prefab = RBMenu.prefabBrowser,
    }

    local targetBrowser = allBrowsers[targetKey]
    if not targetBrowser then
        return
    end

    for key, browser in pairs(allBrowsers) do
        if key ~= targetKey and browser and browser.panel and browser.panel.Open then
            browser:Close()
        end
    end
    targetBrowser:Toggle()
end

local browserMenu = RegisterWindow("generic", "Browser Menu", "Guide Menu")
browserMenu.AlwaysAutoResize = true
browserMenu.Closeable = true

local allAvailableBrowsers = {
    {Key = "item", Label = "Item Browser"},
    {Key = "effect", Label = "Effect Browser"},
    {Key = "character", Label = "Character Browser"},
    {Key = "scenery", Label = "Scenery Browser"},
    {Key = "prefab", Label = "Prefab Browser"},
}
table.sort(allAvailableBrowsers, function(a,b) return a.Label < b.Label end)

for _, browser in pairs(allAvailableBrowsers) do
    browserMenu:AddButton(browser.Label).OnClick = function()
        ToggleBrowser(browser.Key)
    end
end
allAvailableBrowsers = nil

MCM.Keybinding.SetCallback("key_toggle_main_window", function()
    toggleMainWindow()
end)

MCM.EventButton.RegisterCallback("event_button_toggle_main_widnow", function()
    toggleMainWindow()
end)

MCM.Keybinding.SetCallback("key_toggle_browser_menu", function()
    browserMenu.Open = not browserMenu.Open
end)

MCM.Keybinding.SetCallback("key_toggle_transform_toolbar", function()
    if not TransformToolbar or not TransformToolbar.TopToolBar then
        return
    end

    TransformToolbar:Toggle()
end)

MCM.EventButton.SetDisabled("event_button_toggle_main_widnow", true, GetLoca("Enabled after loading a save"))

RegisterOnSessionLoaded(function()
    MCM.EventButton.SetDisabled("event_button_toggle_main_widnow", false)
end)
