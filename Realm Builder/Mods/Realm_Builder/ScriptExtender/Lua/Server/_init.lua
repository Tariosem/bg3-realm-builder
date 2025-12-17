RBUtils.RequireFiles("Server/", {
    "OsirisHelpers",
    "ServerEntityHelpers",
    "EntityManager",
    "EffectsManager",
    "BindManager",
})

RB_GLOBALS.EffectManager = EffectsManager:init("EffectsManager") --[[@as EffectsManager]]

RBUtils.RequireFiles("Server/", {
    "ServerListeners",
})

--Ext.Require("Server/Test/_init.lua") 