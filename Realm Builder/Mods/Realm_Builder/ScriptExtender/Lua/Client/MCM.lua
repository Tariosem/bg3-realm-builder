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

MCM.Keybinding.SetCallback("key_toggle_main_window", function()
    toggleMainWindow()
end)

MCM.EventButton.RegisterCallback("event_button_toggle_main_widnow", function()
    toggleMainWindow()
end)

MCM.Keybinding.SetCallback("key_toggle_items_browser", function()
    if not RBMenu then
        return
    end

    local effectsBrowser, itemsBrowser = RBMenu.effectBrowser, RBMenu.itemBrowser
    if itemsBrowser then
        if itemsBrowser.panel and itemsBrowser.panel.Open then
            itemsBrowser.panel.Open = false
            if itemsBrowser.panel.OnClose then
                itemsBrowser.panel:OnClose()
            end
        elseif not itemsBrowser.panel then
            itemsBrowser:Render()
        else
            itemsBrowser:Focus()
        end
    end

    if effectsBrowser and effectsBrowser.panel and effectsBrowser.panel.Open then
        effectsBrowser.panel.Open = false
        if effectsBrowser.panel.OnClose then
            effectsBrowser.panel:OnClose()
        end
    end
end)

MCM.Keybinding.SetCallback("key_toggle_effects_browser", function()
    if not RBMenu then
        return
    end

    local effectsBrowser, itemsBrowser = RBMenu.effectBrowser, RBMenu.itemBrowser
    if effectsBrowser then
        if effectsBrowser.panel and effectsBrowser.panel.Open then
            effectsBrowser.panel.Open = false
            if effectsBrowser.panel.OnClose then
                effectsBrowser.panel:OnClose()
            end
        elseif not effectsBrowser.panel then
            effectsBrowser:Render()
        else
            effectsBrowser:Focus()
        end
    end
    if itemsBrowser and itemsBrowser.panel and itemsBrowser.panel.Open then
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

    TransformToolbar:Toggle()
end)

MCM.EventButton.SetDisabled("event_button_toggle_main_widnow", true, GetLoca("Enabled after loading a save"))

RegisterOnSessionLoaded(function()
    MCM.EventButton.SetDisabled("event_button_toggle_main_widnow", false)
end)
