RBUtils.RequireFiles("Server/", {
    "OsirisHelpers",
    "ServerEntityHelpers",
    "EntityManager",
    "EffectsManager",
    "BindManager",
})

RB_GLOBALS.EffectManager = EffectsManager:init("EffectsManager") --[[@as RB_EffectsManager]]

RBUtils.RequireFiles("Server/", {
    "ServerListeners",
    "ServerSpawn",
})

--Ext.Require("Server/Test/_init.lua") 