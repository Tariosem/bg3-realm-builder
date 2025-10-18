--- @type table
MCM = MCM or {}

local function toggleMainWindow()
    if LOPMenu and LOPMenu.panel then
        LOPMenu.panel.Open = not LOPMenu.panel.Open
    else
        LOPMenu = Menu:Add()
    end
    NetChannel.ManageEntity:SendToServer({ Action = "Scan" })
    
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

    local effectsBrowser, itemsBrowser = LOPMenu:GetBrowsers()
    if itemsBrowser then
        if itemsBrowser.panel.Open then
            itemsBrowser.panel.Open = false
            if itemsBrowser.panel.OnClose then
                itemsBrowser.panel:OnClose()
            end
        else
            itemsBrowser:Focus()
        end
    end

    if effectsBrowser and effectsBrowser.panel.Open then
        effectsBrowser.panel.Open = false
        if effectsBrowser.panel.OnClose then
            effectsBrowser.panel:OnClose()
        end
    end
end)

MCM.Keybinding.SetCallback("key_toggle_effects_browser", function()
    if not LOPMenu then
        return
    end

    local effectsBrowser, itemsBrowser = LOPMenu:GetBrowsers()
    if effectsBrowser then
        if effectsBrowser.panel.Open then
            effectsBrowser.panel.Open = false
            if effectsBrowser.panel.OnClose then
                effectsBrowser.panel:OnClose()
            end
        else
            effectsBrowser:Focus()
        end
    end
    if itemsBrowser and itemsBrowser.panel.Open then
        itemsBrowser.panel.Open = false
        if itemsBrowser.panel.OnClose then
            itemsBrowser.panel:OnClose()
        end
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
