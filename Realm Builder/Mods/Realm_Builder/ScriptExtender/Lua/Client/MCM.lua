MCM = MCM
if not MCM then return end

local function toggleMainWindow()
    if RB_GLOBALS.MainMenu and RB_GLOBALS.MainMenu.panel then
        RB_GLOBALS.MainMenu.panel.Open = not RB_GLOBALS.MainMenu.panel.Open
    else
        RB_GLOBALS.MainMenu = RealmBuilderMainMenu:Add()
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
    if RB_GLOBALS.MainMenu and not RB_GLOBALS.MainMenu.browserMenu then
        return
    end

    RB_GLOBALS.MainMenu.browserMenu.Open = not RB_GLOBALS.MainMenu.browserMenu.Open

    --browserMenu.Open = not browserMenu.Open
end)

MCM.Keybinding.SetCallback("key_toggle_transform_toolbar", function()
    if not RB_GLOBALS.MainMenu and not RB_GLOBALS.MainMenu.transformBar then
        return
    end

    RB_GLOBALS.MainMenu.transformBar:Toggle()
end)

RB_DEBUG_LEVEL = MCM.Get("slider_int_debug_level") or 2

Ext.ModEvents.BG3MCM["MCM_Setting_Saved"]:Subscribe(function(payload)
    if not payload or payload.modUUID ~= ModuleUUID or not payload.settingId then
        return
    end

    if payload.settingId == "slider_int_debug_level" then
        RB_DEBUG_LEVEL = MCM.Get("slider_int_debug_level") or 2
    end
end)

MCM.EventButton.SetDisabled("event_button_toggle_main_widnow", true, GetLoca("Enabled after loading a save"))

EventsSubscriber.RegisterOnSessionLoaded(function()
    MCM.EventButton.SetDisabled("event_button_toggle_main_widnow", false)
end)
