RequireFiles("Server/", {
    "OsirisHelpers",
    "EntityManager",
    "EffectsManager",
    "BindManager",
})

EM = EffectsManager:init("EffectsManager") --[[@as EffectsManager]]

BM = BindManager

DebugUuid = nil

function OnSessionLoaded()
end

Ext.Events.SessionLoaded:Subscribe(OnSessionLoaded)

RequireFiles("Server/", {
    "ServerListeners",
    "Subscribe",
})

Ext.RegisterConsoleCommand("RBDEBUG", function()
end)

--Ext.Require("Server/Test/_init.lua") 