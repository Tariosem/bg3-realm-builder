RequireFiles("Server/", {
    "OsirisHelpers",
    "PropsManager",
    "EffectsManager",
    "BindManager",
    "GizmoManager"
})

PM = PropsManager:init("PropsManager") --[[@as PropsManager]]

EM = EffectsManager:init("EffectsManager") --[[@as EffectsManager]]

GM = GizmoManager --[[@as GizmoManager]]

BM = BindManager

DebugUuid = nil

function OnSessionLoaded()
end

Ext.Events.SessionLoaded:Subscribe(OnSessionLoaded)

RequireFiles("Server/", {
    "Handlers",
    "Broadcast",
    "Subscribe",
})

Ext.RegisterConsoleCommand("LOPDEBUG", function()
end)

--Ext.Require("Server/Test/_init.lua") 