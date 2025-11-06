SCALE_FACTOR = 1.0

function GetScaleFactor(scale)
    SCALE_FACTOR = scale
end

---@return integer width
---@return integer height
function GetScreenSize()
    local screen = Ext.IMGUI.GetViewportSize()
    return screen[1], screen[2]
end

function GetUIScale()
    local _, screenHeight = GetScreenSize()
    local baseHeight = 2160
    return screenHeight / baseHeight
end

SCALE_FACTOR = GetUIScale()

IMAGESIZE = {
    TINY = Vec2.new(32, 32) * SCALE_FACTOR,
    SMALL = Vec2.new(48, 48) * SCALE_FACTOR,
    MEDIUM = Vec2.new(64, 64) * SCALE_FACTOR,
    LARGE = Vec2.new(128, 128) * SCALE_FACTOR,
}

CONFIG = {
    Theme = {
        Color = {
            autoReload = false,
        },
        Style = {
            autoReload = false,
        }
    },
    EntityMenu = {},
    EffectMenu = {
        autoSave = true,
    },
    EffectBrowser = {
        autoSave = true,
    },
    ItemBrowser = {
        autoSave = true,
    },
    SceneMenu = {
        autoSave = true,
    },
    Misc = {
        DangerButtonColor = {0.6, 0.2, 0.2, 0.8},
        DangerButtonHoveredColor = {1, 0.2, 0.2, 0.9},
        DangerButtonActiveColor = {0.8, 0.1, 0.1, 0.9},
        DangerButtonTextColor = {1, 1, 1, 1},

        ConfirmButtonColor = {0.2, 0.6, 0.2, 0.8},
        ConfirmButtonHoveredColor = {0.3, 0.8, 0.3, 0.9},
        ConfirmButtonActiveColor = {0.1, 0.7, 0.1, 0.9},
        ConfirmButtonTextColor = {1, 1, 1, 1},

        InfoButtonColor = {0.3, 0.4, 0.5, 0.8},
        InfoButtonHoveredColor = {0.3, 0.6, 1, 0.9},
        InfoButtonActiveColor = {0.1, 0.5, 0.8, 0.9},
        InfoButtonTextColor = {1, 1, 1, 1}
    },
    DEBUG_LEVEL = 4
}

function SaveConfig(field)
    if field then
        SaveConfigField(field)
        return
    end

    local configData = Ext.Json.Stringify(CONFIG)
    local filePath = "Realm_Builder/Config.json"
    Ext.IO.SaveFile(filePath, configData)
end

function LoadConfig()
    local filePath = "Realm_Builder/Config.json"
    local configData = Ext.IO.LoadFile(filePath)
    if configData then
        local saved = Ext.Json.Parse(configData)
        for key, v in pairs(saved) do
            CONFIG[key] = v
        end
    end

    SetDebugLevel(CONFIG.DEBUG_LEVEL or 4)
end

function SaveConfigField(field)
    local filePath = "Realm_Builder/Config.json"
    local raw = Ext.IO.LoadFile(filePath)
    local data = raw and Ext.Json.Parse(raw) or {}

    data[field] = CONFIG[field]
    local configData = Ext.Json.Stringify(data)
    Ext.IO.SaveFile(filePath, configData)
end

LoadConfig()


