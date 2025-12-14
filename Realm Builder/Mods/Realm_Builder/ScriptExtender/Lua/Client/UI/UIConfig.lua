SCALE_FACTOR = 1.0

UIHelpers = UIHelpers or {}

function GetScaleFactor(scale)
    SCALE_FACTOR = scale
end

---@return integer width
---@return integer height
function UIHelpers.GetScreenSize()
    local screen = Ext.IMGUI.GetViewportSize()
    return screen[1], screen[2]
end

function UIHelpers.GetUIScale()
    local _, screenHeight = UIHelpers.GetScreenSize()
    local baseHeight = 2160
    return screenHeight / baseHeight
end

--- @param value number
--- @return number
function ScaleUI(value)
    return value * SCALE_FACTOR
end

SCALE_FACTOR = UIHelpers.GetUIScale()

IMAGESIZE = {
    ROW = Vec2.new(36, 36) * SCALE_FACTOR,
    TINY = Vec2.new(32, 32) * SCALE_FACTOR,
    FRAME = Vec2.new(42, 42) * SCALE_FACTOR,
    SMALL = Vec2.new(42, 42) * SCALE_FACTOR,
    MEDIUM = Vec2.new(64, 64) * SCALE_FACTOR,
    LARGE = Vec2.new(128, 128) * SCALE_FACTOR,
}

UIConfig = {}
UICONFIG = {
    Theme = {
        Color = {
            autoReload = false,
        },
        Style = {
            autoReload = false,
        }
    },
    EffectMenu = {
        AutoSave = true,
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

function UIConfig.SaveConfig(field)
    if field then
        UIConfig.SaveConfigField(field)
        return
    end

    local configData = Ext.Json.Stringify(UICONFIG)
    local filePath = FilePath.GetUIConfigPath()
    Ext.IO.SaveFile(filePath, configData)
end

function UIConfig.LoadConfig()
    local filePath = FilePath.GetUIConfigPath()
    local configData = Ext.IO.LoadFile(filePath)
    if configData then
        local saved = Ext.Json.Parse(configData)
        for key, v in pairs(saved) do
            UICONFIG[key] = v
        end
    end

    SetDebugLevel(UICONFIG.DEBUG_LEVEL or 4)
end

function UIConfig.SaveConfigField(field)
    local filePath = FilePath.GetUIConfigPath()
    local raw = Ext.IO.LoadFile(filePath)
    local data = raw and Ext.Json.Parse(raw) or {}

    data[field] = UICONFIG[field]
    local configData = Ext.Json.Stringify(data)
    Ext.IO.SaveFile(filePath, configData)
end

UIConfig.LoadConfig()


