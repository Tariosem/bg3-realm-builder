RequireFiles("Server/", {
    "OsirisHelpers",
    "ServerEntityHelpers",
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

--Ext.Require("Server/Test/_init.lua") 