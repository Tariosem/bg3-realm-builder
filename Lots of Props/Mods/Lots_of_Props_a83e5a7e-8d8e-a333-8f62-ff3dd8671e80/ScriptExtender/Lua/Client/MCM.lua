--- @type table
MCM = MCM or {}

local function toggleMainWindow()
    if LOPMenu and LOPMenu.panel then
        LOPMenu.panel.Open = not LOPMenu.panel.Open
    else
        LOPMenu = Menu:Add()
    end
    Post("ScanAllProps")
end

MCM.Keybinding.SetCallback("key_toggle_main_window", function()
    toggleMainWindow()
end)

MCM.EventButton.RegisterCallback("event_button_toggle_main_widnow", function()
    toggleMainWindow()
end)

MCM.Keybinding.SetCallback("key_toggle_items_browser", function()
    if not LOPMenu then
        return
    end

    local itemsBrowser, effectsBrowser = LOPMenu:GetBrowsers()
    if itemsBrowser then
        if itemsBrowser.panel.Open then
            itemsBrowser.panel.Open = false
        else
            itemsBrowser:Focus()
        end
    end
    if effectsBrowser and effectsBrowser.panel.Open then
        effectsBrowser.panel.Open = false
    end
end)

MCM.Keybinding.SetCallback("key_toggle_effects_browser", function()
    if not LOPMenu then
        return
    end

    local itemsBrowser, effectsBrowser = LOPMenu:GetBrowsers()
    if effectsBrowser then
        if effectsBrowser.panel.Open then
            effectsBrowser.panel.Open = false
        else
            effectsBrowser:Focus()
        end
    end
    if itemsBrowser and itemsBrowser.panel.Open then
        itemsBrowser.panel.Open = false
    end
end)

MCM.Keybinding.SetCallback("key_toggle_transform_toolbar", function()
    if not TransformToolbar or not TransformToolbar.TopToolBar then
        return
    end

    TransformToolbar.TopToolBar.Open = not TransformToolbar.TopToolBar.Open
end)

MCM.EventButton.SetDisabled("event_button_toggle_main_widnow", true, GetLoca("Enabled after loading a save"))

RegisterOnSessionLoaded(function()
    MCM.EventButton.SetDisabled("event_button_toggle_main_widnow", false)
end)
