MCM = MCM
if not MCM then return end

local function toggleMainWindow()
    if RBMenu and RBMenu.panel then
        RBMenu.panel.Open = not RBMenu.panel.Open
    else
        RBMenu = RealmBuilderMainMenu:Add()
    end
    NetChannel.ManageEntity:SendToServer({ Action = "Scan" })
end

MCM.Keybinding.SetCallback("key_toggle_main_window", function()
    toggleMainWindow()
end)

MCM.EventButton.RegisterCallback("event_button_toggle_main_widnow", function()
    toggleMainWindow()
end)

MCM.Keybinding.SetCallback("key_toggle_browser_menu", function()
    if RBMenu and not RBMenu.browserMenu then
        return
    end

    RBMenu.browserMenu.Open = not RBMenu.browserMenu.Open

    --browserMenu.Open = not browserMenu.Open
end)

MCM.Keybinding.SetCallback("key_toggle_transform_toolbar", function()
    if not RBMenu and not RBMenu.transformBar then
        return
    end

    RBMenu.transformBar:Toggle()
end)

MCM.EventButton.SetDisabled("event_button_toggle_main_widnow", true, GetLoca("Enabled after loading a save"))

RegisterOnSessionLoaded(function()
    MCM.EventButton.SetDisabled("event_button_toggle_main_widnow", false)
end)
