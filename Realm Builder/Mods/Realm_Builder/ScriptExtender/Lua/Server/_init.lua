RBUtils.RequireFiles("Server/", {
    "OsirisHelpers",
    "ServerEntityHelpers",
    "EntityManager",
    "EffectsManager",
    "BindManager",
})

RB_EffectManager = EffectsManager:init("EffectsManager") --[[@as EffectsManager]]

RBUtils.RequireFiles("Server/", {
    "ServerListeners",
    "Subscribe",
})

--Ext.Require("Server/Test/_init.lua") 